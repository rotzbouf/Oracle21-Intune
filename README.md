# Oracle 21c Client + VCRedist — Intune Win32 Deployment

[![License: Unlicense](https://img.shields.io/badge/license-Unlicense-blue.svg)](https://unlicense.org)

Four Win32 packages, fully bundled (.intunewin contains all installer files).

---

## Package overview & dependency chain

```
┌─────────────────────────┐    ┌─────────────────────────┐
│  VCRedist 2015-2022 x64 │    │  VCRedist 2015-2022 x86 │
│  (no dependencies)      │    │  (no dependencies)      │
└────────────┬────────────┘    └────────────┬────────────┘
             │ auto-install                 │ auto-install
             ▼                             ▼
┌─────────────────────────┐    ┌─────────────────────────┐
│  Oracle 21c Client x64  │◄───│  Oracle 21c Client x86  │
│  depends on VCRedist x64│    │  depends on VCRedist x86│
└─────────────────────────┘    │  + Oracle x64           │
                               └─────────────────────────┘
```

**Upload order to Intune:** VCRedist x64 → VCRedist x86 → Oracle x64 → Oracle x86

---

## Repository layout

```
Oracle21_Intune/
│
├── vcredist_x64/
│   ├── VC_redist.x64.exe           ← ADD: your installer
│   ├── Install-VCRedist_x64.ps1
│   ├── Uninstall-VCRedist_x64.ps1
│   └── Detect-VCRedist_x64.ps1
│
├── vcredist_x86/
│   ├── VC_redist.x86.exe           ← ADD: your installer
│   ├── Install-VCRedist_x86.ps1
│   ├── Uninstall-VCRedist_x86.ps1
│   └── Detect-VCRedist_x86.ps1
│
├── x64/
│   ├── setup.exe + Oracle files    ← ADD: full extracted Oracle x64 installer
│   ├── tnsnames.ora                ← ADD: your file
│   ├── sqlnet.ora                  ← ADD: your file
│   ├── client_install_x64.rsp
│   ├── Install-Oracle21c_x64.ps1
│   ├── Uninstall-Oracle21c_x64.ps1
│   └── Detect-Oracle21c_x64.ps1
│
└── x86/
    ├── setup.exe + Oracle files    ← ADD: full extracted Oracle x86 installer
    ├── tnsnames.ora                ← ADD: your file
    ├── sqlnet.ora                  ← ADD: your file
    ├── client_install_x86.rsp
    ├── Install-Oracle21c_x86.ps1
    ├── Uninstall-Oracle21c_x86.ps1
    └── Detect-Oracle21c_x86.ps1
```

---

## Step 1 — Populate the folders

| Folder | What to add |
|--------|------------|
| `vcredist_x64\` | `VC_redist.x64.exe` from Microsoft |
| `vcredist_x86\` | `VC_redist.x86.exe` from Microsoft |
| `x64\` | All extracted Oracle 21c x64 installer files + `tnsnames.ora` + `sqlnet.ora` |
| `x86\` | All extracted Oracle 21c x86 installer files + `tnsnames.ora` + `sqlnet.ora` |

---

## Step 2 — Create the four .intunewin packages

```cmd
IntuneWinAppUtil.exe -c "C:\Build\vcredist_x64" -s "Install-VCRedist_x64.ps1" -o "C:\Build\Output" -q
IntuneWinAppUtil.exe -c "C:\Build\vcredist_x86" -s "Install-VCRedist_x86.ps1" -o "C:\Build\Output" -q
IntuneWinAppUtil.exe -c "C:\Build\x64"          -s "Install-Oracle21c_x64.ps1" -o "C:\Build\Output" -q
IntuneWinAppUtil.exe -c "C:\Build\x86"          -s "Install-Oracle21c_x86.ps1" -o "C:\Build\Output" -q
```

Expected output sizes:
| Package | Approximate .intunewin size |
|---------|----------------------------|
| VCRedist x64 | ~15 MB |
| VCRedist x86 | ~10 MB |
| Oracle x64 | ~500–700 MB |
| Oracle x86 | ~500–700 MB |

---

## Step 3 — Configure each app in Intune

Go to **Intune > Apps > Windows > Add > Windows app (Win32)**. Upload in the order below.

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
| **Detection script** | `Detect-VCRedist_x64.ps1` |
| **Run as 32-bit** | **No** |
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
| **Detection script** | `Detect-VCRedist_x86.ps1` |
| **Run as 32-bit** | **Yes** |
| **Dependencies** | — |

---

### App 3 — Oracle 21c Client (x64)

| Setting | Value |
|---------|-------|
| **Name** | Oracle 21c Client (x64) |
| **Install command** | `powershell.exe -ExecutionPolicy Bypass -File Install-Oracle21c_x64.ps1` |
| **Uninstall command** | `powershell.exe -ExecutionPolicy Bypass -File Uninstall-Oracle21c_x64.ps1` |
| **Install behaviour** | System |
| **Max install time** | **120 min** ⚠️ |
| **OS architecture** | 64-bit |
| **Min OS** | Windows 10 1909 |
| **Detection script** | `Detect-Oracle21c_x64.ps1` |
| **Run as 32-bit** | **No** |
| **Dependencies** | VCRedist 2015-2022 (x64) — Auto Install: Yes |

---

### App 4 — Oracle 21c Client (x86)

| Setting | Value |
|---------|-------|
| **Name** | Oracle 21c Client (x86) |
| **Install command** | `powershell.exe -ExecutionPolicy Bypass -File Install-Oracle21c_x86.ps1` |
| **Uninstall command** | `powershell.exe -ExecutionPolicy Bypass -File Uninstall-Oracle21c_x86.ps1` |
| **Install behaviour** | System |
| **Max install time** | **120 min** ⚠️ |
| **OS architecture** | 32-bit or 64-bit |
| **Min OS** | Windows 10 1909 |
| **Detection script** | `Detect-Oracle21c_x86.ps1` |
| **Run as 32-bit** | **Yes** |
| **Dependencies** | VCRedist 2015-2022 (x86) — Auto Install: Yes |
|  | Oracle 21c Client (x64) — Auto Install: Yes |

> ⚠️ **120 minutes for Oracle** — Oracle extraction + OUI on slow hardware can exceed
> the default 60-minute timeout. Intune reports failure while the install is still running.

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
1. Check installer exe is present in package
2. Run /install /quiet /norestart
3. Handle exit codes: 0=OK, 3010=OK+reboot, 1638=already newer installed
4. Verify via registry (Installed=1) + DLL present
```

### Oracle packages
```
1. Pre-flight: verify setup.exe and .rsp are present
2. Skip if sqlplus.exe already exists (idempotent)
3. OUI silent install: -silent -waitforcompletion -ignorePrereq
4. Post-install verify: sqlplus.exe exists
5. Create ORACLE_HOME\network\admin\ if missing
6. Copy tnsnames.ora + sqlnet.ora into network\admin\
7. Add ORACLE_HOME\bin to system PATH (x64 only)
```

---

## Install results on the client

| | VCRedist x64 | VCRedist x86 |
|--|---|---|
| Registry | `HKLM\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64` | `HKLM\SOFTWARE\WOW6432Node\Microsoft\VisualStudio\14.0\VC\Runtimes\x86` |
| Key DLL | `C:\Windows\System32\msvcp140.dll` | `C:\Windows\SysWOW64\msvcp140.dll` |

| | Oracle x64 | Oracle x86 |
|--|---|---|
| Oracle Home | `C:\Oracle\product\21.0.0\client_x64` | `C:\Oracle\product\21.0.0\client_x86` |
| network\admin | `…\client_x64\network\admin\` | `…\client_x86\network\admin\` |
| Registry | `HKLM\SOFTWARE\Oracle\KEY_OraClient21Home1_x64` | `HKLM\SOFTWARE\WOW6432Node\Oracle\KEY_OraClient21Home1_x86` |
| in PATH | `client_x64\bin` ✔ | not added (intentional) |

---

## Log files on the client

```
C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\
    VCRedist_x64_Install.log
    VCRedist_x64_Uninstall.log
    VCRedist_x86_Install.log
    VCRedist_x86_Uninstall.log
    Oracle21c_x64_Install.log
    Oracle21c_x64_Uninstall.log
    Oracle21c_x86_Install.log
    Oracle21c_x86_Uninstall.log
```

Oracle OUI own logs (installer-level failures): `C:\Oracle\cfgtoollogs\`

---

## TNS_ADMIN — when x64 and x86 coexist on the same machine

ODBC drivers pick up TNS files based on bitness. To guarantee both use the same file:

1. Change `$NetworkAdmin` in **both** Oracle install scripts to `C:\Oracle\network\admin`
2. Uncomment the `TNS_ADMIN` block in both scripts
3. Put a single copy of `tnsnames.ora` / `sqlnet.ora` in both `x64\` and `x86\` package folders —
   they will both copy to `C:\Oracle\network\admin\` and overwrite each other harmlessly
   (they are identical files).
