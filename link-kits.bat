@echo off
rem Links each kit's Libs\KitDock folder to this KitDock folder (a directory
rem junction, no admin rights needed), so every kit loads this one copy.
rem Run it once from the KitDock folder that sits next to the kit folders.
setlocal
set "DOCK=%~dp0"
set "DOCK=%DOCK:~0,-1%"
for %%K in (FirstAidKit CampingKit FishingKit WarlockKit) do (
  if exist "%DOCK%\..\%%K\" (
    if not exist "%DOCK%\..\%%K\Libs\" mkdir "%DOCK%\..\%%K\Libs"
    if exist "%DOCK%\..\%%K\Libs\KitDock\" (
      echo %%K: already linked
    ) else (
      mklink /J "%DOCK%\..\%%K\Libs\KitDock" "%DOCK%"
    )
  ) else (
    echo %%K: not found next to KitDock, skipped
  )
)
pause
