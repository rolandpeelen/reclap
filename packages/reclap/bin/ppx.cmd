@echo off
REM The reclap PPX on Windows. postinstall.js replaces this script with
REM bin\ppx.exe; this fallback serves installs that skip install scripts.
if exist "%~dp0..\_build\default\ppx\bin\reclap_ppx.exe" (
  "%~dp0..\_build\default\ppx\bin\reclap_ppx.exe" %*
  exit /b %ERRORLEVEL%
)
if not exist "%~dp0ppx-windows.exe" (
  echo reclap: no prebuilt PPX found in %~dp0. Build it from source with OCaml 5 and dune: cd node_modules\@rolandpeelen\reclap ^&^& dune build 1>&2
  exit /b 1
)
"%~dp0ppx-windows.exe" %*
exit /b %ERRORLEVEL%
