@echo off
chcp 65001 >nul
cd /d "%~dp0"
python tools/project.py data
if errorlevel 1 goto failed
python tools/project.py graphs
if errorlevel 1 goto failed
godot --headless --language en --path . --editor --quit
if errorlevel 1 goto failed
python tools/project.py assets
if errorlevel 1 goto failed
python tools/project.py run
if errorlevel 1 goto failed
exit /b 0
:failed
pause
exit /b 1
