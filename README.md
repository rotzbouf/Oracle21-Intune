# Oracle 21c Client + VCRedist — Intune Win32 Deployment

[![License: Unlicense](https://img.shields.io/badge/license-Unlicense-blue.svg)](https://unlicense.org)

Six Win32 packages for deploying Oracle 21c connectivity to Windows clients via Intune.
Choose the packages that match your use case — ODBC-only for Excel/Access, full client for SQL*Plus/OCI/JDBC.

---

## Which packages do you need?

| Use case | Packages to deploy |
|----------|--------------------|
| Excel / Access / ODBC apps only | VCRedist + **Oracle ODBC** |
| SQL\*Plus, OCI, JDBC, full Oracle tooling | VCRedist + **Oracle Client** |
| Both ODBC apps and full tooling on the same machine | VCRedist + Oracle ODBC + Oracle Client |

> **ODBC packages are much lighter** (~25–40 MB .intunewin vs ~500–700 MB for the full client).
> Use them wherever the full client is not strictly needed.

---

## Package overview & dependency chain

```
┌─────────────────────────┐         ┌─────────────────────────┐
│  VCRedist 2015-2022 x64 │         │  VCRedist 2015-2022 x86 │
│  (no dependencies)      │         │  (no dependencies)      │
└────────────┬────────────┘         └──────────┬──────────────┘
             │ auto-install                    │ auto-install
     ┌───────┴────────┐               ┌────────┴────────┐
     ▼                ▼               ▼                 ▼
┌──────────────┐ ┌──────────────┐ ┌──────────────┐ ┌───────────────────────┐
│ Oracle ODBC  │ │Oracle Client │ │ Oracle ODBC  │ │   Oracle Client x86   │
│    x64       │ │    x64       │ │    x86       │ │ deps: VCRedist x86    │
│ (Excel x64,  │ │ (SQL*Plus,   │ │ (Excel x86,  │ │       + Oracle Cli x64│
│  Power BI)   │ │  OCI, JDBC)  │ │  Access)     │ └───────────────────────┘
└──────────────┘ └──────────────┘ └──────────────┘
```

**Upload order to Intune:**
VCRedist x64 → VCRedist x86 → Oracle ODBC x64 → Oracle ODBC x86 → Oracle Client x64 → Oracle Client x86

---

## Repository layout

```
Oracle21_Intune/
│
├── vcredist_x64/
│   ├── VC_redist.x64.exe               ← ADD: Microsoft VC++ 2015-2022 x64
│   ├── Install-VCRedist_x64.ps1
│   ├── Uninstall-VCRedist_x64.ps1
│   └── Detect-VCRedist_x64.ps1
│
├── vcredist_x86/
│   ├── VC_redist.x86.exe               ← ADD: Microsoft VC++ 2015-2022 x86
│   ├── Install-VCRedist_x86.ps1
│   ├── Uninstall-VCRedist_x86.ps1
│   └── Detect-VCRedist_x86.ps1
│
├── odbc_x64/
│   ├── instantclient-basic-windows.x64-21.*.zip  ← ADD: Oracle download
│   ├── instantclient-odbc-windows.x64-21.*.zip   ← ADD: Oracle download
│   ├── tnsnames.ora                    ← ADD: your file
│   ├── sqlnet.ora                      ← ADD: your file
│   ├── Install-OracleODBC_x64.ps1
│   ├── Uninstall-OracleODBC_x64.ps1
│   └── Detect-OracleODBC_x64.ps1
│
├── odbc_x86/
│   ├── instantclient-basic-nt-21.*.zip           ← ADD: Oracle download
│   ├── instantclient-odbc-nt-21.*.zip            ← ADD: Oracle download
│   ├── tnsnames.ora                    ← ADD: your file
│   ├── sqlnet.ora                      ← ADD: your file
│   ├── Install-OracleODBC_x86.ps1
│   ├── Uninstall-OracleODBC_x86.ps1
│   └── Detect-OracleODBC_x86.ps1
│
├── x64/
│   ├── setup.exe + Oracle installer files  ← ADD: extracted Oracle Client x64
│   ├── tnsnames.ora                    ← ADD: your file
│   ├── sqlnet.ora                      ← ADD: your file
│   ├── client_install_x64.rsp
│   ├── Install-Oracle21c_x64.ps1
│   ├── Uninstall-Oracle21c_x64.ps1
│   └── Detect-Oracle21c_x64.ps1
│
├── x86/
│   ├── setup.exe + Oracle installer files  ← ADD: extracted Oracle Client x86
│   ├── tnsnames.ora                    ← ADD: your file
│   ├── sqlnet.ora                      ← ADD: your file
│   ├── client_install_x86.rsp
│   ├── Install-Oracle21c_x86.ps1
│   ├── Uninstall-Oracle21c_x86.ps1
│   └── Detect-Oracle21c_x86.ps1
│
└── dsn/
    └── Create-OracleDSN.ps1            ← configure DSN names + TNS aliases, deploy as Intune platform script
```

---

## Step 1 — Download and populate the folders

### VCRedist installers
Download from [Microsoft Visual C++ Redistributable latest](https://learn.microsoft.com/en-us/cpp/windows/latest-supported-vc-redist):

| File | Destination |
|------|------------|
| `VC_redist.x64.exe` | `vcredist_x64\` |
| `VC_redist.x86.exe` | `vcredist_x86\` |

### Oracle Instant Client ZIPs (for ODBC packages)
Download from Oracle — **free, no login required**:

| File | Download page | Destination |
|------|--------------|------------|
| `instantclient-basic-windows.x64-21.*.zip` | [Windows x64](https://www.oracle.com/database/technologies/instant-client/winx64-64-downloads.html) → Basic | `odbc_x64\` |
| `instantclient-odbc-windows.x64-21.*.zip` | [Windows x64](https://www.oracle.com/database/technologies/instant-client/winx64-64-downloads.html) → ODBC | `odbc_x64\` |
| `instantclient-basic-nt-21.*.zip` | [Windows x86](https://www.oracle.com/database/technologies/instant-client/microsoft-windows-32-downloads.html) → Basic | `odbc_x86\` |
| `instantclient-odbc-nt-21.*.zip` | [Windows x86](https://www.oracle.com/database/technologies/instant-client/microsoft-windows-32-downloads.html) → ODBC | `odbc_x86\` |

### Oracle full client installers (for Client packages)
Place the fully extracted Oracle 21c installer content into `x64\` and `x86\`.

### tnsnames.ora and sqlnet.ora
Copy your files into **every** package folder that needs them:
`odbc_x64\`, `odbc_x86\`, `x64\`, `x86\`

---

## Step 2 — Create the .intunewin packages

Download [Microsoft Win32 Content Prep Tool](https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool).

```cmd
IntuneWinAppUtil.exe -c "C:\Build\vcredist_x64" -s "Install-VCRedist_x64.ps1"    -o "C:\Build\Output" -q
IntuneWinAppUtil.exe -c "C:\Build\vcredist_x86" -s "Install-VCRedist_x86.ps1"    -o "C:\Build\Output" -q
IntuneWinAppUtil.exe -c "C:\Build\odbc_x64"     -s "Install-OracleODBC_x64.ps1"  -o "C:\Build\Output" -q
IntuneWinAppUtil.exe -c "C:\Build\odbc_x86"     -s "Install-OracleODBC_x86.ps1"  -o "C:\Build\Output" -q
IntuneWinAppUtil.exe -c "C:\Build\x64"          -s "Install-Oracle21c_x64.ps1"   -o "C:\Build\Output" -q
IntuneWinAppUtil.exe -c "C:\Build\x86"          -s "Install-Oracle21c_x86.ps1"   -o "C:\Build\Output" -q
```

| Package | Approximate .intunewin size |
|---------|-----------------------------|
| VCRedist x64 | ~15 MB |
| VCRedist x86 | ~10 MB |
| Oracle ODBC x64 | ~25–40 MB |
| Oracle ODBC x86 | ~25–40 MB |
| Oracle Client x64 | ~500–700 MB |
| Oracle Client x86 | ~500–700 MB |

---

## Step 3 — Configure each app in Intune

Go to **Intune > Apps > Windows > Add > Windows app (Win32)**.
Upload in the order listed below so dependencies are available before they are referenced.

---

### App 1 — VCRedist 2015-2022 (x64)

| Setting | Value |
|---------|-------|
| **Name** | VCRedist 2015-2022 (x64) |
| **Install command** | `powershell.exe -ExecutionPolicy Bypass -File Install-VCRedist_x64.ps1` |
| **Uninstall command** | `powershell.exe -ExecutionPolicy Bypass -File Uninstall-VCRedist_x64.ps1` |
| **Install behaviour** | System |
| **Max install time** | 30 min |
| **OS architecture** | 64-bit |
| **Min OS** | Windows 10 1909 |
| **Detection script** | `Detect-VCRedist_x64.ps1` / Run as 32-bit: **No** |
| **Dependencies** | — |

---

### App 2 — VCRedist 2015-2022 (x86)

| Setting | Value |
|---------|-------|
| **Name** | VCRedist 2015-2022 (x86) |
| **Install command** | `powershell.exe -ExecutionPolicy Bypass -File Install-VCRedist_x86.ps1` |
| **Uninstall command** | `powershell.exe -ExecutionPolicy Bypass -File Uninstall-VCRedist_x86.ps1` |
| **Install behaviour** | System |
| **Max install time** | 30 min |
| **OS architecture** | 32-bit or 64-bit |
| **Min OS** | Windows 10 1909 |
| **Detection script** | `Detect-VCRedist_x86.ps1` / Run as 32-bit: **Yes** |
| **Dependencies** | — |

---

### App 3 — Oracle ODBC Driver 21c (x64)

> For **64-bit applications**: Excel 64-bit, Power BI Desktop, 64-bit ODBC data sources.

| Setting | Value |
|---------|-------|
| **Name** | Oracle ODBC Driver 21c (x64) |
| **Install command** | `powershell.exe -ExecutionPolicy Bypass -File Install-OracleODBC_x64.ps1` |
| **Uninstall command** | `powershell.exe -ExecutionPolicy Bypass -File Uninstall-OracleODBC_x64.ps1` |
| **Install behaviour** | System |
| **Max install time** | 30 min |
| **OS architecture** | 64-bit |
| **Min OS** | Windows 10 1909 |
| **Detection script** | `Detect-OracleODBC_x64.ps1` / Run as 32-bit: **No** |
| **Dependencies** | VCRedist 2015-2022 (x64) — Auto Install: Yes |

---

### App 4 — Oracle ODBC Driver 21c (x86)

> For **32-bit applications**: Excel 32-bit, Access, legacy line-of-business apps.

| Setting | Value |
|---------|-------|
| **Name** | Oracle ODBC Driver 21c (x86) |
| **Install command** | `powershell.exe -ExecutionPolicy Bypass -File Install-OracleODBC_x86.ps1` |
| **Uninstall command** | `powershell.exe -ExecutionPolicy Bypass -File Uninstall-OracleODBC_x86.ps1` |
| **Install behaviour** | System |
| **Max install time** | 30 min |
| **OS architecture** | 32-bit or 64-bit |
| **Min OS** | Windows 10 1909 |
| **Detection script** | `Detect-OracleODBC_x86.ps1` / Run as 32-bit: **Yes** |
| **Dependencies** | VCRedist 2015-2022 (x86) — Auto Install: Yes |

---

### App 5 — Oracle 21c Client (x64)

> Full client: SQL\*Plus, OCI, JDBC, ODP.NET. Skip if ODBC-only is sufficient.

| Setting | Value |
|---------|-------|
| **Name** | Oracle 21c Client (x64) |
| **Install command** | `powershell.exe -ExecutionPolicy Bypass -File Install-Oracle21c_x64.ps1` |
| **Uninstall command** | `powershell.exe -ExecutionPolicy Bypass -File Uninstall-Oracle21c_x64.ps1` |
| **Install behaviour** | System |
| **Max install time** | **120 min** ⚠️ |
| **OS architecture** | 64-bit |
| **Min OS** | Windows 10 1909 |
| **Detection script** | `Detect-Oracle21c_x64.ps1` / Run as 32-bit: **No** |
| **Dependencies** | VCRedist 2015-2022 (x64) — Auto Install: Yes |

---

### App 6 — Oracle 21c Client (x86)

> Full 32-bit client. Skip if ODBC-only is sufficient.

| Setting | Value |
|---------|-------|
| **Name** | Oracle 21c Client (x86) |
| **Install command** | `powershell.exe -ExecutionPolicy Bypass -File Install-Oracle21c_x86.ps1` |
| **Uninstall command** | `powershell.exe -ExecutionPolicy Bypass -File Uninstall-Oracle21c_x86.ps1` |
| **Install behaviour** | System |
| **Max install time** | **120 min** ⚠️ |
| **OS architecture** | 32-bit or 64-bit |
| **Min OS** | Windows 10 1909 |
| **Detection script** | `Detect-Oracle21c_x86.ps1` / Run as 32-bit: **Yes** |
| **Dependencies** | VCRedist 2015-2022 (x86) — Auto Install: Yes |
|  | Oracle 21c Client (x64) — Auto Install: Yes |

> ⚠️ **120 minutes for Oracle Client** — Oracle extraction + OUI on slow hardware can exceed
> the default 60-minute timeout. Intune will report failure while the install is still running.

---

## Return codes — add to every app

| Code | Type |
|------|------|
| 0 | Success |
| 1707 | Success |
| 3010 | Soft reboot required |
| 1641 | Hard reboot required |
| 1618 | Retry |

---

## What the scripts do on the client

### VCRedist packages
```
1. Verify installer exe is present in package
2. Run /install /quiet /norestart
3. Handle exit codes: 0=OK  3010=OK+reboot  1638=newer version already installed
4. Verify via registry (Installed=1) + runtime DLL present
```

### Oracle ODBC packages (Instant Client)
```
1. Find Basic and ODBC ZIPs in package folder (by wildcard pattern)
2. Skip extraction if ODBC driver already registered (idempotent)
3. Extract Basic ZIP → C:\Oracle\instantclient_21_x64 (or x86)
4. Extract ODBC ZIP  → same folder (merges in ODBC files + odbc_install.exe)
5. Run odbc_install.exe from the install directory to register the driver
6. Copy tnsnames.ora + sqlnet.ora into the install directory
7. Add install directory to system PATH (needed for DLL resolution)
8. Set TNS_ADMIN system environment variable
```

### Oracle Client packages (full Runtime)
```
1. Verify setup.exe and .rsp file are present
2. Skip if sqlplus.exe already exists (idempotent)
3. OUI silent install: -silent -waitforcompletion -ignorePrereq
4. Post-install verify: sqlplus.exe exists
5. Create ORACLE_HOME\network\admin\ if missing
6. Copy tnsnames.ora + sqlnet.ora into network\admin\
7. Add ORACLE_HOME\bin to system PATH (x64 only)
```

---

## Install results on the client

### VCRedist

| | x64 | x86 |
|--|-----|-----|
| **Registry** | `HKLM\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64` | `HKLM\SOFTWARE\WOW6432Node\Microsoft\VisualStudio\14.0\VC\Runtimes\x86` |
| **Key DLL** | `C:\Windows\System32\msvcp140.dll` | `C:\Windows\SysWOW64\msvcp140.dll` |

### Oracle ODBC (Instant Client)

| | x64 | x86 |
|--|-----|-----|
| **Install dir** | `C:\Oracle\instantclient_21_x64\` | `C:\Oracle\instantclient_21_x86\` |
| **ODBC registry** | `HKLM\SOFTWARE\ODBC\ODBCINST.INI\`<br>`Oracle in instantclient_21_x64` | `HKLM\SOFTWARE\WOW6432Node\ODBC\ODBCINST.INI\`<br>`Oracle in instantclient_21_x86` |
| **tnsnames.ora** | `C:\Oracle\instantclient_21_x64\tnsnames.ora` | `C:\Oracle\instantclient_21_x86\tnsnames.ora` |
| **TNS_ADMIN** | set to install dir | set to install dir |
| **In system PATH** | install dir added ✔ | install dir added ✔ |

### Oracle Client (full Runtime)

| | x64 | x86 |
|--|-----|-----|
| **Oracle Home** | `C:\Oracle\product\21.0.0\client_x64` | `C:\Oracle\product\21.0.0\client_x86` |
| **network\admin** | `…\client_x64\network\admin\` | `…\client_x86\network\admin\` |
| **Registry** | `HKLM\SOFTWARE\Oracle\`<br>`KEY_OraClient21Home1_x64` | `HKLM\SOFTWARE\WOW6432Node\Oracle\`<br>`KEY_OraClient21Home1_x86` |
| **In system PATH** | `client_x64\bin` added ✔ | not added (intentional) |

---

## Log files on the client

All transcript logs are written to:
```
C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\
    VCRedist_x64_Install.log        VCRedist_x64_Uninstall.log
    VCRedist_x86_Install.log        VCRedist_x86_Uninstall.log
    OracleODBC_x64_Install.log      OracleODBC_x64_Uninstall.log
    OracleODBC_x86_Install.log      OracleODBC_x86_Uninstall.log
    Oracle21c_x64_Install.log       Oracle21c_x64_Uninstall.log
    Oracle21c_x86_Install.log       Oracle21c_x86_Uninstall.log
```

Oracle OUI logs (full client installer failures): `C:\Oracle\cfgtoollogs\`

---

## TNS_ADMIN — machines with multiple Oracle packages

### ODBC-only machines (both x64 and x86 ODBC)
Each ODBC package sets `TNS_ADMIN` to its own install directory. The last package
to install wins. To avoid ambiguity, point both to a shared folder:

1. Edit `$TnsAdmin` in **both** ODBC install scripts to `C:\Oracle\network\admin`
2. Create that folder in both ODBC package source folders and place your `.ora` files there
3. Both scripts will then deploy to and read from the same location

### Full client machines (x64 + x86 client)
ODBC drivers and Oracle tools pick up TNS files based on bitness. To guarantee both use the same file:

1. Change `$NetworkAdmin` in **both** Oracle Client install scripts to `C:\Oracle\network\admin`
2. Uncomment the `TNS_ADMIN` block in both scripts
3. Place identical `tnsnames.ora` / `sqlnet.ora` in both `x64\` and `x86\` package folders —
   both will deploy to `C:\Oracle\network\admin\` (overwriting each other harmlessly)

### Machines with both ODBC and full Client packages
Use a single shared `TNS_ADMIN = C:\Oracle\network\admin` across all four Oracle packages
so every Oracle component reads from the same place regardless of bitness or package type.

---

## Creating Oracle ODBC DSNs

After the ODBC driver is installed, applications connect to Oracle databases through
a **DSN (Data Source Name)** — a named connection profile stored in the Windows registry.
DSNs appear by name in Excel's "Get Data" dialog, Access linked tables, and any ODBC-aware app.

### System DSN vs User DSN

Always use **System DSNs** for Intune/enterprise deployments:

| | System DSN | User DSN |
|--|-----------|---------|
| **Registry location** | `HKLM` (all users) | `HKCU` (current user only) |
| **Created by** | SYSTEM context script ✔ | Requires user session |
| **Visible to all users** | ✔ | ✗ |
| **Survives user change** | ✔ | ✗ |

### ⚠️ The 32-bit vs 64-bit ODBC administrator pitfall

There are **two separate ODBC administrators** on every 64-bit Windows machine.
Opening the wrong one will show a completely different set of drivers and DSNs.

| Executable | Manages | Use for |
|-----------|---------|---------|
| `C:\Windows\System32\odbcad32.exe` | 64-bit drivers & DSNs | Excel x64, Power BI |
| `C:\Windows\SysWOW64\odbcad32.exe` | 32-bit drivers & DSNs | Excel x86, Access |

> The **Control Panel shortcut** and the Windows Search result both open the **64-bit** one.
> To reach the 32-bit administrator, run `C:\Windows\SysWOW64\odbcad32.exe` explicitly.

The registry locations mirror this split:

| Bitness | DSN registry path |
|---------|------------------|
| 64-bit System DSN | `HKLM\SOFTWARE\ODBC\ODBC.INI\<DSN_NAME>` |
| 32-bit System DSN | `HKLM\SOFTWARE\WOW6432Node\ODBC\ODBC.INI\<DSN_NAME>` |

---

### Creating DSNs manually (testing / one-off)

1. Open the correct ODBC administrator (see table above)
2. **System DSN** tab → **Add**
3. Select `Oracle in instantclient_21_x64` (or `x86`) → **Finish**
4. Fill in:
   | Field | Value |
   |-------|-------|
   | Data Source Name | e.g. `OracleDB_PROD` |
   | Description | optional |
   | TNS Service Name | the alias from `tnsnames.ora`, e.g. `PROD` |
   | User ID | leave blank to prompt at connect time |
5. Click **Test Connection** to verify → **OK**

---

### Creating DSNs automatically via Intune

Use `dsn/Create-OracleDSN.ps1` in this repository. It creates System DSNs for any number
of databases in a single run, for both 64-bit and 32-bit drivers simultaneously.

**Configuration** — edit the `$DSNList` block at the top of the script:

```powershell
$DSNList = @(
    @{
        Name        = 'OracleDB_PROD'   # appears in Excel "Get Data" dialog
        TNSAlias    = 'PROD'            # must match an alias in tnsnames.ora
        Description = 'Oracle Production Database'
        Create64    = $true             # create 64-bit DSN (Excel x64, Power BI)
        Create86    = $true             # create 32-bit DSN (Excel x86, Access)
    },
    @{
        Name        = 'OracleDB_TEST'
        TNSAlias    = 'TEST'
        Description = 'Oracle Test Database'
        Create64    = $true
        Create86    = $true
    }
)
```

**Deploy as an Intune Platform Script:**

`Devices > Scripts > Add > Windows 10 and later`

| Setting | Value |
|---------|-------|
| Script file | `Create-OracleDSN.ps1` |
| Run this script using the logged on credentials | **No** (run as System) |
| Run script in 64-bit PowerShell host | **Yes** |
| Enforce script signature check | No |

> **Dependency:** Assign this script to the same device group **after** the ODBC driver
> apps are installed. Use a filter or a delay group tag if needed, or deploy it as a
> Win32 app with the ODBC packages set as dependencies.

**Log file:** `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\OracleDSN_Create.log`

---

### DSN-less connections (alternative)

For applications that support it, skip the DSN entirely and use an inline connection string.
This is useful for Power Query / Excel Power Pivot, Python (`cx_Oracle`), and .NET apps.

**EZConnect format** (no `tnsnames.ora` needed):
```
Driver={Oracle in instantclient_21_x64};DBQ=hostname:1521/SERVICENAME;UID=myuser;PWD=mypassword;
```

**TNS alias format** (requires `tnsnames.ora` + `TNS_ADMIN`):
```
Driver={Oracle in instantclient_21_x64};DBQ=PROD;UID=myuser;PWD=mypassword;
```

**Excel "Get Data" → ODBC → Advanced options** connection string (no DSN required):
```
Driver={Oracle in instantclient_21_x64};DBQ=hostname:1521/SERVICENAME;
```

> Use `Oracle in instantclient_21_x86` for 32-bit Excel. The driver name must exactly
> match what is registered — verify it in `odbcad32.exe` under Drivers tab.
