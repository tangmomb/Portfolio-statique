@echo off
setlocal
cd /d "%~dp0"

echo Generation des fichiers JSON depuis update.xlsx...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\generate-json.ps1"

if errorlevel 1 (
  echo.
  echo ERREUR : les fichiers JSON n'ont pas ete generes.
  pause
  exit /b 1
)

echo.
echo Termine. Vous pouvez envoyer le dossier data sur votre hebergement.
pause

