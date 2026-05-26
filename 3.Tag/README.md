# Tag 3 – Tabellentypen und Transaktionen

Themen: MyISAM vs InnoDB, Tablespace, ACID, BEGIN/COMMIT/ROLLBACK, Locking

[← Zurück zur Übersicht](../README.md)

SQL-Dateien in diesem Ordner: [Demo_Transaktionen.sql](Demo_Transaktionen.sql)

---

## 1. Tabellentypen: MyISAM vs InnoDB

### Vergleich

| Merkmal | MyISAM (/ Aria) | InnoDB |
|---------|----------------|--------|
| Transaktionen | Nein (Aria: einfach) | Ja |
| Referentielle Integrität | Nein | Ja |
| Locking | Table-Level | Row-Level |
| Geschwindigkeit | Schneller | Etwas langsamer |
| Speicherplatz | Weniger | Mehr |
| Crash Recovery | Nein | Ja (automatisch) |
| Speicherung | 3 Dateien pro Tabelle (`*.FRM`, `*.MYD`, `*.MYI`) | `*.FRM` + Tablespace (`ibdata1`) / `*.ibd` |

### InnoDB-Tabelle erstellen

```sql
CREATE DATABASE innotest;
USE innotest;

CREATE TABLE tbl_konto (
    id_k  INT AUTO_INCREMENT,
    Name  VARCHAR(30),
    Saldo DECIMAL(10,2),
    PRIMARY KEY (id_k)
) ENGINE = InnoDB;
```

### Tabellentyp nachträglich ändern

```sql
ALTER TABLE tbl_benutzer ENGINE = InnoDB;

-- Prüfen:
SHOW TABLE STATUS FROM hotel;
```

> Tabellen der Systemdatenbank `mysql` dürfen **nie** auf InnoDB umgestellt werden – sie müssen im MyISAM-Format bleiben!

### Tablespace-Grösse prüfen

```sql
SELECT SPACE, NAME, ROUND((ALLOCATED_SIZE/1024/1024), 2) AS "Tablespace Size (MB)"
FROM information_schema.INNODB_SYS_TABLESPACES
ORDER BY 3 DESC;
```

---

## 2. Transaktionen

### Wozu Transaktionen?

Transaktionen kapseln mehrere SQL-Anweisungen in einen Block, der **entweder ganz oder gar nicht** ausgeführt wird. Das schützt vor:

1. **gleichzeitigen Änderungen** durch andere Clients (Isolierung)
2. **Datenverlust bei Absturz** – offene Transaktionen werden automatisch zurückgerollt

### Syntax: BEGIN, COMMIT, ROLLBACK

```sql
SET @uebertrag_var = 1000;

BEGIN;   -- oder START TRANSACTION

  -- Saldo prüfen, Übertrag ggf. nullen
  SELECT IF(Saldo >= @uebertrag_var, @uebertrag_var, 0) INTO @uebertrag_var
    FROM tbl_konto WHERE name = 'Von';

  UPDATE tbl_konto SET Saldo = Saldo - @uebertrag_var WHERE name = 'Von';
  UPDATE tbl_konto SET Saldo = Saldo + @uebertrag_var WHERE name = 'Nach';

COMMIT;   -- alle Änderungen übernehmen
-- oder ROLLBACK;  -- alle Änderungen rückgängig machen
```

### Autocommit

| Einstellung | Verhalten |
|-------------|-----------|
| `AUTOCOMMIT=1` (Standard) | Jedes Statement wird sofort ausgeführt |
| `AUTOCOMMIT=0` | Jede Änderung gilt erst nach `COMMIT` |

```sql
SET AUTOCOMMIT = 0;   -- ab hier muss COMMIT explizit gesetzt werden
```

---

## 3. ACID-Eigenschaften

| Buchstabe | Begriff | Bedeutung |
|-----------|---------|-----------|
| **A** | Atomarität | Ganz oder gar nicht – kein halbfertiger Zustand |
| **C** | Konsistenz | Datenbank bleibt nach der Transaktion widerspruchsfrei |
| **I** | Isoliertheit | Transaktionen beeinflussen sich nicht gegenseitig |
| **D** | Dauerhaftigkeit | Committete Änderungen bleiben dauerhaft gespeichert |

### Atomarität
Alle SQL-Anweisungen einer Transaktion gelten als **eine unteilbare Einheit**. Tritt ein Fehler auf, werden bereits durchgeführte Operationen **nicht wirksam**.

### Konsistenz
Nach dem Commit befindet sich die Datenbank in einem **konsistenten Zustand**: alle Integritätsbedingungen, Schlüssel- und Fremdschlüsselverknüpfungen sind erfüllt.

### Isoliertheit
Durch Sperr-Konzepte wird sichergestellt, dass **parallele Transaktionen sich nicht gegenseitig stören**. Sperrungen sollen so kurz wie möglich gehalten werden.

### Dauerhaftigkeit
Nach `COMMIT` sind alle Änderungen **persistent auf der Festplatte** gespeichert – auch nach einem Stromausfall.

---

## 4. Locking-Mechanismen

### Übersicht

| Engine | Locking-Level | Beschreibung |
|--------|--------------|--------------|
| MyISAM | **Table-Level** | Ganze Tabelle wird gesperrt |
| BDB | **Page-Level** | Ganze Speicherseite wird gesperrt |
| Gemini | **Page-Level** | Ganze Speicherseite wird gesperrt |
| InnoDB | **Row-Level** | Nur der betroffene Datensatz wird gesperrt |

### InnoDB – Locking-Varianten

**(1) Auto Locking**  
InnoDB sperrt alle durch `INSERT`, `UPDATE`, `DELETE` veränderten Datensätze automatisch mit einem **Exclusive Lock** bis zum Ende der Transaktion. Gewöhnliche `SELECT`s werden trotzdem sofort ausgeführt (können veraltete Daten liefern).

```sql
-- Kein explizites LOCK nötig; INSERT/UPDATE/DELETE sperren automatisch
BEGIN;
UPDATE tbl_konto SET Saldo = Saldo - 500 WHERE id_k = 1;
-- Datensatz id_k=1 ist jetzt exklusiv gesperrt
COMMIT;
```

**(2) SELECT … FOR UPDATE**  
Datensätze bereits beim Lesen **exklusiv** sperren – sinnvoll, wenn man zuerst liest und dann schreibt.

```sql
BEGIN;
SELECT * FROM tbl_konto WHERE id_k = 1 FOR UPDATE;
-- Datensatz ist jetzt exklusiv gesperrt – andere Clients müssen warten
UPDATE tbl_konto SET Saldo = Saldo - 100 WHERE id_k = 1;
COMMIT;
```

**(3) SELECT … LOCK IN SHARE MODE**  
Datensätze mit einem **Shared Lock** sperren: andere Clients können diese Datensätze auch lesen, aber nicht verändern.

```sql
BEGIN;
SELECT * FROM tbl_konto WHERE id_k = 1 LOCK IN SHARE MODE;
-- Datensatz ist mit Shared Lock belegt; UPDATE durch andere Clients blockiert
COMMIT;
```

**(4) LOCK TABLE (MyISAM)**  
Ganze Tabelle explizit sperren – sehr restriktiv, für InnoDB nicht empfohlen.

```sql
LOCK TABLE tbl_konto WRITE;
-- ... Operationen ...
UNLOCK TABLES;
```

### Deadlock-Erkennung

InnoDB, BDB und Gemini erkennen **Deadlocks automatisch** und führen bei dem auslösenden Prozess ein `ROLLBACK` durch. Zur Diagnose:

```sql
SHOW ENGINE INNODB STATUS;
```

---

## 5. Checkpoint-Fragen

### 1. Wie bezeichnet man die Ausführung mehrerer DB-Operationen in einem einzigen Schritt?

- [ ] Referentielle Integrität
- [ ] Replikation
- [x] Transaktion
- [ ] Storage Procedure

> Mehrere SQL-Befehle werden als atomare Einheit ("ganz oder gar nicht") ausgeführt – das ist eine **Transaktion**.

---

### 2. Warum sollen Locks möglichst schnell freigegeben werden?

- [ ] damit das DBMS nicht zu stark belastet wird
- [x] damit andere DB-Anwender nicht lange warten müssen
- [ ] damit niemand die Daten ändern kann
- [x] damit möglichst viele Benutzer gleichzeitig auf die DB zugreifen können

> Locks blockieren andere Clients. Je kürzer ein Lock gehalten wird, desto besser die Parallelität und Performance.

---

### 3. Welches ist das Standard-Tabellenformat von MySQL (MariaDB)?

- [ ] InnoDB
- [x] MyISAM
- [ ] ARIA
- [ ] ISAM

> **MyISAM** ist der historische Standard. In neueren MariaDB-Versionen (ab 10.x) ist **InnoDB** teils Standard – aber im TBZ-Kontext (XAMPP/MariaDB 10.4) gilt MyISAM als Standardformat.

---

### 4. Wann verwenden Sie das InnoDB-Tabellenformat?

- [ ] wenn möglichst schnell auf die Daten zugegriffen werden muss
- [x] wenn auf gar keinen Fall ein Datenverlust vorkommen darf
- [x] wenn viele Benutzer gleichzeitig Daten ändern
- [ ] wenn bei sehr vielen Daten nicht beliebig viel Speicherplatz vorhanden ist

> InnoDB bietet Transaktionen, Crash-Recovery und Row-Level-Locking → ideal für Sicherheit und Mehrbenutzerbetrieb. MyISAM ist schneller und speichersparender.

---

### 5. Was trifft auf den sog. Tablespace zu?

- [ ] Datei, welche die Daten der entsprechenden Tabelle enthält (`*.MYD`)
- [ ] Datei, welche Beschreibung, Daten und Indexe einer Tabelle enthält
- [x] Datei, welche alle InnoDB-Tabellen enthält (virtueller Speicher)
- [x] wird nach Erreichen von x MB automatisch vergrössert (falls autoextend eingeschaltet)

> Der Tablespace (`ibdata1`) ist der zentrale virtuelle Speicher für alle InnoDB-Tabellen und wächst automatisch in 8-MB-Schritten, wenn `autoextend` aktiv ist.

---

### 6. Mit welchen Befehlen werden Transaktionen gesteuert?

- [ ] UNLOCK TABLES;
- [x] COMMIT; oder ROLLBACK;
- [ ] ALTER TABLE ... TYPE= ...;
- [x] BEGIN; oder START TRANSACTION;

> `BEGIN`/`START TRANSACTION` startet eine Transaktion. `COMMIT` speichert sie dauerhaft, `ROLLBACK` macht sie rückgängig.

---

### 7. Was trifft auf das Locking bei Transaktionen auf InnoDB-Tabellen zu?

- [ ] in Transaktionen kommt Table locking zur Anwendung
- [x] es wird Row locking angewendet
- [ ] es werden alle Datensätze der entsprechenden Tabelle(n) gesperrt
- [x] es werden nur die gerade bearbeiteten Datensätze gesperrt

> InnoDB verwendet **Row-Level-Locking**: Nur die tatsächlich veränderten Datensätze werden gesperrt. Andere Datensätze in derselben Tabelle bleiben für andere Clients zugänglich.

---

### 8. Welches sind Vorteile der InnoDB-Tabellen gegenüber MyISAM-Tabellen?

- **Transaktionsunterstützung**: Änderungen können mit `ROLLBACK` rückgängig gemacht werden (ACID).
- **Referentielle Integrität**: Foreign Keys werden erzwungen – verwaiste Datensätze sind ausgeschlossen.
- **Row-Level-Locking**: Andere Clients werden weniger blockiert als bei Table-Level-Locking.
- **Automatisches Crash-Recovery**: Nach einem Absturz stellt InnoDB den letzten konsistenten Zustand automatisch wieder her.

---

### 9. In welchen Dateien wird die MyISAM-Tabelle KUNDEN gespeichert?

| Datei | Inhalt |
|-------|--------|
| `KUNDEN.FRM` | Tabellenbeschreibung (Struktur, Spaltentypen) |
| `KUNDEN.MYD` | Eigentliche Daten (My**D**ata) |
| `KUNDEN.MYI` | Indexe (My**I**ndex) |

> Alle drei Dateien liegen im Datenbankverzeichnis (z.B. `C:\xampp\mysql\data\datenbankname\`).

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

> Der entscheidende Teil ist `ENGINE = InnoDB` am Ende des `CREATE TABLE`-Befehls.

---

### 11. Welche Locking-Art ist a) bei MyISAM-Tabellen b) bei InnoDB-Tabellen möglich?

**a) MyISAM – Table-Level-Locking**  
Die gesamte Tabelle wird gesperrt. Kein anderer Client kann gleichzeitig lesen oder schreiben (bei WRITE-Lock). Einfach, aber wenig effizient bei vielen gleichzeitigen Zugriffen.

**b) InnoDB – Row-Level-Locking**  
Nur die tatsächlich bearbeiteten Datensätze werden gesperrt. Andere Datensätze in der gleichen Tabelle sind weiterhin zugänglich. Deutlich effizienter im Mehrbenutzerbetrieb.

---

### 12. Beschreiben Sie den Begriff Datenbank-Transaktion!

Eine **Datenbank-Transaktion** ist eine Gruppe von SQL-Anweisungen, die als eine unteilbare Einheit behandelt wird. Sie beginnt mit `BEGIN` und endet entweder mit `COMMIT` (alle Änderungen werden dauerhaft gespeichert) oder `ROLLBACK` (alle Änderungen werden verworfen).

Das Prinzip lautet: **ganz oder gar nicht** – entweder werden alle Operationen vollständig ausgeführt, oder keine. So wird verhindert, dass die Datenbank in einem inkonsistenten Halbzustand bleibt (z.B. wenn Geld abgebucht, aber nicht gutgeschrieben wird).

---

### 13. Beschreiben Sie die Bedeutung von I in der Abkürzung ACID.

**I = Isoliertheit (Isolation)**

Parallele Transaktionen verschiedener Clients dürfen sich **nicht gegenseitig beeinflussen**. Jede Transaktion läuft so ab, als wäre sie die einzige aktive Transaktion im System.

Technisch wird dies durch Sperrmechanismen (Locks), Arbeitskopien und Timestamps sichergestellt: Eine Transaktion kann keine Daten sehen oder verändern, die durch eine andere, noch laufende Transaktion gesperrt sind. Die Sperrungen sollen dabei so kurz und begrenzt wie möglich gehalten werden, um die Performance anderer Operationen nicht unnötig zu beeinträchtigen.

---

### 14. Wie stellen Transaktionen bei einem DB-Server-Crash die Datenkonsistenz sicher?

InnoDB schreibt alle Transaktionsänderungen **zuerst in ein Transaktions-Log** (Redo Log: `ib_logfile0`, `ib_logfile1`), bevor sie in den eigentlichen Tablespace geschrieben werden.

Beim nächsten Start nach einem Absturz führt InnoDB automatisch ein **Crash-Recovery** durch:

1. Das Redo Log wird ausgelesen.
2. Alle Transaktionen, die vor dem Absturz vollständig `COMMIT`et wurden, werden wiederhergestellt.
3. Alle Transaktionen, die beim Absturz noch offen waren (kein `COMMIT`), werden automatisch zurückgerollt (`ROLLBACK`).

Das garantiert, dass die Datenbank nach dem Neustart wieder in einem **konsistenten Zustand** ist.

---

### 15. Mit welcher Locking-Art wartet ein SELECT-Befehl, bis alle Transaktionen auf die angeforderte Tabelle entsperrt sind?

**`SELECT ... LOCK IN SHARE MODE`**

Dieser Befehl wartet, bis alle noch offenen **Exclusive Locks** auf die betroffenen Datensätze aufgelöst sind. Anschliessend legt er selbst einen **Shared Lock** auf die gefundenen Datensätze. Das bedeutet: andere Clients können diese Datensätze ebenfalls lesen (mit Shared Lock), aber nicht mehr verändern.

```sql
BEGIN;
SELECT * FROM tbl_konto WHERE id_k = 1 LOCK IN SHARE MODE;
-- Wartet bis alle Exclusive Locks weg sind, dann Shared Lock
COMMIT;
```

---

### 16. Wie muss Autocommit gesetzt werden, damit jeder SQL-Befehl zu einer Transaktion gehört und explizit mit COMMIT abgeschlossen werden muss?

```sql
SET AUTOCOMMIT = 0;
```

Mit `AUTOCOMMIT = 0` gehört jede SQL-Anweisung automatisch zur laufenden Transaktion. Änderungen werden erst dann dauerhaft gespeichert, wenn man explizit `COMMIT` ausführt. Mit `ROLLBACK` können alle Änderungen seit dem letzten `COMMIT` verworfen werden.

> Bei `AUTOCOMMIT = 1` (Standard) wird jede einzelne Anweisung sofort als eigene Transaktion ausgeführt und committed.
