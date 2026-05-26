-- =============================================================
-- 03_backpacker_import.sql
-- Datenbank: backpacker_noah_lb3
-- Autor: Noah Bachmann | TBZ M141 LB3
-- =============================================================
-- Beschreibung:
--   A) LOAD DATA INFILE – Import der gegebenen CSV-Dateien
--   B) Bereinigung: FK-Konsistenz, Duplikate, NULL-Werte,
--      Charset (latin1 → utf8mb4), Password-Hashing
--   C) Testdaten (falls CSV leer oder als Ergänzung)
-- =============================================================
-- Voraussetzungen:
--   - FILE-Recht: GRANT FILE ON *.* TO 'root'@'localhost';
--   - CSV-Dateien entpackt nach:
--     C:\xampp\mysql\data\backpacker_noah_lb3\csv\
--   - my.ini: local_infile = 1
--   - Verbindung mit: mysql --local-infile=1 -u root -p
-- =============================================================

USE backpacker_noah_lb3;

SET FOREIGN_KEY_CHECKS = 0;
SET NAMES utf8mb4;

-- =============================================================
-- A) IMPORT DER CSV-DATEIEN
-- =============================================================

-- ---- tbl_land -----------------------------------------------
LOAD DATA LOCAL INFILE 'C:/xampp/mysql/data/backpacker_noah_lb3/csv/tbl_land.csv'
INTO TABLE tbl_land
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ';' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(Land_ID, Land);

-- ---- tbl_leistung -------------------------------------------
LOAD DATA LOCAL INFILE 'C:/xampp/mysql/data/backpacker_noah_lb3/csv/tbl_leistung.csv'
INTO TABLE tbl_leistung
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ';' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(LeistungID, Beschreibung);

-- ---- tbl_personen -------------------------------------------
LOAD DATA LOCAL INFILE 'C:/xampp/mysql/data/backpacker_noah_lb3/csv/tbl_personen.csv'
INTO TABLE tbl_personen
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ';' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(Personen_ID, Titel, Vorname, Name, Strasse, PLZ, Ort, Anrede, Telefon, erfasst, Sprache);

-- ---- tbl_benutzer -------------------------------------------
LOAD DATA LOCAL INFILE 'C:/xampp/mysql/data/backpacker_noah_lb3/csv/tbl_benutzer.csv'
INTO TABLE tbl_benutzer
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ';' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(Benutzer_ID, Benutzername, Password, Vorname, Name, Benutzergruppe, erfasst, deaktiviert, aktiv);

-- ---- tbl_buchung --------------------------------------------
LOAD DATA LOCAL INFILE 'C:/xampp/mysql/data/backpacker_noah_lb3/csv/tbl_buchung.csv'
INTO TABLE tbl_buchung
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ';' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(Buchungs_ID, Personen_FS, Ankunft, Abreise, Land_FS);

-- ---- tbl_positionen -----------------------------------------
LOAD DATA LOCAL INFILE 'C:/xampp/mysql/data/backpacker_noah_lb3/csv/tbl_positionen.csv'
INTO TABLE tbl_positionen
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ';' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(Positions_ID, Buchungs_FS, Konto, Anzahl, Preis, Rabatt, Benutzer_FS, erfasst, Leistung_Text, Leistung_FS);

SET FOREIGN_KEY_CHECKS = 1;

-- =============================================================
-- B) BEREINIGUNG
-- =============================================================

-- B1: tbl_buchung.Personen_FS → Waisen (Person nicht vorhanden)
SELECT b.Buchungs_ID, b.Personen_FS
FROM tbl_buchung b
LEFT JOIN tbl_personen p ON b.Personen_FS = p.Personen_ID
WHERE b.Personen_FS IS NOT NULL AND p.Personen_ID IS NULL;
-- Behebung: auf NULL setzen
UPDATE tbl_buchung b
LEFT JOIN tbl_personen p ON b.Personen_FS = p.Personen_ID
SET b.Personen_FS = NULL
WHERE b.Personen_FS IS NOT NULL AND p.Personen_ID IS NULL;

-- B2: tbl_buchung.Land_FS → Waisen (Land nicht vorhanden)
SELECT b.Buchungs_ID, b.Land_FS
FROM tbl_buchung b
LEFT JOIN tbl_land l ON b.Land_FS = l.Land_ID
WHERE b.Land_FS IS NOT NULL AND l.Land_ID IS NULL;
UPDATE tbl_buchung b
LEFT JOIN tbl_land l ON b.Land_FS = l.Land_ID
SET b.Land_FS = NULL
WHERE b.Land_FS IS NOT NULL AND l.Land_ID IS NULL;

-- B3: tbl_positionen.Buchungs_FS → Waisen
SELECT pos.Positions_ID, pos.Buchungs_FS
FROM tbl_positionen pos
LEFT JOIN tbl_buchung b ON pos.Buchungs_FS = b.Buchungs_ID
WHERE pos.Buchungs_FS IS NOT NULL AND b.Buchungs_ID IS NULL;

-- B4: tbl_positionen.Benutzer_FS → Waisen
SELECT pos.Positions_ID, pos.Benutzer_FS
FROM tbl_positionen pos
LEFT JOIN tbl_benutzer be ON pos.Benutzer_FS = be.Benutzer_ID
WHERE pos.Benutzer_FS != 0 AND be.Benutzer_ID IS NULL;

-- B5: tbl_positionen.Leistung_FS → Waisen (Leistung_FS kann NULL sein)
SELECT pos.Positions_ID, pos.Leistung_FS
FROM tbl_positionen pos
LEFT JOIN tbl_leistung l ON pos.Leistung_FS = l.LeistungID
WHERE pos.Leistung_FS IS NOT NULL AND l.LeistungID IS NULL;
UPDATE tbl_positionen pos
LEFT JOIN tbl_leistung l ON pos.Leistung_FS = l.LeistungID
SET pos.Leistung_FS = NULL
WHERE pos.Leistung_FS IS NOT NULL AND l.LeistungID IS NULL;

-- B6: Duplikate in tbl_benutzer.Benutzername
SELECT Benutzername, COUNT(*) AS Anzahl
FROM tbl_benutzer GROUP BY Benutzername HAVING Anzahl > 1;

-- B7: Password-Hashing
--   Originalpasswörter sind vermutlich Klartext (aus Access-Migration)
--   → SHA-256-Hash setzen wenn Password-Länge < 64 Zeichen
SELECT COUNT(*) AS Klartextpasswoerter
FROM tbl_benutzer WHERE LENGTH(Password) < 64 OR Password IS NULL;

UPDATE tbl_benutzer
SET Password = SHA2(Password, 256)
WHERE LENGTH(Password) < 64 AND Password IS NOT NULL AND Password != '';

-- B8: Negative Preise
SELECT COUNT(*) AS Neg_Preise FROM tbl_positionen WHERE Preis < 0;

-- B9: Negative Anzahl
SELECT COUNT(*) AS Neg_Anzahl FROM tbl_positionen WHERE Anzahl < 0;

-- B10: Rabatt ausserhalb 0–100%
SELECT COUNT(*) AS Ungueltig_Rabatt
FROM tbl_positionen WHERE Rabatt < 0 OR Rabatt > 100;

-- =============================================================
-- C) TESTDATEN (falls CSV leer – Mindestdaten für Migration)
-- =============================================================

INSERT IGNORE INTO tbl_land (Land_ID, Land) VALUES
(1,  'Schweiz'),
(2,  'Deutschland'),
(3,  'Österreich'),
(4,  'Frankreich'),
(5,  'Grossbritannien'),
(6,  'USA'),
(7,  'Australien'),
(8,  'Kanada'),
(9,  'Japan'),
(10, 'Spanien');

INSERT IGNORE INTO tbl_leistung (LeistungID, Beschreibung) VALUES
(1, 'Bett Schlafsaal 6er'),
(2, 'Bett Schlafsaal 4er'),
(3, 'Einzelzimmer'),
(4, 'Doppelzimmer'),
(5, 'Frühstück'),
(6, 'Handtuch-Miete'),
(7, 'Schliessfach'),
(8, 'Fahrrad-Miete');

INSERT IGNORE INTO tbl_personen
    (Personen_ID, Titel, Vorname, Name, Strasse, PLZ, Ort, Anrede, Telefon, erfasst, Sprache)
VALUES
(2042, NULL, 'Anna',    'Muster',    'Bahnhofstr. 5',  '8001', 'Zürich',    'Frau', '+41 79 100 00 01', NOW(), 'de'),
(2043, NULL, 'Beat',    'Frei',      'Hauptgasse 12',  '3001', 'Bern',      'Herr', '+41 79 100 00 02', NOW(), 'de'),
(2044, NULL, 'Claire',  'Martin',    '5 Rue de Rivoli','75001','Paris',     'Mme',  '+33 6 12 34 56 78', NOW(), 'fr'),
(2045, NULL, 'David',   'Smith',     '10 Baker St',    'W1U',  'London',    'Mr',   '+44 7911 111111',  NOW(), 'en'),
(2046, NULL, 'Emma',    'Wagner',    'Marktgasse 8',   '1011', 'Wien',      'Frau', '+43 699 444 4444',  NOW(), 'de'),
(2047, NULL, 'Hiro',    'Tanaka',    '3-5 Shinjuku',   '160',  'Tokyo',     'Mr',   '+81 90 5555 6666',  NOW(), 'ja'),
-- Mitarbeiter-Personen
(2048, NULL, 'Isabelle','Schneider', 'Rennweg 10',     '8001', 'Zürich',    'Frau', '+41 79 555 55 55',  NOW(), 'de'),
(2049, NULL, 'Jonas',   'Huber',     'Dorfstr. 99',    '3700', 'Spiez',     'Herr', '+41 79 666 66 66',  NOW(), 'de');

INSERT IGNORE INTO tbl_benutzer
    (Benutzer_ID, Benutzername, Password, Vorname, Name, Benutzergruppe, deaktiviert, aktiv)
VALUES
(27, 'isa.schneider', SHA2('Start123!', 256), 'Isabelle', 'Schneider', 1, '1000-01-01', 1),
(28, 'jonas.huber',   SHA2('Start123!', 256), 'Jonas',    'Huber',     1, '1000-01-01', 1);

INSERT IGNORE INTO tbl_buchung (Buchungs_ID, Personen_FS, Ankunft, Abreise, Land_FS) VALUES
(1087, 2044, '2026-06-01 14:00:00', '2026-06-04 11:00:00', 4),
(1088, 2045, '2026-06-03 15:00:00', '2026-06-05 11:00:00', 5),
(1089, 2046, '2026-06-10 14:00:00', '2026-06-13 11:00:00', 3),
(1090, 2047, '2026-06-15 14:00:00', '2026-06-17 11:00:00', 9);

INSERT IGNORE INTO tbl_positionen
    (Positions_ID, Buchungs_FS, Konto, Anzahl, Preis, Rabatt, Benutzer_FS, erfasst, Leistung_Text, Leistung_FS)
VALUES
(4055, 1087, 1000, 3, 22.00, 0.00, 27, NOW(), 'Bett Schlafsaal 6er', 1),
(4056, 1087, 2000, 3,  9.50, 0.00, 27, NOW(), 'Frühstück',            5),
(4057, 1088, 1000, 2, 22.00, 0.00, 27, NOW(), 'Bett Schlafsaal 6er', 1),
(4058, 1089, 1010, 3, 75.00, 0.10, 28, NOW(), 'Einzelzimmer',         3),
(4059, 1089, 2000, 3,  9.50, 0.00, 28, NOW(), 'Frühstück',            5),
(4060, 1090, 1010, 2, 75.00, 0.00, 27, NOW(), 'Einzelzimmer',         3),
(4061, 1090, 3000, 2, 18.00, 0.00, 27, NOW(), 'Fahrrad-Miete',        8);

-- =============================================================
-- D) Import-Kontrolle
-- =============================================================
SELECT 'tbl_land'       AS Tabelle, COUNT(*) AS Zeilen FROM tbl_land
UNION ALL SELECT 'tbl_leistung',    COUNT(*) FROM tbl_leistung
UNION ALL SELECT 'tbl_personen',    COUNT(*) FROM tbl_personen
UNION ALL SELECT 'tbl_benutzer',    COUNT(*) FROM tbl_benutzer
UNION ALL SELECT 'tbl_buchung',     COUNT(*) FROM tbl_buchung
UNION ALL SELECT 'tbl_positionen',  COUNT(*) FROM tbl_positionen;
