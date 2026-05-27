<#
.SYNOPSIS
    Detection script for Oracle ODBC Driver 21c (x86) — Intune Win32 custom detection.

.DESCRIPTION
    Checks:
      1. Install directory exists with oci.dll
      2. ODBC driver is registered under WOW6432Node (32-bit drivers on 64-bit Windows)
      3. tnsnames.ora is present

    Intune: output to stdout = detected. No output = not detected.
    Run as 32-bit process on 64-bit clients: Yes
#>

$InstallDir = 'C:\Oracle\instantclient_21_x86'
$driverKey  = 'HKLM:\SOFTWARE\WOW6432Node\ODBC\ODBCINST.INI\Oracle in instantclient_21_x86'

$ok = (Test-Path "$InstallDir\oci.dll") -and
      (Test-Path $driverKey) -and
      (Test-Path "$InstallDir\tnsnames.ora")

if ($ok) {
    Write-Output "Oracle ODBC Driver 21c x86 detected at $InstallDir"
    exit 0
} else {
    exit 0   # no output = not detected
}
