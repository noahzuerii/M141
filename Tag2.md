# M141 – Tag 2: Konfiguration & Datenimport

---

## 1. Optionsdateien (my.ini)

### Welche .ini-Dateien existieren auf dem System?

MySQL/MariaDB sucht Konfigurationsdateien in dieser Reihenfolge (Windows):

```
C:\Windows\my.ini
C:\Windows\my.cnf
C:\my.ini
C:\my.cnf
C:\xampp\mysql\my.ini   ← XAMPP-Standardpfad
```

Befehl zur Überprüfung (CMD als Administrator):
```
mysqld --verbose --help | more
```

Typische Ausgabe der ersten Zeilen:
```
mysqld  Ver 10.4.28-MariaDB for Win64 on AMD64 (mariadb.org binary distribution)
Copyright (c) 2000, 2018, Oracle, MariaDB Corporation Ab and others.

Starts the MariaDB database server.

Usage: mysqld [OPTIONS]

Default options are read from the following files in the given order:
C:\Windows\my.ini C:\Windows\my.cnf C:\my.ini C:\my.cnf
C:\xampp\mysql\my.ini C:\xampp\mysql\my.cnf
...
```

### Abschnitte in der my.ini

| Abschnitt | Gilt für |
|-----------|---------|
| `[mysqld]` | MariaDB-Server |
| `[client]` | Alle Clients |
| `[mysql]` | mysql.exe CLI-Client |
| `[mysqldump]` | mysqldump-Tool |

Wichtige Einstellungen im `[mysqld]`-Abschnitt:
```ini
[mysqld]
port        = 3306
basedir     = "C:/xampp/mysql"
datadir     = "C:/xampp/mysql/data"
character-set-server = utf8mb4
collation-server     = utf8mb4_unicode_ci
```

---

## 2. Kollation / Zeichenkodierung

SQL-Script: [Tag2/kollation.sql](Tag2/kollation.sql)

### Zeichenkodierungen im Überblick

| Kodierung | Bits | Zeichen | Verwendung |
|-----------|------|---------|------------|
| ASCII | 7 Bit | 128 | Nur Englisch (veraltet) |
| ISO-8859-1 (Latin1) | 8 Bit | 256 | Westeuropäisch mit Umlauten |
| UTF-8 | 8–32 Bit variabel | alle Unicode | Web-Standard (98.5% aller Websites) |
| UTF-16 / UTF-32 | 16 / 32 Bit fest | alle Unicode | Intern in Betriebssystemen |

### Kollation (Sortierregel)

Eine Kollation definiert, wie Zeichen in einer Spalte sortiert und verglichen werden – z.B. ob Gross-/Kleinschreibung unterschieden wird.

**Aufbau des Namens:** `<Zeichensatz>_<Sortierregeln>_<ci|cs>`
- `ci` = case insensitive (Gross-/Kleinschreibung ignoriert)
- `cs` = case sensitive

**Empfehlungen:**

| Kollation | Empfohlen für |
|-----------|--------------|
| `utf8mb4_unicode_ci` | Allgemein (mehrsprachig) |
| `utf8mb4_german2_ci` | Deutsch (Telefonbuch-Sortierung: ä = ae) |
| `utf8mb4_general_ci` | Schnell, aber weniger präzise |

### Kollation einer Spalte ändern (SQL)

```sql
-- Kollation einer Spalte nachträglich ändern
ALTER TABLE tbl_mitarbeiter
  MODIFY Name VARCHAR(50)
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_german2_ci;
```

---

## 3. SQL-Befehle auffrischen

| Befehl | Gruppe | Beschreibung |
|--------|--------|-------------|
| `SELECT` | DQL | Daten abfragen |
| `SHOW` | DQL | Datenbank-Objekte anzeigen |
| `INSERT` | DML | Datensatz einfügen |
| `UPDATE` | DML | Datensatz ändern |
| `DELETE` | DML | Datensatz löschen |
| `CREATE` | DDL | Objekt (DB, Tabelle, Index) erstellen |
| `ALTER` | DDL | Objekt ändern |
| `DROP` | DDL | Objekt löschen |
| `TRUNCATE` | DDL | Alle Zeilen einer Tabelle löschen (schnell) |
| `GRANT` | DCL | Rechte vergeben |
| `REVOKE` | DCL | Rechte entziehen |
| `COMMIT` | TCL | Transaktion bestätigen |
| `ROLLBACK` | TCL | Transaktion rückgängig machen |

**DDL** – Data Definition Language  
**DML** – Data Manipulation Language  
**DQL** – Data Query Language  
**DCL** – Data Control Language  
**TCL** – Transaction Control Language

---

## 4. Datenbank „Firma" erstellen

SQL-Scripts: [Tag2/Firma_DDL.sql](Tag2/Firma_DDL.sql)

### 4.1 Datenbank und Tabellen erstellen

```sql
CREATE DATABASE IF NOT EXISTS firma
  DEFAULT CHARACTER SET utf8mb4
  DEFAULT COLLATE utf8mb4_unicode_ci;

USE firma;
```

Vollständige DDL inkl. aller Tabellen: siehe [Tag2/Firma_DDL.sql](Tag2/Firma_DDL.sql)

### 4.2 CSV importieren (Abteilungen.txt)

```sql
-- Datei: Tag2/Abteilungen.txt
LOAD DATA LOCAL INFILE 'Abteilungen.txt'
INTO TABLE tbl_abteilung
FIELDS TERMINATED BY ';'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES
(Abtlg_ID, Bezeichnung);
```

Oder via phpMyAdmin: Import → CSV → Trennzeichen `;` → Zeichensatz `utf-8`

### 4.3 SQL importieren (tbl_plz_ort.sql, tbl_mitarbeiter.sql)

```bash
# Über Kommandozeile (mysql.exe)
mysql -u root -p firma < Tag2/tbl_plz_ort.sql
mysql -u root -p firma < Tag2/tbl_mitarbeiter.sql
```

### 4.4 Index löschen & Tabellentyp ändern (MyISAM → InnoDB)

```sql
-- Vorhandene Indizes anzeigen
SHOW INDEX FROM tbl_mitarbeiter;

-- Index löschen
ALTER TABLE tbl_mitarbeiter DROP INDEX idx_name;

-- Tabellentyp von MyISAM auf InnoDB ändern
ALTER TABLE tbl_mitarbeiter ENGINE = InnoDB;
ALTER TABLE tbl_abteilung   ENGINE = InnoDB;
ALTER TABLE tbl_plz_ort     ENGINE = InnoDB;

-- Prüfen
SHOW TABLE STATUS FROM firma;
```

### 4.5 Eigene Tabelle erstellen

```sql
-- Projekt-Tabelle als eigene Erweiterung
CREATE TABLE tbl_projekt (
    Proj_ID       INT            NOT NULL AUTO_INCREMENT,
    Bezeichnung   VARCHAR(100)   NOT NULL,
    Start_Datum   DATE,
    End_Datum     DATE,
    Budget        DECIMAL(12,2),
    PRIMARY KEY (Proj_ID)
) ENGINE = InnoDB;

-- Zuweisung Mitarbeiter ↔ Projekt
CREATE TABLE tbl_ma_proj (
    MA_ID    INT         NOT NULL,
    Proj_ID  INT         NOT NULL,
    Funktion VARCHAR(50),
    PRIMARY KEY (MA_ID, Proj_ID),
    FOREIGN KEY (MA_ID)   REFERENCES tbl_mitarbeiter(MA_ID),
    FOREIGN KEY (Proj_ID) REFERENCES tbl_projekt(Proj_ID)
) ENGINE = InnoDB;
```

Beispieldaten einfügen:
```sql
INSERT INTO tbl_projekt VALUES
(1, 'ERP-Migration',   '2024-01-01', '2024-06-30', 150000.00),
(2, 'Website Relaunch','2024-03-01', '2024-04-30',  20000.00);
```

### 4.6 Dump erstellen mit mysqldump

```bash
# Vollständiger Dump (Struktur + Daten)
mysqldump -u root -p firma > Tag2/firma_dump.sql

# Nur Struktur (kein INSERT)
mysqldump -u root -p --no-data firma > Tag2/firma_schema.sql

# Einzelne Tabelle
mysqldump -u root -p firma tbl_mitarbeiter > Tag2/firma_mitarbeiter.sql
```

Dump wieder einspielen:
```bash
mysql -u root -p firma < Tag2/firma_dump.sql
```
