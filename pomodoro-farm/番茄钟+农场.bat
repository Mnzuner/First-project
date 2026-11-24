@echo off
setlocal
set "PROJ=%~dp0"
if "%PROJ:~-1%"=="\" set "PROJ=%PROJ:~0,-1%"

rem 便携模式：把 Godot 的日志与存档放到项目内的 .runtime 目录，
rem 避免 %APPDATA% 不可写时引擎启动即崩溃。
set "RUNTIME=%PROJ%\.runtime"
if not exist "%RUNTIME%\appdata" mkdir "%RUNTIME%\appdata"
set "APPDATA=%RUNTIME%\appdata"
set "LOGFILE=%RUNTIME%\launch.log"

set "GODOT="
if exist "%PROJ%\Godot_v4.5-stable_win64.exe" set "GODOT=%PROJ%\Godot_v4.5-stable_win64.exe"
if not defined GODOT if exist "%PROJ%\..\tools\Godot_v4.5-stable_win64.exe" set "GODOT=%PROJ%\..\tools\Godot_v4.5-stable_win64.exe"
if not defined GODOT if exist "%PROJ%\..\tools\Godot_v4.5-stable_win64_console.exe" set "GODOT=%PROJ%\..\tools\Godot_v4.5-stable_win64_console.exe"
if not defined GODOT (
  where godot.exe >nul 2>nul
  if not errorlevel 1 set "GODOT=godot.exe"
)

if not defined GODOT (
  echo [ERROR] Godot 4.x not found.
  echo         Copy Godot_v4.5-stable_win64.exe next to this .bat,
  echo         or into "%PROJ%\..\tools\", or add godot to PATH.
  echo.
  pause
  exit /b 1
)

echo Engine : %GODOT%
echo Project: %PROJ%
echo Save   : %APPDATA%\Godot\app_userdata
echo.
echo Starting game, this window will close by itself...

"%GODOT%" --path "%PROJ%" > "%LOGFILE%" 2>&1
set "CODE=%ERRORLEVEL%"
if not "%CODE%"=="0" (
  echo.
  echo [ERROR] Game exited with code %CODE%. Log:
  echo ------------------------------------------------------------
  type "%LOGFILE%"
  echo ------------------------------------------------------------
  pause
)
exit /b %CODE%
