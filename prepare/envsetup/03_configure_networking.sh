configure_networking () {
    [ -e /tmp/nm_eth_configured ] && return
    # Prepare all devices

    # unload modules after NM build
    modprobe -r ip_gre
    modprobe -r ipip
    modprobe -r ip6_gre
    modprobe -r sit
    modprobe -r ip_tunnel
    modprobe -r ip6_tunnel
    modprobe -r ip_vti
    modprobe -r ip6_vti

    # Load dummy module with numdummies=0 to prevent dummyX device creation by kernel
    modprobe dummy numdummies=0

    # Install server package
    yum -y install NetworkManager-config-server

    # If we have custom built packages let's store it's dir
    dir="$(find /root /tmp -name nm-build)"
    if test $dir ; then
        echo "$dir/NetworkManager/contrib/fedora/rpm/latest0/RPMS/" > /tmp/nm-builddir
    fi

    # Do we have special HW needs?
    wlan=0
    dcb_inf_wol_sriov=0
    if [[ $1 == *sriov_* ]]; then
        dcb_inf_wol_sriov=1
    fi
    if [[ $1 == *dcb_* ]]; then
        dcb_inf_wol_sriov=1
    fi
    if [[ $1 == *inf_* ]]; then
        dcb_inf_wol_sriov=1
    fi
    if [[ $1 == *wol_* ]]; then
        dcb_inf_wol_sriov=1
    fi
    if [[ $1 == *dpdk_* ]]; then
        dcb_inf_wol_sriov=1
    fi
    if [[ $1 == *nmcli_wifi* || $1 == *nmtui_wifi_* ]]; then
        wlan=1
    fi

    # We need this if yes
    if [ $dcb_inf_wol_sriov -eq 1 ]; then
        touch /tmp/nm_dcb_inf_wol_sriov_configured
    fi

    # We need wlanX and orig-wlanX for non wlan tests
    NUM=0
    for DEV in `nmcli device | grep wifi | awk {'print $1'}`; do
        ip link set $DEV down
        if [ $wlan -eq 1 ]; then
            ip link set $DEV name wlan$NUM
            ip link set wlan$NUM up
        else
            ip link set $DEV name orig-wlan$NUM
            ip link set orig-wlan$NUM up
        fi
        NUM=$(($NUM+1))
    done

    # Do we need virtual eth setup?
    veth=0
    if [ $wlan -eq 0 ]; then
        if [ $dcb_inf_wol_sriov -eq 0 ]; then
            for X in $(seq 0 10); do
                if ! nmcli -f DEVICE -t device |grep eth${X}$; then
                    veth=1
                    break
                else
                    # Setting ipv6 dad to 0 as parallel test on different machines
                    # there can be dad connected failures
                    sysctl net.ipv6.conf.eth$X.accept_dad=0
                fi
            done

        fi
    fi

    # Do we have keyfiles or ifcfg plugins enabled?
    DEV=$(nmcli -t d | grep :ethernet | grep :connected | awk -F':' '{print $1}' | head -n 1)
    if test $(nmcli -t -f FILENAME,DEVICE,ACTIVE connection|grep "$DEV:yes"| grep system-connections); then
        touch /tmp/nm_plugin_keyfiles
        # Remove all ifcfg files as we don't need them
        rm -rf /etc/sysconfig/network-scripts/*
    fi

    # Comment out all mentions of plugins
    for file in `grep -rl '^\s*plugins\s*=' /etc/NetworkManager/`; do
        sed -i "s/\(^\s*plugins\s*=\)/#\1/" "$file"
    done

    # Drop compiled in defaults into proper config
    if grep -q -e 'release 8' /etc/redhat-release; then
        echo -e "[main]\ndhcp=nettools\nplugins=ifcfg-rh,keyfile" >> /etc/NetworkManager/conf.d/95-nmci-test.conf
    elif grep -q -e 'release 7' /etc/redhat-release; then
        echo -e "[main]\ndhcp=dhclient\nplugins=ifcfg-rh,keyfile" >> /etc/NetworkManager/conf.d/95-nmci-test.conf
    elif grep -q -e 'release 9' /etc/redhat-release; then
        echo -e "[main]\ndhcp=nettools\nplugins=keyfile,ifcfg-rh" >> /etc/NetworkManager/conf.d/95-nmci-test.conf
    elif grep -q -e 'Fedora' /etc/redhat-release; then
        echo -e "[main]\ndhcp=nettools\nplugins=keyfile,ifcfg-rh" >> /etc/NetworkManager/conf.d/95-nmci-test.conf
    fi

    # Remove dnsmasq's mapping to lo only RHEL9 and Fedora 33+
    sed -i 's/^interface=lo/# interface=lo/' /etc/dnsmasq.conf

    # Do veth setup if yes
    if [ $veth -eq 1 ]; then
        echo $(pwd)
        sh prepare/vethsetup.sh setup

        # Copy this once more just to be sure it's there as it's really crucial
        testeth0_file="$(nmcli -t -f FILENAME,NAME con show | grep ':testeth0' | sed 's/:testeth0//' )"
        if [ ! -e /tmp/testeth0 ] ; then
            yes | cp -rf "$testeth0_file" /tmp/testeth0
        fi

        cat /tmp/testeth0

        touch /tmp/nm_veth_configured

    else
        # Profiles tuning
        if [ $wlan -eq 0 ]; then
            if [ $dcb_inf_wol_sriov -eq 0 ]; then
                nmcli connection add type ethernet ifname eth0 con-name testeth0
                nmcli connection delete eth0
                nmcli connection up id testeth0
                nmcli con show -a
                for X in $(seq 1 10); do
                    nmcli connection add type ethernet con-name testeth$X ifname eth$X autoconnect no
                    nmcli connection delete eth$X
                done
                nmcli connection modify testeth10 ipv6.method auto
            fi

            # THIS NEEDS TO BE DONE HERE AS DONE SEPARATELY IN VETHSETUP FOR RECREATION REASONS
            nmcli c modify testeth0 ipv4.may-fail no
            nmcli c modify testeth0 ipv4.route-metric 99 ipv6.route-metric 99
            sleep 1
            # Copy final connection to /tmp/testeth0 for later in test usage
            testeth0_file="$(nmcli -t -f FILENAME,NAME con show | grep ':testeth0' | sed 's/:testeth0//' )"
            if [ ! -e /tmp/testeth0 ] ; then
                yes | cp -rf "$testeth0_file" /tmp/testeth0
            fi
        fi

        if [ $wlan -eq 1 ]; then
            # obtain valid certificates
            mkdir /tmp/certs
            wget http://hpe-dl380pgen9-02.wlan.rhts.eng.bos.redhat.com/ca.pem -O /tmp/certs/eaptest_ca_cert.pem
            wget http://hpe-dl380pgen9-02.wlan.rhts.eng.bos.redhat.com/client.pem -O /tmp/certs/client.pem
            touch /tmp/nm_wifi_configured
        fi
    fi

    systemctl stop firewalld
    systemctl mask firewalld mptcpd

    nmcli c u testeth0

    systemctl daemon-reload
    systemctl restart NetworkManager
    sleep 5
    nmcli con del "System eth0"
    nmcli con up testeth0; rc=$?
    if [ $rc -ne 0 ]; then
        sleep 20
        nmcli con up testeth0
    fi

    touch /tmp/nm_eth_configured
}
