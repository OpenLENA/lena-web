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

call %SCRIPTPATH%\..\service.bat configtest

exit /B 0