@echo off
rem Leuchtturm-Abgleich starten (Fenster offen lassen, solange ihr spielt)
cd /d "%~dp0"
where py >nul 2>nul
if %errorlevel%==0 (py -3 leuchtturm_sync.py) else (python leuchtturm_sync.py)
pause
