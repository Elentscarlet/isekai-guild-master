@echo off
setlocal EnableExtensions
python -B "%~dp0tools\build_server_package.py" %*
exit /b %errorlevel%
