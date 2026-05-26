# Tag 6 – Server-Administration im Produktivbetrieb

Themen: Konfiguration, Logging, Backup & Recovery, Optimierung

[← Zurück zur Übersicht](../README.md)

---

## 1. Konfiguration

### Drei Wege zur Konfiguration

| Methode | Beschreibung | Vorrang |
|---------|-------------|--------|
| **A) Konfigurationsdatei** (`my.ini` / `my.cnf`) | Dauerhafte Einstellungen für Server und Clients | Mittel |
| **B) Kommandozeilen-Parameter** | Beim Start von `mysqld` oder `mysql` angegeben | Höchster |
| **C) Systemvariablen** (`SET GLOBAL ...`) | Zur Laufzeit änderbar, ohne Neustart | Mittel (Session) |

> Werte auf der Kommandozeile haben **Vorrang** vor der Konfigurationsdatei. Es gilt immer der zuletzt gelesene Wert.

### Aufbau my.ini

```ini
[mysqld]
language = german
log-error = C:/log/mysql_error.log
log-bin   = mysql-bin
slow_query_log = 1
long_query_time = 2

[mysql]
user   = meier
silent
```

### Konfiguration validieren (vor Neustart)

```cmd
mysqld.exe --validate-config
mysqld.exe --defaults-file=C:\path\to\my.ini --validate-config
```

> Ein Tippfehler in `my.ini` (z.B. `-` statt `_`) verhindert den Serverstart!

### Systemvariablen anzeigen

```sql
-- Alle Log-Variablen
SHOW VARIABLES LIKE '%log%';

-- Einzelne Variable
SHOW VARIABLES LIKE 'slow_query_log';

-- Zur Laufzeit ändern (ohne Neustart)
SET GLOBAL slow_query_log = 1;
SET GLOBAL long_query_time = 2;
```

---

## 2. Logging

### Log-Typen im Überblick

| Log-Typ | Datei | Zweck | Standard |
|---------|-------|-------|----------|
| **Error Log** | `mysql_error.log` | Start/Stop, Fehler | Immer aktiv |
| **Binary Log** | `mysql-bin.000001` | Alle Datenänderungen – für Recovery | Deaktiviert |
| **General Query Log** | `<host>.log` | Alle Befehle aller Verbindungen | Deaktiviert |
| **Slow Query Log** | `<host>-slow.log` | Abfragen über Zeitlimit | Deaktiviert |
| **Transaction Log** | `ib_logfile0/1` | InnoDB Crash-Recovery | Automatisch |

> **Standardmässig ist nur das Error Log aktiv** – alle anderen verlangsamen den Server und verbrauchen Speicher.

### Binary Log aktivieren

```ini
[mysqld]
log-bin = mysql-bin
max_binlog_size = 100M
```

Nach Neustart entsteht `mysql-bin.000001` und eine Indexdatei `mysql-bin.index`.

Neue Log-Datei erzwingen:
```sql
FLUSH LOGS;
```

Binary Log lesen:
```cmd
C:\xampp\mysql\bin\mysqlbinlog -u root -p C:\xampp\mysql\data\mysql-bin.000001
```

### Slow Query Log aktivieren

```ini
[mysqld]
slow_query_log = 1
long_query_time = 2        -- Abfragen über 2 Sekunden werden geloggt
```

### General Query Log (nur für Debugging)

```sql
SET GLOBAL general_log = 1;
SET GLOBAL general_log = 0;   -- wieder ausschalten
```

---

## 3. Backup & Recovery

### Backup mit mysqldump

```cmd
rem Einfaches Backup
mysqldump -u root -p firma > backup.sql

rem Mit Passwort direkt (kein Prompt)
mysqldump --user=root --password=pwd --opt firma > backup.sql

rem Mit Table-Lock (Integrität)
mysqldump --lock-tables firma > backup.sql

rem Alle Datenbanken
mysqldump --all-databases --opt -u root -p > all_backup.sql

rem Einzelne Tabelle
mysqldump --opt hotel person > person_backup.sql

rem Mit sauberem Log-Schnittpunkt (wichtig vor Recovery!)
mysqldump --flush-logs --lock-all-tables -u root -p hotel > hotel_backup.sql
```

### Wichtige mysqldump-Optionen

| Option | Wirkung |
|--------|---------|
| `--opt` | Optimiertes Skript (umfasst mehrere Optionen) |
| `--quick` | Kein RAM-Zwischenspeicher – für grosse Tabellen |
| `--add-drop-table` | `DROP TABLE` vor jedem `CREATE TABLE` |
| `--add-locks` | `LOCK`/`UNLOCK` um INSERTs für schnelleres Einlesen |
| `--extended-insert` | Wenige INSERT mit mehreren Datensätzen |
| `--lock-tables` | READ LOCK während Backup |
| `--lock-all-tables` | Alle DBs sperren |
| `--flush-logs` | Logs vor Dump leeren (sauberer Schnittpunkt mit Binary Log) |
| `--flush-privileges` | Nötig beim Sichern der `mysql`-Datenbank |
| `--compact` | Weniger Ausgabetext |

### Restore

```cmd
rem Letztes Backup einspielen
mysql -u root -p firma < backup.sql

rem Binary Logs seit dem Backup anwenden (älteste zuerst!)
mysqlbinlog mysql-bin.000002 | mysql -u root -p
mysqlbinlog mysql-bin.000003 | mysql -u root -p
```

### Kompletter Recovery-Ablauf nach Totalverlust

```
1. Backup einspielen:     mysql -u root -p firma < backup.sql
2. Binary Logs anwenden:  mysqlbinlog mysql-bin.000002 | mysql -u root -p
                          mysqlbinlog mysql-bin.000003 | mysql -u root -p
   → Nur Logs NACH dem Backup-Zeitpunkt verwenden!
3. Daten prüfen:          SELECT COUNT(*) FROM tabelle;
```

---

## 4. Optimierung

### Tabellenspeicherplatz optimieren (MyISAM)

```sql
-- Nicht genutzten Speicher entfernen, Daten defragmentieren
OPTIMIZE TABLE person;
```

### Indizes

```sql
-- Index erstellen
CREATE INDEX idx_name ON tbl_mitarbeiter (nachname);

-- Index löschen
DROP INDEX idx_name ON tbl_mitarbeiter;

-- Indizes einer Tabelle anzeigen
SHOW INDEX FROM tbl_mitarbeiter;
```

**Wann Index sinnvoll:**
- Primär- und Fremdschlüssel (automatisch)
- Attribute, die häufig in `WHERE`-Bedingungen stehen
- Attribute, die häufig sortiert werden (`ORDER BY`)

**Wann Index nicht hilft:**
- `NOT` und `<>` Operatoren
- `LIKE` mit `%` am Anfang (`LIKE '%name'`)
- Abfragen mit Funktionen auf indizierte Spalten (`WHERE YEAR(datum) = 2024`)

### Abfragen analysieren mit EXPLAIN

```sql
EXPLAIN SELECT COUNT(*)
FROM buchung
JOIN person ON buchung.PersID = person.PersID;
```

**Wichtige EXPLAIN-Spalten:**

| Spalte | Bedeutung |
|--------|-----------|
| `table` | Reihenfolge der Tabellenzugriffe |
| `type` | Zugriffstyp (`ALL` = voller Scan, `ref` = Index genutzt) |
| `key` | Verwendeter Index (`NULL` = kein Index) |
| `rows` | Geschätzte Anzahl zu prüfender Zeilen |

> Produkt aller `rows`-Werte sollte möglichst klein sein.

### Server-Tuning (Speicherparameter)

```ini
[mysqld]
key_buffer_size   = 64M    -- Speicher für Indizes (Default: 8M)
table_cache       = 256    -- Max. geöffnete Tabellen (Default: 64)
sort_buffer_size  = 4M     -- Sortier-Buffer (Default: 2M)
read_buffer_size  = 256K   -- Sequentielles Lesen
```

### Query Cache

```ini
[mysqld]
query_cache_size  = 32M    -- 32 MB für Cache reservieren
query_cache_type  = 1      -- 0=Off, 1=On, 2=Demand
query_cache_limit = 50K    -- Max. Grösse eines einzelnen Resultats
```

```sql
-- Cache für aktuelle Verbindung deaktivieren
SET query_cache_type = 0;

-- Cache-Status anzeigen
SHOW STATUS LIKE 'Qcache%';

-- Cache leeren
RESET QUERY CACHE;
```

---

## 5. Checkpoint – Server konfigurieren

### 1. Auf welche Arten können Konfigurationsparameter definiert werden?

- [ ] mit einem INSERT-Befehl
- [x] durch Eintrag auf der Kommandozeile
- [x] durch Eintrag in einer Konfigurationsdatei
- [ ] durch Eintrag in einem Logfile

> Konfiguration erfolgt entweder **dauerhaft** via `my.ini`/`my.cnf` oder **einmalig** als Parameter beim Programmstart (`mysqld --parameter`). Ein dritter Weg ist `SET GLOBAL` zur Laufzeit (nur im RAM, geht nach Neustart verloren). In Logfiles oder via INSERT werden keine Konfigurationsparameter gesetzt.

---

### 2. Welcher Konfigurationsparameter legt fest, wo die Log-Dateien abgelegt werden?

- [ ] basedir
- [x] datadir
- [ ] log-bin
- [ ] logdir

> `datadir` ist das Datenverzeichnis des Servers – hier werden standardmässig alle Log-Dateien abgelegt. `basedir` zeigt auf das MySQL-Installationsverzeichnis. `log-bin` definiert den **Dateinamen** des Binary Logs, nicht das Verzeichnis. `logdir` ist kein gültiger MySQL-Parameter.

---

### 3. Mit welchem Eintrag beginnen die Server-Parameter in der Konfigurationsdatei?

- [ ] [mysql]
- [ ] [WinMySQLadmin]
- [ ] [mysqldump]
- [x] [mysqld]

> `[mysqld]` leitet den Abschnitt für den **Server-Prozess** ein. `[mysql]` gilt für den interaktiven Client, `[mysqldump]` für das Backup-Tool. `[WinMySQLadmin]` ist ein veraltetes Tool aus frühen XAMPP-Versionen.

---

### 4. Wozu kann der DB-Client `mysqlshow` verwendet werden?

- [ ] Backup erstellen
- [x] DB-Schema anzeigen
- [x] Verbindung zum DB-Server testen
- [ ] Inhalt einer Protokolldatei anschauen

> `mysqlshow` zeigt Datenbanken, Tabellen und Spaltenstruktur an – es ist ein schnelles Schema-Inspection-Tool. Da es eine Verbindung aufbaut, testet es implizit auch die Erreichbarkeit des Servers. Backups erstellt `mysqldump`, Log-Dateien werden mit `TYPE` (Windows) oder `cat` (Linux) angezeigt.

---

### 5. Mit welchem Log-File bestimmen Sie den letzten Start des MySQL-Servers?

- [x] Error Log
- [ ] Update Log
- [ ] Query Log
- [ ] Transaction Log

> Das **Error Log** protokolliert jeden Start und Shutdown des Servers mit Datum und Uhrzeit. Das Update/Binary Log protokolliert Datenänderungen, das Query Log alle Befehle, das Transaction Log (InnoDB) verwaltet Crash-Recovery intern.

---

### 6. Welcher Eintrag im Konfigurationsfile schaltet die Protokollierung aller User-Logins ein?

- [ ] log-bin
- [ ] log-slow-queries
- [x] log
- [ ] log-error=C:/log/err.log

> Der Parameter `log` (in neueren Versionen `general_log = 1`) aktiviert das **General Query Log**, das jeden Verbindungsaufbau und jeden SQL-Befehl aufzeichnet – also auch alle Logins. `log-bin` ist das Binary Log, `log-slow-queries` das Slow Query Log, `log-error` definiert nur den Pfad des Error Logs.

---

### 7. Wie restaurieren Sie nach einem Server-Ausfall eine DB vollständig?

- [x] Einlesen des letzten Backup
- [ ] Verwenden der Option `--opt` beim Erstellen des Backup
- [ ] Einlesen des Query-Log
- [x] Einlesen aller Update-Logs in der richtigen Reihenfolge (mit Hilfe von `mysqlbinlog`)

> Vollständige Wiederherstellung = **Backup + Binary Logs**. Zuerst das letzte vollständige Backup einspielen, dann alle Binary Log-Dateien, die seit dem Backup entstanden sind (älteste zuerst). `--opt` ist eine Backup-Erstellungsoption, das Query-Log ist für Recovery nicht geeignet.

---

### 8. Wie erreichen Sie, dass Änderungen in der Konfigurationsdatei wirksam werden?

Änderungen in `my.ini` / `my.cnf` werden erst nach einem **Neustart des DB-Servers** wirksam:

```cmd
net stop mysql
net start mysql
```

**Ausnahme:** Systemvariablen, die zur Laufzeit per `SET GLOBAL` geändert werden, wirken sofort – gehen aber nach dem Neustart verloren, sofern sie nicht auch in `my.ini` eingetragen werden.

> Vor dem Neustart die Konfiguration prüfen: `mysqld.exe --validate-config`

---

### 9. Durch welche Daten wird der von einer DB benötigte Speicherplatz bestimmt?

| Datenart | Beschreibung |
|----------|-------------|
| **Nutzdaten** | Eigentlicher Tabelleninhalt (`.MYD` / InnoDB Tablespace) |
| **Indizes** | Indextabellen (`.MYI` bei MyISAM) |
| **Systemdaten** | Tabellenbeschreibungen (`.FRM`), Systemkatalog, User- und Rechteverwaltung |
| **Log-Dateien** | Error Log, Binary Log, Slow Query Log – wachsen im Betrieb |
| **Temporäre Dateien** | Für `ORDER BY`, `GROUP BY`, komplexe JOINs |

> Genaue Abschätzung schwierig wegen `VARCHAR`-Spalten variabler Länge, wachsender Log-Dateien und Datenträgerfragmentierung.

---

### 10. Wozu wird das Logging (Protokollierung) verwendet?

| Zweck | Log-Typ |
|-------|---------|
| **Monitoring** | Error Log – Start, Shutdown, Fehler |
| **Datenwiederherstellung** | Binary Log – Basis für Recovery zwischen Backups |
| **Sicherheit** | General Query Log – wer hat wann was verändert? |
| **Optimierung** | Slow Query Log – Flaschenhälse identifizieren |
| **Replikation** | Binary Log – Master sendet Log an Slave-Server |
| **Transaktionen** | Transaction Log – InnoDB Crash-Recovery |

---

### 11. In welcher Log-Datei finden Sie den Anwender, der bestimmte Daten löschte?

Im **General Query Log** (`<host>.log`). Es zeichnet jeden Verbindungsaufbau und jeden SQL-Befehl inklusive **Benutzer, Zeitstempel und Befehlstext** auf:

```
2024-01-15 14:23:11 42 Connect root@localhost on hotel
2024-01-15 14:23:15 42 Query DELETE FROM benutzer WHERE id = 5
```

> Das Binary Log enthält auch die DELETE-Befehle, aber ohne direkten Benutzernamen im lesbaren Format. Das General Query Log ist der eindeutige Nachweis.

---

### 12. Welche Informationen finden Sie im Slow Query Log?

- **Zeitstempel** der Abfrage
- **Ausführungszeit** (`Query_time`)
- **Anzahl der geprüften Zeilen** (`Rows_examined`)
- **Vollständiger SQL-Text** der Abfrage
- **Benutzername und Datenbankname**

Beispiel-Eintrag:
```
# Time: 2024-01-15T14:25:03
# User@Host: root[root] @ localhost []
# Query_time: 4.523  Lock_time: 0.001  Rows_sent: 1  Rows_examined: 850000
SELECT COUNT(*) FROM buchung WHERE datum LIKE '%2023%';
```

---

### 13. Geben Sie für jede Protokolldatei an, wie Sie deren Inhalt kontrollieren.

| Log-Typ | Datei | Lesen |
|---------|-------|-------|
| **Error Log** | `mysql_error.log` | `TYPE C:\xampp\mysql\data\mysql_error.log` (Textdatei) |
| **Binary Log** | `mysql-bin.000001` | `mysqlbinlog mysql-bin.000001` (Binärdatei!) |
| **General Query Log** | `<host>.log` | `TYPE <host>.log` (Textdatei) |
| **Slow Query Log** | `<host>-slow.log` | `TYPE <host>-slow.log` (Textdatei) |

> Binary Logs sind binär codiert – nur mit `mysqlbinlog.exe` lesbar.

---

### 14. Wie beeinflusst der Parameter `--opt` beim Erstellen eines Backup das Tabellenlocking?

`--opt` enthält die Option `--lock-tables`, die während des Dumps ein **READ LOCK** auf alle Tabellen der gesicherten Datenbank setzt.

**Auswirkungen:**
- Andere Clients können die Tabellen weiterhin **lesen**
- Andere Clients können während des Dumps **nicht schreiben**
- Garantiert ein **konsistentes Backup** (kein inkonsistenter Zwischenzustand)
- Das Lock wird nach Abschluss des Dumps automatisch aufgehoben

---

### 15. Beschreiben Sie das Vorgehen, um Daten von MySQL nach Oracle zu migrieren.

1. **Export aus MySQL** als SQL oder CSV:
   ```cmd
   mysqldump --no-create-info --tab=C:\export firma tbl_kunden
   rem oder
   SELECT * FROM tbl_kunden INTO OUTFILE 'kunden.csv' FIELDS TERMINATED BY ';';
   ```
2. **Schema anpassen**: Oracle verwendet andere Datentypen (`INT` → `NUMBER`, `AUTO_INCREMENT` → `SEQUENCE`, `VARCHAR` → `VARCHAR2`)
3. **Schema in Oracle erstellen** mit angepasstem DDL-Script
4. **Daten importieren** in Oracle via SQL*Loader oder Oracle Data Pump

Alternativ: **ETL-Tool** (z.B. Pentaho, Talend) oder **ODBC-Verbindung** für direkte Migration.

---

### 16. Beschreiben Sie eine praktische Anwendung für den READ-Lock.

**Szenario: Konsistentes Backup bei laufendem Betrieb**

```sql
-- Client A (Backup-Prozess)
LOCK TABLES bestellungen READ, kunden READ;
-- Alle anderen Clients können weiterhin lesen, aber nicht schreiben
-- → konsistenter Snapshot der Daten

-- Backup erstellen...
-- mysqldump oder SELECT INTO OUTFILE

UNLOCK TABLES;   -- Freigabe nach Backup
```

**Weitere Anwendungen:**
- **Datenanalyse**: Report-Abfragen sollen keine veränderten Zwischenstände sehen
- **Datenexport**: Während des Exports sollen keine Änderungen einfliessen

---

## 6. Checkpoint – Optimierung

### 1. Welche Möglichkeiten können die Geschwindigkeit eines DB-Servers verbessern?

- [ ] Indexe möglichst vermeiden
- [x] Serverparameter einstellen
- [ ] Transaktionen verwenden
- [x] Locks verwenden

> Indizes zu vermeiden ist kontraproduktiv – sie beschleunigen Lesezugriffe massgeblich. Serverparameter (`key_buffer_size`, `sort_buffer`, `query_cache_size`) direkt an die Hardware anpassen. Tabel-Locks vor Massen-INSERTs beschleunigen das Laden. Transaktionen erhöhen die Sicherheit, verbessern aber nicht primär die Geschwindigkeit.

---

### 2. Wie werden Daten schneller in eine DB-Tabelle geladen?

- [ ] durch Komprimieren der Daten vor der Übertragung
- [x] durch Verwenden des Parameters `--opt` beim Erstellen des Backup-Skripts
- [x] durch Importieren der Daten aus einer Textdatei
- [ ] durch Verwenden von vielen INSERT-Befehlen

> `--opt` erzeugt `extended-insert` (viele Zeilen pro INSERT) und fügt `LOCK`/`UNLOCK`-Befehle ein → schnelleres Einlesen. **Am schnellsten** ist `LOAD DATA INFILE` aus einer Textdatei – viel schneller als viele einzelne INSERTs.

---

### 3. Was trifft auf den Befehl `OPTIMIZE TABLE` zu?

- [x] entfernt nicht genutzten Speicherplatz aus MyISAM-Tabellendateien
- [ ] ist auf MyISAM- und InnoDB-Tabellen anwendbar
- [ ] wird angewendet bei Tabellen, die häufig abgefragt werden
- [x] defragmentiert DB-Dateien

> `OPTIMIZE TABLE` ist primär für **MyISAM** relevant. Bei InnoDB baut es die Tabelle neu auf (teuer). Angewendet wird es nach vielen **DELETE/UPDATE-Operationen** – nicht bei häufig abgefragten Tabellen.

---

### 4. Wie finden Sie langsame DB-Abfragen?

- [x] mit `EXPLAIN SELECT`
- [ ] im Query Log
- [x] im Slow Query Log
- [ ] im Error Log

> Das **Slow Query Log** listet alle Abfragen, die das konfigurierte Zeitlimit überschreiten. `EXPLAIN SELECT` analysiert dann eine spezifische Abfrage und zeigt, **warum** sie langsam ist (fehlende Indizes, ungünstige Join-Reihenfolge). Das General Query Log zeigt alle Abfragen ohne Zeitfilter.

---

### 5. Welche Aussagen betreffend DB-Optimierung sind korrekt?

- [ ] Abfragen, die LIKE enthalten, können immer optimiert werden
- [x] Indexe beschleunigen Abfragen
- [x] Indexe werden allgemein auf Schlüsselattribute gelegt
- [ ] durch Indexe werden DB-Einträge und -änderungen schneller

> `LIKE '%suchbegriff'` mit `%` am Anfang kann **nicht** mit einem Index optimiert werden. Indexe **verlangsamen** INSERT/UPDATE, da die Indextabellen aktualisiert werden müssen – das ist ein bewusst akzeptierter Nachteil.

---

### 6. Wann verwenden Sie den Befehl `EXPLAIN`?

- [ ] um Daten schneller in die DB zu laden
- [x] immer im Zusammenhang mit SELECT
- [ ] um langsame Abfragen zu finden
- [x] um zu erkennen, wie sich ein Index auf die Geschwindigkeit einer Abfrage auswirkt

> `EXPLAIN` wird **vor ein SELECT** gestellt und zeigt den Ausführungsplan. Damit prüft man, ob Indizes genutzt werden und wie viele Zeilen geprüft werden müssen. Langsame Abfragen findet man zuerst im **Slow Query Log**, dann analysiert man sie mit EXPLAIN.

---

### 7. Welches sind Gründe für die Verwendung eines Index?

- [ ] um das Eintragen von Daten in Tabellen bei Unique-Attributen zu beschleunigen
- [x] um DB-Abfragen zu beschleunigen
- [ ] um das Ändern von Daten zu verlangsamen
- [x] um einmalige Werte zu gewährleisten

> Der Hauptzweck eines Index ist die **Beschleunigung von Lesezugriffen** (SELECT, WHERE, ORDER BY, JOIN). Ein `UNIQUE`-Index gewährleistet zusätzlich **Einmaligkeit** von Werten. Das Verlangsamen von Änderungen ist ein unerwünschter Nebeneffekt, kein Ziel.

---

### 8. Nennen Sie Ziele der DB-Optimierung.

| Ziel | Massnahme |
|------|-----------|
| **Performance verbessern** | Schnellere SQL-Ausführung durch Indizes und Server-Tuning |
| **Speicherplatz einsparen** | `OPTIMIZE TABLE`, minimales Schema-Design |
| **Portabilität ermöglichen** | Standardkonformes SQL, Export als CSV/SQL-Dump |

---

### 9. Was wird optimiert, um die Geschwindigkeit eines DB-Servers zu verbessern?

| Optimierungsobjekt | Massnahmen |
|--------------------|-----------|
| **Datenbankstruktur** | Minimaler Speicherplatz, sinnvolle Indizes |
| **DB-Abfragen** | EXPLAIN verwenden, Abfragen umschreiben, Indizes ergänzen |
| **Locks** | Tabellen-Locks vor Massen-Operationen |
| **Server-Parameter** | `key_buffer_size`, `sort_buffer`, `query_cache_size` in `my.ini` |

---

### 10. Mit welchen 2 prinzipiellen Massnahmen werden DB-Abfragen beschleunigt?

1. **Indizes setzen**: Auf Attribute, die in `WHERE`, `ORDER BY` oder `JOIN`-Bedingungen häufig vorkommen
2. **Abfragen analysieren und umschreiben**: Mit `EXPLAIN` den Ausführungsplan prüfen, dann die Abfrage so formulieren, dass Indizes genutzt werden können (z.B. `LIKE 'prefix%'` statt `LIKE '%suffix'`)

---

### 11. Beschreiben Sie kurz, wie Sie den Befehl `EXPLAIN` verwenden.

`EXPLAIN` wird einem `SELECT`-Statement vorangestellt:

```sql
EXPLAIN SELECT COUNT(*)
FROM buchung
JOIN person ON buchung.PersID = person.PersID
WHERE buchung.datum > '2024-01-01';
```

**Interpretation:**
- `key = NULL` → kein Index → voller Tabellenscan → langsam
- `key = PRIMARY` → Index genutzt → schnell
- `rows` → Produkt aller Zeilen sollte möglichst klein sein
- `type = ALL` → vollständiger Scan (schlecht), `type = ref` → Index genutzt (gut)

---

### 12. Wozu wird der Befehl `OPTIMIZE TABLE` angewendet?

Nach vielen `DELETE`- und `UPDATE`-Operationen entstehen **Lücken** in der Tabellendatei (wie Löcher in einem Schweizer Käse). `OPTIMIZE TABLE` räumt diese auf:

- Entfernt **ungenutzten Speicherplatz**
- **Defragmentiert** die Datei – zusammengehörende Datensätze werden physisch zusammen gespeichert
- Verkleinert die Datei → schnellere Festplattenzugriffe

```sql
OPTIMIZE TABLE tbl_bestellungen;
```

---

### 13. Wie werden SELECT-Befehle optimiert?

1. **Slow Query Log** → langsame Abfragen identifizieren
2. **EXPLAIN** → Ausführungsplan analysieren: `key = NULL`? → Index fehlt
3. **Index erstellen**: `CREATE INDEX idx_datum ON buchung (datum);`
4. **Abfrage umformulieren**:
   - `LIKE '%wort'` → nicht optimierbar; `LIKE 'wort%'` → Index nutzbar
   - Funktionen auf Spalten vermeiden: `WHERE datum > '2024-01-01'` statt `WHERE YEAR(datum) = 2024`
   - `NOT`/`<>` durch positive Bedingungen ersetzen wo möglich

---

### 14. Wie viele DB-Tabellen können standardmässig gleichzeitig geöffnet sein?

**64 Tabellen** – definiert durch den Parameter `table_cache` (Standard: 64).

```ini
[mysqld]
table_cache = 256   -- für grössere Systeme anpassen
```

```sql
SHOW VARIABLES LIKE 'table_cache';
```

---

### 15. Wie schalten Sie den Query Cache ein bzw. aus?

**In `my.ini`** (dauerhaft):
```ini
[mysqld]
query_cache_type = 1    -- 0=Off, 1=On, 2=Demand
query_cache_size = 32M
```

**Zur Laufzeit** (bis zum nächsten Neustart):
```sql
SET GLOBAL query_cache_type = 1;   -- einschalten
SET GLOBAL query_cache_type = 0;   -- ausschalten

-- Cache leeren
RESET QUERY CACHE;

-- Status prüfen
SHOW STATUS LIKE 'Qcache%';
```

---

### 16. CLI-Tools im MySQL/MariaDB bin-Verzeichnis

| Tool | Funktion |
|------|---------|
| `mysql.exe` | Interaktiver SQL-Client – SQL-Befehle eingeben, Skripte ausführen |
| `mysqladmin.exe` | Server-Administration: Status prüfen, Passwörter setzen, Server stoppen (`ping`, `shutdown`, `status`) |
| `mysqlbinlog.exe` | Binary Log-Dateien lesbar anzeigen – für Recovery und Audit |
| `mysqlcheck.exe` | Tabellen prüfen, reparieren, analysieren und optimieren (`--check`, `--repair`, `--optimize`) |
| `mysqld.exe` | Der DB-Server-Prozess selbst – wird als Dienst gestartet |
| `mysqldump.exe` | Datenbank-Backup als SQL-Dump – Struktur und/oder Daten exportieren |
| `mysqlimport.exe` | Daten aus Textdateien importieren – entspricht `LOAD DATA INFILE` auf der Kommandozeile |
| `mysqlshow.exe` | Schema anzeigen: Datenbanken, Tabellen, Spalten auflisten |
| `mysqlslap.exe` | Last- und Performance-Test – simuliert mehrere gleichzeitige Clients |
| `mysql_install_db.exe` | Initiale Systemdatenbanken anlegen – einmalig bei der Installation |
| `mysql_plugin.exe` | Server-Plugins aktivieren oder deaktivieren |
| `mariabackup.exe` | Hot-Backup für InnoDB-Tabellen ohne Server-Stopp (physisches Backup) |
| `myrocks_hotbackup` | Hot-Backup für MyRocks-Engine (RocksDB-basiert) |

