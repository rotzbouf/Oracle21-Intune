#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Installs Microsoft Visual C++ 2015-2022 Redistributable (x64) — Intune Win32 deployment.

.DESCRIPTION
    Silent install of VC_redist.x64.exe bundled in the .intunewin package.
    Safe to run when already installed — the installer detects a newer or equal
    version and exits cleanly with code 1638.

    Package folder layout:
        VC_redist.x64.exe           ← Microsoft VC++ 2015-2022 x64 installer
        Install-VCRedist_x64.ps1    (this file)
        Uninstall-VCRedist_x64.ps1
        Detect-VCRedist_x64.ps1

    Intune Win32 app settings:
        Name             : VCRedist 2015-2022 (x64)
        Install command  : powershell.exe -ExecutionPolicy Bypass -File Install-VCRedist_x64.ps1
        Uninstall command: powershell.exe -ExecutionPolicy Bypass -File Uninstall-VCRedist_x64.ps1
        Install behaviour: System
        Detection        : Custom script — Detect-VCRedist_x64.ps1  /  Run as 32-bit: No
        Max install time : 30 minutes
        Dependencies     : none
#>

# ── Configuration ─────────────────────────────────────────────────────────────
$InstallerName = 'VC_redist.x64.exe'
$ScriptDir     = Split-Path -Parent $MyInvocation.MyCommand.Definition
$Installer     = "$ScriptDir\$InstallerName"
$LogDir        = 'C:\ProgramData\Microsoft\IntuneManagementExtension\Logs'
$LogFile       = "$LogDir\VCRedist_x64_Install.log"
# ─────────────────────────────────────────────────────────────────────────────

if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }
Start-Transcript -Path $LogFile -Append -Force
$ErrorActionPreference = 'Stop'

function Write-Log {
    param([string]$Message, [string]$Level = 'INFO')
    Write-Output "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')][$Level] $Message"
}

try {
    Write-Log "=== VCRedist 2015-2022 x64 — Install START ==="

    # ── Pre-flight ─────────────────────────────────────────────────────────────
    if (-not (Test-Path $Installer)) {
        Write-Log "$InstallerName not found at: $Installer" 'ERROR'
        Stop-Transcript; exit 1
    }
    Write-Log "Installer : $Installer"
    Write-Log "Size      : $([math]::Round((Get-Item $Installer).Length / 1MB, 1)) MB"

    # ── Run installer ──────────────────────────────────────────────────────────
    Write-Log "Running silent install..."
    $proc = Start-Process -FilePath $Installer `
                          -ArgumentList '/install', '/quiet', '/norestart' `
                          -Wait -PassThru -NoNewWindow
    $exit = $proc.ExitCode
    Write-Log "Exit code: $exit"

    switch ($exit) {
        0    { Write-Log "Installation successful." }
        3010 { Write-Log "Installation successful — reboot required (Intune will handle)." }
        1638 { Write-Log "A newer or equal version is already installed. No action needed." }
        1641 { Write-Log "Installation successful — reboot initiated." }
        default {
            Write-Log "Installation FAILED with exit code $exit." 'ERROR'
            Stop-Transcript; exit $exit
        }
    }

    # ── Verify ─────────────────────────────────────────────────────────────────
    $regPath = 'HKLM:\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64'
    $installed = (Get-ItemProperty -Path $regPath -ErrorAction SilentlyContinue).Installed
    if ($installed -ne 1) {
        Write-Log "Post-install check FAILED: registry key not found or Installed != 1." 'ERROR'
        Stop-Transcript; exit 1
    }
    $version = (Get-ItemProperty -Path $regPath -ErrorAction SilentlyContinue).Version
    Write-Log "Post-install check OK — installed version: $version"

    Write-Log "=== VCRedist 2015-2022 x64 — Install SUCCESSFUL ==="
    Stop-Transcript

    # Return 3010 to Intune if a reboot is pending, 0 otherwise
    if ($exit -eq 3010) { exit 3010 } else { exit 0 }

} catch {
    Write-Log "Unhandled exception: $_" 'ERROR'
    Stop-Transcript; exit 1
}
