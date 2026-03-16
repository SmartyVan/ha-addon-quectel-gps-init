# Changelog

## 1.1.1

- Add device dropdown for AT port selection (no more typing paths)
- Add translated labels and descriptions for configuration
- Update repository naming and maintainer attribution

## 1.1.0

- Switch to privileged mode for reliable serial port access
- Add stable `/dev/serial/by-id/` device paths
- Add multi-architecture support (aarch64, amd64, armv7)

## 1.0.0

- Initial release
- Sends AT+CFUN=4 to disable cellular radio on every boot
- Enables GNSS with AT+QGPS=1
- Sets autogps=1 and NMEA output to usbnmea (persisted to NVRAM)
- Tested with Quectel EC25-A on Seeed Studio CM5
