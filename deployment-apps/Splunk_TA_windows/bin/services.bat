@echo off
REM --------------------------------------------------------
REM REM Copyright (C) 2019 Splunk Inc. All Rights Reserved.
REM REM --------------------------------------------------------
wmic service where started=true get  name, startname /format:csv
