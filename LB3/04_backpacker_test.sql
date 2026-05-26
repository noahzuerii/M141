-- =============================================================
-- 04_backpacker_test.sql
-- Datenbank: backpacker_noah_lb3
-- Autor: Noah Bachmann | TBZ M141 LB3
-- =============================================================
-- Testprotokolle:
--   T1  – Rollen & Benutzer (Zugriffsmatrix)
--   T2  – Datenkonsistenz (Import & Bereinigung)
--   T3  – Business-Abfragen (Migrationsvorbereitung)
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

-- [P02] UPDATE tbl_personen – erlaubt
UPDATE tbl_personen SET Telefon = '+41 79 999 99 99' WHERE Personen_ID = 2042;
-- Erwartet: Query OK

-- [P03] SELECT tbl_benutzer ohne Password – erlaubt
SELECT Benutzer_ID, Benutzername, Vorname, Name, deaktiviert, aktiv
FROM tbl_benutzer;
-- Erwartet: Zeilen (ohne Password-Spalte)

-- [P04] INSERT tbl_buchung – erlaubt
INSERT INTO tbl_buchung (Personen_FS, Ankunft, Abreise, Land_FS)
VALUES (2042, NOW(), DATE_ADD(NOW(), INTERVAL 3 DAY), 1);
-- Erwartet: Query OK

-- [P05] UPDATE tbl_buchung – erlaubt
UPDATE tbl_buchung SET Abreise = DATE_ADD(NOW(), INTERVAL 5 DAY)
WHERE Buchungs_ID = LAST_INSERT_ID();
-- Erwartet: Query OK

-- [P06] DELETE tbl_buchung – erlaubt (Testbuchung löschen)
DELETE FROM tbl_buchung
WHERE Personen_FS = 2042 AND Buchungs_ID = LAST_INSERT_ID();
-- Erwartet: Query OK

-- [P07] SELECT tbl_land – erlaubt
SELECT * FROM tbl_land;
-- Erwartet: alle Länder

-- [P08] SELECT tbl_leistung – erlaubt
SELECT * FROM tbl_leistung;
-- Erwartet: alle Leistungen

-- ============================================================
-- T1.2  BENUTZER-ROLLE (ben_noah) – NEGATIV-TESTS
-- ============================================================

-- [N01] SELECT tbl_benutzer.Password – verboten
SELECT Password FROM tbl_benutzer WHERE Benutzer_ID = 27;
-- Erwartet: ERROR 1143 – SELECT command denied for column 'Password'

-- [N02] INSERT tbl_personen – verboten
INSERT INTO tbl_personen (Vorname, Name) VALUES ('Test', 'Gast');
-- Erwartet: ERROR 1142 – INSERT command denied

-- [N03] DELETE tbl_personen – verboten
DELETE FROM tbl_personen WHERE Personen_ID = 9999;
-- Erwartet: ERROR 1142 – DELETE command denied

-- [N04] INSERT tbl_land – verboten
INSERT INTO tbl_land (Land) VALUES ('Testland');
-- Erwartet: ERROR 1142 – INSERT command denied

-- [N05] UPDATE tbl_benutzer.deaktiviert – verboten
UPDATE tbl_benutzer SET deaktiviert = CURDATE() WHERE Benutzer_ID = 27;
-- Erwartet: ERROR 1143 – UPDATE command denied for column 'deaktiviert'

-- [N06] UPDATE tbl_benutzer.Password – verboten
UPDATE tbl_benutzer SET Password = SHA2('Hack!', 256) WHERE Benutzer_ID = 27;
-- Erwartet: ERROR 1143 – UPDATE command denied for column 'Password'

-- ============================================================
-- T1.3  MANAGEMENT-ROLLE (mgmt_noah) – POSITIV-TESTS
-- ============================================================

-- [P10] SELECT tbl_buchung – erlaubt
SELECT Buchungs_ID, Personen_FS, Ankunft, Abreise FROM tbl_buchung LIMIT 5;
-- Erwartet: Buchungen sichtbar

-- [P11] SELECT tbl_positionen – erlaubt
SELECT Positions_ID, Buchungs_FS, Preis, Rabatt FROM tbl_positionen LIMIT 5;
-- Erwartet: Positionen sichtbar

-- [P12] INSERT tbl_personen – erlaubt
INSERT INTO tbl_personen (Vorname, Name, erfasst) VALUES ('Mgmt', 'Test', NOW());
-- Erwartet: Query OK

-- [P13] UPDATE tbl_land – erlaubt
UPDATE tbl_land SET Land = 'Schweiz (CH)' WHERE Land_ID = 1;
-- Erwartet: Query OK
UPDATE tbl_land SET Land = 'Schweiz' WHERE Land_ID = 1;  -- zurücksetzen

-- [P14] DELETE tbl_personen (Testdatensatz) – erlaubt
DELETE FROM tbl_personen WHERE Vorname = 'Mgmt' AND Name = 'Test';
-- Erwartet: Query OK

-- [P15] UPDATE tbl_benutzer.deaktiviert – erlaubt
UPDATE tbl_benutzer SET deaktiviert = CURDATE() WHERE Benutzer_ID = 28;
-- Erwartet: Query OK
UPDATE tbl_benutzer SET deaktiviert = '1000-01-01' WHERE Benutzer_ID = 28;  -- zurücksetzen

-- ============================================================
-- T1.4  MANAGEMENT-ROLLE (mgmt_noah) – NEGATIV-TESTS
-- ============================================================

-- [N10] INSERT tbl_buchung – verboten
INSERT INTO tbl_buchung (Personen_FS, Ankunft) VALUES (2042, NOW());
-- Erwartet: ERROR 1142 – INSERT command denied

-- [N11] DELETE tbl_positionen – verboten
DELETE FROM tbl_positionen WHERE Positions_ID = 9999;
-- Erwartet: ERROR 1142 – DELETE command denied

-- [N12] UPDATE tbl_buchung – verboten
UPDATE tbl_buchung SET Abreise = NOW() WHERE Buchungs_ID = 1087;
-- Erwartet: ERROR 1142 – UPDATE command denied

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

-- [K02] FK: tbl_buchung.Personen_FS → tbl_personen
SELECT COUNT(*) AS Waisen_Buch_Personen
FROM tbl_buchung b
LEFT JOIN tbl_personen p ON b.Personen_FS = p.Personen_ID
WHERE b.Personen_FS IS NOT NULL AND p.Personen_ID IS NULL;
-- Erwartet: 0

-- [K03] FK: tbl_buchung.Land_FS → tbl_land
SELECT COUNT(*) AS Waisen_Buch_Land
FROM tbl_buchung b
LEFT JOIN tbl_land l ON b.Land_FS = l.Land_ID
WHERE b.Land_FS IS NOT NULL AND l.Land_ID IS NULL;
-- Erwartet: 0

-- [K04] FK: tbl_positionen.Buchungs_FS → tbl_buchung
SELECT COUNT(*) AS Waisen_Pos_Buchung
FROM tbl_positionen pos
LEFT JOIN tbl_buchung b ON pos.Buchungs_FS = b.Buchungs_ID
WHERE pos.Buchungs_FS IS NOT NULL AND b.Buchungs_ID IS NULL;
-- Erwartet: 0

-- [K05] FK: tbl_positionen.Benutzer_FS → tbl_benutzer
SELECT COUNT(*) AS Waisen_Pos_Benutzer
FROM tbl_positionen pos
LEFT JOIN tbl_benutzer be ON pos.Benutzer_FS = be.Benutzer_ID
WHERE pos.Benutzer_FS != 0 AND be.Benutzer_ID IS NULL;
-- Erwartet: 0

-- [K06] FK: tbl_positionen.Leistung_FS → tbl_leistung
SELECT COUNT(*) AS Waisen_Pos_Leistung
FROM tbl_positionen pos
LEFT JOIN tbl_leistung l ON pos.Leistung_FS = l.LeistungID
WHERE pos.Leistung_FS IS NOT NULL AND l.LeistungID IS NULL;
-- Erwartet: 0

-- [K07] Duplikate Benutzername
SELECT Benutzername, COUNT(*) FROM tbl_benutzer GROUP BY Benutzername HAVING COUNT(*) > 1;
-- Erwartet: keine Zeilen

-- [K08] Passwords korrekt gehasht (SHA-256 = 64 Zeichen)
SELECT COUNT(*) AS Ungehashte_Passwoerter
FROM tbl_benutzer WHERE LENGTH(Password) < 64 OR Password IS NULL;
-- Erwartet: 0

-- [K09] Negative oder fehlerhafte Preise
SELECT COUNT(*) AS Neg_Preis  FROM tbl_positionen WHERE Preis  < 0;
SELECT COUNT(*) AS Neg_Anzahl FROM tbl_positionen WHERE Anzahl < 0;
SELECT COUNT(*) AS Ungueltig_Rabatt FROM tbl_positionen WHERE Rabatt < 0 OR Rabatt > 100;
-- Alle Erwartet: 0

-- [K10] Indizes prüfen
SHOW INDEX FROM tbl_buchung;
SHOW INDEX FROM tbl_positionen;

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

-- [B03] Aktive Mitarbeiter
SELECT
    be.Benutzer_ID, be.Benutzername,
    be.Vorname, be.Name,
    be.deaktiviert,
    be.aktiv
FROM tbl_benutzer be
ORDER BY be.aktiv DESC, be.Benutzername;

-- [B04] Datenbankgrösse
SELECT
    table_name AS Tabelle,
    table_rows AS Zeilen_est,
    ROUND((data_length + index_length) / 1024, 2) AS KB,
    engine
FROM information_schema.tables
WHERE table_schema = 'backpacker_noah_lb3'
ORDER BY (data_length + index_length) DESC;
