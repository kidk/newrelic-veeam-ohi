@ECHO OFF

set endpoint=%1
set interval=%2

powershell.exe -NoLogo -ExecutionPolicy Unrestricted -File veeam-stats.ps1 -Endpoint "%endpoint%" -Interval %interval%
