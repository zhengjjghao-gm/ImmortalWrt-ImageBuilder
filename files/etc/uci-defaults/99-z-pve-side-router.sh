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

LAN_ZONE=$(uci show firewall | sed -n "s/^\(firewall\.@zone\[[0-9][0-9]*\]\)\.name='lan'$/\1/p" | head -n 1)
WAN_ZONE=$(uci show firewall | sed -n "s/^\(firewall\.@zone\[[0-9][0-9]*\]\)\.name='wan'$/\1/p" | head -n 1)

if [ -n "$LAN_ZONE" ]; then
    uci set "$LAN_ZONE.input=ACCEPT"
    uci set "$LAN_ZONE.output=ACCEPT"
    uci set "$LAN_ZONE.forward=ACCEPT"
    uci set "$LAN_ZONE.masq=1"
    uci set "$LAN_ZONE.mtu_fix=1"
fi

if [ -n "$WAN_ZONE" ]; then
    uci set "$WAN_ZONE.input=REJECT"
    uci set "$WAN_ZONE.output=ACCEPT"
    uci set "$WAN_ZONE.forward=REJECT"
fi

uci set dropbear.@dropbear[0].Interface='lan'
uci set dropbear.@dropbear[0].PasswordAuth='on'
uci set dropbear.@dropbear[0].RootPasswordAuth='on'

uci -q delete uhttpd.main.listen_http
uci add_list uhttpd.main.listen_http='192.168.3.5:80'
uci -q delete uhttpd.main.listen_https
uci add_list uhttpd.main.listen_https='192.168.3.5:443'
uci set uhttpd.main.redirect_https='1'

uci -q set passwall.@global[0].enabled='0'
uci -q set passwall.@global[0].localhost_proxy='0'
uci -q set passwall.@global[0].client_proxy='0'

uci commit system
uci commit network
uci commit dhcp
uci commit firewall
uci commit dropbear
uci commit uhttpd
uci -q commit passwall

if [ -x /etc/init.d/ttyd ]; then
    /etc/init.d/ttyd disable
    /etc/init.d/ttyd stop
fi

if [ -x /etc/init.d/odhcpd ]; then
    /etc/init.d/odhcpd disable
    /etc/init.d/odhcpd stop
fi

# Several proxy core packages enable their generic init services during image
# creation. PassWall launches the selected core itself, so keep every proxy
# service stopped until a verified node and ACL are configured.
for service in passwall passwall_server haproxy sing-box xray; do
    if [ -x "/etc/init.d/$service" ]; then
        "/etc/init.d/$service" stop >/dev/null 2>&1 || true
        "/etc/init.d/$service" disable
    fi
done

sysctl -w net.ipv4.conf.all.send_redirects=0 >/dev/null 2>&1 || true
sysctl -w net.ipv4.conf.default.send_redirects=0 >/dev/null 2>&1 || true
sysctl -w net.ipv4.conf.br-lan.send_redirects=0 >/dev/null 2>&1 || true

{
    echo "Configured PVE side router at $(date)"
    echo "LAN=192.168.3.5/24 gateway=192.168.3.1"
    echo "DHCPv4/DHCPv6/RA=disabled"
    echo "IPv4 ICMP redirects=disabled"
} >"$LOGFILE"

exit 0
