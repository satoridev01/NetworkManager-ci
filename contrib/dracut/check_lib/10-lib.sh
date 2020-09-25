die() {
  die_cmd $@ 1>&2
}

die_cmd() {
  echo "[FAIL] $@"
  echo FAIL | dd oflag=direct,dsync of=/dev/sda
  clean_root
  echo "== dump state after fail =="
  ip_list
  nmcli_list
  NM_logs
  poweroff -f
}

arg() {
  shift $1
  echo $1
}

clean_root() {
  echo "== cleaning ifcfg =="
  rm -vf /etc/sysconfig/network-scripts/ifcfg*
  echo "== cleaning check script =="
  rm -vf /check.sh
  echo "== cleaning hostname =="
  echo > /etc/hostname
  sync
}

mount_list() {
  echo "== nfs mounts =="
  mount | grep nfs
  echo "== ext3 mounts =="
  mount | grep ext3
}

NM_logs() {
  echo "== NM logs =="
  time journalctl -b -u NetworkManager --no-pager -o cat
}

nfs_server() {
    local nfs_mnt
    nfs_mnt=$(mount | grep "type nfs")
    nfs_mnt=$(arg 1 $nfs_mnt)
    nfs_mnt=${nfs_mnt%:*}
    [[ "$nfs_mnt" == "$1" ]] || die "NFS server is '$nfs_mnt', expected '$1'"
}

mount_root_type() {
    local root_mnt
    root_mnt=$(mount | grep " / type ")
    root_mnt=$(arg 5 $root_mnt)
    [[ "$root_mnt" == "$1" ]] || die "fstype of / is '$root_mnt', expected '$1'"
}

no_ifcfg() {
  find /etc/sysconfig/network-scripts/ifcfg-* &> /dev/null && \
    die "ifcfg file exists: $(echo; find /etc/sysconfig/network-scripts/ifcfg-*)"
  echo "[OK] no ifcfg file exists"
}

hostname_check() {
  local hostname
  hostname=$(cat /proc/sys/kernel/hostname)
  [[ "$hostname" == "$1" ]] || die "hostname is not '$1', but '$hostname'"
  echo "[OK] hostname is '$hostname'"
}