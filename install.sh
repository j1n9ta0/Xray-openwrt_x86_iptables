#!/bin/sh

v=firewall.xray

uci delete "$v"

uci batch <<-EOF
	set $v=include
	set $v.type=script
	set $v.path=/usr/share/xray/firewall.include
	set $v.reload=1
	commit firewall
EOF

cp -a etc /
cp -a usr /

chmod 755 /usr/bin/xray /etc/init.d/xray

/etc/init.d/xray enable

fw3 reload
