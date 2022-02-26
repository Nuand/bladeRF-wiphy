#!/bin/bash
#
# Script to shut down bladeRF-wiphy
#
set -e          # uncomment to stop on any error
# set -x          # uncomment to display lines as they are executed
# trap read debug # uncomment to prompt after each line

# Configuration
export BUILD_DIR=${BUILD_DIR:-/tmp/build-bladeRF-wiphy}

# Termeinate the user-mode driver
sudo pkill -f hostapd && true
sudo pkill -f bladeRF-linux-mac80211 && true
sudo pkill -f "python3 bladeRF-net.py" && true
sudo pkill -f "tail -f /var" && true

# Unload kernel modules
MODULES="^mac80211|^mac80211_hwsim|^bladeRF_mac80211_hwsim"
lsmod | awk '{print $1}' | egrep "${MODULES}" | xargs -rt sudo rmmod

# Restore standard bladeRF FPGA code
echo
echo -n "Restoring standard bladeRF firmware: "
bladeRF-cli -l /etc/Nuand/bladeRF/hostedxA9-latest.rbf 

cat <<EOF

    -----------------------------

    bladeRF-wiphi is now stopped.

    -----------------------------

EOF
