-- =============================================================
-- 05_backpacker_migration.sql
-- Autor: Noah Bachmann | TBZ M141 LB3
-- =============================================================
-- Beschreibung:
--   Automatisierte Migration der Datenbank backpacker_noah_lb3
--   vom lokalen MariaDB (XAMPP) auf AWS RDS (MySQL 8.0).
--
-- Ablauf:
--   1. Lokales Backup erstellen (Struktur + Daten)
--   2. Benutzer/Rollen-Backup erstellen (DCL)
--   3. Dump auf Cloud-Server einspielen
--   4. DCL auf Cloud-Server einspielen
--   5. Verbindung testen
--
-- Ausführung als Bash-Befehle (CMD / PowerShell) – nicht als SQL!
-- MySQL-Kommentare zeigen die Shell-Befehle für die Dokumentation.
-- =============================================================

-- =============================================================
-- SCHRITT 1: Lokales Backup (lokal ausführen)
-- =============================================================
-- Struktur + Daten als SQL-Dump:
--
-- Windows CMD:
-- mysqldump -u root -p ^
--   --databases backpacker_noah_lb3 ^
--   --add-drop-database ^
--   --routines ^
--   --triggers ^
--   --single-transaction ^
--   --set-gtid-purged=OFF ^
--   > C:\backup\backpacker_noah_lb3_dump.sql
--
-- Prüfen ob Dump vollständig:
-- findstr /C:"Dump completed" C:\backup\backpacker_noah_lb3_dump.sql

-- =============================================================
-- SCHRITT 2: DCL-Backup (Benutzer separat sichern)
-- =============================================================
-- mysqldump -u root -p ^
--   --no-create-info --no-data ^
--   --databases mysql ^
--   --tables user db tables_priv columns_priv ^
--   --where="user IN ('ben_noah','mgmt_noah')" ^
--   > C:\backup\backpacker_noah_lb3_users.sql
--
-- Alternativ: 02_backpacker_dcl.sql direkt auf Cloud ausführen
-- (empfohlen, da Passwort-Hashes auf Cloud neu gesetzt werden)

-- =============================================================
-- SCHRITT 3: Dump auf AWS RDS einspielen
-- =============================================================
-- CLOUD_HOST = <endpoint>.rds.amazonaws.com
-- CLOUD_PORT = 3306
-- CLOUD_USER = admin
--
-- Windows CMD:
-- mysql -h <endpoint>.rds.amazonaws.com ^
--       -u admin -p ^
--       --ssl-mode=REQUIRED ^
--       < C:\backup\backpacker_noah_lb3_dump.sql
--
-- Fortschritt überwachen (grosse Dumps):
-- mysql -h <endpoint> -u admin -p < dump.sql 2>&1 | findstr /V "^$"

-- =============================================================
-- SCHRITT 4: DCL auf Cloud-Server einrichten
-- =============================================================
-- Da AWS RDS kein SUPER-Privilege für normale User erlaubt,
-- werden Rollen und Benutzer direkt auf der Cloud erstellt.
--
-- mysql -h <endpoint>.rds.amazonaws.com -u admin -p < 02_backpacker_dcl.sql
--
-- Anpassung für AWS RDS:
-- SET DEFAULT ROLE ist in AWS RDS ggf. als admin auszuführen.

-- =============================================================
-- SCHRITT 5: SQL-Verifikation nach Migration (als admin auf Cloud)
-- =============================================================

-- Verbindung prüfen:
SELECT @@hostname, @@version, DATABASE();

-- Datenbank vorhanden:
SHOW DATABASES LIKE 'backpacker_noah_lb3';

-- Zeilenzahlen vergleichen (mit lokal):
USE backpacker_noah_lb3;

SELECT 'tbl_land'      AS Tabelle, COUNT(*) AS Zeilen FROM tbl_land
UNION ALL SELECT 'tbl_leistung',   COUNT(*) FROM tbl_leistung
UNION ALL SELECT 'tbl_personen',   COUNT(*) FROM tbl_personen
UNION ALL SELECT 'tbl_benutzer',   COUNT(*) FROM tbl_benutzer
UNION ALL SELECT 'tbl_buchung',    COUNT(*) FROM tbl_buchung
UNION ALL SELECT 'tbl_positionen', COUNT(*) FROM tbl_positionen;

-- Engine und Charset prüfen:
SELECT table_name, engine, table_collation
FROM information_schema.tables
WHERE table_schema = 'backpacker_noah_lb3';

-- Fremdschlüssel prüfen:
SELECT constraint_name, table_name, column_name,
       referenced_table_name, referenced_column_name
FROM information_schema.key_column_usage
WHERE table_schema = 'backpacker_noah_lb3'
  AND referenced_table_name IS NOT NULL
ORDER BY table_name;

-- Benutzer vorhanden:
SELECT user, host FROM mysql.user
WHERE user IN ('ben_noah', 'mgmt_noah');

-- =============================================================
-- SCHRITT 6: Produktionssicherung (my.cnf-Konfiguration)
-- =============================================================
-- Folgende Parameter sollten in der AWS RDS Parametergruppe gesetzt sein:
--
-- max_connections          = 100
-- innodb_buffer_pool_size  = 128M
-- slow_query_log           = 1
-- long_query_time          = 2
-- log_bin                  = 1         -- Binary Log für Recovery
-- expire_logs_days         = 7
-- character_set_server     = utf8mb4
-- collation_server         = utf8mb4_unicode_ci
-- require_secure_transport = ON        -- SSL erzwingen
--
-- Sicherheitseinstellungen AWS RDS:
-- - Security Group: nur Port 3306 von bekannten IPs öffnen
-- - VPC: private Subnet bevorzugen
-- - Multi-AZ: für Produktionsbetrieb aktivieren
-- - Automated Backups: 7 Tage Retention
-- - Deletion Protection: aktivieren

-- =============================================================
-- Rollback-Plan (falls Migration fehlschlägt)
-- =============================================================
-- 1. Cloud-Datenbank löschen: DROP DATABASE backpacker_noah_lb3;
-- 2. Lokale Datenbank läuft weiterhin – keine Unterbrechung
-- 3. Ursache im Dump identifizieren (Charset, Engine, Syntax)
-- 4. Angepassten Dump erneut einspielen
