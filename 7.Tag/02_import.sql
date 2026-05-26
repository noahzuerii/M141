-- =============================================================
-- 02_import.sql  –  Tag 7: Bulk-Import (400'000 Datensätze)
-- Autor: Noah Bachmann | TBZ M141
-- VORAUSSETZUNG: CSV-Dateien in das secure_file_priv-Verzeichnis kopieren
--   Verzeichnis prüfen: SHOW VARIABLES LIKE 'secure_file_priv';
--   Standard XAMPP: C:\xampp\mysql\data\ oder leer (= alle Verzeichnisse erlaubt)
-- =============================================================

USE `myTestDb`;

-- Prüfen, wo LOAD DATA INFILE Dateien lesen darf
SHOW VARIABLES LIKE 'secure_file_priv';

-- =============================================================
-- SCHRITT 4a: person.csv importieren
-- CSV muss im secure_file_priv-Verzeichnis liegen
-- Alternativpfade:
--   'C:/xampp/mysql/data/person.csv'
--   'C:/ProgramData/MySQL/MySQL Server X.Y/Uploads/person.csv'
-- =============================================================

LOAD DATA INFILE 'C:/xampp/mysql/data/person.csv'
INTO TABLE Person
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS;

-- =============================================================
-- SCHRITT 4b: adresse.csv importieren
-- =============================================================

LOAD DATA INFILE 'C:/xampp/mysql/data/adresse.csv'
INTO TABLE Adresse
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS;

-- =============================================================
-- Import prüfen: Anzahl Datensätze
-- =============================================================

SELECT 'Person'  AS Tabelle, COUNT(*) AS Datensätze FROM Person
UNION ALL
SELECT 'Adresse' AS Tabelle, COUNT(*) AS Datensätze FROM Adresse;
-- Erwartet: je 400'000 Datensätze

-- Stichprobe anschauen
SELECT * FROM Person  LIMIT 5;
SELECT * FROM Adresse LIMIT 5;
