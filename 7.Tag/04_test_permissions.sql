-- =============================================================
-- 04_test_permissions.sql  –  Tag 7: Berechtigungen testen
-- Autor: Noah Bachmann | TBZ M141
-- Einloggen als:
--   mysql -u Reader      -p'123!' myTestDb
--   mysql -u Contributor -p'123!' myTestDb
-- =============================================================

USE `myTestDb`;

-- =============================================================
-- SCHRITT 6: Tests mit Reader-User
-- Einloggen: mysql -u Reader -p'123!' myTestDb
-- =============================================================

-- [R-P01] SELECT – erlaubt
SELECT Id, Vorname, Nachname FROM Person LIMIT 5;
-- Erwartet: Zeilen

-- [R-P02] SELECT Adresse – erlaubt
SELECT Id, Stadt, PLZ FROM Adresse LIMIT 5;
-- Erwartet: Zeilen

-- [R-N01] INSERT – verboten
INSERT INTO Person (Id, Vorname, Nachname, Email, AdresseId)
VALUES (999999, 'Max', 'Test', 'max@test.ch', 1);
-- Erwartet: ERROR 1142 – INSERT command denied to user 'Reader'

-- [R-N02] UPDATE – verboten
UPDATE Person SET Nachname = 'Geändert' WHERE Id = 1;
-- Erwartet: ERROR 1142 – UPDATE command denied to user 'Reader'

-- [R-N03] DELETE – verboten
DELETE FROM Person WHERE Id = 1;
-- Erwartet: ERROR 1142 – DELETE command denied to user 'Reader'

-- =============================================================
-- Tests mit Contributor-User
-- Einloggen: mysql -u Contributor -p'123!' myTestDb
-- =============================================================

-- [C-P01] SELECT – erlaubt
SELECT Id, Vorname, Nachname FROM Person LIMIT 5;
-- Erwartet: Zeilen

-- [C-P02] INSERT – erlaubt
INSERT INTO Person (Id, Vorname, Nachname, Email, AdresseId)
VALUES (999998, 'Test', 'Contributor', 'test@test.ch', 1);
-- Erwartet: Query OK

-- [C-P03] UPDATE – erlaubt
UPDATE Person SET Email = 'neu@test.ch' WHERE Id = 999998;
-- Erwartet: Query OK

-- [C-P04] DELETE – erlaubt
DELETE FROM Person WHERE Id = 999998;
-- Erwartet: Query OK

-- [C-N01] DROP TABLE – verboten
DROP TABLE Person;
-- Erwartet: ERROR 1142 – DROP command denied to user 'Contributor'

-- [C-N02] CREATE VIEW – verboten
CREATE VIEW vw_Person AS SELECT * FROM Person;
-- Erwartet: ERROR 1044 – Access denied for user 'Contributor'

-- [C-N03] GRANT – verboten
GRANT SELECT ON myTestDb.* TO 'Reader'@'localhost';
-- Erwartet: ERROR 1044 – Access denied for user 'Contributor'
