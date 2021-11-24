#!/bin/bash
set +x

HOSTAPD_CFG="/etc/hostapd/wireless.conf"
EAP_USERS_FILE="/etc/hostapd/hostapd.eap_user"
HOSTAPD_KEYS_PATH="/etc/hostapd/ssl"
CLIENT_KEYS_PATH="/tmp/certs"

function get_phy() {
    ifname=$1
    phynum=$(iw dev $ifname info | grep "wiphy [0-9]\+" | awk '{print $2}')
    echo "phy$phynum"
}

function start_dnsmasq ()
{
    echo "Start DHCP server (dnsmasq)"
    local dnsmasq="/usr/sbin/dnsmasq"
    local ip="ip"
    if $DO_NAMESPACE; then
        dnsmasq="ip netns exec wlan_ns $dnsmasq"
        ip="ip -n wlan_ns"
    fi

    # assign addreses to wlan1_* interfaces created by hostapd
    # wlan1 is already configured
    num=2
    for dev in $($ip l | grep -o 'wlan1_[^:]*'); do
      $ip add add 10.0.254.$((num++))/24 dev $dev
    done

    $dnsmasq\
    --pid-file=/tmp/dnsmasq_wireless.pid\
    --port=63\
    --conf-file\
    --no-hosts\
    --interface=wlan1*\
    --clear-on-reload\
    --strict-order\
    --listen-address=10.0.254.1\
    --dhcp-range=10.0.254.$((num)),10.0.254.100,60m\
    --dhcp-option=option:router,10.0.254.1\
    --dhcp-leasefile=/var/lib/dnsmasq/hostapd.leases \
    --dhcp-lease-max=50
}

function ver_gte() {
    test "$1" = "`echo -e "$1\n$2" | sort -V | tail -n1`"
}

function write_hostapd_cfg ()
{
    num_ap=8
    echo "# Hostapd configuration for 802.1x client testing

#open
interface=wlan1
bssid=$new_mac
driver=nl80211
ctrl_interface=/var/run/hostapd
ctrl_interface_group=0
ssid=open
hw_mode=g
channel=6
auth_algs=1
wpa=0
country_code=EN

#pskwep
bss=wlan1_pskwep
ssid=wep
channel=1
hw_mode=g
auth_algs=3
ignore_broadcast_ssid=0
wep_default_key=0
wep_key0=\"abcde\"
wep_key_len_broadcast=\"5\"
wep_key_len_unicast=\"5\"
wep_rekey_period=300

#pskwep_len13
bss=wlan1_13pskwep
ssid=wep-2
channel=1
hw_mode=g
auth_algs=3
ignore_broadcast_ssid=0
wep_default_key=0
wep_key0=\"testing123456\"
wep_key_len_broadcast=\"13\"
wep_key_len_unicast=\"13\"
wep_rekey_period=300

#dynwep
bss=wlan1_dynwep
ssid=dynwep
channel=1
hw_mode=g
auth_algs=3
ignore_broadcast_ssid=0
wep_default_key=0
wep_key0=\"abcde\"
wep_key_len_broadcast=5
wep_key_len_unicast=5
wep_rekey_period=300
ieee8021x=1
eapol_version=1
eap_reauth_period=3600
eap_server=1
use_pae_group_addr=1
eap_user_file=$EAP_USERS_FILE
ca_cert=$HOSTAPD_KEYS_PATH/hostapd.ca.pem
dh_file=$HOSTAPD_KEYS_PATH/hostapd.dh.pem
server_cert=$HOSTAPD_KEYS_PATH/hostapd.cert.pem
private_key=$HOSTAPD_KEYS_PATH/hostapd.key.enc.pem
private_key_passwd=redhat

#wpa2
bss=wlan1_wpa2eap
ssid=wpa2-eap
country_code=EN
hw_mode=g
channel=7
auth_algs=3
wpa=3
ieee8021x=1
eapol_version=1
wpa_key_mgmt=WPA-EAP WPA-PSK
rsn_pairwise=CCMP
wpa_passphrase=secret123
eap_reauth_period=3600
eap_server=1
use_pae_group_addr=1
eap_user_file=$EAP_USERS_FILE
ca_cert=$HOSTAPD_KEYS_PATH/hostapd.ca.pem
dh_file=$HOSTAPD_KEYS_PATH/hostapd.dh.pem
server_cert=$HOSTAPD_KEYS_PATH/hostapd.cert.pem
private_key=$HOSTAPD_KEYS_PATH/hostapd.key.enc.pem
private_key_passwd=redhat

#wpa2_pskonly
bss=wlan1_wpa2psk
ssid=wpa2-psk
country_code=EN
hw_mode=g
channel=7
auth_algs=3
wpa=3
wpa_key_mgmt=WPA-PSK
rsn_pairwise=CCMP
wpa_passphrase=secret123

#wpa1eap
bss=wlan1_wpa1eap
ssid=wpa1-eap
country_code=EN
hw_mode=g
channel=7
auth_algs=3
wpa=1
ieee8021x=1
eapol_version=1
wpa_key_mgmt=WPA-EAP
wpa_pairwise=CCMP
eap_reauth_period=3600
eap_server=1
use_pae_group_addr=1
eap_user_file=$EAP_USERS_FILE
ca_cert=$HOSTAPD_KEYS_PATH/hostapd.ca.pem
dh_file=$HOSTAPD_KEYS_PATH/hostapd.dh.pem
server_cert=$HOSTAPD_KEYS_PATH/hostapd.cert.pem
private_key=$HOSTAPD_KEYS_PATH/hostapd.key.enc.pem
private_key_passwd=redhat

#wpa1_pskonly
bss=wlan1_wpa1psk
ssid=wpa1-psk
country_code=EN
hw_mode=g
channel=7
auth_algs=3
wpa=1
wpa_key_mgmt=WPA-PSK
wpa_pairwise=CCMP
wpa_passphrase=secret123
" > $HOSTAPD_CFG

# wpa3 requires wpa_suuplicant >= 2.9
wpa_ver=$(rpm -q wpa_supplicant)
wpa_ver=${wpa_ver#wpa_supplicant-}

if ver_gte $wpa_ver 2.9; then
((num_ap++))
echo "
#wpa3
bss=wlan1_wpa3psk
ssid=wpa3-psk
country_code=EN
hw_mode=g
channel=7
auth_algs=3
wpa=2
wpa_key_mgmt=SAE
rsn_pairwise=CCMP
ieee80211w=2
wpa_passphrase=secret123
" >> $HOSTAPD_CFG

fi

hostapd_ver=$(rpm -q hostapd)
hostapd_ver=${hostapd_ver#hostapd-}
# There is no wpa_supplicant support in Fedoras
if ver_gte $hostapd_ver 2.9-6 && grep -q -e 'release \(8\|9\)' /etc/redhat-release; then
num_ap=$((num_ap+3))
echo "
#wpa3eap
bss=wlan1_wpa3eap
ssid=wpa3-eap
country_code=EN
hw_mode=g
channel=7
auth_algs=3
wpa=2
ieee8021x=1
eapol_version=1
ieee80211w=2
wpa_key_mgmt=WPA-EAP-SUITE-B-192
eap_reauth_period=3600
eap_server=1
use_pae_group_addr=1
eap_user_file=$EAP_USERS_FILE
ca_cert=$HOSTAPD_KEYS_PATH/hostapd.ca.pem
dh_file=$HOSTAPD_KEYS_PATH/hostapd.dh.pem
server_cert=$HOSTAPD_KEYS_PATH/hostapd.cert.pem
private_key=$HOSTAPD_KEYS_PATH/hostapd.key.enc.pem
private_key_passwd=redhat
rsn_pairwise=GCMP-256
group_cipher=GCMP-256
group_mgmt_cipher=BIP-GMAC-256

#wpa3_owe
bss=wlan1_wpa3owe
ssid=wpa3-owe
country_code=EN
hw_mode=g
channel=7
ieee80211w=2
wpa=2
wpa_key_mgmt=OWE
rsn_pairwise=CCMP

#wpa3_owe_transit
bss=wlan1_wpa3owet
ssid=wpa3-owe-transition
country_code=EN
hw_mode=g
owe_transition_ifname=wlan1_wpa3owe

" >> $HOSTAPD_CFG
fi

if ((MANY_AP)); then
  while ((num_ap < MANY_AP)); do
    ((num_ap++))
    echo "
bss=wlan1_open_$num_ap
ssid=open_$num_ap
channel=1
hw_mode=g
auth_algs=1
wpa=0

" >> $HOSTAPD_CFG
  done
fi

# Create a list of users for network authentication, authentication types, and corresponding credentials.
echo "# Create hostapd peap user file
# Phase 1 authentication
\"user\"   MD5     \"password\"
\"test\"   TLS,TTLS,PEAP
# this is for doc_procedures, not to require anonymous identity to be set
\"TESTERS\\test_mschapv2\"  TLS,TTLS,PEAP

# Phase 2 authentication (tunnelled within EAP-PEAP or EAP-TTLS)
\"TESTERS\\test_mschapv2\"   MSCHAPV2    \"password\"  [2]
\"test_md5\"       MD5         \"password\"  [2]
\"test_gtc\"       GTC         \"password\"  [2]
# Tunneled TLS and non-EAP authentication inside the tunnel.
\"test_ttls\"      TTLS-PAP,TTLS-CHAP,TTLS-MSCHAP,TTLS-MSCHAPV2    \"password\"  [2]" > $EAP_USERS_FILE

echo $num_ap > /tmp/nm_wifi_ap_num
}

function copy_certificates ()
{
    # Copy certificates to correct places
    [ -d $HOSTAPD_KEYS_PATH ] || mkdir -p $HOSTAPD_KEYS_PATH
    /bin/cp -rf $CERTS_PATH/server/hostapd* $HOSTAPD_KEYS_PATH

    [ -d $CLIENT_KEYS_PATH ] || mkdir -p $CLIENT_KEYS_PATH
    /bin/cp -rf $CERTS_PATH/client/test_user.*.pem $CLIENT_KEYS_PATH

    /bin/cp -rf $CERTS_PATH/client/test_user.ca.pem /etc/pki/ca-trust/source/anchors
    chown -R test:test $CLIENT_KEYS_PATH
    update-ca-trust extract
}

function restart_services ()
{
    systemctl daemon-reload
    systemctl restart NetworkManager
    systemctl restart wpa_supplicant
}

function start_nm_hostapd ()
{
    local ip="ip"
    local hostapd="hostapd -ddd $HOSTAPD_CFG"
    if $DO_NAMESPACE; then
        ip="ip -n wlan_ns"
        hostapd="ip netns exec wlan_ns $hostapd"
    fi
    systemd-run --unit nm-hostapd $hostapd

    ap_num=$(cat /tmp/nm_wifi_ap_num)
    for i in {1..20}; do
        if [ $($ip -o l | grep wlan1_ | wc -l) == "$ap_num" ]; then
            break;
        fi
        sleep 0.5
    done

    # sleep 10
}

function wireless_hostapd_check ()
{
    need_setup=0
    need_restart=0
    echo "* Checking hostapd"
    if [ ! -e /tmp/nm_wifi_supp_configured ]; then
        echo "Not OK!!"
        need_setup=1
    fi
    echo "* Checking dnsmasqs"
    pid=$(cat /tmp/dnsmasq_wireless.pid)
    if ! pidof dnsmasq |grep -q $pid; then
        echo "Not OK!!"
        need_setup=1
    fi
    echo "* Checking nm-hostapd"
    if ! systemctl is-active nm-hostapd -q; then
        echo "Not OK!!"
        need_setup=1
    fi
    echo "* Checking wlan0"
    if ! nmcli device show wlan0 |grep -q connected; then
        echo "Not OK!!"
        need_setup=1
    fi
    echo "* Checking namespace"
    namespace=false
    if ip netns exec wlan_ns true; then
        namespace=true
    fi
    if [ $namespace != $DO_NAMESPACE ]; then
        echo "Not OK!!"
        need_setup=1
    fi

    echo "* Checking crypto"
    crypto="default"
    if [ -f /tmp/nm_wifi_supp_legacy_crypto ]; then
      crypto="legacy"
    fi
    if [ $crypto != $CRYPTO ]; then
        if grep -q "release 9" /etc/redhat-release; then
            echo "Not OK!! (restart suffices)"
            need_restart=1
        fi
    fi

    echo "* Checking 'many_ap'"
    many_ap=$(sed -n 's/.*bss=wlan1_open_//p' $HOSTAPD_CFG | tail -n1)
    if [ "$many_ap" != "$MANY_AP" ]; then
      echo "Not OK!! - need $MANY_AP, found $many_ap"
      need_setup=1
    fi

    if [ $need_setup -eq 1 ]; then
        rm -rf /tmp/nm_wifi_supp_configured
        wireless_hostapd_teardown
        return 1
    fi

    if [ $need_restart -eq 1 ]; then
        if [ "$CRYPTO" == "default" ]; then
          rm -rf /tmp/nm_wifi_supp_legacy_crypto
        else
          touch /tmp/nm_wifi_supp_legacy_crypto
        fi
        restart_services
        systemctl stop nm-hostapd
        pkill -F /tmp/dnsmasq_wireless.pid
        start_ap

    fi

    return 0
}

function prepare_test_bed ()
{
    # Install haveged to increase entropy
    yum -y install haveged
    systemctl restart haveged

    if $DO_NAMESPACE; then
        local major_ver=$(cat /etc/redhat-release | grep -o "release [0-9]*" | sed 's/release //')
        local policy_file="contrib/selinux-policy/hostapd_wireless_$major_ver.pp"
        (semodule -l | grep -q hostapd_wireless) || semodule -i $policy_file || echo "ERROR: unable to load selinux policy !!!"
        ip netns add wlan_ns
    fi

    if [ "$CRYPTO" == "legacy" ]; then
        touch /tmp/nm_wifi_supp_legacy_crypto
    else
        rm -rf /tmp/nm_wifi_supp_legacy_crypto
    fi

    # Disable mac randomization to avoid rhbz1490885
    echo -e "[device-wifi]\nwifi.scan-rand-mac-address=no" > /etc/NetworkManager/conf.d/99-wifi.conf
    echo -e "[connection-wifi]\nwifi.cloned-mac-address=preserve" >> /etc/NetworkManager/conf.d/99-wifi.conf
    echo -e "[device]\nmatch-device=interface-name:wlan1\nmanaged=0" >> /etc/NetworkManager/conf.d/99-wifi.conf

    if ! lsmod | grep -q -w mac80211_hwsim; then
        modprobe mac80211_hwsim
        sleep 5
    fi
    if ! lsmod | grep -q -w mac80211_hwsim; then
        echo "Error. Cannot load module \"mac80211_hwsim\"." >&2
        return 1
    fi

    restart_services
    sleep 5
    if ! systemctl -q is-active wpa_supplicant; then
        echo "Error. Cannot start the service for WPA supplicant." >&2
        return 1
    fi

    # zero last two bits in wlan1 MAC address
    new_mac=$(ip link show dev wlan1 | grep -o 'link/ether [^ ]*' | sed 's/^.* //;s/:..$/:00/')
    ip link set dev wlan1 down
    ip link set dev wlan1 address "$new_mac"
    ip link set dev wlan1 up

    if $DO_NAMESPACE; then
        phy=$(get_phy wlan1)
        iw phy $phy set netns name wlan_ns
        ip -n wlan_ns add add 10.0.254.1/24 dev wlan1
    else
        ip add add 10.0.254.1/24 dev wlan1
    fi
    sleep 5

}

function wireless_hostapd_setup ()
{
    set +x

    echo "Configuring hostapd 802.1x server..."

    rm -rf /tmp/wireless_hostapd_check.txt
    if  wireless_hostapd_check; then
        echo "OK. Configuration has already been done."
        touch /tmp/wireless_hostapd_check.txt
        return 0
    fi

    prepare_test_bed
    write_hostapd_cfg
    copy_certificates

    set -e

    start_ap

    touch /tmp/nm_wifi_supp_configured
}

function start_ap () {
    # Start 802.1x authentication and built-in RADIUS server.
    # Start hostapd as a service via systemd-run using configuration wifi adapters
    start_nm_hostapd
    if ! systemctl -q is-active nm-hostapd; then
        echo "Error. Cannot start the service for hostapd." >&2
        return 1
    fi

    start_dnsmasq
    pid=$(cat /tmp/dnsmasq_wireless.pid)
    if ! pidof dnsmasq | grep -q $pid; then
        echo "Error. Cannot start dnsmasq as DHCP server." >&2
        return 1
    fi

    # do not lower this as first test may fail then
    sleep 5
}

function wireless_hostapd_teardown ()
{
    set -x
    ip netns del wlan_ns
    pkill -F /tmp/dnsmasq_wireless.pid
    if systemctl --quiet is-failed nm-hostapd; then
        systemctl reset-failed nm-hostapd
    fi
    systemctl stop nm-hostapd
    nmcli device set wlan1 managed on
    ip addr flush dev wlan1
    modprobe -r mac80211_hwsim
    [ -f /run/hostapd/wlan1 ] && rm -rf /run/hostapd/wlan1
    rm -rf /etc/NetworkManager/conf.d/99-wifi.conf
    systemctl reload NetworkManager
    rm -rf /tmp/nm_wifi_supp_configured

}
if [ "$1" == "teardown" ]; then
    wireless_hostapd_teardown
    echo "System's state returned prior to hostapd's config."
else
    # If hostapd's config fails then restore initial state.
    echo "Configure and start hostapd..."
    # Set DO_NAMESPACE to true if "namespace" in arguments
    DO_NAMESPACE=false
    MANY_AP=
    CRYPTO="default"

    for arg in "$@"; do
      if [[ "$arg" == "namespace" ]]; then
          DO_NAMESPACE=true
      fi
      if [[ "$arg" == "legacy_crypto" ]]; then
        CRYPTO="legacy"
      fi
      if [[ "$arg" == "many_ap="* ]]; then
        MANY_AP=${arg#many_ap=}
      fi
    done

    CERTS_PATH=${1:?"Error. Path to certificates is not specified."}

    wireless_hostapd_setup $1; RC=$?
    if [ $RC -eq 0 ]; then
        echo "hostapd started successfully."
    else
        echo "Error. Failed to start hostapd." >&2
        exit 1
    fi
fi
