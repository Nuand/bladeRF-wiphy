#!/bin/bash
#
# Script to shut down bladeRF-wiphy
#
set -e          # uncomment to stop on any error
# set -x          # uncomment to display lines as they are executed
# trap read debug # uncomment to prompt after each line

# Settings
DEV="wlan1"

sudo killall bladeRF-linux-mac80211 >& /dev/null && true

# Unload kernel modules
MODULES="^mac80211|^mac80211_hwsim|^bladeRF_mac80211_hwsim"
lsmod | awk '{print $1}' | egrep "${MODULES}" | xargs -rt sudo rmmod

# Clean up any remaining devices
DEVICES="^${DEV}|^bladeRFwlan|^mon"
ip -o link | awk '{ print $2}' | egrep "${DEVICES}" | xargs -rt -I DEV sudo ip link set DEV down

# Restore standard bladeRF FPGA code
echo
echo -n "Restoring standard bladeRF firmware: "
bladeRF-cli -l /usr/share/Nuand/bladeRF/hostedxA9-latest.rbf 

cat <<EOF

    -----------------------------

    bladeRF-wiphi is now stopped.

    -----------------------------

EOF
