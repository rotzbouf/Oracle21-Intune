<#
.SYNOPSIS
    Detection script for Oracle ODBC Driver 21c (x64) — Intune Win32 custom detection.

.DESCRIPTION
    Checks:
      1. Install directory exists with oci.dll
      2. ODBC driver is registered in the system registry
      3. tnsnames.ora is present

    Intune: output to stdout = detected. No output = not detected.
    Run as 32-bit process on 64-bit clients: No
#>

$InstallDir = 'C:\Oracle\instantclient_21_x64'
$driverKey  = 'HKLM:\SOFTWARE\ODBC\ODBCINST.INI\Oracle in instantclient_21_x64'

$ok = (Test-Path "$InstallDir\oci.dll") -and
      (Test-Path $driverKey) -and
      (Test-Path "$InstallDir\tnsnames.ora")

if ($ok) {
    Write-Output "Oracle ODBC Driver 21c x64 detected at $InstallDir"
    exit 0
} else {
    exit 0   # no output = not detected
}
