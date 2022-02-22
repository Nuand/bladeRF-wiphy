#!/bin/bash

# Script to shut down bladeRF-wiphy
set -e          # uncomment to stop on any error
set -x          # uncomment to display lines as they are executed
trap read debug # uncomment to prompt after each line

sudo killall bladeRF-linux-mac80211 >& /dev/null && true

# Unload kernel modules
MODULES="^cfg80211|^mac80211|^mac80211_hwsim|^bladeRF_mac80211_hwsim"
lsmod | awk '{print $1}' | egrep "${MODULES}" | xargs -rt sudo rmmod

# Clean up any remaining devices
DEVICES="^wlan|^bladeRFwlan|^mon"
ip -o link | awk '{ print $2}' | egrep "${DEVICES}" | xargs -rt -I DEV sudo ip link set DEV down
