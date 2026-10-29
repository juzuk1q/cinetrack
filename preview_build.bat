@echo off
chcp 65001 > nul
echo ========================================================
echo   Локальный веб-сервер CineTrack (Production Web Build)
echo ========================================================
echo.
echo Приложение откроется мгновенно на: http://localhost:8080
echo.
start http://localhost:8080
cd build\web
python -m http.server 8080
pause
