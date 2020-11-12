@ECHO OFF

:: ######################################################
:: #
:: # Splunk for Microsoft Active Directory
:: # 
:: # Copyright (C) 2016 Splunk, Inc.
:: # All Rights Reserved
:: #
:: ######################################################

set SplunkApp=Splunk_TA_microsoft_dns

powershell.exe -command "C:\Program*\SplunkUniversalForwarder\etc\apps\TA_microsoft_dns_input\bin\powershell\dns-health.ps1"
