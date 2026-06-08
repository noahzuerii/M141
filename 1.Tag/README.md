# Tag 1 – Intro & Installation

Themen: Einführung, DB-Engines, XAMPP, Workbench

[← Zurück zur Übersicht](../README.md)

---

## 1. Theoretische Grundlagen (Fragen & Antworten)

Bei den folgenden Lernkontrollfragen treffen eine oder mehrere Antworten zu. Alle Antworten sind mit fundierten technischen Erklärungen versehen.

### 1. Welches ist die heute am häufigsten verwendete Datenbank-Art?

* [ ] Hierarchische Datenbank
* [x] Relationale Datenbank
* [ ] Objektorientierte Datenbank
* [ ] Netzwerkförmige Datenbank

> **Erklärung:**
> Relationale Datenbanksysteme (RDBMS) sind seit Jahrzehnten der absolute Industriestandard für strukturierte Datenhaltung. Sie basieren auf dem mathematischen Konzept der Relationenalgebren von Edgar F. Codd. Moderne Enterprise-Systeme nutzen relationale Datenbanken wegen ihrer hohen Konsistenzgarantien (ACID) und der standardisierten Abfragesprache SQL.
> * *Hierarchisch und netzwerkförmig:* Stammen aus den 1960/70er Jahren (IMS/CODASYL) und gelten heute als veraltet (ausser in Legacy-Mainframe-Umgebungen).
> * *Objektorientiert (OODBMS):* Hatte in den 1990ern einen Hype, konnte sich aber wegen mangelnder Performance und fehlendem Standardzugriff nie im Massenmarkt durchsetzen. Heute werden stattdessen meist OR-Mapper (Object-Relational Mapping) verwendet.

---

### 2. Welche Komponenten sind in einem DB-Server enthalten?

* [x] 1 oder mehrere Datenbanken
* [ ] 1 oder mehrere Datenbank-Anwendungen
* [x] Datenbank-Management-System (DBMS)
* [ ] Formulare, Reports und Abfragen

> **Erklärung:**
> Ein Datenbank-Server (die physische oder virtuelle Instanz) beherbergt das **DBMS** (die Software-Engine, z. B. `mysqld.exe`) und die eigentlichen physischen **Datenbanken** (Dateien auf dem Datenträger).
> * *Datenbank-Anwendungen* (wie Webshops, ERP-Systeme) und *Formulare/Reports* sind externe **Clients**, die über das Netzwerk auf den Server zugreifen. Sie laufen in der Regel auf separaten Systemen und gehören nicht zur Kernstruktur des DB-Servers.

---

### 3. Bei welchen der folgenden Fabrikate handelt es sich um eine relationale Datenbank?

* [x] Oracle Database
* [ ] CouchDB
* [x] MySQL
* [x] MariaDB
* [ ] MongoDB
* [x] MS Access
* [x] PostgreSQL

> **Erklärung:**
> * **Relational (SQL):** Oracle, MySQL, MariaDB, PostgreSQL und MS Access (Desktop-RDBMS) speichern Daten in zweidimensionalen Tabellen mit Zeilen und Spalten und erzwingen Beziehungen über Fremdschlüssel.
> * **Nicht-Relational (NoSQL):** MongoDB und CouchDB sind dokumentenorientierte Datenbanken. Sie speichern Daten schemalos in BSON- bzw. JSON-Dokumenten und gehören zur Klasse der NoSQL-Systeme.

---

### 4. Welches sind Beispiele für Aufgaben eines DB-Clients?

* [ ] speichert die eigentlichen Daten
* [x] stellt dem Benutzer ein User-Interface für den Datenzugriff zur Verfügung
* [ ] verwaltet Benutzer und Passworte und gewährleistet damit die Sicherheit der Datenbank
* [x] leitet die Befehle des Benutzers an den DB-Server weiter

> **Erklärung:**
> Der Client ist das Werkzeug für den menschlichen Anwender oder das Anwendungsprogramm. Seine Hauptaufgaben sind das **Bereitstellen des User-Interfaces** (z. B. eine CLI-Eingabeaufforderung oder eine grafische Oberfläche wie Workbench) und das **Senden der SQL-Befehle** über das Netzwerk an den Server.
> * *Datenspeicherung* und *Benutzerverwaltung (Sicherheit)* sind Kernaufgaben des **DB-Servers** (DBMS) – der Client hat selbst keine Datenhoheit und delegiert diese administrativen und logischen Aufgaben vollständig an den Server.

---

### 5. Welches sind Client-Komponenten von MySQL?

* [ ] `mysqld`
* [ ] `my.ini`
* [x] `mysql`
* [x] `phpMyAdmin`

> **Erklärung:**
> * **`mysql` (bzw. `mysql.exe` unter Windows):** Der offizielle Befehlszeilen-Client von MySQL/MariaDB.
> * **`phpMyAdmin`:** Ein browserbasierter, grafischer Web-Client, der im Hintergrund über PHP-SQL-Schnittstellen Befehle an den Server sendet.
> * *`mysqld` (MySQL Daemon):* Der eigentliche Server-Hintergrundprozess.
> * *`my.ini`:* Die Konfigurationsdatei des Servers (kein ausführbares Client-Programm).

---

### 6. Wie heisst die Server-Komponente von MySQL?

* [ ] phpMyAdmin
* [ ] Workbench
* [ ] mysql
* [x] `mysqld`

> **Erklärung:**
> Das Suffix **d** steht für **Daemon** (Hintergrunddienst unter Unix/Linux, unter Windows als Systemdienst implementiert). `mysqld` ist das eigentliche Triebwerk der Datenbank. Alle anderen Optionen (`mysql`, phpMyAdmin, Workbench) sind Werkzeuge der Client-Schicht, die mit dem Daemon kommunizieren.

---

### 7. Beschreiben Sie den Begriff Client/Server-Modell.

Das Client/Server-Modell ist eine Netzwerkarchitektur, die Aufgaben und Ressourcen zwischen Service-Anbietern (Server) und Service-Nachfragern (Client) aufteilt.

```
+------------------+                    +--------------------+
|  Client (DQL)    |---(Port 3306 TCP)-->| Server (mysqld)    |
|  (mysql/pma/App) |<---(Result Set)-----| (Data & Engines)   |
+------------------+                    +--------------------+
```

*   **Der Server** läuft kontinuierlich als Hintergrundprozess (`mysqld`). Er wartet auf eingehende Verbindungen, verwaltet die Datenkonsistenz, führt Abfragen aus, sichert Transaktionen und verwaltet die Zugriffsrechte.
*   **Der Client** (z. B. `mysql.exe`, phpMyAdmin oder eine Applikation) baut bei Bedarf eine Netzwerkverbindung zum Server auf (standardmässig über TCP-Port 3306), sendet SQL-Statements und nimmt das strukturierte Ergebnis (Result Set) entgegen, um es dem Benutzer anzuzeigen.

---

### 8. Welche Vorteile hat die Client/Server-Architektur gegenüber einer Desktop-DB?

| Kriterium | Desktop-Datenbank (z. B. reines MS Access / SQLite) | Client/Server-Datenbank (z. B. MariaDB / PostgreSQL) |
|-----------|----------------------------------------------------|----------------------------------------------------|
| **Datenhaltung** | Lokal auf der Client-Maschine oder einer einfachen Dateifreigabe. | Zentral auf einem dedizierten Server. |
| **Mehrbenutzer** | Schlecht skalierbar. Gleichzeitige Schreibzugriffe führen oft zu Dateikorruption. | Hervorragend. Das DBMS steuert Nebenläufigkeit über Sperren (Locks). |
| **Sicherheit** | Dateibasiert. Jeder Benutzer benötigt direkten Lese-/Schreibzugriff auf die DB-Datei. | Verbindungsorientiert. Berechtigungen werden feingranular im DBMS geprüft. |
| **Performance** | Der Client muss zur Filterung oft die gesamte DB-Datei über das Netz laden. | Der Server filtert die Daten und sendet nur das Endergebnis über das Netz. |
| **Ausfallsicherheit** | Absturz des Clients während des Schreibens beschädigt oft die ganze DB. | ACID-Garantien und Transaktionslogs verhindern Datenverlust bei Abstürzen. |

---

### 9. Wie werden die Daten in einer relationalen Datenbank abgespeichert?

In einem RDBMS werden Daten in zweidimensionalen Tabellen (formaler Begriff: **Relationen**) organisiert.
*   Jede Zeile (Datensatz, Tupel) repräsentiert eine konkrete Instanz eines Objekts.
*   Jede Spalte (Attribut, Feld) beschreibt eine Eigenschaft dieses Objekts und besitzt einen festen Datentyp (z. B. `INT`, `VARCHAR`, `DATE`).
*   Beziehungen zwischen Tabellen werden physisch durch die Verknüpfung von **Primärschlüsseln** (Primary Key, eindeutiger Identifikator einer Zeile) und **Fremdschlüsseln** (Foreign Key, Spalte, die auf den Primärschlüssel einer anderen Tabelle verweist) realisiert.

---

### 10. Was sind die Vorteile, wenn ein DB-Server die referentielle Datenintegrität unterstützt?

Die referentielle Integrität stellt sicher, dass Beziehungen zwischen Tabellen logisch konsistent bleiben. Das DBMS überwacht diese Regeln streng:
*   **Keine verwaisten Datensätze (Orphan Records):** Ein Fremdschlüssel darf niemals auf einen Primärschlüssel verweisen, der nicht existiert.
*   **Automatisierte Kaskadierung:** Wird ein Datensatz gelöscht, kann das DBMS verknüpfte Datensätze automatisch mitlöschen (`ON DELETE CASCADE`) oder das Löschen verweigern (`ON DELETE RESTRICT`), um Fehler zu vermeiden.
*   **Zentralisierung der Logik:** Die Validierung findet direkt im DB-Server statt. Software-Entwickler müssen diese Prüfungen nicht mühsam in jeder einzelnen Applikation programmieren.

---

### 11. Welches sind die 4 Gruppen von NoSQL-Datenbanken, die zurzeit relevant sind?

NoSQL-Datenbanken ("Not Only SQL") wurden entwickelt, um grosse Mengen unstrukturierter Daten zu speichern und hohe Schreiblasten horizontal zu skalieren.

1.  **Dokumentenorientierte Datenbanken (Document Stores):** Speichern Daten in halbstrukturierten Dokumenten (JSON/BSON). Jedes Dokument kann ein anderes Schema besitzen.
    *   *Beispiele:* MongoDB, CouchDB.
2.  **Schlüssel-Wert-Datenbanken (Key-Value Stores):** Extrem schnelle, einfache Zuordnung von Schlüsseln zu Werten. Oft im Arbeitsspeicher betrieben.
    *   *Beispiele:* Redis, Memcached.
3.  **Spaltenorientierte Datenbanken (Wide Column Stores / Column-Family):** Speichern Daten spalten- statt zeilenweise ab. Perfekt für riesige Datenmengen und analytische Abfragen.
    *   *Beispiele:* Apache Cassandra, HBase.
4.  **Graphdatenbanken (Graph Databases):** Speichern Daten als Knoten und Kanten (Beziehungen). Ideal für soziale Netzwerke, Empfehlungsdienste und Routenplaner.
    *   *Beispiele:* Neo4j, ArangoDB.

---

### 12. Was bedeutet DBaaS? Erklären Sie anhand eines Beispiels.

**DBaaS** steht für **Database as a Service** und ist ein Cloud-Computing-Modell, bei dem der Cloud-Anbieter eine vollständig verwaltete Datenbank zur Verfügung stellt.
*   **Vorteile:** Der Anwender muss keine Hardware beschaffen, kein Betriebssystem installieren und sich nicht um Patches, Backups, Skalierung oder Hochverfügbarkeit kümmern.
*   **Beispiel Amazon RDS (Relational Database Service):** AWS stellt eine lauffähige MariaDB- oder PostgreSQL-Instanz bereit. Der Entwickler erhält eine Verbindungsadresse (Endpoint) und kann direkt SQL-Befehle ausführen, während AWS die Wartung und Datensicherung im Hintergrund automatisiert.

---

### 13. Was sind die Vorteile eines RDBMS gegenüber anderen DB-Modellen?

*   **ACID-Garantien:** Garantiert absolute Datenkonsistenz und Fehlersicherheit selbst bei Systemabstürzen.
*   **Deklarative Abfragesprache (SQL):** Der Benutzer beschreibt *was* er haben möchte, das DBMS entscheidet über den optimalen Weg (*wie*), was Abfragen hochgradig optimiert und portabel macht.
*   **Referentielle Integrität:** Systemseitig erzwungene Konsistenzregeln verhindern logische Datenfehler.
*   **Reife und Ökosystem:** RDBMS sind seit über 40 Jahren erprobt, besitzen exzellente Admin-Tools, Konnektoren für alle Programmiersprachen und eine riesige Entwicklergemeinde.

---

## 2. Praxis: DB-Server administrieren

### 14. DB-Server starten und stoppen

Um den MariaDB/MySQL-Server unter Windows zu steuern, gibt es drei gebräuchliche Wege:

#### Methode A: XAMPP Control-Panel (Grafisch)
1. Starten Sie das XAMPP Control-Panel als Administrator.
2. Klicken Sie neben dem Modul "MySQL" auf **Start** bzw. **Stop**.
3. *Ergebnisprüfung:* Bei erfolgreichem Start wechselt die Hintergrundfarbe von MySQL auf Grün, und die zugewiesenen Ports (z. B. `3306`) sowie die Prozess-IDs (PIDs) werden angezeigt. Im Windows Task-Manager taucht der Prozess `mysqld.exe` auf.

#### Methode B: Windows Command Line (CMD / PowerShell)
Wenn der MySQL-Server als Windows-Systemdienst registriert ist, kann er über administrative Befehle gesteuert werden.
*   **Dienst starten:**
    ```cmd
    net start mysql
    ```
*   **Dienst stoppen:**
    ```cmd
    net stop mysql
    ```

> [!TIP]
> **PowerShell-Alternative:**
> Unter Windows PowerShell können Sie die Befehle `Start-Service -Name mysql` und `Stop-Service -Name mysql` nutzen.

#### Methode C: MySQL Workbench (Administrationstools)
1. Starten Sie MySQL Workbench und öffnen Sie die Serververbindung.
2. Klicken Sie im linken Menübereich unter "Management" auf **Instance** → **Startup / Shutdown**.
3. Hier sehen Sie den aktuellen Server-Status und können ihn über Schaltflächen stoppen oder starten.

---

### 15. DB-Serverlaufzeit und Erreichbarkeit prüfen

Bevor Sie mit einer Datenbank arbeiten, verifizieren Sie den Status über folgende Werkzeuge:

#### 1. Windows Task-Manager
*   Öffnen Sie den Task-Manager (`Strg` + `Umschalt` + `Esc`).
*   Navigieren Sie zum Reiter **Details** und suchen Sie nach dem Prozess `mysqld.exe`.
*   Ein aktiver Prozess bestätigt, dass der Server-Prozess im Speicher geladen ist.

#### 2. Windows Dienst-Manager (`services.msc`)
*   Drücken Sie `Win` + `R`, geben Sie `services.msc` ein und drücken Sie Enter.
*   Suchen Sie nach dem Dienst **MySQL** oder **MariaDB**.
*   Der Status muss auf "Wird ausgeführt" (Running) und der Starttyp auf "Automatisch" stehen.

#### 3. Kommandozeile (CLI)
Bauen Sie eine interaktive Verbindung auf. Wenn das Login gelingt, läuft der Server:
```cmd
mysql -u root -p
```
Geben Sie nach dem erfolgreichen Login den Befehl `status;` ein, um Details zur Version und der Laufzeit (Uptime) des Servers zu erhalten.

#### 4. Web-Client (phpMyAdmin)
*   Öffnen Sie einen Browser und rufen Sie `http://localhost/phpmyadmin/` auf.
*   Wird das Dashboard geladen, läuft sowohl der Apache-Webserver als auch der MariaDB-Datenbankdienst fehlerfrei.
