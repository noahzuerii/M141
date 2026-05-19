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

---

## 5. Checkpoint-Fragen: DB-Server und XAMPP

### Wie kann der MySQL-Server gestartet werden?

- [ ] Start von mysql.exe im CMD-Fenster
- [x] Start von mysqld.exe im CMD-Fenster
- [x] über MySQL-Workbench
- [ ] Eingabe von localhost als URL im Browser
- [x] NET START mysql (im CMD-Fenster)
- [x] mit dem Dienstmanager von Windows

> `mysql.exe` ist der Client, nicht der Server. `localhost` im Browser öffnet phpMyAdmin, startet aber nicht mysqld.

---

### Welche Informationen erhalten Sie beim Befehl `status;` im MySQL-Konsolenfenster?

- [x] Version des Konsolenprogramms
- [x] Betriebszeit des Servers
- [x] Version des Servers
- [ ] Betriebszeit des DB-Klienten mysql

Beispielausgabe von `status;`:
```
mysql  Ver 15.1 Distrib 10.4.28-MariaDB, for Win64 (AMD64)

Connection id:          8
Current database:
Current user:           root@localhost
SSL:                    Not in use
Using delimiter:        ;
Server version:         10.4.28-MariaDB mariadb.org binary distribution
Protocol version:       10
Connection:             localhost via TCP/IP
Server characterset:    utf8mb4
Db     characterset:    utf8mb4
Client characterset:    utf8mb4
Conn.  characterset:    utf8mb4
TCP port:               3306
Uptime:                 1 hour 23 min 45 sec
```

---

### Welche Daten befinden sich im Verzeichnis `datadir` (z. B. `C:\xampp\mysql\data`)?

- [x] Protokoll-Dateien (Log-Files)
- [x] Fehlerprotokolle
- [ ] die ausführbaren MySQL-Programme, z.B. mysql.exe
- [x] Datenbanken

> Die ausführbaren Programme liegen im `bin`-Verzeichnis (z.B. `C:\xampp\mysql\bin`).

---

### Wie prüfen Sie, ob der MySQL-Server läuft?

- [x] mit dem Dienst-Manager von Windows
- [ ] mit dem GUI-Tool Administrator
- [x] durch Eingabe des Befehls `status` im CMD-Fenster (nach Login mit mysql.exe)
- [x] mit dem Task-Manager von Windows (Prozess `mysqld.exe`)

---

### Wie testen Sie die Installation des DB-Servers?

1. Prüfen ob `mysqld.exe` im Task-Manager sichtbar ist
2. Mit dem mysql-Client verbinden: `mysql -u root -p`
3. Befehl `SHOW DATABASES;` ausführen → gibt Systemdatenbanken zurück
4. phpMyAdmin aufrufen: `http://localhost/phpmyadmin`
5. In MySQL Workbench eine neue Verbindung zu `localhost:3306` herstellen

---

### Wie überprüfen Sie die Laufzeit des DB-Servers?

```sql
-- Option 1: im mysql-Client
status;
-- → zeigt "Uptime: X hours Y min Z sec"

-- Option 2: per SQL
SHOW STATUS LIKE 'Uptime';
-- → gibt Sekunden zurück

-- Option 3: Dienst-Manager
-- Spalte "Startzeit" beim MySQL-Dienst ablesen
```

---

### Wozu verwenden Sie das Programm `mysql.exe`? Wie starten Sie es?

`mysql.exe` ist der interaktive Kommandozeilen-**Client** für MariaDB/MySQL. Damit können Sie:
- SQL-Befehle direkt eingeben
- Skript-Dateien ausführen (`mysql -u root -p < script.sql`)
- Datenbanken verwalten

**Starten:**
```cmd
mysql -u root -p
```
Optionen:
```
-u root        Benutzername
-p             Passwort abfragen
-h localhost   Host (Standard: localhost)
-P 3306        Port (Standard: 3306)
-D firma       Direkt eine Datenbank öffnen
```

---

### 3 Informationen aus `status;` mit Bedeutung

| Information | Beispielwert | Bedeutung |
|-------------|-------------|-----------|
| `Server version` | `10.4.28-MariaDB` | Installierte MariaDB-Version |
| `Uptime` | `1 hour 23 min` | Wie lange der Server bereits läuft (seit letztem Start) |
| `Current user` | `root@localhost` | Angemeldeter Benutzer und Verbindungshost |

---

### 2 wichtige Verzeichnisse der MySQL-Installation

| Verzeichnis | Inhalt |
|-------------|--------|
| `C:\xampp\mysql\bin` | Ausführbare Programme: `mysql.exe`, `mysqld.exe`, `mysqldump.exe`, usw. |
| `C:\xampp\mysql\data` | Datenbankdaten, Log-Dateien, Fehlerprotokoll (`<hostname>.err`) |

---

### Inhalt der `my.ini`-Datei

Die `my.ini` ist die zentrale Konfigurationsdatei des MySQL/MariaDB-Servers. Sie enthält:

- **Servereinstellungen** (`[mysqld]`): Port, Verzeichnisse, Zeichensatz, Puffergrössen
- **Client-Einstellungen** (`[client]`/`[mysql]`): Standardverbindungsparameter
- **Tool-Einstellungen** (`[mysqldump]`): Optionen für mysqldump

Wichtigste Parameter:
```ini
[mysqld]
port              = 3306
basedir           = "C:/xampp/mysql"
datadir           = "C:/xampp/mysql/data"
character-set-server  = utf8mb4
collation-server      = utf8mb4_unicode_ci
innodb_buffer_pool_size = 16M
```

---

## 6. Checkpoint-Fragen: Codierung und Kollation

### Welche Aussagen treffen zur Codierung zu?

- [ ] Ein Datenbankserver erkennt die Codierung einer Datei automatisch
- [x] Codierung ist eine Vereinbarung zwischen dem Nutzer und dem System.
- [x] Die Codierung legt fest, welche binäre Bitkombination zu welchem Zeichen gehört.
- [ ] ANSI- und ASCII-Codierung ist dasselbe
- [ ] Der Unicode-Zeichensatz hat 32 Bit Codelänge
- [x] UTF bedeutet Unicode Transformation Format
- [ ] UTF-8 hat nur 8 Bit lange Zeichen aus dem Unicode-Zeichensatz

> **ANSI ≠ ASCII**: ANSI (z.B. ISO-8859-1) ist eine Erweiterung von ASCII auf 8 Bit.  
> **Unicode-Codelänge**: Unicode definiert Codepunkte (bis U+10FFFF), die Codelänge hängt vom Encoding ab (UTF-8: 1–4 Byte).  
> **UTF-8**: Variabel lang – ASCII-Zeichen brauchen 1 Byte, andere bis zu 4 Byte.

---

### Welche Aussagen treffen zur Kollation zu?

- [ ] `utf8_general_cs` ist die Standard-Einstellung bei MySQL.
- [x] In der DIN-Normierung zur deutschen Kollation werden zwei Varianten zur Umlauthandhabung angeboten.
- [ ] Die Endung `_ci` gibt an, dass die Sortierung die Gross-/Kleinschreibweise **unterscheidet**.
- [x] Seit MySQL 5.5.3 sollte `utf8mb4` anstelle von `utf8` verwendet werden.
- [x] In der Konfig-Datei (my.ini) kann die UTF8-Codierung als Standard angegeben werden.
- [ ] Eine Kollationseinstellung gilt für die ganze Tabelle (Entität).
- [x] „Binärsortierung" ist die Sortierung anhand des binären Codes der verglichenen Zeichen.

> **`_ci`** = case **in**sensitive (ignoriert Gross-/Kleinschreibung) – nicht das Gegenteil.  
> **Kollation** kann pro Spalte unterschiedlich sein – sie gilt nicht zwingend für die ganze Tabelle.  
> **Standard**: MariaDB/MySQL verwendet `utf8mb4_general_ci` als Standard, nicht `utf8_general_cs`.

---

### Was haben Sie bei der DB Kollation beobachtet? (Latin1, general, ci, cs, ...)

- Mit `utf8mb4_general_ci` werden `ä`, `ae` und `Ä` als gleich betrachtet → Suchergebnisse können unerwartete Treffer liefern
- Mit `utf8mb4_unicode_ci` ist die Sortierung nach Unicode-Standard präziser, aber langsamer
- Mit `utf8mb4_german2_ci` wird `ä` wie `ae` sortiert (Telefonbuch-Reihenfolge): Müller erscheint nach Mueller
- Mit `_cs` (case sensitive) unterscheidet MySQL zwischen `'Max'` und `'max'` – `WHERE Name = 'max'` findet `'Max'` **nicht**
- `latin1` kann keine Sonderzeichen ausserhalb von Westeuropa speichern; Emojis z.B. werden abgeschnitten

---

## 7. Checkpoint-Fragen: Daten importieren

### Mit welchem Befehl kontrollieren Sie die Struktur einer Tabelle?

- [ ] `SHOW DATABASES;`
- [x] `SHOW CREATE TABLE tabellenname;`
- [x] `DESC tabellenname;`
- [x] `DESCRIBE tabellenname;`
- [ ] `SELECT * FROM tabellenname;`
- [ ] `SHOW TABLE tabellenname;`

> `DESC` und `DESCRIBE` sind identisch – beide zeigen Spalten, Datentypen, NULL-Erlaubnis und Keys.  
> `SHOW CREATE TABLE` gibt das vollständige CREATE-Statement inkl. Engine, Kollation und Constraints zurück.  
> `SELECT *` gibt Daten zurück, nicht die Struktur. `SHOW TABLE` ist kein gültiger SQL-Befehl.
