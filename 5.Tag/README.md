# Tag 5 – Zugriffsberechtigung / Autorisierung

Themen: GRANT, REVOKE, Privilegien, Rollen, Zugriffsmatrix, pma-User

[← Zurück zur Übersicht](../README.md)

---

## 1. Das MySQL-Zugriffssystem

### "WAS" – Privilegien

| Privileg | Beschreibung |
|----------|-------------|
| `SELECT` | Daten lesen |
| `INSERT` | Neue Datensätze einfügen |
| `UPDATE` | Bestehende Daten ändern |
| `DELETE` | Datensätze löschen |
| `FILE` | Datei-Operationen auf dem Server (`LOAD DATA INFILE`) – globales Recht |
| `GRANT OPTION` | Eigene Rechte an andere Benutzer weitergeben |
| `ALL PRIVILEGES` | Alle verfügbaren Rechte für die gewählte Ebene (ohne `GRANT OPTION`) |
| `USAGE` | Nur Verbindungsrecht – keine Datenrechte |

### "WO" – Geltungsbereich

| Ebene | Syntax | Beschreibung |
|-------|--------|-------------|
| Global | `ON *.*` | Ganzer Server – alle Datenbanken und Tabellen |
| Datenbank | `ON mydb.*` | Eine Datenbank und alle ihre Tabellen |
| Tabelle | `ON mydb.tabelle` | Nur eine einzelne Tabelle |
| Spalte | `(att1, att2) ON db.tb` | Nur bestimmte Spalten einer Tabelle |
| Stored Routine | `ON PROCEDURE ...` | Eine gespeicherte Prozedur oder Funktion |

### Wo werden Privilegien gespeichert?

| Tabelle in `mysql` | Ebene | Inhalt |
|--------------------|-------|--------|
| `mysql.global_priv` | Global (`*.*`) | Benutzerkonten, Passwörter, globale Rechte (als JSON) |
| `mysql.db` | Datenbank (`db.*`) | Rechte für eine bestimmte Datenbank |
| `mysql.tables_priv` | Tabelle (`db.tabelle`) | Rechte für einzelne Tabellen |
| `mysql.columns_priv` | Spalte (`db.tabelle.spalte`) | Rechte für einzelne Spalten |
| `mysql.procs_priv` | Prozeduren/Funktionen | Rechte für Stored Procedures |

> `mysql.user` ist seit MariaDB 10.4 nur noch eine **View** auf `mysql.global_priv`. Die Rohdaten liegen in `global_priv` als JSON.

---

## 2. GRANT und REVOKE

### Allgemeine Syntax

```sql
GRANT privileg1 [, privileg2, ...]
  ON [datenbank.]tabelle
  TO user@host [IDENTIFIED BY 'passwort'] [WITH GRANT OPTION];

REVOKE privileg1 [, privileg2, ...]
  ON [datenbank.]tabelle
  FROM user@host;
```

### Beispiele

```sql
-- Alle Rechte auf eine DB (inkl. Weitergabe)
GRANT ALL ON hotel.* TO 'hotel_admin'@'localhost' WITH GRANT OPTION;

-- Lesen und Ändern auf eine DB
GRANT SELECT, INSERT, UPDATE, DELETE ON hotel.* TO 'hotel_user'@'localhost';

-- Datei-Operationen (global)
GRANT FILE ON *.* TO 'import_user'@'%';

-- Nur eine Spalte lesen
GRANT SELECT (name, email) ON firma.tbl_mitarbeiter TO 'hr_user'@'localhost';

-- Rechte entziehen
REVOKE INSERT, DELETE ON hotel.* FROM 'hotel_user'@'localhost';

-- Rechte eines Users anzeigen
SHOW GRANTS FOR 'hotel_admin'@'localhost';

-- Aktivierung (nach direkten Änderungen an Systemtabellen)
FLUSH PRIVILEGES;
```

---

## 3. Rollen (Roles)

Rollen bündeln Privilegien und können mehreren Benutzern zugewiesen werden (ab MariaDB 10.x).

```sql
-- Rolle erstellen und Rechte zuweisen
CREATE ROLE verkauf;
GRANT SELECT ON kunden.produkte TO verkauf;
GRANT SELECT, INSERT, UPDATE ON kunden.kunden TO verkauf;

-- User erstellen und Rolle zuweisen
CREATE USER 'frau_muster'@'localhost' IDENTIFIED BY 'Passw0rt';
GRANT verkauf TO 'frau_muster'@'localhost';

FLUSH PRIVILEGES;

-- User muss Rolle aktivieren (oder Default-Rolle setzen)
SET ROLE verkauf;
SET DEFAULT ROLE verkauf;   -- automatisch beim Login aktiv

-- Aktive Rollen anzeigen
SELECT CURRENT_ROLE;
```

---

## 4. Zugriffsmatrix umsetzen (DB kunden)

### Matrix

| Tabelle / Attribut | Verkauf – S | I | U | D | Management – S | I | U | D |
|--------------------|:-----------:|:-:|:-:|:-:|:--------------:|:-:|:-:|:-:|
| produkte | x | | | | x | x | x | x |
| personal | – | | | | | | | |
| **–** lohn | | | | | x | – | x | – |
| **–** restl. Attribute | | | | | x | – | x | – |
| rechnungen | x | | | | x | x | x | x |
| kunden | x | x | x | | x | x | x | x |

*S=SELECT, I=INSERT, U=UPDATE, D=DELETE, –=nicht möglich*

### SQL-Umsetzung

```sql
-- Rollen erstellen
CREATE ROLE verkauf, management;

-- Rechte für Rolle 'verkauf'
GRANT SELECT ON kunden.produkte   TO verkauf;
GRANT SELECT ON kunden.rechnungen TO verkauf;
GRANT SELECT, INSERT, UPDATE ON kunden.kunden TO verkauf;

-- Rechte für Rolle 'management'
GRANT SELECT, INSERT, UPDATE, DELETE ON kunden.produkte   TO management;
GRANT SELECT, INSERT, UPDATE, DELETE ON kunden.rechnungen TO management;
GRANT SELECT, INSERT, UPDATE, DELETE ON kunden.kunden     TO management;
-- Nur bestimmte Spalten der Tabelle personal
GRANT SELECT (lohn, vorname, nachname, abteilung), UPDATE (lohn) ON kunden.personal TO management;

-- User erstellen und Rollen zuweisen
CREATE USER 'user_verkauf'@'localhost' IDENTIFIED BY 'Passw0rt';
CREATE USER 'user_management'@'localhost' IDENTIFIED BY 'Passw0rt';

GRANT verkauf    TO 'user_verkauf'@'localhost';
GRANT management TO 'user_management'@'localhost';

FLUSH PRIVILEGES;

-- Login und Rolle aktivieren
-- mysql -u user_verkauf -p kunden
-- SET ROLE verkauf;

-- Kontrolle
SHOW GRANTS FOR 'user_verkauf'@'localhost';
SHOW GRANTS FOR 'user_management'@'localhost';
```

### Aufräumen

```sql
REVOKE verkauf    FROM 'user_verkauf'@'localhost';
REVOKE management FROM 'user_management'@'localhost';
DROP USER 'user_verkauf'@'localhost', 'user_management'@'localhost';
DROP ROLE verkauf, management;
FLUSH PRIVILEGES;
```

---

## 5. pma-User für phpMyAdmin

```sql
-- Rechte des pma-Users anzeigen
SHOW GRANTS FOR 'pma'@'localhost';

-- Passwort setzen
SET PASSWORD FOR 'pma'@'localhost' = PASSWORD('irgendwas');
FLUSH PRIVILEGES;
```

In `C:\xampp\phpMyAdmin\config.inc.php`:
```php
$cfg['Servers'][$i]['controluser'] = 'pma';
$cfg['Servers'][$i]['controlpass'] = 'irgendwas';
```

Server manuell herunterfahren (wenn XAMPP-Control-Panel nicht mehr funktioniert):
```cmd
C:\xampp\mysql\bin\mysqladmin --user=pma --password=irgendwas shutdown
```

---

## 6. Checkpoint-Fragen

### Was ist der Unterschied zwischen Authentifizierung und Autorisierung?

| Begriff | Frage | Zeitpunkt |
|---------|-------|-----------|
| **Authentifizierung** | Wer darf sich verbinden? (Benutzername, Passwort, Host) | Verbindungsaufbau – Phase 1 |
| **Autorisierung** | Was darf der eingeloggte User tun? (Privilegien) | Bei jedem SQL-Befehl – Phase 2 |

---

### Welche vier Grundprivilegien gibt es für Datenmanipulation?

- `SELECT` – lesen
- `INSERT` – einfügen
- `UPDATE` – ändern
- `DELETE` – löschen

---

### Was bedeutet `ALL PRIVILEGES` und was ist ausgenommen?

`ALL PRIVILEGES` erteilt alle verfügbaren Rechte für die gewählte Ebene. **Nicht** enthalten ist `GRANT OPTION` – dieses muss separat mit `WITH GRANT OPTION` vergeben werden.

---

### Was ist der Unterschied zwischen globalem und lokalem Geltungsbereich?

| Bereich | Syntax | Inhalt |
|---------|--------|--------|
| Global | `ON *.*` | Gilt für alle Datenbanken und alle Tabellen des Servers. Hier liegen auch Admin-Rechte wie `SHUTDOWN`. |
| Lokal | `ON db.*` oder `ON db.tabelle` | Gilt nur für eine bestimmte Datenbank oder Tabelle. |

---

### Was ist `USAGE` und wofür wird es eingesetzt?

`USAGE` ist das "Nichts-Privileg": Es erlaubt dem Benutzer nur, sich einzuloggen (Connect), gibt ihm aber keinerlei Rechte auf Daten. Wird eingesetzt, um einen User anzulegen, ohne ihm sofort Datenrechte zu geben, oder um Attribute wie SSL zu setzen.

```sql
GRANT USAGE ON *.* TO 'readonly_user'@'localhost';
```

---

### Wie erteilt man einem User `SELECT`-Recht auf alle Tabellen der Datenbank `hotel`?

```sql
GRANT SELECT ON hotel.* TO 'hotel_user'@'localhost';
```

---

### Wie entzieht man einem User das `DELETE`-Recht auf die Datenbank `hotel`?

```sql
REVOKE DELETE ON hotel.* FROM 'hotel_user'@'localhost';
```

> Mit `REVOKE` kann der Zugriff nur auf DB-Ebene oder höher entzogen werden – nicht auf einzelne Tabellen verboten, wenn Rechte auf DB-Ebene vergeben wurden.

---

### Wie prüft man die Zugriffsrechte eines Benutzers?

```sql
SHOW GRANTS FOR 'hotel_admin'@'localhost';
```

---

### Was sind Rollen (Roles) und welchen Vorteil bieten sie?

Eine **Rolle** ist ein benanntes Bündel von Privilegien. Anstatt jedem User einzeln Rechte zu vergeben, weist man eine Rolle zu:

- **Vorteil**: Rechte zentral verwalten – ändert man eine Rolle, ändert sich das Recht für alle User mit dieser Rolle
- **Vorteil**: Übersichtliche Zugriffsmatrix umsetzbar (z.B. `verkauf`, `management`)
- **Achtung**: Rollen müssen nach dem Login aktiviert werden: `SET ROLE rollenname;` (oder als Default: `SET DEFAULT ROLE rollenname;`)

---

### In welchen Systemtabellen speichert MariaDB die Privilegien?

| Tabelle | Ebene |
|---------|-------|
| `mysql.global_priv` | Global – alle Datenbankrechte, Passwörter (JSON-Format) |
| `mysql.db` | Datenbankebene |
| `mysql.tables_priv` | Tabellenebene |
| `mysql.columns_priv` | Spaltenebene |
| `mysql.procs_priv` | Prozeduren/Funktionen |

> `mysql.user` ist seit MariaDB 10.4 nur noch eine View auf `mysql.global_priv`.

---

### Was ist der pma-User und warum darf er nicht gelöscht werden?

Der `pma`-User ist der **Control-User von phpMyAdmin**. Er verwaltet interne phpMyAdmin-Funktionen (z.B. gespeicherte Abfragen, Lesezeichen) in der Datenbank `phpmyadmin`. Wird er gelöscht, ist phpMyAdmin nicht mehr nutzbar. Das Passwort muss sowohl in der MySQL-Usertabelle als auch in `config.inc.php` übereinstimmen.

---

### Warum sind Rechte in MySQL nicht hierarchisch aufgebaut?

Jede Ebene (Global, Datenbank, Tabelle, Spalte) ist **unabhängig** voneinander. Das bedeutet:
- Ein User kann Rechte auf eine einzelne Tabelle haben, ohne Rechte auf die Datenbank zu haben
- Eine Tabelle kann freigegeben sein, die übergeordnete Datenbank ist aber nicht sichtbar
- Dies erlaubt sehr fein granulierte Zugriffssteuerung

---

### Vollständige Strategie zur Rechtevergabe

```sql
-- 1. Admin-Account (global)
GRANT ALL PRIVILEGES ON *.* TO 'admin'@'localhost' WITH GRANT OPTION;

-- 2. Rolle definieren
CREATE ROLE leser;
GRANT SELECT ON firma.* TO leser;

-- 3. User erstellen und Rolle zuweisen
CREATE USER 'hans'@'localhost' IDENTIFIED BY 'Passw0rt';
GRANT leser TO 'hans'@'localhost';
SET DEFAULT ROLE leser FOR 'hans'@'localhost';

-- 4. Aktivieren
FLUSH PRIVILEGES;

-- 5. Kontrolle
SHOW GRANTS FOR 'hans'@'localhost';
```

---

## 7. Checkpoint 4./5. Tag – Datenbank-Sicherheit

### 1. Was bedeutet der Begriff "Authentifizierung" im Zusammenhang mit einem DB-Server?

- [ ] Prüfung der Privilegien des Benutzers
- [x] Antwort auf die Frage: Wer?
- [x] Identitätsprüfung
- [ ] Antwort auf die Frage: Was?

> **Authentifizierung** = Phase 1 beim Verbindungsaufbau: Der Server prüft Benutzername, Passwort und Hostname – also *wer* sich verbinden will. Die Prüfung der Privilegien ("Was darf er?") ist **Autorisierung** (Phase 2).

---

### 2. Wann werden Änderungen im Zugriffssystem von MySQL wirksam?

- [ ] sofort nach Eingabe der Änderung
- [x] nach dem Befehl `FLUSH PRIVILEGES`
- [x] nach dem Neustart des DB-Servers
- [x] nach dem Befehl `GRANT`

> `GRANT` und `REVOKE` wirken **sofort**. Direkte Änderungen an Systemtabellen (`UPDATE mysql.user ...`) werden erst nach `FLUSH PRIVILEGES` oder nach einem Server-Neustart aktiv.

---

### 3. Was bewirkt der SQL-Befehl `GRANT ... ON ... TO ...;`?

- [x] Privileg(ien) erteilen
- [ ] Privileg(ien) wegnehmen
- [x] User erstellen, falls noch nicht vorhanden
- [ ] User löschen

> `GRANT` erteilt Rechte. In älteren MySQL-Versionen legt `GRANT ... IDENTIFIED BY 'pw'` den User automatisch an, wenn er noch nicht existiert. Das Gegenteil von `GRANT` ist `REVOKE`.

---

### 4. Mit welchem Befehl werden Privilegien kontrolliert?

- [ ] `REVOKE ... ON ... FROM;`
- [ ] `SELECT user, host, password FROM user;`
- [ ] `SHOW TABLES;`
- [x] `SHOW GRANTS FOR ...;`

> ```sql
> SHOW GRANTS FOR 'hotel_admin'@'localhost';
> ```
> Zeigt alle Privilegien eines bestimmten Benutzers übersichtlich an.

---

### 5. Welches sind die beiden wichtigsten DCL-Befehle (Data Control Language)?

- [ ] SELECT
- [x] REVOKE
- [ ] DELETE
- [x] GRANT

> **DCL** (Data Control Language) steuert Zugriffsrechte. Die zwei zentralen Befehle sind `GRANT` (Rechte erteilen) und `REVOKE` (Rechte entziehen). `SELECT` ist DQL, `DELETE` ist DML.

---

### 6. Was ist nötig, damit Benutzer "meier" keinen Zugang mehr auf den DB-Server hat?

- [ ] in Systemtabelle user für diesen Benutzer jedes Privileg auf "N" setzen
- [x] mit `DELETE FROM user WHERE user = 'meier';` und `FLUSH PRIVILEGES;`
- [ ] in allen Systemtabellen für diesen Benutzer jedes Privileg auf "N" setzen
- [ ] dem Benutzer das GRANT-Privileg (`Grant_priv`) wegnehmen

> Nur das Entfernen des Eintrags aus der `user`-Tabelle verhindert das Einloggen vollständig. Alle Privilegien auf "N" setzen lässt den User weiterhin verbinden (er erhält dann `USAGE`). Das GRANT-Privileg zu entziehen ändert nichts an der Login-Möglichkeit. Bevorzugter Befehl in der Praxis: `DROP USER 'meier'@'localhost';`

---

### 7. Erklären Sie den Begriff "Autorisierung" im Zusammenhang mit einem DB-Server.

**Autorisierung** ist die zweite Phase der Zugangskontrolle. Nachdem der Benutzer erfolgreich authentifiziert wurde (Phase 1), prüft der Server bei **jedem einzelnen SQL-Befehl**, ob der Benutzer das erforderliche Privileg für diese Aktion besitzt.

- Beantwortet die Frage: **Was darf der Benutzer tun?**
- Grundlage sind die Privilegientabellen: `mysql.global_priv`, `mysql.db`, `mysql.tables_priv`, `mysql.columns_priv`
- Fehlt das Privileg, bricht der Befehl mit einer Fehlermeldung ab: `ERROR 1142: SELECT command denied to user`

---

### 8. Wann wird das Schlüsselwort `IDENTIFIED BY` verwendet?

`IDENTIFIED BY` wird eingesetzt, um beim Erstellen oder Berechtigen eines Users gleichzeitig sein **Passwort** festzulegen:

```sql
-- Beim Erstellen
CREATE USER 'meier'@'localhost' IDENTIFIED BY 'Passw0rt';

-- Beim GRANT (ältere MySQL-Syntax – erstellt User, falls nicht vorhanden)
GRANT SELECT ON hotel.* TO 'meier'@'localhost' IDENTIFIED BY 'Passw0rt';
```

Das Passwort wird intern als Hash gespeichert. Im Klartext erscheint es nur in diesem Befehl.

---

### 9. Ergänzen Sie den Befehl `REVOKE ... ON ... FROM ...;` mit eigenen Angaben.

```sql
REVOKE SELECT, INSERT ON hotel.* FROM 'hotel_user'@'localhost';
```

> Entzieht dem User `hotel_user` auf `localhost` die Rechte `SELECT` und `INSERT` auf alle Tabellen der Datenbank `hotel`. Die übrigen Rechte (z.B. `UPDATE`) bleiben bestehen.

---

### 10. Beschreiben Sie den Begriff der MySQL-Testdatenbank.

Die **Testdatenbank** (`test`) ist eine leere Datenbank, die bei der Standard-Installation von MySQL/MariaDB automatisch angelegt wird. Standardmässig hat **jeder Benutzer** – auch solche ohne explizite Rechte – vollständigen Zugriff auf diese Datenbank.

In einer **Produktionsumgebung** stellt sie ein Sicherheitsrisiko dar und sollte gelöscht werden:

```sql
DROP DATABASE test;
```

---

### 11. Mit welchem Befehl ändern Sie das Passwort von Benutzer Meier auf "abc123"?

```sql
SET PASSWORD FOR 'meier'@'localhost' = PASSWORD('abc123');
FLUSH PRIVILEGES;
```

> Das Passwort wird als Hash gespeichert. `FLUSH PRIVILEGES` stellt sicher, dass die Änderung sofort wirksam ist.

---

### 12. Geben Sie eine Erklärung für folgende Fehlermeldung.

```sql
GRANT USAGE ON *.* TO abc IDENTIFIED BY 'a12';
ERROR 1045: Access denied for user: '@127.0.0.1'
```

**Ursache**: Der aktuell eingeloggte Benutzer ist ein **anonymer User** (`''@'127.0.0.1'`) ohne `GRANT`-Privileg. Nur Benutzer mit dem `GRANT OPTION`-Recht (z.B. `root`) dürfen `GRANT`-Befehle ausführen.

**Lösung**: Als privilegierter Benutzer einloggen und den Befehl wiederholen:

```cmd
mysql -u root -p
```
```sql
GRANT USAGE ON *.* TO 'abc'@'%' IDENTIFIED BY 'a12';
```

---

### 13. Korrigieren Sie den folgenden Befehl.

```sql
REVOKE ALL FROM ''@localhost;
ERROR 1064: You have an error
```

**Fehler**: Der `ON`-Teil fehlt. `REVOKE` benötigt zwingend die Angabe, *von wo* die Rechte entzogen werden sollen.

**Korrektur**:

```sql
REVOKE ALL ON *.* FROM ''@'localhost';
```

> `ON *.*` bedeutet: globale Rechte entziehen. Ohne `ON ...` ist die Syntax ungültig.
