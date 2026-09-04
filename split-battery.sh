#!/bin/bash
# Prints "<central> <peripheral>" battery % for the connected ZMK split keyboard
# by reading every GATT Battery Level characteristic (0x2a19) BlueZ exposes on it.
# Exits 1 when no ZMK keyboard is connected (widget hides itself).

tree=$(busctl tree org.bluez --list 2>/dev/null)

# ZMK identifies itself with vendor 0x1D50 / product 0x615E, an ID pair registered to
# ZMK Firmware in OpenMoko's free USB ID block. It is documented as the USB default and
# used unchanged as the PnP ID of the Bluetooth Device Information Service; BlueZ caches
# that PnP ID as the device Modalias, so spotting the keyboard costs no GATT read.
#   docs (USB VID/PID):   https://zmk.dev/docs/config/system
#   source (BT PnP ID):   https://github.com/zmkfirmware/zmk/blob/0331b7d16e80954b807917f9323e59ffc1e3b626/app/Kconfig#L39-L43
#   registry:             https://github.com/openmoko/openmoko-usb-oui
# TODO: first match wins; add a device setting if two ZMK boards are ever connected at once
DEV=""
for dev in $(grep -E '^/org/bluez/hci[0-9]+/dev_[0-9A-F_]+$' <<<"$tree"); do
  [[ $(busctl get-property org.bluez "$dev" org.bluez.Device1 Connected 2>/dev/null) == "b true" ]] || continue
  [[ $(busctl get-property org.bluez "$dev" org.bluez.Device1 Modalias 2>/dev/null) == *v1D50p615E* ]] || continue
  DEV=$dev
  break
done
[[ -n $DEV ]] || exit 1

levels=()
for char in $(grep -E "^$DEV/service[0-9a-f]+/char[0-9a-f]+$" <<<"$tree" | sort); do
  uuid=$(busctl get-property org.bluez "$char" org.bluez.GattCharacteristic1 UUID 2>/dev/null | cut -d'"' -f2)
  # Check the Bluetooth SIG's assigned number for the "Battery Level" characteristic
  [[ $uuid == 00002a19-* ]] || continue
  level=$(busctl call -j org.bluez "$char" org.bluez.GattCharacteristic1 ReadValue 'a{sv}' 0 2>/dev/null |
    jq -r '.data | flatten | .[0] // empty')
  levels+=("${level:-?}")
done

[[ ${#levels[@]} -gt 0 ]] || exit 1
echo "${levels[@]}"
