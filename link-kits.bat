@echo off
rem Links each kit's Libs\KitDock folder to this KitDock folder (a directory
rem junction, no admin rights needed), so every kit loads this one copy.
rem Run it once from the KitDock folder that sits next to the kit folders.
rem Any folder next to this one whose .toc loads KitDock.lua is linked, so a
rem new kit needs no change here.
setlocal
set "DOCK=%~dp0"
set "DOCK=%DOCK:~0,-1%"
set "FOUND="
for /d %%K in ("%DOCK%\..\*") do call :link "%%~fK" "%%~nxK"
if not defined FOUND echo No kits next to KitDock load it.
pause
exit /b

:link
if /i "%~2"=="KitDock" exit /b
findstr /m /i /l /c:"KitDock.lua" "%~1\*.toc" >nul 2>&1 || exit /b
set "FOUND=1"
if not exist "%~1\Libs\" mkdir "%~1\Libs"
if exist "%~1\Libs\KitDock\" (
  echo %~2: already linked
) else (
  mklink /J "%~1\Libs\KitDock" "%DOCK%"
)
exit /b
