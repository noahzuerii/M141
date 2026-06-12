# Testprotokoll – Lokales DBMS (MS B 1.5)

**Autor:** Noah Bachmann · TBZ M141 LB3 · 2025/2026
**DB:** `backpacker_noah_lb3` auf MariaDB 10.4.32 (XAMPP 8.2.4, Windows 11)
**Ausgeführt am:** 2026-06-10 (Tag 9)
**SQL-Quelle:** [04_backpacker_test.sql](./04_backpacker_test.sql)

> Dieses Protokoll dokumentiert die manuelle Verifikation aller im Skript `04_backpacker_test.sql` enthaltenen Tests. Es wird zusammen mit dem Skript abgegeben (MS B 1.5 – „Testprotokolle Rollen, Benutzer → Zugriffsmatrix“ und „Testprotokolle Datenkonsistenz“).

## Test-Setup

| Element                 | Wert                                                   |
|-------------------------|--------------------------------------------------------|
| Hostname (lokal)        | `NOAH-LAPTOP` (Windows 11 Pro 23H2, Build 22631)       |
| MariaDB Version         | `10.4.32-MariaDB`                                      |
| my.ini                  | siehe [my-local.cnf](./my-local.cnf)                   |
| Datenbank-Name          | `backpacker_noah_lb3` *(personalisiert)*               |
| Test-User Frontdesk     | `ben_noah` (Rolle `benutzer_rolle`)                    |
| Test-User Management    | `mgmt_noah` (Rolle `management_rolle`)                 |
| Daten-Quelle            | `backpacker_lb3.csv.zip` aus dem M141-Repo             |
| Zeilen nach Import      | 10 Länder · 8 Leistungen · 8 Personen · 2 Benutzer · 4 Buchungen · 7 Positionen |

### Wie die Tests ausgeführt wurden
```cmd
:: Schema, DCL, Import, Logik
mysql -u root -p < 01_backpacker_ddl.sql
mysql -u root -p < 02_backpacker_dcl.sql
mysql --local-infile=1 -u root -p backpacker_noah_lb3 < 03_backpacker_import.sql
mysql -u root -p backpacker_noah_lb3 < 07_backpacker_views_proc.sql

:: Lokale Tests (anonym, ohne Rolle)
mysql -u root -p backpacker_noah_lb3 < 04_backpacker_test.sql > 04_test_ausgabe.txt

:: Rollentests (interaktiv)
mysql -u ben_noah  -p backpacker_noah_lb3
mysql -u mgmt_noah -p backpacker_noah_lb3
```

---

## T1 – Rollentests (Zugriffsmatrix)

### T1.1 `benutzer_rolle` – Positiv-Tests (Frontdesk `ben_noah`)

| ID  | SQL-Test                                       | Erwartet              | Ergebnis | Bemerkung |
|-----|-----------------------------------------------|-----------------------|----------|-----------|
| P01 | `SELECT … FROM tbl_personen LIMIT 5`          | 5 Zeilen              | ✓ OK     | siehe Skript |
| P02 | `UPDATE tbl_personen SET Telefon=… WHERE ID=2042` | 1 row affected    | ✓ OK     | matched=1, changed=1 |
| P03 | `SELECT (ohne Password) FROM tbl_benutzer`    | 2 Zeilen, kein PW     | ✓ OK     | Password-Spalte nicht angefragt |
| P04 | `INSERT INTO tbl_buchung …`                   | Query OK              | ✓ OK     | LAST_INSERT_ID=1091 |
| P05 | `UPDATE tbl_buchung … WHERE Buchungs_ID=LAST…`| 1 row affected        | ✓ OK     | |
| P06 | `DELETE FROM tbl_buchung … LAST_INSERT_ID`    | 1 row affected        | ✓ OK     | Testbuchung entfernt |
| P07 | `SELECT * FROM tbl_buchung LIMIT 5`           | 4 Zeilen (Originaldaten) | ✓ OK | Buchungen 1087-1090 |
| P08 | `SELECT * FROM tbl_positionen LIMIT 5`        | 5 Zeilen              | ✓ OK     | |
| P09 | `INSERT INTO tbl_positionen …`                | Query OK              | ✓ OK     | Folge-Insert für P04 |
| P10 | `SELECT * FROM v_buchung_uebersicht LIMIT 5`  | View liefert Zeilen   | ✓ OK     | DEFINER-View ohne Basistabellen-Grant |

### T1.2 `benutzer_rolle` – Negativ-Tests (was die Rolle NICHT darf)

| ID  | SQL-Test                                       | Erwartet                            | Ergebnis | MySQL-Fehler |
|-----|-----------------------------------------------|-------------------------------------|----------|--------------|
| N01 | `SELECT Password FROM tbl_benutzer`           | ERROR 1143 (column denied)          | ✓ OK     | `ERROR 1143 (42000): SELECT command denied to user 'ben_noah'@'localhost' for column 'Password' in table 'tbl_benutzer'` |
| N02 | `UPDATE tbl_benutzer SET Password=…`          | ERROR 1143                          | ✓ OK     | `ERROR 1143 (42000): UPDATE command denied … for column 'Password'` |
| N03 | `UPDATE tbl_benutzer SET deaktiviert=NOW()`   | ERROR 1143 (deaktiviert ist read-only) | ✓ OK  | `ERROR 1143 (42000): UPDATE command denied … for column 'deaktiviert'` |
| N04 | `DELETE FROM tbl_benutzer WHERE ID=27`        | ERROR 1142 (no DELETE on table)     | ✓ OK     | `ERROR 1142 (42000): DELETE command denied to user 'ben_noah'@'localhost' for table 'tbl_benutzer'` |
| N05 | `INSERT INTO tbl_land VALUES (99,'Atlantis')` | ERROR 1142                          | ✓ OK     | `ERROR 1142 (42000): INSERT command denied … for table 'tbl_land'` |
| N06 | `DELETE FROM tbl_leistung WHERE LeistungID=1` | ERROR 1142                          | ✓ OK     | `ERROR 1142 (42000): DELETE command denied … for table 'tbl_leistung'` |
| N07 | `SELECT * FROM v_umsatz_pro_buchung`          | ERROR 1142 (View nur Management)    | ✓ OK     | `ERROR 1142 (42000): SELECT command denied … for table 'v_umsatz_pro_buchung'` |
| N08 | `SELECT * FROM tbl_audit_log`                 | ERROR 1142                          | ✓ OK     | `ERROR 1142 (42000): SELECT command denied … for table 'tbl_audit_log'` |

### T1.3 `management_rolle` – Positiv-Tests (Verwaltung `mgmt_noah`)

| ID  | SQL-Test                                       | Erwartet              | Ergebnis | Bemerkung |
|-----|-----------------------------------------------|-----------------------|----------|-----------|
| M01 | `SELECT Password FROM tbl_benutzer`           | 2 Hash-Strings (64 Zeichen) | ✓ OK | SHA-256-Hashes sichtbar |
| M02 | `UPDATE tbl_benutzer SET Password=SHA2('neu',256)` | 1 row affected | ✓ OK | Trigger `tr_audit_pw_aenderung` ausgelöst |
| M03 | `SELECT * FROM tbl_audit_log`                 | 1 Zeile (PASSWORD_CHANGE) | ✓ OK | Trigger schrieb Audit-Log |
| M04 | `UPDATE tbl_benutzer SET deaktiviert=CURDATE() WHERE ID=28` | 1 row | ✓ OK | |
| M05 | `INSERT INTO tbl_land (Land) VALUES ('Liechtenstein')` | Query OK | ✓ OK | |
| M06 | `DELETE FROM tbl_land WHERE Land='Liechtenstein'` | Query OK | ✓ OK | Cleanup |
| M07 | `INSERT INTO tbl_leistung VALUES (99,'Test-Leistung')` | Query OK | ✓ OK | |
| M08 | `DELETE FROM tbl_leistung WHERE LeistungID=99` | Query OK | ✓ OK | Cleanup |
| M09 | `SELECT * FROM v_umsatz_pro_buchung`          | 4 Zeilen Umsatz       | ✓ OK | Gesamtumsatz CHF 577.78 |
| M10 | `CALL sp_monatsbericht(2026, 6)`              | 4 Buchungen Juni 2026 | ✓ OK | |
| M11 | `CALL sp_umsatz_zusammenfassung()`            | 1 Zeile Aggregat      | ✓ OK | 4 Buchungen, 577.78 CHF, ø 2.6 Nächte |

### T1.4 `management_rolle` – Negativ-Tests

| ID  | SQL-Test                                       | Erwartet | Ergebnis | MySQL-Fehler |
|-----|-----------------------------------------------|----------|----------|--------------|
| N09 | `INSERT INTO tbl_buchung …`                   | ERROR 1142 | ✓ OK | `ERROR 1142 (42000): INSERT command denied to user 'mgmt_noah'@'localhost' for table 'tbl_buchung'` |
| N10 | `UPDATE tbl_positionen SET Preis=99 WHERE Positions_ID=4055` | ERROR 1142 | ✓ OK | `ERROR 1142 (42000): UPDATE command denied … for table 'tbl_positionen'` |
| N11 | `DELETE FROM tbl_positionen`                  | ERROR 1142 | ✓ OK | `ERROR 1142 (42000): DELETE command denied … for table 'tbl_positionen'` |

**Subtotal T1:** 30/30 Tests bestanden, 8 Negativ-Tests bestätigt.

---

## T2 – Datenkonsistenz nach Import & Bereinigung

| ID  | Check                                                | Erwartet | Ergebnis | Output |
|-----|-----------------------------------------------------|----------|----------|--------|
| K01 | Zeilenzahl `tbl_land`                                | 10       | ✓ 10     | `10`   |
| K02 | Zeilenzahl `tbl_leistung`                            | 8        | ✓ 8      | `8`    |
| K03 | Zeilenzahl `tbl_personen`                            | 8        | ✓ 8      | `8`    |
| K04 | Zeilenzahl `tbl_benutzer`                            | 2        | ✓ 2      | `2`    |
| K05 | Zeilenzahl `tbl_buchung`                             | 4        | ✓ 4      | `4`    |
| K06 | Zeilenzahl `tbl_positionen`                          | 7        | ✓ 7      | `7`    |
| K07 | FK-Waisen `buchung.Personen_FS → personen`           | 0        | ✓ 0      | LEFT JOIN ergibt 0 NULL-Treffer |
| K08 | Passwords gehasht (LEN=64, SHA-256)                  | 0 unhashed | ✓ 0    | `WHERE LENGTH(Password)<64 OR NULL` → 0 |
| K09 | CHECK `chk_pos_preis` (Preis ≥ 0)                    | 0        | ✓ 0      | |
| K10 | CHECK `chk_pos_anzahl` (Anzahl ≥ 0)                  | 0        | ✓ 0      | |
| K11 | CHECK `chk_pos_rabatt` (0–100)                       | 0        | ✓ 0      | |

**Subtotal T2:** 11/11 OK – Datenkonsistenz lokal nachgewiesen.

### Negativtest CHECK-Constraint (manuell)
```sql
INSERT INTO tbl_positionen (Buchungs_FS, Konto, Anzahl, Preis, Rabatt, Benutzer_FS, erfasst, Leistung_Text)
VALUES (1087, 4000, 1, -10.00, 0, 27, NOW(), 'Negativ-Test');
-- Ergebnis: ERROR 4025 (HY000): CONSTRAINT `chk_pos_preis` failed for `backpacker_noah_lb3`.`tbl_positionen`
-- ✓ OK – CHECK greift
```

---

## T4 – Views, Stored Procedures, Function, Trigger, CTE

| ID  | Objekt                            | Test                                | Ergebnis |
|-----|----------------------------------|-------------------------------------|----------|
| V01 | `v_buchung_uebersicht`            | 4 Zeilen, JOINs korrekt             | ✓ OK |
| V02 | `v_umsatz_pro_buchung`            | Netto je Buchung, Order DESC        | ✓ OK |
| V03 | `v_top_leistungen`                | 4 Leistungen mit Umsatz             | ✓ OK |
| P01 | `sp_monatsbericht(2026,6)`        | 4 Buchungen Juni 2026               | ✓ OK |
| P02 | `sp_umsatz_zusammenfassung()`     | 4 / 4 / 577.78 CHF / 2.6            | ✓ OK |
| F01 | `fn_buchung_netto(1087)`          | 94.50                               | ✓ OK |
| F02 | `fn_buchung_netto(1089)`          | 253.28                              | ✓ OK |
| T01 | Trigger `tr_audit_pw_aenderung`   | Eintrag im `tbl_audit_log` nach M02 | ✓ OK |
| T02 | Trigger `tr_buchung_datum_insert` | INSERT mit Abreise < Ankunft        | ✗ blockiert → ✓ OK |
| T03 | Trigger `tr_buchung_datum_update` | UPDATE mit Abreise < Ankunft        | ✗ blockiert → ✓ OK |

```text
-- T02 / T03 Beispiel-Fehler (gewünscht!):
INSERT INTO tbl_buchung (Personen_FS, Ankunft, Abreise, Land_FS)
VALUES (2042, '2026-09-10', '2026-09-08', 1);
ERROR 1644 (45000): Abreise muss nach Ankunft liegen
```

**Subtotal T4:** 10/10 OK – alle DB-Objekte funktional und Trigger schützen Eingaben.

---

## Zusammenfassung

| Bereich                          | Geprüft | OK | Note |
|----------------------------------|:-------:|:--:|------|
| T1 Rollentests `ben_noah`        | 18      | 18 | ✓    |
| T1 Rollentests `mgmt_noah`       | 14      | 14 | ✓    |
| T2 Datenkonsistenz               | 11      | 11 | ✓    |
| T3/T4 Views / SP / Function / Trigger | 10 | 10 | ✓ |
| **Summe**                        | **53**  | **53** | **100 %** |

> Die Daten sind nach Import konsistent, alle FK/CHECK-Constraints greifen, die Zugriffsmatrix wird sowohl auf Tabellen- als auch auf Spaltenebene durchgesetzt. Audit-Trigger schreibt PW-Änderungen nachvollziehbar in `tbl_audit_log`. Die Datenbank ist bereit für die Migration in die Cloud (MS C/D).

— *Noah Bachmann, Zürich, 2026-06-10*
