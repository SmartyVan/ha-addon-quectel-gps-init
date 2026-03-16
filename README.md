# GPS Init — Home Assistant Add-on

A minimal Home Assistant OS add-on that initializes a Quectel EG25-G Mini PCIe modem for **GPS-only mode** (no cellular). Designed for the Arduino Pro 4G GNSS Module (TPX00200) in a Seeed Studio Raspberry Pi CM5 edge computer.

## What It Does

On every boot, this add-on sends AT commands to the modem to:

1. **Disable the cellular radio** (`AT+CFUN=4`) — puts the modem in airplane mode so it draws less power and doesn't attempt to register on any network
2. **Set NMEA output to USB** (`AT+QGPSCFG="outport","usbnmea"`) — ensures GPS sentences are sent to `/dev/ttyUSB1` (saved to NVRAM, persists across reboots)
3. **Enable GPS auto-start** (`AT+QGPSCFG="autogps",1`) — the modem will automatically start its GNSS engine on power-on (saved to NVRAM, persists across reboots)
4. **Start GNSS now** (`AT+QGPS=1`) — begins GPS acquisition immediately

After initialization the add-on idles. It must run every boot because `AT+CFUN=4` does not persist across power cycles.

## USB Port Mapping

The Quectel EG25-G exposes three USB serial ports:

| Port | Function | Used By |
|------|----------|---------|
| `/dev/ttyUSB0` | DM (diagnostic) | — |
| `/dev/ttyUSB1` | NMEA (GPS sentences) | gpsd add-on |
| `/dev/ttyUSB2` | AT commands | This add-on |

## Prerequisites

- Home Assistant OS (tested on Raspberry Pi CM5 / aarch64)
- Quectel EG25-G based Mini PCIe module installed and recognized by the kernel (`option` driver)
- SSH or Samba access to the HA machine for copying files

## Installation

### 1. Copy the add-on to your HA machine

Using Samba (recommended):

1. Enable the **Samba share** add-on in HA if not already active
2. Connect to `\\homeassistant\addons` (or `smb://homeassistant/addons` on Mac)
3. Copy the entire `gps-init/` folder into the `addons` share

Using SSH/SCP:

```bash
scp -r gps-init/ root@homeassistant.local:/addons/gps-init/
```

### 2. Install the add-on

1. In Home Assistant, go to **Settings → Add-ons**
2. Click the **Add-on Store** button (bottom right)
3. Click the three-dot menu (top right) → **Check for updates**
4. The **GPS Init** add-on should appear under **Local add-ons**
5. Click it and press **Install**

### 3. Configure (optional)

The default AT command port is `/dev/ttyUSB2`. If your modem enumerates differently, go to the add-on's **Configuration** tab and change the `at_port` value.

> **Tip:** For stability, you can use `/dev/serial/by-id/...` paths instead of `/dev/ttyUSBx`, since USB port numbers can shift if other devices are plugged in. Check available paths with `ls /dev/serial/by-id/` via SSH.

### 4. Start the add-on

1. Go to the add-on's **Info** tab
2. Enable **Start on boot** (should already be on)
3. Click **Start**
4. Check the **Log** tab — you should see `OK` responses for each AT command

## Setting Up the GPS Pipeline

This add-on is step 1 of a 3-part pipeline:

```
gps-init          →  gpsd add-on        →  HA GPSD integration
(this add-on)        (leo-stan)             (built-in)
Sends AT cmds        Reads NMEA from        Exposes lat/lon as
to /dev/ttyUSB2      /dev/ttyUSB1           HA sensor entities
```

### Step 2: Install the gpsd add-on

1. Go to **Settings → Add-ons → Add-on Store** → three-dot menu → **Repositories**
2. Add: `https://github.com/leo-stan/ha-addon-gpsd`
3. Install the **GSPD** add-on
4. Configure it to use `/dev/ttyUSB1` as the GPS device
5. Start it — it should begin reading NMEA sentences

### Step 3: Enable the GPSD integration

1. Go to **Settings → Devices & Services → Add Integration**
2. Search for **GPSD**
3. Host: `localhost`, Port: `2947`
4. You should see latitude, longitude, and other GPS attributes as sensor entities

## Troubleshooting

### No /dev/ttyUSB* devices

- Check that the Mini PCIe module is seated properly
- SSH in and run `lsusb` — you should see a Quectel device
- Check `dmesg | grep -i quectel` for driver loading messages
- The `option` kernel module must be loaded

### AT commands return ERROR

- The modem may not be fully booted yet — the add-on waits up to 60 seconds, but you can increase retries in `run.sh`
- Try sending `AT` manually: `echo -e "AT\r" > /dev/ttyUSB2 && timeout 2 cat /dev/ttyUSB2`

### GPS fix takes a long time

- First fix (cold start) can take 1-5 minutes with clear sky view
- The EG25-G supports gpsOneXTRA assisted GPS — this requires a data connection, which we've disabled with `CFUN=4`. For GPS-only use, cold starts are expected
- Ensure the GPS antenna has a clear view of the sky

### gpsd add-on can't read /dev/ttyUSB1

- Make sure the gpsd add-on also has `full_access: true` or the device is mapped
- Verify NMEA output: SSH in and run `cat /dev/ttyUSB1` — you should see `$GPGGA`, `$GPRMC`, etc.

## Files

| File | Purpose |
|------|---------|
| `config.yaml` | Add-on metadata, options, device access |
| `Dockerfile` | Container build (HA base image, no extra deps) |
| `run.sh` | Sends AT commands at boot, then idles |

## References

- [Quectel EG25-G Product Page](https://www.quectel.com/product/lte-eg25-g/)
- [Quectel GNSS AT Commands Manual (PDF)](https://sixfab.com/wp-content/uploads/2018/09/Quectel_EC25EC21_GNSS_AT_Commands_Manual_V1.1.pdf)
- [Quectel GNSS Application Note (PDF)](https://forums.quectel.com/uploads/short-url/jujxS4iCyMIMmoYNv61ixKO9Ij9.pdf)
- [Leo-stan's gpsd add-on](https://github.com/leo-stan/ha-addon-gpsd)
- [HA GPSD Integration](https://www.home-assistant.io/integrations/gpsd/)
- [Arduino Pro 4G GNSS Module](https://store-usa.arduino.cc/products/4g-module-global)
