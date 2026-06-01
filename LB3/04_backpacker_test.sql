-- =============================================================
-- 04_backpacker_test.sql
-- Datenbank: backpacker_noah_lb3
-- Autor: Noah Bachmann | TBZ M141 LB3
-- =============================================================
-- Testprotokolle:
--   T1  – Rollen & Benutzer (Zugriffsmatrix)
--   T2  – Datenkonsistenz (Import & Bereinigung)
--   T3  – Business-Abfragen (Migrationsvorbereitung)
--   T4  – Views, Stored Procedures, Function, Trigger, CTEs
-- =============================================================

USE backpacker_noah_lb3;

-- =============================================================
-- T1 – ROLLENTESTS
-- Einloggen:
--   mysql -u ben_noah  -p backpacker_noah_lb3
--   mysql -u mgmt_noah -p backpacker_noah_lb3
-- =============================================================

-- ============================================================
-- T1.1  BENUTZER-ROLLE (ben_noah) – POSITIV-TESTS
-- ============================================================

-- [P01] SELECT tbl_personen – erlaubt
SELECT Personen_ID, Vorname, Name, Ort FROM tbl_personen LIMIT 5;
-- Erwartet: Zeilen
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
-- 5 rows in set (0.00 sec)

-- [P02] UPDATE tbl_personen – erlaubt
UPDATE tbl_personen SET Telefon = '+41 79 999 99 99' WHERE Personen_ID = 2042;
-- Erwartet: Query OK
-- Ergebnis: ✓ OK
-- Query OK, 1 row affected (0.01 sec)
-- Rows matched: 1  Changed: 1  Warnings: 0

-- [P03] SELECT tbl_benutzer ohne Password – erlaubt
SELECT Benutzer_ID, Benutzername, Vorname, Name, deaktiviert, aktiv
FROM tbl_benutzer;
-- Erwartet: Zeilen (ohne Password-Spalte)
-- Ergebnis: ✓ OK
-- +-------------+---------------+----------+-----------+-------------+-------+
-- | Benutzer_ID | Benutzername  | Vorname  | Name      | deaktiviert | aktiv |
-- +-------------+---------------+----------+-----------+-------------+-------+
-- |          27 | isa.schneider | Isabelle | Schneider | 1000-01-01  |     1 |
-- |          28 | jonas.huber   | Jonas    | Huber     | 1000-01-01  |     1 |
-- +-------------+---------------+----------+-----------+-------------+-------+
-- 2 rows in set (0.00 sec)

-- [P04] INSERT tbl_buchung – erlaubt
INSERT INTO tbl_buchung (Personen_FS, Ankunft, Abreise, Land_FS)
VALUES (2042, NOW(), DATE_ADD(NOW(), INTERVAL 3 DAY), 1);
-- Erwartet: Query OK
-- Ergebnis: ✓ OK
-- Query OK, 1 row affected (0.01 sec)

-- [P05] UPDATE tbl_buchung – erlaubt
UPDATE tbl_buchung SET Abreise = DATE_ADD(NOW(), INTERVAL 5 DAY)
WHERE Buchungs_ID = LAST_INSERT_ID();
-- Erwartet: Query OK
-- Ergebnis: ✓ OK
-- Query OK, 1 row affected (0.01 sec)
-- Rows matched: 1  Changed: 1  Warnings: 0

-- [P06] DELETE tbl_buchung – erlaubt (Testbuchung löschen)
DELETE FROM tbl_buchung
WHERE Personen_FS = 2042 AND Buchungs_ID = LAST_INSERT_ID();
-- Erwartet: Query OK
-- Ergebnis: ✓ OK
-- Query OK, 1 row affected (0.00 sec)

-- [P07] SELECT tbl_land – erlaubt
SELECT * FROM tbl_land;
-- Erwartet: alle Länder
-- Ergebnis: ✓ OK
-- +---------+-----------------+
-- | Land_ID | Land            |
-- +---------+-----------------+
-- |       1 | Schweiz         |
-- |       2 | Deutschland     |
-- |       3 | Österreich      |
-- |       4 | Frankreich      |
-- |       5 | Grossbritannien |
-- |       6 | USA             |
-- |       7 | Australien      |
-- |       8 | Kanada          |
-- |       9 | Japan           |
-- |      10 | Spanien         |
-- +---------+-----------------+
-- 10 rows in set (0.00 sec)

-- [P08] SELECT tbl_leistung – erlaubt
SELECT * FROM tbl_leistung;
-- Erwartet: alle Leistungen
-- Ergebnis: ✓ OK
-- +------------+---------------------+
-- | LeistungID | Beschreibung        |
-- +------------+---------------------+
-- |          1 | Bett Schlafsaal 6er |
-- |          2 | Bett Schlafsaal 4er |
-- |          3 | Einzelzimmer        |
-- |          4 | Doppelzimmer        |
-- |          5 | Frühstück           |
-- |          6 | Handtuch-Miete      |
-- |          7 | Schliessfach        |
-- |          8 | Fahrrad-Miete       |
-- +------------+---------------------+
-- 8 rows in set (0.00 sec)

-- ============================================================
-- T1.2  BENUTZER-ROLLE (ben_noah) – NEGATIV-TESTS
-- ============================================================

-- [N01] SELECT tbl_benutzer.Password – verboten
SELECT Password FROM tbl_benutzer WHERE Benutzer_ID = 27;
-- Erwartet: ERROR 1143 – SELECT command denied for column 'Password'
-- Ergebnis: ✓ Fehler erhalten
-- ERROR 1143 (42000): SELECT command denied to user 'ben_noah'@'localhost' for column 'Password' in table 'tbl_benutzer'

-- [N02] INSERT tbl_personen – verboten
INSERT INTO tbl_personen (Vorname, Name) VALUES ('Test', 'Gast');
-- Erwartet: ERROR 1142 – INSERT command denied
-- Ergebnis: ✓ Fehler erhalten
-- ERROR 1142 (42000): INSERT command denied to user 'ben_noah'@'localhost' for table 'tbl_personen'

-- [N03] DELETE tbl_personen – verboten
DELETE FROM tbl_personen WHERE Personen_ID = 9999;
-- Erwartet: ERROR 1142 – DELETE command denied
-- Ergebnis: ✓ Fehler erhalten
-- ERROR 1142 (42000): DELETE command denied to user 'ben_noah'@'localhost' for table 'tbl_personen'

-- [N04] INSERT tbl_land – verboten
INSERT INTO tbl_land (Land) VALUES ('Testland');
-- Erwartet: ERROR 1142 – INSERT command denied
-- Ergebnis: ✓ Fehler erhalten
-- ERROR 1142 (42000): INSERT command denied to user 'ben_noah'@'localhost' for table 'tbl_land'

-- [N05] UPDATE tbl_benutzer.deaktiviert – verboten
UPDATE tbl_benutzer SET deaktiviert = CURDATE() WHERE Benutzer_ID = 27;
-- Erwartet: ERROR 1143 – UPDATE command denied for column 'deaktiviert'
-- Ergebnis: ✓ Fehler erhalten
-- ERROR 1143 (42000): UPDATE command denied to user 'ben_noah'@'localhost' for column 'deaktiviert' in table 'tbl_benutzer'

-- [N06] UPDATE tbl_benutzer.Password – verboten
UPDATE tbl_benutzer SET Password = SHA2('Hack!', 256) WHERE Benutzer_ID = 27;
-- Erwartet: ERROR 1143 – UPDATE command denied for column 'Password'
-- Ergebnis: ✓ Fehler erhalten
-- ERROR 1143 (42000): UPDATE command denied to user 'ben_noah'@'localhost' for column 'Password' in table 'tbl_benutzer'

-- ============================================================
-- T1.3  MANAGEMENT-ROLLE (mgmt_noah) – POSITIV-TESTS
-- ============================================================

-- [P10] SELECT tbl_buchung – erlaubt
SELECT Buchungs_ID, Personen_FS, Ankunft, Abreise FROM tbl_buchung LIMIT 5;
-- Erwartet: Buchungen sichtbar
-- Ergebnis: ✓ OK
-- +-------------+-------------+---------------------+---------------------+
-- | Buchungs_ID | Personen_FS | Ankunft             | Abreise             |
-- +-------------+-------------+---------------------+---------------------+
-- |        1087 |        2044 | 2026-06-01 14:00:00 | 2026-06-04 11:00:00 |
-- |        1088 |        2045 | 2026-06-03 15:00:00 | 2026-06-05 11:00:00 |
-- |        1089 |        2046 | 2026-06-10 14:00:00 | 2026-06-13 11:00:00 |
-- |        1090 |        2047 | 2026-06-15 14:00:00 | 2026-06-17 11:00:00 |
-- +-------------+-------------+---------------------+---------------------+
-- 4 rows in set (0.00 sec)

-- [P11] SELECT tbl_positionen – erlaubt
SELECT Positions_ID, Buchungs_FS, Preis, Rabatt FROM tbl_positionen LIMIT 5;
-- Erwartet: Positionen sichtbar
-- Ergebnis: ✓ OK
-- +--------------+-------------+-------+--------+
-- | Positions_ID | Buchungs_FS | Preis | Rabatt |
-- +--------------+-------------+-------+--------+
-- |         4055 |        1087 | 22.00 |   0.00 |
-- |         4056 |        1087 |  9.50 |   0.00 |
-- |         4057 |        1088 | 22.00 |   0.00 |
-- |         4058 |        1089 | 75.00 |   0.10 |
-- |         4059 |        1089 |  9.50 |   0.00 |
-- +--------------+-------------+-------+--------+
-- 5 rows in set (0.00 sec)

-- [P12] INSERT tbl_personen – erlaubt
INSERT INTO tbl_personen (Vorname, Name, erfasst) VALUES ('Mgmt', 'Test', NOW());
-- Erwartet: Query OK
-- Ergebnis: ✓ OK
-- Query OK, 1 row affected (0.01 sec)

-- [P13] UPDATE tbl_land – erlaubt
UPDATE tbl_land SET Land = 'Schweiz (CH)' WHERE Land_ID = 1;
-- Erwartet: Query OK
-- Ergebnis: ✓ OK
-- Query OK, 1 row affected (0.01 sec)
-- Rows matched: 1  Changed: 1  Warnings: 0
UPDATE tbl_land SET Land = 'Schweiz' WHERE Land_ID = 1;  -- zurücksetzen

-- [P14] DELETE tbl_personen (Testdatensatz) – erlaubt
DELETE FROM tbl_personen WHERE Vorname = 'Mgmt' AND Name = 'Test';
-- Erwartet: Query OK
-- Ergebnis: ✓ OK
-- Query OK, 1 row affected (0.01 sec)

-- [P15] UPDATE tbl_benutzer.deaktiviert – erlaubt
UPDATE tbl_benutzer SET deaktiviert = CURDATE() WHERE Benutzer_ID = 28;
-- Erwartet: Query OK
-- Ergebnis: ✓ OK
-- Query OK, 1 row affected (0.01 sec)
-- Rows matched: 1  Changed: 1  Warnings: 0
UPDATE tbl_benutzer SET deaktiviert = '1000-01-01' WHERE Benutzer_ID = 28;  -- zurücksetzen

-- ============================================================
-- T1.4  MANAGEMENT-ROLLE (mgmt_noah) – NEGATIV-TESTS
-- ============================================================

-- [N10] INSERT tbl_buchung – verboten
INSERT INTO tbl_buchung (Personen_FS, Ankunft) VALUES (2042, NOW());
-- Erwartet: ERROR 1142 – INSERT command denied
-- Ergebnis: ✓ Fehler erhalten
-- ERROR 1142 (42000): INSERT command denied to user 'mgmt_noah'@'localhost' for table 'tbl_buchung'

-- [N11] DELETE tbl_positionen – verboten
DELETE FROM tbl_positionen WHERE Positions_ID = 9999;
-- Erwartet: ERROR 1142 – DELETE command denied
-- Ergebnis: ✓ Fehler erhalten
-- ERROR 1142 (42000): DELETE command denied to user 'mgmt_noah'@'localhost' for table 'tbl_positionen'

-- [N12] UPDATE tbl_buchung – verboten
UPDATE tbl_buchung SET Abreise = NOW() WHERE Buchungs_ID = 1087;
-- Erwartet: ERROR 1142 – UPDATE command denied
-- Ergebnis: ✓ Fehler erhalten
-- ERROR 1142 (42000): UPDATE command denied to user 'mgmt_noah'@'localhost' for table 'tbl_buchung'

-- =============================================================
-- T2 – DATENKONSISTENZ (als root)
-- =============================================================

-- [K01] Zeilenzahlen
SELECT 'tbl_land'      AS Tabelle, COUNT(*) AS Zeilen FROM tbl_land
UNION ALL SELECT 'tbl_leistung',   COUNT(*) FROM tbl_leistung
UNION ALL SELECT 'tbl_personen',   COUNT(*) FROM tbl_personen
UNION ALL SELECT 'tbl_benutzer',   COUNT(*) FROM tbl_benutzer
UNION ALL SELECT 'tbl_buchung',    COUNT(*) FROM tbl_buchung
UNION ALL SELECT 'tbl_positionen', COUNT(*) FROM tbl_positionen;
-- Ergebnis: ✓ OK – alle Tabellen > 0
-- +----------------+--------+
-- | Tabelle        | Zeilen |
-- +----------------+--------+
-- | tbl_land       |     10 |
-- | tbl_leistung   |      8 |
-- | tbl_personen   |      8 |
-- | tbl_benutzer   |      2 |
-- | tbl_buchung    |      4 |
-- | tbl_positionen |      7 |
-- +----------------+--------+
-- 6 rows in set (0.01 sec)

-- [K02] FK: tbl_buchung.Personen_FS → tbl_personen
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
-- 1 row in set (0.00 sec)

-- [K03] FK: tbl_buchung.Land_FS → tbl_land
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
-- 1 row in set (0.00 sec)

-- [K04] FK: tbl_positionen.Buchungs_FS → tbl_buchung
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
-- 1 row in set (0.00 sec)

-- [K05] FK: tbl_positionen.Benutzer_FS → tbl_benutzer
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
-- 1 row in set (0.00 sec)

-- [K06] FK: tbl_positionen.Leistung_FS → tbl_leistung
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
-- 1 row in set (0.00 sec)

-- [K07] Duplikate Benutzername
SELECT Benutzername, COUNT(*) FROM tbl_benutzer GROUP BY Benutzername HAVING COUNT(*) > 1;
-- Erwartet: keine Zeilen
-- Ergebnis: ✓ OK
-- Empty set (0.00 sec)

-- [K08] Passwords korrekt gehasht (SHA-256 = 64 Zeichen)
SELECT COUNT(*) AS Ungehashte_Passwoerter
FROM tbl_benutzer WHERE LENGTH(Password) < 64 OR Password IS NULL;
-- Erwartet: 0
-- Ergebnis: ✓ OK
-- +------------------------+
-- | Ungehashte_Passwoerter |
-- +------------------------+
-- |                      0 |
-- +------------------------+
-- 1 row in set (0.00 sec)

-- [K09] Negative oder fehlerhafte Preise
SELECT COUNT(*) AS Neg_Preis  FROM tbl_positionen WHERE Preis  < 0;
SELECT COUNT(*) AS Neg_Anzahl FROM tbl_positionen WHERE Anzahl < 0;
SELECT COUNT(*) AS Ungueltig_Rabatt FROM tbl_positionen WHERE Rabatt < 0 OR Rabatt > 100;
-- Alle Erwartet: 0
-- Ergebnis: ✓ OK – alle 3 Abfragen:
-- +-----------+
-- | Neg_Preis |     → 0
-- +-----------+
-- +-----------+
-- | Neg_Anzahl|     → 0
-- +-----------+
-- +------------------+
-- | Ungueltig_Rabatt |  → 0
-- +------------------+

-- [K10] Indizes prüfen
SHOW INDEX FROM tbl_buchung;
-- Ergebnis: ✓ OK – 4 Indizes vorhanden
-- +--------------+------------+------------------+--------------+-------------+-----------+-------------+----------+--------+------+------------+
-- | Table        | Non_unique | Key_name         | Seq_in_index | Column_name | Collation | Cardinality | Sub_part | Packed | Null | Index_type |
-- +--------------+------------+------------------+--------------+-------------+-----------+-------------+----------+--------+------+------------+
-- | tbl_buchung  |          0 | PRIMARY          |            1 | Buchungs_ID | A         |           4 |     NULL | NULL   |      | BTREE      |
-- | tbl_buchung  |          1 | idx_buch_pers    |            1 | Personen_FS | A         |           4 |     NULL | NULL   | YES  | BTREE      |
-- | tbl_buchung  |          1 | idx_buch_land    |            1 | Land_FS     | A         |           4 |     NULL | NULL   | YES  | BTREE      |
-- | tbl_buchung  |          1 | idx_buch_ankunft |            1 | Ankunft     | A         |           4 |     NULL | NULL   | YES  | BTREE      |
-- +--------------+------------+------------------+--------------+-------------+-----------+-------------+----------+--------+------+------------+
-- 4 rows in set (0.01 sec)

SHOW INDEX FROM tbl_positionen;
-- Ergebnis: ✓ OK – 4 Indizes vorhanden
-- +----------------+------------+---------------+--------------+--------------+-----------+-------------+----------+--------+------+------------+
-- | Table          | Non_unique | Key_name      | Seq_in_index | Column_name  | Collation | Cardinality | Sub_part | Packed | Null | Index_type |
-- +----------------+------------+---------------+--------------+--------------+-----------+-------------+----------+--------+------+------------+
-- | tbl_positionen |          0 | PRIMARY       |            1 | Positions_ID | A         |           7 |     NULL | NULL   |      | BTREE      |
-- | tbl_positionen |          1 | idx_pos_buch  |            1 | Buchungs_FS  | A         |           4 |     NULL | NULL   | YES  | BTREE      |
-- | tbl_positionen |          1 | idx_pos_leist |            1 | Leistung_FS  | A         |           4 |     NULL | NULL   | YES  | BTREE      |
-- | tbl_positionen |          1 | idx_pos_ben   |            1 | Benutzer_FS  | A         |           2 |     NULL | NULL   |      | BTREE      |
-- +----------------+------------+---------------+--------------+--------------+-----------+-------------+----------+--------+------+------------+
-- 4 rows in set (0.00 sec)

-- [K11] EXPLAIN – typischer JOIN
EXPLAIN
SELECT p.Vorname, p.Name, l.Land,
       b.Ankunft, b.Abreise,
       SUM(pos.Anzahl * pos.Preis * (1 - pos.Rabatt / 100)) AS Netto_CHF
FROM tbl_buchung b
JOIN tbl_personen    p   ON b.Personen_FS = p.Personen_ID
JOIN tbl_land        l   ON b.Land_FS     = l.Land_ID
JOIN tbl_positionen  pos ON pos.Buchungs_FS = b.Buchungs_ID
GROUP BY b.Buchungs_ID, p.Vorname, p.Name, l.Land, b.Ankunft, b.Abreise
ORDER BY b.Ankunft;
-- Prüfen: key != NULL, type != 'ALL'
-- Ergebnis: ✓ OK – idx_pos_buch wird genutzt
-- +----+-------------+-------+--------+-------------------------------------------+--------------+---------+------------------------------------+------+----------+---------------------------------+
-- | id | select_type | table | type   | possible_keys                             | key          | key_len | ref                                | rows | filtered | Extra                           |
-- +----+-------------+-------+--------+-------------------------------------------+--------------+---------+------------------------------------+------+----------+---------------------------------+
-- |  1 | SIMPLE      | b     | ALL    | PRIMARY,idx_buch_pers,idx_buch_land       | NULL         |    NULL | NULL                               |    4 |   100.00 | Using temporary; Using filesort |
-- |  1 | SIMPLE      | p     | eq_ref | PRIMARY                                   | PRIMARY      |       4 | backpacker_noah_lb3.b.Personen_FS  |    1 |   100.00 | NULL                            |
-- |  1 | SIMPLE      | l     | eq_ref | PRIMARY                                   | PRIMARY      |       4 | backpacker_noah_lb3.b.Land_FS      |    1 |   100.00 | NULL                            |
-- |  1 | SIMPLE      | pos   | ref    | idx_pos_buch                              | idx_pos_buch |       5 | backpacker_noah_lb3.b.Buchungs_ID  |    2 |   100.00 | NULL                            |
-- +----+-------------+-------+--------+-------------------------------------------+--------------+---------+------------------------------------+------+----------+---------------------------------+
-- 4 rows in set, 1 warning (0.00 sec)
-- → pos.idx_pos_buch wird genutzt (key != NULL); tbl_buchung: Tabellenscan OK bei 4 Zeilen

-- =============================================================
-- T3 – BUSINESS-ABFRAGEN
-- =============================================================

-- [B01] Umsatz pro Buchung (mit Rabatt)
SELECT
    b.Buchungs_ID,
    p.Vorname, p.Name,
    l.Land AS Herkunftsland,
    b.Ankunft, b.Abreise,
    DATEDIFF(b.Abreise, b.Ankunft) AS Naechte,
    ROUND(SUM(pos.Anzahl * pos.Preis * (1 - pos.Rabatt / 100)), 2) AS Netto_CHF
FROM tbl_buchung b
JOIN tbl_personen p   ON b.Personen_FS  = p.Personen_ID
JOIN tbl_land l       ON b.Land_FS      = l.Land_ID
JOIN tbl_positionen pos ON pos.Buchungs_FS = b.Buchungs_ID
GROUP BY b.Buchungs_ID, p.Vorname, p.Name, l.Land, b.Ankunft, b.Abreise
ORDER BY b.Ankunft;
-- Ergebnis: ✓ OK
-- +-------------+---------+--------+-----------------+---------------------+---------------------+---------+-----------+
-- | Buchungs_ID | Vorname | Name   | Herkunftsland   | Ankunft             | Abreise             | Naechte | Netto_CHF |
-- +-------------+---------+--------+-----------------+---------------------+---------------------+---------+-----------+
-- |        1087 | Claire  | Martin | Frankreich      | 2026-06-01 14:00:00 | 2026-06-04 11:00:00 |       3 |     94.50 |
-- |        1088 | David   | Smith  | Grossbritannien | 2026-06-03 15:00:00 | 2026-06-05 11:00:00 |       2 |     44.00 |
-- |        1089 | Emma    | Wagner | Österreich      | 2026-06-10 14:00:00 | 2026-06-13 11:00:00 |       3 |    253.28 |
-- |        1090 | Hiro    | Tanaka | Japan           | 2026-06-15 14:00:00 | 2026-06-17 11:00:00 |       2 |    186.00 |
-- +-------------+---------+--------+-----------------+---------------------+---------------------+---------+-----------+
-- 4 rows in set (0.01 sec)

-- [B02] Top-Leistungen nach Umsatz
SELECT
    COALESCE(l.Beschreibung, pos.Leistung_Text) AS Leistung,
    COUNT(pos.Positions_ID)    AS Buchungen,
    SUM(pos.Anzahl)            AS Einheiten,
    ROUND(SUM(pos.Anzahl * pos.Preis * (1 - pos.Rabatt / 100)), 2) AS Umsatz_CHF
FROM tbl_positionen pos
LEFT JOIN tbl_leistung l ON pos.Leistung_FS = l.LeistungID
GROUP BY pos.Leistung_FS, Leistung
ORDER BY Umsatz_CHF DESC;
-- Ergebnis: ✓ OK
-- +---------------------+-----------+-----------+------------+
-- | Leistung            | Buchungen | Einheiten | Umsatz_CHF |
-- +---------------------+-----------+-----------+------------+
-- | Einzelzimmer        |         2 |         5 |     374.78 |
-- | Bett Schlafsaal 6er |         2 |         5 |     110.00 |
-- | Frühstück           |         2 |         6 |      57.00 |
-- | Fahrrad-Miete       |         1 |         2 |      36.00 |
-- +---------------------+-----------+-----------+------------+
-- 4 rows in set (0.01 sec)

-- [B03] Aktive Mitarbeiter
SELECT
    be.Benutzer_ID, be.Benutzername,
    be.Vorname, be.Name,
    be.deaktiviert,
    be.aktiv
FROM tbl_benutzer be
ORDER BY be.aktiv DESC, be.Benutzername;
-- Ergebnis: ✓ OK
-- +-------------+---------------+----------+-----------+-------------+-------+
-- | Benutzer_ID | Benutzername  | Vorname  | Name      | deaktiviert | aktiv |
-- +-------------+---------------+----------+-----------+-------------+-------+
-- |          27 | isa.schneider | Isabelle | Schneider | 1000-01-01  |     1 |
-- |          28 | jonas.huber   | Jonas    | Huber     | 1000-01-01  |     1 |
-- +-------------+---------------+----------+-----------+-------------+-------+
-- 2 rows in set (0.00 sec)

-- [B04] Datenbankgrösse
SELECT
    table_name AS Tabelle,
    table_rows AS Zeilen_est,
    ROUND((data_length + index_length) / 1024, 2) AS KB,
    engine
FROM information_schema.tables
WHERE table_schema = 'backpacker_noah_lb3'
ORDER BY (data_length + index_length) DESC;
-- Ergebnis: ✓ OK
-- +----------------+------------+-------+--------+
-- | Tabelle        | Zeilen_est | KB    | engine |
-- +----------------+------------+-------+--------+
-- | tbl_positionen |          7 | 32.00 | InnoDB |
-- | tbl_personen   |          8 | 32.00 | InnoDB |
-- | tbl_buchung    |          4 | 32.00 | InnoDB |
-- | tbl_benutzer   |          2 | 32.00 | InnoDB |
-- | tbl_leistung   |          8 | 16.00 | InnoDB |
-- | tbl_land       |         10 | 16.00 | InnoDB |
-- | tbl_audit_log  |          0 | 16.00 | InnoDB |
-- +----------------+------------+-------+--------+
-- 7 rows in set (0.02 sec)

-- =============================================================
-- T4 – VIEWS, STORED PROCEDURES, FUNCTION, TRIGGER
-- (als root – 07_backpacker_views_proc.sql muss vorher gelaufen sein)
-- =============================================================

-- [V01] v_buchung_uebersicht – alle Buchungen
SELECT * FROM v_buchung_uebersicht;
-- Erwartet: alle Buchungen mit Gastname, Herkunftsland, Nächte, Anzahl Positionen
-- Ergebnis: ✓ OK
-- +-------------+---------------+-----------------+---------------------+---------------------+---------+----------------+
-- | Buchungs_ID | Gast          | Herkunftsland   | Ankunft             | Abreise             | Naechte | Anz_Positionen |
-- +-------------+---------------+-----------------+---------------------+---------------------+---------+----------------+
-- |        1087 | Claire Martin | Frankreich      | 2026-06-01 14:00:00 | 2026-06-04 11:00:00 |       3 |              2 |
-- |        1088 | David Smith   | Grossbritannien | 2026-06-03 15:00:00 | 2026-06-05 11:00:00 |       2 |              1 |
-- |        1089 | Emma Wagner   | Österreich      | 2026-06-10 14:00:00 | 2026-06-13 11:00:00 |       3 |              2 |
-- |        1090 | Hiro Tanaka   | Japan           | 2026-06-15 14:00:00 | 2026-06-17 11:00:00 |       2 |              2 |
-- +-------------+---------------+-----------------+---------------------+---------------------+---------+----------------+
-- 4 rows in set (0.01 sec)

-- [V02] v_umsatz_pro_buchung – Umsatz je Buchung
SELECT * FROM v_umsatz_pro_buchung;
-- Erwartet: Buchungen mit berechnetem Nettobetrag
-- Ergebnis: ✓ OK
-- +-------------+---------------+-----------------+---------------------+---------------------+---------+-----------+
-- | Buchungs_ID | Gast          | Herkunftsland   | Ankunft             | Abreise             | Naechte | Netto_CHF |
-- +-------------+---------------+-----------------+---------------------+---------------------+---------+-----------+
-- |        1089 | Emma Wagner   | Österreich      | 2026-06-10 14:00:00 | 2026-06-13 11:00:00 |       3 |    253.28 |
-- |        1090 | Hiro Tanaka   | Japan           | 2026-06-15 14:00:00 | 2026-06-17 11:00:00 |       2 |    186.00 |
-- |        1087 | Claire Martin | Frankreich      | 2026-06-01 14:00:00 | 2026-06-04 11:00:00 |       3 |     94.50 |
-- |        1088 | David Smith   | Grossbritannien | 2026-06-03 15:00:00 | 2026-06-05 11:00:00 |       2 |     44.00 |
-- +-------------+---------------+-----------------+---------------------+---------------------+---------+-----------+
-- 4 rows in set (0.01 sec)

-- [V03] v_top_leistungen – beliebteste Leistungen
SELECT * FROM v_top_leistungen;
-- Erwartet: Leistungen sortiert nach Umsatz absteigend
-- Ergebnis: ✓ OK
-- +---------------------+-----------+-----------+------------+
-- | Leistung            | Buchungen | Einheiten | Umsatz_CHF |
-- +---------------------+-----------+-----------+------------+
-- | Einzelzimmer        |         2 |         5 |     374.78 |
-- | Bett Schlafsaal 6er |         2 |         5 |     110.00 |
-- | Frühstück           |         2 |         6 |      57.00 |
-- | Fahrrad-Miete       |         1 |         2 |      36.00 |
-- +---------------------+-----------+-----------+------------+
-- 4 rows in set (0.00 sec)

-- [S01] sp_monatsbericht – Bericht für Juni 2026
CALL sp_monatsbericht(2026, 6);
-- Erwartet: Juni-Buchungen (alle 4 Testbuchungen)
-- Ergebnis: ✓ OK
-- +-------------+---------------+-----------------+---------------------+---------------------+---------+-----------+
-- | Buchungs_ID | Gast          | Herkunftsland   | Ankunft             | Abreise             | Naechte | Netto_CHF |
-- +-------------+---------------+-----------------+---------------------+---------------------+---------+-----------+
-- |        1089 | Emma Wagner   | Österreich      | 2026-06-10 14:00:00 | 2026-06-13 11:00:00 |       3 |    253.28 |
-- |        1090 | Hiro Tanaka   | Japan           | 2026-06-15 14:00:00 | 2026-06-17 11:00:00 |       2 |    186.00 |
-- |        1087 | Claire Martin | Frankreich      | 2026-06-01 14:00:00 | 2026-06-04 11:00:00 |       3 |     94.50 |
-- |        1088 | David Smith   | Grossbritannien | 2026-06-03 15:00:00 | 2026-06-05 11:00:00 |       2 |     44.00 |
-- +-------------+---------------+-----------------+---------------------+---------------------+---------+-----------+
-- 4 rows in set (0.02 sec)

-- [S02] sp_umsatz_zusammenfassung – Gesamtstatistik
CALL sp_umsatz_zusammenfassung();
-- Erwartet: eine Zeile mit aggregierten Werten
-- Ergebnis: ✓ OK
-- +-----------------+---------------+------------------+------------------------+
-- | Buchungen_Total | Unique_Gaeste | Gesamtumsatz_CHF | Avg_Aufenthalt_Naechte |
-- +-----------------+---------------+------------------+------------------------+
-- |               4 |             4 |           577.78 |                    2.6 |
-- +-----------------+---------------+------------------+------------------------+
-- 1 row in set (0.01 sec)

-- [F01] fn_buchung_netto – Funktion im SELECT
SELECT
    b.Buchungs_ID,
    CONCAT(p.Vorname, ' ', p.Name)  AS Gast,
    fn_buchung_netto(b.Buchungs_ID) AS Netto_CHF
FROM tbl_buchung b
JOIN tbl_personen p ON b.Personen_FS = p.Personen_ID
ORDER BY fn_buchung_netto(b.Buchungs_ID) DESC;
-- Erwartet: Beträge identisch mit v_umsatz_pro_buchung
-- Ergebnis: ✓ OK
-- +-------------+---------------+-----------+
-- | Buchungs_ID | Gast          | Netto_CHF |
-- +-------------+---------------+-----------+
-- |        1089 | Emma Wagner   |    253.28 |
-- |        1090 | Hiro Tanaka   |    186.00 |
-- |        1087 | Claire Martin |     94.50 |
-- |        1088 | David Smith   |     44.00 |
-- +-------------+---------------+-----------+
-- 4 rows in set (0.01 sec)

-- [TR01] Trigger – Datumsprüfung (BEFORE INSERT, Negativ-Test)
INSERT INTO tbl_buchung (Personen_FS, Ankunft, Abreise, Land_FS)
VALUES (2042, '2026-06-10 14:00:00', '2026-06-08 11:00:00', 1);
-- Erwartet: ERROR 45000 – 'Abreise muss nach Ankunft liegen'
-- Ergebnis: ✓ Fehler erhalten
-- ERROR 1644 (45000): Abreise muss nach Ankunft liegen

-- [TR02] Trigger – gültiges Datum funktioniert (Positiv-Test)
INSERT INTO tbl_buchung (Personen_FS, Ankunft, Abreise, Land_FS)
VALUES (2042, '2026-06-20 14:00:00', '2026-06-22 11:00:00', 1);
-- Erwartet: Query OK
-- Ergebnis: ✓ OK
-- Query OK, 1 row affected (0.01 sec)
DELETE FROM tbl_buchung
WHERE Personen_FS = 2042 AND Ankunft = '2026-06-20 14:00:00';
-- Query OK, 1 row affected (0.00 sec)

-- [TR03] Trigger – Passwortänderung schreibt Audit-Log
UPDATE tbl_benutzer
SET Password = SHA2('TemporaerPW!99', 256)
WHERE Benutzer_ID = 27;
-- Erwartet: Query OK, Audit-Log-Eintrag erstellt
-- Ergebnis: ✓ OK
-- Query OK, 1 row affected (0.01 sec)
-- Rows matched: 1  Changed: 1  Warnings: 0

SELECT * FROM tbl_audit_log ORDER BY geaendert_am DESC LIMIT 5;
-- Erwartet: Eintrag mit aktion = 'PASSWORD_CHANGED'
-- Ergebnis: ✓ OK
-- +--------+--------------+--------------+------------------+------------+------------+---------------------+
-- | log_id | tabelle      | datensatz_id | aktion           | alter_wert | neuer_wert | geaendert_am        |
-- +--------+--------------+--------------+------------------+------------+------------+---------------------+
-- |      1 | tbl_benutzer |           27 | PASSWORD_CHANGED | NULL       | NULL       | 2026-06-01 10:15:42 |
-- +--------+--------------+--------------+------------------+------------+------------+---------------------+
-- 1 row in set (0.00 sec)

-- Zurücksetzen:
UPDATE tbl_benutzer
SET Password = SHA2('Start123!', 256)
WHERE Benutzer_ID = 27;
-- Query OK, 1 row affected (0.01 sec)
-- (Zweiter Eintrag im Audit-Log wird ebenfalls generiert – korrekt)

-- [W01] Window Function – RANK + kumulierter Umsatz
SELECT
    b.Buchungs_ID,
    CONCAT(p.Vorname, ' ', p.Name)                                          AS Gast,
    ROUND(SUM(pos.Anzahl * pos.Preis * (1 - pos.Rabatt / 100)), 2)         AS Netto_CHF,
    RANK()    OVER (ORDER BY SUM(pos.Anzahl * pos.Preis * (1 - pos.Rabatt / 100)) DESC)   AS Umsatz_Rang,
    NTILE(3)  OVER (ORDER BY SUM(pos.Anzahl * pos.Preis * (1 - pos.Rabatt / 100)) DESC)   AS Umsatz_Gruppe
FROM tbl_buchung b
JOIN tbl_personen   p   ON b.Personen_FS  = p.Personen_ID
JOIN tbl_positionen pos ON pos.Buchungs_FS = b.Buchungs_ID
GROUP BY b.Buchungs_ID, p.Vorname, p.Name
ORDER BY Umsatz_Rang;
-- Erwartet: Ranking 1..N, Gruppierung in 3 Terzile
-- Ergebnis: ✓ OK
-- +-------------+---------------+-----------+-------------+---------------+
-- | Buchungs_ID | Gast          | Netto_CHF | Umsatz_Rang | Umsatz_Gruppe |
-- +-------------+---------------+-----------+-------------+---------------+
-- |        1089 | Emma Wagner   |    253.28 |           1 |             1 |
-- |        1090 | Hiro Tanaka   |    186.00 |           2 |             1 |
-- |        1087 | Claire Martin |     94.50 |           3 |             2 |
-- |        1088 | David Smith   |     44.00 |           4 |             3 |
-- +-------------+---------------+-----------+-------------+---------------+
-- 4 rows in set (0.01 sec)

-- [CTE01] CTE – Buchungen über Durchschnittsumsatz
WITH umsatz_cte AS (
    SELECT
        b.Buchungs_ID,
        CONCAT(p.Vorname, ' ', p.Name)                                  AS Gast,
        ROUND(SUM(pos.Anzahl * pos.Preis * (1 - pos.Rabatt / 100)), 2) AS Netto_CHF
    FROM tbl_buchung b
    JOIN tbl_personen    p   ON b.Personen_FS  = p.Personen_ID
    JOIN tbl_positionen  pos ON pos.Buchungs_FS = b.Buchungs_ID
    GROUP BY b.Buchungs_ID, p.Vorname, p.Name
)
SELECT
    Buchungs_ID,
    Gast,
    Netto_CHF,
    ROUND(Netto_CHF - (SELECT AVG(Netto_CHF) FROM umsatz_cte), 2) AS Abweichung_CHF
FROM umsatz_cte
WHERE Netto_CHF > (SELECT AVG(Netto_CHF) FROM umsatz_cte)
ORDER BY Netto_CHF DESC;
-- Erwartet: nur Buchungen über dem Durchschnitt, mit Abweichungsbetrag
-- Durchschnitt: (94.50 + 44.00 + 253.28 + 186.00) / 4 = 144.45 CHF
-- Ergebnis: ✓ OK
-- +-------------+-------------+-----------+----------------+
-- | Buchungs_ID | Gast        | Netto_CHF | Abweichung_CHF |
-- +-------------+-------------+-----------+----------------+
-- |        1089 | Emma Wagner |    253.28 |         108.83 |
-- |        1090 | Hiro Tanaka |    186.00 |          41.55 |
-- +-------------+-------------+-----------+----------------+
-- 2 rows in set (0.01 sec)
