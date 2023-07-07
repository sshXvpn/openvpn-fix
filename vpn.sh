#!/bin/bash

domain=$(cat /etc/xray/domain)
clear

# Initial variable setup
export DEBIAN_FRONTEND=noninteractive
OS=$(uname -m);
ANU=$(ip -o $ANU -4 route show to default | awk '{print $5}');

# Generate a new OpenVPN certificate
cd /etc/openvpn/server/easy-rsa/
./easyrsa init-pki
./easyrsa --batch build-ca nopass
./easyrsa --batch build-server-full server nopass
cp pki/ca.crt /etc/openvpn/server/
cp pki/issued/server.crt /etc/openvpn/server/
cp pki/private/server.key /etc/openvpn/server/

cd
mkdir -p /usr/lib/openvpn/
cp /usr/lib/x86_64-linux-gnu/openvpn/plugins/openvpn-plugin-auth-pam.so /usr/lib/openvpn/openvpn-plugin-auth-pam.so

# Update /etc/default/openvpn configuration
sed -i 's/#AUTOSTART="all"/AUTOSTART="all"/g' /etc/default/openvpn

# Restart OpenVPN service and check status
systemctl enable --now openvpn-server@server-tcp
systemctl enable --now openvpn-server@server-udp
/etc/init.d/openvpn restart
/etc/init.d/openvpn status

# Enable IPv4 forwarding
echo 1 > /proc/sys/net/ipv4/ip_forward
sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/g' /etc/sysctl.conf
sysctl -p

# Generate client configurations
cd /etc/openvpn/server/easy-rsa/
./easyrsa --batch build-client-full client nopass

# Create client directory if it doesn't exist
mkdir -p /etc/openvpn/clients/

# Copy client certificates to the client directory
cp pki/issued/client.crt /etc/openvpn/clients/
cp pki/private/client.key /etc/openvpn/clients/

# Create client configuration files
cat > /etc/openvpn/tcp.ovpn <<-END
client
dev tun
proto tcp
remote $domain 1194
resolv-retry infinite
route-method exe
nobind
persist-key
persist-tun
auth-user-pass
comp-lzo
verb 3
<ca>
$(cat /etc/openvpn/server/ca.crt)
</ca>
<cert>
$(cat /etc/openvpn/clients/client.crt)
</cert>
<key>
$(cat /etc/openvpn/clients/client.key)
</key>
END

cat > /etc/openvpn/udp.ovpn <<-END
client
dev tun
proto udp
remote $domain 2200
resolv-retry infinite
route-method exe
nobind
persist-key
persist-tun
auth-user-pass
comp-lzo
verb 3
<ca>
$(cat /etc/openvpn/server/ca.crt)
</ca>
<cert>
$(cat /etc/openvpn/clients/client.crt)
</cert>
<key>
$(cat /etc/openvpn/clients/client.key)
</key>
END

cat > /etc/openvpn/ssl.ovpn <<-END
client
dev tun
proto tcp
remote $domain 990
resolv-retry infinite
route-method exe
nobind
persist-key
persist-tun
auth-user-pass
comp-lzo
verb 3
<ca>
$(cat /etc/openvpn/server/ca.crt)
</ca>
<cert>
$(cat /etc/openvpn/clients/client.crt)
</cert>
<key>
$(cat /etc/openvpn/clients/client.key)
</key>
END

# Copy client configuration files to /home/vps/public_html/
mkdir -p /home/vps/public_html/
cp -f /etc/openvpn/tcp.ovpn /home/vps/public_html/tcp.ovpn
cp -f /etc/openvpn/udp.ovpn /home/vps/public_html/udp.ovpn
cp -f /etc/openvpn/ssl.ovpn /home/vps/public_html/ssl.ovpn

# Restart OpenVPN service
/etc/init.d/openvpn restart

# Delete the script
rm -f "$0"
history -c
rm -f /root/vpn.sh
sleep 1
reboot
