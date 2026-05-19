# M141 – Datenbanksystem in Betrieb nehmen

Lernportfolio von **Noah Bachmann** – TBZ Zürich, 2025/2026

> Installiert und konfiguriert ein Datenbanksystem, führt eine Dateninitialisierung durch, stellt die Funktionalität sicher und führt die Übergabe in den produktiven Betrieb durch.

Offizielles Modul-Repo: [gitlab.com/ch-tbz-it/Stud/m141/m141](https://gitlab.com/ch-tbz-it/Stud/m141/m141)

---

## Lektionenplan

| Tag | Thema | Inhalte | Bewertung |
|:---:|-------|---------|:---------:|
| [1](1.Tag/README.md) | Intro & Installation | Einführung, RDBMS-Übersicht, MariaDB, Workbench, phpMyAdmin, XAMPP | |
| [2](2.Tag/README.md) | Konfiguration & Datenimport | my.ini, Kollation, SQL-Befehlsgruppen, Datenbank „Firma" | |
| 3 | Tabellentypen & Transaktionen | MyISAM, InnoDB, Locking, Transaktionskonzept | |
| 4 | Datenbanksicherheit | Authentifizierung, Netzwerkzugang | |
| 5 | Zugriffssystem | Autorisierung, DCL | **LB1 20%** |
| 6 | Server Administration | Admin-Tools, Logging, Optimierungen | |
| 7 | Testen | Testing, Ablauf & Performance | **LB2 30%** |
| 8 | Praxisarbeit MS A | Lokale DBMS: DDL, DML, DCL | **LB3 50%** |
| 9 | Praxisarbeit MS B | Lokale DBMS testen → Migration auf Cloud-DBMS | |
| 10 | Praxisarbeit MS C/D & Demo | Cloud-DBMS testen, optimieren, Protokollierung, Demo | |

---

## Bewertungen

| | Gewicht | Umfang |
|-|:-------:|--------|
| LB1 | 20 % | Tag 1–4: Zugriffssystem & Authentifizierung |
| LB2 | 30 % | Tag 1–7: Server Administration & Testing |
| LB3 | 50 % | Tag 8–10: Praxisarbeit inkl. Cloud-Migration |

---

## Tools

| Tool | Art | Beschreibung |
|------|-----|-------------|
| XAMPP | Umgebung | Lokale Entwicklungsumgebung mit Apache & MariaDB |
| MySQL Workbench | GUI-Client | Grafischer DB-Client und Admin-Tool |
| phpMyAdmin | Web-Client | Browserbasierter DB-Client (`localhost/phpmyadmin`) |
| mysql | CLI-Client | Kommandozeilen-Client (`mysql -u root -p`) |
| mysqld | Server | MariaDB/MySQL-Serverprozess |
| mysqldump | CLI-Tool | Datenbank-Backup und Export |
