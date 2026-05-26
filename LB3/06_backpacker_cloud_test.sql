-- =============================================================
-- 06_backpacker_cloud_test.sql
-- Autor: Noah Bachmann | TBZ M141 LB3
-- =============================================================
-- Beschreibung:
--   Testprotokolle nach Migration auf AWS RDS.
--   Entspricht MS D (3.3 – Testen).
--   Vergleich: lokale DB vs. Cloud-DB.
-- =============================================================
-- Verbindung zur Cloud:
--   mysql -h <endpoint>.rds.amazonaws.com -u ben_noah -p backpacker_noah_lb3
--   mysql -h <endpoint>.rds.amazonaws.com -u mgmt_noah -p backpacker_noah_lb3
-- =============================================================

USE backpacker_noah_lb3;

-- =============================================================
-- C1 – MIGRATIONSKONSISTENZ (als admin / root)
-- =============================================================

-- [C01] Server-Infos anzeigen (für Screenshot-Dokumentation)
SELECT
    @@hostname                   AS Cloud_Host,
    @@version                    AS MySQL_Version,
    @@character_set_server       AS Charset,
    @@collation_server           AS Collation,
    @@innodb_buffer_pool_size    AS InnoDB_BufferPool;

-- [C02] SSL-Status prüfen (muss auf Cloud aktiv sein)
SHOW STATUS LIKE 'Ssl_cipher';
-- Erwartet: Ssl_cipher = z.B. 'TLS_AES_256_GCM_SHA384' (nicht leer)

-- [C03] Tabellen-Überblick
SELECT
    table_name                                              AS Tabelle,
    table_rows                                             AS Zeilen_est,
    engine,
    table_collation,
    ROUND((data_length + index_length) / 1024, 2)         AS KB
FROM information_schema.tables
WHERE table_schema = 'backpacker_noah_lb3'
ORDER BY table_name;

-- [C04] Zeilenzahlen (Vergleich mit lokal)
SELECT 'tbl_land'      AS Tabelle, COUNT(*) AS Zeilen FROM tbl_land
UNION ALL SELECT 'tbl_leistung',   COUNT(*) FROM tbl_leistung
UNION ALL SELECT 'tbl_personen',   COUNT(*) FROM tbl_personen
UNION ALL SELECT 'tbl_benutzer',   COUNT(*) FROM tbl_benutzer
UNION ALL SELECT 'tbl_buchung',    COUNT(*) FROM tbl_buchung
UNION ALL SELECT 'tbl_positionen', COUNT(*) FROM tbl_positionen;
-- Erwartet: identisch mit lokalen Werten

-- [C05] FK-Constraints vorhanden
SELECT
    constraint_name,
    table_name,
    column_name,
    referenced_table_name,
    referenced_column_name
FROM information_schema.key_column_usage
WHERE table_schema = 'backpacker_noah_lb3'
  AND referenced_table_name IS NOT NULL
ORDER BY table_name, constraint_name;
-- Erwartet: 5 FK-Constraints

-- [C06] Indizes vorhanden
SELECT table_name, index_name, column_name
FROM information_schema.statistics
WHERE table_schema = 'backpacker_noah_lb3'
ORDER BY table_name, index_name;

-- =============================================================
-- C2 – ROLLENTESTS AUF CLOUD (gleich wie lokal)
-- =============================================================

-- ---- Als ben_noah auf Cloud einloggen ----

-- [CP01] SELECT tbl_personen
SELECT PersID, Vorname, Nachname, Email FROM tbl_personen LIMIT 5;
-- Erwartet: Daten sichtbar

-- [CP02] SELECT tbl_benutzer ohne Passwort
SELECT BenID, Benutzername, deaktiviert FROM tbl_benutzer;
-- Erwartet: OK

-- [CP03] Passwort-Sperre (Negativ)
SELECT Passwort FROM tbl_benutzer WHERE BenID = 1;
-- Erwartet: ERROR 1143

-- [CP04] INSERT tbl_buchung
INSERT INTO tbl_buchung (BenID, Datum, Bemerkung)
VALUES (1, CURDATE(), 'Cloud-Test-Buchung');
-- Erwartet: Query OK

-- [CP05] SELECT der neuen Buchung
SELECT * FROM tbl_buchung ORDER BY BuchID DESC LIMIT 1;
-- Erwartet: Cloud-Test-Buchung sichtbar

-- [CP06] DELETE der Test-Buchung
DELETE FROM tbl_buchung WHERE Bemerkung = 'Cloud-Test-Buchung';
-- Erwartet: Query OK

-- ---- Als mgmt_noah auf Cloud einloggen ----

-- [CM01] SELECT tbl_buchung
SELECT * FROM tbl_buchung LIMIT 3;
-- Erwartet: Buchungen sichtbar

-- [CM02] INSERT tbl_buchung verboten (Negativ)
INSERT INTO tbl_buchung (BenID, Datum) VALUES (1, CURDATE());
-- Erwartet: ERROR 1142

-- [CM03] CRUD tbl_personen
INSERT INTO tbl_personen (Vorname, Nachname, LandID) VALUES ('Cloud', 'Test', 1);
-- Erwartet: Query OK
DELETE FROM tbl_personen WHERE Vorname = 'Cloud' AND Nachname = 'Test';
-- Erwartet: Query OK

-- =============================================================
-- C3 – DATENKONSISTENZ AUF CLOUD
-- =============================================================

-- [CK01] FK-Integrität vollständig
SELECT COUNT(*) AS Waisen_Pers_Land
FROM tbl_personen p
LEFT JOIN tbl_land l ON p.LandID = l.LandID
WHERE p.LandID IS NOT NULL AND l.LandID IS NULL;
-- Erwartet: 0

SELECT COUNT(*) AS Waisen_Ben_Pers
FROM tbl_benutzer b
LEFT JOIN tbl_personen p ON b.PersID = p.PersID
WHERE p.PersID IS NULL;
-- Erwartet: 0

SELECT COUNT(*) AS Waisen_Pos
FROM tbl_positionen pos
LEFT JOIN tbl_buchung  b ON pos.BuchID  = b.BuchID
LEFT JOIN tbl_personen p ON pos.PersID  = p.PersID
LEFT JOIN tbl_leistung l ON pos.LeistID = l.LeistID
WHERE b.BuchID IS NULL OR p.PersID IS NULL OR l.LeistID IS NULL;
-- Erwartet: 0

-- [CK02] Passwörter korrekt (alle SHA-256-Hash)
SELECT COUNT(*) AS Unsichere_Passwoerter
FROM tbl_benutzer WHERE LENGTH(Passwort) < 64;
-- Erwartet: 0

-- =============================================================
-- C4 – BUSINESSLOGIK-ABFRAGEN (Demo-Vorbereitung)
-- =============================================================

-- [D01] Umsatz pro Buchungsmonat
SELECT
    DATE_FORMAT(b.Datum, '%Y-%m') AS Monat,
    COUNT(DISTINCT b.BuchID)       AS Buchungen,
    SUM(pos.Anzahl * pos.EinzelPreis) AS Umsatz_CHF
FROM tbl_buchung b
JOIN tbl_positionen pos ON b.BuchID = pos.BuchID
GROUP BY DATE_FORMAT(b.Datum, '%Y-%m')
ORDER BY Monat;

-- [D02] Beliebteste Leistungen
SELECT
    l.Bezeichnung,
    SUM(pos.Anzahl) AS Gebuchte_Einheiten,
    SUM(pos.Anzahl * pos.EinzelPreis) AS Umsatz_CHF
FROM tbl_leistung l
JOIN tbl_positionen pos ON l.LeistID = pos.LeistID
GROUP BY l.LeistID, l.Bezeichnung
ORDER BY Umsatz_CHF DESC;

-- [D03] Gäste mit meisten Übernachtungen
SELECT
    p.Vorname, p.Nachname,
    la.Bezeichnung AS Herkunftsland,
    COUNT(pos.PosID)               AS Positionen,
    SUM(pos.Anzahl * pos.EinzelPreis) AS Gesamtausgaben_CHF
FROM tbl_personen p
JOIN tbl_land la ON p.LandID = la.LandID
JOIN tbl_positionen pos ON pos.PersID = p.PersID
GROUP BY p.PersID, p.Vorname, p.Nachname, la.Bezeichnung
ORDER BY Gesamtausgaben_CHF DESC
LIMIT 5;

-- [D04] Aktive Mitarbeiter-Logins
SELECT
    be.BenID, be.Benutzername,
    p.Vorname, p.Nachname,
    be.deaktiviert
FROM tbl_benutzer be
JOIN tbl_personen p ON be.PersID = p.PersID
ORDER BY be.deaktiviert, be.Benutzername;

-- [D05] EXPLAIN – Performance-Check auf Cloud
EXPLAIN
SELECT p.Vorname, p.Nachname,
       SUM(pos.Anzahl * pos.EinzelPreis) AS Umsatz
FROM tbl_personen p
JOIN tbl_positionen pos ON pos.PersID = p.PersID
JOIN tbl_buchung    b   ON pos.BuchID = b.BuchID
WHERE b.Datum BETWEEN '2026-01-01' AND '2026-12-31'
GROUP BY p.PersID, p.Vorname, p.Nachname;
-- Prüfen: type != 'ALL', Indizes genutzt
