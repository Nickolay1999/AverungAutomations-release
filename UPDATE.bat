@echo off
setlocal EnableExtensions EnableDelayedExpansion

REM ============================================================
REM  Если запущены НЕ из TEMP - копируем себя в TEMP и стартуем оттуда.
REM  Это освобождает файл в репозитории для git pull.
REM ============================================================
if /i "%~dp0"=="%TEMP%\" goto :main

set "SELF_TMP=%TEMP%\__git_update_run.bat"
copy /y "%~f0" "%SELF_TMP%" >nul
if errorlevel 1 (
    echo [ERROR] Не удалось скопировать себя в TEMP.
    exit /b 1
)
REM Передаём исходную папку аргументом
call "%SELF_TMP%" "%~dp0"
set "RC=%errorlevel%"
del "%SELF_TMP%" >nul 2>&1
exit /b %RC%

REM ============================================================
REM  Основная логика (выполняется из TEMP, %~1 = папка репозитория)
REM ============================================================
:main
pushd "%~1" 2>nul
if errorlevel 1 (
    echo [ERROR] Не удалось открыть папку: %~1
    popd
    exit /b 1
)

where git >nul 2>&1
if errorlevel 1 (
    echo [ERROR] git не найден в PATH.
    popd
    exit /b 1
)

git rev-parse --is-inside-work-tree >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Папка не является git-репозиторием: %CD%
    popd
    exit /b 1
)

for /f "delims=" %%R in ('git rev-parse --show-toplevel') do set "REPO_ROOT=%%R"
echo ============================================================
echo  Репозиторий: %REPO_ROOT%
echo ============================================================
echo.

set "LFS_OK=0"
git lfs version >nul 2>&1 && set "LFS_OK=1"
if "%LFS_OK%"=="0" (
    echo [WARN] Git LFS не установлен - LFS-объекты не скачаются.
    echo        Установка: winget install GitHub.GitLFS
    echo.
)

echo [1/3] git fetch --all --prune
git fetch --all --prune
if errorlevel 1 (
    echo [ERROR] git fetch завершился ошибкой.
    popd
    exit /b 1
)
echo.

echo [2/3] git pull --ff-only
git pull --ff-only
if errorlevel 1 (
    echo [ERROR] git pull завершился ошибкой. Проверьте: git status
    popd
    exit /b 1
)
echo.

if "%LFS_OK%"=="1" (
    echo [3/3] git lfs pull
    git lfs pull
    if errorlevel 1 echo [WARN] git lfs pull завершился ошибкой.
) else (
    echo [3/3] Пропуск git lfs pull - LFS не установлен.
)

echo.
echo ============================================================
echo  Готово.
echo ============================================================
popd
endlocal
exit /b 0
