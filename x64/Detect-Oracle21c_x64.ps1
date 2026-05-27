<#
.SYNOPSIS
    Detection script for Oracle Database Client 21c (64-bit) — Intune Win32 custom detection.

.DESCRIPTION
    Intune runs this script and interprets the result as follows:
        - Exit code 0  + output written to stdout  = DETECTED (installed)
        - Exit code 0  + no stdout output           = NOT detected
        - Non-zero exit code                        = Script error (treated as not detected)

    Checks:
        1. ORACLE_HOME directory exists
        2. sqlplus.exe exists in ORACLE_HOME\bin\
        3. Registry key for this Oracle Home exists
        4. tnsnames.ora and sqlnet.ora are present in network\admin\
#>

$OracleHome   = 'C:\Oracle\product\21.0.0\client_x64'
$SqlplusExe   = "$OracleHome\bin\sqlplus.exe"
$NetworkAdmin = "$OracleHome\network\admin"
$RegistryPath = 'HKLM:\SOFTWARE\Oracle\KEY_OraClient21Home1_x64'

$allGood = $true
$reasons = @()

# Check 1: Oracle Home directory
if (-not (Test-Path $OracleHome)) {
    $allGood = $false
    $reasons += "Oracle Home not found: $OracleHome"
}

# Check 2: sqlplus.exe binary
if (-not (Test-Path $SqlplusExe)) {
    $allGood = $false
    $reasons += "sqlplus.exe not found: $SqlplusExe"
}

# Check 3: Registry key
if (-not (Test-Path $RegistryPath)) {
    $allGood = $false
    $reasons += "Registry key not found: $RegistryPath"
}

# Check 4: Network config files
foreach ($file in @('tnsnames.ora', 'sqlnet.ora')) {
    if (-not (Test-Path "$NetworkAdmin\$file")) {
        $allGood = $false
        $reasons += "$file not found in $NetworkAdmin"
    }
}

if ($allGood) {
    # Write to stdout — Intune requires output to confirm detection
    Write-Output "Oracle 21c x64 Runtime detected at $OracleHome"
    exit 0
} else {
    # No stdout output = not detected
    # Optionally log why (goes to IME log, not to Intune detection result)
    exit 0
}
