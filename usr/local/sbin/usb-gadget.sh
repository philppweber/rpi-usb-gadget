#!/bin/bash

gadget=/sys/kernel/config/usb_gadget/pi4
use_mass_storage=1

if [[ ! -e "/etc/usb-gadgets/$1" ]]; then
    echo "No such config, $1, found in /etc/usb-gadgets"
    exit 1
fi
source /etc/usb-gadgets/$1

# load libcomposite module
modprobe libcomposite

mkdir -p ${gadget}
echo "${vendor_id}" >${gadget}/idVendor
echo "${product_id}" >${gadget}/idProduct
echo "${bcd_device}" >${gadget}/bcdDevice
echo "${usb_version}" >${gadget}/bcdUSB

if [ ! -z "${device_class}" ]; then
    echo "${device_class}" >${gadget}/bDeviceClass
    echo "${device_subclass}" >${gadget}/bDeviceSubClass
    echo "${device_protocol}" >${gadget}/bDeviceProtocol
fi

mkdir -p ${gadget}/strings/0x409
echo "${manufacturer}" >${gadget}/strings/0x409/manufacturer
echo "${product}" >${gadget}/strings/0x409/product
echo "${serial}" >${gadget}/strings/0x409/serialnumber

mkdir -p ${gadget}/configs/c.1
echo "${power}" >${gadget}/configs/c.1/MaxPower
if [ ! -z "${attr}" ]; then
    echo "${attr}" >${gadget}/configs/c.1/bmAttributes
fi

mkdir -p ${gadget}/configs/c.1/strings/0x409
echo "${config1}" >${gadget}/configs/c.1/strings/0x409/configuration

if [ "${config1}" = "ECM" ]; then
    mkdir -p ${gadget}/functions/ecm.usb0
    echo "${dev_mac}" >${gadget}/functions/ecm.usb0/dev_addr
    echo "${host_mac}" >${gadget}/functions/ecm.usb0/host_addr

    ln -s ${gadget}/functions/ecm.usb0 ${gadget}/configs/c.1/

    #mkdir -p ${gadget}/functions/acm.usb0
    #ln -s functions/acm.usb0 ${gadget}/configs/c.1/
fi

if [ "${config1}" = "RNDIS" ]; then
    mkdir -p ${gadget}/os_desc
    echo "1" >${gadget}/os_desc/use
    echo "${ms_vendor_code}" >${gadget}/os_desc/b_vendor_code
    echo "${ms_qw_sign}" >${gadget}/os_desc/qw_sign

    mkdir -p ${gadget}/functions/rndis.usb0
    echo "${dev_mac}" >${gadget}/functions/rndis.usb0/dev_addr
    echo "${host_mac}" >${gadget}/functions/rndis.usb0/host_addr
    echo "${ms_compat_id}" >${gadget}/functions/rndis.usb0/os_desc/interface.rndis/compatible_id
    echo "${ms_subcompat_id}" >${gadget}/functions/rndis.usb0/os_desc/interface.rndis/sub_compatible_id

    ln -s ${gadget}/configs/c.1 ${gadget}/os_desc
    ln -s ${gadget}/functions/rndis.usb0 ${gadget}/configs/c.1
fi

if [ "${use_mass_storage}" = 1 ]; then
    # ensure function is loaded
    modprobe usb_f_mass_storage
    # create the function (name must match a usb_f_<name> module such as 'acm')
    mkdir -p ${gadget}/functions/mass_storage.usb0
    # configure mass storage gadget and logical units
    echo 0 >${gadget}/functions/mass_storage.usb0/stall
    mkdir -p ${gadget}/functions/mass_storage.usb0/lun.0
    echo 0 >${gadget}/functions/mass_storage.usb0/lun.0/cdrom
    echo 0 >${gadget}/functions/mass_storage.usb0/lun.0/ro
    echo 0 >${gadget}/functions/mass_storage.usb0/lun.0/nofua
    echo 1 >${gadget}/functions/mass_storage.usb0/lun.0/removable
    # associate logical unit 0 with boot partition
    echo "/dev/mmcblk0p1" >${gadget}/functions/mass_storage.usb0/lun.0/file
    mkdir -p ${gadget}/functions/mass_storage.usb0/lun.1
    echo 0 >${gadget}/functions/mass_storage.usb0/lun.1/cdrom
    echo 0 >${gadget}/functions/mass_storage.usb0/lun.1/ro
    echo 0 >${gadget}/functions/mass_storage.usb0/lun.1/nofua
    echo 1 >${gadget}/functions/mass_storage.usb0/lun.1/removable
    # associate logical unit 1 with root partition (unusable on Windows because of missing ext4 support)
    echo "/dev/mmcblk0p2" >${gadget}/functions/mass_storage.usb0/lun.1/file
    # associate function with config
    ln -s ${gadget}/functions/mass_storage.usb0 ${gadget}/configs/c.1/
fi

# enable gadget by binding it to a UDC from /sys/class/udc
# to unbind it: echo "" > ${gadget}/UDC; sleep 1; rm -rf /sys/kernel/config/usb_gadget/pi4
ls /sys/class/udc >${gadget}/UDC

udevadm settle -t 5 || :
ifup usb0
service dnsmasq restart
