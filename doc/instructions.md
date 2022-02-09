---
created: 2022-02-05T15:45:34 (UTC -05:00)
tags: []
source: https://www.nuand.com/bladeRF-wiphy-instructions/#synthesize-bladerf-wiphy-optional
author: 
---

# bladeRF-wiphy instructions - Nuand

> ## Excerpt
> Instructions to compile, install, and run bladeRF-wiphy

---
Instructions to compile, install, and run bladeRF-wiphy

To run bladeRF-wiphy on the bladeRF 2.0 micro xA9 so it can function with mac80211 and hostapd, and beacon as an Access Point (AP), follow the instructions below to build `bladeRF`, `bladeRF-mac80211_hwsim`, etc. from scratch.

![](https://www.nuand.com/wp-content/uploads/2021/01/bw-block-diagram.png)

## Compile bladeRF-wiphy and dependencies

Consider creating a directory such as `~/wiphy-build/` for fetching the following subsections’ repositories into. In the end, the directory hierarchy of `~/wiphy-build/` should look (approximately) as follows:

```
wiphy-build/
 ├── bladeRF
 ├── bladeRF-linux-mac80211
 ├── bladeRF-mac80211_hwsim
 ├── bladeRF-net
 ├── bladeRF-wiphy
 └── hostap
```

The first step then is to create `~/wiphy-build/`:

```
mkdir ~/wiphy-build/
cd ~/wiphy-build/
```

The rest of this page assumes `~/wiphy-build/` is the current working directory.

### Compile libbladeRF

Fetch the dependencies mentioned in the bladeRF wiki: [https://github.com/Nuand/bladeRF/wiki/Getting-Started%3A-Linux#debian-based-distros-eg-ubuntu](https://github.com/Nuand/bladeRF/wiki/Getting-Started%3A-Linux#debian-based-distros-eg-ubuntu)

  
Ensure `~/wiphy-build/` is the current working directory then git clone the `bladeRF` Github repository into `~/wiphy-build/bladeRF` by calling:

```
cd ~/wiphy-build/
git clone https://github.com/Nuand/bladeRF
cd ~/bladeRF
mkdir host/build
cd host/build
cmake ../
make -j4
sudo make install
sudo ldconfig
cd ../..
```

For more instructions and troubleshooting build `libbladeRF` and the `bladeRF` tools from source take a look at: [https://github.com/Nuand/bladeRF/wiki/Getting-Started%3A-Linux#Building_bladeRF_libraries_and_tools_from_source](https://github.com/Nuand/bladeRF/wiki/Getting-Started%3A-Linux#Building_bladeRF_libraries_and_tools_from_source)

### Synthesize bladeRF-wiphy (optional)

This step is optional, to skip this step download the synthesized bladeRF-wiphy RBF (wlanxA9.rbf) for the bladeRF 2.0 micro xA9 go to [FPGA images](https://www.nuand.com/fpga_images/).

Again ensure the current working directory is `~/wiphy-build/` and fetch the source from the Github repository into `~/wiphy-build/bladeRF-wiphy/`

```
cd ~/wiphy-build/
git clone https://github.com/Nuand/bladeRF-wiphy/
```

Generate the QSys cores:

```
pushd bladeRF-wiphy/fpga/ip
bash generate.sh
popd
```

Synthesize `bladeRF-wiphy`:

```
cd ~/wiphy-build/bladeRF  
pushd host  
mkdir build/  
cmake ../  
popd  
cd hdl/quartus/  
./build_bladerf.sh -b bladeRF-micro -r wlan -s A9

cd $( ls -td wlanxA9* | head -1 )
sudo install -D wlanxA9.rbf /usr/share/Nuand/bladeRF/
```

### Build bladeRF-mac80211_hwsim

Linux’s default mac80211_hwsim kernel module can be used, however some features (such as changing channels) require the use of `bladeRF-mac80211_hwsim`. `bladeRF-mac80211_hwsim` is recommended, and can be compiled with these commands:

```
cd ~/wiphy-build/
git clone https://github.com/Nuand/bladeRF-mac80211_hwsim  
cd bladeRF-mac80211_hwsim  
make -j4  
sudo make install
sudo ldconfig
cd ..
```

### Build bladeRF-linux-mac80211

Prior to compiling `bladeRF-linux-mac80211`, ensure Generic Netlink and SSL libraries are installed:

```
sudo apt-get install libssl-dev libnl-genl-3-dev
```

`bladeRF-linux-mac80211` is the usermode application that controls the bladeRF, and exchanges packets between `libbladeRF` and `mac80211_hwsim` through a netlink socket.

```
cd ~/wiphy-build/
git clone https://github.com/Nuand/bladeRF-linux-mac80211  
cd bladeRF-linux-mac80211/  
make -j14  
sudo make install
sudo ldconfig
cd ..
```

### Build hostapd

Compile `hostapd` (currently tested with commit hash `1759a8e3f36a40b20e7c7df06c6d1afc5d1c30c7`) using the following instructions. 


```
cd ~/wiphy-build/
git clone git://w1.fi/hostap.git  
cd hostap  
git reset --hard 1759a8e3f36a40b20e7c7df06c6d1afc5d1c30c7  
cd hostapd  
cp defconfig .config  
make -j4
sudo make install  
cd ..
```

The reference `hostapd.conf` tested with bladeRF-wiphy can be fetched with `wget`. 
```
# wget https://nuand.com/downloads/hostapd.conf -O hostapd.conf  
```

Before running `hostapd`, verify `hostapd.conf` to ensure operation is permitted and suitable for your domain, and channel availability.  Once you have modified `hostapd.conf` appropriately, copy it into place:
```
sudo install -D -v hostapd.conf /etc/hostapd/hostapd.conf
```




### Fetch bladeRF-net (optional)

This is a simple Python Flask application that acts as welcome page for associated STAs! 

Install the Python Flask module, either through your distributions package manager, e.g. for Debian or Ubuntu:
```
sudo apt install python3-flask
```
or via Python's PIP package manager:
```
pip3 install flask
```

Then install the flask code and (optionally) the logo image `birb.png`:
```
cd ~/wiphy-build/
git clone https://github.com/Nuand/bladeRF-net  
cd bladeRF-net  
wget https://nuand.com/images/birb.png -O images/birb.png  
cd ..
```

### Setup a DHCP server for STAs (optional)

If you are intending to run bladerf-wiphy in Access Point mode, and want to configure a DHCP server for associating devices, consider using `isc-dhcp-server`.   It can be installed with:
```
sudo apt-get install isc-dhcp-server
```

To setup a `10.254.239.x` subnet for associate STAs, add the following `10.254.239.x` subnet to `/etc/dhcp/dhcpd.conf`:

```
subnet 10.254.239.0 netmask 255.255.255.224 {
 range 10.254.239.10 10.254.239.20;
    }
```

**Note** Be sure to select an address range that conflict with your regular network.


Tell the DHCP server to listen to DHCP requests on wlan0 (or whatever the network interface name of `bladeRF-mac80211_hwsim`) , by adding the following lines to `/etc/dhcp/dhcpd.conf` :

```
INTERFACESv4="wlan0"  
INTERFACESv6="wlan0"
```

## Running bladeRF-wifi

Ensure the bladeRF 2.0 micro xA9 is running a firmware version of at least `v2.4.0`. A quick check is to look at the “Firmware verion” line in the output of `bladeRF-cli -e ver` . Update the bladeRF’s FX3 firmware to v2.4.0 (or later) by `fetching bladeRF_fw_v2.4.0.img` from [https://www.nuand.com/fx3_images/](https://www.nuand.com/fx3_images/) and running `bladeRF-cli -f bladeRF_fw_v2.4.0.img`.

There are several moving parts that all need to be loaded and running simultaneously including `bladeRF-mac80211_hwsim`, `bladeRF-linux-mac80211`, and `hostapd` (if intending to run in AP mode).

These commands have to repeated after every system reboot. The goal of the following commands is to 
1. load the `mac80211_hwsim` kernel module, 
2. create the main network interface, 
3. assign it an IP and routes, 
4. setup the monitor mode interface
5. start a DHCP server. 

This page assumes the `mac80211_hwsim` network interface is called `wlan0`, however things may be different on different systems. 

### Load the pre-requisite kernel modules

Ensure mac80211 and cfg80211 modules are loaded first using 
```
lsmod | grep 80211
```

If they are not listed, use `modprobe` to load them:
```
sudo modprobe mac80211  
sudo modprobe cfg80211
```

Then use `lsmod` again to check that the modules are now listed:
```
lsmod | grep 80211
```

### Load the `mac80211_hwsim` kernel module

First, use `ifconfig` to list the current network interfaces.
```
ifconfig | grep flags
```

Now, use `insmod` to load the kernel module:
```
cd ~/wiphy-build/bladeRF-mac80211_hwsim/
sudo insmod mac80211_hwsim.ko radios=1
cd ~
```

Now use `ifconfig` again to see the newly created interface;
```
ifconfig | grep flags
```


### Configure the network interface

Once the interface name is determined (and assuming it is called `wlan0`), configure the network interface.

If running on Ubuntu, disable Network Manager from controling the interface:

```
nmcli dev set wlan0 managed false
```

The remaining steps should generally be done in the following order:

```
sudo bash <<EOF
# Set bladeRF-wiphy MAC address 
ifconfig wlan0 down
ifconfig wlan0 hw ether 70:B3:D5:7D:80:01
ifconfig wlan0 up

# Congigure 802.11 options
iw wlan0 set bitrates legacy-2.4 6 9 12 18 24 48 54

# Add monitoring interface
iw dev wlan0 interface add mon0 type monitor
ifconfig mon0 up

# Set bladeRF-wiphy IP address
ifconfig wlan0 10.254.239.1
ip link set wlan0 down

iw dev wlan0 set type monitor
iw dev wlan0 set freq 5825

ip link set wlan0 up
ifconfig wlan0 10.254.239.1
EOF
```

If you are using the bladeRF as an Access Point, start the dhcp server: 
```
service isc-dhcp-server restart
```

You should only need to perform the actions in this section after reboots, or right after the kernel module has been inserted.


### Load the FPGA

Either fetch the `wlanxA9.rbf` file from [https://www.nuand.com/fpga_images/](https://www.nuand.com/fpga_images/) or build the RBF. Load the bladeRF 2.0 micro xA9 RBF containing the bladeRF-wiphy 802.11 modem by changing to the directory where you either downloaded or built the `wlanxA9` file and using the bladeRF command-line tool, for example

```
bladeRF-cli -l /usr/share/Nuand/bladeRF/wlanxA9.rbf
```

### Run bladeRF-linux-mac80211

`bladeRF-linux-mac80211` is the user mode application that controls and interfaces with the bladeRF and netlink socket, and must remain running for bladeRF-wiphy to run. This command should be run (potentially in another terminal):

```
bladeRF-linux-mac80211
```

If you wish to use a non-starndard frequency, use command line argument -f and specify the frequency in MHz, e.g. 2.412GHz would require `-f 2412`. 


### Run hostapd

If you wish to run an Access Point, run `hostapd`.

Before starting `hostapd`, review `/etc/hostapd/hostapd.conf` and ensure the configuration is correct for your region and application.

**NOTE:** The default bladeRF-wiphy `hostapd.conf` creates an open SSID named `bladeRF-net`.  

```
sudo hostapd /etc/hostapd/hostapd.conf
```

In yet another terminal, wait a moment after launching hostpad and restart the DHCP server.

```
sudo service isc-dhcp-server restart
```

### Launch bladeRF-net (optional)

Launch the bladeRF-net FLask app to run on port 5000. The web server at http://10.254.239.1:5000/ should be accessible to devices associated to the Access Point.

```
cd ~/wiphy-build/bladeRF-net  
python3 bladeRF-net.py
```

At this point an open SSID named `bladeRF-net` should be visible and able to be associated to by STAs. If bladeRF-net is running, try to navigate to bladeRF-net SSID gateway at http://10.254.239.1:5000/ !

![](https://www.nuand.com/wp-content/uploads/2021/01/current-1024x1024.png)


## Troubleshooting

In case something needs to be restarted. It is recommended to restart the process from right after loading the kernel module. However if a full reset is necessary, try 
```
rmmod mac80211_hwsim.ko
```
(or reboot the system if all else fails).

## Miscellaneous commands

To enable a monitor mode interface for the bladeRF-wiphy interface:

```
iw dev wlan0 set type monitor
```

To change channels, use the `iw dev` commands prior to running hostap:  
```
iw dev wlan0 set freq 2412
```

## Theory of operation

After loading `wlanxA9.rbf`, the bladeRF 2.0 micro xA9 is controlled by a program called `bladeRF-linux-mac80211` ( https://github.com/Nuand/bladeRF-linux-mac80211 ). `bladeRF-linux-mac80211` uses `libbladeRF` to exchange digital payload packets between the modem in the FPGA, and mac80211 through a netlink socket and `mac80211_hwsim`. `bladeRF-linux-mac80211` relies on the existence of `mac80211_hwsim` to send and receive netlink packets.

A received 802.11 packet that is decoded by the FPGA is transmitted to the host PC through USB. `libbladeRF` receives the packet (with the help of libusb) and returns the packet to `bladeRF-linux-mac80211`’s pending `bladerf_sync_rx()` call. `bladeRF-linux-mac80211` then creates a netlink packet to further send the received packet to the `mac80211_hwsim` kernel module. Upon receiving the netlink packet containing the received 802.11 packet, the `mac80211_hwsim` kernel module inserts the 802.11 PDU into `mac80211`. At this point the `mac80211` stack takes over.

Conversely, a packet that is generated by the `mac80211` stack is send received by the `mac80211_hwsim` kernel module, which then uses its netlink socket to further send the packet to `bladeRF-linux-mac80211`. In user mode, `bladeRF-linux-mac80211` receives the netlink packet from the kernel, prepares it with the appropriate hardware header, and calls `bladerf_sync_tx()` to send the digital payload to modem on the bladeRF 2.0 micro for modulation.

----

All specifications subject to change at any time without notice. bladeRF is sold as test equipment and is expected for all intents and purposes to be used as such. Use of this device is at your own risk and discretion. Nuand LLC makes no warranty of any kind (whether express or implied) with regard to material presented on this page, and disclaims any and all warranties, including accuracy of this document, or the implied warranties of merchatability and fitness for use.
