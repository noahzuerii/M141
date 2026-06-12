# Live-Demo Drehbuch (10–15 Minuten, MS E)

**Autor:** Noah Bachmann · TBZ M141 LB3 · 2025/2026
**Setting:** Vor der LP, 1 Bildschirm geteilt: links lokale MariaDB (XAMPP), rechts Aiven-Cloud (`mysql`-CLI).
**Datum Demo:** 2026-06-12, Tag 10

> Ziel: In 10–15 Min. zeigen, dass die Datenbank lokal sauber läuft, **identisch** in die Cloud migriert wurde, dort sicher ist (TLS, Allowlist) und dass die Zugriffsmatrix wirksam ist. Pflicht: 3 User auf Cloud + LP-Testscript.

## 0. Einstieg (1 Min.)

* Begrüssung, Worum geht's: „Migration einer Access-DB der Backpacker-Jugendherberge auf eine sichere Cloud-Instanz – Aiven for MySQL, weil unsere Klasse kein AWS-Abo erhalten hat.“
* Repo-Tab zeigen: README.md auf GitLab (Hinweis-Box „Pivot AWS → Aiven“).
* Architektur-Diagramm aus README.md kurz erklären (Client → TLS → Allowlist → Aiven Primary + Standby).

## 1. Lokale DB-Vorführung (3 Min.)

```cmd
:: Terminal A
mysql -u root -p backpacker_noah_lb3
```

```sql
-- Tabellenzahl
SHOW TABLES;
-- Erwartet: 7 Tabellen (inkl. tbl_audit_log)

-- 4 Buchungen
SELECT * FROM v_buchung_uebersicht;

-- Stored Procedure
CALL sp_umsatz_zusammenfassung();
-- Zeigt 4 Buchungen, 577.78 CHF, 2.6 Nächte Ø
```

## 2. Migration & Cloud-Verbindung (2 Min.)

* Im Aiven-Dashboard kurz das Service-Cockpit zeigen (Status `RUNNING`, Region `west6 Zurich`, Allowed IPs).
* Im Terminal B:

```cmd
mysql -h backpacker-noah-lb3-noah-lb3.h.aivencloud.com ^
      -P 12947 -u avnadmin -p ^
      --ssl-mode=VERIFY_CA --ssl-ca=C:\backup\aiven_ca.pem ^
      backpacker_noah_lb3
```

```sql
SHOW STATUS LIKE 'Ssl_cipher';   -- TLS_AES_256_GCM_SHA384
SELECT @@hostname, @@version;     -- Aiven-Host, 8.0.35

-- 1:1-Vergleich zur lokalen DB
SELECT 'tbl_personen', COUNT(*) FROM tbl_personen
UNION ALL SELECT 'tbl_buchung', COUNT(*) FROM tbl_buchung
UNION ALL SELECT 'tbl_positionen', COUNT(*) FROM tbl_positionen;
```

→ Auf beiden Terminals nebeneinander: Zeilenzahlen identisch.

## 3. **Drei-User-Test in der Cloud (4 Min.)**  *(Pflicht für MS E)*

### 3a) `avnadmin` (Cloud-Owner)
```sql
SHOW GRANTS FOR ben_noah;
SHOW GRANTS FOR mgmt_noah;
```

### 3b) `ben_noah` (Frontdesk)
```cmd
mysql -h … -u ben_noah -p --ssl-mode=VERIFY_CA --ssl-ca=ca.pem backpacker_noah_lb3
```
```sql
SELECT * FROM v_buchung_uebersicht;     -- erlaubt
SELECT Password FROM tbl_benutzer;       -- ERROR 1143 ✓
SELECT * FROM v_umsatz_pro_buchung;     -- ERROR 1142 ✓
```

### 3c) `mgmt_noah` (Verwaltung)
```cmd
mysql -h … -u mgmt_noah -p --ssl-mode=VERIFY_CA --ssl-ca=ca.pem backpacker_noah_lb3
```
```sql
SELECT * FROM v_umsatz_pro_buchung;      -- erlaubt
CALL sp_monatsbericht(2026, 6);          -- erlaubt
INSERT INTO tbl_buchung (Personen_FS, Ankunft, Abreise, Land_FS)
VALUES (2042,'2026-08-01','2026-08-03',1);  -- ERROR 1142 ✓ (Management darf keine Buchung anlegen)
```

## 4. **LP-Testscript-Ausführung (3 Min.)**  *(Pflicht für MS E)*

Die LP soll selbst tippen / das von ihr mitgebrachte Script ausführen. Vorgesehener Pfad:

```cmd
:: LP-Workstation (im TBZ-Netz → in Allowlist)
mysql -h backpacker-noah-lb3-noah-lb3.h.aivencloud.com ^
      -P 12947 -u mgmt_noah -p ^
      --ssl-mode=VERIFY_CA --ssl-ca=C:\Users\Public\aiven_ca.pem ^
      backpacker_noah_lb3 < pruefskript_LP.sql
```

> Damit die LP-Workstation Zugriff hat, wurde **vor** der Demo die TBZ-NAT-IP in die Aiven-Allowlist eingetragen. Falls die LP von einem anderen Netz kommt, kann ich live im Aiven-Dashboard ihre IP hinzufügen (dauert <10 s).

## 5. Sicherheits-Beweise (1 Min.)

* Aiven-Console → *Logs* → letzte Verbindungen (zeigt nur erlaubte IPs).
* Backup-Tab → letztes PITR-Backup von vor 2 Min.
* Aiven-Console → *Service Forks* → erkläre, wie ich im Notfall in <2 Min. einen geforkten Snapshot starte.

## 6. Abschluss (1 Min.)

* Verweis auf Repo / Markdown-Dokumente:
  * `08_testprotokoll_lokal.md` – 53 Tests, alle ✓
  * `09_testprotokoll_cloud.md` – 48 Tests, alle ✓
  * `PROMPTS.md` – KI-Einsatz transparent
* Frage offen halten: „Möchten Sie noch eine spezifische Spalte/Berechtigung testen?“

## Notfall-Plan während Demo

| Problem                                  | Reaktion                                       |
|------------------------------------------|------------------------------------------------|
| TBZ-Netz blockiert Port 12947 ausgehend  | Tethering Handy → IP live in Allowlist + retry |
| Aiven-Console nicht erreichbar           | Backup-Screenshots im OneDrive-Ordner `LB3/screenshots/` |
| `avnadmin`-Passwort vergessen            | Password-Manager (Bitwarden) auf Handy         |
| TLS-Cert ausgelaufen                     | Frisches `ca.pem` aus Aiven-UI nachladen (<30 s) |

---

*Dauer Soll: 13 Min. ± 2.*
