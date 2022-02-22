#!/bin/bash

# Script to start up bladeRF-wiphy

set -e          # stop on any error
set -x          # uncomment to display lines as they are executed
# trap read debug # uncomment to prompt after each line

# Load the kernel modules
sudo modprobe cfg80211
sudo modprobe mac80211 
sudo modprobe bladeRF_mac80211_hwsim

read -p "Press <RETURN> to contiue." prompt 

# Prevent network manager from controlling the interface
if [ $(env nmcli >& /dev/null)]; then    
    env nmcli && sudo nmcli dev set wlan0 managed false
fi


# Get the mac address of the physical ethernet adaptor
MACADDR=$( LANG=C ip -o link show | egrep -v 'wlan|mon|loop' | awk '{print $17}' )
echo "Using MAC addresss $"

# Set bladeRF-wiphy MAC address 
sudo ip link set wlan0 down
sudo ip link set wlan0 address ${MACADDR}
sudo ip link set wlan0 up

# Congigure 802.11 options
sudo iw wlan0 set bitrates legacy-2.4 6 9 12 18 24 48 54

# Add monitoring interface
sudo iw dev wlan0 interface add mon0 type monitor
sudo ip link set mon0 up

# Set bladeRF-wiphy IP address & properties

sudo ip link set wlan0 down

sudo ip address add 10.254.239.1 dev wlan0 # !! Be sure this matches the range in dhhcpd.conf
sudo iw dev wlan0 set type monitor
sudo iw dev wlan0 set freq 5825

sudo ip link set wlan0 up

# Enable network forwarding
echo 1 | sudo tee /proc/sys/net/ipv4/ip_forward

# Use the `enp0s5` interface for IP forwarding
sudo iptables -t nat -A POSTROUTING -s 10.254.239.1/16 -o enp0s5 -j MASQUERADE

# Load the FPGA firmware
bladeRF-cli -f /usr/share/Nuand/bladeRF/bladeRF_fw_latest.img
bladeRF-cli -l /usr/share/Nuand/bladeRF/wlanxA9-latest.rbf

# Start all components in separate terminals
gnome-terminal -t /var/log -- tail -f /var/log/*
gnome-terminal -t bladeRF-linux-mac80211 -- bladeRF-linux-mac80211
gnome-terminal -t bladeRF-net.py --working-directory=$HOME/wiphy-build/bladeRF-net -- python3 bladeRF-net.py
gnome-terminal -t hostapd -- sudo /usr/local/bin/hostapd /etc/hostapd/hostapd.conf

sleep 5s
sudo service isc-dhcp-server restart

cat <<EOF

    -----------------------------------------
    bladeRF-wiphi is now running.

    Execute `stop-bladeRF-wiphy` to terminate
    -----------------------------------------

EOF

