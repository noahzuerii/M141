-- =============================================================
-- 02_backpacker_dcl.sql
-- Datenbank: backpacker_noah_lb3
-- Autor: Noah Bachmann | TBZ M141 LB3
-- =============================================================
-- Beschreibung:
--   Rollen und Benutzer gemäss Zugriffsmatrix LB3.
--   Spaltenebene für tbl_benutzer:
--     - Password    : kein Zugriff für Benutzer-Gruppe
--     - deaktiviert : nur SELECT für Benutzer-Gruppe
--
-- Zwei Rollen:
--   benutzer_rolle  → Frontdesk-Mitarbeiter
--   management_rolle → Verwaltung
-- =============================================================

USE backpacker_noah_lb3;

-- =============================================================
-- 1. ROLLEN erstellen
-- =============================================================
DROP ROLE IF EXISTS benutzer_rolle;
DROP ROLE IF EXISTS management_rolle;

CREATE ROLE benutzer_rolle;
CREATE ROLE management_rolle;

-- =============================================================
-- 2. RECHTE für "benutzer_rolle"
-- =============================================================

-- tbl_personen: SELECT + UPDATE (kein INSERT / DELETE)
GRANT SELECT, UPDATE
    ON backpacker_noah_lb3.tbl_personen
    TO benutzer_rolle;

-- tbl_benutzer: Spaltenweise
--   Password    → kein Zugriff
--   deaktiviert → nur SELECT
--   restliche Attribute → SELECT, INSERT, UPDATE
GRANT SELECT (Benutzer_ID, Benutzername, Vorname, Name,
              Benutzergruppe, erfasst, deaktiviert, aktiv)
    ON backpacker_noah_lb3.tbl_benutzer
    TO benutzer_rolle;

GRANT INSERT (Benutzername, Vorname, Name, Benutzergruppe, aktiv)
    ON backpacker_noah_lb3.tbl_benutzer
    TO benutzer_rolle;

GRANT UPDATE (Benutzername, Vorname, Name, Benutzergruppe, aktiv)
    ON backpacker_noah_lb3.tbl_benutzer
    TO benutzer_rolle;

-- tbl_buchung: vollständiges CRUD
GRANT SELECT, INSERT, UPDATE, DELETE
    ON backpacker_noah_lb3.tbl_buchung
    TO benutzer_rolle;

-- tbl_positionen: vollständiges CRUD
GRANT SELECT, INSERT, UPDATE, DELETE
    ON backpacker_noah_lb3.tbl_positionen
    TO benutzer_rolle;

-- tbl_land: nur lesen
GRANT SELECT
    ON backpacker_noah_lb3.tbl_land
    TO benutzer_rolle;

-- tbl_leistung: nur lesen
GRANT SELECT
    ON backpacker_noah_lb3.tbl_leistung
    TO benutzer_rolle;

-- =============================================================
-- 3. RECHTE für "management_rolle"
-- =============================================================

-- tbl_buchung + tbl_positionen: nur lesen
GRANT SELECT ON backpacker_noah_lb3.tbl_buchung    TO management_rolle;
GRANT SELECT ON backpacker_noah_lb3.tbl_positionen TO management_rolle;

-- tbl_audit_log: Management darf lesen (kein manuelles Schreiben!)
GRANT SELECT ON backpacker_noah_lb3.tbl_audit_log  TO management_rolle;

-- Alle anderen Tabellen: vollständiges CRUD
GRANT SELECT, INSERT, UPDATE, DELETE
    ON backpacker_noah_lb3.tbl_personen   TO management_rolle;

GRANT SELECT, INSERT, UPDATE, DELETE
    ON backpacker_noah_lb3.tbl_benutzer   TO management_rolle;

GRANT SELECT, INSERT, UPDATE, DELETE
    ON backpacker_noah_lb3.tbl_land       TO management_rolle;

GRANT SELECT, INSERT, UPDATE, DELETE
    ON backpacker_noah_lb3.tbl_leistung   TO management_rolle;

-- =============================================================
-- 4. BENUTZER erstellen
-- =============================================================

-- Frontdesk-Mitarbeiter (lokal + Cloud)
DROP USER IF EXISTS 'ben_noah'@'localhost';
DROP USER IF EXISTS 'ben_noah'@'%';
CREATE USER 'ben_noah'@'localhost' IDENTIFIED BY 'Backpacker_Ben!1';
CREATE USER 'ben_noah'@'%'         IDENTIFIED BY 'Backpacker_Ben!1';
GRANT benutzer_rolle TO 'ben_noah'@'localhost';
GRANT benutzer_rolle TO 'ben_noah'@'%';
SET DEFAULT ROLE benutzer_rolle FOR 'ben_noah'@'localhost';
SET DEFAULT ROLE benutzer_rolle FOR 'ben_noah'@'%';

-- Management (lokal + Cloud)
DROP USER IF EXISTS 'mgmt_noah'@'localhost';
DROP USER IF EXISTS 'mgmt_noah'@'%';
CREATE USER 'mgmt_noah'@'localhost' IDENTIFIED BY 'Backpacker_Mgmt!1';
CREATE USER 'mgmt_noah'@'%'         IDENTIFIED BY 'Backpacker_Mgmt!1';
GRANT management_rolle TO 'mgmt_noah'@'localhost';
GRANT management_rolle TO 'mgmt_noah'@'%';
SET DEFAULT ROLE management_rolle FOR 'mgmt_noah'@'localhost';
SET DEFAULT ROLE management_rolle FOR 'mgmt_noah'@'%';

FLUSH PRIVILEGES;

-- =============================================================
-- 5. Kontrolle
-- =============================================================
SHOW GRANTS FOR benutzer_rolle;
SHOW GRANTS FOR management_rolle;
SHOW GRANTS FOR 'ben_noah'@'localhost';
SHOW GRANTS FOR 'mgmt_noah'@'localhost';

-- =============================================================
-- AUFRÄUMEN (nur bei Reset der Testumgebung)
-- =============================================================
-- DROP USER IF EXISTS 'ben_noah'@'localhost', 'ben_noah'@'%';
-- DROP USER IF EXISTS 'mgmt_noah'@'localhost', 'mgmt_noah'@'%';
-- DROP ROLE IF EXISTS benutzer_rolle, management_rolle;
-- FLUSH PRIVILEGES;
