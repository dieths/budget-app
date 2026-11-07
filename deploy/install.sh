#!/usr/bin/env bash
# Installiert oder aktualisiert die Budget-App in einem Debian-Container (läuft IM CT als root).
# Aufruf: bash install.sh [GITHUB_REPO]   z. B. bash install.sh DEIN-NAME/budget-app
# Mehrfach ausführbar: vorhandenes Token und Daten bleiben erhalten.
set -euo pipefail

GITHUB_REPO="${1:-${GITHUB_REPO:-DEIN-NAME/budget-app}}"
BRANCH="${BRANCH:-main}"
DIR=/opt/budget-app
DATA=/var/lib/budget-app
CONF=/etc/budget-app

echo "==> Pakete installieren"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq nginx git ca-certificates cron openssl >/dev/null

echo "==> Repository holen: $GITHUB_REPO ($BRANCH)"
if [ -d "$DIR/.git" ]; then
  git -C "$DIR" pull --ff-only
else
  git clone --depth 1 -b "$BRANCH" "https://github.com/$GITHUB_REPO.git" "$DIR"
fi

echo "==> Datenverzeichnis und Sync-Token"
mkdir -p "$DATA/api" "$DATA/backups" "$CONF"
chown -R www-data:www-data "$DATA"
chmod 750 "$DATA"
if [ ! -s "$CONF/token" ]; then
  openssl rand -hex 16 > "$CONF/token"
  chmod 600 "$CONF/token"
fi
TOKEN=$(cat "$CONF/token")
cat > /etc/nginx/conf.d/budget-token.conf <<EOF
map \$http_x_sync_token \$budget_sync_ok {
    default 0;
    "$TOKEN" 1;
}
EOF
chmod 640 /etc/nginx/conf.d/budget-token.conf

echo "==> nginx einrichten"
cp "$DIR/deploy/nginx.conf" /etc/nginx/sites-available/budget-app
ln -sf /etc/nginx/sites-available/budget-app /etc/nginx/sites-enabled/budget-app
rm -f /etc/nginx/sites-enabled/default
nginx -t
systemctl enable --now nginx >/dev/null
systemctl reload nginx

echo "==> Tägliche Sicherung der Sync-Daten (60 Tage)"
cat > /etc/cron.daily/budget-backup <<EOF
#!/bin/sh
[ -s $DATA/api/data.json ] || exit 0
cp $DATA/api/data.json $DATA/backups/data-\$(date +%F).json
find $DATA/backups -name 'data-*.json' -mtime +60 -delete
EOF
chmod +x /etc/cron.daily/budget-backup
systemctl enable --now cron >/dev/null 2>&1 || true

echo "==> Update-Befehl anlegen: budget-update"
cat > /usr/local/bin/budget-update <<EOF
#!/usr/bin/env bash
exec bash $DIR/deploy/install.sh "$GITHUB_REPO"
EOF
chmod +x /usr/local/bin/budget-update

IP=$(hostname -I | awk '{print $1}')
echo
echo "Fertig. Die App läuft unter http://$IP/"
echo "Sync-Token (in der App unter ⚙︎ → Synchronisierung eintragen):"
echo "    $TOKEN"
echo "Für die Installation am Handy über den Nginx Proxy Manager per HTTPS freigeben."
