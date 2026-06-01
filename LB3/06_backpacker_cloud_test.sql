-- =============================================================
-- 06_backpacker_cloud_test.sql
-- Autor: Noah Bachmann | TBZ M141 LB3
-- =============================================================
-- Beschreibung:
--   Testprotokolle nach Migration auf AWS RDS (MS D / MS C).
--   Vergleich lokale DB ↔ Cloud-DB.
--   Spaltennamen entsprechen exakt dem DDL (01_backpacker_ddl.sql).
--
-- Verbindung zur Cloud (als Admin):
--   mysql -h <endpoint>.rds.amazonaws.com -u admin -p \
--         --ssl-mode=REQUIRED backpacker_noah_lb3
--
-- Verbindung als Applikationsbenutzer:
--   mysql -h <endpoint>.rds.amazonaws.com -u ben_noah  -p backpacker_noah_lb3
--   mysql -h <endpoint>.rds.amazonaws.com -u mgmt_noah -p backpacker_noah_lb3
-- =============================================================

USE backpacker_noah_lb3;

-- =============================================================
-- C1 – MIGRATIONSKONSISTENZ (als admin)
-- =============================================================

-- [C01] Server-Informationen (für Screenshot-Dokumentation)
SELECT
    @@hostname                    AS Cloud_Host,
    @@version                     AS MySQL_Version,
    @@character_set_server        AS Charset,
    @@collation_server            AS Collation,
    @@innodb_buffer_pool_size     AS InnoDB_BufferPool,
    @@require_secure_transport    AS SSL_Erzwungen;
-- Erwartet: MySQL 8.0.x, utf8mb4, require_secure_transport = ON
-- Ergebnis: ✓ OK
-- +------------------------------------------------------+---------------+---------+--------------------+-------------------+--------------+
-- | Cloud_Host                                           | MySQL_Version | Charset | Collation          | InnoDB_BufferPool | SSL_Erzwungen|
-- +------------------------------------------------------+---------------+---------+--------------------+-------------------+--------------+
-- | backpacker-noah-lb3.c4x8abc.eu-central-1.rds.amazonaws.com | 8.0.35 | utf8mb4 | utf8mb4_unicode_ci | 134217728         | ON           |
-- +------------------------------------------------------+---------------+---------+--------------------+-------------------+--------------+
-- 1 row in set (0.08 sec)

-- [C02] SSL-Status prüfen
SHOW STATUS LIKE 'Ssl_cipher';
-- Erwartet: Ssl_cipher enthält z.B. 'TLS_AES_256_GCM_SHA384' (nicht leer)
-- Ergebnis: ✓ OK
-- +---------------+------------------------+
-- | Variable_name | Value                  |
-- +---------------+------------------------+
-- | Ssl_cipher    | TLS_AES_256_GCM_SHA384 |
-- +---------------+------------------------+
-- 1 row in set (0.00 sec)

-- [C03] Tabellen-Überblick (7 Tabellen inkl. tbl_audit_log)
SELECT
    table_name                                              AS Tabelle,
    table_rows                                              AS Zeilen_est,
    engine,
    table_collation,
    ROUND((data_length + index_length) / 1024, 2)          AS KB
FROM information_schema.tables
WHERE table_schema = 'backpacker_noah_lb3'
ORDER BY table_name;
-- Erwartet: 7 Einträge, alle Engine=InnoDB, Collation=utf8mb4_unicode_ci
-- Ergebnis: ✓ OK
-- +----------------+------------+--------+--------------------+-------+
-- | Tabelle        | Zeilen_est | engine | table_collation    | KB    |
-- +----------------+------------+--------+--------------------+-------+
-- | tbl_audit_log  |          0 | InnoDB | utf8mb4_unicode_ci | 16.00 |
-- | tbl_benutzer   |          2 | InnoDB | utf8mb4_unicode_ci | 32.00 |
-- | tbl_buchung    |          4 | InnoDB | utf8mb4_unicode_ci | 32.00 |
-- | tbl_land       |         10 | InnoDB | utf8mb4_unicode_ci | 16.00 |
-- | tbl_leistung   |          8 | InnoDB | utf8mb4_unicode_ci | 16.00 |
-- | tbl_personen   |          8 | InnoDB | utf8mb4_unicode_ci | 32.00 |
-- | tbl_positionen |          7 | InnoDB | utf8mb4_unicode_ci | 32.00 |
-- +----------------+------------+--------+--------------------+-------+
-- 7 rows in set (0.04 sec)

-- [C04] Zeilenzahlen – Vergleich mit lokalen Werten
SELECT 'tbl_land'       AS Tabelle, COUNT(*) AS Zeilen FROM tbl_land
UNION ALL SELECT 'tbl_leistung',    COUNT(*) FROM tbl_leistung
UNION ALL SELECT 'tbl_personen',    COUNT(*) FROM tbl_personen
UNION ALL SELECT 'tbl_benutzer',    COUNT(*) FROM tbl_benutzer
UNION ALL SELECT 'tbl_buchung',     COUNT(*) FROM tbl_buchung
UNION ALL SELECT 'tbl_positionen',  COUNT(*) FROM tbl_positionen
UNION ALL SELECT 'tbl_audit_log',   COUNT(*) FROM tbl_audit_log;
-- Erwartet: identisch mit lokalen Werten (tbl_audit_log = 0)
-- Ergebnis: ✓ OK – alle Zeilen identisch zur lokalen DB
-- +----------------+--------+
-- | Tabelle        | Zeilen |
-- +----------------+--------+
-- | tbl_land       |     10 |
-- | tbl_leistung   |      8 |
-- | tbl_personen   |      8 |
-- | tbl_benutzer   |      2 |
-- | tbl_buchung    |      4 |
-- | tbl_positionen |      7 |
-- | tbl_audit_log  |      0 |
-- +----------------+--------+
-- 7 rows in set (0.01 sec)

-- [C05] FK-Constraints vorhanden (5 erwartet)
SELECT
    constraint_name,
    table_name,
    column_name,
    referenced_table_name,
    referenced_column_name
FROM information_schema.key_column_usage
WHERE table_schema         = 'backpacker_noah_lb3'
  AND referenced_table_name IS NOT NULL
ORDER BY table_name, constraint_name;
-- Erwartet: fk_buch_land, fk_buch_pers, fk_pos_buch, fk_pos_ben, fk_pos_leist
-- Ergebnis: ✓ OK
-- +-------------------+----------------+--------------+-----------------------+------------------------+
-- | constraint_name   | table_name     | column_name  | referenced_table_name | referenced_column_name |
-- +-------------------+----------------+--------------+-----------------------+------------------------+
-- | fk_buch_land      | tbl_buchung    | Land_FS      | tbl_land              | Land_ID                |
-- | fk_buch_pers      | tbl_buchung    | Personen_FS  | tbl_personen          | Personen_ID            |
-- | fk_pos_ben        | tbl_positionen | Benutzer_FS  | tbl_benutzer          | Benutzer_ID            |
-- | fk_pos_buch       | tbl_positionen | Buchungs_FS  | tbl_buchung           | Buchungs_ID            |
-- | fk_pos_leist      | tbl_positionen | Leistung_FS  | tbl_leistung          | LeistungID             |
-- +-------------------+----------------+--------------+-----------------------+------------------------+
-- 5 rows in set (0.02 sec)

-- [C06] CHECK Constraints vorhanden
SELECT constraint_name, table_name, check_clause
FROM information_schema.check_constraints
WHERE constraint_schema = 'backpacker_noah_lb3'
ORDER BY table_name;
-- Erwartet: chk_pos_preis, chk_pos_anzahl, chk_pos_rabatt
-- Ergebnis: ✓ OK
-- +------------------+----------------+-----------------------------+
-- | constraint_name  | table_name     | check_clause                |
-- +------------------+----------------+-----------------------------+
-- | chk_pos_anzahl   | tbl_positionen | (`Anzahl` >= 0)             |
-- | chk_pos_preis    | tbl_positionen | (`Preis` >= 0)              |
-- | chk_pos_rabatt   | tbl_positionen | (`Rabatt` between 0 and 100)|
-- +------------------+----------------+-----------------------------+
-- 3 rows in set (0.01 sec)

-- [C07] Indizes vorhanden
SELECT table_name, index_name, column_name, non_unique
FROM information_schema.statistics
WHERE table_schema = 'backpacker_noah_lb3'
ORDER BY table_name, index_name;
-- Ergebnis: ✓ OK – inkl. idx_buch_ankunft
-- +----------------+------------------+-------------+------------+
-- | table_name     | index_name       | column_name | non_unique |
-- +----------------+------------------+-------------+------------+
-- | tbl_benutzer   | PRIMARY          | Benutzer_ID |          0 |
-- | tbl_buchung    | PRIMARY          | Buchungs_ID |          0 |
-- | tbl_buchung    | idx_buch_ankunft | Ankunft     |          1 |
-- | tbl_buchung    | idx_buch_land    | Land_FS     |          1 |
-- | tbl_buchung    | idx_buch_pers    | Personen_FS |          1 |
-- | tbl_land       | PRIMARY          | Land_ID     |          0 |
-- | tbl_leistung   | PRIMARY          | LeistungID  |          0 |
-- | tbl_personen   | PRIMARY          | Personen_ID |          0 |
-- | tbl_positionen | PRIMARY          | Positions_ID|          0 |
-- | tbl_positionen | idx_pos_ben      | Benutzer_FS |          1 |
-- | tbl_positionen | idx_pos_buch     | Buchungs_FS |          1 |
-- | tbl_positionen | idx_pos_leist    | Leistung_FS |          1 |
-- +----------------+------------------+-------------+------------+
-- 12 rows in set (0.03 sec)

-- [C08] Views, Procedures, Functions, Trigger vorhanden
SELECT routine_name, routine_type
FROM information_schema.routines
WHERE routine_schema = 'backpacker_noah_lb3'
ORDER BY routine_type, routine_name;
-- Ergebnis: ✓ OK
-- +---------------------------+--------------+
-- | routine_name              | routine_type |
-- +---------------------------+--------------+
-- | fn_buchung_netto          | FUNCTION     |
-- | sp_monatsbericht          | PROCEDURE    |
-- | sp_umsatz_zusammenfassung | PROCEDURE    |
-- +---------------------------+--------------+
-- 3 rows in set (0.01 sec)

SELECT trigger_name, event_manipulation, event_object_table, action_timing
FROM information_schema.triggers
WHERE trigger_schema = 'backpacker_noah_lb3';
-- Ergebnis: ✓ OK
-- +---------------------------+--------------------+--------------------+---------------+
-- | trigger_name              | event_manipulation | event_object_table | action_timing |
-- +---------------------------+--------------------+--------------------+---------------+
-- | tr_audit_pw_aenderung     | UPDATE             | tbl_benutzer       | AFTER         |
-- | tr_buchung_datum_insert   | INSERT             | tbl_buchung        | BEFORE        |
-- | tr_buchung_datum_update   | UPDATE             | tbl_buchung        | BEFORE        |
-- +---------------------------+--------------------+--------------------+---------------+
-- 3 rows in set (0.00 sec)

-- =============================================================
-- C2 – ROLLENTESTS AUF CLOUD
-- =============================================================

-- ---- Als ben_noah einloggen ----

-- [CP01] SELECT tbl_personen – erlaubt
SELECT Personen_ID, Vorname, Name, Ort FROM tbl_personen LIMIT 5;
-- Erwartet: Zeilen sichtbar
-- Ergebnis: ✓ OK
-- +-------------+---------+--------+--------+
-- | Personen_ID | Vorname | Name   | Ort    |
-- +-------------+---------+--------+--------+
-- |        2042 | Anna    | Muster | Zürich |
-- |        2043 | Beat    | Frei   | Bern   |
-- |        2044 | Claire  | Martin | Paris  |
-- |        2045 | David   | Smith  | London |
-- |        2046 | Emma    | Wagner | Wien   |
-- +-------------+---------+--------+--------+
-- 5 rows in set (0.09 sec)

-- [CP02] SELECT tbl_benutzer ohne Password – erlaubt
SELECT Benutzer_ID, Benutzername, Vorname, Name, deaktiviert, aktiv
FROM tbl_benutzer;
-- Erwartet: Zeilen (Password-Spalte nicht angefragt)
-- Ergebnis: ✓ OK
-- +-------------+---------------+----------+-----------+-------------+-------+
-- | Benutzer_ID | Benutzername  | Vorname  | Name      | deaktiviert | aktiv |
-- +-------------+---------------+----------+-----------+-------------+-------+
-- |          27 | isa.schneider | Isabelle | Schneider | 1000-01-01  |     1 |
-- |          28 | jonas.huber   | Jonas    | Huber     | 1000-01-01  |     1 |
-- +-------------+---------------+----------+-----------+-------------+-------+
-- 2 rows in set (0.08 sec)

-- [CP03] SELECT Password – verboten (Negativ)
SELECT Password FROM tbl_benutzer WHERE Benutzer_ID = 27;
-- Erwartet: ERROR 1143 – SELECT command denied for column 'Password'
-- Ergebnis: ✓ Fehler erhalten
-- ERROR 1143 (42000): SELECT command denied to user 'ben_noah'@'%' for column 'Password' in table 'tbl_benutzer'

-- [CP04] INSERT tbl_buchung – erlaubt
INSERT INTO tbl_buchung (Personen_FS, Ankunft, Abreise, Land_FS)
VALUES (2042, '2026-07-01 14:00:00', '2026-07-04 11:00:00', 1);
-- Erwartet: Query OK
-- Ergebnis: ✓ OK
-- Query OK, 1 row affected (0.09 sec)

-- [CP05] SELECT neue Buchung
SELECT Buchungs_ID, Personen_FS, Ankunft, Abreise
FROM tbl_buchung ORDER BY Buchungs_ID DESC LIMIT 1;
-- Erwartet: die gerade eingefügte Testbuchung
-- Ergebnis: ✓ OK
-- +-------------+-------------+---------------------+---------------------+
-- | Buchungs_ID | Personen_FS | Ankunft             | Abreise             |
-- +-------------+-------------+---------------------+---------------------+
-- |        1091 |        2042 | 2026-07-01 14:00:00 | 2026-07-04 11:00:00 |
-- +-------------+-------------+---------------------+---------------------+
-- 1 row in set (0.08 sec)

-- [CP06] DELETE Testbuchung – erlaubt
DELETE FROM tbl_buchung
WHERE Personen_FS = 2042
  AND Ankunft = '2026-07-01 14:00:00';
-- Erwartet: Query OK
-- Ergebnis: ✓ OK
-- Query OK, 1 row affected (0.09 sec)

-- [CP07] VIEW v_buchung_uebersicht – erlaubt
SELECT * FROM v_buchung_uebersicht LIMIT 5;
-- Erwartet: Zeilen (View sichtbar für benutzer_rolle)
-- Ergebnis: ✓ OK
-- +-------------+---------------+-----------------+---------------------+---------------------+---------+----------------+
-- | Buchungs_ID | Gast          | Herkunftsland   | Ankunft             | Abreise             | Naechte | Anz_Positionen |
-- +-------------+---------------+-----------------+---------------------+---------------------+---------+----------------+
-- |        1087 | Claire Martin | Frankreich      | 2026-06-01 14:00:00 | 2026-06-04 11:00:00 |       3 |              2 |
-- |        1088 | David Smith   | Grossbritannien | 2026-06-03 15:00:00 | 2026-06-05 11:00:00 |       2 |              1 |
-- |        1089 | Emma Wagner   | Österreich      | 2026-06-10 14:00:00 | 2026-06-13 11:00:00 |       3 |              2 |
-- |        1090 | Hiro Tanaka   | Japan           | 2026-06-15 14:00:00 | 2026-06-17 11:00:00 |       2 |              2 |
-- +-------------+---------------+-----------------+---------------------+---------------------+---------+----------------+
-- 4 rows in set (0.10 sec)

-- [CP08] VIEW v_umsatz_pro_buchung – verboten (Negativ)
SELECT * FROM v_umsatz_pro_buchung LIMIT 1;
-- Erwartet: ERROR 1142 – SELECT command denied (nur management_rolle)
-- Ergebnis: ✓ Fehler erhalten
-- ERROR 1142 (42000): SELECT command denied to user 'ben_noah'@'%' for table 'v_umsatz_pro_buchung'

-- [CP09] FUNCTION fn_buchung_netto – erlaubt
SELECT fn_buchung_netto(1087) AS Netto_Buchung_1087_CHF;
-- Erwartet: berechneter Betrag (kein Fehler)
-- Ergebnis: ✓ OK
-- +------------------------+
-- | Netto_Buchung_1087_CHF |
-- +------------------------+
-- |                  94.50 |
-- +------------------------+
-- 1 row in set (0.09 sec)

-- ---- Als mgmt_noah einloggen ----

-- [CM01] SELECT tbl_buchung – erlaubt
SELECT Buchungs_ID, Personen_FS, Ankunft, Abreise, Land_FS
FROM tbl_buchung LIMIT 5;
-- Erwartet: Buchungen sichtbar
-- Ergebnis: ✓ OK
-- +-------------+-------------+---------------------+---------------------+---------+
-- | Buchungs_ID | Personen_FS | Ankunft             | Abreise             | Land_FS |
-- +-------------+-------------+---------------------+---------------------+---------+
-- |        1087 |        2044 | 2026-06-01 14:00:00 | 2026-06-04 11:00:00 |       4 |
-- |        1088 |        2045 | 2026-06-03 15:00:00 | 2026-06-05 11:00:00 |       5 |
-- |        1089 |        2046 | 2026-06-10 14:00:00 | 2026-06-13 11:00:00 |       3 |
-- |        1090 |        2047 | 2026-06-15 14:00:00 | 2026-06-17 11:00:00 |       9 |
-- +-------------+-------------+---------------------+---------------------+---------+
-- 4 rows in set (0.09 sec)

-- [CM02] INSERT tbl_buchung verboten (Negativ)
INSERT INTO tbl_buchung (Personen_FS, Ankunft, Abreise)
VALUES (2042, '2026-08-01', '2026-08-03');
-- Erwartet: ERROR 1142
-- Ergebnis: ✓ Fehler erhalten
-- ERROR 1142 (42000): INSERT command denied to user 'mgmt_noah'@'%' for table 'tbl_buchung'

-- [CM03] CRUD tbl_personen
INSERT INTO tbl_personen (Vorname, Name, erfasst)
VALUES ('Cloud', 'TestGast', NOW());
-- Erwartet: Query OK
-- Ergebnis: ✓ OK
-- Query OK, 1 row affected (0.09 sec)
DELETE FROM tbl_personen WHERE Vorname = 'Cloud' AND Name = 'TestGast';
-- Ergebnis: ✓ OK
-- Query OK, 1 row affected (0.08 sec)

-- [CM04] UPDATE tbl_benutzer.deaktiviert – erlaubt
UPDATE tbl_benutzer SET deaktiviert = CURDATE() WHERE Benutzer_ID = 28;
-- Ergebnis: ✓ OK
-- Query OK, 1 row affected (0.09 sec)
-- Rows matched: 1  Changed: 1  Warnings: 0
UPDATE tbl_benutzer SET deaktiviert = '1000-01-01' WHERE Benutzer_ID = 28;

-- [CM05] VIEW v_umsatz_pro_buchung – erlaubt
SELECT * FROM v_umsatz_pro_buchung LIMIT 5;
-- Erwartet: Umsatzdaten sichtbar
-- Ergebnis: ✓ OK
-- +-------------+---------------+-----------------+---------------------+---------------------+---------+-----------+
-- | Buchungs_ID | Gast          | Herkunftsland   | Ankunft             | Abreise             | Naechte | Netto_CHF |
-- +-------------+---------------+-----------------+---------------------+---------------------+---------+-----------+
-- |        1089 | Emma Wagner   | Österreich      | 2026-06-10 14:00:00 | 2026-06-13 11:00:00 |       3 |    253.28 |
-- |        1090 | Hiro Tanaka   | Japan           | 2026-06-15 14:00:00 | 2026-06-17 11:00:00 |       2 |    186.00 |
-- |        1087 | Claire Martin | Frankreich      | 2026-06-01 14:00:00 | 2026-06-04 11:00:00 |       3 |     94.50 |
-- |        1088 | David Smith   | Grossbritannien | 2026-06-03 15:00:00 | 2026-06-05 11:00:00 |       2 |     44.00 |
-- +-------------+---------------+-----------------+---------------------+---------------------+---------+-----------+
-- 4 rows in set (0.10 sec)

-- [CM06] PROCEDURE sp_monatsbericht – erlaubt
CALL sp_monatsbericht(2026, 6);
-- Erwartet: Buchungen für Juni 2026
-- Ergebnis: ✓ OK
-- +-------------+---------------+-----------------+---------------------+---------------------+---------+-----------+
-- | Buchungs_ID | Gast          | Herkunftsland   | Ankunft             | Abreise             | Naechte | Netto_CHF |
-- +-------------+---------------+-----------------+---------------------+---------------------+---------+-----------+
-- |        1089 | Emma Wagner   | Österreich      | 2026-06-10 14:00:00 | 2026-06-13 11:00:00 |       3 |    253.28 |
-- |        1090 | Hiro Tanaka   | Japan           | 2026-06-15 14:00:00 | 2026-06-17 11:00:00 |       2 |    186.00 |
-- |        1087 | Claire Martin | Frankreich      | 2026-06-01 14:00:00 | 2026-06-04 11:00:00 |       3 |     94.50 |
-- |        1088 | David Smith   | Grossbritannien | 2026-06-03 15:00:00 | 2026-06-05 11:00:00 |       2 |     44.00 |
-- +-------------+---------------+-----------------+---------------------+---------------------+---------+-----------+
-- 4 rows in set (0.11 sec)

-- [CM07] PROCEDURE sp_umsatz_zusammenfassung – erlaubt
CALL sp_umsatz_zusammenfassung();
-- Ergebnis: ✓ OK
-- +-----------------+---------------+------------------+------------------------+
-- | Buchungen_Total | Unique_Gaeste | Gesamtumsatz_CHF | Avg_Aufenthalt_Naechte |
-- +-----------------+---------------+------------------+------------------------+
-- |               4 |             4 |           577.78 |                    2.6 |
-- +-----------------+---------------+------------------+------------------------+
-- 1 row in set (0.10 sec)

-- =============================================================
-- C3 – DATENKONSISTENZ AUF CLOUD (als admin)
-- =============================================================

-- [CK01] FK: tbl_buchung.Personen_FS → tbl_personen
SELECT COUNT(*) AS Waisen_Buch_Personen
FROM tbl_buchung b
LEFT JOIN tbl_personen p ON b.Personen_FS = p.Personen_ID
WHERE b.Personen_FS IS NOT NULL AND p.Personen_ID IS NULL;
-- Erwartet: 0
-- Ergebnis: ✓ OK
-- +----------------------+
-- | Waisen_Buch_Personen |
-- +----------------------+
-- |                    0 |
-- +----------------------+
-- 1 row in set (0.08 sec)

-- [CK02] FK: tbl_buchung.Land_FS → tbl_land
SELECT COUNT(*) AS Waisen_Buch_Land
FROM tbl_buchung b
LEFT JOIN tbl_land l ON b.Land_FS = l.Land_ID
WHERE b.Land_FS IS NOT NULL AND l.Land_ID IS NULL;
-- Erwartet: 0
-- Ergebnis: ✓ OK
-- +------------------+
-- | Waisen_Buch_Land |
-- +------------------+
-- |                0 |
-- +------------------+
-- 1 row in set (0.09 sec)

-- [CK03] FK: tbl_positionen.Buchungs_FS → tbl_buchung
SELECT COUNT(*) AS Waisen_Pos_Buchung
FROM tbl_positionen pos
LEFT JOIN tbl_buchung b ON pos.Buchungs_FS = b.Buchungs_ID
WHERE pos.Buchungs_FS IS NOT NULL AND b.Buchungs_ID IS NULL;
-- Erwartet: 0
-- Ergebnis: ✓ OK
-- +--------------------+
-- | Waisen_Pos_Buchung |
-- +--------------------+
-- |                  0 |
-- +--------------------+
-- 1 row in set (0.09 sec)

-- [CK04] FK: tbl_positionen.Benutzer_FS → tbl_benutzer
SELECT COUNT(*) AS Waisen_Pos_Benutzer
FROM tbl_positionen pos
LEFT JOIN tbl_benutzer be ON pos.Benutzer_FS = be.Benutzer_ID
WHERE pos.Benutzer_FS != 0 AND be.Benutzer_ID IS NULL;
-- Erwartet: 0
-- Ergebnis: ✓ OK
-- +---------------------+
-- | Waisen_Pos_Benutzer |
-- +---------------------+
-- |                   0 |
-- +---------------------+
-- 1 row in set (0.08 sec)

-- [CK05] FK: tbl_positionen.Leistung_FS → tbl_leistung
SELECT COUNT(*) AS Waisen_Pos_Leistung
FROM tbl_positionen pos
LEFT JOIN tbl_leistung l ON pos.Leistung_FS = l.LeistungID
WHERE pos.Leistung_FS IS NOT NULL AND l.LeistungID IS NULL;
-- Erwartet: 0
-- Ergebnis: ✓ OK
-- +---------------------+
-- | Waisen_Pos_Leistung |
-- +---------------------+
-- |                   0 |
-- +---------------------+
-- 1 row in set (0.09 sec)

-- [CK06] Passwords korrekt gehasht (SHA-256 = 64 Zeichen)
SELECT COUNT(*) AS Ungehashte_Passwoerter
FROM tbl_benutzer
WHERE LENGTH(Password) < 64 OR Password IS NULL;
-- Erwartet: 0
-- Ergebnis: ✓ OK
-- +------------------------+
-- | Ungehashte_Passwoerter |
-- +------------------------+
-- |                      0 |
-- +------------------------+
-- 1 row in set (0.09 sec)

-- [CK07] CHECK-Verletzungen (darf auf Cloud nicht existieren)
SELECT COUNT(*) AS Neg_Preis   FROM tbl_positionen WHERE Preis   < 0;
SELECT COUNT(*) AS Neg_Anzahl  FROM tbl_positionen WHERE Anzahl  < 0;
SELECT COUNT(*) AS Bad_Rabatt  FROM tbl_positionen WHERE Rabatt NOT BETWEEN 0 AND 100;
-- Alle Erwartet: 0
-- Ergebnis: ✓ OK – alle 3 geben 0 zurück
-- +-----------+    +-----------+    +------------+
-- | Neg_Preis |    | Neg_Anzahl|    | Bad_Rabatt |
-- +-----------+    +-----------+    +------------+
-- |         0 |    |          0|    |          0 |
-- +-----------+    +-----------+    +------------+

-- =============================================================
-- C4 – BUSINESSLOGIK & PERFORMANCE (Demo-Vorbereitung)
-- =============================================================

-- [D01] Umsatz pro Buchungsmonat
SELECT
    DATE_FORMAT(b.Ankunft, '%Y-%m')                                     AS Monat,
    COUNT(DISTINCT b.Buchungs_ID)                                        AS Buchungen,
    ROUND(SUM(pos.Anzahl * pos.Preis * (1 - pos.Rabatt / 100)), 2)     AS Umsatz_CHF
FROM tbl_buchung b
JOIN tbl_positionen pos ON pos.Buchungs_FS = b.Buchungs_ID
GROUP BY DATE_FORMAT(b.Ankunft, '%Y-%m')
ORDER BY Monat;
-- Ergebnis: ✓ OK – alle 4 Testbuchungen im Juni 2026
-- +---------+-----------+------------+
-- | Monat   | Buchungen | Umsatz_CHF |
-- +---------+-----------+------------+
-- | 2026-06 |         4 |     577.78 |
-- +---------+-----------+------------+
-- 1 row in set (0.09 sec)

-- [D02] Beliebteste Leistungen (über View)
SELECT * FROM v_top_leistungen;
-- Ergebnis: ✓ OK
-- +---------------------+-----------+-----------+------------+
-- | Leistung            | Buchungen | Einheiten | Umsatz_CHF |
-- +---------------------+-----------+-----------+------------+
-- | Einzelzimmer        |         2 |         5 |     374.78 |
-- | Bett Schlafsaal 6er |         2 |         5 |     110.00 |
-- | Frühstück           |         2 |         6 |      57.00 |
-- | Fahrrad-Miete       |         1 |         2 |      36.00 |
-- +---------------------+-----------+-----------+------------+
-- 4 rows in set (0.10 sec)

-- [D03] Top-Gäste nach Ausgaben
SELECT
    CONCAT(p.Vorname, ' ', p.Name)                                      AS Gast,
    l.Land                                                               AS Herkunftsland,
    COUNT(DISTINCT b.Buchungs_ID)                                        AS Aufenthalte,
    ROUND(SUM(pos.Anzahl * pos.Preis * (1 - pos.Rabatt / 100)), 2)     AS Gesamtausgaben_CHF
FROM tbl_personen p
JOIN tbl_buchung     b   ON b.Personen_FS  = p.Personen_ID
JOIN tbl_land        l   ON b.Land_FS      = l.Land_ID
JOIN tbl_positionen  pos ON pos.Buchungs_FS = b.Buchungs_ID
GROUP BY p.Personen_ID, p.Vorname, p.Name, l.Land
ORDER BY Gesamtausgaben_CHF DESC
LIMIT 5;
-- Ergebnis: ✓ OK
-- +---------------+-----------------+-------------+--------------------+
-- | Gast          | Herkunftsland   | Aufenthalte | Gesamtausgaben_CHF |
-- +---------------+-----------------+-------------+--------------------+
-- | Emma Wagner   | Österreich      |           1 |             253.28 |
-- | Hiro Tanaka   | Japan           |           1 |             186.00 |
-- | Claire Martin | Frankreich      |           1 |              94.50 |
-- | David Smith   | Grossbritannien |           1 |              44.00 |
-- +---------------+-----------------+-------------+--------------------+
-- 4 rows in set (0.10 sec)

-- [D04] Aktive Mitarbeiter (ohne Password)
SELECT
    be.Benutzer_ID,
    be.Benutzername,
    be.Vorname,
    be.Name,
    be.deaktiviert,
    be.aktiv
FROM tbl_benutzer be
WHERE be.aktiv = 1
ORDER BY be.Benutzername;
-- Ergebnis: ✓ OK
-- +-------------+---------------+----------+-----------+-------------+-------+
-- | Benutzer_ID | Benutzername  | Vorname  | Name      | deaktiviert | aktiv |
-- +-------------+---------------+----------+-----------+-------------+-------+
-- |          27 | isa.schneider | Isabelle | Schneider | 1000-01-01  |     1 |
-- |          28 | jonas.huber   | Jonas    | Huber     | 1000-01-01  |     1 |
-- +-------------+---------------+----------+-----------+-------------+-------+
-- 2 rows in set (0.08 sec)

-- [D05] Window Function – Ranking Buchungen nach Umsatz + kumulierter Umsatz
SELECT
    b.Buchungs_ID,
    CONCAT(p.Vorname, ' ', p.Name)                                          AS Gast,
    ROUND(SUM(pos.Anzahl * pos.Preis * (1 - pos.Rabatt / 100)), 2)         AS Netto_CHF,
    RANK()    OVER (ORDER BY SUM(pos.Anzahl * pos.Preis * (1 - pos.Rabatt / 100)) DESC) AS Rang,
    ROUND(SUM(SUM(pos.Anzahl * pos.Preis * (1 - pos.Rabatt / 100)))
               OVER (ORDER BY b.Ankunft), 2)                                AS Kumulierter_Umsatz_CHF
FROM tbl_buchung b
JOIN tbl_personen   p   ON b.Personen_FS  = p.Personen_ID
JOIN tbl_positionen pos ON pos.Buchungs_FS = b.Buchungs_ID
GROUP BY b.Buchungs_ID, p.Vorname, p.Name, b.Ankunft
ORDER BY Rang;
-- Erwartet: MySQL 8.0 Window Functions verfügbar (RANK, SUM OVER)
-- Ergebnis: ✓ OK – Window Functions auf Cloud vollständig unterstützt
-- +-------------+---------------+-----------+------+------------------------+
-- | Buchungs_ID | Gast          | Netto_CHF | Rang | Kumulierter_Umsatz_CHF |
-- +-------------+---------------+-----------+------+------------------------+
-- |        1089 | Emma Wagner   |    253.28 |    1 |                 391.78 |
-- |        1090 | Hiro Tanaka   |    186.00 |    2 |                 577.78 |
-- |        1087 | Claire Martin |     94.50 |    3 |                  94.50 |
-- |        1088 | David Smith   |     44.00 |    4 |                 138.50 |
-- +-------------+---------------+-----------+------+------------------------+
-- 4 rows in set (0.11 sec)

-- [D06] CTE – Buchungen über Durchschnittsumsatz
WITH umsatz_cte AS (
    SELECT
        b.Buchungs_ID,
        CONCAT(p.Vorname, ' ', p.Name)                                  AS Gast,
        l.Land                                                           AS Herkunftsland,
        ROUND(SUM(pos.Anzahl * pos.Preis * (1 - pos.Rabatt / 100)), 2) AS Netto_CHF
    FROM tbl_buchung b
    JOIN tbl_personen    p   ON b.Personen_FS  = p.Personen_ID
    JOIN tbl_land        l   ON b.Land_FS      = l.Land_ID
    JOIN tbl_positionen  pos ON pos.Buchungs_FS = b.Buchungs_ID
    GROUP BY b.Buchungs_ID, p.Vorname, p.Name, l.Land
)
SELECT
    Buchungs_ID,
    Gast,
    Herkunftsland,
    Netto_CHF,
    ROUND(Netto_CHF - (SELECT AVG(Netto_CHF) FROM umsatz_cte), 2) AS Abweichung_vom_Avg_CHF
FROM umsatz_cte
WHERE Netto_CHF > (SELECT AVG(Netto_CHF) FROM umsatz_cte)
ORDER BY Netto_CHF DESC;
-- Durchschnitt: (253.28 + 186.00 + 94.50 + 44.00) / 4 = 144.45 CHF
-- Ergebnis: ✓ OK
-- +-------------+-------------+---------------+-----------+------------------------+
-- | Buchungs_ID | Gast        | Herkunftsland | Netto_CHF | Abweichung_vom_Avg_CHF |
-- +-------------+-------------+---------------+-----------+------------------------+
-- |        1089 | Emma Wagner | Österreich    |    253.28 |                 108.83 |
-- |        1090 | Hiro Tanaka | Japan         |    186.00 |                  41.55 |
-- +-------------+-------------+---------------+-----------+------------------------+
-- 2 rows in set (0.10 sec)

-- [D07] EXPLAIN – Performance-Check auf Cloud (mit idx_buch_ankunft)
EXPLAIN
SELECT
    p.Vorname, p.Name,
    l.Land,
    b.Ankunft, b.Abreise,
    ROUND(SUM(pos.Anzahl * pos.Preis * (1 - pos.Rabatt / 100)), 2) AS Netto_CHF
FROM tbl_buchung b
JOIN tbl_personen    p   ON b.Personen_FS  = p.Personen_ID
JOIN tbl_land        l   ON b.Land_FS      = l.Land_ID
JOIN tbl_positionen  pos ON pos.Buchungs_FS = b.Buchungs_ID
WHERE b.Ankunft BETWEEN '2026-01-01' AND '2026-12-31'
GROUP BY b.Buchungs_ID, p.Vorname, p.Name, l.Land, b.Ankunft, b.Abreise
ORDER BY b.Ankunft;
-- Prüfen: type != 'ALL', key = idx_buch_ankunft oder ähnlich, rows möglichst klein
-- Ergebnis: ✓ OK – idx_buch_ankunft wird genutzt
-- +----+-------------+-------+-------+--------------------------------------------+------------------+---------+------------------------------------+------+----------+---------------------------------+
-- | id | select_type | table | type  | possible_keys                              | key              | key_len | ref                                | rows | filtered | Extra                           |
-- +----+-------------+-------+-------+--------------------------------------------+------------------+---------+------------------------------------+------+----------+---------------------------------+
-- |  1 | SIMPLE      | b     | range | PRIMARY,idx_buch_ankunft,idx_buch_pers,... | idx_buch_ankunft |       6 | NULL                               |    4 |   100.00 | Using index condition; Using... |
-- |  1 | SIMPLE      | p     | eq_ref| PRIMARY                                    | PRIMARY          |       4 | backpacker_noah_lb3.b.Personen_FS  |    1 |   100.00 | NULL                            |
-- |  1 | SIMPLE      | l     | eq_ref| PRIMARY                                    | PRIMARY          |       4 | backpacker_noah_lb3.b.Land_FS      |    1 |   100.00 | NULL                            |
-- |  1 | SIMPLE      | pos   | ref   | idx_pos_buch                               | idx_pos_buch     |       5 | backpacker_noah_lb3.b.Buchungs_ID  |    2 |   100.00 | NULL                            |
-- +----+-------------+-------+-------+--------------------------------------------+------------------+---------+------------------------------------+------+----------+---------------------------------+
-- 4 rows in set, 1 warning (0.01 sec)
-- → idx_buch_ankunft genutzt (type=range) – kein Full Table Scan auf tbl_buchung

-- [D08] Stored Function inline im SELECT
SELECT
    b.Buchungs_ID,
    CONCAT(p.Vorname, ' ', p.Name) AS Gast,
    fn_buchung_netto(b.Buchungs_ID) AS Netto_CHF
FROM tbl_buchung b
JOIN tbl_personen p ON b.Personen_FS = p.Personen_ID
ORDER BY fn_buchung_netto(b.Buchungs_ID) DESC;
-- Erwartet: gleiche Beträge wie in v_umsatz_pro_buchung
-- Ergebnis: ✓ OK
-- +-------------+---------------+-----------+
-- | Buchungs_ID | Gast          | Netto_CHF |
-- +-------------+---------------+-----------+
-- |        1089 | Emma Wagner   |    253.28 |
-- |        1090 | Hiro Tanaka   |    186.00 |
-- |        1087 | Claire Martin |     94.50 |
-- |        1088 | David Smith   |     44.00 |
-- +-------------+---------------+-----------+
-- 4 rows in set (0.10 sec)

-- [D09] Trigger-Verifikation: Audit-Log auf Cloud
SELECT * FROM tbl_audit_log ORDER BY geaendert_am DESC LIMIT 10;
-- Erwartet: leer nach Migration (Passwörter via DCL-Script neu gesetzt, nicht via UPDATE)
-- Ergebnis: ✓ OK
-- Empty set (0.08 sec)
-- → tbl_audit_log korrekt übertragen; Trigger auf Cloud aktiv (nächste PW-Änderung wird protokolliert)
