# GPS Init — Home Assistant Add-on

A minimal Home Assistant OS add-on that initializes Quectel Mini PCIe modems for **GPS-only mode** (no cellular). Sends AT commands at boot to disable the cellular radio and enable GNSS, then NMEA sentences flow on a separate USB serial port for gpsd to consume.

Tested with the Quectel EC25-A on a Seeed Studio Raspberry Pi CM5 edge computer.

## What It Does

On every boot, this add-on sends AT commands to the modem's AT port:

1. **Disable the cellular radio** (`AT+CFUN=4`) — airplane mode, less power draw, no network registration
2. **Set NMEA output to USB** (`AT+QGPSCFG="outport","usbnmea"`) — ensures GPS sentences go to the NMEA port (saved to NVRAM)
3. **Enable GPS auto-start** (`AT+QGPSCFG="autogps",1`) — GNSS starts automatically on module power-on (saved to NVRAM)
4. **Start GNSS now** (`AT+QGPS=1`) — begins GPS acquisition immediately

After initialization the add-on idles. It must run every boot because `AT+CFUN=4` does not persist across power cycles.

## Compatible Modems

This add-on works with Quectel modems that share the `AT+QGPS` / `AT+QGPSCFG` / `AT+CFUN` command set. All use the same 4-port USB serial layout.

### Tested

| Modem | Form Factor | Notes |
|-------|-------------|-------|
| **EC25-A** | Mini PCIe | North America LTE bands. Primary test hardware. |

### Expected Compatible (same AT command set)

| Series | Models | Form Factor |
|--------|--------|-------------|
| EC25 | EC25-E, EC25-AU, EC25-AF, etc. | Mini PCIe |
| EG25 | EG25-G, EG25-GL | Mini PCIe |
| EC21 | EC21-A, EC21-E, etc. | Mini PCIe |
| EG91 | EG91-NA, EG91-E, etc. | Mini PCIe |
| EG95 | EG95-NA, EG95-E, etc. | Mini PCIe |
| BG96 | BG96 | Mini PCIe |
| BG95 | BG95-M3 | Mini PCIe |
| EM05 | EM05-E, EM05-G | M.2 |

> **Not compatible** with SIMCom (SIM7600), Sierra Wireless (MC7455), or Telit modems — they use different AT command sets.

If you test this add-on with a modem not listed under "Tested", please open an issue or PR to update this table!

## USB Port Mapping

Quectel LTE Standard modules expose 4 USB serial ports:

| Port | Interface | Function | Used By |
|------|-----------|----------|---------|
| `ttyUSB0` | `if00` | DM (diagnostic) | — |
| `ttyUSB1` | `if01` | NMEA (GPS sentences) | gpsd add-on |
| `ttyUSB2` | `if02` | AT commands | **This add-on** |
| `ttyUSB3` | `if03` | PPP/modem | — |

> **Important:** The `ttyUSBx` numbering can shift if other USB-serial devices are plugged in. Use the stable `/dev/serial/by-id/` paths instead. The add-on configuration presents a dropdown of available serial devices.

## Installation

### Option A: Add as a repository (recommended)

1. In Home Assistant, go to **Settings > Add-ons > Add-on Store**
2. Click the three-dot menu (top right) > **Repositories**
3. Add: `https://github.com/SmartyVan/ha-addon-quectel-gps-init`
4. Click **Close**, then refresh. **GPS Init** should appear in the store.
5. Click it and press **Install**

### Option B: Install as a local add-on

Using Samba:

1. Enable the **Samba share** add-on in HA if not already active
2. Connect to `\\homeassistant\addons` (or `smb://homeassistant.local/addons` on Mac)
3. Copy the entire `gps-init/` folder into the `addons` share

Using SSH/SCP:

```bash
scp -r gps-init/ root@homeassistant.local:/addons/gps-init/
```

Then in HA: **Settings > Add-ons > Add-on Store** > three-dot menu > **Check for updates**. It should appear under **Local add-ons**.

## Configuration

1. Go to the add-on's **Configuration** tab
2. Select the modem's **AT command port** from the dropdown — typically the `if02` interface
   - Example: `/dev/serial/by-id/usb-Android_Android-if02-port0`
   - If unsure, `ttyUSB2` is the default for Quectel modems
3. Enable **Start on boot**
4. Click **Start**
5. Check the **Log** tab — you should see `OK` responses for each AT command

## Setting Up the GPS Pipeline

This add-on is step 1 of a 2-part pipeline:

```
GPS Init             gpsd2mqtt add-on
(this add-on)   -->  (reads NMEA, publishes to MQTT)
Sends AT cmds        Auto-discovers as a device tracker
to AT port           in Home Assistant
```

### Step 2: Install the gpsd2mqtt add-on

We recommend [gpsd2mqtt](https://github.com/corvy/ha-addons/tree/main/gpsd2mqtt):

1. Go to **Settings > Add-ons > Add-on Store** > three-dot menu > **Repositories**
2. Add: `https://github.com/corvy/ha-addons`
3. Install **GPSD to MQTT**
4. Configure the GPS device to the modem's **NMEA port** (the `if01` interface):
   - Example: `/dev/serial/by-id/usb-Android_Android-if01-port0`
5. Start it — a device tracker entity is auto-discovered in Home Assistant via MQTT

## Troubleshooting

### No /dev/ttyUSB* devices

- Check that the Mini PCIe module is seated properly
- SSH in and run `lsusb` — look for vendor ID `2c7c` (Quectel)
- Check `dmesg | grep -i -E "quectel|option|ttyUSB"` for driver messages
- The `option` kernel module must be loaded

### AT commands return ERROR

- The modem may not be fully booted yet — the add-on waits up to 60 seconds
- Try manually: `echo -e "AT\r" > /dev/ttyUSB2 && timeout 2 cat /dev/ttyUSB2`

### CME ERROR: 504 on AT+QGPS=1

- This means GPS is already running (likely because `autogps` was previously set). This is harmless.

### GPS fix takes a long time

- Cold start can take 1-5 minutes with clear sky view
- gpsOneXTRA assisted GPS requires a data connection, which is disabled by `CFUN=4`. Cold starts are expected in GPS-only mode.
- Ensure the GNSS antenna has a clear view of the sky

### gpsd add-on can't read NMEA port

- Make sure the gpsd add-on also has device access (check its configuration)
- Verify NMEA output: SSH in and run `timeout 5 cat /dev/ttyUSB1` — you should see `$GPGGA`, `$GPRMC`, etc.

## Files

| File | Purpose |
|------|---------|
| `config.yaml` | Add-on metadata, options, device access |
| `Dockerfile` | Container build (Alpine base, no extra deps beyond bash/coreutils) |
| `run.sh` | Sends AT commands at boot, then idles |
| `build.yaml` | Build architecture configuration |
| `repository.yaml` | HA add-on repository metadata |

## References

- [Quectel EC25 Product Page](https://www.quectel.com/product/lte-ec25-series/)
- [Quectel GNSS AT Commands Manual (PDF)](https://sixfab.com/wp-content/uploads/2018/09/Quectel_EC25EC21_GNSS_AT_Commands_Manual_V1.1.pdf)
- [Quectel GNSS Application Note (PDF)](https://forums.quectel.com/uploads/short-url/jujxS4iCyMIMmoYNv61ixKO9Ij9.pdf)
- [gpsd2mqtt Add-on](https://github.com/corvy/ha-addons/tree/main/gpsd2mqtt)
- [gpsd2mqtt Add-on Repository](https://github.com/corvy/ha-addons)
