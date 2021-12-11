@echo off
if exist "%~dp0\secret\secret.dme" (
    copy "%~dp0\secret\secret.dme" "%~dp0"
)
call "%~dp0\tools\build\build.bat" %*
pause
