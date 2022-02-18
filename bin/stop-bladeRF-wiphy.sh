#!/bin/bash

# Script to shut down bladeRF-wiphy
# set -e          # uncomment to stop on any error
set -x          # uncomment to display lines as they are executed
trap read debug # uncomment to prompt after each line

killall bladeRF-linux-mac80211 

# Unload kernel modules
sudo rmmod mac80211_hwsim
sudo rmmod mac80211
# Don't remove cfg80211 because it could be used by other devices

# Clean up devices
sudo ip link set wlan0 down
sudo ip link set wlan1 down
sudo ip link set bladeRFwlan0 down
