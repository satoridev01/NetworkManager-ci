#!/bin/bash

# 1. make veth managed by changing /usr/lib/udev/rules.d/85-nm-unmanaged.rules
# 2. check that DHCP connections are generated by NM for veths (uninstall NM-config-server package)

die() {
    cleanup_dev
    exit 1
}

cleanup_dev() {
    echo "Cleanup"
    for i in {1..20}; do
        ip link del veth$i
    done
}

wait_for_dev() {
  for i in {1..20}; do
      nmcli -t d |grep ':connected' |grep "$1:" && return
      sleep 0.5
  done
  echo "device '$1' is not connected:"
  nmcli c | cat
  die
}

wait_for_not_dev() {
  for i in {1..20}; do
      nmcli -t d |grep ':connected' |grep "$1:" || return 0
      sleep 0.5
  done
  echo "Device '$1' is still connected"
  nmcli c | cat
  die
}

echo "Create devices"
for i in {1..20}; do
    ip l add veth$i type veth peer name veth${i}p
    ip l set veth$i up
    ip l set veth${i}p up
done

echo "Wait for devices"
time for i in {1..20}; do
    wait_for_dev veth"$i"p
done

cleanup_dev

echo "Wait until connections disappears"
time for i in {1..20}; do
    wait_for_not_dev veth"$i"p
done
