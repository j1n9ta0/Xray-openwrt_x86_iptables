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
            },
            "streamSettings": {
                "sockopt": {
                    "tproxy": "tproxy"
                }
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

    # 设置策略路由
    ip rule add fwmark 1 table 100
    ip route add local 0.0.0.0/0 dev lo table 100

    iptables-restore --noflush <<-EOF
*mangle
:V2RAY_LOCALHOST -
:V2RAY_NETWORK -
-A PREROUTING -j V2RAY_NETWORK
-A OUTPUT -j V2RAY_LOCALHOST
-A V2RAY_LOCALHOST -d 0.0.0.0/8 -j RETURN
-A V2RAY_LOCALHOST -d 10.0.0.0/8 -j RETURN
-A V2RAY_LOCALHOST -d 127.0.0.0/8 -j RETURN
-A V2RAY_LOCALHOST -d 169.254.0.0/16 -j RETURN
-A V2RAY_LOCALHOST -d 172.16.0.0/12 -j RETURN
-A V2RAY_LOCALHOST -d 192.168.0.0/16 -j RETURN
-A V2RAY_LOCALHOST -d 224.0.0.0/4 -j RETURN
-A V2RAY_LOCALHOST -d 240.0.0.0/4 -j RETURN
-A V2RAY_LOCALHOST -m mark --mark 0xff -j RETURN  
-A V2RAY_LOCALHOST -p udp -j MARK --set-mark 1 
-A V2RAY_LOCALHOST -p tcp -j MARK --set-mark 1 
-A V2RAY_NETWORK -d 0.0.0.0/8 -j RETURN
-A V2RAY_NETWORK -d 10.0.0.0/8 -j RETURN
-A V2RAY_NETWORK -d 127.0.0.0/8 -j RETURN
-A V2RAY_NETWORK -d 169.254.0.0/16 -j RETURN
-A V2RAY_NETWORK -d 172.16.0.0/12 -j RETURN
-A V2RAY_NETWORK -d 192.168.0.0/16 -j RETURN
-A V2RAY_NETWORK -d 224.0.0.0/4 -j RETURN
-A V2RAY_NETWORK -d 240.0.0.0/4 -j RETURN
-A V2RAY_NETWORK -m mark --mark 0xff -j RETURN
-A V2RAY_NETWORK -p udp -j TPROXY --on-port 12345 --tproxy-mark 1 
-A V2RAY_NETWORK -p tcp -j TPROXY --on-port 12345 --tproxy-mark 1 
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
