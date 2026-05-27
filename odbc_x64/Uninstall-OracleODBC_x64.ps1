#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Uninstalls Oracle Instant Client ODBC driver (64-bit) — Intune Win32.
#>

$InstallDir = 'C:\Oracle\instantclient_21_x64'
$LogDir     = 'C:\ProgramData\Microsoft\IntuneManagementExtension\Logs'
$LogFile    = "$LogDir\OracleODBC_x64_Uninstall.log"

if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }
Start-Transcript -Path $LogFile -Append -Force
$ErrorActionPreference = 'Stop'

function Write-Log {
    param([string]$Message, [string]$Level = 'INFO')
    Write-Output "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')][$Level] $Message"
}

try {
    Write-Log "=== Oracle ODBC Driver 21c x64 — Uninstall START ==="

    $odbcUninstall = "$InstallDir\odbc_uninstall.exe"
    $driverKey     = 'HKLM:\SOFTWARE\ODBC\ODBCINST.INI\Oracle in instantclient_21_x64'

    if (-not (Test-Path $InstallDir)) {
        Write-Log "Install directory not found ($InstallDir). Nothing to uninstall." 'WARN'
        Stop-Transcript; exit 0
    }

    # ── Deregister ODBC driver ────────────────────────────────────────────────
    if (Test-Path $odbcUninstall) {
        Write-Log "Running odbc_uninstall.exe ..."
        $proc = Start-Process -FilePath $odbcUninstall `
                              -WorkingDirectory $InstallDir `
                              -Wait -PassThru -NoNewWindow
        Write-Log "odbc_uninstall.exe exit code: $($proc.ExitCode)"
    } elseif (Test-Path $driverKey) {
        Write-Log "odbc_uninstall.exe not found — removing registry key manually." 'WARN'
        Remove-Item -Path $driverKey -Recurse -Force -ErrorAction SilentlyContinue
        $refKey = 'HKLM:\SOFTWARE\ODBC\ODBCINST.INI\ODBC Drivers'
        if (Test-Path $refKey) {
            Remove-ItemProperty -Path $refKey -Name 'Oracle in instantclient_21_x64' -ErrorAction SilentlyContinue
        }
    }

    # ── Remove from PATH ──────────────────────────────────────────────────────
    $currentPath = [System.Environment]::GetEnvironmentVariable('PATH', 'Machine')
    if ($currentPath -like "*$InstallDir*") {
        $newPath = ($currentPath.Split(';') | Where-Object { $_ -ne $InstallDir }) -join ';'
        [System.Environment]::SetEnvironmentVariable('PATH', $newPath, 'Machine')
        Write-Log "Removed $InstallDir from system PATH."
    }

    # ── Remove TNS_ADMIN if it points to this install ─────────────────────────
    $tnsAdmin = [System.Environment]::GetEnvironmentVariable('TNS_ADMIN', 'Machine')
    if ($tnsAdmin -eq $InstallDir) {
        [System.Environment]::SetEnvironmentVariable('TNS_ADMIN', $null, 'Machine')
        Write-Log "Removed TNS_ADMIN environment variable."
    }

    # ── Remove install directory ──────────────────────────────────────────────
    Remove-Item -Path $InstallDir -Recurse -Force -ErrorAction SilentlyContinue
    Write-Log "Removed directory: $InstallDir"

    Write-Log "=== Oracle ODBC Driver 21c x64 — Uninstall COMPLETE ==="
    Stop-Transcript; exit 0

} catch {
    Write-Log "Unhandled exception: $_" 'ERROR'
    Stop-Transcript; exit 1
}
