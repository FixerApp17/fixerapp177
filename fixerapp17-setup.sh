#!/bin/bash
# ==================================================
#   ███████ ██ ██   ██ ███████ ██████   ██████
#   ██      ██ ██  ██  ██      ██   ██ ██    ██
#   █████   ██ █████   █████   ██████  ██    ██
#   ██      ██ ██  ██  ██      ██   ██ ██    ██
#   ██      ██ ██   ██ ███████ ██   ██  ██████
#
#       SERVER & PROXY MANAGEMENT SYSTEM
#           Version: 1.1 — FixerApp17
#           ⚠️ Don't Abuse This Script
# ==================================================

clear
echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║           🔥 FIXERAPP17 — SERVER & PROXY v1.1             ║"
echo "║       SSH • WS • SSL • Squid • OpenVPN • Users            ║"
echo "║               ⚠️ Don't Abuse This Script                  ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

# ==================================================
# CHECK ROOT
# ==================================================
if [ "$(id -u)" -ne 0 ]; then
    echo "❌ Pakigamit ang: sudo bash fixerapp17-setup.sh"
    exit 1
fi

# ==================================================
# STEP 1 — UPDATE & INSTALL PACKAGES
# ==================================================
echo "📦 [1/8] Nag-u-update ng system..."
apt update && apt upgrade -y

echo "🔧 Nag-i-install ng mga kailangang packages..."
apt install -y openssh-server nginx certbot python3-certbot-nginx squid ufw curl wget nano openvpn easy-rsa

# ==================================================
# STEP 2 — SSH SERVER
# ==================================================
echo "🔐 [2/8] Nagse-setup ng SSH Server..."
systemctl enable --now ssh
systemctl is-active --quiet ssh && echo "   ✅ SSH Tumatakbo sa Port 22"

# ==================================================
# STEP 3 — FIREWALL
# ==================================================
echo "🔥 [3/8] Nagse-setup ng Firewall..."
ufw --force reset
ufw allow 22/tcp    # SSH
ufw allow 80/tcp    # HTTP / WS
ufw allow 443/tcp   # HTTPS / WSS
ufw allow 3128/tcp  # Squid Proxy
ufw allow 8080/tcp  # Squid Proxy
ufw allow 8000/tcp  # Squid Proxy
ufw allow 1194/udp  # OpenVPN UDP
ufw allow 1194/tcp  # OpenVPN TCP
ufw --force enable
echo "   ✅ Ports Bukas: 22, 80, 443, 3128, 8080, 8000, 1194(UDP+TCP)"

# ==================================================
# STEP 4 — NGINX WEBSOCKET TUNNELS
# ==================================================
echo "🌐 [4/8] Nagse-setup ng WebSocket Tunnels..."

# Backup original config
cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.bak

# SSH + WebSocket (HTTP — Port 80)
cat > /etc/nginx/sites-available/fixerapp17-ssh-ws << 'EOF'
server {
    listen 80;
    server_name _;

    location /ssh-ws {
        proxy_pass http://127.0.0.1:22;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_read_timeout 86400;
    }
}
EOF

# SSH + SSL + WebSocket (HTTPS — Port 443)
cat > /etc/nginx/sites-available/fixerapp17-ssh-ssl-ws << 'EOF'
server {
    listen 443 ssl;
    server_name your-domain.com;

    ssl_certificate /etc/letsencrypt/live/your-domain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/your-domain.com/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    location /ssh-ssl-ws {
        proxy_pass http://127.0.0.1:22;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-Proto https;
        proxy_read_timeout 86400;
    }
}
EOF

# Enable sites
ln -sf /etc/nginx/sites-available/fixerapp17-ssh-ws /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

nginx -t && systemctl reload nginx
echo "   ✅ SSH+WS: Port 80 /ssh-ws — Naka-ON"
echo "   ⏳ SSH+SSL+WS: Kailangan ng domain — Menu #5 para i-setup"

# ==================================================
# STEP 5 — SQUID PROXY
# ==================================================
echo "🌍 [5/8] Nagse-setup ng Squid Proxy..."

cp /etc/squid/squid.conf /etc/squid/squid.conf.bak

cat > /etc/squid/conf.d/fixerapp17-rules.conf << 'EOF'
# ==========================================
#   FIXERAPP17 — Squid Proxy Rules
#   ⚠️ Don't Abuse This Script
# ==========================================

http_port 3128
http_port 8080
http_port 8000

acl all src all
acl localnet src 10.0.0.0/8
acl localnet src 172.16.0.0/12
acl localnet src 192.168.0.0/16

acl blocked dstdomain "/etc/squid/fixerapp17-blocked.txt"
http_access deny blocked

http_access allow localnet
http_access allow localhost
http_access deny all

cache_dir ufs /var/spool/squid 100 16 256
access_log /var/log/squid/access.log squid
EOF

touch /etc/squid/fixerapp17-blocked.txt
systemctl enable --now squid
systemctl restart squid
echo "   ✅ Squid Proxy: Port 3128, 8080, 8000 — Naka-ON"

# ==================================================
# STEP 6 — OPENVPN SERVER (UDP + TCP)
# ==================================================
echo "🔐 [6/8] Nagse-setup ng OpenVPN Server (UDP + TCP)..."

EASYRSA_DIR="/etc/openvpn/easy-rsa"
CLIENT_DIR="/etc/openvpn/clients"
mkdir -p $EASYRSA_DIR $CLIENT_DIR
SERVER_IP=$(curl -s ifconfig.me)

# Initialize PKI kung bago lang
if [ ! -d "$EASYRSA_DIR/pki" ]; then
    echo "   📜 Gumagawa ng Certificate Authority..."
    cp -r /usr/share/easy-rsa/* $EASYRSA_DIR/
    cd $EASYRSA_DIR
    ./easyrsa init-pki
    ./easyrsa build-ca nopass
    echo "   📜 Gumagawa ng Server Certificate..."
    ./easyrsa gen-req server nopass
    ./easyrsa sign-req server server
    ./easyrsa gen-dh
    openvpn --genkey secret pki/ta.key
fi

cd $EASYRSA_DIR
cp pki/ca.crt /etc/openvpn/ 2>/dev/null
cp pki/issued/server.crt /etc/openvpn/ 2>/dev/null
cp pki/private/server.key /etc/openvpn/ 2>/dev/null
cp pki/dh.pem /etc/openvpn/ 2>/dev/null
cp pki/ta.key /etc/openvpn/ 2>/dev/null

# UDP Config
cat > /etc/openvpn/server-udp.conf << EOF
port 1194
proto udp
dev tun
ca ca.crt
cert server.crt
key server.key
dh dh.pem
tls-auth ta.key 0
cipher AES-256-GCM
auth SHA256
server 10.8.0.0 255.255.255.0
push "redirect-gateway def1 bypass-dhcp"
push "dhcp-option DNS 8.8.8.8"
push "dhcp-option DNS 8.8.4.4"
keepalive 10 120
persist-key
persist-tun
status openvpn-status-udp.log
verb 3
EOF

# TCP Config
cat > /etc/openvpn/server-tcp.conf << EOF
port 1194
proto tcp
dev tun
ca ca.crt
cert server.crt
key server.key
dh dh.pem
tls-auth ta.key 0
cipher AES-256-GCM
auth SHA256
server 10.9.0.0 255.255.255.0
push "redirect-gateway def1 bypass-dhcp"
push "dhcp-option DNS 8.8.8.8"
push "dhcp-option DNS 8.8.4.4"
keepalive 10 120
persist-key
persist-tun
status openvpn-status-tcp.log
verb 3
EOF

systemctl enable --now openvpn-server@server-udp
systemctl enable --now openvpn-server@server-tcp

systemctl is-active --quiet openvpn-server@server-udp && echo "   ✅ OpenVPN UDP: Port 1194 — Naka-ON"
systemctl is-active --quiet openvpn-server@server-tcp && echo "   ✅ OpenVPN TCP: Port 1194 — Naka-ON"

# Function: Generate .ovpn file
generate_ovpn() {
    local NAME=$1
    local PROTO=$2
    cd $EASYRSA_DIR
    if [ ! -f "pki/issued/${NAME}.crt" ]; then
        ./easyrsa gen-req $NAME nopass
        ./easyrsa sign-req client $NAME
    fi
    cat > ${CLIENT_DIR}/${NAME}-${PROTO}.ovpn << OVPN
client
dev tun
proto $PROTO
remote $SERVER_IP 1194
resolv-retry infinite
nobind
persist-key
persist-tun
cipher AES-256-GCM
auth SHA256
remote-cert-tls server
verb 3
<ca>
$(cat pki/ca.crt)
</ca>
<cert>
$(openssl x509 -in "pki/issued/${NAME}.crt")
</cert>
<key>
$(cat "pki/private/${NAME}.key")
</key>
<tls-auth>
$(cat pki/ta.key)
</tls-auth>
key-direction 1
OVPN
    chmod 600 ${CLIENT_DIR}/${NAME}-${PROTO}.ovpn
}

# Generate default client files
generate_ovpn "fixerapp17" "udp"
generate_ovpn "fixerapp17" "tcp"

echo ""
echo "📂 ==================================================="
echo "✅ MGA .OVPN FILE — I-DOWNLOAD ANG DALAWANG ITO:"
echo "===================================================="
echo "🟢 UDP:   ${CLIENT_DIR}/fixerapp17-udp.ovpn"
echo "🔵 TCP:   ${CLIENT_DIR}/fixerapp17-tcp.ovpn"
echo "===================================================="
echo "💡 Paano i-download:"
echo "   1. SFTP/SCP: scp root@$SERVER_IP:$CLIENT_DIR/* ~/"
echo "   2. File Manager: kopyahin at i-send sa Telegram/Email"
echo "   3. Nano: nano $CLIENT_DIR/fixerapp17-udp.ovpn → copy all → save sa phone"
echo "===================================================="

# ==================================================
# STEP 7 — BANNER MESSAGE + COMPLETE
# ==================================================
echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║                ✅ FIXERAPP17 — INSTALL COMPLETE! ✅        ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""
echo -e "\033[38;5;197m=======================\033[0m"
echo -e "\033[38;5;212m   FixerApp17 Script Taglish\033[0m"
echo -e "\033[38;5;197m=======================\033[0m"
echo ""
echo -e "\033[38;5;218mFree Script For All by FixerApp17 Codes\033[0m"
echo -e "\033[38;5;197m==============================\033[0m"
echo ""
echo -e "\033[38;5;175mTERMS:\033[0m"
echo -e "\033[38;5;147m  • No DDOS\033[0m"
echo -e "\033[38;5;139m  • No Hacking\033[0m"
echo -e "\033[38;5;130m  • No Carding\033[0m"
echo -e "\033[38;5;122m  • No Spam\033[0m"
echo -e "\033[38;5;114m  • No Torrent\033[0m"
echo -e "\033[38;5;106m  • No Fraud\033[0m"
echo -e "\033[38;5;98m  • No Repost\033[0m"
echo -e "\033[38;5;90m  • No Multi Login\033[0m"
echo ""
echo -e "\033[38;5;49mAny Feedback/Question:\033[0m"
echo "🔗 Telegram: https://t.me/FixerApp17"
echo ""
echo -e "\033[38;5;37mSubscribe Our Channel:\033[0m"
echo "🔗 YouTube: https://YouTube.com/@fixerapp2442"
echo ""
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "📌 CONNECTION DETAILS:"
echo "═══════════════════════════════════════════════════════════"
echo "🔌 SSH DIRECT       → Port 22"
echo "🌐 SSH + WS         → Port 80, Path: /ssh-ws"
echo "🔒 SSH + SSL + WS   → Port 443, Path: /ssh-ssl-ws (kailangan domain)"
echo "🌍 SQUID PROXY      → Port 3128, 8080, 8000"
echo "🔐 OPENVPN          → Port 1194 UDP + TCP"
echo "   📂 UDP File: $CLIENT_DIR/fixerapp17-udp.ovpn"
echo "   📂 TCP File: $CLIENT_DIR/fixerapp17-tcp.ovpn"
echo "═══════════════════════════════════════════════════════════"
echo ""

# ==================================================
# MAIN MENU
# ==================================================
while true; do
    echo ""
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║          🔥 FIXERAPP17 — MAIN MENU                        ║"
    echo "║               ⚠️ Don't Abuse This Script                  ║"
    echo "╠══════════════════════════════════════════════════════════╣"
    echo "║  👤 USER MANAGEMENT          🌐 SQUID PROXY               ║"
    echo "║  1. Gumawa ng User           6. Block Website             ║"
    echo "║  2. Listahan ng Users        7. Unblock Website           ║"
    echo "║  3. Delete User              8. View Blocked Sites        ║"
    echo "║  4. Palitan ang Password     9. View Access Logs          ║"
    echo "║                                                           ║"
    echo "║  🔐 OPENVPN                  ⚙️ SYSTEM                     ║"
    echo "║  A. Bagong Client File       5. Setup SSL Certificate     ║"
    echo "║  B. Listahan ng Files        F. Full Connection Info      ║"
    echo "║                              0. Exit                       ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    read -p "👉 Piliin ang numero: " choice
    
    case $choice in
        1)
            echo ""
            read -p "👤 Username: " u
            if id "$u" &>/dev/null; then echo "⚠️ Umiiral na!"; else
                useradd -m -s /bin/bash "$u"
                echo "✅ User '$u' nagawa na! Password:"
                passwd "$u"
            fi
            ;;
        2)
            echo ""
            echo "📋 MGA USER:"
            awk -F':' '{ if ($3>=1000 && $3!=65534) print "  👤 "$1 }' /etc/passwd
            echo "───────────────"
            echo "Kabuuan: $(awk -F':' '{ if ($3>=1000 && $3!=65534) print $1 }' /etc/passwd | wc -l) na user"
            ;;
        3)
            echo ""
            read -p "❌ Username na ide-delete: " u
            if id "$u" &>/dev/null; then
                read -p "⚠️ Sigurado? (y/n): " c
                [ "$c" = "y" ] && userdel -r "$u" 2>/dev/null && echo "✅ Na-delete na!"
            else echo "⚠️ Walang ganong user."; fi
            ;;
        4)
            echo ""
            read -p "👤 Username: " u
            if id "$u" &>/dev/null; then passwd "$u"; else echo "⚠️ Walang ganong user."; fi
            ;;
        5)
            echo ""
            read -p "🌐 Ilagay ang domain: " dom
            echo "⚠️ Siguraduhin na ang domain ay nakaturo na sa server IP!"
            read -p "Ituloy? (y/n): " c
            if [ "$c" = "y" ]; then
                certbot --nginx -d "$dom"
                sed -i "s/your-domain.com/$dom/g" /etc/nginx/sites-available/fixerapp17-ssh-ssl-ws
                nginx -t && systemctl reload nginx
                echo "✅ SSH+SSL+WS: wss://$dom/ssh-ssl-ws — Naka-ON!"
            fi
            ;;
        6)
            echo ""
            read -p "🌐 Website na ibabaw (hal: .facebook.com): " s
            echo "$s" >> /etc/squid/fixerapp17-blocked.txt
            systemctl reload squid
            echo "✅ Na-block na ang $s"
            ;;
        7)
            echo ""
            nano /etc/squid/fixerapp17-blocked.txt
            systemctl reload squid
            echo "✅ Na-update!"
            ;;
        8)
            echo ""
            echo "🚫 BLOCKED WEBSITES:"
            echo "─────────────────────"
            if [ -s /etc/squid/fixerapp17-blocked.txt ]; then
                cat /etc/squid/fixerapp17-blocked.txt
            else echo "(Walang naka-block)"; fi
            echo "─────────────────────"
            ;;
        9)
            echo ""
            echo "📝 ACCESS LOGS (huling 15):"
            echo "──────────────────────────"
            tail -n 15 /var/log/squid/access.log
            echo "───────────────────────────"
            ;;
        A|a)
            echo ""
            read -p "🔐 Pangalan ng Client: " cname
            generate_ovpn "$cname" "udp"
            generate_ovpn "$cname" "tcp"
            echo ""
            echo "✅ TAPOS NA! Dalawang file ang nagawa:"
            echo "🟢 UDP:   $CLIENT_DIR/${cname}-udp.ovpn"
            echo "🔵 TCP:   $CLIENT_DIR/${cname}-tcp.ovpn"
            echo ""
            ;;
        B|b)
            echo ""
            echo "📂 MGA .OVPN FILES SA SERVER:"
            echo "────────────────────────────"
            ls -lh $CLIENT_DIR/ 2>/dev/null || echo "(Wala pang client file)"
            echo "────────────────────────────"
            echo "📂 Lokasyon: $CLIENT_DIR/"
            echo ""
            ;;
        F|f)
            echo ""
            echo "╔══════════════════════════════════════════════════════════╗"
            echo "║           📌 FIXERAPP17 — FULL CONNECTION INFO             ║"
            echo "║               ⚠️ Don't Abuse This Script                  ║"
            echo "╠══════════════════════════════════════════════════════════╣"
            ip=$(curl -s ifconfig.me)
            echo "║  🌐 SERVER IP: $ip"
            echo "╠══════════════════════════════════════════════════════════╣"
            echo "║  🔌 SSH DIRECT                                            ║"
            echo "║     ssh user@$ip -p 22                                     ║"
            echo "╠══════════════════════════════════════════════════════════╣"
            echo "║  🌐 SSH + WEBSOCKET                                        ║"
            echo "║     ws://$ip/ssh-ws                                        ║"
            echo "╠══════════════════════════════════════════════════════════╣"
            echo "║  🔒 SSH + SSL + WEBSOCKET                                  ║"
            echo "║     wss://your-domain.com/ssh-ssl-ws                       ║"
            echo "║     ⚠️ Kailangan ng sariling domain — Piliin Menu #5       ║"
            echo "╠══════════════════════════════════════════════════════════╣"
            echo "║  🌍 SQUID PROXY                                            ║"
            echo "║     IP: $ip   Port: 3128, 8080, 8000                       ║"
            echo "╠══════════════════════════════════════════════════════════╣"
            echo "║  🔐 OPENVPN                                                ║"
            echo "║     UDP: $ip:1194  📂 $CLIENT_DIR/fixerapp17-udp.ovpn    ║"
            echo "║     TCP: $ip:1194  📂 $CLIENT_DIR/fixerapp17-tcp.ovpn    ║"
            echo "╠══════════════════════════════════════════════════════════╣"
            echo "║  📂 FILE LOCATIONS:                                        ║"
            echo "║     Squid Rules:    /etc/squid/conf.d/fixerapp17-rules.conf ║"
            echo "║     Blocked Sites:  /etc/squid/fixerapp17-blocked.txt      ║"
            echo "║     SSH Config:     /etc/ssh/sshd_config                   ║"
            echo "║     Nginx Config:   /etc/nginx/sites-available/            ║"
            echo "║     OpenVPN Files:  $CLIENT_DIR/                           ║"
            echo "╚══════════════════════════════════════════════════════════╝"
            ;;
        0)
            echo ""
            echo "╔══════════════════════════════════════════════════════════╗"
            echo "║             👋 Salamat sa paggamit ng FIXERAPP17 Script 😊!          ║"
            echo "║           ⚠️ Again Don't Abuse This Script                ║"
            echo "╚══════════════════════════════════════════════════════════╝"
            exit 0
            ;;
        *)
            echo "❌ Mali ang napili. Subukan ulit."
            ;;
    esac
done
