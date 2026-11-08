#!/usr/bin/env bash
# Legt auf dem Proxmox-Host einen schlanken Debian-LXC an und installiert die Budget-App darin.
# Auf dem Proxmox-Host als root ausführen.
#
# Alle Werte lassen sich per Umgebungsvariable überschreiben, z. B.:
#   CTID=120 IP=192.168.1.50/24 GW=192.168.1.1 bash proxmox-create-ct.sh
set -euo pipefail

GITHUB_REPO="${GITHUB_REPO:-DEIN-NAME/budget-app}"
BRANCH="${BRANCH:-main}"
CTID="${CTID:-$(pvesh get /cluster/nextid)}"
CT_HOSTNAME="${CT_HOSTNAME:-budget}"
STORAGE="${STORAGE:-local-lvm}"          # Speicher für das Root-Laufwerk
TMPL_STORAGE="${TMPL_STORAGE:-local}"    # Speicher für Container-Vorlagen
BRIDGE="${BRIDGE:-vmbr0}"
IP="${IP:-dhcp}"                         # oder z. B. 192.168.1.50/24
GW="${GW:-}"                             # nur bei fester IP nötig
DISK_GB="${DISK_GB:-2}"
MEMORY="${MEMORY:-256}"

command -v pct >/dev/null || { echo "Bitte auf dem Proxmox-Host ausführen."; exit 1; }

echo "==> Debian-Vorlage suchen"
pveam update >/dev/null
TEMPLATE=$(pveam available --section system | awk '{print $2}' | grep -E '^debian-13-standard' | sort -V | tail -1 || true)
[ -z "$TEMPLATE" ] && TEMPLATE=$(pveam available --section system | awk '{print $2}' | grep -E '^debian-12-standard' | sort -V | tail -1)
if ! pveam list "$TMPL_STORAGE" | grep -q "$TEMPLATE"; then
  echo "==> Lade $TEMPLATE"
  pveam download "$TMPL_STORAGE" "$TEMPLATE"
fi

NET="name=eth0,bridge=$BRIDGE,ip=$IP"
[ -n "$GW" ] && NET="$NET,gw=$GW"

echo "==> Erstelle CT $CTID ($CT_HOSTNAME)"
pct create "$CTID" "$TMPL_STORAGE:vztmpl/$TEMPLATE" \
  --hostname "$CT_HOSTNAME" \
  --cores 1 --memory "$MEMORY" --swap 256 \
  --rootfs "$STORAGE:$DISK_GB" \
  --net0 "$NET" \
  --unprivileged 1 --features nesting=1 \
  --onboot 1 --start 1 \
  --description "Budget-App (github.com/$GITHUB_REPO)"

echo "==> Warte auf Netzwerk"
for i in $(seq 1 30); do
  pct exec "$CTID" -- getent hosts deb.debian.org >/dev/null 2>&1 && break
  sleep 2
done

echo "==> Installiere App im Container"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || true)"
if [ -n "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/../app/index.html" ]; then
  # Lokale Kopie (z. B. entpacktes Archiv): komplett in den CT übertragen
  TMP=$(mktemp /tmp/budget-src.XXXXXX.tar.gz)
  tar -C "$SCRIPT_DIR/.." --exclude=.git -czf "$TMP" app deploy README.md
  pct push "$CTID" "$TMP" /root/budget-src.tar.gz
  rm -f "$TMP"
  pct exec "$CTID" -- bash -c "rm -rf /root/budget-src && mkdir -p /root/budget-src && tar -xzf /root/budget-src.tar.gz -C /root/budget-src"
  pct exec "$CTID" -- bash /root/budget-src/deploy/install.sh
else
  pct exec "$CTID" -- bash -c "apt-get update -qq && apt-get install -y -qq curl >/dev/null"
  pct exec "$CTID" -- curl -fsSL -o /root/install.sh \
    "https://raw.githubusercontent.com/$GITHUB_REPO/$BRANCH/deploy/install.sh"
  pct exec "$CTID" -- env BRANCH="$BRANCH" bash /root/install.sh "$GITHUB_REPO"
fi

echo
echo "CT $CTID ist bereit."
