@ECHO OFF

SET SplunkApp=TA-Exchange-ClientAccess_input
SET SPLUNK_HOME=C:\Program Files\SplunkUniversalForwarder


IF %1 EQU v8.0 ( GOTO ExchangeVersion2007 
) ELSE ( GOTO ExchangeVersionOth)

:ExchangeVersion2007
FOR /F "tokens=2* delims=	 " %%A IN ('REG QUERY "HKLM\Software\Microsoft\Exchange\%1\Setup" /v MsiInstallPath') DO SET Exchangepath=%%B
Powershell -PSConsoleFile "%Exchangeinstallpath%\Bin\exshell.psc1" -command ". '%SPLUNK_HOME%\etc\apps\%SplunkApp%\bin\powershell\%2'"
goto:eof

:ExchangeVersionOth
FOR /F "tokens=2* delims=	 " %%A IN ('REG QUERY "HKLM\Software\Microsoft\ExchangeServer\%1\Setup" /v MsiInstallPath') DO SET Exchangepath=%%B
Powershell -PSConsoleFile "%Exchangeinstallpath%\bin\exshell.psc1" -command ". '%SPLUNK_HOME%\etc\apps\%SplunkApp%\bin\powershell\%2'"
goto:eof
