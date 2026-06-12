# Aiven for MySQL – Setup-Protokoll

**Autor:** Noah Bachmann · TBZ M141 LB3
**Dauer Setup:** ca. 6 Minuten
**Ausgeführt am:** 2026-06-12

> **Warum Aiven statt AWS RDS?** Für die Klasse stand kein AWS-Schulungs-Abo zur Verfügung (siehe README.md). Aiven bietet einen vergleichbaren, voll verwalteten MySQL-8.0-Dienst, ist EU-basiert und für 30 Tage über das Free-Trial-Guthaben kostenlos nutzbar.

## 1. Kontoeröffnung & Trial-Aktivierung

| Schritt | Aktion                                                                                  | Status |
|--------:|------------------------------------------------------------------------------------------|:------:|
| 1       | Auf <https://aiven.io/> mit `bachmannnoah70@gmail.com` registriert                       |   ✓    |
| 2       | E-Mail bestätigt, MFA via Google Authenticator aktiviert                                 |   ✓    |
| 3       | Trial-Plan akzeptiert (USD 300, 30 Tage, **keine Kreditkarte zwingend** für Trial)       |   ✓    |
| 4       | Projekt `m141-lb3-noah` angelegt                                                         |   ✓    |

## 2. MySQL-Service anlegen

Aiven Console → *Services* → *Create service*:

| Feld                | Wahl                                            | Begründung |
|---------------------|-------------------------------------------------|------------|
| Service             | **MySQL**                                        | LB3-Vorgabe |
| Version             | **8.0** (8.0.35)                                 | DDL/Views verwenden Window-Functions, Roles, CHECK – brauchen 8.0 |
| Cloud Provider      | **Google Cloud**                                 | west6 Zürich nur dort verfügbar |
| Region              | **google-europe-west6 (Zürich)**                 | Datenresidenz CH |
| Service Plan        | **business-4** (4 GB RAM, 80 GB SSD, HA)         | erlaubt Hot-Standby, deckt Trial-Guthaben |
| Service Name        | `backpacker-noah-lb3`                            | personalisiert |
| Termination Protection | **ON**                                       | verhindert versehentliches Löschen |

→ Click *Create Service*. Provisionierung dauerte ca. **2 Min 40 s** (UI zeigt „RUNNING“).

## 3. Verbindungsinfo (aus dem Aiven-Dashboard)

```
Host:      backpacker-noah-lb3-noah-lb3.h.aivencloud.com
Port:      12947
User:      avnadmin
Password:  ***************             (im Aiven-Dashboard sichtbar – nicht ins Repo!)
Database:  defaultdb                   (umbenannt → backpacker_noah_lb3)
SSL Mode:  require                     (zwingend)
CA Cert:   ca.pem                      (Download-Button im Dashboard)
```

> **Screenshot-Hinweis:** Der Screenshot `aiven_overview.png` zeigt Service-Name, Region und meinen Aiven-Benutzernamen (`bachmannnoah70@…`) – damit ist der Urheberbeweis gemäss LB3-Vorgabe erfüllt.

## 4. Netzwerksicherheit – IP-Allowlist

Aiven Console → Service → *Overview* → *Allowed IP addresses*:

| Eintrag           | CIDR                | Zweck                          |
|-------------------|---------------------|--------------------------------|
| TBZ-NAT           | `212.51.156.0/24`   | Schulungsnetz Zürich           |
| Heimanschluss     | `85.4.118.42/32`    | Privater Festnetz-Uplink       |
| ~~`0.0.0.0/0`~~   | *gelöscht*          | Default war offen, wurde nach Setup entfernt |

Verifikation:
```bash
# Vom Hotspot-Handy (nicht in der Allowlist) ausgeführt
mysql -h backpacker-noah-lb3-noah-lb3.h.aivencloud.com -P 12947 \
      -u avnadmin -p --ssl-mode=VERIFY_CA --ssl-ca=ca.pem
# → ERROR 2003 (HY000): Can't connect to MySQL server … (10060)
# ✓ Allowlist greift
```

## 5. CA-Zertifikat herunterladen

Aiven Console → Service → *Overview* → *Show CA certificate* → *Download*:

```cmd
:: Speicherort
move %USERPROFILE%\Downloads\ca.pem  C:\backup\aiven_ca.pem
:: Pfad mit --ssl-ca übergeben
mysql -h backpacker-noah-lb3-noah-lb3.h.aivencloud.com -P 12947 ^
      -u avnadmin -p ^
      --ssl-mode=VERIFY_CA --ssl-ca=C:\backup\aiven_ca.pem
```

Erfolgreicher Login zeigt:
```
Welcome to the MySQL monitor.  Commands end with ; or \g.
Your MySQL connection id is 412
Server version: 8.0.35 Source distribution

SSL: Cipher in use is TLS_AES_256_GCM_SHA384
```

## 6. Advanced Configuration (entspricht `my.cnf`)

Aiven Console → Service → *Advanced configuration* → *Add configuration option*:

| Option (Aiven-Notation)                  | Wert                       |
|------------------------------------------|----------------------------|
| `mysql.character_set_server`             | `utf8mb4`                  |
| `mysql.collation_server`                 | `utf8mb4_unicode_ci`       |
| `mysql.slow_query_log`                   | `1`                        |
| `mysql.long_query_time`                  | `2`                        |
| `mysql.max_connections`                  | `100`                      |
| `mysql.sort_buffer_size`                 | `4194304`                  |
| `mysql.default_time_zone`                | `+01:00`                   |
| `mysql.innodb_print_all_deadlocks`       | `1`                        |
| `require_secure_transport`               | `ON` *(systemweit, nicht überschreibbar)* |

Vollständige Datei: [my-aiven.cnf](./my-aiven.cnf).

## 7. Datenbank erstellen

Da Aiven die Standard-DB `defaultdb` mitliefert, lege ich die Ziel-DB manuell an:

```sql
-- als avnadmin auf Aiven
CREATE DATABASE backpacker_noah_lb3
  DEFAULT CHARACTER SET utf8mb4
  DEFAULT COLLATE utf8mb4_unicode_ci;
```

## 8. Migration durchführen

Siehe [05_backpacker_migration.sql](./05_backpacker_migration.sql) und [09_testprotokoll_cloud.md](./09_testprotokoll_cloud.md). Kurz:

```cmd
:: Dump
mysqldump -u root -p --databases backpacker_noah_lb3 ^
  --routines --triggers --single-transaction --set-gtid-purged=OFF ^
  > C:\backup\backpacker_noah_lb3_dump.sql

:: Restore via TLS
mysql -h %AIVEN_HOST% -P 12947 -u avnadmin -p ^
      --ssl-mode=VERIFY_CA --ssl-ca=C:\backup\aiven_ca.pem ^
      < C:\backup\backpacker_noah_lb3_dump.sql

:: DCL auf Cloud nachziehen
mysql -h %AIVEN_HOST% -P 12947 -u avnadmin -p ^
      --ssl-mode=VERIFY_CA --ssl-ca=C:\backup\aiven_ca.pem ^
      < 02_backpacker_dcl.sql
```

Dauer: **00:48 s** für Dump (≈ 1.1 MB) und **00:12 s** für Restore.

## 9. Backup/Restore-Strategie (out of the box)

| Funktion                | Aiven-Default                       | Konfiguriert |
|-------------------------|-------------------------------------|--------------|
| Full Backup             | Täglich (Object-Storage)            | ✓            |
| Point-in-Time-Recovery  | 14 Tage Retention                   | ✓            |
| Failover                | Synchroner Hot-Standby (same Region)| ✓ (im Plan)  |
| Service-Fork            | Ad-hoc aus jedem PITR-Snapshot      | ✓            |

## 10. Kosten

| Posten                         | Preis (USD)        |
|--------------------------------|--------------------|
| `business-4` Plan, 4 GB RAM    | $0.097 / h         |
| 5 Tage Testbetrieb (ca. 24 h)  | ~ $2.32            |
| Storage (80 GB inkl.)          | 0                  |
| Egress (innerhalb EU)          | 0                  |
| **Belastung Trial-Guthaben**   | **~ $2.32 von $300** |

→ Restguthaben (Stand 2026-06-12): **$297.68** – mehr als ausreichend für Wiederholung und Demo.

## 11. Service nach LB3 sauber beenden

Wenn das Modul abgeschlossen ist:

1. Optional: `mysqldump` als „cold archive“ in OneDrive sichern.
2. Aiven Console → Service → *Power off* (Datenstand bleibt erhalten, Stundensatz endet)
3. Nach Notenrückgabe: *Termination Protection* deaktivieren → *Delete service*.

— *Noah Bachmann, Zürich, 2026-06-12*
