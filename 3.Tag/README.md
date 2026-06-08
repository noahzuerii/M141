# Tag 3 – Tabellentypen und Transaktionen

Themen: MyISAM vs InnoDB, Tablespace, ACID, BEGIN/COMMIT/ROLLBACK, Locking

[← Zurück zur Übersicht](../README.md)

SQL-Dateien in diesem Ordner: [Demo_Transaktionen.sql](Demo_Transaktionen.sql)

---

## 1. Tabellentypen: MyISAM vs. InnoDB

Die Wahl des Speicherverfahrens (Storage Engine) bestimmt, wie Tabellen physikalisch auf der Festplatte abgelegt, gesperrt und indiziert werden. In MariaDB/MySQL sind **MyISAM** und **InnoDB** die historisch und praktisch bedeutendsten Engines.

### Speicherarchitektur im Detail

```
 Speicherstruktur auf der Festplatte (data/):
 
 MyISAM-Tabelle:                          InnoDB-Tabelle (file-per-table):
 +----------------------------------+     +----------------------------------+
 |  kunden.frm  (Tabellendefinition)|     |  kunden.frm  (Tabellendefinition)|
 +----------------------------------+     +----------------------------------+
 |  kunden.MYD  (Reine Nutzdaten)   |     |  kunden.ibd                      |
 +----------------------------------+     |  - Daten (B+ Tree)               |
 |  kunden.MYI  (Indexstruktur)     |     |  - Primärindizes                 |
 +----------------------------------+     |  - Sekundärindizes               |
                                          +----------------------------------+
```

| Merkmal | MyISAM (/ Aria) | InnoDB |
|---------|----------------|--------|
| **Transaktionen** | Nein. Aria (MariaDB-Nachfolger von MyISAM) unterstützt einfache Crash-Sicherheit, aber keine vollen Transaktionen. | **Ja.** Unterstützt das vollständige ACID-Prinzip. |
| **Referentielle Integrität** | Nein. Deklarative Foreign Keys werden ignoriert (die Tabellen werden erstellt, aber Fremdschlüssel-Constraints werden nicht überprüft). | **Ja.** Prüft und erzwingt alle Fremdschlüsselbeziehungen streng. |
| **Locking-Stufe** | **Table-Level-Locking.** Schreibzugriffe sperren immer die gesamte Tabelle für andere Nutzer. | **Row-Level-Locking.** Nur die gerade veränderten Zeilen werden gesperrt. Hohe Parallelität im Mehrbenutzerbetrieb. |
| **Crash-Recovery** | Nein. Nach einem Stromausfall oder Absturz können MyISAM-Tabellen beschädigt werden und müssen repariert werden (`REPAIR TABLE`). | **Ja (automatisch).** Stellt den Zustand beim Serverstart mittels Redo-Logs konsistent wieder her. |
| **Speicherung** | Drei Dateien pro Tabelle: `.frm` (Metadaten), `.MYD` (Daten), `.MYI` (Indizes). | `.frm` (Metadaten) + Tablespace (entweder in der globalen Datei `ibdata1` oder pro Tabelle in einer `.ibd`-Datei). |
| **Daten- & Indexspeicherung** | Daten und Indizes sind getrennt. Indizes verweisen auf die physische Dateiposition der Zeile. | **Clustered Index.** Tabellendaten sind direkt im Primärschlüssel-B+Tree organisiert. Sekundärindizes verweisen auf den Primärschlüssel. |

---

### Tabellentyp festlegen und ändern

```sql
-- Erstellen einer neuen Tabelle mit der InnoDB-Engine
CREATE TABLE tbl_konto (
    id_k  INT AUTO_INCREMENT,
    Name  VARCHAR(30),
    Saldo DECIMAL(10,2),
    PRIMARY KEY (id_k)
) ENGINE = InnoDB;

-- Tabellentyp einer bestehenden Tabelle nachträglich ändern
ALTER TABLE tbl_benutzer ENGINE = InnoDB;

-- Engine-Typ und Status aller Tabellen einer DB kontrollieren
SHOW TABLE STATUS FROM hotel;
```

> [!CAUTION]
> **Achtung bei Systemtabellen:**
> Die internen Tabellen in der Systemdatenbank `mysql` (z. B. Privilege-Tabellen) wurden historisch als MyISAM angelegt. Ändern Sie niemals den Engine-Typ der Systemdatenbanken, da dies den Server instabil oder unbrauchbar machen kann.

---

## 2. Transaktionen (Transaction Management)

Eine **Transaktion** fasst mehrere SQL-Operationen zu einer logischen Einheit zusammen. Sie stellt sicher, dass Daten auch bei Hardwareabstürzen oder parallelen Zugriffen konsistent bleiben.

### Syntax: BEGIN, COMMIT und ROLLBACK

```sql
-- 1. Transaktion starten
BEGIN; -- oder: START TRANSACTION;

-- 2. Transaktionsoperationen durchführen
UPDATE tbl_konto SET Saldo = Saldo - 500.00 WHERE Name = 'Müller';
UPDATE tbl_konto SET Saldo = Saldo + 500.00 WHERE Name = 'Meier';

-- 3. Transaktion abschliessen
COMMIT;   -- Übernimmt alle Änderungen dauerhaft auf den Datenträger.
-- ODER:
ROLLBACK; -- Verwirft alle Änderungen seit dem BEGIN vollständig.
```

---

### Autocommit-Modus

Standardmässig läuft MySQL/MariaDB im **Autocommit-Modus** (`AUTOCOMMIT = 1`). Jedes einzelne SQL-Statement (z. B. ein `INSERT` oder `UPDATE`) wird sofort implizit committet und ist direkt unumkehrbar auf der Festplatte gespeichert.

*   Um mehrere Statements manuell zu gruppieren, wird eine Transaktion explizit mit `BEGIN` gestartet (Autocommit wird temporär für diese Session ausgesetzt).
*   Alternativ kann Autocommit dauerhaft für die aktuelle Session deaktiviert werden:
    ```sql
    SET AUTOCOMMIT = 0;
    -- Ab hier müssen ALLE Datenänderungen explizit mit COMMIT bestätigt werden!
    ```

---

## 3. ACID-Eigenschaften

Jede transaktionale Storage-Engine (wie InnoDB) muss die vier ACID-Eigenschaften garantieren, um Datensicherheit zu gewährleisten.

| Buchstabe | Eigenschaft | Bedeutung & Technische Umsetzung |
|:---:|-------------|----------------------------------|
| **A** | **Atomicity** (Atomarität) | **Ganz oder gar nicht.** Entweder werden alle Anweisungen einer Transaktion erfolgreich ausgeführt oder keine einzige. <br>*Umsetzung:* Das **Undo-Log** speichert die Umkehroperationen, um bei einem Fehler oder `ROLLBACK` den Ursprungszustand wiederherzustellen. |
| **C** | **Consistency** (Konsistenz) | **Integrität erhalten.** Vor und nach einer Transaktion muss die Datenbank in einem konsistenten, gültigen Zustand sein. Alle Constraints (Fremdschlüssel, Primary Keys, CHECK-Klauseln) müssen erfüllt sein. |
| **I** | **Isolation** (Isoliertheit) | **Ungestörte Parallelität.** Gleichzeitig ablaufende Transaktionen dürfen sich nicht gegenseitig beeinflussen. <br>*Umsetzung:* Durch **Sperrmechanismen (Locks)** und **MVCC** (Multi-Version Concurrency Control) sieht eine Transaktion Datenänderungen anderer, noch offener Transaktionen nicht. |
| **D** | **Durability** (Dauerhaftigkeit) | **Dauerhafte Speicherung.** Sobald ein `COMMIT` erfolgreich bestätigt wurde, bleiben die Daten dauerhaft im System gespeichert, selbst bei einem plötzlichen Systemabsturz oder Stromausfall. <br>*Umsetzung:* Das **Redo-Log** (Write-Ahead Logging) schreibt Änderungen sofort sequentiell auf die Festplatte, bevor sie in die eigentlichen Datendateien übertragen werden. |

---

### Transaktions-Isolationsstufen (Isolation Levels)

Das SQL-Standard-Modell definiert vier Stufen der Isoliertheit, um unerwünschte Phänomene bei parallelen Zugriffen zu steuern:

| Isolationsstufe | Dirty Read | Non-Repeatable Read | Phantom Read |
|-----------------|:----------:|:-------------------:|:------------:|
| **Read Uncommitted** | Ja | Ja | Ja |
| **Read Committed** | Nein | Ja | Ja |
| **Repeatable Read** (InnoDB-Default) | Nein | Nein | Nein (bei InnoDB durch Next-Key-Locks) |
| **Serializable** | Nein | Nein | Nein |

*   **Dirty Read:** Eine Transaktion liest noch nicht committete (unbestätigte) Daten einer anderen Transaktion.
*   **Non-Repeatable Read:** Werte ändern sich während einer Transaktion, weil ein anderer Client dazwischen committet.
*   **Phantom Read:** Neue Zeilen tauchen unerwartet in Suchergebnissen auf, weil ein anderer Client Zeilen eingefügt hat.

---

## 4. Sperrmechanismen (Locking)

Um Datenintegrität bei parallelen Zugriffen zu garantieren, sperrt das DBMS betroffene Objekte.

### Sperrstufen im Vergleich

1.  **Table-Level-Locking (MyISAM):**
    Sperrt bei einer Änderung die **gesamte Tabelle**. Liest ein Client, blockiert er alle Schreiber. Schreibt ein Client, blockiert er alle Leser und Schreiber.
2.  **Row-Level-Locking (InnoDB):**
    Sperrt ausschliesslich die **betroffenen Zeilen** (Datensätze). Andere Zeilen derselben Tabelle können von anderen Benutzern zeitgleich gelesen und modifiziert werden.

---

### Sperrtypen bei InnoDB

*   **Shared Lock (S-Lock / Lesesperre):**
    Erlaubt anderen Sessions das Lesen der gesperrten Zeile, verhindert jedoch jegliche Modifikation. Mehrere Clients können gleichzeitig ein S-Lock auf dieselbe Zeile halten.
*   **Exclusive Lock (X-Lock / Schreibsperre):**
    Verhindert, dass andere Sessions die Zeile lesen (mit Sperrwunsch) oder schreiben. Nur ein Client kann ein X-Lock halten.

#### Explizites Sperren mit SQL:

```sql
-- 1. Schreibsperre erzwingen (Exclusive Lock)
-- Nützlich, wenn man Daten liest und sie kurz darauf aktualisieren möchte.
BEGIN;
SELECT * FROM tbl_konto WHERE id_k = 1 FOR UPDATE;
-- Datensatz ist für andere gesperrt.
UPDATE tbl_konto SET Saldo = Saldo - 100 WHERE id_k = 1;
COMMIT; -- Gibt die Sperre frei.

-- 2. Lesesperre erzwingen (Shared Lock)
-- Verhindert, dass andere die Daten ändern, während man sie analysiert.
BEGIN;
SELECT * FROM tbl_konto WHERE id_k = 1 LOCK IN SHARE MODE;
-- Andere dürfen lesen, aber nicht schreiben.
COMMIT;
```

---

### Deadlocks (Verklemmungen)

Ein **Deadlock** entsteht, wenn zwei Transaktionen gegenseitig auf Ressourcen warten, die von der jeweils anderen Transaktion gesperrt sind.

```
Transaktion 1                        Transaktion 2
  |                                    |
  |-- Lockt Zeile A                    |-- Lockt Zeile B
  |                                    |
  |-- Wartet auf Zeile B (blockiert)   |
  |                                    |-- Wartet auf Zeile A (blockiert)
  v                                    v
  =========== DEADLOCK ERKANNT ===========
```

#### Beispiel-Szenario:
1.  **Tx1** sperrt Konto 1 (`FOR UPDATE`).
2.  **Tx2** sperrt Konto 2 (`FOR UPDATE`).
3.  **Tx1** versucht Konto 2 zu sperren $\rightarrow$ *Tx1 muss warten (blockiert)*.
4.  **Tx2** versucht Konto 1 zu sperren $\rightarrow$ *Tx2 müsste warten (Deadlock!)*.

**Erkennung:**
InnoDB erkennt diese zyklischen Abhängigkeiten **automatisch**. Es bricht eine der beiden Transaktionen ab, führt ein automatisches `ROLLBACK` durch und gibt die Sperren frei, sodass die andere Transaktion weiterarbeiten kann.

```sql
-- Letzte Deadlock-Informationen im Server abfragen
SHOW ENGINE INNODB STATUS;
```

---

## 5. Checkpoint-Fragen

### 1. Wie bezeichnet man die Ausführung mehrerer DB-Operationen in einem einzigen Schritt?
* [ ] Referentielle Integrität
* [ ] Replikation
* [x] Transaktion
* [ ] Storage Procedure

> **Erklärung:**
> Eine **Transaktion** ist eine logische Einheit, die mehrere SQL-Statements kapselt und dem Prinzip "alles oder nichts" unterliegt.

---

### 2. Warum sollen Locks möglichst schnell freigegeben werden?
* [ ] damit das DBMS nicht zu stark belastet wird
* [x] damit andere DB-Anwender nicht lange warten müssen
* [ ] damit niemand die Daten ändern kann
* [x] damit möglichst viele Benutzer gleichzeitig auf die DB zugreifen können

> **Erklärung:**
> Sperren schränken den gleichzeitigen Zugriff ein. Um Wartezeiten (Sperrkonflikte) zu minimieren und die Durchsatzrate (Parallelität) des Systems hochzuhalten, müssen Transaktionen so kurz wie möglich gehalten werden.

---

### 3. Welches ist das Standard-Tabellenformat von MySQL (MariaDB)?
* [ ] InnoDB
* [x] MyISAM
* [ ] ARIA
* [ ] ISAM

> **Erklärung:**
> Historisch war **MyISAM** das Standardformat von MySQL. In modernen Versionen von MariaDB und MySQL hat sich **InnoDB** als Standard etabliert. In älteren Lehrmitteln und Standard-XAMPP-Konfigurationen wird MyISAM jedoch oft noch als historischer Standard betitelt.

---

### 4. Wann verwenden Sie das InnoDB-Tabellenformat?
* [ ] wenn möglichst schnell auf die Daten zugegriffen werden muss
* [x] wenn auf gar keinen Fall ein Datenverlust vorkommen darf
* [x] wenn viele Benutzer gleichzeitig Daten ändern
* [ ] wenn bei sehr vielen Daten nicht beliebig viel Speicherplatz vorhanden ist

> **Erklärung:**
> InnoDB ist die Engine der Wahl bei **Mehrbenutzerbetrieb** (dank Row-Level-Locking) und bei **sicherheitskritischen Daten** (ACID, Crash-Recovery). MyISAM bietet zwar bei reinem Lesezugriff leichten Geschwindigkeitsvorteil und spart Festplattenplatz, bietet jedoch keine Transaktionssicherheit.

---

### 5. Was trifft auf den sog. Tablespace zu?
* [ ] Datei, welche die Daten der entsprechenden Tabelle enthält (`*.MYD`)
* [ ] Datei, welche Beschreibung, Daten und Indexe einer Tabelle enthält
* [x] Datei, welche alle InnoDB-Tabellen enthält (virtueller Speicher)
* [x] wird nach Erreichen von x MB automatisch vergrössert (falls autoextend eingeschaltet)

> **Erklärung:**
> Der Tablespace (`ibdata1` beim globalen Modell) ist die Speicherdatei für alle InnoDB-Tabellenstrukturen und Daten. Ist `autoextend` aktiviert, vergrössert sich die Datei bei Bedarf dynamisch.

---

### 6. Mit welchen Befehlen werden Transaktionen gesteuert?
* [ ] UNLOCK TABLES;
* [x] COMMIT; oder ROLLBACK;
* [ ] ALTER TABLE ... TYPE= ...;
* [x] BEGIN; oder START TRANSACTION;

---

### 7. Was trifft auf das Locking bei Transaktionen auf InnoDB-Tabellen zu?
* [ ] in Transaktionen kommt Table locking zur Anwendung
* [x] es wird Row locking angewendet
* [ ] es werden alle Datensätze der entsprechenden Tabelle(n) gesperrt
* [x] es werden nur die gerade bearbeiteten Datensätze gesperrt

---

### 8. Welches sind Vorteile der InnoDB-Tabellen gegenüber MyISAM-Tabellen?
1.  **Transaktionssicherheit (ACID):** Schutz vor unvollständigen Schreibvorgängen.
2.  **Referentielle Integrität:** Fremdschlüsselprüfung verhindert inkonsistente Verknüpfungen.
3.  **Fehlertoleranz (Crash-Recovery):** Automatische Rekonstruktion ungeschriebener Daten nach einem Systemabsturz über das Redo-Log.
4.  **Hohe Nebenläufigkeit:** Row-Level-Locking verhindert, dass Leser und Schreiber sich gegenseitig auf Tabellenebene blockieren.

---

### 9. In welchen Dateien wird die MyISAM-Tabelle KUNDEN gespeichert?
*   `KUNDEN.FRM`: Enthält die Tabellendefinition (Schema und Spaltendefinitionen).
*   `KUNDEN.MYD` (MyData): Enthält die reinen Datensätze.
*   `KUNDEN.MYI` (MyIndex): Speichert die Indexbäume für schnelle Suchanfragen.

---

### 10. Notieren Sie den SQL-Befehl, der die InnoDB-Tabelle BESTELLUNGEN erstellt.
```sql
CREATE TABLE BESTELLUNGEN (
    bestell_id   INT            NOT NULL AUTO_INCREMENT,
    kunden_id    INT            NOT NULL,
    bestelldatum DATE,
    betrag       DECIMAL(10,2),
    PRIMARY KEY (bestell_id)
) ENGINE = InnoDB;
```

---

### 11. Welche Locking-Art ist a) bei MyISAM-Tabellen b) bei InnoDB-Tabellen möglich?
*   **a) MyISAM:** Nur **Table-Level-Locking** (Sperrung der gesamten Tabelle bei Schreiboperationen).
*   **b) InnoDB:** Hauptsächlich **Row-Level-Locking** (Sperrung einzelner Zeilen). Das Sperren der ganzen Tabelle (`Table Lock`) ist optional ebenfalls möglich (z. B. durch `LOCK TABLES`), wird aber selten empfohlen.

---

### 12. Beschreiben Sie den Begriff Datenbank-Transaktion!
Eine Datenbank-Transaktion ist eine logische Folge von einer oder mehreren SQL-Anweisungen, die als atomare (unteilbare) Einheit ausgeführt wird. Sie überführt die Datenbank von einem konsistenten Zustand in einen neuen konsistenten Zustand. Schlägt ein Befehl fehl, macht das System alle Änderungen über ein `ROLLBACK` rückgängig.

---

### 13. Beschreiben Sie die Bedeutung von I in der Abkürzung ACID.
**I = Isolation (Isoliertheit):**
Stellt sicher, dass parallel ausgeführte Transaktionen so isoliert voneinander ablaufen, als ob sie nacheinander ausgeführt würden. Keine Transaktion darf unfertige Zwischenstände einer anderen Transaktion sehen. Das schützt vor Fehlberechnungen durch parallele Datenänderungen.

---

### 14. Wie stellen Transaktionen bei einem DB-Server-Crash die Datenkonsistenz sicher?
Durch das Prinzip des **Write-Ahead Loggings**. InnoDB schreibt alle Transaktionsschritte sequentiell in das **Redo-Log** auf dem Datenträger, bevor die eigentliche Tabellendatei im Tablespace geändert wird. Nach einem Absturz liest der Server beim Start das Redo-Log:
*   Bereits mit `COMMIT` bestätigte Transaktionen werden nachgeschrieben (Redo/Roll-Forward).
*   Unfertige Transaktionen ohne Commit werden anhand der Daten im **Undo-Log** zurückgerollt (Undo/Rollback).

---

### 15. Mit welcher Locking-Art wartet ein SELECT-Befehl, bis alle Transaktionen auf die angeforderte Tabelle entsperrt sind?
Mit einem **Shared Lock**, initiiert durch:
```sql
SELECT * FROM tabelle LOCK IN SHARE MODE;
```
Dieser Befehl fordert eine Lesesperre an und muss warten, bis alle exklusiven Schreibsperren (X-Locks) anderer Transaktionen auf den betroffenen Zeilen freigegeben wurden.

---

### 16. Wie muss Autocommit gesetzt werden, damit jeder SQL-Befehl zu einer Transaktion gehört und explizit mit COMMIT abgeschlossen werden muss?
Der Autocommit-Modus muss deaktiviert werden:
```sql
SET AUTOCOMMIT = 0;
```
Ab diesem Zeitpunkt startet das DBMS bei der ersten Datenänderung implizit eine neue Transaktion, die erst durch ein manuelles `COMMIT` dauerhaft gespeichert oder durch `ROLLBACK` verworfen wird.
