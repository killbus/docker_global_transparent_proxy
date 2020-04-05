#!/bin/bash

set -e

reset_iptables(){
    iptables -P INPUT ACCEPT
    iptables -P FORWARD ACCEPT
    iptables -P OUTPUT ACCEPT
    iptables -t nat -F
    iptables -t mangle -F
    iptables -t filter -F
    iptables -F
    iptables -X
}

set_clash_iptables(){

    if [ -z "$EN_MODE_TUN" ]; then
        #tcp
        iptables -t nat -N CLASH
        iptables -t nat -A CLASH -d 0.0.0.0/8 -j RETURN
        iptables -t nat -A CLASH -d 10.0.0.0/8 -j RETURN
        iptables -t nat -A CLASH -d 127.0.0.0/8 -j RETURN
        iptables -t nat -A CLASH -d 169.254.0.0/16 -j RETURN
        iptables -t nat -A CLASH -d 172.16.0.0/12 -j RETURN
        iptables -t nat -A CLASH -d 192.168.0.0/16 -j RETURN
        iptables -t nat -A CLASH -d 224.0.0.0/4 -j RETURN
        iptables -t nat -A CLASH -d 240.0.0.0/4 -j RETURN

        iptables -t nat -A CLASH -p tcp -j REDIRECT --to-ports 7892
        iptables -t nat -I PREROUTING -p tcp -d 8.8.8.8 -j REDIRECT --to-ports 7892
        iptables -t nat -I PREROUTING -p tcp -d 8.8.4.4 -j REDIRECT --to-ports 7892

        #拦截 dns 请求并且转发!
        iptables -t nat -A PREROUTING -p tcp --dport 53 -j REDIRECT --to-ports 1053
        iptables -t nat -A PREROUTING -p udp --dport 53 -j REDIRECT --to-ports 1053
        
        iptables -t nat -A PREROUTING -p tcp -j CLASH
        
        #udp
        if [ "${ENABLE_UDP_PROXY:-0}" -eq 1 ]; then
            ip rule add fwmark 1 table 100
            ip route add local default dev lo table 100
            iptables -t mangle -N CLASH
            iptables -t mangle -A CLASH -d 0.0.0.0/8 -j RETURN
            iptables -t mangle -A CLASH -d 10.0.0.0/8 -j RETURN
            iptables -t mangle -A CLASH -d 127.0.0.0/8 -j RETURN
            iptables -t mangle -A CLASH -d 169.254.0.0/16 -j RETURN
            iptables -t mangle -A CLASH -d 172.16.0.0/12 -j RETURN
            iptables -t mangle -A CLASH -d 192.168.0.0/16 -j RETURN
            iptables -t mangle -A CLASH -d 224.0.0.0/4 -j RETURN
            iptables -t mangle -A CLASH -d 240.0.0.0/4 -j RETURN
            
            iptables -t mangle -A CLASH -p udp -j TPROXY --on-port 7892 --tproxy-mark 1
            iptables -t mangle -A PREROUTING -p udp -j CLASH
        fi
        
        if [ "${EN_MODE:-fake-ip}" = "fake-ip" ]; then
            iptables -t nat -A OUTPUT -p tcp -d 198.18.0.0/16 -j REDIRECT --to-ports 7892
            if [ "$ENABLE_UDP_PROXY" -eq 1 ]; then
                iptables -t mangle -A OUTPUT -p udp -d 198.18.0.0/16 -j MARK --set-mark 1
            fi
        fi

    else
        setup_clash_tun
    fi
}

init_clash_tun_settings() {
    readonly PROXY_BYPASS_USER="nobody"
    # readonly PROXY_BYPASS_CGROUP="0x16200000"
    readonly PROXY_FWMARK="0x162"
    readonly PROXY_ROUTE_TABLE="0x162"
    readonly PROXY_DNS_PORT="1053"
    readonly PROXY_FORCE_NETADDR="198.18.0.0/16"
    readonly PROXY_TUN_DEVICE_NAME="clash0"
    readonly PROXY_TUN_ADDRESS="172.31.255.253/30"
}

setup_clash_tun() {
    init_clash_tun_settings

    if [ "${EN_MODE:-fake-ip}" = "fake-ip" ]; then
        ip tuntap add "$PROXY_TUN_DEVICE_NAME" mode tun user $PROXY_BYPASS_USER
        ip link set "$PROXY_TUN_DEVICE_NAME" up
        ip addr add "$PROXY_FORCE_NETADDR" dev "$PROXY_TUN_DEVICE_NAME"
    else
        ipset create localnetwork hash:net
        ipset add localnetwork 127.0.0.0/8
        ipset add localnetwork 10.0.0.0/8
        ipset add localnetwork 192.168.0.0/16
        ipset add localnetwork 224.0.0.0/4
        ipset add localnetwork 172.16.0.0/12 

        #/opt/script/setup-clash-cgroup.sh

        ip tuntap add "$PROXY_TUN_DEVICE_NAME" mode tun user $PROXY_BYPASS_USER
        ip link set "$PROXY_TUN_DEVICE_NAME" up

        ip address replace "$PROXY_TUN_ADDRESS" dev "$PROXY_TUN_DEVICE_NAME"

        ip route replace default dev "$PROXY_TUN_DEVICE_NAME" table "$PROXY_ROUTE_TABLE"

        ip rule add fwmark "$PROXY_FWMARK" lookup "$PROXY_ROUTE_TABLE"

        iptables -t mangle -N CLASH
        iptables -t mangle -F CLASH
        iptables -t mangle -A CLASH -m owner --uid-owner "$PROXY_BYPASS_USER" -j RETURN
        #iptables -t mangle -A CLASH -m owner --uid-owner systemd-timesync -j RETURN
        iptables -t mangle -A CLASH -d "$PROXY_FORCE_NETADDR" -j MARK --set-mark "$PROXY_FWMARK"
        #iptables -t mangle -A CLASH -m cgroup --cgroup "$PROXY_BYPASS_CGROUP" -j RETURN
        iptables -t mangle -A CLASH -m addrtype --dst-type BROADCAST -j RETURN
        iptables -t mangle -A CLASH -m set --match-set localnetwork dst -j RETURN
        iptables -t mangle -A CLASH -j MARK --set-mark "$PROXY_FWMARK"

        iptables -t nat -N CLASH_DNS
        iptables -t nat -F CLASH_DNS
        iptables -t nat -A CLASH_DNS -d 127.0.0.0/8 -j RETURN
        iptables -t nat -A CLASH_DNS -m owner --uid-owner "$PROXY_BYPASS_USER" -j RETURN
        #iptables -t nat -A CLASH_DNS -m owner --uid-owner systemd-timesync -j RETURN
        #iptables -t nat -A CLASH_DNS -m cgroup --cgroup "$PROXY_BYPASS_CGROUP" -j RETURN
        iptables -t nat -A CLASH_DNS -p udp -j REDIRECT --to-ports "$PROXY_DNS_PORT"

        iptables -t mangle -I OUTPUT -j CLASH
        iptables -t mangle -I PREROUTING -m set ! --match-set localnetwork dst -j MARK --set-mark "$PROXY_FWMARK"

        iptables -t nat -I OUTPUT -p udp --dport 53 -j CLASH_DNS
        iptables -t nat -I PREROUTING -p udp --dport 53 -j REDIRECT --to "$PROXY_DNS_PORT"

    fi
}

setup_clash_cgroup() {
    if [ -d "/sys/fs/cgroup/net_cls/bypass_proxy" ];then
        exit 0
    fi

    mkdir -p /sys/fs/cgroup/net_cls/bypass_proxy
    echo "$PROXY_BYPASS_CGROUP" > /sys/fs/cgroup/net_cls/bypass_proxy/net_cls.classid
    chmod 666 /sys/fs/cgroup/net_cls/bypass_proxy/tasks
}

clean_clash_tun() {
    ip link set dev "$PROXY_TUN_DEVICE_NAME" down
    ip tuntap del "$PROXY_TUN_DEVICE_NAME" mode tun

    ip route del default dev "$PROXY_TUN_DEVICE_NAME" table "$PROXY_ROUTE_TABLE"
    ip rule del fwmark "$PROXY_FWMARK" lookup "$PROXY_ROUTE_TABLE"
    # ip -6 route del default dev "$PROXY_TUN_DEVICE_NAME" table "$PROXY_ROUTE_TABLE"
    # ip -6 rule del fwmark "$PROXY_FWMARK" lookup "$PROXY_ROUTE_TABLE"

    iptables -t mangle -D OUTPUT -j CLASH
    iptables -t mangle -D PREROUTING -m set ! --match-set localnetwork dst -j MARK --set-mark "$PROXY_FWMARK"

    # ip6tables -t mangle -D OUTPUT -j CLASH6
    # ip6tables -t mangle -D PREROUTING -m set ! --match-set localnetwork6 dst -j MARK --set-mark "$PROXY_FWMARK"

    iptables -t nat -D OUTPUT -p udp --dport 53 -j CLASH_DNS
    iptables -t nat -D PREROUTING -p udp --dport 53 -j REDIRECT --to-ports "$PROXY_DNS_PORT"

    # ip6tables -t nat -D OUTPUT -p udp --dport 53 -j CLASH_DNS6
    # ip6tables -t nat -D PREROUTING -p udp --dport 53 -j REDIRECT --to-ports "$PROXY_DNS_PORT"

    iptables -t mangle -F CLASH
    iptables -t mangle -X CLASH

    # ip6tables -t mangle -F CLASH6
    # ip6tables -t mangle -X CLASH6

    iptables -t nat -F CLASH_DNS
    iptables -t nat -X CLASH_DNS

    # ip6tables -t nat -F CLASH_DNS6
    # ip6tables -t nat -X CLASH_DNS6

    iptables -t filter -D OUTPUT -d "$PROXY_TUN_ADDRESS" -j REJECT

    ipset destroy localnetwork
    # ipset destroy localnetwork6

} &> /dev/null

reset_iptables
set_clash_iptables

#开启转发
echo "1" > /proc/sys/net/ipv4/ip_forward

if [ ! -e '/clash_config/config.yaml' ]; then
    echo "init /clash_config/config.yaml"
    cp  /root/.config/clash/config.yaml /clash_config/config.yaml
fi

if [ ! -e '/clash_config/Country.mmdb' ]; then
    echo "init /clash_config/Country.mmdb"
    cp  /root/.config/clash/Country.mmdb /clash_config/Country.mmdb
fi

ip addr

exec "$@"