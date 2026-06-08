# Tag 2 – Konfiguration & Datenimport

Themen: my.ini, Kollation, SQL-Befehlsgruppen, Datenbank „Firma"

[← Zurück zur Übersicht](../README.md)

SQL-Dateien in diesem Ordner: [kollation.sql](kollation.sql) · [Firma_DDL.sql](Firma_DDL.sql) · [Abteilungen.txt](Abteilungen.txt)

---

## 1. Optionsdateien (my.ini)

Der MySQL-/MariaDB-Server liest seine Konfiguration beim Starten aus sogenannten Optionsdateien. Unter Windows sucht der Server an fest vorgegebenen Orten in einer definierten Reihenfolge nach diesen Dateien.

### Suchreihenfolge (Windows)
1. `C:\Windows\my.ini`
2. `C:\Windows\my.cnf`
3. `C:\my.ini`
4. `C:\my.cnf`
5. `C:\xampp\mysql\my.ini` (Standardpfad bei XAMPP-Installationen)
6. `C:\xampp\mysql\my.cnf`

> [!WARNING]
> Der Server übernimmt immer den **zuletzt gelesenen Wert** für einen Parameter. Wenn also ein Parameter sowohl in `C:\Windows\my.ini` als auch in `C:\xampp\mysql\my.ini` definiert ist, überschreibt der Wert aus der XAMPP-Konfiguration den globalen Windows-Wert.

Um zu ermitteln, welche Konfigurationsdateien MariaDB aktuell sucht und einliest, kann folgender Befehl in der Eingabeaufforderung (CMD als Administrator) ausgeführt werden:
```cmd
mysqld --verbose --help | more
```
*(Die Ausgabe listet im oberen Abschnitt die gelesenen Pfade auf.)*

---

### Abschnitte in der my.ini

Die Konfigurationsdatei ist in Sektionen unterteilt, die in eckige Klammern gesetzt sind. Jede Sektion steuert das Verhalten einer bestimmten Komponente oder eines Tools.

| Sektion | Gilt für | Typische Parameter |
|---------|----------|-------------------|
| `[mysqld]` | **Der Server-Prozess** (`mysqld.exe`). Steuert das Verhalten des Datenbank-Triebwerks. | `port`, `datadir`, `character-set-server`, `innodb_buffer_pool_size` |
| `[client]` | **Alle Client-Programme** (lokale CLI, Workbench, phpMyAdmin), die sich mit dem Server verbinden. | `port`, `socket` |
| `[mysql]` | **Das CLI-Client-Tool** `mysql.exe` (Kommandozeile). | `no-auto-rehash` (schnellerer Start), `safe-updates` (Schutz vor fehlerhaften UPDATEs) |
| `[mysqldump]` | **Das Backup-Tool** `mysqldump.exe`. | `quick`, `max_allowed_packet` |

#### Wichtige Server-Variablen im `[mysqld]`-Abschnitt:
```ini
[mysqld]
port        = 3306                   # Standard-Netzwerkport für Verbindungen
basedir     = "C:/xampp/mysql"       # Installationsverzeichnis der Binärdateien
datadir     = "C:/xampp/mysql/data"  # Speicherort der physischen Tabellendaten und Logs
character-set-server = utf8mb4       # Standard-Zeichensatz für neue Tabellen
collation-server     = utf8mb4_unicode_ci # Standard-Sortierung
```

> [!TIP]
> **Konfiguration vor Neustart validieren:**
> Ein Syntaxfehler in der `my.ini` verhindert, dass der Datenbankdienst startet. Prüfen Sie die Datei vor einem Neustart mit:
> `mysqld --validate-config`

---

## 2. Zeichensatz (Character Set) & Kollation (Collation)

SQL-Script: [kollation.sql](kollation.sql)

### Zeichensätze im Überblick

Ein **Zeichensatz (Character Set)** definiert die Zuordnung von Binärwerten (Bits) zu lesbaren Zeichen (Buchstaben, Zahlen, Symbole).

| Zeichensatz | Bit-Breite | Anzahl Zeichen | Anwendungsbereich |
|-------------|------------|----------------|-------------------|
| **ASCII** | 7 Bit | 128 | Reine englische Texte (keine Umlaute oder Akzente). Veraltet für moderne Datenhaltung. |
| **ISO-8859-1** (Latin1) | 8 Bit | 256 | Westeuropäische Sprachen (inkl. deutsche Umlaute `ä, ö, ü`). Kann keine Zeichen anderer Alphabete (z. B. Kyrillisch, Arabisch) speichern. |
| **UTF-8** | 8 bis 32 Bit (variabel) | > 1.1 Millionen | Globaler Standard. Unterstützt alle Schriftsysteme weltweit sowie Emojis. |
| **UTF-16 / UTF-32** | 16 bzw. 32 Bit (fest) | > 1.1 Millionen | Wird oft betriebssystemintern genutzt (z. B. Windows-Kernel, Java-VM). |

> [!IMPORTANT]
> **Der `utf8`-Fallstrick in MySQL/MariaDB:**
> In älteren MySQL-/MariaDB-Versionen ist der Begriff `utf8` ein Alias für `utf8mb3`. Dieser Zeichensatz nutzt maximal 3 Byte pro Zeichen und kann somit viele Emojis und seltene Schriftzeichen (die 4 Byte benötigen) nicht speichern. Verwenden Sie **immer explizit `utf8mb4`** für echte, vollständige Unicode-Unterstützung.

---

### Kollation (Collation)

Eine **Kollation** definiert die Sortierregeln und Vergleichsregeln für Zeichenketten (z. B. wie `WHERE Name = 'müller'` oder `ORDER BY Name` ausgeführt wird).

#### Aufbau des Namens einer Kollation:
`[Zeichensatz]_[Sprach-/Sortierregel]_[Suffix]`
*   **`_ci` (Case Insensitive):** Gross- und Kleinschreibung wird beim Suchen und Sortieren ignoriert (`'a'` = `'A'`).
*   **`_cs` (Case Sensitive):** Gross- und Kleinschreibung wird unterschieden (`'a'` ≠ `'A'`).
*   **`_bin` (Binary):** Vergleich erfolgt direkt auf dem Binärwert der Bytes (extrem schnell, unterscheidet Gross-/Kleinschreibung und Akzente exakt).

#### Wichtige Kollationen für Deutsch und Unicode:
*   **`utf8mb4_unicode_ci` (Empfohlen):** Sortiert exakt nach dem Unicode-Standard. Unterstützt korrekte Vergleiche über Sprachgrenzen hinweg.
*   **`utf8mb4_german2_ci` (Telefonbuch-Sortierung):** Behandelt Umlaute nach DIN 5007-2 (ä = ae, ö = oe, ü = ue, ß = ss). Ideal für Namensregister in Deutschland/Schweiz.
*   **`utf8mb4_general_ci`:** Eine vereinfachte Sortierregel. Schneller als `unicode_ci`, sortiert aber in Grenzfällen (z. B. Sonderzeichen) ungenauer. Heute wegen starker CPUs kaum noch nötig.

#### Kollation einer Spalte nachträglich ändern:
```sql
ALTER TABLE tbl_mitarbeiter
  MODIFY Name VARCHAR(50)
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_german2_ci;
```

---

## 3. SQL-Befehlsgruppen (DQL, DML, DDL, DCL, TCL)

Die Befehle der Structured Query Language (SQL) werden anhand ihrer Funktion in fünf standardisierte Gruppen unterteilt:

```
                          +------------------------+
                          |      SQL Commands      |
                          +------------------------+
                                      |
         +-----------------+----------+----------+-----------------+
         |                 |                     |                 |
     +-------+         +-------+             +-------+         +-------+
     |  DDL  |         |  DML  |             |  DCL  |         |  TCL  |
     +-------+         +-------+             +-------+         +-------+
     |CREATE |         |INSERT |             |GRANT  |         |COMMIT |
     |ALTER  |         |UPDATE |             |REVOKE |         |ROLLBAC|
     |DROP   |         |DELETE |             +-------+         +-------+
     |TRUNCAT|         +-------+                 |
     +-------+             |                 +-------+
                       +-------+             |  DQL  |
                       |  DQL  |             +-------+
                       +-------+             |SELECT |
                       |SELECT |             +-------+
                       +-------+
```

| Gruppe | Bezeichnung | Befehle | Zweck / Erklärung |
|--------|-------------|---------|-------------------|
| **DDL** | Data Definition Language | `CREATE`, `ALTER`, `DROP`, `TRUNCATE` | Definiert und ändert das **Datenbankschema** (Struktur von Tabellen, Indizes, Views). |
| **DML** | Data Manipulation Language | `INSERT`, `UPDATE`, `DELETE` | Manipuliert die **Nutzdaten** (Zeilen) innerhalb der Tabellen. |
| **DQL** | Data Query Language | `SELECT`, `SHOW` | Dient ausschliesslich der **Abfrage** und dem Auslesen von Daten. *(Gehört oft formal zur DML).* |
| **DCL** | Data Control Language | `GRANT`, `REVOKE` | Verwaltet die **Zugriffsrechte** und Sicherheitseinstellungen der Benutzer. |
| **TCL** | Transaction Control Language | `COMMIT`, `ROLLBACK`, `SAVEPOINT` | Steuert das Verhalten von **Transaktionen** (Änderungen festschreiben oder verwerfen). |

> [!IMPORTANT]
> **Der Unterschied zwischen `DELETE` (DML) und `TRUNCATE` (DDL):**
> *   `DELETE FROM tabelle;` löscht Datensätze zeilenweise. Jede gelöschte Zeile wird im Transaktionsprotokoll (Undo-Log) aufgezeichnet. Dieser Vorgang ist langsam, kann aber mittels `ROLLBACK` rückgängig gemacht werden.
> *   `TRUNCATE TABLE tabelle;` löscht die gesamte Tabelle physisch und baut sie sofort leer neu auf. Dies umgeht das zeilenweise Logging, ist extrem schnell, kann aber **nicht** rückgängig gemacht werden (kein Rollback möglich!).

---

## 4. Datenbank „Firma" erstellen & Daten importieren

SQL-Scripts: [Firma_DDL.sql](Firma_DDL.sql)

### 4.1 Datenbank und Tabellen anlegen
```sql
CREATE DATABASE IF NOT EXISTS firma
  DEFAULT CHARACTER SET utf8mb4
  DEFAULT COLLATE utf8mb4_unicode_ci;

USE firma;
```

---

### 4.2 CSV-Massenimport (`LOAD DATA INFILE`)

Der Import aus strukturierten Textdateien (z. B. CSV) ist die performanteste Methode, um Daten in eine SQL-Datenbank zu laden.

```sql
LOAD DATA LOCAL INFILE 'Abteilungen.txt'
INTO TABLE tbl_abteilung
FIELDS TERMINATED BY ';'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES
(Abtlg_ID, Bezeichnung);
```

#### Diagnose bei Importfehlern:
Wenn der Import mit `ERROR 1290 (HY000): The MariaDB server is running with the --secure-file-priv option` fehlschlägt, blockiert das Sicherheitsfeature des Servers den Zugriff auf lokale Dateien.
*   **Lösung A:** Kopieren Sie die CSV-Datei in das Verzeichnis, das durch `SHOW VARIABLES LIKE 'secure_file_priv';` ausgegeben wird (z. B. `C:/xampp/mysql/data/`).
*   **Lösung B:** Setzen Sie in der `my.ini` unter `[mysqld]` den Parameter `secure_file_priv = ""` (erfordert Server-Neustart), um Importe aus jedem Verzeichnis zu erlauben (nur für Entwicklungsumgebungen empfohlen!).

---

### 4.3 SQL-Skripte über die Kommandozeile importieren

Nutzen Sie die Einlese-Redirection (`<`), um vorgefertigte SQL-Dateien direkt auszuführen.

```cmd
-- Importieren der Postleitzahlen und Mitarbeiter
mysql -u root -p firma < tbl_plz_ort.sql
mysql -u root -p firma < tbl_mitarbeiter.sql
```

> [!WARNING]
> **PowerShell-Einschränkung bei Redirection:**
> Die klassische PowerShell 5.x interpretiert die Operatoren `<` und `>` anders als die CMD und speichert Ausgaben oft fälschlicherweise in UTF-16, was zu korrupten Dumps führt. Verwenden Sie für Datenbank-Dumps und -Imports unter Windows standardmässig die klassische Eingabeaufforderung (`cmd.exe`) oder nutzen Sie in PowerShell die Parameter `--result-file` von mysqldump.

---

### 4.4 Engine von MyISAM auf InnoDB konvertieren

Um Fremdschlüssel und Transaktionen nutzen zu können, müssen alte Tabellen oft von der veralteten `MyISAM`-Engine auf das moderne `InnoDB`-Format umgestellt werden.

```sql
-- Vorhandene Triebwerke und Indizes anzeigen
SHOW TABLE STATUS FROM firma;
SHOW INDEX FROM tbl_mitarbeiter;

-- Tabellentyp ändern
ALTER TABLE tbl_mitarbeiter ENGINE = InnoDB;
ALTER TABLE tbl_abteilung   ENGINE = InnoDB;
ALTER TABLE tbl_plz_ort     ENGINE = InnoDB;

-- Zur Kontrolle erneut den Engine-Typ prüfen
SHOW TABLE STATUS FROM firma;
```

---

### 4.5 Backup erstellen mit `mysqldump`

Mit `mysqldump` erstellen Sie ein textbasiertes Backup, das alle SQL-Befehle (`CREATE TABLE`, `INSERT`) enthält, um die DB an einem anderen Ort wiederherzustellen.

```cmd
-- Vollständiges Backup (Struktur + Daten)
mysqldump -u root -p firma > firma_dump.sql

-- Backup NUR der Tabellenstruktur (ohne INSERTs)
mysqldump -u root -p --no-data firma > firma_schema.sql

-- Dump wieder einspielen
mysql -u root -p firma < firma_dump.sql
```

---

## 5. Checkpoint-Fragen: DB-Server und XAMPP

### Wie kann der MySQL-Server gestartet werden?
* [ ] Start von `mysql.exe` im CMD-Fenster *(Falsch: `mysql.exe` ist der Client.)*
* [x] Start von `mysqld.exe` im CMD-Fenster *(Richtig: Startet das Server-Triebwerk direkt.)*
* [x] Über MySQL Workbench *(Richtig: Über das Administrationsmenü, falls als Dienst eingerichtet.)*
* [ ] Eingabe von `localhost` als URL im Browser *(Falsch: Ruft nur den Webserver/phpMyAdmin auf, startet aber nicht den DB-Dienst selbst.)*
* [x] `NET START mysql` im CMD-Fenster *(Richtig: Windows-Standardbefehl für Systemdienste.)*
* [x] Mit dem Dienstmanager von Windows (`services.msc`) *(Richtig: Grafische Diensteverwaltung.)*

---

### Welche Informationen erhalten Sie beim Befehl `status;`?
* [x] Version des Konsolenprogramms (Client-Version)
* [x] Betriebszeit des Servers (Uptime)
* [x] Version des Servers
* [ ] Betriebszeit des DB-Klienten mysql *(Falsch: Der Client trackt keine eigene Betriebszeit.)*

---

### Welche Daten befinden sich im Verzeichnis `datadir`?
* [x] Protokoll-Dateien (Log-Files, z. B. Error Log)
* [x] Fehlerprotokolle (`.err`-Dateien)
* [ ] Die ausführbaren Programme (z. B. `mysql.exe`) *(Falsch: Diese liegen im `bin`-Verzeichnis.)*
* [x] Physische Datenbankordner und Tabellendateien (z. B. InnoDB-Tablespaces)

---

### Wie testen Sie die Installation des DB-Servers?
1. Prüfen, ob der Prozess `mysqld.exe` im Windows Task-Manager aktiv ist.
2. Verbindung per CLI-Client aufbauen: `mysql -u root -p`.
3. Systemdatenbanken anzeigen lassen mit `SHOW DATABASES;`.
4. Rufen Sie `http://localhost/phpmyadmin` auf. Wenn die Oberfläche geladen wird und die DB-Struktur anzeigt, funktioniert die Installation.

---

## 6. Checkpoint-Fragen: Codierung und Kollation

### Welche Aussagen treffen zur Codierung zu?
* [ ] Ein Datenbankserver erkennt die Codierung einer Datei automatisch *(Falsch: Beim Import muss die Codierung explizit mitgeteilt werden, sonst drohen Zeichensatzfehler.)*
* [x] Codierung ist eine Vereinbarung zwischen dem Nutzer und dem System. *(Richtig: Definiert die Repräsentation.)*
* [x] Die Codierung legt fest, welche binäre Bitkombination zu welchem Zeichen gehört. *(Richtig: Zeichensatz-Definition.)*
* [ ] ANSI- und ASCII-Codierung ist dasselbe *(Falsch: ANSI ist eine 8-Bit-Erweiterung, ASCII nutzt nur 7 Bit.)*
* [ ] Der Unicode-Zeichensatz hat immer eine feste 32-Bit-Codelänge *(Falsch: Die Länge hängt von der Kodierung ab – UTF-8 ist variabel 1–4 Byte.)*
* [x] UTF bedeutet Unicode Transformation Format *(Richtig.)*
* [ ] UTF-8 hat nur 8 Bit lange Zeichen aus dem Unicode-Zeichensatz *(Falsch: UTF-8 nutzt 1 bis 4 Byte (8 bis 32 Bit) je nach Komplexität des Zeichens.)*

---

### Welche Aussagen treffen zur Kollation zu?
* [ ] `utf8_general_cs` ist die Standard-Einstellung bei MySQL. *(Falsch: Standard ist ein `_ci` (case insensitive) Zeichensatz, z. B. `utf8mb4_general_ci` oder `utf8mb4_0900_ai_ci`.)*
* [x] In der DIN-Normierung zur deutschen Kollation werden zwei Varianten zur Umlauthandhabung angeboten. *(Richtig: DIN 5007-1 (ä = a) und DIN 5007-2 (ä = ae) – letzteres entspricht `german2`.)*
* [ ] Die Endung `_ci` gibt an, dass die Sortierung die Gross-/Kleinschreibweise unterscheidet. *(Falsch: `_ci` steht für Case **In**sensitive – ignoriert den Unterschied.)*
* [x] Seit MySQL 5.5.3 sollte `utf8mb4` anstelle von `utf8` verwendet werden. *(Richtig: Nur `utf8mb4` unterstützt vollen 4-Byte-Unicode inklusive Emojis.)*
* [x] In der Konfig-Datei (my.ini) kann die UTF8-Codierung als Standard angegeben werden. *(Richtig: Über `character-set-server`.)*
* [ ] Eine Kollationseinstellung gilt zwingend für die ganze Tabelle (Entität). *(Falsch: Kann feingranular pro Spalte individuell festgelegt werden.)*
* [x] „Binärsortierung" ist die Sortierung anhand des binären Codes der verglichenen Zeichen. *(Richtig: Entspricht Kollationen mit dem Suffix `_bin`.)*

---

## 7. Checkpoint-Fragen: Daten importieren

### Mit welchem Befehl kontrollieren Sie die Struktur einer Tabelle?
* [ ] `SHOW DATABASES;` *(Falsch: Zeigt nur die vorhandenen Datenbanken an.)*
* [x] `SHOW CREATE TABLE tabellenname;` *(Richtig: Gibt das exakte SQL-Statement aus, mit dem die Tabelle erstellt wurde.)*
* [x] `DESC tabellenname;` *(Richtig: Kurzform für DESCRIBE.)*
* [x] `DESCRIBE tabellenname;` *(Richtig: Listet Spalten, Typen, Null-Erlaubnis und Keys tabellarisch auf.)*
* [ ] `SELECT * FROM tabellenname;` *(Falsch: Gibt den Inhalt/die Daten aus, nicht das Schema.)*
* [ ] `SHOW TABLE tabellenname;` *(Falsch: Kein gültiger SQL-Syntax.)*
