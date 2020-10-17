#!/bin/bash

ws_server_host="proxy.v2ray.com"
ws_server_port="443"
ws_server_users_id="186c4339-f8bd-4645-a403-ccdb3deb95f6"
loglevel="info"

function init() {

    bash <(curl -L -s https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh)

}

function start() {

    #journalctl -f -u v2ray
    cat >/usr/local/etc/v2ray/config.json <<EOF
{
    "log": {       
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
            "port": 53,
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
            "protocol": "VLESS",
            "settings": {
                "vnext": [
                    {
                        "address": "$ws_server_host",
                        "port": $ws_server_port,
                        "users": [
                            {
                                "id": "$ws_server_users_id",
                                "encryption": "none"
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
                "enabled": true
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
    # --dport 53
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
-A V2RAY -p udp --dport 53 -j TPROXY --on-port 12345 --tproxy-mark 1
-A V2RAY_MARK -d 0.0.0.0/8 -j RETURN
-A V2RAY_MARK -d 10.0.0.0/8 -j RETURN
-A V2RAY_MARK -d 127.0.0.0/8 -j RETURN
-A V2RAY_MARK -d 169.254.0.0/16 -j RETURN
-A V2RAY_MARK -d 172.16.0.0/12 -j RETURN
-A V2RAY_MARK -d 192.168.0.0/16 -j RETURN
-A V2RAY_MARK -d 224.0.0.0/4 -j RETURN
-A V2RAY_MARK -d 240.0.0.0/4 -j RETURN
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
