#!/bin/bash

# Script to start up bladeRF-wiphy

# Uncomment to debug
set -x

# # Load the kernel modules
# sudo modprobe mac80211  
# sudo modprobe cfg80211
# sudo modprobe bladeRF_mac80211_hwsim

# Prevent network manager from controlling the interface
sudo nmcli dev set wlan0 managed false

# Set bladeRF-wiphy MAC address 
sudo ifconfig wlan0 down
sudo ifconfig wlan0 hw ether 70:B3:D5:7D:80:01
sudo ifconfig wlan0 up

# Congigure 802.11 options
sudo iw wlan0 set bitrates legacy-2.4 6 9 12 18 24 48 54

# Add monitoring interface
sudo iw dev wlan0 interface add mon0 type monitor
sudo ifconfig mon0 up

# Set bladeRF-wiphy IP address
sudo ifconfig wlan0 10.254.239.1 # !! Be sure this matches the range in dhhcpd.conf
sudo ip link set wlan0 down

sudo iw dev wlan0 set type monitor
sudo iw dev wlan0 set freq 5825

sudo ip link set wlan0 up
sudo ifconfig wlan0 10.254.239.1

# Enable network forwarding
echo 1 | sudo tee /proc/sys/net/ipv4/ip_forward

# Use the `enp0s5` interface for IP forwarding
sudo iptables -t nat -A POSTROUTING -s 10.254.239.1/16 -o enp0s5 -j MASQUERADE

# Load the FPGA firmware
bladeRF-cli -l /usr/share/Nuand/bladeRF/wlanxA9.rbf

# Start all components in separate terminals
gnome-terminal -t bladeRF-linux-mac80211 -- bladeRF-linux-mac80211
gnome-terminal -t hostapd -- sudo /usr/local/bin/hostapd /etc/hostapd/hostapd.conf
gnome-terminal -t bladeRF-net.py --working-directory=$HOME/wiphy-build/bladeRF-net -- python3 bladeRF-net.py

sleep 5s
sudo service isc-dhcp-server restart

gnome-terminal -t /var/log -- tail -f /var/log/*
