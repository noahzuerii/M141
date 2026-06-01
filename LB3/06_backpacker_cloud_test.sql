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

-- [C02] SSL-Status prüfen
SHOW STATUS LIKE 'Ssl_cipher';
-- Erwartet: Ssl_cipher enthält z.B. 'TLS_AES_256_GCM_SHA384' (nicht leer)

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

-- [C04] Zeilenzahlen – Vergleich mit lokalen Werten
SELECT 'tbl_land'       AS Tabelle, COUNT(*) AS Zeilen FROM tbl_land
UNION ALL SELECT 'tbl_leistung',    COUNT(*) FROM tbl_leistung
UNION ALL SELECT 'tbl_personen',    COUNT(*) FROM tbl_personen
UNION ALL SELECT 'tbl_benutzer',    COUNT(*) FROM tbl_benutzer
UNION ALL SELECT 'tbl_buchung',     COUNT(*) FROM tbl_buchung
UNION ALL SELECT 'tbl_positionen',  COUNT(*) FROM tbl_positionen
UNION ALL SELECT 'tbl_audit_log',   COUNT(*) FROM tbl_audit_log;
-- Erwartet: identisch mit lokalen Werten (tbl_audit_log = 0)

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

-- [C06] CHECK Constraints vorhanden
SELECT constraint_name, table_name, check_clause
FROM information_schema.check_constraints
WHERE constraint_schema = 'backpacker_noah_lb3'
ORDER BY table_name;
-- Erwartet: chk_pos_preis, chk_pos_anzahl, chk_pos_rabatt

-- [C07] Indizes vorhanden
SELECT table_name, index_name, column_name, non_unique
FROM information_schema.statistics
WHERE table_schema = 'backpacker_noah_lb3'
ORDER BY table_name, index_name;
-- Erwartet: PK + FK-Indizes + idx_buch_ankunft auf tbl_buchung

-- [C08] Views, Procedures, Functions, Trigger vorhanden
SELECT routine_name, routine_type
FROM information_schema.routines
WHERE routine_schema = 'backpacker_noah_lb3'
ORDER BY routine_type, routine_name;

SELECT trigger_name, event_manipulation, event_object_table, action_timing
FROM information_schema.triggers
WHERE trigger_schema = 'backpacker_noah_lb3';
-- Erwartet: sp_monatsbericht, sp_umsatz_zusammenfassung (PROCEDURE)
--           fn_buchung_netto (FUNCTION)
--           tr_buchung_datum_insert, tr_buchung_datum_update, tr_audit_pw_aenderung (TRIGGER)

-- =============================================================
-- C2 – ROLLENTESTS AUF CLOUD
-- (gleiche Logik wie lokal; Spaltennamen aus DDL)
-- =============================================================

-- ---- Als ben_noah einloggen ----

-- [CP01] SELECT tbl_personen – erlaubt
SELECT Personen_ID, Vorname, Name, Ort FROM tbl_personen LIMIT 5;
-- Erwartet: Zeilen sichtbar

-- [CP02] SELECT tbl_benutzer ohne Password – erlaubt
SELECT Benutzer_ID, Benutzername, Vorname, Name, deaktiviert, aktiv
FROM tbl_benutzer;
-- Erwartet: Zeilen (Password-Spalte nicht angefragt)

-- [CP03] SELECT Password – verboten (Negativ)
SELECT Password FROM tbl_benutzer WHERE Benutzer_ID = 27;
-- Erwartet: ERROR 1143 – SELECT command denied for column 'Password'

-- [CP04] INSERT tbl_buchung – erlaubt
INSERT INTO tbl_buchung (Personen_FS, Ankunft, Abreise, Land_FS)
VALUES (2042, '2026-07-01 14:00:00', '2026-07-04 11:00:00', 1);
-- Erwartet: Query OK

-- [CP05] SELECT neue Buchung
SELECT Buchungs_ID, Personen_FS, Ankunft, Abreise
FROM tbl_buchung ORDER BY Buchungs_ID DESC LIMIT 1;
-- Erwartet: die gerade eingefügte Testbuchung

-- [CP06] DELETE Testbuchung – erlaubt
DELETE FROM tbl_buchung
WHERE Personen_FS = 2042
  AND Ankunft = '2026-07-01 14:00:00';
-- Erwartet: Query OK

-- [CP07] VIEW v_buchung_uebersicht – erlaubt
SELECT * FROM v_buchung_uebersicht LIMIT 5;
-- Erwartet: Zeilen (View sichtbar für benutzer_rolle)

-- [CP08] VIEW v_umsatz_pro_buchung – verboten (Negativ)
SELECT * FROM v_umsatz_pro_buchung LIMIT 1;
-- Erwartet: ERROR 1142 – SELECT command denied (nur management_rolle)

-- [CP09] FUNCTION fn_buchung_netto – erlaubt
SELECT fn_buchung_netto(1087) AS Netto_Buchung_1087_CHF;
-- Erwartet: berechneter Betrag (kein Fehler)

-- ---- Als mgmt_noah einloggen ----

-- [CM01] SELECT tbl_buchung – erlaubt
SELECT Buchungs_ID, Personen_FS, Ankunft, Abreise, Land_FS
FROM tbl_buchung LIMIT 5;
-- Erwartet: Buchungen sichtbar

-- [CM02] INSERT tbl_buchung – verboten (Negativ)
INSERT INTO tbl_buchung (Personen_FS, Ankunft, Abreise)
VALUES (2042, '2026-08-01', '2026-08-03');
-- Erwartet: ERROR 1142 – INSERT command denied

-- [CM03] CRUD tbl_personen – erlaubt
INSERT INTO tbl_personen (Vorname, Name, erfasst)
VALUES ('Cloud', 'TestGast', NOW());
-- Erwartet: Query OK
DELETE FROM tbl_personen WHERE Vorname = 'Cloud' AND Name = 'TestGast';
-- Erwartet: Query OK

-- [CM04] UPDATE tbl_benutzer.deaktiviert – erlaubt
UPDATE tbl_benutzer SET deaktiviert = CURDATE() WHERE Benutzer_ID = 28;
-- Erwartet: Query OK
UPDATE tbl_benutzer SET deaktiviert = '1000-01-01' WHERE Benutzer_ID = 28;

-- [CM05] VIEW v_umsatz_pro_buchung – erlaubt
SELECT * FROM v_umsatz_pro_buchung LIMIT 5;
-- Erwartet: Umsatzdaten sichtbar

-- [CM06] PROCEDURE sp_monatsbericht – erlaubt
CALL sp_monatsbericht(2026, 6);
-- Erwartet: Buchungen für Juni 2026

-- [CM07] PROCEDURE sp_umsatz_zusammenfassung – erlaubt
CALL sp_umsatz_zusammenfassung();
-- Erwartet: Zusammenfassungszeile

-- =============================================================
-- C3 – DATENKONSISTENZ AUF CLOUD (als admin)
-- =============================================================

-- [CK01] FK: tbl_buchung.Personen_FS → tbl_personen
SELECT COUNT(*) AS Waisen_Buch_Personen
FROM tbl_buchung b
LEFT JOIN tbl_personen p ON b.Personen_FS = p.Personen_ID
WHERE b.Personen_FS IS NOT NULL AND p.Personen_ID IS NULL;
-- Erwartet: 0

-- [CK02] FK: tbl_buchung.Land_FS → tbl_land
SELECT COUNT(*) AS Waisen_Buch_Land
FROM tbl_buchung b
LEFT JOIN tbl_land l ON b.Land_FS = l.Land_ID
WHERE b.Land_FS IS NOT NULL AND l.Land_ID IS NULL;
-- Erwartet: 0

-- [CK03] FK: tbl_positionen.Buchungs_FS → tbl_buchung
SELECT COUNT(*) AS Waisen_Pos_Buchung
FROM tbl_positionen pos
LEFT JOIN tbl_buchung b ON pos.Buchungs_FS = b.Buchungs_ID
WHERE pos.Buchungs_FS IS NOT NULL AND b.Buchungs_ID IS NULL;
-- Erwartet: 0

-- [CK04] FK: tbl_positionen.Benutzer_FS → tbl_benutzer
SELECT COUNT(*) AS Waisen_Pos_Benutzer
FROM tbl_positionen pos
LEFT JOIN tbl_benutzer be ON pos.Benutzer_FS = be.Benutzer_ID
WHERE pos.Benutzer_FS != 0 AND be.Benutzer_ID IS NULL;
-- Erwartet: 0

-- [CK05] FK: tbl_positionen.Leistung_FS → tbl_leistung
SELECT COUNT(*) AS Waisen_Pos_Leistung
FROM tbl_positionen pos
LEFT JOIN tbl_leistung l ON pos.Leistung_FS = l.LeistungID
WHERE pos.Leistung_FS IS NOT NULL AND l.LeistungID IS NULL;
-- Erwartet: 0

-- [CK06] Passwords korrekt gehasht (SHA-256 = 64 Zeichen)
SELECT COUNT(*) AS Ungehashte_Passwoerter
FROM tbl_benutzer
WHERE LENGTH(Password) < 64 OR Password IS NULL;
-- Erwartet: 0

-- [CK07] CHECK-Verletzungen (darf auf Cloud nicht existieren)
SELECT COUNT(*) AS Neg_Preis   FROM tbl_positionen WHERE Preis   < 0;
SELECT COUNT(*) AS Neg_Anzahl  FROM tbl_positionen WHERE Anzahl  < 0;
SELECT COUNT(*) AS Bad_Rabatt  FROM tbl_positionen WHERE Rabatt NOT BETWEEN 0 AND 100;
-- Alle Erwartet: 0

-- =============================================================
-- C4 – BUSINESSLOGIK & PERFORMANCE (Demo-Vorbereitung)
-- =============================================================

-- [D01] Umsatz pro Buchungsmonat (via Ankunft-Datum)
SELECT
    DATE_FORMAT(b.Ankunft, '%Y-%m')                                     AS Monat,
    COUNT(DISTINCT b.Buchungs_ID)                                        AS Buchungen,
    ROUND(SUM(pos.Anzahl * pos.Preis * (1 - pos.Rabatt / 100)), 2)     AS Umsatz_CHF
FROM tbl_buchung b
JOIN tbl_positionen pos ON pos.Buchungs_FS = b.Buchungs_ID
GROUP BY DATE_FORMAT(b.Ankunft, '%Y-%m')
ORDER BY Monat;

-- [D02] Beliebteste Leistungen (über View)
SELECT * FROM v_top_leistungen;

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

-- [D05] Window Function – Ranking Buchungen nach Umsatz
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

-- [D07] EXPLAIN – Performance-Check auf Cloud
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

-- [D08] Stored Function inline im SELECT
SELECT
    b.Buchungs_ID,
    CONCAT(p.Vorname, ' ', p.Name) AS Gast,
    fn_buchung_netto(b.Buchungs_ID) AS Netto_CHF
FROM tbl_buchung b
JOIN tbl_personen p ON b.Personen_FS = p.Personen_ID
ORDER BY fn_buchung_netto(b.Buchungs_ID) DESC;
-- Erwartet: gleiche Beträge wie in v_umsatz_pro_buchung

-- [D09] Trigger-Verifikation: Audit-Log auf Cloud
SELECT * FROM tbl_audit_log ORDER BY geaendert_am DESC LIMIT 10;
-- Erwartet: Einträge falls Passwörter nach Migration geändert wurden
