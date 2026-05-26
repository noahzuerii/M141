-- =============================================================
-- 06_performance.sql  –  Tag 7: Performance & Index-Tests
-- Autor: Noah Bachmann | TBZ M141
-- =============================================================

USE `myTestDb`;

-- =============================================================
-- SCHRITT 8: Performance Test OHNE Index
-- Messung: Duration und Execution Plan (Tablescan)
-- =============================================================

-- Ausführungsplan anzeigen (kein Index erwartet: type=ALL, key=NULL)
EXPLAIN
SELECT * FROM Person person
INNER JOIN Adresse adresse ON adresse.Id = person.AdresseId
WHERE person.Id = 2569;

-- Eigentliche Query mit Zeitmessung
-- (Duration in phpMyAdmin/DBeaver ablesen)
SELECT * FROM Person person
INNER JOIN Adresse adresse ON adresse.Id = person.AdresseId
WHERE person.Id = 2569;

-- Ergebnis: Schlechte Performance (bis zu 500ms), EXPLAIN zeigt:
--   type  = ALL   → voller Tablescan
--   key   = NULL  → kein Index verwendet
--   rows  ≈ 400000

-- =============================================================
-- SCHRITT 9: Index nur auf Person erstellen
-- =============================================================

-- Index auf Person.AdresseId (Fremdschlüssel-Seite)
DROP INDEX IF EXISTS idx_AddresseId ON Person;
CREATE INDEX idx_AddresseId ON Person (AdresseId);

-- Index prüfen
SHOW INDEX FROM Person;

-- =============================================================
-- SCHRITT 10: Test nach Index auf Person wiederholen
-- =============================================================

-- Ausführungsplan (Index auf Person sollte genutzt werden)
EXPLAIN
SELECT * FROM Person person
INNER JOIN Adresse adresse ON adresse.Id = person.AdresseId
WHERE person.Id = 2569;

-- Messung: Duration notieren
-- Ergebnis: Person wird per Index gefunden, Adresse noch Tablescan
--   person:  type=ref, key=idx_AddresseId  → verbessert
--   adresse: type=ALL, key=NULL            → noch kein Index

-- Query
SELECT * FROM Person person
INNER JOIN Adresse adresse ON adresse.Id = person.AdresseId
WHERE person.Id = 2569;

-- =============================================================
-- SCHRITT 11: Index auf Adresse erstellen
-- =============================================================

DROP INDEX IF EXISTS idx_Id ON Adresse;
CREATE INDEX idx_Id ON Adresse (Id);

-- Index prüfen
SHOW INDEX FROM Adresse;

-- =============================================================
-- SCHRITT 12: Test nach beiden Indizes wiederholen
-- =============================================================

-- Ausführungsplan (beide Tabellen sollten Index nutzen)
EXPLAIN
SELECT * FROM Person person
INNER JOIN Adresse adresse ON adresse.Id = person.AdresseId
WHERE person.Id = 2569;

-- Ergebnis: Maximale Performance
--   person:  type=ref, key=PRIMARY oder idx_AddresseId
--   adresse: type=ref, key=idx_Id
--   rows ≈ 1 für beide Tabellen → fast kein Scan mehr

-- Query (Messung mit signifikant kürzerer Duration)
SELECT * FROM Person person
INNER JOIN Adresse adresse ON adresse.Id = person.AdresseId
WHERE person.Id = 2569;

-- =============================================================
-- Performance-Vergleich Zusammenfassung:
-- Ohne Index:     ~400-500ms  (Tablescan, rows ≈ 400000)
-- Index Person:   ~50-100ms   (Person per Index, Adresse noch Scan)
-- Beide Indizes:  ~1-5ms      (beide per Index, rows ≈ 1)
-- =============================================================
