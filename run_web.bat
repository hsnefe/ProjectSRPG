@echo off
cd /d "%~dp0"
call flutter\bin\flutter.bat run -d web-server --web-port 5050 --web-hostname 127.0.0.1
