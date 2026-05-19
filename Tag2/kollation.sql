-- kollation.sql
-- Testet verschiedene Kollationen (Sortierregeln) in MariaDB/MySQL

CREATE DATABASE IF NOT EXISTS kollation
  DEFAULT CHARACTER SET utf8mb4
  DEFAULT COLLATE utf8mb4_unicode_ci;

USE kollation;

-- Tabelle mit verschiedenen Kollationen pro Spalte
CREATE TABLE tbl_kollation_test (
    id          INT AUTO_INCREMENT PRIMARY KEY,
    -- Standardmässige Sortierung (unicode, case-insensitive)
    name_unicode    VARCHAR(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
    -- Deutsche Telefonbuch-Sortierung (ä = ae, ö = oe, ü = ue)
    name_german2    VARCHAR(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_german2_ci,
    -- Allgemein (schneller, weniger präzise)
    name_general    VARCHAR(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci
);

-- Testdaten mit deutschen Umlauten
INSERT INTO tbl_kollation_test (name_unicode, name_german2, name_general) VALUES
('Müller',  'Müller',  'Müller'),
('Mueller', 'Mueller', 'Mueller'),
('Maier',   'Maier',   'Maier'),
('Mäier',   'Mäier',   'Mäier'),
('Huber',   'Huber',   'Huber'),
('Über',    'Über',    'Über'),
('Abel',    'Abel',    'Abel'),
('Özdemir', 'Özdemir', 'Özdemir');

-- Sortierung mit unicode_ci
SELECT 'utf8mb4_unicode_ci' AS Kollation, name_unicode AS Name
FROM tbl_kollation_test
ORDER BY name_unicode;

-- Sortierung mit german2_ci (Telefonbuch: ä kommt nach ae)
SELECT 'utf8mb4_german2_ci' AS Kollation, name_german2 AS Name
FROM tbl_kollation_test
ORDER BY name_german2;

-- Vergleich case-insensitive: 'mueller' = 'Mueller'?
SELECT
    'mueller' = 'Mueller' COLLATE utf8mb4_unicode_ci  AS unicode_ci_gleich,
    'mueller' = 'Mueller' COLLATE utf8mb4_unicode_cs  AS unicode_cs_gleich;

-- Kollation einer Spalte nachträglich ändern
ALTER TABLE tbl_kollation_test
    MODIFY name_general VARCHAR(50)
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_german2_ci;

-- Aktuelle Kollation der Datenbank anzeigen
SHOW CREATE DATABASE kollation;

-- Kollation aller Spalten der Tabelle anzeigen
SHOW FULL COLUMNS FROM tbl_kollation_test;
