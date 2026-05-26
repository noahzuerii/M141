-- =============================================================
-- 03_permissions.sql  –  Tag 7: Rollen und Berechtigungen
-- Autor: Noah Bachmann | TBZ M141
-- Zugriffsmatrix:
--   Reader:      SELECT auf alle Tabellen
--   Contributor: SELECT, INSERT, UPDATE, DELETE auf alle Tabellen
-- =============================================================

USE `myTestDb`;

-- =============================================================
-- SCHRITT 5: Rollen erstellen und berechtigen
-- =============================================================

-- Bestehende Rollen entfernen (idempotent)
DROP ROLE IF EXISTS 'RoleReader';
DROP ROLE IF EXISTS 'RoleContributor';

-- Rollen anlegen
CREATE ROLE 'RoleReader';
CREATE ROLE 'RoleContributor';

-- Berechtigungen auf DB myTestDb vergeben
GRANT SELECT                            ON myTestDb.* TO 'RoleReader';
GRANT SELECT, INSERT, UPDATE, DELETE    ON myTestDb.* TO 'RoleContributor';

-- Rollen den Usern zuweisen (alle Hosts)
GRANT 'RoleReader'      TO 'Reader'@'%';
GRANT 'RoleReader'      TO 'Reader'@'localhost';
GRANT 'RoleContributor' TO 'Contributor'@'%';
GRANT 'RoleContributor' TO 'Contributor'@'localhost';

-- Default-Rolle setzen (automatisch aktiv beim Login)
SET DEFAULT ROLE 'RoleReader'      FOR 'Reader'@'%';
SET DEFAULT ROLE 'RoleReader'      FOR 'Reader'@'localhost';
SET DEFAULT ROLE 'RoleContributor' FOR 'Contributor'@'%';
SET DEFAULT ROLE 'RoleContributor' FOR 'Contributor'@'localhost';

-- Berechtigungen sofort wirksam machen
FLUSH PRIVILEGES;

-- =============================================================
-- Grants überprüfen
-- =============================================================

SHOW GRANTS FOR 'Reader'@'localhost';
SHOW GRANTS FOR 'Contributor'@'localhost';

-- Rollen-Grants prüfen
SHOW GRANTS FOR 'RoleReader';
SHOW GRANTS FOR 'RoleContributor';
