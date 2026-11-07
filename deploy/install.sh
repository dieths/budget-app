#!/usr/bin/env bash
# Installiert die Budget-App in einem Debian-Container (läuft IM CT als root).
# Aufruf: bash install.sh [GITHUB_REPO]   z. B. bash install.sh DEIN-NAME/budget-app
set -euo pipefail

GITHUB_REPO="${1:-${GITHUB_REPO:-DEIN-NAME/budget-app}}"
BRANCH="${BRANCH:-main}"
DIR=/opt/budget-app

echo "==> Pakete installieren"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq nginx git ca-certificates >/dev/null

echo "==> Repository holen: $GITHUB_REPO ($BRANCH)"
if [ -d "$DIR/.git" ]; then
  git -C "$DIR" pull --ff-only
else
  git clone --depth 1 -b "$BRANCH" "https://github.com/$GITHUB_REPO.git" "$DIR"
fi

echo "==> nginx einrichten"
cp "$DIR/deploy/nginx.conf" /etc/nginx/sites-available/budget-app
ln -sf /etc/nginx/sites-available/budget-app /etc/nginx/sites-enabled/budget-app
rm -f /etc/nginx/sites-enabled/default
nginx -t
systemctl enable --now nginx >/dev/null
systemctl reload nginx

echo "==> Update-Befehl anlegen: budget-update"
cat >/usr/local/bin/budget-update <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
git -C /opt/budget-app pull --ff-only
cp /opt/budget-app/deploy/nginx.conf /etc/nginx/sites-available/budget-app
nginx -t && systemctl reload nginx
echo "Budget-App aktualisiert."
EOF
chmod +x /usr/local/bin/budget-update

IP=$(hostname -I | awk '{print $1}')
echo
echo "Fertig. Die App läuft unter http://$IP/"
echo "Für die Installation am Handy über den Nginx Proxy Manager per HTTPS freigeben."
