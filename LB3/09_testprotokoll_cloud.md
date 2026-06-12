# Testprotokoll – Cloud-DBMS Aiven (MS D 3.3)

**Autor:** Noah Bachmann · TBZ M141 LB3 · 2025/2026
**Cloud-Plattform:** **Aiven for MySQL 8.0** (Plan `business-4`, Trial)
**Region:** `google-europe-west6` (Zürich)
**Service-Name:** `backpacker-noah-lb3`
**Ausgeführt am:** 2026-06-12 (Tag 10)
**SQL-Quelle:** [06_backpacker_cloud_test.sql](./06_backpacker_cloud_test.sql)

> Dieses Protokoll dokumentiert die Tests **nach** Migration von der lokalen MariaDB-Instanz auf Aiven. Es belegt MS D 3.3 (Testprotokolle Rollen / Datenkonsistenz / Migration) sowie MS C 2.2 (gesicherter produktiver Betrieb).

> **Cloud-Pivot:** Anstelle der ursprünglich in der Vorgabe genannten AWS RDS wurde **Aiven** verwendet, da kein AWS-Konto bereitgestellt werden konnte. Details siehe [README.md](./README.md) und [10_aiven_setup.md](./10_aiven_setup.md). Die Tests bleiben SQL-seitig identisch.

## Verbindungs-Setup

```cmd
:: Endpoint + CA-Cert
set AIVEN_HOST=backpacker-noah-lb3-noah-lb3.h.aivencloud.com
set AIVEN_PORT=12947
set AIVEN_CA=C:\backup\aiven_ca.pem

:: Admin-Login
mysql -h %AIVEN_HOST% -P %AIVEN_PORT% -u avnadmin -p ^
      --ssl-mode=VERIFY_CA --ssl-ca=%AIVEN_CA% backpacker_noah_lb3

:: Frontdesk-Login
mysql -h %AIVEN_HOST% -P %AIVEN_PORT% -u ben_noah  -p ^
      --ssl-mode=VERIFY_CA --ssl-ca=%AIVEN_CA% backpacker_noah_lb3

:: Management-Login
mysql -h %AIVEN_HOST% -P %AIVEN_PORT% -u mgmt_noah -p ^
      --ssl-mode=VERIFY_CA --ssl-ca=%AIVEN_CA% backpacker_noah_lb3
```

---

## C1 – Migrationskonsistenz

| ID  | Test                                  | Erwartet                              | Ergebnis | Output |
|-----|---------------------------------------|---------------------------------------|----------|--------|
| C01 | `SELECT @@hostname, @@version, …`     | MySQL 8.0.x, utf8mb4, SSL ON          | ✓ OK | host=`backpacker-noah-lb3-noah-lb3.h.aivencloud.com`, version=`8.0.35`, charset=`utf8mb4`, SSL=`ON` |
| C02 | `SHOW STATUS LIKE 'Ssl_cipher'`       | TLS 1.3 cipher                        | ✓ OK | `TLS_AES_256_GCM_SHA384` |
| C03 | `information_schema.tables` (7 Stk.)  | InnoDB + utf8mb4_unicode_ci           | ✓ OK | 7 Zeilen, alle InnoDB |
| C04 | Zeilenzahlen Cloud == lokal           | 10/8/8/2/4/7/0                        | ✓ OK | identisch |
| C05 | 5 FK-Constraints aktiv                | fk_buch_land, fk_buch_pers, fk_pos_*  | ✓ OK | 5 FKs gefunden |
| C06 | 3 CHECK-Constraints aktiv             | chk_pos_preis/anzahl/rabatt           | ✓ OK | 3 CHECKs gefunden |
| C07 | Indizes (12 Einträge inkl. idx)       | inkl. `idx_buch_ankunft`              | ✓ OK | 12 Index-Zeilen |
| C08 | Routinen + Trigger vorhanden          | 1 Function, 2 Procedures, 3 Trigger   | ✓ OK | wie lokal |
| C09 | `SHOW GRANTS FOR ben_noah`            | identisch zu lokal                    | ✓ OK | Column-Grants korrekt übertragen |
| C10 | `SHOW GRANTS FOR mgmt_noah`           | identisch zu lokal                    | ✓ OK | inkl. ALL on tbl_personen |

**Subtotal C1:** 10/10 OK – Migration strukturell und datenmässig identisch.

---

## C2 – Rollentests in der Cloud

### C2.1 `ben_noah` (Frontdesk)

| ID   | Test                                              | Erwartet | Ergebnis | Bemerkung |
|------|---------------------------------------------------|----------|----------|-----------|
| CP01 | `SELECT … FROM tbl_personen LIMIT 5`              | Zeilen   | ✓ OK     | Anna Muster, Beat Frei, … |
| CP02 | `SELECT (ohne Password) FROM tbl_benutzer`        | Zeilen   | ✓ OK     | |
| CP03 | `SELECT Password FROM tbl_benutzer`               | ERROR 1143 | ✓ OK   | Spaltenschutz auf Cloud aktiv |
| CP04 | `INSERT INTO tbl_buchung …`                       | OK       | ✓ OK     | Buchungs_ID 1091 |
| CP05 | `SELECT …  ORDER BY ID DESC LIMIT 1`              | Zeile    | ✓ OK     | |
| CP06 | `DELETE FROM tbl_buchung … 2042 / 2026-07-01`     | OK       | ✓ OK     | Cleanup |
| CP07 | `SELECT * FROM v_buchung_uebersicht LIMIT 5`      | Zeilen   | ✓ OK     | View via DEFINER |
| CP08 | `SELECT * FROM v_umsatz_pro_buchung`              | ERROR 1142 | ✓ OK   | Nur Management |
| CP09 | `SELECT fn_buchung_netto(1087)`                   | 94.50    | ✓ OK     | |

### C2.2 `mgmt_noah` (Management)

| ID   | Test                                              | Erwartet | Ergebnis | Bemerkung |
|------|---------------------------------------------------|----------|----------|-----------|
| CM01 | `SELECT … FROM tbl_buchung LIMIT 5`               | Zeilen   | ✓ OK     | 4 Buchungen |
| CM02 | `INSERT INTO tbl_buchung …`                       | ERROR 1142 | ✓ OK   | Negativ erwartet |
| CM03 | `INSERT/DELETE tbl_personen` ('Cloud TestGast')   | OK + OK  | ✓ OK     | Cleanup erfolgreich |
| CM04 | `UPDATE tbl_benutzer.deaktiviert` (toggle/zurück) | 1 row    | ✓ OK     | Trigger ruht (keine PW-Änderung) |
| CM05 | `SELECT * FROM v_umsatz_pro_buchung LIMIT 5`      | 4 Zeilen | ✓ OK     | Gesamtumsatz 577.78 CHF |
| CM06 | `CALL sp_monatsbericht(2026,6)`                   | 4 Zeilen | ✓ OK     | |
| CM07 | `CALL sp_umsatz_zusammenfassung()`                | 1 Zeile  | ✓ OK     | 4/4/577.78/2.6 |

**Subtotal C2:** 16/16 Rolltests in der Cloud OK – Zugriffsmatrix wirksam.

---

## C3 – Datenkonsistenz nach Migration (als `avnadmin`)

| ID   | Check                                                 | Erwartet | Ergebnis |
|------|-------------------------------------------------------|----------|----------|
| CK01 | FK-Waisen `buchung.Personen_FS → personen`            | 0        | ✓ 0      |
| CK02 | FK-Waisen `buchung.Land_FS → land`                    | 0        | ✓ 0      |
| CK03 | FK-Waisen `positionen.Buchungs_FS → buchung`          | 0        | ✓ 0      |
| CK04 | FK-Waisen `positionen.Benutzer_FS → benutzer`         | 0        | ✓ 0      |
| CK05 | FK-Waisen `positionen.Leistung_FS → leistung`         | 0        | ✓ 0      |
| CK06 | Ungehashte Passwörter (`LEN<64`)                      | 0        | ✓ 0      |
| CK07 | CHECK-Verletzungen (Preis<0, Anzahl<0, Rabatt out)    | 0/0/0    | ✓ 0/0/0  |

**Subtotal C3:** 7/7 OK – kein Datenverlust und keine Integritätsbrüche im Restore.

---

## C4 – Business-Logik & Performance (Demo-Vorbereitung)

| ID  | Abfrage                                               | Ergebnis |
|-----|-------------------------------------------------------|----------|
| D01 | Umsatz pro Monat                                      | `2026-06 / 4 / 577.78` ✓ |
| D02 | View `v_top_leistungen`                              | Einzelzimmer 374.78, Schlafsaal 110.00, Frühstück 57.00, Velo 36.00 ✓ |
| D03 | Top-Gäste nach Ausgaben                              | Emma Wagner 253.28, Hiro Tanaka 186.00, … ✓ |
| D04 | Aktive Mitarbeiter                                    | 2 (isa.schneider, jonas.huber) ✓ |
| D05 | Window-Function `RANK() OVER (…)`                     | Rang 1–4 sauber, kum. Umsatz korrekt ✓ |
| D06 | CTE „Buchungen > Durchschnitt“                        | 2 Buchungen über Ø (144.45 CHF) ✓ |
| D07 | `EXPLAIN` für Datumsbereich                           | `idx_buch_ankunft` genutzt (type=range), keine ALL-Scans ✓ |
| D08 | Stored Function inline                                | Identische Werte wie View `v_umsatz_pro_buchung` ✓ |
| D09 | Trigger-Verifikation `tbl_audit_log`                  | leer (Restore via DCL ohne PW-UPDATE) ✓ |

**Subtotal C4:** 9/9 Business-Logik-Cases OK.

---

## Sicherheits-Verifikation (MS C 2.2)

| Aspekt | Erwartet | Ergebnis |
|--------|----------|----------|
| Port-Scan von externer IP via `nmap` | nur `12947/tcp`, sonst gefiltert | ✓ OK – `12947/tcp open mysql`, andere Ports `filtered` |
| Login ohne `--ssl-mode` | abgewiesen | ✓ `ERROR 2026 (HY000): SSL connection error: socket layer receive error` |
| Login mit `--ssl-mode=DISABLED` | abgewiesen | ✓ `ERROR 1045 (28000): Access denied for user 'avnadmin' (using password: YES)` – Aiven blockt unverschlüsselte Sessions |
| Login mit falscher CA | abgewiesen | ✓ `ERROR 2026: SSL connection error: certificate verify failed` |
| Login mit gültiger CA `aiven_ca.pem` | erlaubt | ✓ OK – Banner zeigt `Cipher in use is TLS_AES_256_GCM_SHA384` |
| Login mit unbekannter IP (mobiles Hotspot) | abgewiesen | ✓ `ERROR 2003 (HY000): Can't connect to MySQL server …(10060 timeout)` – IP-Allowlist greift |

---

## Zusammenfassung Cloud-Tests

| Bereich                              | Geprüft | OK | Note |
|--------------------------------------|:-------:|:--:|------|
| C1 Migrationskonsistenz              | 10      | 10 | ✓    |
| C2 Rollentests (ben_noah + mgmt_noah)| 16      | 16 | ✓    |
| C3 Datenkonsistenz nach Migration    | 7       | 7  | ✓    |
| C4 Business-Logik / Performance      | 9       | 9  | ✓    |
| Sicherheits-Verifikation (TLS/IP)    | 6       | 6  | ✓    |
| **Summe**                            | **48**  | **48** | **100 %** |

### Endergebnis
* **Strukturell identisch** zur lokalen DB (Tabellen, Indizes, FKs, CHECKs, Routinen, Trigger).
* **Datenkonsistent** – Zeilenzahlen 1 : 1 übernommen, keine Waisen, keine Klartextpasswörter.
* **Zugriffsmatrix wirksam** – auch in der Cloud werden Spalten- und Tabellen-Grants konsequent durchgesetzt.
* **Sicherer Betrieb** – TLS 1.3, IP-Allowlist, automatische Backups, Hot-Standby.
* **Bereit für den produktiven Betrieb** – alle Tests grün, Sicherheit verifiziert.

— *Noah Bachmann, Zürich, 2026-06-12*
