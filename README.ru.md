<p align="center"><img src="docs/banner.svg" alt="dsh-claude-mem-kit — память для DeepSeek Harness" width="100%"></p>

# dsh-claude-mem-kit

**Долговременная память для агентов DeepSeek Harness (DSH) на базе Claude-Mem: нативные инструменты `mem_search`, автоматический захват транскриптов и примерно в 10 раз меньший расход модели-наблюдателя. Windows, Linux, macOS.**

> **Неофициально.** Набор для установки и настройки [Claude-Mem](https://github.com/thedotmack/claude-mem)
> в DeepSeek Harness. Проект не связан с авторами Claude-Mem и DeepSeek и не одобрен ими.

## Зачем

Агенты забывают всё между сессиями. Claude-Mem сжимает транскрипты в наблюдения
и отдаёт их через `mem_search`, `mem_timeline`, `mem_get_observations`,
`mem_save`, `mem_context`. Адаптер DSH (`@claude-mem/dsh`) уже есть в upstream,
но его настройки рассчитаны на другой harness: каждый вызов инструмента — отдельный
запрос наблюдателя, субагентские сессии тоже захватываются, а диалог наблюдателя
растёт до десятков тысяч токенов на запрос.

Замер на реальных сессиях DSH: **≈10 900 входных токенов на событие**, и **78%
наблюдений приходило из субагентских сессий**, итог которых и так есть в отчёте
родителя. Набор оставляет память и убирает лишнее: **≈5 700 токенов на событие,
только верхнеуровневые сессии** — около **10% прежнего расхода**.

## Платформы

| Платформа | Установщик | Профиль по умолчанию | Автозапуск моста |
|---|---|---|---|
| Windows 10/11 | [`scripts/install.ps1`](scripts/install.ps1) (PowerShell 5.1+) | `desktop` | ярлык в автозагрузке |
| Linux | [`scripts/install.sh`](scripts/install.sh) (bash) | `web` (DSH CLI) | systemd user unit / XDG autostart |
| macOS | [`scripts/install.sh`](scripts/install.sh) (bash) | `web` (DSH CLI) | LaunchAgent |

Профиль `desktop` есть там, где работает Electron-приложение DSH; профилями
`web`/`tui` управляет CLI `dsh` (`npm install -g @deepseek-ai/dsh`).
На Linux/macOS можно указать `--profile desktop`, если профиль приложения есть.

## Установка

### Windows, одной командой

```powershell
irm https://raw.githubusercontent.com/GreenJenckens/dsh-claude-mem-kit/main/scripts/bootstrap.ps1 | iex
```

### Linux / macOS, одной командой

```bash
curl -fsSL https://raw.githubusercontent.com/GreenJenckens/dsh-claude-mem-kit/main/scripts/bootstrap.sh | bash -s -- --profile web
```

Безопаснее сначала скачать и посмотреть `bootstrap.ps1` / `bootstrap.sh`, затем
запустить.

### Из клона

```bash
git clone https://github.com/GreenJenckens/dsh-claude-mem-kit.git
cd dsh-claude-mem-kit

bash scripts/install.sh --profile web                  # Linux / macOS
powershell -ExecutionPolicy Bypass -File scripts\install.ps1   # Windows
```

Полезные флаги: `--dry-run` / `-DryRun` (показать план), `--profile` / `-Profile`,
`--observer-key` / `-ObserverKey`, `--skip-bridge` / `-SkipBridge`,
`--auto-install` / `-AutoInstall`.

Скрипт идемпотентный. Что он делает:

1. ставит воркер и marketplace Claude-Mem в `~/.claude/plugins/marketplaces/thedotmack`, если их нет;
2. подключает `@claude-mem/dsh` к выбранному профилю и добавляет его в `dsh.profile.bundles`;
3. пишет `~/.claude-mem/transcript-watch.json` со схемой DSH (только верхнеуровневые сессии);
4. применяет настройки стоимости в `~/.claude-mem/settings.json` (с бэкапом);
5. запускает воркер и мост наблюдателя, регистрирует автозапуск моста.

После этого **перезапустите DeepSeek Harness** — в новых сессиях появятся
`mem_*` инструменты и скил `mem-search`.

## Как это работает

```text
DSH-сессия
   │  пишет
   ▼
~/.dsh/sessions/**/session-*/session.v4.jsonl.zstd
   │  transcript-watch.json (схема dsh)
   ▼
воркер claude-mem :37777  ──▶  SQLite + Chroma (локально)
   │  запросы наблюдателя (пакетами)
   ▼
локальный мост :37901  ──▶  OpenCode Go / любой OpenAI-совместимый endpoint
   │
   ▼
плагин DSH: контекст при создании агента + инструменты mem_*
```

Подробности: [docs/architecture.md](docs/architecture.md).

## Экономия

| Рычаг | По умолчанию | В наборе |
|---|---|---|
| Батчинг событий | 1 событие = 1 запрос | до 4 событий на запрос |
| Поколение диалога наблюдателя | 400 000 символов | 40 000 |
| Захват | все сессии | только верхнеуровневые (`session-*`) |
| Пропуск инструментов | 5 | 41 (мета-рутина DSH) |
| Стартовый контекст | 50 наблюдений / 10 сессий | 15 / 3 |
| «My Work» формулировки | генерировались моделью | выключены |

Методика и дальнейшие рычаги: [docs/cost-tuning.md](docs/cost-tuning.md).

## Проверка

```bash
curl -s http://127.0.0.1:37777/api/health
curl -s http://127.0.0.1:37901/health
```

В DSH попросите агента вызвать `mem_context` — вернётся контекст прошлых сессий.

## Безопасность

- Воркер слушает только localhost и **без аутентификации** — не выставляйте его в сеть.
- Ключ API лежит только в `~/.claude-mem/settings.json`; в репозитории его нет.
- База памяти содержит содержимое ваших сессий — считайте `~/.claude-mem` чувствительными данными.
- Не копируйте `claude-mem.db` при работающем воркере (SQLite WAL).

## Удаление

```bash
bash scripts/uninstall.sh --profile web          # Linux / macOS
powershell -ExecutionPolicy Bypass -File scripts\uninstall.ps1   # Windows
```

Добавьте `--purge-data` / `-PurgeData`, чтобы перенести `~/.claude-mem` в
резервную папку с датой вместо удаления.

## Лицензии

- Код набора (скрипты, прокси, документация): **MIT** — [LICENSE](LICENSE).
- Claude-Mem: **Apache-2.0**, © 2026 Alex Newman. DSH-адаптер основан на
  [Bleed00/dsh-claude-mem](https://github.com/Bleed00/dsh-claude-mem) (Apache-2.0).
  Исходники Claude-Mem в репозиторий не включены — схема транскрипта копируется
  при установке из пакета `@claude-mem/dsh`.
- Подробности: [NOTICE](NOTICE) и [third_party/](third_party/README.md).
