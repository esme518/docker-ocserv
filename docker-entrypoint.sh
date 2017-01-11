#!/bin/sh

# Set ocserv.conf
sed -i "/^tcp-port = /{s/443/$PORT/}" /etc/ocserv/ocserv.conf
sed -i "/^udp-port = /{s/443/$PORT/}" /etc/ocserv/ocserv.conf
sed -i "/^ipv4-network = /{s/192.168.1.0/$IPV4/}" /etc/ocserv/ocserv.conf
sed -i "/^dns = /{s/192.168.1.2/$DNS/}" /etc/ocserv/ocserv.conf

# Set cn-no-route
echo "Update cn-no-route"
curl -SL "https://raw.githubusercontent.com/CNMan/ocserv-cn-no-route/master/cn-no-route.txt" -o /tmp/route.txt
cat /tmp/route.txt > /etc/ocserv/config-per-group/Surf
rm -fr /tmp/route.txt

if [ ! -f /etc/ocserv/certs/server-key.pem ] || [ ! -f /etc/ocserv/certs/server-cert.pem ]; then
	# Check environment variables
	if [ -z "$CA_CN" ]; then
		CA_CN="VPN CA"
	fi

	if [ -z "$CA_ORG" ]; then
		CA_ORG="X Corp"
	fi

	if [ -z "$CA_DAYS" ]; then
		CA_DAYS=3652
	fi

	if [ -z "$SRV_CN" ]; then
		SRV_CN="VPN Server"
	fi

	if [ -z "$SRV_URL" ]; then
		SRV_URL="www.example.com"
	fi

	if [ -z "$SRV_ORG" ]; then
		SRV_ORG="MyCompany"
	fi

	if [ -z "$SRV_DAYS" ]; then
		SRV_DAYS=3652
	fi

	# No certification found, generate one
	mkdir /etc/ocserv/certs
	cd /etc/ocserv/certs
	certtool --generate-privkey --outfile ca-key.pem
	cat > ca.tmpl <<-EOCA
	cn = "$CA_CN"
	organization = "$CA_ORG"
	serial = 1
	expiration_days = $CA_DAYS
	ca
	signing_key
	cert_signing_key
	crl_signing_key
	EOCA
	certtool --generate-self-signed --load-privkey ca-key.pem --template ca.tmpl --outfile ca.pem
	certtool --generate-privkey --outfile server-key.pem 
	cat > server.tmpl <<-EOSRV
	cn = "$SRV_CN"
	dns_name = "$SRV_URL"
	organization = "$SRV_ORG"
	expiration_days = $SRV_DAYS
	signing_key
	encryption_key
	tls_www_server
	EOSRV
	certtool --generate-certificate --load-privkey server-key.pem --load-ca-certificate ca.pem --load-ca-privkey ca-key.pem --template server.tmpl --outfile server-cert.pem

	# Create a test user
	if [ -z "$NO_TEST_USER" ] && [ ! -f /etc/ocserv/ocpasswd ]; then
		echo "Create test user 'test' with password 'test'"
		echo 'test:Surf,All:$5$DktJBFKobxCFd7wN$sn.bVw8ytyAaNamO.CvgBvkzDiFR6DaHdUzcif52KK7' > /etc/ocserv/ocpasswd
	fi
fi

# Open ipv4 ip forward
sysctl -w net.ipv4.ip_forward=1

# Enable NAT forwarding
iptables -t nat -A POSTROUTING -j MASQUERADE
iptables -A FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu

# Enable TUN device
mkdir -p /dev/net
mknod /dev/net/tun c 10 200
chmod 600 /dev/net/tun

# Run OpennConnect Server
exec ocserv -c /etc/ocserv/ocserv.conf -f
