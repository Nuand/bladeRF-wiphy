#!/bin/bash
#
# Script to install bladeRF-wiphy
#
set -x          # display lines as they are executed
# trap read debug # prompt after each line
#
# Configuration 
BUILD_DIR=$HOME/wiphy-build-test

# The first step then is to create `${BUILD_DIR}`:

mkdir -p ${BUILD_DIR}
cd ${BUILD_DIR}


### Build & install libbladeRF, bladeRF-cli

# Install dependencies

sudo apt-get install libusb-1.0-0-dev \
  libusb-1.0-0 \
  build-essential \
  cmake \
  libncurses5-dev \
  libtecla1 \
  libtecla-dev \
  pkg-config \
  git \
  wget

# Clone the `bladeRF` Github repository into `${BUILD_DIR}bladeRF` 

cd ${BUILD_DIR}
git clone https://github.com/Nuand/bladeRF

# Build libbladeRF

cd ${BUILD_DIR}/bladeRF
mkdir host/build
cd host/build
cmake ..
make -j4
sudo make install
sudo ldconfig

### Download & install the Firmware

cd ${BUILD_DIR}
mkdir firmware
cd firmware
wget https://www.nuand.com/fx3/bladeRF_fw_latest.img
wget https://www.nuand.com/fpga/wlanxA9-latest.rbf

sudo install -D -v bladeRF_fw_latest.img /usr/share/Nuand/bladeRF
sudo install -D -v wlanxA9-latest.rbf /usr/share/Nuand/bladeRF


### Compile bladeRF-wiphy

# Fetch bladeRF-wiphy source from Github

cd ${BUILD_DIR}
git clone https://github.com/warnes/bladeRF-wiphy/ -b add-doc

# # Generate the QSys cores:
#
# ```
# cd ${BUILD_DIR}/bladeRF-wiphy/fpga/ip
# bash generate.sh
# ```

# Synthesize `bladeRF-wiphy`:

# ```
# cd ${BUILD_DIR}/bladeRF/host
# mkdir build
# cmake ..  

# cd ${BUILD_DIR}/bladeRF/hdl/quartus/  
# ./build_bladerf.sh -b bladeRF-micro -r wlan -s A9
# cd $( ls -td wlanxA9* | head -1 )
#
# sudo install -D -v wlanxA9.rbf /usr/share/Nuand/bladeRF/
# ```


### Build & Install bladeRF-mac80211_hwsim


##!!!##
trap read debug # prompt after each line
##!!!##

cd ${BUILD_DIR}
git clone https://github.com/warnes-wireless/bladeRF-mac80211_hwsim -b nuand/main
cd bladeRF-mac80211_hwsim  
make -j4  
sudo make install

### Build & Install bladeRF-linux-mac80211

# Install dependencies

sudo apt-get install libssl-dev libnl-genl-3-dev

cd ${BUILD_DIR}
git clone https://github.com/warnes-wireless/bladeRF-linux-mac80211  
cd bladeRF-linux-mac80211/  
make -j14  
sudo make install
sudo ldconfig

### Build & Install hostapd

# Compile `hostapd` (currently tested with commit hash `1759a8e3f36a40b20e7c7df06c6d1afc5d1c30c7`)
cd ${BUILD_DIR}
git clone git://w1.fi/hostap.git  
cd hostap  
git reset --hard 1759a8e3f36a40b20e7c7df06c6d1afc5d1c30c7  

cd hostapd  
cp defconfig .config  
make -j4
sudo make install  

# Get the `hostapd.conf` tested with bladeRF-wiphy

echo "Make any changes to hostapd.conf HERE."
# cd ~/wiphy-build/bladeRF-wiphy/etc
# editor hostapd.conf

# Once you have modified `hostapd.conf` appropriately, copy it into place:
cd ~/wiphy-build/bladeRF-wiphy/etc
sudo install -D -v hostapd.conf /etc/hostapd/hostapd.conf

### Build & Install bladeRF-net (optional)

# Install python flask
sudo apt install python3-flask

# Install the flask code and the logo image
cd ${BUILD_DIR}
git clone https://github.com/Nuand/bladeRF-net  
cd bladeRF-net  
wget https://nuand.com/images/birb.png -O images/birb.png  

### Install & Setup a DHCP server for STAs (optional)

# Install DHCP server
sudo apt-get install isc-dhcp-server

# Install DHCP server configuration file 
cd ~/wiphy-build/bladeRF-wiphy/etc
sudo install -D -v dhcpd.conf /etc/dhcp/dhcpd.conf


### Install the bladeRF-wiphy startup script
cd ${BUILD_DIR}/bladeRF-wiphy/bin
sudo install -D start-bladeRF-wiphy.sh /usr/local/bin


### All Done!
echo "---------------------------------------------------"
echo "bladeRF-wiphy installation complete"
echo
echo "To start run: /usr/local/bin/start-bladeRF-wiphy.sh"
echo "To stop run:  /usr/local/bin/stop-bladeRF-wiphy.sh"
echo
echo "You may now remove the build directory '$BUILD_DIR'"
echo "---------------------------------------------------"
