# Budget

Minimalistische Budget-App fürs Handy. Budgets anlegen, monatlich aufstocken, Ausgaben mit einem Tipp auf **−** abbuchen. Zeigt pro Budget und insgesamt, wie viel bis Monatsende **pro Tag** übrig ist.

- Reine Web-App (HTML/CSS/JS, keine Abhängigkeiten, kein Build)
- Installierbar als App (PWA), funktioniert offline
- Daten bleiben lokal auf dem Gerät (`localStorage`), Export/Import als JSON-Sicherung

## Aufbau

```
app/      Die App selbst (wird von nginx ausgeliefert)
deploy/   Skripte für Proxmox-LXC und nginx
```

## Bereitstellung als Proxmox-Container

Auf dem **Proxmox-Host** als root:

```bash
GITHUB_REPO=DEIN-NAME/budget-app \
bash -c "$(curl -fsSL https://raw.githubusercontent.com/DEIN-NAME/budget-app/main/deploy/proxmox-create-ct.sh)"
```

Das Skript lädt die aktuelle Debian-Vorlage, legt einen unprivilegierten CT an (1 Kern, 256 MB RAM, 2 GB Disk), installiert nginx und klont dieses Repository nach `/opt/budget-app`.

Optionale Variablen: `CTID`, `CT_HOSTNAME`, `STORAGE`, `TMPL_STORAGE`, `BRIDGE`, `IP` (z. B. `192.168.1.50/24`), `GW`, `DISK_GB`, `MEMORY`, `BRANCH`.

Alternativ in einem vorhandenen Debian-CT: `bash deploy/install.sh DEIN-NAME/budget-app`

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

## Datensicherung

Die Daten liegen nur im Browser des jeweiligen Geräts. Regelmäßig über ⚙︎ → „Daten exportieren“ sichern.
