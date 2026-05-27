#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Installs Oracle Database Client 21c (64-bit / Runtime) — Intune Win32 bundled deployment.

.DESCRIPTION
    All files travel inside the .intunewin package:
        setup.exe + Oracle installer files  ← extracted Oracle x64 installer
        client_install_x64.rsp              ← silent install response file
        tnsnames.ora                        ← your custom file
        sqlnet.ora                          ← your custom file
        Install-Oracle21c_x64.ps1  (this file)
        Uninstall-Oracle21c_x64.ps1
        Detect-Oracle21c_x64.ps1

    Intune Win32 app settings:
        Install command   : powershell.exe -ExecutionPolicy Bypass -File Install-Oracle21c_x64.ps1
        Uninstall command : powershell.exe -ExecutionPolicy Bypass -File Uninstall-Oracle21c_x64.ps1
        Install behaviour : System
        Detection         : Custom script — Detect-Oracle21c_x64.ps1  /  Run as 32-bit: No
        Max install time  : 120 minutes  ← increase from the default 60 min
#>

# ── Configuration — adjust only if you change paths ──────────────────────────
$OracleHome     = 'C:\Oracle\product\21.0.0\client_x64'
$NetworkAdmin   = "$OracleHome\network\admin"
$ScriptDir      = Split-Path -Parent $MyInvocation.MyCommand.Definition
$ResponseFile   = "$ScriptDir\client_install_x64.rsp"
$SetupExe       = "$ScriptDir\setup.exe"
$TnsNamesSource = "$ScriptDir\tnsnames.ora"
$SqlnetSource   = "$ScriptDir\sqlnet.ora"
$LogDir         = 'C:\ProgramData\Microsoft\IntuneManagementExtension\Logs'
$LogFile        = "$LogDir\Oracle21c_x64_Install.log"
# ─────────────────────────────────────────────────────────────────────────────

if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }
Start-Transcript -Path $LogFile -Append -Force
$ErrorActionPreference = 'Stop'

function Write-Log {
    param([string]$Message, [string]$Level = 'INFO')
    Write-Output "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')][$Level] $Message"
}

try {
    Write-Log "=== Oracle 21c Client x64 — Install START ==="
    Write-Log "Script dir  : $ScriptDir"
    Write-Log "Oracle Home : $OracleHome"

    # ── Pre-flight ────────────────────────────────────────────────────────────
    foreach ($required in @($SetupExe, $ResponseFile)) {
        if (-not (Test-Path $required)) {
            Write-Log "Required file missing: $required" 'ERROR'
            Stop-Transcript; exit 1
        }
    }

    # ── Already installed? ────────────────────────────────────────────────────
    if (Test-Path "$OracleHome\bin\sqlplus.exe") {
        Write-Log "Oracle x64 already installed — skipping setup.exe, updating .ora files only." 'WARN'
    } else {

        # ── Silent install ────────────────────────────────────────────────────
        Write-Log "Running Oracle OUI silent install..."
        $proc = Start-Process -FilePath $SetupExe `
                              -ArgumentList '-silent', '-waitforcompletion', '-ignorePrereq', `
                                            "-responseFile `"$ResponseFile`"" `
                              -Wait -PassThru -NoNewWindow
        $exit = $proc.ExitCode
        Write-Log "Installer exit code: $exit"

        # 0 = success | 6 = prereq warning bypassed (still OK with -ignorePrereq)
        if ($exit -notin @(0, 6)) {
            Write-Log "Installation FAILED (exit $exit). OUI logs: C:\Oracle\cfgtoollogs\" 'ERROR'
            Stop-Transcript; exit $exit
        }

        # ── Verify ────────────────────────────────────────────────────────────
        if (-not (Test-Path "$OracleHome\bin\sqlplus.exe")) {
            Write-Log "Post-install check FAILED: sqlplus.exe not found." 'ERROR'
            Stop-Transcript; exit 1
        }
        Write-Log "Post-install check OK."
    }

    # ── Deploy tnsnames.ora and sqlnet.ora ────────────────────────────────────
    if (-not (Test-Path $NetworkAdmin)) {
        New-Item -ItemType Directory -Path $NetworkAdmin -Force | Out-Null
        Write-Log "Created: $NetworkAdmin"
    }
    foreach ($src in @($TnsNamesSource, $SqlnetSource)) {
        $name = Split-Path -Leaf $src
        if (Test-Path $src) {
            Copy-Item -Path $src -Destination "$NetworkAdmin\$name" -Force
            Write-Log "Deployed: $name -> $NetworkAdmin"
        } else {
            Write-Log "$name not found in package — skipping." 'WARN'
        }
    }

    # ── System PATH ───────────────────────────────────────────────────────────
    $oracleBin   = "$OracleHome\bin"
    $currentPath = [System.Environment]::GetEnvironmentVariable('PATH', 'Machine')
    if ($currentPath -notlike "*$oracleBin*") {
        [System.Environment]::SetEnvironmentVariable('PATH', "$oracleBin;$currentPath", 'Machine')
        Write-Log "Added to system PATH: $oracleBin"
    }

    # ── TNS_ADMIN (optional — uncomment if needed) ────────────────────────────
    # Useful when both x64 and x86 are installed; point both to the same folder.
    # [System.Environment]::SetEnvironmentVariable('TNS_ADMIN', $NetworkAdmin, 'Machine')
    # Write-Log "Set TNS_ADMIN = $NetworkAdmin"

    Write-Log "=== Oracle 21c Client x64 — Install SUCCESSFUL ==="
    Stop-Transcript; exit 0

} catch {
    Write-Log "Unhandled exception: $_" 'ERROR'
    Stop-Transcript; exit 1
}
