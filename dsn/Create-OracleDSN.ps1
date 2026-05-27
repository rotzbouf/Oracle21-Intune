#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Creates Oracle System DSNs for x64 and/or x86 ODBC drivers — Intune deployment.

.DESCRIPTION
    Creates System DSNs (machine-wide, all users) in the Windows registry.
    System DSNs are stored in HKLM and require no user interaction.

    Designed for deployment as an Intune Platform Script:
        Devices > Scripts > Add > Windows 10 and later
        Run as account        : System
        Run in 64-bit context : Yes  (script handles both 32-bit and 64-bit DSNs internally)

    Or run manually as administrator for testing.

    Prerequisites (must be installed first — via Intune app dependencies):
        - Oracle ODBC Driver 21c (x64)  → for x64 DSNs
        - Oracle ODBC Driver 21c (x86)  → for x86 DSNs

.NOTES
    A System DSN created in the 64-bit registry is visible to 64-bit apps (Excel x64).
    A System DSN created in the 32-bit registry (WOW6432Node) is visible to 32-bit apps (Excel x86).
    On a machine with mixed Office bitness, create both.
#>

# ════════════════════════════════════════════════════════════════════════════════
# ── DSN definitions — EDIT THIS SECTION ─────────────────────────────────────
# ════════════════════════════════════════════════════════════════════════════════
# Add one entry per database. Each entry is a hashtable with:
#   Name        : DSN name as it appears in Excel / Access "get data" dialogs
#   TNSAlias    : The alias from tnsnames.ora  (or a full EZConnect string)
#   Description : Optional description shown in ODBC administrator
#   Create64    : $true to create a 64-bit System DSN (Excel x64, Power BI)
#   Create86    : $true to create a 32-bit System DSN (Excel x86, Access)

$DSNList = @(
    @{
        Name        = 'OracleDB_PROD'
        TNSAlias    = 'PROD'           # must match an alias in tnsnames.ora
        Description = 'Oracle Production Database'
        Create64    = $true
        Create86    = $true
    },
    @{
        Name        = 'OracleDB_TEST'
        TNSAlias    = 'TEST'
        Description = 'Oracle Test Database'
        Create64    = $true
        Create86    = $true
    }
    # Add more entries here as needed:
    # @{ Name = 'OracleDB_DEV'; TNSAlias = 'DEV'; Description = '...'; Create64 = $true; Create86 = $false }
)

# ── Driver names — match the ORACLE_HOME_NAME values in your .rsp files ───────
$DriverName64 = 'Oracle in instantclient_21_x64'
$DriverName86 = 'Oracle in instantclient_21_x86'

# ════════════════════════════════════════════════════════════════════════════════

$LogDir  = 'C:\ProgramData\Microsoft\IntuneManagementExtension\Logs'
$LogFile = "$LogDir\OracleDSN_Create.log"

if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }
Start-Transcript -Path $LogFile -Append -Force
$ErrorActionPreference = 'Stop'

function Write-Log {
    param([string]$Message, [string]$Level = 'INFO')
    Write-Output "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')][$Level] $Message"
}

function New-SystemDSN {
    param(
        [string]$DsnName,
        [string]$DriverName,
        [string]$TnsAlias,
        [string]$Description,
        [string]$OdbcIniRoot    # HKLM:\SOFTWARE\ODBC  or  HKLM:\SOFTWARE\WOW6432Node\ODBC
    )

    # ── Verify driver is installed ────────────────────────────────────────────
    $driverRegPath = "$OdbcIniRoot\ODBCINST.INI\$DriverName"
    if (-not (Test-Path $driverRegPath)) {
        Write-Log "Driver '$DriverName' not found in registry ($driverRegPath). Install the ODBC package first." 'ERROR'
        return $false
    }

    # Read the driver DLL path registered by odbc_install.exe
    $driverDll = (Get-ItemProperty -Path $driverRegPath -ErrorAction Stop).Driver
    if (-not $driverDll) {
        Write-Log "Driver DLL path not found in $driverRegPath." 'ERROR'
        return $false
    }
    Write-Log "Driver DLL : $driverDll"

    # ── Create DSN registry key ───────────────────────────────────────────────
    $dsnPath = "$OdbcIniRoot\ODBC.INI\$DsnName"
    $existed = Test-Path $dsnPath

    New-Item -Path $dsnPath -Force | Out-Null
    Set-ItemProperty -Path $dsnPath -Name 'Driver'      -Value $driverDll
    Set-ItemProperty -Path $dsnPath -Name 'DBQ'         -Value $TnsAlias     # TNS alias or EZConnect string
    Set-ItemProperty -Path $dsnPath -Name 'Description' -Value $Description
    Set-ItemProperty -Path $dsnPath -Name 'DBA'         -Value 'W'           # read/write
    Set-ItemProperty -Path $dsnPath -Name 'APA'         -Value 'T'           # auto-tune performance
    Set-ItemProperty -Path $dsnPath -Name 'RST'         -Value 'T'           # result sets
    Set-ItemProperty -Path $dsnPath -Name 'LOB'         -Value 'T'           # LOB support
    Set-ItemProperty -Path $dsnPath -Name 'NUM'         -Value 'NLS'         # NLS numeric handling
    Set-ItemProperty -Path $dsnPath -Name 'FWC'         -Value 'F'           # force wide char off
    Set-ItemProperty -Path $dsnPath -Name 'QTO'         -Value 'T'           # query timeout
    Set-ItemProperty -Path $dsnPath -Name 'FRL'         -Value 'F'           # fetch with rowlimit

    # ── Register DSN name in the ODBC Data Sources list ──────────────────────
    $sourcesPath = "$OdbcIniRoot\ODBC.INI\ODBC Data Sources"
    if (-not (Test-Path $sourcesPath)) { New-Item -Path $sourcesPath -Force | Out-Null }
    Set-ItemProperty -Path $sourcesPath -Name $DsnName -Value $DriverName

    $action = if ($existed) { 'Updated' } else { 'Created' }
    Write-Log "$action DSN '$DsnName' → TNS alias '$TnsAlias' using driver '$DriverName'"
    return $true
}

# ════════════════════════════════════════════════════════════════════════════════

try {
    Write-Log "=== Oracle DSN Creation START ==="
    Write-Log "DSN entries to process: $($DSNList.Count)"

    $odbcRoot64 = 'HKLM:\SOFTWARE\ODBC'
    $odbcRoot86 = 'HKLM:\SOFTWARE\WOW6432Node\ODBC'

    foreach ($dsn in $DSNList) {
        Write-Log "--- Processing DSN: $($dsn.Name) (TNS: $($dsn.TNSAlias)) ---"

        if ($dsn.Create64) {
            Write-Log "Creating 64-bit System DSN..."
            $ok = New-SystemDSN -DsnName    $dsn.Name `
                                -DriverName $DriverName64 `
                                -TnsAlias   $dsn.TNSAlias `
                                -Description $dsn.Description `
                                -OdbcIniRoot $odbcRoot64
            if (-not $ok) { Write-Log "64-bit DSN '$($dsn.Name)' FAILED." 'WARN' }
        }

        if ($dsn.Create86) {
            Write-Log "Creating 32-bit System DSN..."
            $ok = New-SystemDSN -DsnName    $dsn.Name `
                                -DriverName $DriverName86 `
                                -TnsAlias   $dsn.TNSAlias `
                                -Description $dsn.Description `
                                -OdbcIniRoot $odbcRoot86
            if (-not $ok) { Write-Log "32-bit DSN '$($dsn.Name)' FAILED." 'WARN' }
        }
    }

    Write-Log "=== Oracle DSN Creation COMPLETE ==="
    Stop-Transcript; exit 0

} catch {
    Write-Log "Unhandled exception: $_" 'ERROR'
    Stop-Transcript; exit 1
}
