@echo off
rem Run the PowerShell controller without changing the computer policy.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0run_stata_peer_1.ps1" %*
exit /b %errorlevel%
