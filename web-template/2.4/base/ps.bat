@echo off
setLocal EnableDelayedExpansion
set SCRIPTPATH=%~dp0
call %SCRIPTPATH%\env.bat
set _INSTALL_PATH=%INSTALL_PATH:\=\\%

if not "%1%" == "-silent" (
	goto verbose
) else (
	goto silent
)

:verbose
wmic process get name, ProcessID, Commandline /format:list | findstr %_INSTALL_PATH% | findstr httpd
set ERROR_LEVEL=%errorlevel%
 	
:silent
wmic process get name, ProcessID, Commandline /format:list | findstr %_INSTALL_PATH% | findstr httpd > NUL
set ERROR_LEVEL=%errorlevel%

:end
exit /B %ERROR_LEVEL%


:end_success
exit /B 0

:end_fail
exit /B 1