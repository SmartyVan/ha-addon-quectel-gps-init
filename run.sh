#!/bin/bash

# Read AT port from add-on options
AT_PORT=$(cat /data/options.json | grep -o '"at_port"[^"]*"[^"]*"' | grep -o '"[^"]*"$' | tr -d '"')
AT_PORT="${AT_PORT:-/dev/ttyUSB2}"

echo "[GPS Init] Configuring modem on ${AT_PORT}"

# Wait for the modem to enumerate USB devices
RETRIES=0
while [ ! -e "${AT_PORT}" ] && [ ${RETRIES} -lt 30 ]; do
    echo "[GPS Init] Waiting for ${AT_PORT} to appear... (${RETRIES}/30)"
    sleep 2
    RETRIES=$((RETRIES + 1))
done

if [ ! -e "${AT_PORT}" ]; then
    echo "[GPS Init] ERROR: ${AT_PORT} not found after 60s. Is the modem connected?"
    exit 1
fi

# Configure serial port
stty -F "${AT_PORT}" 115200 raw -echo 2>/dev/null || true

# Send an AT command and log the response
send_at() {
    local cmd="$1"
    local desc="$2"
    echo "[GPS Init] Sending: ${cmd} (${desc})"
    echo -e "${cmd}\r" > "${AT_PORT}"
    sleep 1
    response=$(timeout 3 cat "${AT_PORT}" 2>/dev/null || true)
    echo "[GPS Init] Response: ${response}"
}

# Basic connectivity check
send_at "AT" "ping modem"

# Disable cellular radio (airplane mode) — does NOT persist across reboots
send_at "AT+CFUN=4" "disable cellular radio"

# Ensure NMEA output goes to USB NMEA port (ttyUSB1) — saved to NVRAM
send_at 'AT+QGPSCFG="outport","usbnmea"' "set NMEA output to usbnmea"

# Enable auto-start GPS on module power-on — saved to NVRAM
send_at 'AT+QGPSCFG="autogps",1' "enable GPS auto-start"

# Start GNSS now
send_at "AT+QGPS=1" "enable GNSS"

echo "[GPS Init] Complete. NMEA sentences should now appear on /dev/ttyUSB1."
echo "[GPS Init] Sleeping to keep add-on alive..."

# Sleep forever — HA supervisor restarts add-ons that exit
exec sleep infinity
