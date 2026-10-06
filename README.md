# Marble Time-To-Full Fix

A KernelSU module for **Xiaomi marble** that fixes the incorrect charging time estimate caused by a minutes-to-seconds mismatch in the battery Health reporting path.

On affected builds, the fuel gauge reports `time_to_full_now` in **minutes**, while Android's Health HAL expects the value in **seconds**. This can cause the lockscreen to display absurd charging ETAs such as 1–2 minutes or some 20 hours.

The module converts the reported value before it is exposed to Android.

# How It Works

```text
     charger
        ↓
time_to_full_now
        ↓
minutes → seconds
        ↓
Android Health
        ↓
     SystemUI
        ↓
 69hours remaining
```

# Requirements

- Xiaomi **marble** / compatible device
- KernelSU
- A ROM where `time_to_full_now` is exposed and is giving same conversion error

# Installation

1. Download the latest module()[https://github.com/sakthibalank-f/Film-Diary/releases/download/v1.2/XIMI_Marble_TimeToFull_Fix_KSU_v1.2.zip] ZIP from **Releases**.
2. Open KernelSU Manager.
3. Install the ZIP as a module.
4. Reboot.
5. Connect your charger and check the charging ETA on the lockscreen.

# Configuration

The module includes a `settings` file:

```sh
MULT=60
CAP=21600
INTERVAL=5
```
## CAP

Maximum accepted converted ETA in seconds.

Values above the limit are treated as unknown,I have set charging time above 6h obsolete.

## INTERVAL

How frequently the module updates the value while charging.

Default:

```text
5 seconds
```

# Important

This module **does not control charging**.

It only modifies the **reported charging time estimate**.

# Compatibility / Disclaimer

This module was developed and tested for **Xiaomi marble in A17**.

It is **not guaranteed to work correctly on other devices if it uses different logic**.

If you encounter issues, disable the module through KernelSU and reboot.

# Author

**Sakthi**
