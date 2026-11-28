@echo off
chcp 65001 >nul
setlocal EnableExtensions EnableDelayedExpansion
title 异世界公会长 · 生成可分发版本

set "ROOT=%~dp0"
set "SRC=%ROOT%GuildMaster-Godot-src"
set "OUT=%ROOT%dist\portable\GuildMaster"
set "ZIP=%ROOT%dist\GuildMaster-Portable.zip"
set "WITH_MUSIC=0"
set "MAKE_ZIP=0"
set "PAUSE_AT_END=1"
set "ADMIN_FLAG="
set "SIGN_FLAG="
set "PREPARED_EXE="

:args
if "%~1"=="" goto check
if /i "%~1"=="--music"  (set "WITH_MUSIC=1" & shift & goto args)
if /i "%~1"=="--zip"    (set "MAKE_ZIP=1"  & shift & goto args)
if /i "%~1"=="--admin"  (set "ADMIN_FLAG=-RequireAdmin" & shift & goto args)
if /i "%~1"=="--sign"   (set "SIGN_FLAG=-Sign" & shift & goto args)
if /i "%~1"=="--nopause" (set "PAUSE_AT_END=0" & shift & goto args)
if /i "%~1"=="--help"  goto help
if /i "%~1"=="/?"      goto help
echo [错误] 未知参数: %~1
goto help

:help
echo.
echo 用法:  package-portable.bat [--music] [--zip] [--admin] [--sign] [--nopause]
echo.
echo   --music   连 music 文件夹一起打包（额外 578 MB）
echo   --zip     复制完成后生成 dist\GuildMaster-Portable.zip
echo   --admin   为 GuildMaster.exe 添加管理员权限请求
echo   --sign    用 GUILDMASTER_SIGN_CERT_SHA1 指定的证书签名
echo   --nopause 结束时不等待按键（CI / 批处理调用用）
echo.
if "%PAUSE_AT_END%"=="1" pause
exit /b 1

:check
echo ============================================================
echo   异世界公会长 · 生成可分发版本
echo ============================================================
echo   源目录: %SRC%
echo   输出到: %OUT%
echo.

if not exist "%SRC%\GuildMaster.exe" goto no_exe
if not exist "%SRC%\GuildMaster.pck" goto no_pck
if not exist "%SRC%\art\characters"     goto no_art
if not exist "%SRC%\art\images\piece_png" goto no_tiles
if not exist "%SRC%\runtime\python.exe" goto no_runtime
if not exist "%SRC%\rules\guild_session.py" goto no_rules

set "INPUT_EXE=%SRC%\GuildMaster.exe"
if defined ADMIN_FLAG goto prepare_exe
if not defined SIGN_FLAG goto copy_package

:prepare_exe
set "PREPARED_EXE=%TEMP%\GuildMaster-%RANDOM%-%RANDOM%.exe"
if exist "%PREPARED_EXE%" goto prepare_exe
echo 准备 EXE 权限清单和代码签名 ...
powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%tools\prepare_portable_exe.ps1" -Source "%INPUT_EXE%" -Destination "%PREPARED_EXE%" %ADMIN_FLAG% %SIGN_FLAG%
if errorlevel 1 goto fail
set "INPUT_EXE=%PREPARED_EXE%"

:copy_package
echo [1/6] 清理旧输出 ...
if exist "%OUT%" (
    echo %OUT% | findstr /i "portable" >nul || (echo [错误] 输出路径异常，拒绝删除: %OUT% & goto fail)
    rmdir /s /q "%OUT%"
)
mkdir "%OUT%" 2>nul

echo [2/6] 复制 EXE 与 PCK ...
copy /y "%INPUT_EXE%" "%OUT%\GuildMaster.exe" >nul || goto fail
if defined PREPARED_EXE del /q "%PREPARED_EXE%"
set "PREPARED_EXE="
copy /y "%SRC%\GuildMaster.pck" "%OUT%\" >nul || goto fail
if exist "%SRC%\GuildMaster.console.exe" copy /y "%SRC%\GuildMaster.console.exe" "%OUT%\" >nul

echo [3/6] 复制 art（跳过 .import）...
robocopy "%SRC%\art" "%OUT%\art" /E /XF *.import *.uid /NFL /NDL /NJH /NJS /NP >nul
if errorlevel 8 goto fail

echo [4/6] 复制 rules 与 runtime ...
robocopy "%SRC%\rules" "%OUT%\rules" /E /XD __pycache__ /XF *.pyc *.pyo /NFL /NDL /NJH /NJS /NP >nul
if errorlevel 8 goto fail
robocopy "%SRC%\runtime" "%OUT%\runtime" /E /XD __pycache__ /XF *.pyc *.pyo /NFL /NDL /NJH /NJS /NP >nul
if errorlevel 8 goto fail

echo [5/6] 复制 LICENSES 与说明 ...
if exist "%SRC%\LICENSES" robocopy "%SRC%\LICENSES" "%OUT%\LICENSES" /E /NFL /NDL /NJH /NJS /NP >nul
if %WITH_MUSIC%==1 (
    echo       附带 music 文件夹 ...
    if exist "%SRC%\music" robocopy "%SRC%\music" "%OUT%\music" /E /XF .gdignore /NFL /NDL /NJH /NJS /NP >nul
) else (
    echo       未附带 music（游戏启动时会自动建空目录，无 BGM）
)
powershell -NoProfile -Command "Set-Content -LiteralPath '%OUT%\运行说明.txt' -Encoding UTF8 -Value @('异世界公会长 · 运行说明','====================','','1. 解压后双击 GuildMaster.exe 即可开始（首次运行 Windows 可能提示 SmartScreen，选“更多信息 → 仍要运行”）。','2. 不要单独把 GuildMaster.exe 拷到别处：图片在 art\ 里，规则在 rules\，离线模式需要 runtime\。','3. 想加 BGM：把 mp3 / ogg / wav / flac 放进 music\ 文件夹，游戏内设置里可切换曲目。','4. 设置与存档保存在 %%APPDATA%%\Godot\app_userdata\ 下。')" >nul 2>nul

echo [6/6] 完成.
echo.

for /f "usebackq delims=" %%A in (`powershell -NoProfile -Command "'{0:N0}' -f ((Get-ChildItem -LiteralPath '%OUT%' -Recurse -File | Measure-Object Length -Sum).Sum/1MB)"`) do set "SIZE=%%A"
for /f "usebackq delims=" %%A in (`powershell -NoProfile -Command "(Get-ChildItem -LiteralPath '%OUT%' -Recurse -File).Count"`) do set "COUNT=%%A"
echo   输出: %OUT%
echo   文件: %COUNT% 个   体积: %SIZE% MB
echo.

if "%MAKE_ZIP%"=="0" goto done
echo   正在压缩 ... 大文件需要几分钟
del /q "%ZIP%" 2>nul
where tar >nul 2>nul && (
    tar -a -c -f "%ZIP%" -C "%ROOT%dist\portable" GuildMaster
) || (
    powershell -NoProfile -Command "Compress-Archive -Path '%OUT%' -DestinationPath '%ZIP%' -CompressionLevel Optimal -Force"
)
if not exist "%ZIP%" goto fail
for /f "usebackq delims=" %%A in (`powershell -NoProfile -Command "'{0:N0}' -f ((Get-Item -LiteralPath '%ZIP%').Length/1MB)"`) do set "ZSIZE=%%A"
echo   压缩包: %ZIP%  (%ZSIZE% MB)
echo.

:done
echo ============================================================
echo   完成。把 %OUT% 这个文件夹整个发给对方即可。
echo ============================================================
if "%PAUSE_AT_END%"=="1" pause
exit /b 0

:no_exe
echo [错误] 找不到 %SRC%\GuildMaster.exe
echo        请先在 Godot 里导出（导出路径设为 GuildMaster-Godot-src\GuildMaster.exe）。
goto fail

:no_pck
echo [错误] 找不到 %SRC%\GuildMaster.pck
echo        导出时请关闭「嵌入 PCK」（binary_format/embed_pck=false）。
goto fail

:no_art
echo [错误] 找不到 %SRC%\art\characters
echo        当前导出配置把 art\* 排除在 PCK 之外，art 必须随包发送；请先准备 art 素材。
goto fail

:no_tiles
echo [错误] 找不到 %SRC%\art\images\piece_png
echo        板块图缺失，地图会空白。
goto fail

:no_runtime
echo [错误] 找不到 %SRC%\runtime\python.exe
echo        离线模式需要内置 Python 运行时。
goto fail

:no_rules
echo [错误] 找不到 %SRC%\rules\guild_session.py
echo        离线规则缺失。
goto fail

:fail
if defined PREPARED_EXE if exist "%PREPARED_EXE%" del /q "%PREPARED_EXE%"
echo.
echo [失败] 打包未完成。
if "%PAUSE_AT_END%"=="1" pause
exit /b 1
