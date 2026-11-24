@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion
cd /d "%~dp0"

where git >nul 2>nul
if errorlevel 1 (
    echo [X] git was not found in PATH.
    echo     Install Git for Windows or add D:\\Git\\cmd to PATH.
    pause
    exit /b 1
)

echo.
echo ==========================================
echo   Git_Workspace  --^>  GitHub
echo ==========================================
echo.

git add -A
git diff --cached --quiet
if errorlevel 1 (
    set "TS="
    for /f "delims=" %%i in ('powershell -NoProfile -Command "Get-Date -Format 'yyyy-MM-dd HH:mm'"') do set "TS=%%i"
    if not defined TS set "TS=%date% %time%"
    git commit -m "update !TS!"
    if errorlevel 1 goto fail
) else (
    echo [i] Working tree clean, nothing new to commit.
)

echo.
echo [.] Pushing to origin ...
git push -u origin HEAD
if errorlevel 1 goto fail

echo.
echo [OK] Synced.
git status -sb
echo [OK] https://github.com/Mnzuner/First-project
goto end

:fail
echo.
echo [X] Operation failed - read the message above.
echo.
echo     Authentication error  -^> run "git push" once and
echo                            complete the browser login.
echo     rejected/non-fast-forward -^> remote has newer commits,
echo                            run "git pull --rebase" then retry.

:end
echo.
pause
endlocal
