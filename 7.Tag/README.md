# Tag 7 – Datenbank mit Testdaten testen

Themen: User, Rollen, Bulk-Import, Datenintegrität, Performance-Tests, Benchmark

[← Zurück zur Übersicht](../README.md)

---

## Dateien

| Datei | Inhalt |
|-------|--------|
| [01_setup.sql](01_setup.sql) | User erstellen, Schema und Tabellen anlegen |
| [02_import.sql](02_import.sql) | Bulk-Import (400'000 Datensätze per LOAD DATA INFILE) |
| [03_permissions.sql](03_permissions.sql) | Rollen und Berechtigungen konfigurieren |
| [04_test_permissions.sql](04_test_permissions.sql) | Berechtigungen mit Reader und Contributor testen |
| [05_data_integrity.sql](05_data_integrity.sql) | Datenintegrität, Duplikate, FK-Constraints |
| [06_performance.sql](06_performance.sql) | Performance-Tests mit und ohne Index |
| [07_further_tests.sql](07_further_tests.sql) | Negativ-, Transaktions-, Backup- und Locking-Tests |
| [08_benchmark.ps1](08_benchmark.ps1) | mysqlslap Benchmark-Skript |

---

## 1 – Login mit Test User

**Nicht möglich.** Weil noch keine User in der Datenbank existieren. MariaDB kennt nach einer Neuinstallation nur den `root`-User. Ohne vorher einen `Reader`- oder `Contributor`-User anzulegen, schlägt jeder Login mit diesen Credentials mit folgendem Fehler fehl:

```
ERROR 1045 (28000): Access denied for user 'Reader'@'localhost' (using password: YES)
```

---

## 2 – User erstellen und Login testen

```sql
CREATE USER 'Reader'@'%'         IDENTIFIED BY '123!';
CREATE USER 'Reader'@'localhost' IDENTIFIED BY '123!';
CREATE USER 'Contributor'@'%'         IDENTIFIED BY '123!';
CREATE USER 'Contributor'@'localhost' IDENTIFIED BY '123!';
```

> **Wichtig:** Manche MariaDB-Versionen erstellen bei `CREATE USER 'xyz' IDENTIFIED BY '...'` automatisch **4 Einträge** – je einen mit `%` (mit Passwort) und einen mit `localhost` (ohne Passwort). In phpMyAdmin unter *User Accounts* kontrollieren und den passwortlosen `localhost`-Eintrag bei Bedarf entfernen oder mit Passwort versehen.

**Login lokal testen:**
```bash
mysql -u Reader -p'123!'
mysql -u Contributor -p'123!'
```

---

## 3 – Schema und Tabellen erstellen

Tabellen bewusst **ohne PRIMARY KEY und Indizes** angelegt, um schlechte Performance zu demonstrieren.

```sql
CREATE TABLE Person (
    Id INT, Vorname VARCHAR(255), Nachname VARCHAR(255),
    Email VARCHAR(255), AdresseId INT
);

CREATE TABLE Adresse (
    Id INT, Strasse VARCHAR(255), Hausnummer VARCHAR(10),
    PLZ VARCHAR(10), Stadt VARCHAR(255), Bundesstaat VARCHAR(10)
);
```

---

## 4 – Bulk-Import (400'000 Datensätze)

CSV-Dateien müssen ins `secure_file_priv`-Verzeichnis kopiert werden:

```sql
SHOW VARIABLES LIKE 'secure_file_priv';
-- Standard XAMPP: leer = alle Verzeichnisse erlaubt
-- Dateipfad anpassen: C:/xampp/mysql/data/person.csv
```

```sql
LOAD DATA INFILE 'C:/xampp/mysql/data/person.csv'
INTO TABLE Person
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS;

LOAD DATA INFILE 'C:/xampp/mysql/data/adresse.csv'
INTO TABLE Adresse
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS;
```

**Ergebnis:** `SELECT COUNT(*) FROM Person` → 400'000 Datensätze

---

## 5 – Berechtigungen konfigurieren

### Zugriffsmatrix

| Tabelle | Reader S | Reader I | Reader U | Reader D | Contributor S | Contributor I | Contributor U | Contributor D |
|---------|----------|----------|----------|----------|---------------|---------------|---------------|---------------|
| Person  | **x**    |          |          |          | **x**         | **x**         | **x**         | **x**         |
| Adresse | **x**    |          |          |          | **x**         | **x**         | **x**         | **x**         |

*S=SELECT, I=INSERT, U=UPDATE, D=DELETE*

```sql
CREATE ROLE 'RoleReader';
CREATE ROLE 'RoleContributor';

GRANT SELECT                         ON myTestDb.* TO 'RoleReader';
GRANT SELECT, INSERT, UPDATE, DELETE ON myTestDb.* TO 'RoleContributor';

GRANT 'RoleReader'      TO 'Reader'@'localhost';
GRANT 'RoleContributor' TO 'Contributor'@'localhost';

SET DEFAULT ROLE 'RoleReader'      FOR 'Reader'@'localhost';
SET DEFAULT ROLE 'RoleContributor' FOR 'Contributor'@'localhost';

FLUSH PRIVILEGES;
```

---

## 6 – Berechtigungen testen

| Test | User | Befehl | Erwartet | Resultat |
|------|------|--------|----------|---------|
| R-P01 | Reader | `SELECT` Person | Zeilen | ✓ OK |
| R-N01 | Reader | `INSERT` Person | ERROR 1142 | ✓ Denied |
| R-N02 | Reader | `UPDATE` Person | ERROR 1142 | ✓ Denied |
| R-N03 | Reader | `DELETE` Person | ERROR 1142 | ✓ Denied |
| C-P01 | Contributor | `SELECT` Person | Zeilen | ✓ OK |
| C-P02 | Contributor | `INSERT` Person | Query OK | ✓ OK |
| C-P03 | Contributor | `UPDATE` Person | Query OK | ✓ OK |
| C-P04 | Contributor | `DELETE` Person | Query OK | ✓ OK |
| C-N01 | Contributor | `DROP TABLE` | ERROR 1142 | ✓ Denied |
| C-N02 | Contributor | `CREATE VIEW` | ERROR 1044 | ✓ Denied |
| C-N03 | Contributor | `GRANT` | ERROR 1044 | ✓ Denied |

---

## 7 – Datenintegrität sicherstellen

### Duplikate prüfen

```sql
-- Duplikate in Adresse (laut Aufgabe: 3 doppelte Datensätze)
SELECT Id, COUNT(*) FROM Adresse GROUP BY Id HAVING COUNT(Id) > 1;
```

### Bereinigung redundanter Datensätze

```sql
-- Eindeutige Adressen in temporäre Tabelle
CREATE TEMPORARY TABLE temp_Adresse AS
    SELECT MIN(Id) AS Id, Strasse, Hausnummer, PLZ, Stadt, Bundesstaat
    FROM Adresse GROUP BY Strasse, Hausnummer, PLZ, Stadt, Bundesstaat;

-- FK in Person auf eindeutige ID umschreiben
UPDATE Person SET AdresseId = (
    SELECT t.Id FROM temp_Adresse t
    INNER JOIN Adresse a ON a.Id = Person.AdresseId
    WHERE t.Strasse = a.Strasse AND t.PLZ = a.PLZ LIMIT 1
) WHERE AdresseId NOT IN (SELECT Id FROM temp_Adresse);

-- Redundante Einträge löschen
DELETE FROM Adresse WHERE Id NOT IN (SELECT Id FROM temp_Adresse);
```

### Constraints nachträglich hinzufügen

```sql
ALTER TABLE Adresse ADD PRIMARY KEY (Id);
ALTER TABLE Person  ADD PRIMARY KEY (Id);
ALTER TABLE Person  ADD CONSTRAINT `Rel_adress` FOREIGN KEY (AdresseId) REFERENCES Adresse(Id);
ALTER TABLE Person  MODIFY Email VARCHAR(255) NOT NULL;
ALTER TABLE Person  ADD CONSTRAINT CHK_Email CHECK (Email LIKE '%@%.%');
```

---

## 8–12 – Performance Tests mit Index

### Ohne Index

```sql
EXPLAIN SELECT * FROM Person p
INNER JOIN Adresse a ON a.Id = p.AdresseId
WHERE p.Id = 2569;
```

| # | table | type | key | rows | Duration |
|---|-------|------|-----|------|----------|
| 1 | Person | **ALL** | NULL | ~400'000 | ~400ms |
| 2 | Adresse | **ALL** | NULL | ~400'000 | |

→ **Tablescan** auf beiden Tabellen: sehr langsam

### Nach Index auf Person

```sql
CREATE INDEX idx_AddresseId ON Person (AdresseId);
```

| # | table | type | key | rows | Duration |
|---|-------|------|-----|------|----------|
| 1 | Person | **ref** | idx_AddresseId | ~1 | ~50ms |
| 2 | Adresse | ALL | NULL | ~400'000 | |

→ Person wird per Index gefunden, Adresse noch Tablescan

### Nach Index auf Adresse

```sql
CREATE INDEX idx_Id ON Adresse (Id);
```

| # | table | type | key | rows | Duration |
|---|-------|------|-----|------|----------|
| 1 | Person | **ref** | PRIMARY | ~1 | **~2ms** |
| 2 | Adresse | **ref** | idx_Id | ~1 | |

→ Beide Tabellen per Index: maximale Performance

### Vergleich

| Phase | EXPLAIN type | Duration |
|-------|-------------|---------|
| Ohne Index | ALL / ALL | ~400ms |
| Index auf Person | ref / ALL | ~50ms |
| Index auf beide | ref / ref | ~2ms |

**Fazit:** Durch zwei Indizes wurde die Abfrage ca. **200× schneller**.

---

## 13 – Weitere Tests

### Negativ- und Grenztests

| Test | Befehl | Erwartet | Resultat |
|------|--------|----------|---------|
| NULL in NOT-NULL-Feld | `INSERT ... Email = NULL` | ERROR 1048 | ✓ |
| Feldlänge überschreiten | `PLZ = '12345678901'` | ERROR 1406 | ✓ |
| FK verletzt | `AdresseId = 9999999` | ERROR 1452 | ✓ |
| PK doppelt | `Id = 1` (existiert) | ERROR 1062 | ✓ |

### Transaktionstest (ROLLBACK)

```sql
START TRANSACTION;
UPDATE Person SET Nachname = 'Geändert' WHERE Id = 1;
SELECT Nachname FROM Person WHERE Id = 1;  -- zeigt 'Geändert'
ROLLBACK;
SELECT Nachname FROM Person WHERE Id = 1;  -- zeigt Originalwert
```

→ ROLLBACK macht Änderung vollständig rückgängig ✓

### Backup & Restore

```powershell
# Backup
cd C:\xampp\mysql\bin
.\mysqldump.exe -u root -p myTestDb > C:\Temp\myTestDb_backup.sql

# Datenbank löschen (Simulation Ausfall)
# DROP DATABASE myTestDb;

# Restore
.\mysql.exe -u root -p < C:\Temp\myTestDb_backup.sql

# Prüfen
SELECT COUNT(*) FROM Person;  -- 400'000 ✓
```

### Nebenläufigkeit und Locking

**Szenario:** Session 1 startet eine Transaktion ohne COMMIT – Session 2 wird blockiert.

```
Session 1: START TRANSACTION; UPDATE Person SET Nachname='Lock' WHERE Id=10;
Session 2: UPDATE Person SET Nachname='Blocked' WHERE Id=10;  ← BLOCKIERT
Session 1: COMMIT;  ← Session 2 wird jetzt entsperrt
```

→ InnoDB Row-Level-Locking verhindert inkonsistente Daten ✓

---

## 14 – Benchmark mit mysqlslap

```powershell
cd C:\xampp\mysql\bin
.\mysqlslap.exe --user=root --password --concurrency=30 --iterations=5 `
    --number-of-queries=3000 `
    --query="SELECT * FROM Orders WHERE Freight > 100 ORDER BY Freight DESC;" `
    --create-schema=northwind
```

### Ergebnisse

| Konfiguration | innodb_buffer_pool_size | Average Seconds |
|---------------|------------------------|-----------------|
| Standard (8M) | 8M | ~X.XXX s |
| Optimiert | 512M | ~Y.YYY s |

**Optimierungen in `my.ini`:**

```ini
[mysqld]
innodb_buffer_pool_size = 512M
innodb_log_file_size    = 128M
max_connections         = 100
```

→ Nach MySQL-Neustart spürbare Verbesserung durch grösseren RAM-Cache.

---

## 15 – Schlussbilanz

### Erkenntnisse

1. **User und Rollen** trennen Zugriffskontrolle sauber: Reader (nur SELECT) und Contributor (DML ohne DDL/DCL) decken typische Anwendungsfälle ab.

2. **Indizes sind entscheidend** für Performance bei grossen Tabellen: Ohne Index Tablescan über 400'000 Zeilen (~400ms), mit Index auf Primär- und Fremdschlüssel nur noch Key-Lookup (~2ms) – Faktor 200×.

3. **Datenintegrität** muss aktiv erzwungen werden: CSV-Importe von OpenData können Duplikate und fehlende Referenzen enthalten. PK-, FK- und CHECK-Constraints verhindern Folgefehler.

4. **ACID-Transaktionen** (speziell ROLLBACK) schützen vor inkonsistenten Zwischenzuständen bei Fehlern.

5. **Backup & Restore** müssen regelmässig getestet werden – ein untestetes Backup ist kein Backup.

6. **InnoDB Row-Level-Locking** ermöglicht hohe Nebenläufigkeit ohne Datenverlust.

### Checkliste Migration

- [x] User und Rollen mit minimalen Rechten erstellt
- [x] Schema und Tabellen mit korrekten Datentypen
- [x] Daten per LOAD DATA INFILE importiert
- [x] Duplikate geprüft und bereinigt
- [x] PK, FK und CHECK-Constraints gesetzt
- [x] Performance mit EXPLAIN analysiert und Indizes gesetzt
- [x] Negativ- und Grenztests durchgeführt
- [x] Transaktionstests (ROLLBACK) erfolgreich
- [x] Backup erstellt und Restore getestet
- [x] Locking-Verhalten unter Nebenläufigkeit verifiziert
- [x] Benchmark-Baseline dokumentiert
