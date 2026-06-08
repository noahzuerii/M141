# Tag 6 – Server-Administration im Produktivbetrieb

Themen: Konfiguration, Logging, Backup & Recovery, Optimierung

[← Zurück zur Übersicht](../README.md)

---

## 1. Konfiguration des RDBMS

Im Betrieb eines Datenbanksystems gibt es drei Möglichkeiten, Konfigurationsparameter zu definieren. Diese besitzen eine feste Rangordnung (Priorität).

```
 Priorität bei Konfigurationsparametern:
 
 +---------------------------------------------------------------+
 | Prio 1: Kommandozeilen-Parameter (beim Start von mysqld)       |
 +---------------------------------------------------------------+
   | (überschreibt alle darunterliegenden Werte)
   v
 +---------------------------------------------------------------+
 | Prio 2: Systemvariablen zur Laufzeit (SET GLOBAL ...)         |
 +---------------------------------------------------------------+
   | (wirkt sofort im RAM, geht nach Neustart verloren)
   v
 +---------------------------------------------------------------+
 | Prio 3: Konfigurationsdatei (my.ini / my.cnf)                 |
 +---------------------------------------------------------------+
```

### Die drei Konfigurationswege im Detail

1.  **Konfigurationsdatei (`my.ini` / `my.cnf`):**
    Der Standardweg für dauerhafte Einstellungen. Der Server liest diese Datei bei jedem Start ein.
2.  **Kommandozeilen-Parameter:**
    Parameter, die beim direkten Aufruf des Serverprozesses übergeben werden (z. B. `mysqld --port=3307`). Diese Einstellungen überschreiben die Werte in der `my.ini` für diesen einen Start.
3.  **Systemvariablen (`SET GLOBAL` / `SET SESSION`):**
    Viele Parameter lassen sich im laufenden Betrieb per SQL-Befehl ändern, ohne dass der Server neu gestartet werden muss.
    ```sql
    -- Ändern eines Parameters für den gesamten Server zur Laufzeit
    SET GLOBAL slow_query_log = 1;
    
    -- Ändern eines Parameters nur für die aktuelle Verbindung (Session)
    SET SESSION join_buffer_size = 1048576;
    ```
    *Wichtig:* Mit `SET GLOBAL` geänderte Werte sind flüchtig und gehen bei einem Serverneustart verloren, sofern sie nicht auch in die `my.ini` eingetragen werden.

---

### Konfiguration validieren (vor dem Neustart)

Syntaxfehler in der `my.ini` (z. B. falsche Parameternamen oder Tippfehler) führen dazu, dass der Server-Dienst abstürzt oder nicht mehr startet. Prüfen Sie die Datei daher vor einem geplanten Neustart:
```cmd
-- Validiert die Standardkonfiguration
mysqld --validate-config

-- Validiert eine spezifische Datei
mysqld --defaults-file="C:\xampp\mysql\my.ini" --validate-config
```
*(Bleibt die Konsole leer und gibt keinen Fehler aus, ist die Datei syntaktisch korrekt.)*

---

## 2. Protokollierung (Logging)

Logs sind essenziell für die Fehlersuche, Sicherheitsüberwachung und Datenwiederherstellung. Da Logging jedoch CPU-Leistung und Speicherplatz beansprucht, sollten in der Produktion nur benötigte Protokolle aktiviert sein.

### Die Log-Typen im Überblick

| Log-Typ | Dateiname (Beispiel) | Inhalt & Verwendungszweck | Leistungseinhalt |
|---------|----------------------|---------------------------|------------------|
| **Error Log** | `mysql_error.log` | Start/Stop-Einträge, kritische Fehler, Abstürze. **Immer aktiv.** | Minimal. |
| **Binary Log** | `mysql-bin.000001` | Protokolliert jede datenverändernde Aktion (DML/DDL) im Binärformat. Zwingend nötig für **Replikation** und **Point-in-Time-Recovery**. | Mittel (Schreibzugriffe werden minimal verzögert). |
| **General Query Log** | `<hostname>.log` | Protokolliert jeden Verbindungsaufbau (Login/Logout) und **jeden einzelnen abgesetzten SQL-Befehl** aller Clients. Nur zu Debugging-Zwecken aktivieren! | **Sehr hoch** (Schreibflaschenhals auf der Festplatte). |
| **Slow Query Log** | `<hostname>-slow.log` | Zeichnet Abfragen auf, die eine definierte Ausführungszeit überschreiten. Ideal zur Performance-Analyse. | Gering (da nur langsame Abfragen gefiltert werden). |
| **Transaction Log** | `ib_logfile0` / `ib_logfile1` | Internes InnoDB-Redo-Log zur Absicherung von Transaktionen und für das automatische Crash-Recovery. **Immer aktiv.** | Mittel (wird sequentiell geschrieben). |

---

### Point-in-Time Recovery (PITR) mit dem Binary Log

Das Binary Log ermöglicht es, nach einem Hardwareausfall oder einem fatalen Benutzerfehler (z. B. ein `DELETE FROM kunden` ohne `WHERE`-Klausel) den exakten Datenbestand bis zu einer bestimmten Sekunde wiederherzustellen.

```
Point-in-Time-Recovery Ablauf:
                                  Unfall (z.B. Drop Table)
                                            |
[Backup.sql] ------------[Binary Log 001] --v--------- [Binary Log 002]
     |                           |                            |
 1. Einspielen              2. Einspielen bis                (Ignorieren)
                            exakt 13:59:59 Uhr
```

#### Schritt-für-Schritt-Anleitung:
1.  **Letztes vollständiges Backup** einspielen:
    ```cmd
    mysql -u root -p firma < C:\backup\firma_backup.sql
    ```
2.  **Binary Logs analysieren** und den genauen Zeitpunkt des Fehlers ermitteln:
    ```cmd
    -- Binärdatei in lesbares Textformat konvertieren
    mysqlbinlog --base64-output=DECODE-ROWS -v C:\xampp\mysql\data\mysql-bin.000002 > C:\temp\binlog_lesbar.sql
    ```
    *Suchen Sie in der Textdatei nach dem fehlerhaften Befehl (z. B. `DROP TABLE`) und notieren Sie sich den Zeitstempel (z. B. `2026-06-08 14:00:05`).*
3.  **Wiederherstellung der Transaktionen** seit dem Backup bis unmittelbar vor dem Fehlerzeitpunkt:
    ```cmd
    mysqlbinlog --stop-datetime="2026-06-08 14:00:00" C:\xampp\mysql\data\mysql-bin.000001 C:\xampp\mysql\data\mysql-bin.000002 | mysql -u root -p
    ```

---

## 3. Backup & Recovery

Ein sicheres Backup muss im laufenden Betrieb konsistent sein und darf die Anwendung nicht blockieren.

### Der Unterschied beim Tabellenlocking:

*   **`--lock-tables` (MyISAM-Standard):**
    Sperrt alle Tabellen der Datenbank für Schreibzugriffe während des Dumps. Garantiert Konsistenz, blockiert jedoch produktive Webanwendungen komplett.
*   **`--single-transaction` (InnoDB-Standard - Empfohlen):**
    Nutzt das MVCC-Prinzip (Multi-Version Concurrency Control) von InnoDB. Es startet eine Transaktion mit der Isolationsstufe `REPEATABLE READ`, um einen konsistenten Snapshot zu lesen. **Die Datenbank wird nicht gesperrt**, andere Benutzer können während des Backups weiterhin Daten schreiben.

#### Wichtige Befehle:
```cmd
-- Konsistentes Online-Backup einer InnoDB-Datenbank (ohne Sperrung der Anwendung)
mysqldump -u root -p --single-transaction --quick --databases firma > C:\backup\firma.sql

-- Backup inkl. Binary-Log-Koordinaten (wichtig für Replikation und PITR)
mysqldump -u root -p --single-transaction --master-data=2 --databases firma > C:\backup\firma_repl.sql
```

---

## 4. Performance-Optimierung

### Index-Architektur: Wie funktioniert ein B-Tree-Index?

Ein B-Tree-Index (Balanced Tree) ist eine baumförmige Datenstruktur, die Suchabfragen drastisch beschleunigt.

```
 B-Tree Indexsuche nach Wert 'Müller':
 
                 [ Root-Knoten: K ]
                    /          \
                   /            \
        [ Node: D - H ]      [ Node: P - T ]  <-- Suche verzweigt nach rechts (M > K)
          /    |    \          /    |    \
         A     F     I        M     R     S   <-- Suche findet Zeiger auf Müller
                             /
                        [ Müller ]  ---> Zeiger auf Datensatz in Tabelle
```

*   **Ohne Index (Full Table Scan / `ALL`):** Der Server muss jeden Datensatz der Tabelle nacheinander von der Festplatte lesen ($O(n)$-Komplexität). Bei 1 Mio. Zeilen sind das 1 Mio. Leseoperationen.
*   **Mit Index:** Der Server navigiert gezielt durch die Baumstufen ($O(\log n)$-Komplexität). Bei 1 Mio. Zeilen sind meist nur 3 bis 4 Leseschritte im Baum nötig, um den Datensatz zu finden.

---

### Best Practices zur Indexierung

*   **Hohe Selektivität:** Legen Sie Indizes nur auf Spalten mit vielen unterschiedlichen Werten (z. B. E-Mail, Kundennummer). Spalten mit geringer Selektivität (z. B. Spalte `geschlecht` mit den Werten M/W) profitieren nicht von einem Index, da das DBMS ohnehin fast die gesamte Tabelle lesen muss.
*   **Leftmost-Prefix-Rule (Zusammengesetzte Indizes):**
    Erstellen Sie einen Index über mehrere Spalten `INDEX(nachname, vorname)`. Dieser beschleunigt Suchen nach:
    *   `nachname`
    *   `nachname AND vorname`
    *   *Achtung:* Eine Suche nur nach `vorname` kann diesen Index **nicht** nutzen! Die Reihenfolge der Spalten im Index ist entscheidend.
*   **Der Index-Nachteil:** Jeder Index verlangsamt Schreiboperationen (`INSERT`, `UPDATE`, `DELETE`), da der B-Tree bei jeder Änderung neu berechnet und sortiert werden muss.

---

### Abfragen analysieren mit `EXPLAIN`

Stellen Sie den Befehl `EXPLAIN` vor ein `SELECT`-Statement, um zu sehen, wie der Abfrageoptimierer (Optimizer) die Daten liest.

```sql
EXPLAIN SELECT * FROM tbl_mitarbeiter WHERE nachname = 'Müller';
```

#### Die `type`-Hierarchie (von schnell nach langsam):
1.  **`system` / `const`:** Die Tabelle hat maximal eine passende Zeile (z. B. Suche nach dem Primärschlüssel). Extrem schnell.
2.  **`eq_ref`:** Für jede Zeile der vorherigen Tabelle wird genau eine Zeile aus dieser Tabelle gelesen (oft bei Joins über Primärschlüssel).
3.  **`ref`:** Alle passenden Zeilen werden über einen normalen Index gelesen (z. B. Suche nach Nicht-Unique-Indizes).
4.  **`range`:** Der Index wird genutzt, um Zeilen in einem bestimmten Bereich zu finden (z. B. `WHERE id > 100` oder `BETWEEN`).
5.  **`index`:** Ein Index-Scan. Der Server liest den gesamten Indexbaum (zwar schneller als die Tabelle, aber dennoch ein vollständiger Scan).
6.  **`ALL` (Full Table Scan):** Die gesamte Tabelle wird von der Festplatte gelesen. **Vermeiden bei grossen Tabellen!**

---

### Der Query Cache und sein Ende

*   **Konzept:** Der Query Cache speichert den genauen SQL-Text einer Abfrage zusammen mit dem exakten Resultat im RAM. Wird dieselbe Abfrage erneut abgeschickt, liefert der Server das Ergebnis blitzschnell ohne Festplattenzugriff zurück.
*   **Das Problem:** Sobald sich in einer Tabelle auch nur eine einzige Zeile ändert (`INSERT`/`UPDATE`), wird der **gesamte Cache für diese Tabelle ungültig gemacht** und gelöscht. Bei modernen Systemen mit vielen Schreibzugriffen und vielen CPU-Kernen führte dies zu massiven Sperrkonflikten (Lock Contention).
*   **Aktueller Status:** Der Query Cache wurde in **MySQL 8.0 komplett entfernt**. In MariaDB ist er aus Kompatibilitätsgründen standardmässig deaktiviert, kann aber bei reinen Lese-Datenbanken (z. B. Data Warehouses) gezielt aktiviert werden.

---

## 5. Checkpoint – Server konfigurieren

### 1. Auf welche Arten können Konfigurationsparameter definiert werden?
* [ ] mit einem INSERT-Befehl
* [x] durch Eintrag auf der Kommandozeile *(Richtig: z. B. Parameter beim Aufruf von mysqld.)*
* [x] durch Eintrag in einer Konfigurationsdatei *(Richtig: Dauerhafte Konfiguration via my.ini.)*
* [ ] durch Eintrag in einem Logfile

---

### 2. Welcher Konfigurationsparameter legt fest, wo die Log-Dateien abgelegt werden?
* [ ] basedir
* [x] datadir *(Richtig: Definiert das Datenverzeichnis des Servers, in dem auch standardmässig die Logs liegen.)*
* [ ] log-bin
* [ ] logdir

---

### 3. Mit welchem Eintrag beginnen die Server-Parameter in der Konfigurationsdatei?
* [ ] [mysql]
* [ ] [WinMySQLadmin]
* [ ] [mysqldump]
* [x] [mysqld] *(Richtig: Leitet den Konfigurationsblock für den Server-Daemon mysqld.exe ein.)*

---

### 4. Wozu kann der DB-Client `mysqlshow` verwendet werden?
* [ ] Backup erstellen
* [x] DB-Schema anzeigen *(Richtig: Zeigt Tabellen- und Spaltenstrukturen an.)*
* [x] Verbindung zum DB-Server testen *(Richtig: Da es eine Netzwerkverbindung aufbaut, dient es als schneller Verbindungstest.)*
* [ ] Inhalt einer Protokolldatei anschauen

---

### 5. Mit welchem Log-File bestimmen Sie den letzten Start des MySQL-Servers?
* [x] Error Log *(Richtig: Protokolliert jeden Start, Shutdown und alle Fehler des Daemons.)*
* [ ] Update Log
* [ ] Query Log
* [ ] Transaction Log

---

### 6. Welcher Eintrag im Konfigurationsfile schaltet die Protokollierung aller User-Logins ein?
* [ ] log-bin
* [ ] log-slow-queries
* [x] log *(Richtig: In modernen Versionen `general_log = 1`. Aktiviert das General Query Log.)*
* [ ] log-error=C:/log/err.log

---

### 7. Wie restaurieren Sie nach einem Server-Ausfall eine DB vollständig?
* [x] Einlesen des letzten Backup *(Richtig: Stellt den Stand zum Backupzeitpunkt wieder her.)*
* [ ] Verwenden der Option `--opt` beim Erstellen des Backup
* [ ] Einlesen des Query-Log
* [x] Einlesen aller Update-Logs in der richtigen Reihenfolge (mit Hilfe von `mysqlbinlog`) *(Richtig: Stellt alle Änderungen seit dem Backup wieder her (Point-in-Time Recovery).)*

---

## 6. Checkpoint – Optimierung

### 1. Welche Möglichkeiten können die Geschwindigkeit eines DB-Servers verbessern?
* [ ] Indexe möglichst vermeiden *(Falsch: Indizes sind das wichtigste Werkzeug für schnelle Suchen.)*
* [x] Serverparameter einstellen *(Richtig: Caches wie den `innodb_buffer_pool_size` vergrössern.)*
* [ ] Transaktionen verwenden *(Falsch: Transaktionen sichern Daten, verlangsamen aber durch Logging tendenziell eher Schreibzugriffe.)*
* [x] Locks verwenden *(Richtig: Temporäres Sperren von Tabellen bei Massen-Imports beschleunigt den Vorgang.)*

---

### 2. Wie werden Daten schneller in eine DB-Tabelle geladen?
* [ ] durch Komprimieren der Daten vor der Übertragung
* [x] durch Verwenden des Parameters `--opt` beim Erstellen des Backup-Skripts *(Richtig: Aktiviert Extended Inserts und deaktiviert temporär Indizes beim Import.)*
* [x] durch Importieren der Daten aus einer Textdatei *(Richtig: Mittels `LOAD DATA INFILE`, da dies den SQL-Parser umgeht.)*
* [ ] durch Verwenden von vielen INSERT-Befehlen *(Falsch: Viele einzelne INSERTs verursachen massiven Overhead.)*

---

### 3. Was trifft auf den Befehl `OPTIMIZE TABLE` zu?
* [x] entfernt nicht genutzten Speicherplatz aus MyISAM-Tabellendateien *(Richtig.)*
* [ ] ist auf MyISAM- und InnoDB-Tabellen anwendbar *(Falsch: Macht bei InnoDB standardmässig keinen Sinn bzw. baut die Tabelle nur neu auf.)*
* [ ] wird angewendet bei Tabellen, die häufig abgefragt werden
* [x] defragmentiert DB-Dateien *(Richtig: Bereinigt physische Lücken nach vielen DELETEs.)*

---

### 4. Wie finden Sie langsame DB-Abfragen?
* [x] mit `EXPLAIN SELECT` *(Richtig: Analysiert, warum eine bestimmte Abfrage langsam ist.)*
* [ ] im Query Log
* [x] im Slow Query Log *(Richtig: Protokolliert automatisch alle Abfragen, die länger als x Sekunden dauern.)*
* [ ] im Error Log

---

### 5. Welche Aussagen betreffend DB-Optimierung sind korrekt?
* [ ] Abfragen, die LIKE enthalten, können immer optimiert werden *(Falsch: Bei `%suchbegriff` ist kein Index nutzbar.)*
* [x] Indexe beschleunigen Abfragen *(Richtig.)*
* [x] Indexe werden allgemein auf Schlüsselattribute gelegt *(Richtig: Primär- und Fremdschlüssel.)*
* [ ] durch Indexe werden DB-Einträge und -änderungen schneller *(Falsch: Sie werden langsamer, da der Indexbaum mitgepflegt werden muss.)*

---

### 6. Wann verwenden Sie den Befehl `EXPLAIN`?
* [ ] um Daten schneller in die DB zu laden
* [x] immer im Zusammenhang mit SELECT *(Richtig: Beschreibt den Ausführungsplan eines SELECTs.)*
* [ ] um langsame Abfragen zu finden *(Falsch: Findet man über das Slow Query Log.)*
* [x] um zu erkennen, wie sich ein Index auf die Geschwindigkeit einer Abfrage auswirkt *(Richtig: Zeigt, ob der Index genutzt (`key`) wird.)*

---

### 7. Welches sind Gründe für die Verwendung eines Index?
* [ ] um das Eintragen von Daten in Tabellen bei Unique-Attributen zu beschleunigen *(Falsch: Macht Schreibzugriffe langsamer.)*
* [x] um DB-Abfragen zu beschleunigen *(Richtig.)*
* [ ] um das Ändern von Daten zu verlangsamen
* [x] um einmalige Werte zu gewährleisten *(Richtig: Ein `UNIQUE`-Index verhindert Duplikate.)*
