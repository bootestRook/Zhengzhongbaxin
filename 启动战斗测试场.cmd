@echo off
chcp 65001 >nul
cd /d "%~dp0"
python -X utf8 tools/battle_lab.py run
if errorlevel 1 pause
