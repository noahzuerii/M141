-- =============================================================
-- 05_data_integrity.sql  –  Tag 7: Datenintegrität sicherstellen
-- Autor: Noah Bachmann | TBZ M141
-- =============================================================

USE `myTestDb`;

-- =============================================================
-- SCHRITT 7a: Duplikate prüfen (Eindeutigkeit)
-- =============================================================

-- Duplikate in Person
SELECT Id, COUNT(*) AS Anzahl
FROM Person
GROUP BY Id
HAVING COUNT(Id) > 1;
-- Erwartet: Zeilen falls Duplikate vorhanden

-- Duplikate in Adresse
SELECT Id, COUNT(*) AS Anzahl
FROM Adresse
GROUP BY Id
HAVING COUNT(Id) > 1;
-- Hinweis laut Aufgabe: 3 doppelte Datensätze in Adresse vorhanden

-- =============================================================
-- SCHRITT 7b: Referenzielle Integrität prüfen
-- (Gibt es Person.AdresseId die keine Adresse haben?)
-- =============================================================

SELECT COUNT(*) AS Waisen_Personen
FROM Person p
LEFT JOIN Adresse a ON p.AdresseId = a.Id
WHERE p.AdresseId IS NOT NULL AND a.Id IS NULL;
-- Erwartet: 0 (falls Daten konsistent)

-- =============================================================
-- SCHRITT 7c: Redundante Adress-Datensätze bereinigen
-- Laut Aufgabe: in Adresse kommen 3 Datensätze doppelt vor
-- =============================================================

-- Schritt 1: Welche Datensätze sind doppelt?
SELECT Id, Strasse, Hausnummer, PLZ, Stadt, Bundesstaat, COUNT(*) AS n
FROM Adresse
GROUP BY Id, Strasse, Hausnummer, PLZ, Stadt, Bundesstaat
HAVING COUNT(*) > 1;

-- Schritt 2: Temporäre Tabelle mit eindeutigen Adressen (MIN-ID gewinnt)
CREATE TEMPORARY TABLE temp_Adresse AS
    SELECT MIN(Id) AS Id, Strasse, Hausnummer, PLZ, Stadt, Bundesstaat
    FROM Adresse
    GROUP BY Strasse, Hausnummer, PLZ, Stadt, Bundesstaat;

-- Schritt 3: Fremdschlüssel in Person auf die eindeutige ID umschreiben
UPDATE Person SET AdresseId = (
    SELECT t.Id FROM temp_Adresse t
    INNER JOIN Adresse a ON a.Id = Person.AdresseId
    WHERE t.Strasse      = a.Strasse
      AND t.Hausnummer   = a.Hausnummer
      AND t.PLZ          = a.PLZ
      AND t.Stadt        = a.Stadt
      AND t.Bundesstaat  = a.Bundesstaat
    LIMIT 1
)
WHERE AdresseId IN (
    SELECT Id FROM Adresse
    WHERE Id NOT IN (SELECT Id FROM temp_Adresse)
);

-- Schritt 4: Redundante Adress-Einträge löschen
DELETE FROM Adresse
WHERE Id NOT IN (SELECT Id FROM temp_Adresse);

-- Schritt 5: Ergebnis prüfen
SELECT COUNT(*) AS Adress_Datensätze_nach_Bereinigung FROM Adresse;

-- =============================================================
-- SCHRITT 7d: PRIMARY KEY und FOREIGN KEY Constraints setzen
-- =============================================================

-- PRIMARY KEY auf Adresse
ALTER TABLE Adresse
    ADD PRIMARY KEY (Id);

-- PRIMARY KEY auf Person
ALTER TABLE Person
    ADD PRIMARY KEY (Id);

-- FOREIGN KEY von Person.AdresseId → Adresse.Id
ALTER TABLE Person
    ADD CONSTRAINT `Rel_adress`
    FOREIGN KEY (AdresseId) REFERENCES Adresse(Id);

-- Constraints prüfen
SHOW CREATE TABLE Person\G
SHOW CREATE TABLE Adresse\G

-- =============================================================
-- SCHRITT 7e: NOT NULL Constraint setzen (Datenvalidierung)
-- =============================================================

-- E-Mail darf nicht NULL sein
ALTER TABLE Person
    MODIFY Email VARCHAR(255) NOT NULL;

-- PLZ darf nicht NULL sein
ALTER TABLE Adresse
    MODIFY PLZ VARCHAR(10) NOT NULL;

-- =============================================================
-- SCHRITT 7f: Datentypen prüfen (Stichproben)
-- =============================================================

-- PLZ als VARCHAR prüfen (keine Zahlen-only-Werte mit führenden Nullen?)
SELECT PLZ FROM Adresse WHERE PLZ REGEXP '^0' LIMIT 5;

-- Email-Format stichprobenartig prüfen
SELECT Email FROM Person WHERE Email NOT LIKE '%@%.%' LIMIT 10;
-- Erwartet: 0 Zeilen (alle Emails haben @-Zeichen)

-- CHECK Constraint für Email-Format (MariaDB 10.2+)
ALTER TABLE Person
    ADD CONSTRAINT CHK_Email CHECK (Email LIKE '%@%.%');
