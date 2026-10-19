@echo off
setlocal
chcp 65001 >nul
set PYTHONUTF8=1
pushd "%~dp0"
python -X utf8 tools/defense_pipeline.py build %*
set "T8_TABLE_RESULT=%ERRORLEVEL%"
if "%T8_TABLE_RESULT%"=="0" (
  echo.
  echo Export complete. Restart the project game to load the updated data.
) else (
  echo.
  echo Export failed. Existing runtime data was not overwritten.
  echo If a dependency is missing: python -m pip install -r tools/requirements-tables.txt
)
popd
if not defined T8_TABLE_NO_PAUSE pause
exit /b %T8_TABLE_RESULT%
