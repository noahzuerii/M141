# Tag 1 – Intro & Installation

Themen: Einführung, DB-Engines, XAMPP, Workbench

[← Zurück zur Übersicht](../README.md)

---

Bei den folgenden Fragen treffen eine oder mehrere Antworten zu.

1.  Welches ist die heute am **häufigsten** verwendete Datenbank-Art?

    - [ ] Hierarchische Datenbank

    - [x] Relationale Datenbank

    - [ ] Objektorientierte Datenbank

    - [ ] Netzwerkförmige Datenbank

2.  Welche **Komponenten** sind in einem DB-Server enthalten?

    - [x] 1 oder mehrere Datenbanken

    - [ ] 1 oder mehrere Datenbank-Anwendungen

    - [x] Datenbank-Management-System (DBMS)

    - [ ] Formulare, Reports und Abfragen

3.  Bei welchen der folgenden **Fabrikate** handelt es sich um eine relationale Datenbank?

    - [x] Oracle

    - [ ] Couch-DB

    - [x] MySQL

    - [x] MariaDB

    - [ ] Mongo-DB

    - [x] MS Access

    - [x] PostgreSQL

4.  Welches sind Beispiele für **Aufgaben** eines DB-Clients?

    - [ ] speichert die eigentlichen Daten

    - [x] stellt dem Benutzer ein User-Interface für den Datenzugriff zur Verfügung

    - [ ] verwaltet Benutzer und Passworte und gewährleistet damit die Sicherheit der Datenbank

    - [x] leitet die Befehle des Benutzers an den DB-Server weiter

5.  Welches sind **Client-Komponenten** von MySQL?

    - [ ] mysqld

    - [ ] my.ini

    - [x] mysql

    - [x] phpMyAdmin

6.  Wie heisst die **Server-Komponente** von MySQL?

    - [ ] phpMyAdmin

    - [ ] Workbench

    - [ ] mysql

    - [x] mysqld

7.  Beschreiben Sie den Begriff Client/Server-Modell.

    Das Client/Server-Modell ist eine Netzwerkarchitektur, bei der ein zentraler Server Dienste (z.B. Datenbankzugriff) bereitstellt und ein oder mehrere Clients diese Dienste über ein Netzwerk in Anspruch nehmen. Der Client schickt eine Anfrage an den Server, der Server verarbeitet sie und schickt das Ergebnis zurück. Die Logik ist damit klar aufgeteilt: Datenhaltung und Verarbeitung beim Server, Benutzerinteraktion beim Client.

8.  Welche Vorteile hat die Client/Server-Architektur gegenüber einer Desktop-DB?

    - Mehrere Benutzer können gleichzeitig auf dieselbe Datenbank zugreifen (Mehrbenutzerbetrieb)
    - Zentrale Datenhaltung: Daten sind an einem Ort gespeichert und für alle konsistent
    - Bessere Sicherheit: Zugriffskontrolle erfolgt serverseitig
    - Skalierbarkeit: Server kann aufgerüstet werden, ohne Clients zu verändern
    - Datenintegrität wird zentral durch das DBMS gewährleistet

9.  Wie werden die Daten in einer relationalen Datenbank abgespeichert?

    Daten werden in Tabellen (Relationen) gespeichert. Jede Tabelle besteht aus Zeilen (Tupeln / Datensätzen) und Spalten (Attributen / Feldern). Beziehungen zwischen Tabellen werden über Primärschlüssel (Primary Key) und Fremdschlüssel (Foreign Key) hergestellt.

10.  Was sind die Vorteile, wenn ein DB-Server die **referentielle Datenintegrität** unterstützt?

    - Verwaiste Datensätze (orphan records) werden verhindert: ein Fremdschlüssel kann nur auf einen existierenden Primärschlüssel verweisen
    - Datenkonsistenz wird automatisch vom DBMS sichergestellt, ohne dass die Anwendung dies selbst prüfen muss
    - Löschen oder Ändern referenzierter Datensätze wird kontrolliert (z.B. CASCADE oder RESTRICT)

11.  Welches sind die 4 Gruppen von **NoSQL**-Datenbanken, die zurzeit relevant sind?

    - **Document Stores** (z.B. MongoDB, CouchDB) – Daten als JSON-ähnliche Dokumente
    - **Key-Value Stores** (z.B. Redis, DynamoDB) – einfache Schlüssel-Wert-Paare
    - **Column-Family Stores** (z.B. Apache Cassandra, HBase) – spaltenorientierte Speicherung
    - **Graph-Datenbanken** (z.B. Neo4j) – Daten als Knoten und Kanten eines Graphen

12.  Was bedeutet **DBaaS**? Erklären Sie anhand eines Beispiels.

    DBaaS (Database as a Service) bedeutet, dass eine Datenbank als Cloud-Dienst bereitgestellt wird. Der Anbieter übernimmt Betrieb, Updates, Backups und Skalierung; der Nutzer greift einfach über eine Verbindungszeichenfolge zu, ohne eigene Hardware zu betreiben. Beispiel: **Amazon RDS** – AWS stellt eine verwaltete MySQL-Instanz bereit, kümmert sich um Patches und Hochverfügbarkeit, und der Entwickler verbindet sich wie gewohnt mit einem SQL-Client.

13.  Was sind die Vorteile eines RDBMS gegenüber anderen DB-Modellen?

    - Standardisierte Abfragesprache SQL – portabel und weit verbreitet
    - ACID-Eigenschaften (Atomicity, Consistency, Isolation, Durability) garantieren zuverlässige Transaktionen
    - Flexible Abfragen durch JOINs über mehrere Tabellen
    - Referentielle Integrität sichert konsistente Datenbeziehungen
    - Grosse Community, umfangreiche Dokumentation und Tool-Unterstützung

14.  DB-Server starten und stoppen

    Stoppen und starten Sie Ihren DB-Server auf die verschiedenen Arten. Kontrollieren Sie jeweils das Resultat mit dem Task-Manager:

    - **XAMPP Control-Panel**: Über die Schaltflächen «Start» / «Stop» neben «MySQL» im XAMPP Control-Panel kann der Server gestartet bzw. gestoppt werden. Im Task-Manager erscheint / verschwindet dabei der Prozess `mysqld.exe`.
    - **Konsole (CMD / PowerShell)**:
      ```
      net start mysql      # Starten
      net stop mysql       # Stoppen
      ```
    - **MySQL Workbench**: Im Home-Tab unter «Server» → «Startup / Shutdown» (nur wenn MySQL als Windows-Dienst läuft).

15.  DB-Server prüfen

    - **Task-Manager**: Unter «Details» den Prozess `mysqld.exe` suchen – wenn er läuft, ist der Server aktiv.
    - **Dienst-Manager (services.msc)**: Den Dienst «MySQL» suchen; Status muss «Wird ausgeführt» (Running) zeigen.
    - **mysql-Client (Kommandozeile)**:
      ```
      mysql -u root -p
      ```
      Erfolgreiche Verbindung bestätigt, dass der Server läuft.
    - **MySQL Workbench**: Verbindung unter «MySQL Connections» öffnen; bei Erfolg erscheint das SQL-Editor-Fenster.
    - **phpMyAdmin**: Im Browser `http://localhost/phpmyadmin` aufrufen; wird die Oberfläche angezeigt, ist der Server erreichbar.
