#!/bin/bash

v2ray_server_host="pr.goflyway.xyz"
v2ray_server_port="443"
v2ray_server_users_id="e86c4339-f8bd-4645-a403-ccdb3deb95f6"
v2ray_server_users_alterId="32"

function init() {

    bash <(curl -L -s https://install.direct/go.sh)

}

function start() {

    pushd $(dirname $0)
    cp -a v2ray_client_tmp_config.json /etc/v2ray/config.json
    sed -i "s/v2ray_server_host/$v2ray_server_host/g" /etc/v2ray/config.json
    sed -i "s/v2ray_server_port/$v2ray_server_port/g" /etc/v2ray/config.json
    sed -i "s/v2ray_server_users_id/$v2ray_server_users_id/g" /etc/v2ray/config.json
    sed -i "s/v2ray_server_users_alterId/$v2ray_server_users_alterId/g" /etc/v2ray/config.json
    popd

    rm -rf /var/log/v2ray*.log

    systemctl start v2ray

    echo "1" >/proc/sys/net/ipv4/ip_forward

    # 设置策略路由
    ip rule add fwmark 1 table 100
    ip route add local 0.0.0.0/0 dev lo table 100

    # 代理局域网设备
    iptables -t mangle -N V2RAY_NETWORK
    iptables -t mangle -A V2RAY_NETWORK -d 0.0.0.0/8 -j RETURN
    iptables -t mangle -A V2RAY_NETWORK -d 10.0.0.0/8 -j RETURN
    iptables -t mangle -A V2RAY_NETWORK -d 127.0.0.0/8 -j RETURN
    iptables -t mangle -A V2RAY_NETWORK -d 169.254.0.0/16 -j RETURN
    iptables -t mangle -A V2RAY_NETWORK -d 172.16.0.0/12 -j RETURN
    iptables -t mangle -A V2RAY_NETWORK -d 192.168.0.0/16 -j RETURN
    iptables -t mangle -A V2RAY_NETWORK -d 224.0.0.0/4 -j RETURN
    iptables -t mangle -A V2RAY_NETWORK -d 240.0.0.0/4 -j RETURN
    iptables -t mangle -A V2RAY_NETWORK -m mark --mark 0xff -j RETURN                            # 直连 SO_MARK 为 0xff 的流量(0xff 是 16 进制数，数值上等同与上面配置的 255)，此规则目的是避免代理本机(网关)流量出现回环问题
    iptables -t mangle -A V2RAY_NETWORK -p udp -j TPROXY --on-port 12345 --tproxy-mark 0x01/0x01 # 给 UDP 打标记 1，转发至 12345 端口
    iptables -t mangle -A V2RAY_NETWORK -p tcp -j TPROXY --on-port 12345 --tproxy-mark 0x01/0x01 # 给 TCP 打标记 1，转发至 12345 端口
    iptables -t mangle -A PREROUTING -j V2RAY_NETWORK                                            # 应用规则

    # 代理网关本机
    iptables -t mangle -N V2RAY_LOCALHOST
    iptables -t mangle -A V2RAY_LOCALHOST -d 0.0.0.0/8 -j RETURN
    iptables -t mangle -A V2RAY_LOCALHOST -d 10.0.0.0/8 -j RETURN
    iptables -t mangle -A V2RAY_LOCALHOST -d 127.0.0.0/8 -j RETURN
    iptables -t mangle -A V2RAY_LOCALHOST -d 169.254.0.0/16 -j RETURN
    iptables -t mangle -A V2RAY_LOCALHOST -d 172.16.0.0/12 -j RETURN
    iptables -t mangle -A V2RAY_LOCALHOST -d 192.168.0.0/16 -j RETURN
    iptables -t mangle -A V2RAY_LOCALHOST -d 224.0.0.0/4 -j RETURN
    iptables -t mangle -A V2RAY_LOCALHOST -d 240.0.0.0/4 -j RETURN
    iptables -t mangle -A V2RAY_LOCALHOST -m mark --mark 0xff -j RETURN
    iptables -t mangle -A V2RAY_LOCALHOST -p udp -j MARK --set-mark 0x01 # 给 UDP 打标记,重路由
    iptables -t mangle -A V2RAY_LOCALHOST -p tcp -j MARK --set-mark 0x01 # 给 TCP 打标记，重路由
    iptables -t mangle -A OUTPUT -j V2RAY_LOCALHOST                      # 应用规则

}

function stop() {

    systemctl stop v2ray
    iptables -t mangle -D PREROUTING -j V2RAY_NETWORK
    iptables -t mangle -F V2RAY_NETWORK
    iptables -t mangle -X V2RAY_NETWORK
    iptables -t mangle -D OUTPUT -j V2RAY_LOCALHOST
    iptables -t mangle -F V2RAY_LOCALHOST
    iptables -t mangle -X V2RAY_LOCALHOST

    ip route del local default dev lo table 100
    ip rule del fwmark 1 lookup 100

    echo "0" >/proc/sys/net/ipv4/ip_forward

}

case $1 in
init)
    init
    ;;
start)
    start
    ;;
stop)
    stop
    ;;
restart)
    stop
    start
    ;;
*)
    echo "Error command"
    echo "Usage: $(basename $0) (init|start|stop|restart)"
    ;;
esac
