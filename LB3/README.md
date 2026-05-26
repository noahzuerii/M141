# LB3 – Backpacker Praxisarbeit

Lernportfolio von **Noah Bachmann** – TBZ Zürich M141, 2025/2026

[← Zurück zur Übersicht](../README.md)

> Eine Jugendherberge migriert ihre Access-Datenbank „Backpacker" auf MariaDB (lokal) und anschliessend auf ein Cloud-RDBMS (AWS RDS). Struktur, Berechtigungen, Daten und Tests werden vollständig dokumentiert.

---

## Scripts-Übersicht

| # | Script | Inhalt |
|:-:|--------|--------|
| 1 | [01_backpacker_ddl.sql](./01_backpacker_ddl.sql) | Datenbank & Tabellen (InnoDB, utf8mb4, FKs) |
| 2 | [02_backpacker_dcl.sql](./02_backpacker_dcl.sql) | Rollen & Benutzer (Zugriffsmatrix) |
| 3 | [03_backpacker_import.sql](./03_backpacker_import.sql) | CSV-Import, Bereinigung, Testdaten |
| 4 | [04_backpacker_test.sql](./04_backpacker_test.sql) | Testprotokolle lokal (Rollen + Konsistenz) |
| 5 | [05_backpacker_migration.sql](./05_backpacker_migration.sql) | Automatisierte Migration auf Cloud |
| 6 | [06_backpacker_cloud_test.sql](./06_backpacker_cloud_test.sql) | Testprotokolle Cloud |

**Ausführungsreihenfolge (lokal):**
```cmd
mysql -u root -p < 01_backpacker_ddl.sql
mysql -u root -p backpacker_noah_lb3 < 03_backpacker_import.sql
mysql -u root -p < 02_backpacker_dcl.sql
mysql -u root -p backpacker_noah_lb3 < 04_backpacker_test.sql
```

---

## MS A – Definition Infrastruktur

### Anforderungsdefinition (SMART)

| Kriterium | Beschreibung |
|-----------|-------------|
| **S** pezifisch | Die Access-Datenbank „Backpacker" wird auf MariaDB (lokal via XAMPP) migriert und anschliessend auf AWS RDS (MySQL 8.0) transferiert. Benutzerrechte werden gemäss Zugriffsmatrix mit Spalten-Grants umgesetzt. |
| **M** essbar | 6 Tabellen importiert, 2 Rollen + 2 Benutzer erstellt, alle Positiv-/Negativ-Tests bestanden, DB-Dump auf Cloud lauffähig, Zeilenzahlen lokal = Cloud. |
| **A** kzeptiert | Auftrag gemäss LB3-Vorgabe TBZ M141, Bewertung nach offiziellem Punkteraster (40 Punkte). |
| **R** ealistisch | Einzelarbeit, Zeitbudget 9–12 Lektionen + Heimarbeit. Tools: XAMPP/MariaDB, MySQL Workbench, AWS RDS. |
| **T** erminiert | MS A: Tag 8 · MS B: Tag 9 · MS C/D + Demo: Tag 10 |

### Evaluation Cloud-RDBMS

| Kriterium | AWS RDS (MySQL 8.0) | Google Cloud SQL | Azure Database for MySQL |
|-----------|:--------------:|:----------------:|:------------------------:|
| Managed Service | ✓ | ✓ | ✓ |
| MariaDB-kompatible Syntax | ✓ | ✓ | ✓ |
| Free Tier verfügbar | ✓ (db.t2.micro) | ✓ (Sandbox) | ✗ |
| SSL/TLS erzwingbar | ✓ | ✓ | ✓ |
| Automatische Backups | ✓ | ✓ | ✓ |
| VPC / Netzwerksicherheit | ✓ | ✓ | ✓ |
| TBZ-Dokumentation / Erfahrung | ✓✓ | ✓ | ✓ |

**Entscheid: AWS RDS – MySQL 8.0**

Begründung: Vollständig verwalteter Dienst, kostenloses Free-Tier (db.t2.micro, 20 GB SSD), einfache VPC-Konfiguration und im TBZ-Umfeld etabliert. MySQL 8.0 unterstützt Rollen (`CREATE ROLE`, `GRANT ... TO role`) vollständig – kompatibel mit dem MariaDB-DCL-Script.

---

## MS B – Lokales DBMS (MariaDB via XAMPP)

### 1.1 ERD – Entity-Relationship-Diagramm (2. Normalform)

```
tbl_personen (1) ────── (N) tbl_buchung (N) ───── (1) tbl_land
                                │
                         (1 Buchung hat N Positionen)
                                ▼
tbl_leistung (0..1) ── (N) tbl_positionen (N) ──── (1) tbl_benutzer
```

> Das Herkunftsland wird auf **tbl_buchung.Land_FS** gespeichert (originalgetreu aus Access), nicht auf tbl_personen.

| Tabelle | Beschreibung | PK | FKs |
|---------|-------------|:--:|-----|
| `tbl_land` | Ländercodes | Land_ID | – |
| `tbl_leistung` | Leistungskatalog (Bett, Frühstück …) | LeistungID | – |
| `tbl_personen` | Gästedaten | Personen_ID | – |
| `tbl_benutzer` | Mitarbeiter-Logins | Benutzer_ID | – |
| `tbl_buchung` | Buchungskopf (Gast + Zeitraum + Land) | Buchungs_ID | Personen_FS → tbl_personen<br>Land_FS → tbl_land |
| `tbl_positionen` | Einzelpositionen (Leistung × Menge × Preis) | Positions_ID | Buchungs_FS → tbl_buchung<br>Leistung_FS → tbl_leistung<br>Benutzer_FS → tbl_benutzer |

**Änderungen gegenüber dem gegebenen DDL (MyISAM/latin1):**

| Änderung | Begründung |
|----------|-----------|
| MyISAM → **InnoDB** | FK-Constraints, Transaktionen, Crash-Recovery |
| latin1 → **utf8mb4** | Korrekte Darstellung von Umlauten und internationalen Zeichen |
| **FK-Constraints** hinzugefügt | Im Original fehlend – nötig für referentielle Integrität |
| `tbl_land`: PRIMARY KEY + AUTO_INCREMENT ergänzt | Im Original-DDL fehlend |
| **Indizes** auf alle FK-Spalten | Performanz bei JOINs |

Die Datenbank befindet sich in der **2. Normalform**:
- 1NF: Alle Attribute atomar, keine Mehrfachwerte
- 2NF: Jedes Nicht-Schlüsselattribut hängt vollständig vom PK ab

### 1.2 Zugriffsmatrix

| Tabelle / Attribut | Benutzer S | I | U | D | Management S | I | U | D |
|---|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|
| tbl_personen | x | | x | | x | x | x | x |
| tbl_benutzer | | | | | | | | |
| **–** Password | – | – | – | – | x | x | x | x |
| **–** deaktiviert | x | – | – | – | x | x | x | x |
| **–** restl. Attribute | x | x | x | – | x | x | x | x |
| tbl_buchung | x | x | x | x | x | | | |
| tbl_positionen | x | x | x | x | x | | | |
| tbl_land | x | | | | x | x | x | x |
| tbl_leistung | x | | | | x | x | x | x |

*S=SELECT, I=INSERT, U=UPDATE, D=DELETE, –=nicht möglich*

### 1.3 Zugriffsberechtigungen (DCL)

Script: [02_backpacker_dcl.sql](./02_backpacker_dcl.sql)

**Umsetzung:** Zwei MariaDB-Rollen, Spalten-Grants für `tbl_benutzer` (kein Zugriff auf `Password`, `deaktiviert` nur lesbar):

```sql
-- benutzer_rolle: SELECT ohne Password-Spalte
GRANT SELECT (Benutzer_ID, Benutzername, Vorname, Name,
              Benutzergruppe, erfasst, deaktiviert, aktiv)
    ON backpacker_noah_lb3.tbl_benutzer TO benutzer_rolle;

-- benutzer_rolle: INSERT/UPDATE ohne Password und deaktiviert
GRANT INSERT (Benutzername, Vorname, Name, Benutzergruppe, aktiv)
    ON backpacker_noah_lb3.tbl_benutzer TO benutzer_rolle;
GRANT UPDATE (Benutzername, Vorname, Name, Benutzergruppe, aktiv)
    ON backpacker_noah_lb3.tbl_benutzer TO benutzer_rolle;
```

**Erstellte Benutzer:**

| Benutzername | Rolle | Passwort |
|---|---|---|
| `ben_noah` | benutzer_rolle | `Backpacker_Ben!1` |
| `mgmt_noah` | management_rolle | `Backpacker_Mgmt!1` |

Beide Benutzer werden für `localhost` und `%` (Cloud-Zugang) angelegt.

### 1.4 Datenbankdaten – Import & Bereinigung

Script: [03_backpacker_import.sql](./03_backpacker_import.sql)

**Import-Ablauf:**

```cmd
REM CSV-Dateien entpacken nach:
REM C:\xampp\mysql\data\backpacker_noah_lb3\csv\

REM my.ini: local_infile = 1 setzen, dann:
mysql --local-infile=1 -u root -p backpacker_noah_lb3 < 03_backpacker_import.sql
```

**Bereinigungsschritte:**

| Schritt | Prüfung | Massnahme |
|---------|---------|-----------|
| B1 | `tbl_buchung.Personen_FS` ohne Person | `SET Personen_FS = NULL` |
| B2 | `tbl_buchung.Land_FS` ohne Land | `SET Land_FS = NULL` |
| B3 | `tbl_positionen.Buchungs_FS` ohne Buchung | Prüfbericht |
| B4 | `tbl_positionen.Benutzer_FS` ohne Benutzer | Prüfbericht |
| B5 | `tbl_positionen.Leistung_FS` ohne Leistung | `SET Leistung_FS = NULL` |
| B6 | Duplikate `Benutzername` | Prüfbericht |
| B7 | `Password` im Klartext (< 64 Zeichen) | `UPDATE SET Password = SHA2(Password, 256)` |
| B8 | Negative Preise / Anzahl | Prüfbericht |
| B9 | Rabatt ausserhalb 0–100 | Prüfbericht |

### 1.5 Testprotokolle – Lokal

Script: [04_backpacker_test.sql](./04_backpacker_test.sql)

#### Rollentest – Benutzer-Rolle (`ben_noah`)

| Test-ID | SQL | Erwartet | Ergebnis |
|---------|-----|----------|----------|
| P01 | `SELECT Personen_ID, Vorname FROM tbl_personen LIMIT 5` | Daten sichtbar | ✓ OK |
| P02 | `UPDATE tbl_personen SET Telefon = '...'` | Query OK | ✓ OK |
| P03 | `SELECT Benutzer_ID, Benutzername, deaktiviert FROM tbl_benutzer` | OK (ohne Password) | ✓ OK |
| P04 | `INSERT INTO tbl_buchung (...)` | Query OK | ✓ OK |
| P05 | `UPDATE tbl_buchung SET Abreise = ...` | Query OK | ✓ OK |
| P06 | `DELETE FROM tbl_buchung WHERE ...` | Query OK | ✓ OK |
| P07 | `SELECT * FROM tbl_land` | alle Länder | ✓ OK |
| P08 | `SELECT * FROM tbl_leistung` | alle Leistungen | ✓ OK |
| N01 | `SELECT Password FROM tbl_benutzer` | ERROR 1143 | ✓ Fehler |
| N02 | `INSERT INTO tbl_personen (...)` | ERROR 1142 | ✓ Fehler |
| N03 | `DELETE FROM tbl_personen WHERE ...` | ERROR 1142 | ✓ Fehler |
| N04 | `INSERT INTO tbl_land (...)` | ERROR 1142 | ✓ Fehler |
| N05 | `UPDATE tbl_benutzer SET deaktiviert = CURDATE()` | ERROR 1143 | ✓ Fehler |
| N06 | `UPDATE tbl_benutzer SET Password = SHA2(...)` | ERROR 1143 | ✓ Fehler |

#### Rollentest – Management-Rolle (`mgmt_noah`)

| Test-ID | SQL | Erwartet | Ergebnis |
|---------|-----|----------|----------|
| P10 | `SELECT * FROM tbl_buchung LIMIT 5` | Buchungen sichtbar | ✓ OK |
| P11 | `SELECT * FROM tbl_positionen LIMIT 5` | Positionen sichtbar | ✓ OK |
| P12 | `INSERT INTO tbl_personen (...)` | Query OK | ✓ OK |
| P13 | `UPDATE tbl_land SET Land = '...'` | Query OK | ✓ OK |
| P14 | `DELETE FROM tbl_personen WHERE ...` | Query OK | ✓ OK |
| P15 | `UPDATE tbl_benutzer SET deaktiviert = CURDATE()` | Query OK | ✓ OK |
| N10 | `INSERT INTO tbl_buchung (...)` | ERROR 1142 | ✓ Fehler |
| N11 | `DELETE FROM tbl_positionen WHERE ...` | ERROR 1142 | ✓ Fehler |
| N12 | `UPDATE tbl_buchung SET ...` | ERROR 1142 | ✓ Fehler |

#### Datenkonsistenz

| Test-ID | Prüfung | Erwartet | Ergebnis |
|---------|---------|----------|----------|
| K01 | Zeilenzahlen alle 6 Tabellen | > 0 | ✓ OK |
| K02 | Waisen `tbl_buchung.Personen_FS` | 0 | ✓ 0 |
| K03 | Waisen `tbl_buchung.Land_FS` | 0 | ✓ 0 |
| K04 | Waisen `tbl_positionen.Buchungs_FS` | 0 | ✓ 0 |
| K05 | Waisen `tbl_positionen.Benutzer_FS` | 0 | ✓ 0 |
| K06 | Waisen `tbl_positionen.Leistung_FS` | 0 | ✓ 0 |
| K07 | Duplikate `Benutzername` | keine | ✓ OK |
| K08 | Password nicht gehasht (< 64 Zeichen) | 0 | ✓ OK |
| K09 | Negative Preise / Anzahl | 0 | ✓ OK |
| K10 | Indizes auf FK-Spalten vorhanden | ✓ | ✓ OK |
| K11 | EXPLAIN auf mehrtabellen-JOIN | key ≠ NULL | ✓ Index genutzt |

---

## MS C – Remote Cloud-DBMS (AWS RDS)

### 2.1 Setup Cloud-DBMS

**Setup-Schritte AWS RDS:**

1. RDS → „Create database"
   - Engine: **MySQL 8.0** · Template: **Free Tier** (db.t2.micro, 20 GB SSD)
   - DB identifier: `backpacker-noah-lb3` · Master username: `admin`
2. Connectivity: Public access **Yes** · Security Group Port 3306 nur für eigene IP
3. Backup retention: 7 Tage · Deletion protection: aktiviert

```cmd
mysql -h <endpoint>.rds.amazonaws.com -u admin -p --ssl-mode=REQUIRED
SELECT @@hostname, @@version;
```

### 2.2 Produktionskonfiguration (AWS RDS Parameter Group)

| Parameter | Wert | Begründung |
|-----------|------|-----------|
| `character_set_server` | `utf8mb4` | Unicode vollständig |
| `collation_server` | `utf8mb4_unicode_ci` | konsistent mit lokaler DB |
| `max_connections` | `100` | ressourcenschonend (t2.micro) |
| `innodb_buffer_pool_size` | `128M` | ~70% RAM (1 GB t2.micro) |
| `slow_query_log` | `1` | langsame Abfragen protokollieren |
| `long_query_time` | `2` | Grenzwert 2 Sekunden |
| `require_secure_transport` | `ON` | SSL/TLS erzwingen |
| `expire_logs_days` | `7` | Binary Logs bereinigen |

**Sicherheitsmassnahmen:**

| Massnahme | Umsetzung |
|-----------|-----------|
| Netzwerk | Security Group: Port 3306 nur für bekannte IPs |
| Verschlüsselung | `require_secure_transport = ON` |
| Passwörter | Mind. 12 Zeichen, Sonderzeichen |
| Backups | 7 Tage Retention, tägliches Backup-Fenster |
| Deletion Protection | Aktiviert |
| Least Privilege | Benutzer nur mit Rechten gemäss Zugriffsmatrix |

---

## MS D – Automatisierte Migration

### 3.1 Berechtigungen übertragen

Das DCL-Script wird direkt auf der Cloud-DB ausgeführt (Passwort-Hashes werden neu gesetzt):

```cmd
mysql -h <endpoint>.rds.amazonaws.com -u admin -p --ssl-mode=REQUIRED ^
  < 02_backpacker_dcl.sql
```

### 3.2 Migration – Struktur & Daten

Script: [05_backpacker_migration.sql](./05_backpacker_migration.sql)

```cmd
REM Schritt 1: Lokales Backup
mysqldump -u root -p ^
  --databases backpacker_noah_lb3 ^
  --add-drop-database --single-transaction --set-gtid-purged=OFF ^
  > C:\backup\backpacker_noah_lb3_dump.sql

REM Schritt 2: Dump auf Cloud einspielen
mysql -h <endpoint>.rds.amazonaws.com -u admin -p --ssl-mode=REQUIRED ^
  < C:\backup\backpacker_noah_lb3_dump.sql

REM Schritt 3: DCL auf Cloud
mysql -h <endpoint>.rds.amazonaws.com -u admin -p < 02_backpacker_dcl.sql
```

**Rollback-Plan:** `DROP DATABASE backpacker_noah_lb3;` auf Cloud → lokale DB läuft weiter.

### 3.3 Testprotokolle – Cloud

Script: [06_backpacker_cloud_test.sql](./06_backpacker_cloud_test.sql)

#### Migrationskonsistenz

| Test-ID | Prüfung | Lokal | Cloud | Status |
|---------|---------|:-----:|:-----:|:------:|
| C01 | DB-Version | MariaDB 10.x | MySQL 8.0.x | ✓ OK |
| C02 | SSL aktiv | – | TLS aktiv | ✓ OK |
| C03 | Tabellen vorhanden | 6 | 6 | ✓ OK |
| C04 | Zeilenzahlen (alle Tabellen) | ident. | ident. | ✓ OK |
| C05 | FK-Constraints | 5 | 5 | ✓ OK |
| C06 | Indizes | vollständig | vollständig | ✓ OK |

#### Rollen auf Cloud

| Test-ID | Benutzer | SQL | Erwartet | Ergebnis |
|---------|---------|-----|----------|----------|
| CP01 | ben_noah | `SELECT ... FROM tbl_personen` | OK | ✓ OK |
| CP02 | ben_noah | `SELECT Benutzer_ID, Benutzername FROM tbl_benutzer` | OK | ✓ OK |
| CP03 | ben_noah | `SELECT Password FROM tbl_benutzer` | ERROR 1143 | ✓ Fehler |
| CP04 | ben_noah | `INSERT INTO tbl_buchung (...)` | Query OK | ✓ OK |
| CM01 | mgmt_noah | `SELECT * FROM tbl_buchung` | OK | ✓ OK |
| CM02 | mgmt_noah | `INSERT INTO tbl_buchung (...)` | ERROR 1142 | ✓ Fehler |
| CM03 | mgmt_noah | `INSERT/DELETE tbl_personen` | Query OK | ✓ OK |

#### Datenkonsistenz Cloud

| Test-ID | Prüfung | Erwartet | Ergebnis |
|---------|---------|----------|----------|
| CK01 | FK-Waisen (alle 5 FKs) | 0 | ✓ 0 |
| CK02 | Password korrekt gehasht | 0 ungehashte | ✓ 0 |

---

## Demo-Ablauf (10–15 Min)

1. Cloud-Verbindung zeigen: `mysql -h <endpoint> -u admin -p --ssl-mode=REQUIRED`
2. `SHOW STATUS LIKE 'Ssl_cipher'` → SSL aktiv
3. Als `ben_noah`: SELECT tbl_personen ✓ → SELECT Password ✗ (Schutz demonstrieren)
4. Als `mgmt_noah`: SELECT tbl_buchung ✓ → INSERT tbl_buchung ✗ (Schutz demonstrieren)
5. Business-Query: Umsatz pro Buchung (mit Rabatt)
6. `EXPLAIN` auf JOIN-Abfrage → Indizes genutzt

---

## KI-Prompts

**DDL & Konvertierung:**
> "Ich habe ein altes phpMyAdmin-DDL-Script (MyISAM, latin1, keine FKs, fehlende PKs). Konvertiere es zu InnoDB + utf8mb4, füge die fehlenden PRIMARY KEYs und FOREIGN KEY Constraints hinzu, und ergänze sinnvolle Indizes auf FK-Spalten. Tabellen: tbl_land, tbl_leistung, tbl_personen, tbl_benutzer, tbl_buchung, tbl_positionen. [DDL eingefügt]"

**DCL Spalten-Grants:**
> "Erstelle ein MariaDB-DCL-Script mit zwei Rollen (benutzer_rolle, management_rolle) für eine Hostel-Datenbank. Benutzer-Rolle: kein Zugriff auf Password-Spalte in tbl_benutzer, deaktiviert nur SELECT. Umsetzung mit GRANT SELECT (col1, col2...) Spalten-Grants. [Zugriffsmatrix eingefügt]"

**Import & Bereinigung:**
> "Schreibe ein SQL-Script für LOAD DATA LOCAL INFILE (6 CSV-Dateien, Delimiter ';', utf8mb4), gefolgt von FK-Waisen-Checks mit LEFT JOIN, Password-Hashing mit SHA2(..., 256) für Klartext-Passwörter, und Prüfungen auf negative Preise und Duplikate."

**Migration AWS RDS:**
> "Erstelle Shell-Befehle (Windows CMD) für mysqldump → AWS RDS Migration: mit --single-transaction, --set-gtid-purged=OFF, SSL-Mode=REQUIRED beim Import, und SQL-Verifikationsqueries (Zeilenzahlen, FK-Constraints, Engine-Check, SSL-Status)."
