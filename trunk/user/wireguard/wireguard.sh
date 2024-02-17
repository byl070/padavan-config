#!/bin/sh

start_wg() {
	localip="$(nvram get wireguard_localip | awk -F" *: *" '{print $1}')"
	listenport=$(nvram get wireguard_localip | awk -F" *: *" '{print $2}')
	privatekey="$(nvram get wireguard_localkey)"
	peerkey="$(nvram get wireguard_peerkey| awk -F" *[\(\)] *" '{print $1}')"
	presharedkey="$(nvram get wireguard_peerkey| awk -F" *[\(\)] *" '{print $2}')"
	peerip="$(nvram get wireguard_peerip)"
	logger -t "WIREGUARD" "正在启动wireguard"
	ip link show wg0 >/dev/null 2>&1 && ip link set dev wg0 down && ip link del dev wg0
	ip link add dev wg0 type wireguard
	ip link set dev wg0 mtu 1420
	ip addr add $localip dev wg0
	echo "$privatekey" > /tmp/privatekey
	wg set wg0 listen-port $listenport private-key /tmp/privatekey
	echo "$presharedkey" > /tmp/presharedkey
	wg set wg0 peer $peerkey preshared-key /tmp/presharedkey persistent-keepalive 25 allowed-ips 0.0.0.0/0 endpoint $peerip
	iptables -t nat -A POSTROUTING -o wg0 -j MASQUERADE
	ip link set dev wg0 up
}


stop_wg() {
	if [ ip link show wg0 >/dev/null 2>&1 ]; then
		iptables -D INPUT -i wg0 -j ACCEPT
		iptables -D FORWARD -i wg0 -j ACCEPT
		iptables -t nat -D POSTROUTING -o wg0 -j MASQUERADE
		ip link set dev wg0 down
		ip link del dev wg0
		awk -F" += +" 'match($1,"^ *PostDown$"){system($2)}' $conf
		logger -t "WIREGUARD" "已经关闭wireguard"
	fi
	}



case $1 in
start)
	start_wg
	;;
stop)
	stop_wg
	;;
*)
	echo "check"
	#exit 0
	;;
esac
