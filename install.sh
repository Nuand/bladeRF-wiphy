#!/bin/bash
#
# Script to install bladeRF-wiphy
#
set -e          # Stop on errors
set -x          # Display lines as they are executed
# trap read debug # uncomment to prompt after each line
#
# Configuration 
export BUILD_DIR=${BUILD_DIR:-$HOME/wiphy-build-test}

# The first step then is to create `${BUILD_DIR}`:

mkdir -p ${BUILD_DIR}
cd ${BUILD_DIR}


### Build & install libbladeRF, bladeRF-cli

# Install dependencies

sudo apt -y install libusb-1.0-0-dev \
  libusb-1.0-0 \
  build-essential \
  cmake \
  libncurses5-dev \
  libtecla1 \
  libtecla-dev \
  pkg-config \
  git \
  curl

MACHINE="$(uname -m)"
case $MACHINE in
  x86*)
    PLATFORM="x86"
    ;;
  aarch64* | armv7l)
    PLATFORM="rpi"
    ;;
  *)
    echo "Unknown Architecture"
    exit -1
  ;;
esac

# Special case for Raspberry Pi
if [[ ${PLATFORM} == "rpi" ]]; then
  sudo apt install -y raspberrypi-kernel-headers
else
  sudo apt install -y linux-headers-generic
fi


# Clone the `bladeRF` Github repository into `${BUILD_DIR}/bladeRF` 

cd ${BUILD_DIR}
git clone --depth 1 --shallow-submodules https://github.com/Nuand/bladeRF

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
mkdir -p firmware
cd firmware
curl https://www.nuand.com/fx3/bladeRF_fw_latest.img -o bladeRF_fw_latest.img
curl https://www.nuand.com/fpga/v0.14.0/hostedxA9.rbf -o hostedxA9-latest.rbf
curl https://www.nuand.com/fpga/wlanxA9-latest.rbf   -o wlanxA9-latest.rbf 

sudo install -D -v bladeRF_fw_latest.img /usr/share/Nuand/bladeRF/bladeRF_fw_latest.img
sudo install -D -v hostedxA9-latest.rbf  /usr/share/Nuand/bladeRF/hostedxA9-latest.rbf
sudo install -D -v wlanxA9-latest.rbf    /usr/share/Nuand/bladeRF/wlanxA9-latest.rbf


### Compile bladeRF-wiphy

# Fetch bladeRF-wiphy source from Github

cd ${BUILD_DIR}
git clone --depth 1 https://github.com/warnes/bladeRF-wiphy/ -b add-doc

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
cd ${BUILD_DIR}

# TODO: Use kernel version instead of OS Vector for this.
if [[ ${PLATFORM} == "rpi" ]]; then
  git clone  https://github.com/warnes-wireless/bladeRF-mac80211_hwsim -b use_kmod
else 
  git clone  https://github.com/warnes-wireless/bladeRF-mac80211_hwsim -b use_kmod_5.13_plus
fi

cd bladeRF-mac80211_hwsim
make -j4  
sudo make install

### Build & Install bladeRF-linux-mac80211

# Install dependencies
sudo apt install -y libssl-dev libnl-genl-3-dev

# Clone repo, build, and install
cd ${BUILD_DIR}
git clone --depth 1 https://github.com/warnes-wireless/bladeRF-linux-mac80211  
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

cd ${BUILD_DIR}/bladeRF-wiphy/etc
echo "Make any changes to hostapd.conf HERE."
# editor hostapd.conf

# Once you have modified `hostapd.conf` appropriately, copy it into place:
cd ${BUILD_DIR}/bladeRF-wiphy/etc
sudo install -D -v hostapd.conf /etc/hostapd/hostapd.conf

### Build & Install bladeRF-net (optional)

# Install python flask
sudo apt install -y python3-flask

# Install the flask code and the logo image
cd ${BUILD_DIR}
git clone --depth 1 https://github.com/Nuand/bladeRF-net  
cd bladeRF-net  
wget https://nuand.com/images/birb.png -O images/birb.png  

### Install & Setup a DHCP server for STAs (optional)

# Install DHCP server
sudo apt install -y isc-dhcp-server

# Install DHCP server configuration file 
cd ${BUILD_DIR}/bladeRF-wiphy/etc
sudo install -D -v dhcpd.conf /etc/dhcp/dhcpd.conf


## Install the bladeRF-wiphy startup and shutdown scripts
cd ${BUILD_DIR}/bladeRF-wiphy/bin
sudo install -Dv start-bladeRF-wiphy.sh /usr/local/bin/start-bladeRF-wiphy.sh
sudo install -Dv stop-bladeRF-wiphy.sh  /usr/local/bin/stop-bladeRF-wiphy.sh

set +x          # Don't display lines as they are executed
### All Done!
echo
echo
echo "---------------------------------------------------"
echo "         bladeRF-wiphy installation complete"
echo
echo "To start run: /usr/local/bin/start-bladeRF-wiphy.sh"
echo "To stop run:  /usr/local/bin/stop-bladeRF-wiphy.sh"
echo
echo "You may now remove the build directory '$BUILD_DIR'"
echo "---------------------------------------------------"
echo
echo
