@echo off
setlocal
cd /d "%~dp0"

where py >nul 2>nul
if not errorlevel 1 (
  start "" "http://localhost:8080"
  py -m http.server 8080
  exit /b
)

where python >nul 2>nul
if not errorlevel 1 (
  start "" "http://localhost:8080"
  python -m http.server 8080
  exit /b
)

echo Python n'est pas installe. Envoyez les fichiers sur l'hebergement pour tester,
echo ou installez Python puis relancez ce fichier.
pause

