#!/bin/bash

gadget=/sys/kernel/config/usb_gadget/pi4

if [[ ! -e "/etc/usb-gadgets/$1" ]]; then
    echo "No such config, $1, found in /etc/usb-gadgets"
    exit 1
fi
source /etc/usb-gadgets/$1

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

mkdir ${gadget}/configs/c.1
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

ls /sys/class/udc >${gadget}/UDC

udevadm settle -t 5 || :
ifup usb0
service dnsmasq restart
