@echo off

rem Copyright 2021 LENA Development Team.
rem
rem Licensed under the Apache License, Version 2.0 (the "License");
rem you may not use this file except in compliance with
rem the License. You may obtain a copy of the License at
rem
rem http://www.apache.org/licenses/LICENSE-2.0
rem
rem Unless required by applicable law or agreed to in writing, software
rem distributed under the License is distributed on an "AS IS" BASIS,
rem WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
rem See the License for the specific language governing permissions and
rem limitations under the License.

setLocal EnableDelayedExpansion
set SCRIPTPATH=%~dp0

call %SCRIPTPATH%\env.bat

call %SCRIPTPATH%/ps.bat -silent
set RETURN_CODE=!errorlevel!
if "!RETURN_CODE!"=="0" (
	echo ##### ERROR. %INST_NAME% is already running. exiting.. ##### 1>&2
	goto end_fail
)

set "_log_dirs=access error jk"
for %%a in (%_log_dirs%) do (
  IF not exist "!LOG_HOME!\%%a" (
  	mkdir "!LOG_HOME!\%%a"
  )
)

set DATETIME=
for /F "usebackq tokens=1,2 delims==" %%i in (`wmic os get LocalDateTime /VALUE 2^>NUL`) do if '.%%i.'=='.LocalDateTime.' set DATETIME=%%j
set DATETIME=%DATETIME:~0,4%%DATETIME:~4,2%%DATETIME:~6,2%

for /f "delims=" %%i in (' dir /b %LOG_HOME%  ^| findstr /I "error_%INST_NAME%_*" ^| findstr /v %DATETIME% ') do (
  move %LOG_HOME%\%%i %LOG_HOME%\error 
)
for /f "delims=" %%i in (' dir /b %LOG_HOME%  ^| findstr /I "access_%INST_NAME%_*" ^| findstr /v %DATETIME% ') do (
  move %LOG_HOME%\%%i %LOG_HOME%\access
)
for /f "delims=" %%i in (' dir /b %LOG_HOME%  ^| findstr /I "jk_%INST_NAME%_*" ^| findstr /v %DATETIME% ') do (
  move %LOG_HOME%\%%i %LOG_HOME%\jk 
)

if "%1" == "staging" ( 
	call %INSTALL_PATH%/service.bat staging
) else (
  call %INSTALL_PATH%/service.bat start
)

:end_success
exit /B 0

:end_fail
exit /B 1
