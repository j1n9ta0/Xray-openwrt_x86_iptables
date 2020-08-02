#!/bin/bash

ws_server_host="v2ray.proxy.com"
ws_server_port="443"
ws_server_users_id="e86c4339-f8bd-4645-a403-ccdb3deb95f6"
ws_server_users_alterId="32"
loglevel="info"

function init() {

    bash <(curl -L -s https://install.direct/go.sh)
    systemctl disable v2ray
    
}

function start() {

    cat >/etc/v2ray/config.json <<EOF
{
    "log": {       
        "access": "none",
        "error": "/root/v2ray_error.log",
        "loglevel": "$loglevel"
    },
    "dns": {
        "servers": [
            {
                "address": "1.1.1.1",
                "port": 53
            },
            {
                "address": "208.67.220.220",
                "port": 443
            },
            {
                "address": "223.6.6.6",
                "port": 53,
                "domains": [
                    "geosite:cn",
                    "$ws_server_host"
                ]
            },
            "https+local://1.1.1.1/dns-query",
            "localhost"
        ]
    },
    "inbounds": [
        {
            "tag": "dns-in",
            "port": 5353,
            "protocol": "dokodemo-door",
            "settings": {
                "address": "208.67.220.220",
                "port": 5353,
                "network": "udp"
            }
        },
        {
            "tag": "transparent",
            "port": 12345,
            "protocol": "dokodemo-door",
            "settings": {
                "network": "tcp,udp",
                "followRedirect": true
            }           
        }
    ],
    "outbounds": [
        {
            "protocol": "vmess",
            "settings": {
                "vnext": [
                    {
                        "address": "$ws_server_host",
                        "port": $ws_server_port,
                        "users": [
                            {
                                "id": "$ws_server_users_id",
                                "alterId": $ws_server_users_alterId
                            }
                        ]
                    }
                ]
            },
            "streamSettings": {
                "network": "ws",
                "security": "tls",
                "sockopt": {
                    "mark": 255
                }
            },
            "mux": {
                "enabled": false
            }
        },
        {
            "tag": "direct",
            "protocol": "freedom",
            "streamSettings": {
                "sockopt": {
                    "mark": 255
                }
            }
        },
        {
            "tag": "dns-out",
            "protocol": "dns",
            "streamSettings": {
                "sockopt": {
                    "mark": 255
                }
            }
        }
    ],
    "routing": {
        "domainStrategy": "IPIfNonMatch",
        "rules": [
            {
                "type": "field",
                "inboundTag": "dns-in",
                "outboundTag": "dns-out"
            },
            {
                "type": "field",
                "inboundTag": "transparent",
                "port": 53,
                "outboundTag": "dns-out"
            },
            {
                "type": "field",
                "domain": [
                    "geosite:cn"
                ],
                "outboundTag": "direct"
            },
            {
                "type": "field",
                "ip": [
                    "geoip:cn"
                ],
                "outboundTag": "direct"
            }
        ]
    }
}
EOF

    echo "1" >/proc/sys/net/ipv4/ip_forward

    systemctl start v2ray

    ip route add local default dev lo table 100
    ip rule add fwmark 1 lookup 100
    # # 代理局域网设备
    # iptables -t nat -N V2RAY
    # iptables -t nat -A V2RAY -d 0.0.0.0/8 -j RETURN
    # iptables -t nat -A V2RAY -d 10.0.0.0/8 -j RETURN
    # iptables -t nat -A V2RAY -d 127.0.0.0/8 -j RETURN
    # iptables -t nat -A V2RAY -d 169.254.0.0/16 -j RETURN
    # iptables -t nat -A V2RAY -d 172.16.0.0/12 -j RETURN
    # iptables -t nat -A V2RAY -d 192.168.0.0/16 -j RETURN
    # iptables -t nat -A V2RAY -d 224.0.0.0/4 -j RETURN
    # iptables -t nat -A V2RAY -d 240.0.0.0/4 -j RETURN
    # iptables -t nat -A V2RAY -p tcp -j RETURN -m mark --mark 0xff # 直连 SO_MARK 为 0xff 的流量(0xff 是 16 进制数，数值上等同与上面配置的 255)，此规则目的是避免代理本机(网关)流量出现回环问题
    # iptables -t nat -A V2RAY -p tcp -j REDIRECT --to-ports 12345  # 其余流量转发到 12345 端口（即 V2Ray）
    # iptables -t nat -A PREROUTING -p tcp -j V2RAY                 # 对局域网其他设备进行透明代理
    # iptables -t nat -A OUTPUT -p tcp -j V2RAY                     # 对本机进行透明代理

    # iptables -t mangle -N V2RAY
    # iptables -t mangle -A V2RAY -d 0.0.0.0/8 -j RETURN
    # iptables -t mangle -A V2RAY -d 10.0.0.0/8 -j RETURN
    # iptables -t mangle -A V2RAY -d 127.0.0.0/8 -j RETURN
    # iptables -t mangle -A V2RAY -d 169.254.0.0/16 -j RETURN
    # iptables -t mangle -A V2RAY -d 172.16.0.0/12 -j RETURN
    # iptables -t mangle -A V2RAY -d 192.168.0.0/16 -j RETURN
    # iptables -t mangle -A V2RAY -d 224.0.0.0/4 -j RETURN
    # iptables -t mangle -A V2RAY -d 240.0.0.0/4 -j RETURN
    # iptables -t mangle -A V2RAY -p udp -j RETURN -m mark --mark 0xff
    # iptables -t mangle -A V2RAY -p udp -j TPROXY --on-port 12345 --tproxy-mark 0x01/0x01
    # iptables -t mangle -A PREROUTING -p udp -j V2RAY

    # iptables -t mangle -N V2RAY_MARK
    # iptables -t mangle -A V2RAY_MARK -p udp -j RETURN -m mark --mark 0xff
    # iptables -t mangle -A V2RAY_MARK -p udp --dport 53 -j MARK --set-mark 1 #本机只代理53
    # iptables -t mangle -A OUTPUT -p udp -j V2RAY_MARK

    iptables-restore --noflush <<-EOF
*mangle
:V2RAY - 
:V2RAY_MARK - 
-A PREROUTING -p udp -j V2RAY
-A OUTPUT -p udp -j V2RAY_MARK
-A V2RAY -d 0.0.0.0/8 -j RETURN
-A V2RAY -d 10.0.0.0/8 -j RETURN
-A V2RAY -d 127.0.0.0/8 -j RETURN
-A V2RAY -d 169.254.0.0/16 -j RETURN
-A V2RAY -d 172.16.0.0/12 -j RETURN
-A V2RAY -d 192.168.0.0/16 -j RETURN
-A V2RAY -d 224.0.0.0/4 -j RETURN
-A V2RAY -d 240.0.0.0/4 -j RETURN
-A V2RAY -p udp -m mark --mark 0xff -j RETURN
-A V2RAY -p udp -j TPROXY --on-port 12345 --tproxy-mark 1
-A V2RAY_MARK -p udp -m mark --mark 0xff -j RETURN
-A V2RAY_MARK -p udp --dport 53 -j MARK --set-mark 1
COMMIT
*nat
:V2RAY - 
-A PREROUTING -p tcp -j V2RAY
-A OUTPUT -p tcp -j V2RAY
-A V2RAY -d 0.0.0.0/8 -j RETURN
-A V2RAY -d 10.0.0.0/8 -j RETURN
-A V2RAY -d 127.0.0.0/8 -j RETURN
-A V2RAY -d 169.254.0.0/16 -j RETURN
-A V2RAY -d 172.16.0.0/12 -j RETURN
-A V2RAY -d 192.168.0.0/16 -j RETURN
-A V2RAY -d 224.0.0.0/4 -j RETURN
-A V2RAY -d 240.0.0.0/4 -j RETURN
-A V2RAY -p tcp -m mark --mark 0xff -j RETURN
-A V2RAY -p tcp -j REDIRECT --to-ports 12345
COMMIT
EOF

}

function stop() {

    iptables-save --counters | grep -v V2RAY | iptables-restore --counters

    ip route del local default dev lo table 100
    ip rule del fwmark 1 lookup 100

    echo "0" >/proc/sys/net/ipv4/ip_forward

    systemctl stop v2ray

    rm -rf /root/v2ray*.log
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
