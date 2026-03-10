# Bootloader-Free Root Solution

**Applicable Devices**: Redmi 15 5G (spring / 25057RN09E)

**System Version**: Android 15 (AQ3A.250226.002) / HyperOS 2.0 (OS2.0.208.0.VOUEUXM) / kernel 6.1.138

**Root Solution**: KernelSU v3.1.0 (LKM runtime loading) + ZygiskSU v1.3.2 + LSPosed IT v1.9.2

**Principle**: Exploiting the root execution vulnerability of the `miui.mqsas.IMQSNative` service to load the kernel module at runtime

## Prerequisites

1. **ADB Connected** — USB debugging enabled

2. **Python 3** — Python 3 is required on the PC to run the kernel module patching script

3. **KernelSU Manager** — Installed on the device (`ksu_manager.apk`)

4. **ZygiskSU** — Installed as a KSU module (provides Zygisk environment)

5. **LSPosed** — Installed as a KSU module (`LSPosed-v1.9.2-it-7573-release_1773031523.zip`)

## File Description

| File | Purpose |

|------|------|

| `ksu_oneclick.bat` | **One-click script** — Runs on Windows, automatically completes the entire KernelSU loading process |

| `patch_ksu_module.py` | Python patching tool — Reads runtime kallsyms and patches the SHN_UNDEF symbol in .ko files |

| `android15-6.6_kernelsu.ko` | KernelSU kernel module (requires patching before loading) |

| `kernelsu_patched.ko` | Patched kernel modules (products of the last OneClick run, ready to use) |

| `ksud-aarch64-linux-android` | KernelSU user-space daemon |

| `ksu_manager.apk` | KernelSU Manager App |

| `ksu_step1.sh` | Device-side script — pulls `/proc/kallsyms` |

| `ksu_step2.sh` | Device-side script — insmod + deploy ksud + trigger Manager + remove Magisk compatibility links |

| `fix_lspd.sh` | **LSPosed fix script** — re-injects ZygiskSU + starts lspd + safely reboots the framework |

| `do_chmod.sh` | Helper script — fixes MQSAS output file permissions (`chmod 644 /data/local/tmp/*.txt`) | `LSPosed-v1.9.2-it-7573-release_1773031523.zip` | LSPosed IT Module Installation Package |

## Usage Instructions

### Step 1: KernelSU Loading (Run after each boot from termux)

```
ksu.sh
```
Automatically completes the following 5 steps:

1. Pull `/proc/kallsyms` via mqsas root (KASL address is different each boot)

2. Patch the `.ko` file with Python on the PC (fixes the SHN_UNDEF symbol address)

3. Push the patched `.ko` to the device

4. Load the kernel module by executing `insmod` via mqsas root

5. Deploy ksud, execute the boot phase (`post-fs-data → services → boot-completed`), and trigger Manager recognition

### Step 2: LSPosed Repair (If "Not Loaded" is displayed)

After pushing `fix_lspd.sh` to the device, execute it via MQSAS:

``bat
adb push fix_lspd.sh /data/local/tmp/
adb shell "chmod 755 /data/local/tmp/fix_lspd.sh"
adb shell "service call miui.mqsas.IMQSNative 21 i32 1 s16 '/system/bin/sh' i32 1 s16 '/data/local/tmp/fix_lspd.sh' s16 '/data/local/tmp/lspd_fix_out.txt' i32 180"

```

View the execution result:

``bat
adb shell "service call miui.mqsas.IMQSNative 21 i32 1 s16 'sh' i32 1 s16 `'/data/local/tmp/do_chmod.sh' s16 '/dev/null' i32 5"
timeout /t 3
adb pull /data/local/tmp/lspd_fix_out.txt
type lspd_fix_out.txt

```

This script performs the following tasks:

1. Kills the old lspd process

2. Retrieves the `BOOTCLASSPATH` environment variable from the zygote64 process

3. **Re-injects ZygiskSU** — directly calls `zygiskd daemon` + `zygiskd service-stage`

4. Daemonizes lspd using `setsid` + `nsenter -t 1 -m` (enters the init mount namespace)

5. Kills zygote64, triggering a framework restart

6. **Rattle condition protection** — records the old system_server PID, only searching for the new PID after it dies

7. Waits for the bridge binder to be established (Maximum 60 seconds)

8. If bridge fails, automatically execute **Solution B**: Kill system_server to force the injected zygote to re-fork.

## Working Principle

```

┌─ PC Side ────────────────────────────────────────────────────────┐

│ ksu_oneclick.bat │

│ ├─ adb push script and files │

│ ├─ mqsas root → ksu_step1.sh → pull kallsyms │

│ ├─ patch_ksu_module.py → patch .ko KASLR symbols │

│ ├─ adb push patched .ko │

│ └─ mqsas root → ksu_step2.sh → insmod + ksud + Manager │

│ │

│ fix_lspd.sh (Executes when LSPosed is not loaded) │

│ ├─ zygiskd daemon → Re-inject ZygiskSU into the current zygote │

│ ├─ setsid lspd → Daemonize and start the LSPosed daemon process │

│ ├─ kill zygote64 → Trigger a new zygote with ZygiskSU injection │

│ └─ Wait for bridge binder → Confirm successful loading of the LSPosed framework │

└──────────────────────────────────────────────────────────┘

┌─ Device side ─────────────────────────────────────┐

│ miui.mqsas.IMQSNative service call 21 │

│ → Execute arbitrary shell script as root (uid=0) │

│ → SELinux context: hypsys_ssi_default │

│
│ KernelSU (LKM) │

│ → insmod kernelsu_patched.ko │

│ → ksud post-fs-data / services / boot │

│
│ ZygiskSU (Zygisk Next v1.3.2) │

│ → zygiskd daemon injection into zygote64 │

│ → libzygisk.so loading into the zygote process │

│ → Note: Not using the native_bridge attribute method │

│
│ LSPosed │

│ → lspd (app_process) daemon process │

│ → framework.dex injection into system_server │

│ → Bridge binder connecting modules and services │

└─────────────────────────────────────────────┘

```

## Key Technical Points

- **mqsas root call format**: `service call miui.mqsas.IMQSNative 21 i32 1 s16 'interpreter' i32 1 s16 'script path' s16 'output file' i32 timeout in seconds`

- Execution is **asynchronous** — you need to wait for completion and then pull the output file to view the results.

- Output file permissions are root:system 600, you need to fix them with `do_chmod.sh` before you can use adb pull.

- **KASLR**: Kernel symbol address randomization at each boot, you must pull kallsyms and re-patch it in real time.

- **SELinux**: Requires permissive settings (`u:r:hypsys_ssi_default:s0` context).

- **Mount Namespace**: lspd needs to enter the init namespace with `nsenter -t 1 -m` to access APEX.

- **Magisk** **False Detection**: ksu_step2.sh will delete the `$KSU_DIR/bin/magisk` compatibility symbolic link automatically created by ksud; otherwise, the Manager's `hasMagisk()` will falsely report a conflict, causing all modules to become unusable.

**lspd Liveness**: `se` must be used.


