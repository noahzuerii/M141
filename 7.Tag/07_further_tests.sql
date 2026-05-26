-- =============================================================
-- 07_further_tests.sql  –  Tag 7: Weitere Tests
-- Autor: Noah Bachmann | TBZ M141
-- =============================================================

USE `myTestDb`;

-- =============================================================
-- SCHRITT 13a: Negativ- und Grenztests
-- =============================================================

-- [N01] NOT NULL verletzt → Email NULL einfügen
INSERT INTO Person (Id, Vorname, Nachname, Email, AdresseId)
VALUES (999999, 'Max', 'Muster', NULL, 1);
-- Erwartet: ERROR 1048 – Column 'Email' cannot be null

-- [N02] Boundary Test → PLZ zu lang (VARCHAR(10), Wert hat 11 Zeichen)
INSERT INTO Adresse (Id, Strasse, Hausnummer, PLZ, Stadt, Bundesstaat)
VALUES (999999, 'Teststrasse', '1a', '12345678901', 'Zürich', 'ZH');
-- Erwartet: ERROR 1406 – Data too long for column 'PLZ'

-- [N03] FOREIGN KEY verletzt → Person mit nicht existierender AdresseId
INSERT INTO Person (Id, Vorname, Nachname, Email, AdresseId)
VALUES (999997, 'FK', 'Test', 'fk@test.ch', 9999999);
-- Erwartet: ERROR 1452 – Cannot add or update a child row: a foreign key constraint fails

-- [N04] Primärschlüssel-Duplikat
INSERT INTO Person (Id, Vorname, Nachname, Email, AdresseId)
VALUES (1, 'Duplikat', 'Test', 'dup@test.ch', 1);
-- Erwartet: ERROR 1062 – Duplicate entry '1' for key 'PRIMARY'

-- =============================================================
-- SCHRITT 13b: Transaktionstests (ACID)
-- =============================================================

-- Atomarität testen: ROLLBACK macht Änderung rückgängig
START TRANSACTION;

UPDATE Person SET Nachname = 'Geändert_TRANS' WHERE Id = 1;

-- Innerhalb der Transaktion: Änderung sichtbar
SELECT Id, Vorname, Nachname FROM Person WHERE Id = 1;
-- Erwartet: Nachname = 'Geändert_TRANS'

ROLLBACK;

-- Nach ROLLBACK: Originalwert wieder da
SELECT Id, Vorname, Nachname FROM Person WHERE Id = 1;
-- Erwartet: Originalwert (NICHT 'Geändert_TRANS')

-- Commit-Test: Änderung dauerhaft speichern
START TRANSACTION;
UPDATE Person SET Nachname = 'Geändert_COMMIT' WHERE Id = 2;
COMMIT;

SELECT Id, Vorname, Nachname FROM Person WHERE Id = 2;
-- Erwartet: Nachname = 'Geändert_COMMIT' (dauerhaft gespeichert)

-- Zurücksetzen
UPDATE Person SET Nachname = (SELECT Nachname FROM (SELECT Nachname FROM Person WHERE Id = 2) tmp) WHERE Id = 2;

-- =============================================================
-- SCHRITT 13c: Backup und Restore Test
-- (In PowerShell / CMD ausführen, nicht in SQL)
-- =============================================================

/*
  Backup erstellen (PowerShell):
  cd C:\xampp\mysql\bin
  .\mysqldump.exe -u root -p myTestDb > C:\Temp\myTestDb_backup.sql

  Datenbank "zerstören" (Simulation eines Ausfalls):
  DROP DATABASE myTestDb;

  Restore durchführen (PowerShell):
  .\mysql.exe -u root -p < C:\Temp\myTestDb_backup.sql

  Prüfen ob Restore erfolgreich:
*/
SELECT 'Person'  AS Tabelle, COUNT(*) AS Datensätze FROM Person
UNION ALL
SELECT 'Adresse' AS Tabelle, COUNT(*) AS Datensätze FROM Adresse;
-- Erwartet: wieder je 400'000 Datensätze

-- =============================================================
-- SCHRITT 13d: Nebenläufigkeit und Locking
-- Szenario: Zwei Sessions greifen gleichzeitig auf denselben Datensatz zu
-- =============================================================

-- SESSION 1 (Admin): Transaktion starten, Datensatz sperren
-- Folgende Befehle in Session 1 ausführen:
START TRANSACTION;
UPDATE Person SET Nachname = 'Session1_Lock' WHERE Id = 10;
-- KEIN COMMIT! → Datensatz ist gesperrt

-- SESSION 2 (Contributor): Versucht denselben Datensatz zu ändern
-- Folgende Befehle in Session 2 ausführen:
UPDATE Person SET Nachname = 'Session2_Blocked' WHERE Id = 10;
-- Erwartet: Session 2 wartet/blockiert bis Session 1 COMMIT oder ROLLBACK

-- SESSION 1: Transaktion beenden
COMMIT;
-- Session 2 wird jetzt entsperrt

-- Locking-Status beobachten (während Session 2 wartet):
-- SHOW ENGINE INNODB STATUS\G
-- SELECT * FROM information_schema.INNODB_LOCKS;

-- Aufräumen
UPDATE Person SET Nachname = (SELECT orig FROM (SELECT Nachname AS orig FROM Person WHERE Id = 10) t) WHERE Id = 10;
