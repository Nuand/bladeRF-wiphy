#!/bin/bash
#
# Script to start up bladeRF-wiphy
#
set -e          # stop on any error
set -x          # uncomment to display lines as they are executed
# trap read debug # uncomment to prompt after each line

# Configuration 
export BUILD_DIR=${BUILD_DIR:-/tmp/build-bladeRF-wiphy}

# Set the correct terminal command
VENDOR=${VENDOR:-"$(lsb_release -si)"}
TERMINAL=x-terminal-emulator 

# CLean out any existing kernel modules
MODULES="^mac80211|^mac80211_hwsim|^bladeRF_mac80211_hwsim"
lsmod | awk '{print $1}' | egrep "${MODULES}" | xargs -rt sudo rmmod

# Check for existing wlan interfaces so we can use the correct 
# device name (one higher)
WLAN_INDEX=$( ip -o link | awk '{print $2}' | egrep '^wlan[0-9]+' | wc -l )
export DEV=${DEV:-"wlan${WLAN_INDEX}"}
echo "Using device '${DEV}'"

# Edit configuration files to use correct device
echo "Modifying /etc/dhcp/dhcpd.conf to use '${DEV}'"
sudo perl -pi -e "s/wlan[0-9]+/${DEV}/g;" /etc/dhcp/dhcpd.conf 

echo "Modifying /etc/etc/hostapd/hostapd.conf to use '${DEV}'"
sudo perl -pi -e "s/wlan[0-9]+/${DEV}/g;" /etc/hostapd/hostapd.conf

# Load the FPGA firmware
bladeRF-cli -f /etc/Nuand/bladeRF/bladeRF_fw_latest.img
bladeRF-cli -l /etc/Nuand/bladeRF/wlanxA9-latest.rbf

# Load the kernel modules
sudo modprobe cfg80211
sudo modprobe mac80211 
sudo modprobe bladeRF_mac80211_hwsim radios=1

# Prevent network manager from controlling the interface
if [ $(which nmcli) ]; then    
    sudo nmcli dev set ${DEV} managed false
fi

# MACADDR=70:B3:D5:7D:80:01

# Get the mac address of the physical ethernet adaptor
# and use the last 2 digits for this bladeRF-wiphy
MACADDR=$( LANG=C ip -o link show | \
    egrep -v 'wlan|mon|loop' | \
    awk '{print $17}' | \
    awk -F : '{print $6}' \
    )
MACADDR=70:B3:D5:7D:80:${MACADDR}
echo "Using MAC addresss ${MACADDR}"


# Set bladeRF-wiphy MAC address 
sudo ip link set ${DEV} down
sudo ip link set ${DEV} address ${MACADDR}
sudo ip link set ${DEV} up

# Congigure 802.11 options
sudo iw ${DEV} set bitrates legacy-2.4 6 9 12 18 24 48 54

# Add monitoring interface
sudo ip link set ${DEV} down
sudo iw dev ${DEV} interface add mon0 type monitor

# Set bladeRF-wiphy IP address & properties

sudo iw dev ${DEV} set type monitor
sudo ip address change 10.254.239.1 dev ${DEV} # !! Be sure this matches the range in dhhcpd.conf

sudo ip link set ${DEV} up
sudo iw dev ${DEV} set freq 5825

sudo ip link set mon0 up

# # Enable network forwarding
# echo 1 | sudo tee /proc/sys/net/ipv4/ip_forward

# # Forward packages using any/all default route(s)
# GWDEV=$( ip route show | grep default | awk '{print $5}' )
# for DEVICE in ${GWDEV}; do
#     echo "Forwarding packets using ${DEVICE}"
#     sudo iptables -t nat -A POSTROUTING -s 10.254.239.1/16 -o ${DEVICE} -j MASQUERADE
# done

PRESS_RETURN="echo; read -p 'Process Ended.  Press <Return> to exit.' debug"


# Start all components in separate terminals
trap 'read -p "Press <Return> to continue"' debug # uncomment to prompt after each line
${TERMINAL} -t /var/log -e "tail -f /var/log/*.log" &
${TERMINAL} -t bladeRF-linux-mac80211 -e "/usr/local/bin/bladeRF-linux-mac80211 ; ${PRESS_RETURN}" &
${TERMINAL} -t bladeRF-net.py -e "cd ${BUILD_DIR}/bladeRF-net ; python3 bladeRF-net.py; ${PRESS_RETURN}" &
# ${TERMINAL} -t dhcpd   -e "sudo dhcpd -f ; ${PRESS_RETURN}" &
${TERMINAL} -t hostapd -e "sudo /usr/local/bin/hostapd /etc/hostapd/hostapd.conf ; ${PRESS_RETURN} "&

sleep 5s
sudo service isc-dhcp-server restart

cat <<EOF

    -----------------------------------------
    bladeRF-wiphi is now running.

    Execute 'stop-bladeRF-wiphy' to terminate
    -----------------------------------------
s
EOF

