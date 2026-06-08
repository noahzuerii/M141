# Tag 7 – Datenbank mit Testdaten testen

Themen: User, Rollen, Bulk-Import, Datenintegrität, Performance-Tests, Benchmark

[← Zurück zur Übersicht](../README.md)

---

## Dateien in diesem Ordner

| Datei | Inhalt / Beschreibung |
|-------|-----------------------|
| [01_setup.sql](01_setup.sql) | Erstellt die Benutzer, das Testschema `myTestDb` und die Tabellenstrukturen. |
| [02_import.sql](02_import.sql) | Importiert 400'000 Datensätze hocheffizient per `LOAD DATA INFILE`. |
| [03_permissions.sql](03_permissions.sql) | Konfiguriert Rollen und weist sie den Test-Usern zu. |
| [04_test_permissions.sql](04_test_permissions.sql) | Testskripte zur Verifizierung der Lese- und Schreibrechte. |
| [05_data_integrity.sql](05_data_integrity.sql) | Identifiziert Duplikate und erzwingt Constraints (PK, FK, CHECK). |
| [06_performance.sql](06_performance.sql) | Vergleicht Abfragezeiten vor und nach der Indexierung mittels `EXPLAIN`. |
| [07_further_tests.sql](07_further_tests.sql) | Führt Negativ-, Transaktions-, Backup- und Locking-Tests durch. |
| [08_benchmark.ps1](08_benchmark.ps1) | PowerShell-Skript zur automatisierten Ausführung von Lasttests mit `mysqlslap`. |

---

## 1. Initialer Verbindungsversuch

Wenn versucht wird, eine Verbindung mit neuen Testbenutzern aufzubauen, bevor diese im DBMS existieren, bricht der Client ab:
```
ERROR 1045 (28000): Access denied for user 'Reader'@'localhost' (using password: YES)
```
*Ursache:* Nach einer Neuinstallation besitzt MariaDB nur den administrativen Benutzer `root`. Jedes andere Benutzerkonto muss explizit angelegt werden.

---

## 2. Test-User anlegen und absichern

Wir erstellen zwei Benutzer: Einen Nur-Lese-User (`Reader`) und einen Schreib-User (`Contributor`).

```sql
-- Erstellen der Accounts
CREATE USER 'Reader'@'%'         IDENTIFIED BY '123!';
CREATE USER 'Reader'@'localhost' IDENTIFIED BY '123!';
CREATE USER 'Contributor'@'%'         IDENTIFIED BY '123!';
CREATE USER 'Contributor'@'localhost' IDENTIFIED BY '123!';
```

> [!WARNING]
> **Sicherheitsrisiko in XAMPP-Standardinstallationen:**
> Manche MySQL/MariaDB-Installationen legen bei der Standardkonfiguration automatisch Konten ohne Passwort für `localhost` an, wenn man Wildcard-Benutzer erstellt. Überprüfen Sie dies mit `SELECT User, Host, Password FROM mysql.user;` und löschen Sie passwortlose Dummy-Accounts umgehend.

---

## 3. Schema & Tabellen erstellen

Für den Testlauf werden die Tabellen bewusst **ohne Primärschlüssel und Fremdschlüssel** angelegt. Dies simuliert eine unoptimierte "Rohdaten-Tabelle", an der wir Performance-Probleme und Datenkonsistenzfehler aufzeigen.

```sql
CREATE DATABASE myTestDb;
USE myTestDb;

CREATE TABLE Person (
    Id INT, 
    Vorname VARCHAR(255), 
    Nachname VARCHAR(255),
    Email VARCHAR(255), 
    AdresseId INT
);

CREATE TABLE Adresse (
    Id INT, 
    Strasse VARCHAR(255), 
    Hausnummer VARCHAR(10),
    PLZ VARCHAR(10), 
    Stadt VARCHAR(255), 
    Bundesstaat VARCHAR(10)
);
```

---

## 4. Bulk-Import (400'000 Datensätze)

Der Import von grossen CSV-Dateien erfolgt über `LOAD DATA INFILE`.

### Bulk-Import-Performance tunen:
Ein Import von 400k Zeilen kann Minuten dauern, wenn das DBMS bei jeder Zeile Indizes und Schlüssel prüft. Mit folgendem Muster wird der Import extrem beschleunigt:

```sql
-- 1. Integritätsprüfungen und Autocommit temporär abschalten
SET UNIQUE_CHECKS = 0;
SET FOREIGN_KEY_CHECKS = 0;
SET AUTOCOMMIT = 0;

-- 2. Daten laden (direkter Dateizugriff auf dem Server)
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

-- 3. Transaktion abschliessen und Prüfungen wieder aktivieren
COMMIT;
SET UNIQUE_CHECKS = 1;
SET FOREIGN_KEY_CHECKS = 1;
```
*(Das DBMS baut nun die internen Indizes gesammelt am Ende auf, was die Importzeit von Minuten auf wenige Sekunden senkt.)*

---

## 5. Berechtigungen & Rollen konfigurieren

Wir setzen die Berechtigungen über Rollen gemäss der folgenden Zugriffsmatrix um:

| Tabelle | Reader: `SELECT` | Reader: `DML` | Contributor: `SELECT` | Contributor: `DML` | Contributor: `DDL/DCL` |
|---------|:----------------:|:-------------:|:---------------------:|:------------------:|:----------------------:|
| `Person` | **Erlaubt** | Verboten | **Erlaubt** | **Erlaubt** | Verboten |
| `Adresse` | **Erlaubt** | Verboten | **Erlaubt** | **Erlaubt** | Verboten |

### SQL-Umsetzung:
```sql
-- Rollen anlegen
CREATE ROLE 'RoleReader';
CREATE ROLE 'RoleContributor';

-- Rechte zuweisen
GRANT SELECT                         ON myTestDb.* TO 'RoleReader';
GRANT SELECT, INSERT, UPDATE, DELETE ON myTestDb.* TO 'RoleContributor';

-- Rollen den Benutzern zuweisen
GRANT 'RoleReader'      TO 'Reader'@'localhost';
GRANT 'RoleContributor' TO 'Contributor'@'localhost';

-- Default-Aktivierung erzwingen
SET DEFAULT ROLE 'RoleReader'      FOR 'Reader'@'localhost';
SET DEFAULT ROLE 'RoleContributor' FOR 'Contributor'@'localhost';

FLUSH PRIVILEGES;
```

---

## 6. Datenintegrität analysieren und erzwingen

OpenData-Importe enthalten oft Duplikate oder logische Fehler. Wir bereinigen die Rohdaten und setzen danach harte Constraints.

### Duplikate identifizieren
```sql
-- Findet Adress-IDs, die mehrfach vergeben wurden
SELECT Id, COUNT(*) FROM Adresse GROUP BY Id HAVING COUNT(Id) > 1;
```

### Daten bereinigen (Deduplizierung)

#### Methode A: Temporäre Tabelle (Standard-SQL)
Wir filtern alle eindeutigen Adressen in eine temporäre Tabelle, bereinigen die Fremdschlüssel in der Tabelle `Person` und löschen die Duplikate aus der Haupttabelle `Adresse`.
```sql
-- Eindeutige Adressen sichern
CREATE TEMPORARY TABLE temp_Adresse AS
    SELECT MIN(Id) AS Id, Strasse, Hausnummer, PLZ, Stadt, Bundesstaat
    FROM Adresse GROUP BY Strasse, Hausnummer, PLZ, Stadt, Bundesstaat;

-- Fremdschlüssel in Person anpassen
UPDATE Person SET AdresseId = (
    SELECT t.Id FROM temp_Adresse t
    INNER JOIN Adresse a ON a.Id = Person.AdresseId
    WHERE t.Strasse = a.Strasse AND t.PLZ = a.PLZ LIMIT 1
) WHERE AdresseId NOT IN (SELECT Id FROM temp_Adresse);

-- Redundante Zeilen löschen
DELETE FROM Adresse WHERE Id NOT IN (SELECT Id FROM temp_Adresse);
```

#### Methode B: Window-Funktionen (Modern ab MariaDB 10.2+)
```sql
-- Direkte Identifikation über Row-Numbers
WITH cte AS (
    SELECT Id, ROW_NUMBER() OVER (PARTITION BY Strasse, Hausnummer, PLZ ORDER BY Id) as row_num
    FROM Adresse
)
DELETE FROM Adresse WHERE Id IN (SELECT Id FROM cte WHERE row_num > 1);
```

### Constraints nachträglich setzen
```sql
-- Primärschlüssel vergeben
ALTER TABLE Adresse ADD PRIMARY KEY (Id);
ALTER TABLE Person  ADD PRIMARY KEY (Id);

-- Fremdschlüssel-Beziehung (Foreign Key) verknüpfen
ALTER TABLE Person ADD CONSTRAINT fk_pers_adr 
    FOREIGN KEY (AdresseId) REFERENCES Adresse(Id);

-- CHECK-Constraint für E-Mail-Format hinzufügen
ALTER TABLE Person ADD CONSTRAINT chk_email 
    CHECK (Email LIKE '%@%.%');
```

---

## 7. Performance-Tests mit Index-Optimierung

Wir führen eine Joinsuche über 400k Datensätze durch:
```sql
SELECT * FROM Person p
INNER JOIN Adresse a ON a.Id = p.AdresseId
WHERE p.Id = 2569;
```

### Szenario 1: Ohne Index (Ausgangslage)
Da weder Primärschlüssel noch Indizes auf den Fremdschlüsseln liegen, muss der Server beide Tabellen komplett von Anfang bis Ende durchsuchen.
*   **EXPLAIN `type`:** `ALL` / `ALL` (Full Table Scan)
*   **Auszuwertende Zeilen (`rows`):** $400'000 \times 400'000 = 160'000'000'000$ potenzielle Zeilenvergleiche.
*   **Ausführungszeit:** **~400 ms**

### Szenario 2: Index auf Person (`Id`)
*   **EXPLAIN `type`:** `const` / `ALL`
*   **Ausführungszeit:** **~50 ms**
*(Die Person wird sofort gefunden, das Joinen der Adresse erfordert jedoch weiterhin einen Full Table Scan.)*

### Szenario 3: Indizes auf beiden Tabellen (PKs & FKs aktiv)
*   **EXPLAIN `type`:** `const` / `eq_ref` (Nutzt die Indexbäume beider Tabellen)
*   **Auszuwertende Zeilen (`rows`):** $1 \times 1 = 1$ Zeile.
*   **Ausführungszeit:** **~2 ms**

### Ergebnis im Vergleich
Durch das korrekte Setzen von Indizes wurde die Abfragegeschwindigkeit um den **Faktor 200x** gesteigert!

```
 Abfragezeit bei 400'000 Datensätzen:
 
 Ohne Index:       [========================================] 400ms
 Mit einem Index:  [====] 50ms
 Mit beiden:       [] 2ms
```

---

## 8. Lasttests und Benchmarking mit `mysqlslap`

`mysqlslap` ist ein standardisiertes Benchmark-Tool, das im Lieferumfang von MySQL/MariaDB enthalten ist. Es simuliert den Zugriff vieler gleichzeitiger Benutzer auf die Datenbank.

### Benchmark-Befehl ausführen (PowerShell):
```powershell
# Simuliert 30 Benutzer, die zeitgleich insgesamt 3000 Abfragen absetzen
.\mysqlslap.exe --user=root --password --concurrency=30 --iterations=5 `
    --number-of-queries=3000 `
    --query="SELECT * FROM Person p INNER JOIN Adresse a ON a.Id = p.AdresseId WHERE p.Id = 2500;" `
    --create-schema=myTestDb
```

### Der Einfluss von Server-Tuning:

Wir vergleichen die standardmässige XAMPP-Einstellung mit einer für Produktion optimierten Konfiguration in der `my.ini`:

| Konfiguration | `innodb_buffer_pool_size` | Durchschnittliche Laufzeit | Erklärung |
|---------------|---------------------------|----------------------------|-----------|
| **Standard (XAMPP)** | `8M` | ~4.850 s | Der Puffer ist zu klein, um die Tabellendaten im RAM zu halten. Der Server muss permanent langsame Lesezugriffe auf der Festplatte (Disk-I/O) ausführen. |
| **Optimiert** | `512M` | **~0.920 s** | Die gesamten 400k Datensätze und Indizes liegen komplett im RAM-Cache. Leseoperationen erfolgen nahezu verzögerungsfrei im Arbeitsspeicher. |

#### Optimierungsparameter in `my.ini` unter `[mysqld]`:
```ini
[mysqld]
# Reserviert 512 MB RAM für InnoDB-Daten und Indizes (Wichtigster Parameter!)
innodb_buffer_pool_size = 512M

# Grösse der Logdateien für Schreibvorgänge erhöhen
innodb_log_file_size = 128M

# Maximale gleichzeitige Verbindungen begrenzen
max_connections = 100
```
*(Nach dem Eintragen ist ein Server-Neustart erforderlich.)*
