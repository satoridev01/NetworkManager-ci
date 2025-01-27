 Feature: nmcli: sriov

    # Please do use tags as follows:
    # @bugzilla_link (rhbz123456)
    # @version_control (ver+=1.10,rhelver-=8,fedoraver+30,[not_with_]rhel_pkg,[not_with_]fedora_pkg) - see version_control.py
    # @other_tags (see environment.py)
    # @test_name (compiled from scenario name)
    # Scenario:


    ################# Test set with VF enabled via config file ######################################

    @rhbz1398934
    @ver+=1.8.0
    @sriov
    @sriov_enable
    Scenario: NM - sriov - enable sriov in config
    When "Exactly" "1" lines with pattern "p4p1" are visible with command "nmcli dev"
    * Prepare "98-sriov.conf" config for "p4p1" device with "63" VFs
    When "Exactly" "64" lines with pattern "p4p1" are visible with command "nmcli dev" in "40" seconds


    @rhbz1398934
    @ver+=1.33.3
    @sriov
    @sriov_enable_with_deployed_profile
    Scenario: NM - sriov - enable sriov in config
    When "Exactly" "1" lines with pattern "p4p1" are visible with command "nmcli dev"
    * Execute "nmcli device connect p4p1"
    When " connected" is visible with command "nmcli  device |grep p4p1"
    * Prepare "98-sriov.conf" config for "p4p1" device with "4" VFs
    When "Exactly" "5" lines with pattern "p4p1" are visible with command "nmcli dev" in "40" seconds


    @rhbz1398934
    @ver+=1.8.0
    @sriov
    @sriov_disable
    Scenario: NM - sriov - disable sriov in config
    When "Exactly" "1" lines with pattern "p4p1" are visible with command "nmcli dev"
    * Prepare "95-nmci-sriov-conf" config for "p4p1" device with "2" VFs
    When "Exactly" "3" lines with pattern "p4p1" are visible with command "nmcli dev" in "10" seconds
    * Prepare "95-nmci-sriov-conf" config for "p4p1" device with "0" VFs
    When "Exactly" "1" lines with pattern "p4p1" are visible with command "nmcli dev" in "20" seconds


    @rhbz1398934
    @ver+=1.8.0
    @sriov
    @sriov_connect
    Scenario: NM - sriov - connect virtual sriov device
    When "Exactly" "1" lines with pattern "p4p1" are visible with command "nmcli dev"
    * Prepare "95-nmci-sriov-conf" config for "p4p1" device with "2" VFs
    * Add "ethernet" connection named "sriov" for device "p4p1_0" with options
          """
          autoconnect no
          ipv4.method manual
          ipv4.address 1.2.3.4/24
          """
    * Add "ethernet" connection named "sriov_2" for device "p4p1" with options
          """
          autoconnect no
          ipv4.method manual
          ipv4.address 1.2.3.5/24
          """
    When "p4p1_0" is visible with command "nmcli device" in "5" seconds
    * Bring "up" connection "sriov"
    * Bring "up" connection "sriov_2"
    Then "activated" is visible with command "nmcli -g GENERAL.STATE con show sriov" in "5" seconds
     And "activated" is visible with command "nmcli -g GENERAL.STATE con show sriov_2" in "5" seconds


    @rhbz1398934
    @ver+=1.8.0
    @sriov
    @sriov_autoconnect
    Scenario: NM - sriov - autoconnect virtual sriov device
    When "Exactly" "1" lines with pattern "p4p1" are visible with command "nmcli dev"
    * Prepare "95-nmci-sriov-conf" config for "p4p1" device with "2" VFs
    * Add "ethernet" connection named "sriov" for device "p4p1_0" with options
          """
          ipv4.method manual
          ipv4.address 1.2.3.4/24
          """
    * Add "ethernet" connection named "sriov_2" for device "p4p1" with options
          """
          ipv4.method manual
          ipv4.address 1.2.3.5/24
          """
    When "p4p1_0" is visible with command "nmcli device" in "5" seconds
    Then "activated" is visible with command "nmcli -g GENERAL.STATE con show sriov" in "5" seconds
     And "activated" is visible with command "nmcli -g GENERAL.STATE con show sriov_2" in "5" seconds


    @rhbz1398934
    @ver+=1.8.0
    @sriov
    @sriov_connect_externally
    Scenario: NM - sriov - see externally connected sriov device
    When "Exactly" "1" lines with pattern "p4p1" are visible with command "nmcli dev"
    * Execute "echo 2 > /sys/class/net/p4p1/device/sriov_numvfs"
    When "p4p1_0" is visible with command "nmcli device" in "5" seconds
    * Execute "ip add add 192.168.1.2/24 dev p4p1_0"
    Then "192.168.1.2/24" is visible with command "nmcli con sh p4p1_0 |grep IP4" in "2" seconds


    # @rhbz1398934
    # @ver+=1.8.0
    # @sriov
    # @sriov_set_mtu
    # Scenario: NM - sriov - change mtu
    # When "Exactly" "10" lines are visible with command "nmcli dev"
    # * Prepare "95-nmci-sriov-conf" config for "p4p1" device with "2" VFs
    # * Add "ethernet" connection named "sriov" for device "enp5s16f1" with options
    #    """
    #    ipv4.method manual
    #    ipv4.address 1.2.3.4/24
    #    802-3-ethernet.mtu 9000
    #    """
    # Then "9000" is visible with command "ip a s enp5s16f1" in "2" seconds


    @rhbz1398934
    @ver+=1.8.0
    @sriov
    @sriov_reboot_persistence
    Scenario: NM - sriov - reboot persistence
    When "Exactly" "1" lines with pattern "p4p1" are visible with command "nmcli dev"
    * Prepare "95-nmci-sriov-conf" config for "p4p1" device with "2" VFs
    * Add "ethernet" connection named "sriov" for device "p4p1_0" with options
          """
          ipv4.method manual
          ipv4.address 1.2.3.4/24
          """
    * Add "ethernet" connection named "sriov_2" for device "p4p1" with options
          """
          ipv4.method manual
          ipv4.address 1.2.3.5/24
          """
    When "p4p1_1" is visible with command "nmcli device" in "5" seconds
    * Bring "down" connection "sriov"
    * Bring "down" connection "sriov_2"
    * Reboot
    Then "activated" is visible with command "nmcli -g GENERAL.STATE con show sriov" in "25" seconds
     And "activated" is visible with command "nmcli -g GENERAL.STATE con show sriov_2" in "25" seconds


    @rhbz1555013
    @ver+=1.14.0
    @sriov
    @sriov_con_drv_bond_with_config
    Scenario: nmcli - sriov - drv - bond with VF and ethernet reboot persistence
    * Prepare "95-nmci-sriov-conf" config for "p4p1" device with "1" VFs
    * Add "bond" connection named "sriov_bond0" for device "bond0" with options
          """
          ipv4.method manual
          ipv4.address 1.2.3.4/24
          bond.options 'mode=active-backup,primary=p4p1_0,miimon=100,fail_over_mac=2'
          """
    When "p4p1_0" is visible with command "nmcli device" in "5" seconds
    * Add slave connection for master "bond0" on device "p4p1_0" named "sriov_bond0.0"
    * Add slave connection for master "bond0" on device "em3" named "sriov_bond0.1"
    When "Bonding Mode: fault-tolerance \(active-backup\) \(fail_over_mac follow\)\s+Primary Slave: p4p1_0 \(primary_reselect always\)\s+Currently Active Slave: p4p1_0" is visible with command "cat /proc/net/bonding/bond0"
    When Check bond "bond0" link state is "up"
    * Execute "ip link set dev p4p1_0 down"
    Then "Bonding Mode: fault-tolerance \(active-backup\) \(fail_over_mac follow\)\s+Primary Slave: p4p1_0 \(primary_reselect always\)\s+Currently Active Slave: em3" is visible with command "cat /proc/net/bonding/bond0" in "20" seconds
    Then Check bond "bond0" link state is "up"
    * Reboot
    When "Bonding Mode: fault-tolerance \(active-backup\) \(fail_over_mac follow\)\s+Primary Slave: p4p1_0 \(primary_reselect always\)\s+Currently Active Slave: p4p1_0" is visible with command "cat /proc/net/bonding/bond0" in "20" seconds
    When Check bond "bond0" link state is "up"
    * Execute "ip link set dev p4p1_0 down"
    Then "Bonding Mode: fault-tolerance \(active-backup\) \(fail_over_mac follow\)\s+Primary Slave: p4p1_0 \(primary_reselect always\)\s+Currently Active Slave: em3" is visible with command "cat /proc/net/bonding/bond0" in "20" seconds
    Then Check bond "bond0" link state is "up"


    ################# Test set with VF driver and device ######################################

    @rhbz1555013
    @ver+=1.14.0
    @sriov
    @sriov_con_drv_add_VF
    Scenario: nmcli - sriov - drv - add 1 VF
    * Add "ethernet" connection named "sriov" for device "p4p1" with options "sriov.total-vfs 1 autoconnect no"
    * Bring "up" connection "sriov"
    * Add "ethernet" connection named "sriov_2" for device "p4p1_0" with options
          """
          ipv4.method manual
          ipv4.address 1.2.3.4/24
          autoconnect no
          """
    * Bring "up" connection "sriov_2"
    Then "1" is visible with command "cat /sys/class/net/p4p1/device/sriov_numvfs"
    And " connected" is visible with command "nmcli  device |grep p4p1_0"


    @rhbz1555013 @rhbz1651578
    @ver+=1.14.0
    @sriov
    @sriov_con_drv_add_64VFs
    Scenario: nmcli - sriov - drv - add 64 VFs
    * Add "ethernet" connection named "sriov" for device "p4p1" with options "sriov.total-vfs 64 autoconnect no"
    * Bring "up" connection "sriov"
    When "63" is visible with command "cat /sys/class/net/p4p1/device/sriov_numvfs"
    And "disconnected" is visible with command "nmcli  device |grep p4p1_62" in "120" seconds
    And "disconnected" is visible with command "nmcli  device |grep p4p1_31"
    And "disconnected" is visible with command "nmcli  device |grep p4p1_0"
    * Add "ethernet" connection named "sriov_2" for device "''" with options
          """
          match.interface-name p4p1_*
          connection.multi-connect multiple
          """
    Then " connected" is visible with command "nmcli  device |grep p4p1_62" in "45" seconds
    And " connected" is visible with command "nmcli  device |grep p4p1_31" in "45" seconds
    And " connected" is visible with command "nmcli  device |grep p4p1_0" in "45" seconds


    @rhbz1651576 @rhbz1659514
    @ver+=1.14.0
    @sriov
    @sriov_con_drv_set_VF_to_0
    Scenario: nmcli - sriov - set VF number to 0
    * Add "ethernet" connection named "sriov" for device "p4p1" with options "sriov.total-vfs 1 autoconnect no"
    * Execute "nmcli connection modify sriov sriov.total-vfs 0"
    * Bring "up" connection "sriov"
    Then "1" is not visible with command "cat /sys/class/net/p4p1/device/sriov_numvfs"
    And "vf 0" is not visible with command "ip link show dev p4p1 |grep 'vf 0'"
    And "p4p1_0" is not visible with command "nmcli  device" in "10" seconds


    @rhbz1555013
    @ver+=1.14.0
    @sriov
    @sriov_con_drv_add_VF_mac_and_trust
    Scenario: nmcli - sriov - drv - add 1 VF with mac and trust
    * Add "ethernet" connection named "sriov" for device "p4p1" with options
          """
          sriov.vfs '0 mac=00:11:22:33:44:99 trust=true'
          sriov.total-vfs 1
          autoconnect no
          """
    * Bring "up" connection "sriov"
    * Add "ethernet" connection named "sriov_2" for device "p4p1_0" with options
          """
          ipv4.method manual
          ipv4.address 1.2.3.4/24
          autoconnect no
          """
    * Bring "up" connection "sriov_2"
    Then "1" is visible with command "cat /sys/class/net/p4p1/device/sriov_numvfs"
    And " connected" is visible with command "nmcli  device |grep p4p1_0"
    And "00:11:22:33:44:99" is visible with command "ip a s p4p1_0"
    And "trust on" is visible with command " ip l show dev p4p1"


    @rhbz1555013
    @xfail @rhbz1852442
    @ver+=1.14.0
    @sriov
    @sriov_con_drv_add_VF_mtu
    Scenario: nmcli - sriov - drv - add 1 VF with mtu
    * Add "ethernet" connection named "sriov" for device "p4p1" with options
          """
          sriov.vfs '0 mac=00:11:22:33:44:99 trust=true'
          sriov.total-vfs 1
          802-3-ethernet.mtu 9000
          autoconnect no
          """
    * Bring "up" connection "sriov"
    * Add "ethernet" connection named "sriov_2" for device "p4p1_0" with options
          """
          ipv4.method manual
          ipv4.address 1.2.3.4/24
          802-3-ethernet.mtu 9000
          autoconnect no
          """
     * Bring "up" connection "sriov_2"
    Then " connected" is visible with command "nmcli  device |grep p4p1_0"
    And "00:11:22:33:44:99" is visible with command "ip a s p4p1_0"
    And "9000" is visible with command "ip a s p4p1_0" in "10" seconds


    @rhbz1555013
    @ver+=1.14.0
    @sriov @tcpdump
    @sriov_con_drv_add_VF_vlan
    Scenario: nmcli - sriov - drv - add 1 VF with vlan Q
    * Add "ethernet" connection named "sriov" for device "p4p1" with options
          """
          sriov.vfs '0 vlans=100.2.q'
          sriov.total-vfs 1
          autoconnect no
          """
    * Bring "up" connection "sriov"
    * Add "ethernet" connection named "sriov_2" for device "p4p1_0" with options
          """
          ipv4.method manual
          ipv4.address 1.2.3.4/24
          autoconnect no
          """
    * Run child "tcpdump -n -i p4p1 -xxvv -e > /tmp/tcpdump.log"
    When "empty" is not visible with command "file /tmp/tcpdump.log" in "20" seconds
    * Bring "up" connection "sriov_2"
    Then "802.1Q.*vlan 100, p 2" is visible with command "grep 100 /tmp/tcpdump.log" in "20" seconds
    * Execute "pkill tcpdump"


    # Not working under RHEL8 as protocol seems to be unsupported
    # @rhbz1555013
    # @ver+=1.14.0
    # @sriov @tcpdump
    # @sriov_con_drv_add_VF_vlan_ad
    # Scenario: nmcli - sriov - drv - add 1 VF with vlan AD
    # * Add "ethernet" connection named "sriov" for device "p4p1" with options
    #    """
    #    sriov.vfs '0 vlans=100.2.ad'
    #    sriov.total-vfs 1
    #    """
    # * Bring "up" connection "sriov"
    # * Add "ethernet" connection named "sriov_2" for device "p4p1_0" with options
    #    """
    #    ipv4.method manual
    #    ipv4.address 1.2.3.4/24
    #    """
    # * Run child "tcpdump -n -i p4p1 -xxvv -e > /tmp/tcpdump.log"
    # When "empty" is not visible with command "file /tmp/tcpdump.log" in "20" seconds
    # * Bring "up" connection "sriov_2"
    # Then "802.1AD.*vlan 100, p 2" is visible with command "cat /tmp/tcpdump.log" in "20" seconds
    # * Execute "pkill tcpdump"


    @rhbz1555013
    @ver+=1.14.0
    @sriov
    @sriov_con_drv_add_VF_trust_on
    Scenario: nmcli - sriov - drv - add 1 VF with trust on
    * Add "ethernet" connection named "sriov" for device "p4p1" with options
          """
          sriov.vfs '0 mac=00:11:22:33:44:99 trust=true'
          sriov.total-vfs 1
          """
    * Add "ethernet" connection named "sriov_2" for device "p4p1_0" with options
          """
          ipv4.method manual
          ipv4.address 1.2.3.4/24
          """
    When " connected" is visible with command "nmcli  device |grep p4p1_0"
    * Execute "ip link set dev p4p1_0 address 00:11:22:33:44:55"
    Then "trust on" is visible with command " ip link show p4p1"
    And "00:11:22:33:44:55" is visible with command "ip a s p4p1_0"


    @rhbz1555013
    @ver+=1.14.0
    @sriov
    @sriov_con_drv_add_VF_trust_off
    Scenario: nmcli - sriov - drv - add 1 VF with trust off
    * Add "ethernet" connection named "sriov" for device "p4p1" with options
          """
          sriov.vfs '0 mac=00:11:22:33:44:99 trust=false'
          sriov.total-vfs 1
          """
    * Add "ethernet" connection named "sriov_2" for device "p4p1_0" with options
          """
          ipv4.method manual
          ipv4.address 1.2.3.4/24
          """
    When " connected" is visible with command "nmcli  device |grep p4p1_0"
    # It may or may not fail (dependent on ip version and kernel)
    * Execute "ip link set dev p4p1_0 address 00:11:22:33:44:55 || true"
    Then "trust off" is visible with command " ip link show p4p1"
    And "00:11:22:33:44:55" is not visible with command "ip a s p4p1_0"


    @rhbz1555013
    @ver+=1.14.0
    @sriov
    @sriov_con_drv_add_VF_spoof_off
    Scenario: nmcli - sriov - drv - add 1 VF without spoof check
    * Add "ethernet" connection named "sriov" for device "p4p1" with options
          """
          sriov.vfs '0 mac=00:11:22:33:44:55 spoof-check=false'
          sriov.total-vfs 1
          """
    * Add "ethernet" connection named "sriov_2" for device "p4p1_0" with options
          """
          ipv4.method manual
          ipv4.address 1.2.3.4/24
          """
    When " connected" is visible with command "nmcli  device |grep p4p1_0"
    Then "spoof checking off" is visible with command " ip l show dev p4p1"


    @rhbz1555013
    @ver+=1.14.0
    @sriov
    @sriov_con_drv_add_VF_spoof
    Scenario: nmcli - sriov - drv - add 1 VF with spoof check
    * Add "ethernet" connection named "sriov" for device "p4p1" with options
          """
          sriov.vfs '0 mac=00:11:22:33:44:55 spoof-check=true'
          sriov.total-vfs 1
          """
    # * Bring "up" connection "sriov"
    * Add "ethernet" connection named "sriov_2" for device "p4p1_0" with options
          """
          ipv4.method manual
          ipv4.address 1.2.3.4/24
          """
    When " connected" is visible with command "nmcli  device |grep p4p1_0"
    Then "spoof checking on" is visible with command " ip l show dev p4p1"


    @rhbz1555013
    @ver+=1.14.0
    @sriov @firewall
    @sriov_con_drv_add_VF_firewalld
    Scenario: nmcli - sriov - drv - add 1 VF with firewall zone
    * Add "ethernet" connection named "sriov" for device "p4p1" with options
          """
          sriov.vfs '0 vlans=100.2.q'
          sriov.total-vfs 1
          autoconnect no
          """
    * Bring "up" connection "sriov"
    * Add "ethernet" connection named "sriov_2" for device "p4p1_0" with options
          """
          ipv4.method manual
          ipv4.address 1.2.3.4/24
          connection.zone work
          autoconnect no
          """
    * Bring "up" connection "sriov_2"
    Then "1" is visible with command "cat /sys/class/net/p4p1/device/sriov_numvfs"
    And " connected" is visible with command "nmcli  device |grep p4p1_0"
    Then "work\s+interfaces: p4p1_0" is visible with command "firewall-cmd --get-active-zones"



    @rhbz1555013
    @ver+=1.14.0
    @sriov
    @sriov_con_drv_bond
    Scenario: nmcli - sriov - drv - add 2VFs bond on 2PFs
    * Add "ethernet" connection named "sriov" for device "p4p1" with options
          """
          sriov.vfs '0 mac=00:11:22:33:44:55 trust=true'
          sriov.total-vfs 1
          """
    When "p4p1\:ethernet\:connected\:sriov" is visible with command "nmcli -t device" in "15" seconds
    * Add "bond" connection named "sriov_bond0" for device "bond0" with options
          """
          ipv4.method manual
          ipv4.address 1.2.3.4/24
          bond.options 'mode=active-backup,primary=p4p1_0,miimon=100,fail_over_mac=2'
          """
    * Add slave connection for master "bond0" on device "p4p1_0" named "sriov_bond0.0"
    * Add slave connection for master "bond0" on device "em3" named "sriov_bond0.1"
    When "Bonding Mode: fault-tolerance \(active-backup\) \(fail_over_mac follow\)\s+Primary Slave: p4p1_0 \(primary_reselect always\)\s+Currently Active Slave: p4p1_0" is visible with command "cat /proc/net/bonding/bond0"
    When Check bond "bond0" link state is "up"
    * Execute "ip link set dev p4p1_0 down"
    Then "Bonding Mode: fault-tolerance \(active-backup\) \(fail_over_mac follow\)\s+Primary Slave: p4p1_0 \(primary_reselect always\)\s+Currently Active Slave: em3" is visible with command "cat /proc/net/bonding/bond0" in "20" seconds
    Then Check bond "bond0" link state is "up"
    Then "00:11:22:33:44:55" is visible with command "ip a s bond0"
    * Reboot
    When "Bonding Mode: fault-tolerance \(active-backup\) \(fail_over_mac follow\)\s+Primary Slave: p4p1_0 \(primary_reselect always\)\s+Currently Active Slave: p4p1_0" is visible with command "cat /proc/net/bonding/bond0" in "20" seconds
    When Check bond "bond0" link state is "up"
    * Execute "ip link set dev p4p1_0 down"
    Then "Bonding Mode: fault-tolerance \(active-backup\) \(fail_over_mac follow\)\s+Primary Slave: p4p1_0 \(primary_reselect always\)\s+Currently Active Slave: em3" is visible with command "cat /proc/net/bonding/bond0" in "20" seconds
    Then Check bond "bond0" link state is "up"


    ################# Test set WITHOUT VF driver (just inder PF device) ######################################

    @rhbz1555013
    @ver+=1.14.0 @rhelver+=8
    @sriov
    @sriov_con_add_VF
    Scenario: nmcli - sriov - add 1 VF
    * Add "ethernet" connection named "sriov" for device "p4p1" with options
          """
          sriov.total-vfs 1
          sriov.autoprobe-drivers false
          """
    Then "1" is visible with command "cat /sys/class/net/p4p1/device/sriov_numvfs"
    And "vf 0" is visible with command "ip link show dev p4p1 |grep 'vf 0'"


    @rhbz1651576
    @ver+=1.14.0 @rhelver+=8
    @sriov
    @sriov_con_set_VF_to_0
    Scenario: nmcli - sriov - set VF number to 0
    * Add "ethernet" connection named "sriov" for device "p4p1" with options
          """
          sriov.total-vfs 1
          sriov.autoprobe-drivers false
          """
    * Execute "nmcli connection modify sriov sriov.total-vfs 0"
    # Workaround for 1772960
    * Wait for "2" seconds
    * Bring "up" connection "sriov"
    Then "1" is not visible with command "cat /sys/class/net/p4p1/device/sriov_numvfs"
    And "vf 0" is not visible with command "ip link show dev p4p1 |grep 'vf 0'"


    @rhbz1555013
    @ver+=1.14.0 @rhelver+=8
    @sriov
    @sriov_con_add_VF_mac_and_trust
    Scenario: nmcli - sriov - add 1 VF with mac
    * Add "ethernet" connection named "sriov" for device "p4p1" with options
          """
          sriov.vfs '0 mac=00:11:22:33:44:99'
          sriov.total-vfs 1
          sriov.autoprobe-drivers false
          """
    Then "1" is visible with command "cat /sys/class/net/p4p1/device/sriov_numvfs"
    And "00:11:22:33:44:99" is visible with command "ip link show dev p4p1 |grep 'vf 0'"


    @rhbz1555013
    @ver+=1.14.0 @rhelver+=8
    @sriov @tcpdump
    @sriov_con_add_VF_vlan
    Scenario: nmcli - sriov - add 1 VF with vlan Q
    * Run child "tcpdump -n -i p4p1 -xxvv -e > /tmp/tcpdump.log"
    When "empty" is not visible with command "file /tmp/tcpdump.log" in "20" seconds
    * Add "ethernet" connection named "sriov" for device "p4p1" with options
          """
          sriov.vfs '0 vlans=100.2.q'
          sriov.total-vfs 1
          sriov.autoprobe-drivers false
          """
    Then "vlan 100, qos 2" is visible with command "ip link show p4p1 |grep 'vf 0'"


    @rhbz1555013
    @ver+=1.14.0 @rhelver+=8
    @sriov
    @sriov_con_add_VF_trust_off
    Scenario: nmcli - sriov - add 1 VF with trust off
    * Add "ethernet" connection named "sriov" for device "p4p1" with options
          """
          sriov.vfs '0 trust=false'
          sriov.total-vfs 1
          sriov.autoprobe-drivers false
          """
    Then "trust off" is visible with command "ip link show dev p4p1 |grep 'vf 0'"


    @rhbz1555013
    @ver+=1.14.0 @rhelver+=8
    @sriov
    @sriov_con_add_VF_spoof_off
    Scenario: nmcli - sriov - add 1 VF without spoof check
    * Add "ethernet" connection named "sriov" for device "p4p1" with options
          """
          sriov.vfs '0 mac=00:11:22:33:44:55 spoof-check=false'
          sriov.total-vfs 1
          sriov.autoprobe-drivers false
          """
    Then "spoof checking off" is visible with command "ip link show dev p4p1 |grep 'vf 0'"


    @rhbz1555013
    @ver+=1.14.0 @rhelver+=8
    @sriov
    @sriov_con_add_VF_spoof
    Scenario: nmcli - sriov - add 1 VF with spoof check
    * Add "ethernet" connection named "sriov" for device "p4p1" with options
          """
          sriov.vfs '0 mac=00:11:22:33:44:55 spoof-check=true'
          sriov.total-vfs 1
          sriov.autoprobe-drivers false
          """
    Then "spoof checking on" is visible with command "ip link show dev p4p1 |grep 'vf 0'"



    ################# Other ######################################


    @rhbz2150831 @rhbz2038050
    @ver+=1.40.2
    @ver+=1.41.6
    @sriov @nmstate
    @sriov_nmstate_many_vfs
    Scenario: NM - sriov - enable sriov in config
    When "Exactly" "1" lines with pattern "p4p1" are visible with command "nmcli dev"
    * Cleanup connection "p4p1"
    * Write file "/tmp/many-vfs.yaml" with content
      """
      interfaces:
      - name: p4p1
        type: ethernet
        state: up
        ethernet:
          sr-iov:
            total-vfs: 45
      """
    * Execute "nmstatectl apply /tmp/many-vfs.yaml"
    When "Exactly" "46" lines with pattern "p4p1" are visible with command "nmcli dev"
    * Write file "/tmp/many-vfs.yaml" with content
      """
      interfaces:
      - name: p4p1
        type: ethernet
        state: up
        ethernet:
          sr-iov:
            total-vfs: 60
      """
    * Execute "nmstatectl apply /tmp/many-vfs.yaml"
    Then "Exactly" "61" lines with pattern "p4p1" are visible with command "nmcli dev"
