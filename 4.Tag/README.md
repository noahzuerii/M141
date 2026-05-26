# Tag 4 – Datenbank-Sicherheit

Themen: Authentifizierung, User-Verwaltung, Remote-Zugriff, Server absichern

[← Zurück zur Übersicht](../README.md)

---

## 1. Authentifizierung – Grundlagen

MySQL prüft beim Verbindungsaufbau drei Informationen:

| Sicherheitsinformation | Bedeutung | Default |
|------------------------|-----------|---------|
| `Benutzername` | Name für die DB-Anmeldung | leer |
| `Passwort` | Wird als Hash gespeichert | leer |
| `Hostname` | IP/Name des Clients | `%` |

### Hostname-Varianten

| Hostname | Bedeutung |
|----------|-----------|
| `localhost` | User darf nur vom Server-Rechner selbst einloggen |
| `%` | User darf von jedem externen Rechner einloggen (nicht lokal) |
| `172.16.17.111` | User darf nur von dieser IP einloggen |
| `name.local` | User darf nur von diesem Hostnamen einloggen |

### Zwei Phasen der Zugangskontrolle

| Phase | Name | Frage | Quelle |
|-------|------|-------|--------|
| 1 | **Authentifizierung** | Wer darf sich verbinden? | View `mysql.user` / `global_priv` |
| 2 | **Autorisierung** | Was darf der User tun? | Tabellen `db`, `tables_priv`, `columns_priv` |

---

## 2. User-Verwaltung

### User erstellen

```sql
-- Externer User mit Passwort (von überall)
DROP USER IF EXISTS 'user_rem'@'%';
CREATE USER 'user_rem'@'%' IDENTIFIED BY 'Passw0rt';

-- Lokaler User ohne Passwort (nur vom Server selbst)
CREATE USER 'user_local'@'localhost';

-- User nur von einer bestimmten IP
CREATE USER 'user_ip'@'172.16.17.50' IDENTIFIED BY 'Passw0rt';
```

### Passwort setzen / ändern

```sql
-- Mit Klartext-Passwort (nur in sicherer Umgebung!)
SET PASSWORD FOR 'user_rem'@'%' = PASSWORD('NeuesPasswort');

-- Mit Hash (sicherer in Scripts)
SET PASSWORD FOR 'user_rem'@'%' = '*74B1C21ACE0C2D6B0678A5E503D2A60E8F9651A3';

FLUSH PRIVILEGES;   -- immer ausführen!
```

### Passwort-Hash generieren

```sql
SELECT PASSWORD('MeinPasswort');
-- Ergibt z.B.: *A5CEB4E89FB78B...  (41-Byte-Hash mit * am Anfang)
```

### User löschen

```sql
DROP USER 'user_rem'@'%';
FLUSH PRIVILEGES;
```

### User anzeigen

```sql
-- Alle User anzeigen
SELECT User, Host, Password FROM mysql.user;

-- Detailansicht inkl. Plugin
SELECT User, Host, plugin, authentication_string FROM mysql.global_priv;
```

### Localhost-User zu Remote-User machen

```sql
-- Alten User umbenennen (Host ändern)
RENAME USER 'user_local'@'localhost' TO 'user_local'@'%';

-- Oder: neuen User anlegen und alten löschen
CREATE USER 'user_local'@'%' IDENTIFIED BY 'Passw0rt';
DROP USER 'user_local'@'localhost';

FLUSH PRIVILEGES;
```

---

## 3. Remote-Zugriff

### a) Verbindung testen

```cmd
rem Netzverbindung zum Server-Rechner prüfen
ping 172.16.17.4

rem MySQL-Server auf Remote-Host prüfen (ohne Login)
mysqladmin -h 172.16.17.4 ping

rem MySQL-Server auf Remote-Host prüfen (mit User)
mysqladmin -h 172.16.17.4 -u user_rem -p ping
rem → Ausgabe: mysqld is alive
```

### b) Remote-Verbindung aufbauen

```cmd
mysql -h 172.16.17.4 -u user_rem -p
```

```sql
-- Status prüfen (zeigt Current user und Connection)
status;
```

### c) Backup über das Netz

```cmd
mysqldump -h 172.16.17.4 -u user_rem -p firma > C:\temp\backup.sql
```

### d) Restore über das Netz

```cmd
mysql -h 172.16.17.4 -u user_rem -p firma < C:\temp\backup.sql
```

### e) Netzwerkzugriff sperren

In `my.ini` unter `[mysqld]` eintragen:

```ini
[mysqld]
skip-networking
```

Nach Neustart des Servers ist kein TCP/IP-Zugriff mehr möglich (auch lokal nicht).  
Fehlermeldung: `ERROR 2003: Can't connect to MySQL server on '172.16.17.4' (10061)`

---

## 4. Server absichern

### root-Passwort setzen

```sql
-- Als root ohne Passwort einloggen
-- C:\> mysql -u root

SET PASSWORD FOR 'root'@'localhost' = PASSWORD('superpasswort');
FLUSH PRIVILEGES;
```

Ab jetzt: `mysql -u root -p` (Passwort wird abgefragt).

### root-Zugang von extern sperren

```sql
DROP USER 'root'@'%';
-- oder nur Rechte entziehen:
REVOKE ALL PRIVILEGES, GRANT OPTION FROM 'root'@'%';
FLUSH PRIVILEGES;
```

### Lokalen Zugang ohne Passwort erlauben (optional)

```sql
GRANT USAGE ON *.* TO ''@'localhost';
FLUSH PRIVILEGES;
-- USAGE = nur Verbindungsrecht, keine weiteren Rechte
```

### phpMyAdmin-Konfiguration anpassen

Nach Passwort-Änderung des root-Users muss `C:\xampp\phpMyAdmin\config.inc.php` angepasst werden:

```php
$cfg['Servers'][$i]['auth_type'] = 'cookie';   // Login-Dialog
// oder:
$cfg['Servers'][$i]['auth_type'] = 'config';
$cfg['Servers'][$i]['user'] = 'root';
$cfg['Servers'][$i]['password'] = 'superpasswort';
```

---

## 5. Checkpoint-Fragen

### Welche drei Informationen prüft MySQL bei der Authentifizierung?

1. **Benutzername** – Name des DB-Benutzers
2. **Passwort** – wird als Hash verglichen
3. **Hostname** – von welchem Rechner/IP verbindet sich der Client

> Diese Informationen liegen in der View `mysql.user` bzw. `mysql.global_priv`.

---

### Was bedeutet Hostname `%` bei einem MySQL-User?

Der User darf sich von **jedem externen Rechner** aus verbinden – unabhängig von der IP-Adresse. `localhost` ist dabei **nicht** eingeschlossen; für lokalen Zugriff braucht es einen separaten Eintrag mit `'user'@'localhost'`.

---

### Was ist der Unterschied zwischen Authentifizierung und Autorisierung?

| Begriff | Frage | Zeitpunkt |
|---------|-------|-----------|
| **Authentifizierung** | Wer darf sich verbinden? | Beim Verbindungsaufbau (Phase 1) |
| **Autorisierung** | Was darf der verbundene User tun? | Bei jedem SQL-Request (Phase 2) |

---

### Warum muss nach Passwort-Änderungen `FLUSH PRIVILEGES` ausgeführt werden?

`FLUSH PRIVILEGES` lädt die Berechtigungstabellen aus der `mysql`-Datenbank neu in den Arbeitsspeicher. Ohne diesen Befehl werden die Änderungen erst nach einem Server-Neustart wirksam. Bei Verwendung von `GRANT`/`REVOKE` ist `FLUSH PRIVILEGES` **nicht** nötig – nur bei direkten Änderungen an den Systemtabellen.

---

### Wie wird ein Passwort in MySQL gespeichert?

Passwörter werden **nicht im Klartext** gespeichert, sondern als **41-Byte-Hash** (SHA1-basiert). Der Hash beginnt mit einem `*`.

```sql
SELECT PASSWORD('MeinPasswort');
-- Ausgabe: *A4B6157319038724512943...
```

---

### Was bewirkt `skip-networking` in der `my.ini`?

Der MySQL-Server akzeptiert **keine TCP/IP-Verbindungen** mehr – weder von extern noch lokal über TCP. Zugriff ist dann nur noch über Unix-Socket (Linux) oder Named Pipe (Windows) möglich. Sinnvoll, wenn der DB-Server vorübergehend von Netzwerkzugriffen isoliert werden soll (z.B. Wartungsarbeiten, Datenmigration).

---

### Welche Systemtabellen in der `mysql`-Datenbank steuern die Zugriffsrechte?

| Tabelle | Inhalt |
|---------|--------|
| `global_priv` / View `user` | Globale Rechte + Authentifizierungsdaten (User, Host, Passwort) |
| `db` | Datenbankbezogene Rechte |
| `tables_priv` | Tabellenbezogene Rechte |
| `columns_priv` | Spaltenbezogene Rechte |

---

### Wie testet man, ob der MySQL-Server auf einem Remote-Host läuft?

```cmd
mysqladmin -h 172.16.17.4 -u user_rem -p ping
```

Antwort `mysqld is alive` bestätigt, dass der Server erreichbar und aktiv ist.

---

### Welche Massnahmen sichern einen MySQL-Server nach der Installation ab?

1. **root-Passwort setzen** für `localhost`
2. **root-User von `%` entfernen** (kein externer root-Zugriff)
3. **Alle externen User mit Passwort versehen** (kein leeres Passwort)
4. **Anonyme User entfernen** (User ohne Namen)
5. **`skip-networking`** wenn kein Remotezugriff nötig ist
6. **phpMyAdmin absichern** (auth_type auf `cookie` oder `http`)
7. **CIS Benchmarks** als Referenz für weitergehende Härtung nutzen

---

### In welchen Fällen ist das temporäre Sperren des Netzwerkzugriffs sinnvoll?

- **Datenmigration**: Kein Client soll während einer grossen Datenübernahme Daten verändern
- **Wartungsarbeiten**: Schema-Änderungen, Tablespace-Optimierung ohne parallele Zugriffe
- **Sicherheitsvorfälle**: Server isolieren, bis eine Sicherheitslücke behoben ist
- **Backup**: Konsistentes Backup ohne aktive Verbindungen

---

## 6. Checkpoint – DB-Server im LAN

### 1. Welcher Befehl testet die Verbindung zum Server-Rechner mit Adresse 139.79.124.97?

- [ ] `mysql -h 139.79.124.97`
- [ ] `ipconfig`
- [x] `ping 139.79.124.97`
- [x] `mysqladmin -h 139.79.124.97 -u root -p ping`

> `ping` prüft die **Netzwerkverbindung** zum Server-Rechner (Schicht 3). `mysqladmin ... ping` prüft zusätzlich, ob der **MySQL-Dienst** auf diesem Rechner antwortet (`mysqld is alive`). `ipconfig` zeigt die eigene IP-Konfiguration an.

---

### 2. Wozu wird der Parameter `-h` bei MySQL verwendet?

- [ ] bewirkt die Abfrage des Passworts
- [ ] bewirkt die Verbindung als bestimmter Benutzer
- [ ] Angabe der Adresse des Client-Rechners
- [x] Angabe der Adresse des Server-Rechners

> `-h` steht für **host** – die IP-Adresse oder der Hostname des **Server**-Rechners. `-p` fragt das Passwort ab, `-u` gibt den Benutzernamen an.

---

### 3. Was bewirkt der Befehl `mysqldump -h 139.79.124.97 hotel > datei.txt`?

- [ ] Backup der DB hotel in die Datei datei.txt auf Adresse 139.79.124.97
- [x] Backup der angegebenen DB auf dem Server mit der IP-Adresse 139.79.124.97
- [ ] Restore der Datenbank hotel auf dem Server mit der Adresse 139.79.124.97
- [ ] Ausführen des SQL-Skripts datei.txt auf Adresse 139.79.124.97 auf die DB hotel

> `mysqldump` erstellt ein **Backup** (SQL-Dump). `>` leitet die Ausgabe in die lokale Datei `datei.txt` um. `<` wäre Restore (mysql, nicht mysqldump). Die Datei entsteht **lokal** auf dem Client-Rechner.

---

### 4. Welche Aufgabe hat der ODBC-Driver?

- [x] passt die SQL-Befehle dem entsprechenden DB-Server an
- [ ] ermöglicht das Erstellen und Konfigurieren von ODBC-Datenquellen (DSN)
- [x] ermöglicht den einheitlichen Zugriff einer Applikation auf verschiedene Datenbanken
- [ ] ermöglicht den Zugriff einer Applikation auf eine bestimmte DB

> **ODBC** (Open Database Connectivity) ist eine standardisierte Schnittstelle: Eine Applikation spricht immer dasselbe ODBC-API, der passende **Driver** übersetzt diese Anfragen in die datenbankspezifischen Protokolle (MySQL, Oracle, MS SQL etc.). So kann dieselbe Applikation ohne Code-Änderung auf verschiedene Datenbanken zugreifen. Die DSN-Konfiguration übernimmt der ODBC Data Source Administrator (Windows-Tool), nicht der Driver selbst.

---

### 5. Wie greifen Sie vom Konsolenfenster auf einen DB-Server mit Adresse 139.79.124.97 zu?

- [ ] `mysqladmin -h 139.79.124.97`
- [ ] `mysql -h 139.79.124.97 hotel < hotel.bkp`
- [x] `mysql -h 139.79.124.97 -u root -p`
- [ ] `ping 139.79.124.97`

> `mysql -h <IP> -u <user> -p` öffnet eine interaktive MySQL-Konsole auf dem Remote-Server. `< hotel.bkp` wäre ein Restore-Befehl. `ping` testet nur die Netzverbindung.

---

### 6. Welche Aufgaben hat der DB-Server im Gegensatz zum DB-Client?

| DB-Server | DB-Client |
|-----------|-----------|
| Speichert die eigentlichen Daten | Stellt dem Benutzer ein Interface bereit |
| Verarbeitet SQL-Anfragen | Sendet SQL-Befehle an den Server |
| Verwaltet Benutzer und Zugriffsrechte | Empfängt und zeigt die Ergebnisse an |
| Gewährleistet Datenkonsistenz und -integrität | Hat selbst keine Daten |
| Verwaltet Transaktionen und Locks | Kann GUI (phpMyAdmin, Workbench) oder CLI (mysql.exe) sein |
| Führt Backups und Recovery durch | |

---

### 7. Weshalb benutzt man MS Access z.B. zusammen mit einem MySQL-Server?

MS Access bietet eine **benutzerfreundliche Oberfläche** mit Formularen, Berichten, Masken und einem grafischen Abfrage-Designer – ideal für Endbenutzer ohne SQL-Kenntnisse. MySQL als Backend ist dagegen stabiler, für **Mehrbenutzerbetrieb** geeignet und skalierbar.

Die Kombination nutzt die Stärken beider Systeme:
- **Access** = Frontend (Benutzeroberfläche, Reports, Formulare)
- **MySQL** = Backend (Datenspeicherung, Zugriffssteuerung, gleichzeitige Nutzer)

Verbunden werden sie über einen **ODBC-Driver**: Access spricht ODBC, der Treiber übersetzt das für MySQL.

---

### 8. Wie bestimmen Sie die IP-Adresse des Server-Rechners?

```cmd
rem Windows (auf dem Server-Rechner ausführen)
ipconfig

rem Nur IPv4 anzeigen
ipconfig | findstr IPv4
```

Alternativ:
- Netzwerkscanner (z.B. **Advanced IP Scanner**) vom Client aus
- In phpMyAdmin: Status → Server-Variablen → `hostname`
- Im MySQL-Monitor: `SHOW VARIABLES LIKE 'hostname';`

---

### 9. Wie prüfen Sie, ob der DB-Server auf Adresse 139.79.124.97 läuft?

```cmd
mysqladmin -h 139.79.124.97 -u root -p ping
```

**Ausgabe bei Erfolg:**
```
mysqld is alive
```

**Ausgabe bei Fehler (Server nicht erreichbar):**
```
error: 'Can't connect to MySQL server on '139.79.124.97' (10061)'
```

> Zuerst mit `ping 139.79.124.97` prüfen ob der Rechner überhaupt erreichbar ist. Dann mit `mysqladmin ping` prüfen ob MySQL läuft.

---

### 10. Welcher Befehl führt das SQL-Skript `xy.sql` auf die DB `hotel` auf Adresse 139.79.124.97 aus?

```cmd
mysql -h 139.79.124.97 -u root -p hotel < xy.sql
```

> `<` leitet den Inhalt der Datei `xy.sql` als Eingabe an den MySQL-Client weiter – das entspricht dem manuellen Eintippen der Befehle. `hotel` gibt die Zieldatenbank an. Das Gegenteil (`>`) wäre ein Backup mit `mysqldump`.
