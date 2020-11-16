@ECHO OFF

:: ######################################################
:: #
:: # Splunk for Microsoft Active Directory
:: # 
:: # Copyright (C) 2016 Splunk, Inc.
:: # All Rights Reserved
:: #
:: ######################################################

set SplunkApp=Splunk_TA_microsoft_ad

powershell.exe  -command "C:\Program*\SplunkUniversalForwarder\etc\apps\TA-microsoft_ad_inputs\bin\powershell\nt6-health.ps1"