# Super Easy Budget

Minimalistische Budget-App fürs Handy. Budgets anlegen, monatlich aufstocken, Ausgaben mit einem Tipp auf **−** abbuchen. Zeigt pro Budget und insgesamt, wie viel bis Monatsende **pro Tag** übrig ist.

- Reine Web-App (HTML/CSS/JS, keine Abhängigkeiten, kein Build)
- Installierbar als App (PWA), funktioniert offline
- Daten liegen lokal auf dem Gerät (`localStorage`), optional Sync über den eigenen Server
- Spar-Ansporn: Plan-Anzeige, Gold-Ziel pro Tag, Monatsbilanz mit Medaillen, Sparschwein

## Aufbau

```
app/      Die App selbst (wird von nginx ausgeliefert)
deploy/   Skripte für Proxmox-LXC und nginx
```

## Bereitstellung als Proxmox-Container

Auf dem **Proxmox-Host** als root:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/itzlbritzl/budget-app/main/deploy/proxmox-create-ct.sh)"
```

Mit eigenen Werten, z. B. fester IP:

```bash
CTID=120 IP=192.168.1.50/24 GW=192.168.1.1 \
bash -c "$(curl -fsSL https://raw.githubusercontent.com/itzlbritzl/budget-app/main/deploy/proxmox-create-ct.sh)"
```

Das Skript lädt die aktuelle Debian-Vorlage, legt einen unprivilegierten CT an (1 Kern, 256 MB RAM, 2 GB Disk), installiert nginx und klont dieses Repository nach `/opt/budget-app`.

Optionale Variablen: `CTID`, `CT_HOSTNAME`, `STORAGE`, `TMPL_STORAGE`, `BRIDGE`, `IP` (z. B. `192.168.1.50/24`), `GW`, `DISK_GB`, `MEMORY`, `BRANCH`.

Alternativ in einem vorhandenen Debian-CT: `bash deploy/install.sh itzlbritzl/budget-app`

### HTTPS über Nginx Proxy Manager

Installierbarkeit und Offline-Betrieb brauchen HTTPS. Im Nginx Proxy Manager einen Proxy Host anlegen:

- Domain: z. B. `budget.deine-domain.de`
- Forward: `http://<CT-IP>:80`
- SSL: Let's-Encrypt-Zertifikat, „Force SSL“ an

Danach die Seite am Handy öffnen und „Zum Home-Bildschirm“ wählen.

### Aktualisieren

```bash
pct exec <CTID> -- budget-update
```

## Synchronisierung

Der Container stellt unter `/api/data.json` einen kleinen Speicher bereit (nginx, GET/PUT), geschützt durch ein Token. Das Token gibt das Installationsskript aus, später abrufbar mit:

```bash
pct exec <CTID> -- cat /etc/budget-app/token
```

In der App unter ⚙︎ → Synchronisierung eintragen. Danach gleicht die App nach jeder Buchung, beim Öffnen und bei wiederhergestellter Verbindung ab. Offline erfasste Buchungen werden später nachgeholt. Mehrere Geräte werden zusammengeführt (Buchungen über ihre ID, Budget-Änderungen nach Zeitpunkt).

Der Server sichert die Daten täglich nach `/var/lib/budget-app/backups/` (60 Tage).

## Datensicherung ohne Sync

Die Daten liegen dann nur im Browser des jeweiligen Geräts. Regelmäßig über ⚙︎ → „Daten exportieren“ sichern – die Monatsbilanz erinnert daran.
