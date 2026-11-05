' dsh-claude-mem-kit — start the observer bridge without a console window.
' MIT License, Copyright (c) 2026 GreenJenckens.
'
' Drop a shortcut to this file into:
'   %APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup
' or run scripts\install.ps1, which creates that shortcut for you.
Set shell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
shell.Run "cmd /c """ & fso.GetParentFolderName(WScript.ScriptFullName) & "\run-proxy.cmd""", 0, False
