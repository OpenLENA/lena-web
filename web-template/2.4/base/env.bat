@echo off

rem Copyright 2022 LA:T Development Team.
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

set SCRIPTPATH=%~dp0

set LAT_HOME=C:\engn001\lat\1.2
set ENGN_HOME=C:\engn001\lat\1.2\modules\lat-web-pe
set SERVER_ID=latw_80
set SERVICE_PORT=80
set RUN_USER=%username%
set WIN_SERVICE_NAME=lat-%SERVER_ID%
set SHUTDOWN_GRACEFUL=false
FOR /F %%i IN ('hostname') DO SET HOSTNAME=%%i

set /a HTTPS_SERVICE_PORT=%SERVICE_PORT%+363
set /a STAGING_SERVICE_PORT=%SERVICE_PORT%+10000
set /a STAGING_HTTPS_SERVICE_PORT=%HTTPS_SERVICE_PORT%+10000

set INSTALL_PATH=%SCRIPTPATH%
set DOC_ROOT=%INSTALL_PATH%\htdocs
set LOG_HOME=%INSTALL_PATH%\logs
set LOG_MAX_DAYS=0
set MPM_TYPE=MPM_WINNT
set GRACEFUL_SHUTDOWN_TIMEOUT=0
set INST_NAME=%SERVER_ID%_%HOSTNAME%
set TRACE_ENABLED=false
set DATETIME=
for /F "usebackq tokens=1,2 delims==" %%i in (`wmic os get LocalDateTime /VALUE 2^>NUL`) do if '.%%i.'=='.LocalDateTime.' set DATETIME=%%j
set DATETIME=%DATETIME:~0,4%-%DATETIME:~4,2%-%DATETIME:~6,2%_%DATETIME:~8,2%-%DATETIME:~10,2%-%DATETIME:~12,2%

rem ## Server custom settings
if exist "%INSTALL_PATH%\bin\customenv.bat" call "%INSTALL_PATH%\bin\customenv.bat"
