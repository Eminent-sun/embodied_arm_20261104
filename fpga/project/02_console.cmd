@echo off
cd /d "%~dp0"
python software\tools\workflow_console.py --connect --id2-positive
pause
