#!/bin/sh

# Final first-boot override for the single-NIC PVE side-router deployment.
# This file intentionally sorts after the upstream 99-custom.sh, whose
# single-NIC branch otherwise changes LAN to DHCP.

LOGFILE="/etc/config/pve-side-router-firstboot.log"

uci set system.@system[0].hostname='immortalwrt-pve'
uci set system.@system[0].zonename='Asia/Shanghai'
uci set system.@system[0].timezone='CST-8'

uci set network.lan.proto='static'
uci set network.lan.ipaddr='192.168.3.5'
uci set network.lan.netmask='255.255.255.0'
uci set network.lan.gateway='192.168.3.1'
uci -q delete network.lan.dns
uci add_list network.lan.dns='192.168.3.1'
uci set network.lan.delegate='0'
uci -q delete network.lan.ip6assign

uci -q set network.wan.proto='none'
uci -q set network.wan.auto='0'
uci -q set network.wan6.proto='none'
uci -q set network.wan6.auto='0'

uci set dhcp.lan.ignore='1'
uci set dhcp.lan.dhcpv4='disabled'
uci set dhcp.lan.dhcpv6='disabled'
uci set dhcp.lan.ra='disabled'
uci set dhcp.lan.ndp='disabled'

uci set firewall.lan.input='ACCEPT'
uci set firewall.lan.output='ACCEPT'
uci set firewall.lan.forward='ACCEPT'
uci set firewall.lan.masq='1'
uci set firewall.lan.mtu_fix='1'
uci -q set firewall.wan.input='REJECT'
uci -q set firewall.wan.output='ACCEPT'
uci -q set firewall.wan.forward='REJECT'

uci set dropbear.@dropbear[0].Interface='lan'
uci set dropbear.@dropbear[0].PasswordAuth='on'
uci set dropbear.@dropbear[0].RootPasswordAuth='on'

uci -q set uhttpd.main.redirect_https='1'

uci commit system
uci commit network
uci commit dhcp
uci commit firewall
uci commit dropbear
uci -q commit uhttpd

if [ -x /etc/init.d/ttyd ]; then
    /etc/init.d/ttyd disable
    /etc/init.d/ttyd stop
fi

if [ -x /etc/init.d/odhcpd ]; then
    /etc/init.d/odhcpd disable
    /etc/init.d/odhcpd stop
fi

{
    echo "Configured PVE side router at $(date)"
    echo "LAN=192.168.3.5/24 gateway=192.168.3.1"
    echo "DHCPv4/DHCPv6/RA=disabled"
} >"$LOGFILE"

exit 0
