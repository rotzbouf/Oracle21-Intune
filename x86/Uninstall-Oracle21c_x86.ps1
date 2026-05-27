#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Silently uninstalls Oracle Database Client 21c (32-bit) — used by Intune Win32.

.NOTES
    Oracle's deinstall tool removes the Oracle Home, registry keys, and PATH entries.
    It does NOT remove the ORACLE_BASE folder (C:\Oracle) — remove that manually if needed.
#>

# ── Configuration ────────────────────────────────────────────────────────────
$OracleHome   = 'C:\Oracle\product\21.0.0\client_x86'
$DeinstallExe = "$OracleHome\deinstall\deinstall.bat"
$LogDir       = 'C:\ProgramData\Microsoft\IntuneManagementExtension\Logs'
$LogFile      = "$LogDir\Oracle21c_x86_Uninstall.log"
# ─────────────────────────────────────────────────────────────────────────────

if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }
Start-Transcript -Path $LogFile -Append -Force
$ErrorActionPreference = 'Stop'

function Write-Log {
    param([string]$Message, [string]$Level = 'INFO')
    $ts = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    Write-Output "[$ts][$Level] $Message"
}

try {
    Write-Log "=== Oracle 21c Client x86 - Uninstall Start ==="

    if (-not (Test-Path $OracleHome)) {
        Write-Log "Oracle Home not found ($OracleHome). Nothing to uninstall." 'WARN'
        Stop-Transcript; exit 0
    }

    if (-not (Test-Path $DeinstallExe)) {
        Write-Log "Deinstall tool not found at: $DeinstallExe" 'ERROR'
        Write-Log "Falling back to manual directory removal..." 'WARN'
        Remove-Item -Path $OracleHome -Recurse -Force -ErrorAction SilentlyContinue
        # Remove registry keys (32-bit Oracle on 64-bit OS uses WOW6432Node)
        $regPath32 = 'HKLM:\SOFTWARE\WOW6432Node\Oracle'
        $keyName   = 'KEY_OraClient21Home1_x86'
        if (Test-Path "$regPath32\$keyName") {
            Remove-Item -Path "$regPath32\$keyName" -Recurse -Force -ErrorAction SilentlyContinue
            Write-Log "Removed registry key: $regPath32\$keyName"
        }
        Stop-Transcript; exit 0
    }

    Write-Log "Running Oracle deinstall tool: $DeinstallExe"
    $proc = Start-Process -FilePath 'cmd.exe' `
                          -ArgumentList "/c `"$DeinstallExe`" -silent -home OraClient21Home1_x86" `
                          -Wait `
                          -PassThru `
                          -NoNewWindow
    $exitCode = $proc.ExitCode
    Write-Log "Deinstall exit code: $exitCode"

    # Clean up the Oracle Home directory if it still exists
    if (Test-Path $OracleHome) {
        Write-Log "Oracle Home still present after deinstall, removing manually..." 'WARN'
        Remove-Item -Path $OracleHome -Recurse -Force -ErrorAction SilentlyContinue
    }

    Write-Log "=== Oracle 21c Client x86 - Uninstall COMPLETE ==="
    Stop-Transcript
    exit 0

} catch {
    Write-Log "Unhandled exception: $_" 'ERROR'
    Stop-Transcript
    exit 1
}
