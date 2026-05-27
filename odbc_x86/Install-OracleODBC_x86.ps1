#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Installs Oracle Instant Client 21c + ODBC driver (32-bit) — Intune Win32 deployment.

.DESCRIPTION
    Extracts and registers the Oracle 32-bit ODBC driver for use by 32-bit applications
    (Excel 32-bit, Access, 32-bit ODBC data sources, legacy line-of-business apps, etc.)

    No Oracle Universal Installer (OUI) is used — extraction + odbc_install.exe only.

    Package folder layout:
        instantclient-basic-nt-21.*.zip    ← Oracle Instant Client Basic x86 (nt = 32-bit)
        instantclient-odbc-nt-21.*.zip     ← Oracle Instant Client ODBC x86
        tnsnames.ora                       ← your file
        sqlnet.ora                         ← your file
        Install-OracleODBC_x86.ps1  (this file)
        Uninstall-OracleODBC_x86.ps1
        Detect-OracleODBC_x86.ps1

    Download the two ZIPs (free, no login required) from:
        https://www.oracle.com/database/technologies/instant-client/microsoft-windows-32-downloads.html
        → "Basic Package"  : instantclient-basic-nt-21.x.x.x.zip
        → "ODBC Package"   : instantclient-odbc-nt-21.x.x.x.zip

    Intune Win32 app settings:
        Name             : Oracle ODBC Driver 21c (x86)
        Install command  : powershell.exe -ExecutionPolicy Bypass -File Install-OracleODBC_x86.ps1
        Uninstall command: powershell.exe -ExecutionPolicy Bypass -File Uninstall-OracleODBC_x86.ps1
        Install behaviour: System
        Detection        : Custom script — Detect-OracleODBC_x86.ps1  /  Run as 32-bit: Yes
        Max install time : 30 minutes
        Dependencies     : VCRedist 2015-2022 (x86) — Auto Install: Yes
#>

# ── Configuration ─────────────────────────────────────────────────────────────
$InstallDir   = 'C:\Oracle\instantclient_21_x86'   # fixed install path on client
$TnsAdmin     = $InstallDir                         # tnsnames.ora lives here
$ScriptDir    = Split-Path -Parent $MyInvocation.MyCommand.Definition
$LogDir       = 'C:\ProgramData\Microsoft\IntuneManagementExtension\Logs'
$LogFile      = "$LogDir\OracleODBC_x86_Install.log"
$TempDir      = "$env:SystemRoot\Temp\OracleODBC_x86_Extract"
# ─────────────────────────────────────────────────────────────────────────────

if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }
Start-Transcript -Path $LogFile -Append -Force
$ErrorActionPreference = 'Stop'

function Write-Log {
    param([string]$Message, [string]$Level = 'INFO')
    Write-Output "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')][$Level] $Message"
}

function Expand-ZipTo {
    param([string]$ZipPath, [string]$Destination)
    $tempExtract = "$TempDir\_zip_$(Split-Path -Leaf $ZipPath)"
    New-Item -ItemType Directory -Path $tempExtract -Force | Out-Null
    Expand-Archive -Path $ZipPath -DestinationPath $tempExtract -Force

    $icRoot = Get-ChildItem -Path $tempExtract -Directory | Select-Object -First 1
    if (-not $icRoot) { $icRoot = Get-Item $tempExtract }
    Copy-Item -Path "$($icRoot.FullName)\*" -Destination $Destination -Recurse -Force
    Remove-Item $tempExtract -Recurse -Force
    Write-Log "Extracted $(Split-Path -Leaf $ZipPath) -> $Destination"
}

try {
    Write-Log "=== Oracle ODBC Driver 21c x86 — Install START ==="

    # ── Find ZIPs in package folder ───────────────────────────────────────────
    $basicZip = Get-ChildItem -Path $ScriptDir -Filter 'instantclient-basic-nt-21*.zip' |
                Select-Object -First 1
    $odbcZip  = Get-ChildItem -Path $ScriptDir -Filter 'instantclient-odbc-nt-21*.zip' |
                Select-Object -First 1

    if (-not $basicZip) {
        Write-Log "Basic ZIP not found in $ScriptDir (pattern: instantclient-basic-nt-21*.zip)" 'ERROR'
        Stop-Transcript; exit 1
    }
    if (-not $odbcZip) {
        Write-Log "ODBC ZIP not found in $ScriptDir (pattern: instantclient-odbc-nt-21*.zip)" 'ERROR'
        Stop-Transcript; exit 1
    }
    Write-Log "Basic ZIP : $($basicZip.Name) ($([math]::Round($basicZip.Length/1MB,1)) MB)"
    Write-Log "ODBC ZIP  : $($odbcZip.Name)  ($([math]::Round($odbcZip.Length/1MB,1)) MB)"

    # ── Already installed? ────────────────────────────────────────────────────
    # 32-bit ODBC drivers on 64-bit Windows are under WOW6432Node
    $driverKey = 'HKLM:\SOFTWARE\WOW6432Node\ODBC\ODBCINST.INI\Oracle in instantclient_21_x86'
    if (Test-Path $driverKey) {
        Write-Log "ODBC driver already registered. Skipping extraction — updating tnsnames/sqlnet only." 'WARN'
    } else {

        # ── Prepare dirs ──────────────────────────────────────────────────────
        New-Item -ItemType Directory -Path $TempDir    -Force | Out-Null
        New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null

        # ── Extract Basic, then ODBC (merge into same folder) ─────────────────
        Write-Log "Extracting Instant Client files to $InstallDir ..."
        Expand-ZipTo -ZipPath $basicZip.FullName -Destination $InstallDir
        Expand-ZipTo -ZipPath $odbcZip.FullName  -Destination $InstallDir

        # ── Verify odbc_install.exe ───────────────────────────────────────────
        $odbcInstall = "$InstallDir\odbc_install.exe"
        if (-not (Test-Path $odbcInstall)) {
            Write-Log "odbc_install.exe not found in $InstallDir — ODBC ZIP may be missing or corrupt." 'ERROR'
            Stop-Transcript; exit 1
        }

        # ── Register the ODBC driver ──────────────────────────────────────────
        Write-Log "Registering ODBC driver via odbc_install.exe ..."
        $proc = Start-Process -FilePath $odbcInstall `
                              -WorkingDirectory $InstallDir `
                              -Wait -PassThru -NoNewWindow
        $exit = $proc.ExitCode
        Write-Log "odbc_install.exe exit code: $exit"
        if ($exit -ne 0) {
            Write-Log "ODBC driver registration FAILED (exit $exit)." 'ERROR'
            Stop-Transcript; exit $exit
        }

        Remove-Item $TempDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    # ── Verify ───────────────────────────────────────────────────────────────
    if (-not (Test-Path $driverKey)) {
        Write-Log "Post-install check FAILED: ODBC driver key not found in registry." 'ERROR'
        Stop-Transcript; exit 1
    }
    Write-Log "Post-install check OK: ODBC driver registered."

    # ── Deploy tnsnames.ora and sqlnet.ora ────────────────────────────────────
    foreach ($src in @("$ScriptDir\tnsnames.ora", "$ScriptDir\sqlnet.ora")) {
        $name = Split-Path -Leaf $src
        if (Test-Path $src) {
            Copy-Item -Path $src -Destination "$InstallDir\$name" -Force
            Write-Log "Deployed: $name -> $InstallDir"
        } else {
            Write-Log "$name not found in package — skipping." 'WARN'
        }
    }

    # ── Add InstallDir to system PATH (required for 32-bit DLL resolution) ────
    $currentPath = [System.Environment]::GetEnvironmentVariable('PATH', 'Machine')
    if ($currentPath -notlike "*$InstallDir*") {
        [System.Environment]::SetEnvironmentVariable('PATH', "$InstallDir;$currentPath", 'Machine')
        Write-Log "Added to system PATH: $InstallDir"
    }

    # ── Set TNS_ADMIN ─────────────────────────────────────────────────────────
    # NOTE: if both x64 and x86 ODBC drivers are installed on the same machine,
    # TNS_ADMIN will be overwritten by whichever package installs last.
    # In that case, point both to a single shared folder (see README — TNS_ADMIN note).
    [System.Environment]::SetEnvironmentVariable('TNS_ADMIN', $TnsAdmin, 'Machine')
    Write-Log "Set TNS_ADMIN = $TnsAdmin"

    Write-Log "=== Oracle ODBC Driver 21c x86 — Install SUCCESSFUL ==="
    Stop-Transcript; exit 0

} catch {
    Write-Log "Unhandled exception: $_" 'ERROR'
    Remove-Item $TempDir -Recurse -Force -ErrorAction SilentlyContinue
    Stop-Transcript; exit 1
}
