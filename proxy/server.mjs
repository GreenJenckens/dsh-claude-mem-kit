/**
 * dsh-claude-mem-kit — loopback OpenAI-compatible bridge for OpenCode Go.
 *
 * MIT License. Copyright (c) 2026 GreenJenckens.
 *
 * Why it exists: the OpenCode Go inference API rejects requests that do not
 * carry an `x-opencode-session` routing header, while OpenAI-compatible
 * clients (Claude-Mem's observer, local tools) can only set `Authorization`.
 * This proxy adds the header and streams the upstream answer back untouched.
 *
 * Endpoint: http://127.0.0.1:37901/v1/{chat/completions,models}
 * Upstream: https://opencode.ai/inference/go/openai/v1/...
 *
 * Environment:
 *   OC_PROXY_PORT      listen port (default 37901)
 *   OC_PROXY_UPSTREAM  upstream origin (default https://opencode.ai)
 *   OC_PROXY_SESSION   x-opencode-session value (default random per process)
 *   OC_PROXY_MODEL     model id reported by /v1/models
 */
import http from 'node:http'
import { randomUUID } from 'node:crypto'

const LISTEN_HOST = '127.0.0.1'
const LISTEN_PORT = Number(process.env.OC_PROXY_PORT ?? 37901)
const UPSTREAM_ORIGIN = (process.env.OC_PROXY_UPSTREAM ?? 'https://opencode.ai').replace(/\/+$/, '')
const UPSTREAM_PREFIX = '/inference/go/openai'
const SESSION_ID = process.env.OC_PROXY_SESSION ?? `claude-mem-observer-${randomUUID().slice(0, 8)}`
const MODEL_ID = process.env.OC_PROXY_MODEL ?? 'deepseek-v4.1-flash'

/** Forward one request upstream, streaming the response back verbatim. */
async function forward(req, res) {
  const chunks = []
  for await (const chunk of req) chunks.push(chunk)
  const body = Buffer.concat(chunks)

  const headers = {}
  for (const [name, value] of Object.entries(req.headers)) {
    if (['host', 'connection', 'content-length', 'x-opencode-session'].includes(name.toLowerCase())) continue
    headers[name] = value
  }
  headers['x-opencode-session'] = SESSION_ID
  if (body.length > 0) headers['content-length'] = String(body.length)

  const target = `${UPSTREAM_ORIGIN}${UPSTREAM_PREFIX}${req.url ?? '/'}`
  let upstream
  try {
    upstream = await fetch(target, {
      method: req.method,
      headers,
      body: req.method === 'GET' || req.method === 'HEAD' ? undefined : body,
    })
  } catch (error) {
    res.writeHead(502, { 'content-type': 'application/json' })
    res.end(JSON.stringify({ error: { message: `upstream unreachable: ${error.message}` } }))
    return
  }

  const outHeaders = {}
  upstream.headers.forEach((value, name) => {
    if (['content-encoding', 'content-length', 'transfer-encoding', 'connection'].includes(name.toLowerCase())) return
    outHeaders[name] = value
  })
  res.writeHead(upstream.status, outHeaders)
  if (upstream.body === null) {
    res.end()
    return
  }
  for await (const chunk of upstream.body) res.write(chunk)
  res.end()
}

const server = http.createServer((req, res) => {
  if (req.method === 'GET' && req.url === '/health') {
    res.writeHead(200, { 'content-type': 'application/json' })
    res.end(JSON.stringify({ status: 'ok', upstream: `${UPSTREAM_ORIGIN}${UPSTREAM_PREFIX}`, session: SESSION_ID }))
    return
  }
  if (req.method === 'GET' && req.url === '/v1/models') {
    res.writeHead(200, { 'content-type': 'application/json' })
    res.end(JSON.stringify({ object: 'list', data: [{ id: MODEL_ID, object: 'model' }] }))
    return
  }
  forward(req, res).catch((error) => {
    if (!res.headersSent) res.writeHead(500, { 'content-type': 'application/json' })
    res.end(JSON.stringify({ error: { message: error.message } }))
  })
})

server.listen(LISTEN_PORT, LISTEN_HOST, () => {
  console.log(`observer bridge listening on http://${LISTEN_HOST}:${LISTEN_PORT}/v1 -> ${UPSTREAM_ORIGIN}${UPSTREAM_PREFIX}`)
})
