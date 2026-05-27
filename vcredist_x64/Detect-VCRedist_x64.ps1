<#
.SYNOPSIS
    Detection script for VCRedist 2015-2022 (x64) — Intune Win32 custom detection.

.DESCRIPTION
    Checks:
      1. Registry key exists with Installed = 1
      2. The runtime DLL exists in System32

    Intune: output to stdout = detected. No output = not detected.
    Run as 32-bit process on 64-bit clients: No
#>

$regPath  = 'HKLM:\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64'
$dll      = 'C:\Windows\System32\msvcp140.dll'
$detected = $false

$prop = Get-ItemProperty -Path $regPath -ErrorAction SilentlyContinue
if ($prop -and $prop.Installed -eq 1 -and (Test-Path $dll)) {
    $detected = $true
    $version  = $prop.Version
}

if ($detected) {
    Write-Output "VCRedist 2015-2022 x64 detected (version: $version)"
    exit 0
} else {
    exit 0   # no output = not detected
}
