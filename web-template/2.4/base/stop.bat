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

setLocal EnableDelayedExpansion
set SCRIPTPATH=%~dp0

call %SCRIPTPATH%\env.bat

call %SCRIPTPATH%/ps.bat -silent
set RETURN_CODE=!errorlevel!
if not "!RETURN_CODE!" == "0" (
	echo ##### %INST_NAME% is not running. There is nothing to stop.#######
	goto end_fail
)

if "%1%" == "graceful" (
	goto graceful
) else if "%1%" == "force" (
    goto kill
) else (
    if "%SHUTDOWN_GRACEFUL%" == "true" (
        goto graceful
    ) else (
        goto stop
    )
)

:graceful
call %SCRIPTPATH%\service.bat shutdown
goto end_success

:stop
call %SCRIPTPATH%\service.bat stop
goto end_success

:kill
call %SCRIPTPATH%\kill.bat
goto end_success

:end_success
exit /B 0

:end_fail
exit /B 1
