-- =============================================================
-- 05_backpacker_migration.sql
-- Autor: Noah Bachmann | TBZ M141 LB3
-- =============================================================
-- Beschreibung:
--   Automatisierte Migration der Datenbank backpacker_noah_lb3
--   vom lokalen MariaDB (XAMPP) auf Aiven for MySQL 8.0
--   (Cloud-Region: google-europe-west6 / Zürich).
--
-- Hinweis Cloud-Provider:
--   Da kein AWS-Schulungs-Abo zur Verfügung stand, wurde anstelle
--   von AWS RDS der DBaaS-Anbieter Aiven gewählt. Der Migrations-
--   ablauf bleibt identisch; nur Endpoint, Default-Admin
--   (avnadmin) und das CA-Zertifikat unterscheiden sich.
--
-- Ablauf:
--   1. Lokales Backup erstellen (Struktur + Daten + Routinen + Trigger)
--   2. Benutzer/Rollen-Backup (DCL)
--   3. Dump auf Aiven einspielen (TLS 1.3 + VERIFY_CA)
--   4. DCL auf Aiven einspielen
--   5. Verbindung & Konsistenz testen
--
-- Ausführung als Shell-Befehle (CMD / PowerShell) – nicht als SQL!
-- MySQL-Kommentare zeigen die Shell-Befehle für die Dokumentation.
--
-- Variablen (im CMD vorher setzen):
--   set AIVEN_HOST=backpacker-noah-lb3-noah-lb3.h.aivencloud.com
--   set AIVEN_PORT=12947
--   set AIVEN_USER=avnadmin
--   set AIVEN_CA=C:\backup\aiven_ca.pem
-- =============================================================

-- =============================================================
-- SCHRITT 1: Lokales Backup (lokal ausführen)
-- =============================================================
-- Struktur + Daten + Stored Routines + Trigger als SQL-Dump:
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
-- Empfohlen: 02_backpacker_dcl.sql direkt auf Aiven ausführen,
-- da Passwort-Hashes auf der Cloud neu gesetzt werden (kein
-- Klartext-Re-Import alter Hashes).

-- =============================================================
-- SCHRITT 3: Dump auf Aiven einspielen
-- =============================================================
-- CLOUD_HOST = backpacker-noah-lb3-noah-lb3.h.aivencloud.com
-- CLOUD_PORT = 12947
-- CLOUD_USER = avnadmin
-- CA-CERT    = aiven_ca.pem (aus Aiven Console > Service > "Download CA")
--
-- Windows CMD:
-- mysql -h backpacker-noah-lb3-noah-lb3.h.aivencloud.com ^
--       -P 12947 -u avnadmin -p ^
--       --ssl-mode=VERIFY_CA --ssl-ca=C:\backup\aiven_ca.pem ^
--       < C:\backup\backpacker_noah_lb3_dump.sql
--
-- Fortschritt überwachen (grosse Dumps):
-- mysql -h <endpoint> -P 12947 -u avnadmin -p < dump.sql 2>&1 | findstr /V "^$"

-- =============================================================
-- SCHRITT 4: DCL auf Cloud-Server einrichten
-- =============================================================
-- Aiven gibt dem Default-Admin avnadmin alle nötigen GRANT-Rechte
-- (kein SUPER nötig), CREATE ROLE / SET DEFAULT ROLE sind erlaubt.
--
-- mysql -h backpacker-noah-lb3-noah-lb3.h.aivencloud.com ^
--       -P 12947 -u avnadmin -p ^
--       --ssl-mode=VERIFY_CA --ssl-ca=C:\backup\aiven_ca.pem ^
--       < 02_backpacker_dcl.sql

-- =============================================================
-- SCHRITT 5: SQL-Verifikation nach Migration (als avnadmin auf Cloud)
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
-- SCHRITT 6: Produktionssicherung (my.cnf / Aiven Advanced Configuration)
-- =============================================================
-- Aiven exponiert kein direktes my.cnf; die Parameter werden über
-- die "Advanced Configuration" der Service-UI bzw. die Aiven-CLI
-- gesetzt. Die folgenden Werte wurden für den produktiven Betrieb
-- konfiguriert (vgl. my-aiven.cnf im Repo):
--
-- mysql.max_connections          = 100
-- mysql.innodb_buffer_pool_size  = bleibt managed (Aiven-default ~70 % RAM)
-- mysql.slow_query_log           = 1
-- mysql.long_query_time          = 2
-- mysql.log_bin                  = 1         -- binlog für PITR
-- mysql.expire_logs_days         = 7
-- mysql.character_set_server     = utf8mb4
-- mysql.collation_server         = utf8mb4_unicode_ci
-- mysql.require_secure_transport = ON        -- bei Aiven nicht abschaltbar
--
-- Sicherheitseinstellungen Aiven:
-- - IP-Allowlist: nur TBZ-NAT + private Heim-IP
-- - Service Integrations: log-shipping nach "M141 Logs"
-- - Backups: automatisch (PITR, 14 Tage Retention)
-- - Failover: synchroner Hot-Standby in derselben Region
-- - Termination Protection: aktiviert

-- =============================================================
-- Rollback-Plan (falls Migration fehlschlägt)
-- =============================================================
-- 1. Cloud-Datenbank löschen: DROP DATABASE backpacker_noah_lb3;
--    (Service selbst bleibt erhalten, Kosten laufen weiter)
-- 2. Lokale Datenbank läuft weiterhin – keine Unterbrechung
-- 3. Ursache im Dump identifizieren (Charset, Engine, Syntax)
-- 4. Angepassten Dump erneut einspielen
-- 5. Falls Service inkompatibel: 14-Tage-PITR-Snapshot via Aiven-UI
--    auf einen "Fork" wiederherstellen und dort weiterarbeiten.
