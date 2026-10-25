#!/bin/bash
# ==================================================
#   ███████ ██ ██   ██ ███████ ██████   ██████
#   ██      ██ ██  ██  ██      ██   ██ ██    ██
#   █████   ██ █████   █████   ██████  ██    ██
#   ██      ██ ██  ██  ██      ██   ██ ██    ██
#   ██      ██ ██   ██ ███████ ██   ██  ██████
#
#       SERVER & PROXY MANAGEMENT SYSTEM
#           Version: 1.0 — FixerApp17
#           ⚠️ Don't Abuse This Script
# ==================================================

clear
echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║           🔥 FIXERAPP17 — SERVER & PROXY v1.0             ║"
echo "║           SSH • WS • SSL • Squid • Users                  ║"
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
echo "📦 [1/7] Nag-u-update ng system..."
apt update && apt upgrade -y

echo "🔧 Nag-i-install ng mga kailangang packages..."
apt install -y openssh-server nginx certbot python3-certbot-nginx squid ufw curl wget nano

# ==================================================
# STEP 2 — SSH SERVER
# ==================================================
echo "🔐 [2/7] Nagse-setup ng SSH Server..."
systemctl enable --now ssh
systemctl is-active --quiet ssh && echo "   ✅ SSH Tumatakbo sa Port 22"

# ==================================================
# STEP 3 — FIREWALL
# ==================================================
echo "🔥 [3/7] Nagse-setup ng Firewall..."
ufw --force reset
ufw allow 22/tcp    # SSH
ufw allow 80/tcp    # HTTP / WS
ufw allow 443/tcp   # HTTPS / WSS
ufw allow 3128/tcp  # Squid Proxy
ufw --force enable
echo "   ✅ Ports Bukas: 22, 80, 443, 3128"

# ==================================================
# STEP 4 — NGINX WEBSOCKET TUNNELS
# ==================================================
echo "🌐 [4/7] Nagse-setup ng WebSocket Tunnels..."

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
echo "🌍 [5/7] Nagse-setup ng Squid Proxy..."

cp /etc/squid/squid.conf /etc/squid/squid.conf.bak

cat > /etc/squid/conf.d/fixerapp17-rules.conf << 'EOF'
# ==========================================
#   FIXERAPP17 — Squid Proxy Rules
#   ⚠️ Don't Abuse This Script
# ==========================================

http_port 3128

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
echo "   ✅ Squid Proxy: Port 3128 — Naka-ON"

# ==================================================
# STEP 6 — BANNER & COMPLETE
# ==================================================
echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║                ✅ FIXERAPP17 — INSTALL COMPLETE! ✅        ║"
echo "║                    ⚠️ Don't Abuse This Script              ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""
echo "📌 CONNECTION DETAILS:"
echo "═══════════════════════════════════════════════════════════"
echo "🔌 SSH DIRECT       → Port 22"
echo "🌐 SSH + WS         → Port 80, Path: /ssh-ws"
echo "🔒 SSH + SSL + WS   → Port 443, Path: /ssh-ssl-ws (kailangan domain)"
echo "🌍 SQUID PROXY      → Port 3128"
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
    echo "║  ⚙️ SYSTEM                                                ║"
    echo "║  5. Setup SSL Certificate    0. Exit                      ║"
    echo "║  F. Full Connection Info                                  ║"
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
            echo "║     IP: $ip   Port: 3128                                   ║"
            echo "╠══════════════════════════════════════════════════════════╣"
            echo "║  📂 FILE LOCATIONS:                                        ║"
            echo "║     Squid Rules:    /etc/squid/conf.d/fixerapp17-rules.conf ║"
            echo "║     Blocked Sites:  /etc/squid/fixerapp17-blocked.txt      ║"
            echo "║     SSH Config:     /etc/ssh/sshd_config                   ║"
            echo "║     Nginx Config:   /etc/nginx/sites-available/            ║"
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
