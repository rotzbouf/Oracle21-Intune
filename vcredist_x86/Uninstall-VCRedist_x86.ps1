#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Uninstalls Microsoft Visual C++ 2015-2022 Redistributable (x86) — Intune Win32.

.NOTES
    WARNING: Uninstalling VCRedist while other applications depend on it will break
    those applications. Only uninstall if you are certain no other software needs it.
    Oracle 21c Client (x86) must be uninstalled BEFORE uninstalling this package.
#>

$InstallerName = 'VC_redist.x86.exe'
$ScriptDir     = Split-Path -Parent $MyInvocation.MyCommand.Definition
$Installer     = "$ScriptDir\$InstallerName"
$LogDir        = 'C:\ProgramData\Microsoft\IntuneManagementExtension\Logs'
$LogFile       = "$LogDir\VCRedist_x86_Uninstall.log"

if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }
Start-Transcript -Path $LogFile -Append -Force
$ErrorActionPreference = 'Stop'

function Write-Log {
    param([string]$Message, [string]$Level = 'INFO')
    Write-Output "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')][$Level] $Message"
}

try {
    Write-Log "=== VCRedist 2015-2022 x86 — Uninstall START ==="

    $regPath   = 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\VisualStudio\14.0\VC\Runtimes\x86'
    $installed = (Get-ItemProperty -Path $regPath -ErrorAction SilentlyContinue).Installed
    if ($installed -ne 1) {
        Write-Log "VCRedist x86 not detected as installed. Nothing to do." 'WARN'
        Stop-Transcript; exit 0
    }

    if (-not (Test-Path $Installer)) {
        Write-Log "$InstallerName not found — cannot uninstall without the original exe." 'ERROR'
        Stop-Transcript; exit 1
    }

    Write-Log "Running silent uninstall..."
    $proc = Start-Process -FilePath $Installer `
                          -ArgumentList '/uninstall', '/quiet', '/norestart' `
                          -Wait -PassThru -NoNewWindow
    $exit = $proc.ExitCode
    Write-Log "Exit code: $exit"

    if ($exit -notin @(0, 3010, 1605)) {
        Write-Log "Uninstall FAILED with exit code $exit." 'ERROR'
        Stop-Transcript; exit $exit
    }

    Write-Log "=== VCRedist 2015-2022 x86 — Uninstall COMPLETE ==="
    Stop-Transcript
    if ($exit -eq 3010) { exit 3010 } else { exit 0 }

} catch {
    Write-Log "Unhandled exception: $_" 'ERROR'
    Stop-Transcript; exit 1
}
