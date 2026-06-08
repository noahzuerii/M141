# Tag 5 – Zugriffsberechtigung / Autorisierung

Themen: GRANT, REVOKE, Privilegien, Rollen, Zugriffsmatrix, pma-User

[← Zurück zur Übersicht](../README.md)

---

## 1. Das MySQL-Zugriffssystem

Die zweite Phase der Zugriffskontrolle (die Autorisierung) prüft bei jeder Abfrage, ob der Benutzer die Berechtigung besitzt, die gewünschte Aktion auf dem Zielobjekt auszuführen.

### "WAS" – Die Privilegien

Privilegien werden in administrative Rechte (global) und Datenrechte (lokal) unterteilt.

| Privileg | Ebene | Beschreibung / Technische Auswirkung | Sicherheitsrisiko |
|----------|-------|--------------------------------------|-------------------|
| `SELECT` | Daten | Erlaubt das Lesen von Daten (Tabellen, Views, Spalten). | Gering (sofern keine sensiblen Daten betroffen sind). |
| `INSERT` | Daten | Erlaubt das Einfügen neuer Zeilen. | Mittel. |
| `UPDATE` | Daten | Erlaubt das Ändern bestehender Zeilen. | Mittel. |
| `DELETE` | Daten | Erlaubt das Löschen von Zeilen. | Hoch (Datenverlustrisiko). |
| `FILE` | Global | Erlaubt dem Server, Dateien auf dem Betriebssystem des Servers zu lesen (`LOAD DATA INFILE`) und zu schreiben (`SELECT INTO OUTFILE`). | **Sehr hoch:** Kann zum Auslesen von Systemdateien (z. B. `/etc/passwd` oder Windows-Konfigurationsdateien) genutzt werden. |
| `GRANT OPTION` | Alle | Erlaubt dem Benutzer, seine eigenen Rechte an andere Benutzer weiterzugeben. | **Sehr hoch:** Ermöglicht die Erstellung von administrativen Accounts durch unbefugte Dritte. |
| `ALL PRIVILEGES` | Alle | Erteilt alle verfügbaren Rechte für die gewählte Ebene (ohne `GRANT OPTION`). | Hoch. |
| `USAGE` | Global | Das "Nichts-Recht". Erlaubt lediglich den Verbindungsaufbau zum Server, ohne irgendwelche Berechtigungen auf Tabellendaten zu besitzen. | Keine. |

---

### "WO" – Der Geltungsbereich (Scope)

Berechtigungen werden hierarchisch vergeben. Eine höhere Ebene vererbt ihre Rechte automatisch nach unten.

```
 Hierarchie der Rechteprüfung:
 
 +---------------------------------------------------------------+
 | 1. Globale Ebene (ON *.*)                                     | -> mysql.global_priv (bzw. mysql.user)
 +---------------------------------------------------------------+
   | (Wenn nicht gewährt, nächste Stufe prüfen)
   v
 +---------------------------------------------------------------+
 | 2. Datenbank-Ebene (ON db_name.*)                             | -> mysql.db
 +---------------------------------------------------------------+
   | (Wenn nicht gewährt, nächste Stufe prüfen)
   v
 +---------------------------------------------------------------+
 | 3. Tabellen-Ebene (ON db_name.tabelle)                        | -> mysql.tables_priv
 +---------------------------------------------------------------+
   | (Wenn nicht gewährt, nächste Stufe prüfen)
   v
 +---------------------------------------------------------------+
 | 4. Spalten-Ebene (ON db_name.tabelle(spalte))                  | -> mysql.columns_priv
 +---------------------------------------------------------------+
```

*   **Global (`ON *.*`):** Gilt für alle Datenbanken auf dem Server. Administrative Rechte (wie `SHUTDOWN` oder `SUPER`) können nur hier vergeben werden.
*   **Datenbank (`ON db_name.*`):** Gilt für alle bestehenden und zukünftigen Tabellen und Views innerhalb dieser spezifischen Datenbank.
*   **Tabelle (`ON db_name.tabelle`):** Gilt nur für diese eine Tabelle/View.
*   **Spalte (`GRANT SELECT (Spalte1, Spalte2) ON ...`):** Maximale Feingranularität. Der Benutzer sieht oder ändert nur bestimmte Spalten einer Tabelle.

> [!NOTE]
> **Privilegienspeicherung in MariaDB 10.4+:**
> Die Tabelle `mysql.user` ist in modernen MariaDB-Versionen nur noch eine lesbare View. Die echten Daten werden verschlüsselt und strukturiert als JSON in der Tabelle `mysql.global_priv` abgelegt.

---

## 2. DCL-Syntax: GRANT und REVOKE

Die Vergabe und der Entzug von Rechten erfolgt über die Befehle der **Data Control Language (DCL)**.

### Allgemeine Syntax

```sql
-- RECHTE VERGEBEN
GRANT privileg1 [, privileg2, ...]
  ON geltungsbereich
  TO 'user'@'host'
  [WITH GRANT OPTION];

-- RECHTE ENTZIEHEN
REVOKE privileg1 [, privileg2, ...]
  ON geltungsbereich
  FROM 'user'@'host';
```

### Praktische Beispiele

```sql
-- 1. Administratorrechte vergeben (inkl. Recht zur Weitergabe)
GRANT ALL PRIVILEGES ON *.* TO 'db_admin'@'localhost' WITH GRANT OPTION;

-- 2. Lese- und Schreibrechte auf eine gesamte Datenbank vergeben
GRANT SELECT, INSERT, UPDATE, DELETE ON hotel.* TO 'clerk'@'%';

-- 3. Feingranulare Spaltenberechtigung (z. B. für HR-Mitarbeiter)
-- Erlaubt das Lesen von Name und E-Mail, blockiert aber den Zugriff auf das Gehalt.
GRANT SELECT (nachname, email) ON firma.tbl_mitarbeiter TO 'hr_user'@'localhost';

-- 4. Berechtigungen eines Benutzers überprüfen
SHOW GRANTS FOR 'clerk'@'%';

-- 5. Rechte entziehen
REVOKE INSERT, DELETE ON hotel.* FROM 'clerk'@'%';
```

> [!WARNING]
> **Fehler beim Entziehen von Rechten (Hierarchie-Regel):**
> Rechte können mit `REVOKE` nur auf der Ebene entzogen werden, auf der sie mit `GRANT` vergeben wurden. Wurde ein Recht global (`*.*`) vergeben, kann es nicht auf Datenbankebene (`db.*`) entzogen werden. Der Befehl schlägt in diesem Fall fehl.

---

## 3. Rollen (Roles) ab MariaDB 10.x / MySQL 8.0

Eine **Rolle** ist ein benanntes Bündel von Privilegien. Anstatt jedem Benutzer einzeln Rechte zu vergeben, weist man Benutzern eine Rolle zu. Dies vereinfacht die Berechtigungsverwaltung bei grossen Teams massiv.

```sql
-- 1. Rolle erstellen
CREATE ROLE 'role_developer';

-- 2. Der Rolle Rechte zuweisen
GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP ON firma.* TO 'role_developer';

-- 3. Einem Benutzer die Rolle zuweisen
CREATE USER 'dev_noah'@'localhost' IDENTIFIED BY 'DevPass123!';
GRANT 'role_developer' TO 'dev_noah'@'localhost';

-- 4. WICHTIG: Rolle als Standard festlegen (wird beim Login automatisch aktiv)
SET DEFAULT ROLE 'role_developer' FOR 'dev_noah'@'localhost';
```

> [!IMPORTANT]
> **Rollenaktivierung:**
> Standardmässig besitzt ein Benutzer nach der Zuweisung einer Rolle noch keine Rechte, da die Rolle beim Login inaktiv ist. Er müsste sie manuell über `SET ROLE 'rollenname';` aktivieren. Um dies zu automatisieren, verwenden Sie immer `SET DEFAULT ROLE`.

---

## 4. Praxisbeispiel: Zugriffsmatrix für DB „kunden“

### Zugriffsmatrix (Soll-Zustand)

| Tabelle / Spalte | Rolle: `verkauf` | Rolle: `management` |
|------------------|:----------------:|:------------------:|
| `produkte` | Nur Lesen (`SELECT`) | Vollzugriff (`ALL`) |
| `personal` (Gehaltsdaten) | *Kein Zugriff* | Nur Lesen (`SELECT` auf Gehalt & Name) |
| `rechnungen` | Nur Lesen (`SELECT`) | Vollzugriff (`ALL`) |
| `kunden` | Lesen, Einfügen, Ändern (`SELECT, INSERT, UPDATE`) | Vollzugriff (`ALL`) |

---

### SQL-Umsetzung

```sql
-- 1. Rollen erstellen
CREATE ROLE 'verkauf', 'management';

-- 2. Berechtigungen für Rolle 'verkauf' definieren
GRANT SELECT ON kunden.produkte TO 'verkauf';
GRANT SELECT ON kunden.rechnungen TO 'verkauf';
GRANT SELECT, INSERT, UPDATE ON kunden.kunden TO 'verkauf';

-- 3. Berechtigungen für Rolle 'management' definieren
GRANT ALL PRIVILEGES ON kunden.produkte TO 'management';
GRANT ALL PRIVILEGES ON kunden.rechnungen TO 'management';
GRANT ALL PRIVILEGES ON kunden.kunden TO 'management';
-- Spaltenberechtigung auf Personaldaten
GRANT SELECT (name, lohn) ON kunden.personal TO 'management';

-- 4. Benutzer anlegen und Rollen zuweisen
CREATE USER 'user_sales'@'localhost' IDENTIFIED BY 'SalesPass123!';
CREATE USER 'user_manager'@'localhost' IDENTIFIED BY 'ManagerPass123!';

GRANT 'verkauf' TO 'user_sales'@'localhost';
GRANT 'management' TO 'user_manager'@'localhost';

-- Standardrollen setzen
SET DEFAULT ROLE 'verkauf' FOR 'user_sales'@'localhost';
SET DEFAULT ROLE 'management' FOR 'user_manager'@'localhost';
```

---

## 5. Der phpMyAdmin Control-User (`pma`)

phpMyAdmin benötigt im Hintergrund einen administrativen Systembenutzer (den sogenannten **Control-User**), um erweiterte Funktionen bereitzustellen (z. B. Lesezeichen, SQL-Verlauf, PDF-Schemagenerierung, Tabellenbeziehungen). Dieser User heisst standardmässig `pma`.

```sql
-- Berechtigungen des pma-Users kontrollieren
SHOW GRANTS FOR 'pma'@'localhost';

-- Passwort des pma-Users ändern
ALTER USER 'pma'@'localhost' IDENTIFIED BY 'NeuesPmaPasswort789!';
```

Nach einer Passwortänderung muss die Konfigurationsdatei von phpMyAdmin (`C:\xampp\phpMyAdmin\config.inc.php`) angepasst werden:
```php
$cfg['Servers'][$i]['controluser'] = 'pma';
$cfg['Servers'][$i]['controlpass'] = 'NeuesPmaPasswort789!';
```

---

## 6. Checkpoint-Fragen (Tag 4 / 5)

### 1. Was bedeutet der Begriff "Authentifizierung" im Zusammenhang mit einem DB-Server?
* [ ] Prüfung der Privilegien des Benutzers *(Falsch: Das ist Autorisierung.)*
* [x] Antwort auf die Frage: Wer? *(Richtig: Identitätsnachweis.)*
* [x] Identitätsprüfung *(Richtig.)*
* [ ] Antwort auf die Frage: Was? *(Falsch: Das ist Autorisierung.)*

---

### 2. Wann werden Änderungen im Zugriffssystem von MySQL wirksam?
* [ ] sofort nach Eingabe der Änderung *(Falsch: Stimmt nur für DCL-Befehle.)*
* [x] nach dem Befehl `FLUSH PRIVILEGES` *(Richtig: Zwingend bei direkten DML-Tabellenänderungen.)*
* [x] nach dem Neustart des DB-Servers *(Richtig: Lädt alle Privilegentabellen neu.)*
* [x] nach dem Befehl `GRANT` *(Richtig: DCL-Befehle wirken sofort ohne FLUSH.)*

---

### 3. Was bewirkt der SQL-Befehl `GRANT ... ON ... TO ...;`?
* [x] Privileg(ien) erteilen *(Richtig.)*
* [ ] Privileg(ien) wegnehmen *(Falsch: Dafür wird REVOKE genutzt.)*
* [x] User erstellen, falls noch nicht vorhanden *(Richtig: Gilt für ältere MySQL-Versionen; in modernen Versionen ist dies aus Sicherheitsgründen deaktiviert und wirft einen Fehler.)*
* [ ] User löschen *(Falsch: Dafür wird DROP USER genutzt.)*

---

### 4. Mit welchem Befehl werden Privilegien kontrolliert?
* [ ] `REVOKE ... ON ... FROM;` *(Falsch: Entzieht Rechte.)*
* [ ] `SELECT user, host, password FROM user;` *(Falsch: Zeigt nur Konten, nicht deren Rechte.)*
* [ ] `SHOW TABLES;` *(Falsch: Zeigt nur Tabellennamen.)*
* [x] `SHOW GRANTS FOR ...;` *(Richtig: Listet alle vergebenen Privilegien eines Users auf.)*

---

### 5. Welches sind die beiden wichtigsten DCL-Befehle (Data Control Language)?
* [ ] `SELECT` *(Falsch: DQL.)*
* [x] `REVOKE` *(Richtig: Entzieht Rechte.)*
* [ ] `DELETE` *(Falsch: DML.)*
* [x] `GRANT` *(Richtig: Erteilt Rechte.)*

---

### 6. Was ist nötig, damit Benutzer "meier" keinen Zugang mehr auf den DB-Server hat?
* [ ] in Systemtabelle user für diesen Benutzer jedes Privileg auf "N" setzen *(Falsch: Der Benutzer kann sich weiterhin anmelden und erhält das `USAGE`-Recht.)*
* [x] mit `DELETE FROM user WHERE user = 'meier';` und `FLUSH PRIVILEGES;` *(Richtig: Entfernt das Konto physisch aus der Tabelle. Alternativ und moderner: `DROP USER 'meier'@'localhost';`)*
* [ ] in allen Systemtabellen für diesen Benutzer jedes Privileg auf "N" setzen *(Falsch: Blockiert nicht den Login.)*
* [ ] dem Benutzer das GRANT-Privileg (`Grant_priv`) wegnehmen *(Falsch: Verhindert nur, dass er Rechte weitergibt.)*

---

### 7. Erklären Sie den Begriff "Autorisierung" im Zusammenhang mit einem DB-Server.
Die Autorisierung ist die Prüfung der Berechtigungen eines bereits erfolgreich angemeldeten Benutzers. Sie findet bei jedem abgesetzten SQL-Befehl statt und klärt die Frage: **"Was darf der Benutzer auf welchem Objekt tun?"** (z. B. darf der User Daten aus Tabelle X lesen, aber nicht löschen).

---

### 8. Wann wird das Schlüsselwort `IDENTIFIED BY` verwendet?
Es wird verwendet, um das Passwort eines Benutzers festzulegen. Dies geschieht entweder beim Anlegen eines Kontos (`CREATE USER ... IDENTIFIED BY 'passwort'`) oder beim Ändern des Passworts (`ALTER USER ... IDENTIFIED BY 'passwort'`).

---

### 9. Ergänzen Sie den Befehl `REVOKE ... ON ... FROM ...;` mit eigenen Angaben.
```sql
REVOKE INSERT, DELETE ON firma.tbl_mitarbeiter FROM 'azubi'@'localhost';
```
*(Dieser Befehl entzieht dem Benutzer `azubi` auf `localhost` das Recht, Datensätze in der Tabelle `tbl_mitarbeiter` einzufügen oder zu löschen.)*

---

### 10. Beschreiben Sie den Begriff der MySQL-Testdatenbank.
Die Testdatenbank (meist mit dem Namen `test` angelegt) ist eine standardmässig installierte, leere Datenbank. Sie dient Übungszwecken. Das Sicherheitsrisiko besteht darin, dass in der Standardkonfiguration **jeder** angemeldete Benutzer (auch anonyme Accounts) Vollzugriff auf diese Datenbank besitzt. In Produktionsumgebungen muss sie zwingend gelöscht werden (`DROP DATABASE test;`).

---

### 11. Mit welchem Befehl ändern Sie das Passwort von Benutzer Meier auf "abc123"?
```sql
ALTER USER 'meier'@'localhost' IDENTIFIED BY 'abc123';
```

---

### 12. Geben Sie eine Erklärung für folgende Fehlermeldung:
```sql
GRANT USAGE ON *.* TO abc IDENTIFIED BY 'a12';
ERROR 1045: Access denied for user: '@127.0.0.1'
```
**Ursache:** Der Befehl wurde von einer Sitzung aus gestartet, die keine Berechtigung besitzt, andere Benutzer zu verwalten (z. B. ein anonymer Gastzugang oder ein Standardbenutzer ohne das Recht `GRANT OPTION`). Nur administrative Benutzer wie `root` dürfen neue User anlegen oder berechtigen.

---

### 13. Korrigieren Sie den folgenden Befehl:
```sql
REVOKE ALL FROM ''@localhost;
ERROR 1064: You have an error
```
**Fehler:** Bei `REVOKE ALL` fehlt die Angabe des Geltungsbereichs (`ON`).
**Korrektur:**
```sql
REVOKE ALL PRIVILEGES ON *.* FROM ''@'localhost';
```
*(Entzieht dem anonymen User auf Localhost alle globalen Rechte.)*
