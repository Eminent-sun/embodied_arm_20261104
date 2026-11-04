@echo off
cd /d "%~dp0"
echo Support the arm, turn OFF motor and servo power, and close the old ARM console before running this file.
python software\tools\download_gripper.py --download
if errorlevel 1 exit /b 1
pause
