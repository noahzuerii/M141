-- =============================================================
-- 07_backpacker_views_proc.sql
-- Datenbank: backpacker_noah_lb3
-- Autor: Noah Bachmann | TBZ M141 LB3
-- =============================================================
-- Beschreibung:
--   Erweiterte Datenbanklogik:
--     A) Views (v_buchung_uebersicht, v_umsatz_pro_buchung,
--               v_top_leistungen)
--     B) Stored Procedures (sp_monatsbericht, sp_umsatz_zusammenfassung)
--     C) Stored Function  (fn_buchung_netto)
--     D) Trigger (tr_buchung_datum_insert, tr_buchung_datum_update,
--                 tr_audit_pw_aenderung)
--     E) Grants für Rollen
--
-- Ausführungsreihenfolge:
--   01 → 02 → 03 → 04 → 07
--   (07 muss nach 02 laufen, damit Rollen für GRANT existieren)
--   (07 muss nach 01 laufen, damit tbl_audit_log existiert)
-- =============================================================

USE backpacker_noah_lb3;

-- =============================================================
-- A) VIEWS
-- =============================================================

-- ------------------------------------------------------------
-- v_buchung_uebersicht
-- Kompakte Buchungsübersicht mit Gastname und Aufenthaltsdauer.
-- Beide Rollen dürfen lesen (Frontdesk + Management).
-- SQL SECURITY DEFINER: Benutzer braucht nur SELECT auf View.
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW v_buchung_uebersicht AS
SELECT
    b.Buchungs_ID,
    CONCAT(p.Vorname, ' ', p.Name)          AS Gast,
    l.Land                                  AS Herkunftsland,
    b.Ankunft,
    b.Abreise,
    DATEDIFF(b.Abreise, b.Ankunft)          AS Naechte,
    COUNT(pos.Positions_ID)                 AS Anz_Positionen
FROM tbl_buchung b
LEFT JOIN tbl_personen    p   ON b.Personen_FS  = p.Personen_ID
LEFT JOIN tbl_land        l   ON b.Land_FS      = l.Land_ID
LEFT JOIN tbl_positionen  pos ON pos.Buchungs_FS = b.Buchungs_ID
GROUP BY
    b.Buchungs_ID, p.Vorname, p.Name,
    l.Land, b.Ankunft, b.Abreise
ORDER BY b.Ankunft;

-- ------------------------------------------------------------
-- v_umsatz_pro_buchung
-- Nettoumsatz je Buchung (Preis × Anzahl × (1 − Rabatt/100)).
-- Nur Management-Rolle darf lesen.
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW v_umsatz_pro_buchung AS
SELECT
    b.Buchungs_ID,
    CONCAT(p.Vorname, ' ', p.Name)                                      AS Gast,
    l.Land                                                               AS Herkunftsland,
    b.Ankunft,
    b.Abreise,
    DATEDIFF(b.Abreise, b.Ankunft)                                      AS Naechte,
    ROUND(SUM(pos.Anzahl * pos.Preis * (1 - pos.Rabatt / 100)), 2)     AS Netto_CHF
FROM tbl_buchung b
JOIN tbl_personen    p   ON b.Personen_FS  = p.Personen_ID
JOIN tbl_land        l   ON b.Land_FS      = l.Land_ID
JOIN tbl_positionen  pos ON pos.Buchungs_FS = b.Buchungs_ID
GROUP BY
    b.Buchungs_ID, p.Vorname, p.Name,
    l.Land, b.Ankunft, b.Abreise
ORDER BY Netto_CHF DESC;

-- ------------------------------------------------------------
-- v_top_leistungen
-- Beliebteste Leistungen nach Umsatz, absteigend sortiert.
-- Beide Rollen dürfen lesen.
-- Leistung_Text als Fallback, falls keine FK-Referenz vorhanden.
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW v_top_leistungen AS
SELECT
    COALESCE(l.Beschreibung, pos.Leistung_Text)                         AS Leistung,
    COUNT(pos.Positions_ID)                                             AS Buchungen,
    SUM(pos.Anzahl)                                                     AS Einheiten,
    ROUND(SUM(pos.Anzahl * pos.Preis * (1 - pos.Rabatt / 100)), 2)    AS Umsatz_CHF
FROM tbl_positionen pos
LEFT JOIN tbl_leistung l ON pos.Leistung_FS = l.LeistungID
GROUP BY pos.Leistung_FS, COALESCE(l.Beschreibung, pos.Leistung_Text)
ORDER BY Umsatz_CHF DESC;

-- =============================================================
-- B) STORED PROCEDURES
-- =============================================================

-- ------------------------------------------------------------
-- sp_monatsbericht(p_jahr, p_monat)
-- Gibt alle Buchungen mit Umsatz für den gewählten Monat aus.
-- Nur Management-Rolle darf ausführen.
-- Beispiel: CALL sp_monatsbericht(2026, 6);
-- ------------------------------------------------------------
DELIMITER $$
CREATE PROCEDURE sp_monatsbericht(IN p_jahr INT, IN p_monat INT)
BEGIN
    SELECT
        b.Buchungs_ID,
        CONCAT(p.Vorname, ' ', p.Name)                                  AS Gast,
        l.Land                                                           AS Herkunftsland,
        b.Ankunft,
        b.Abreise,
        DATEDIFF(b.Abreise, b.Ankunft)                                  AS Naechte,
        ROUND(SUM(pos.Anzahl * pos.Preis * (1 - pos.Rabatt / 100)), 2) AS Netto_CHF
    FROM tbl_buchung b
    JOIN tbl_personen    p   ON b.Personen_FS  = p.Personen_ID
    JOIN tbl_land        l   ON b.Land_FS      = l.Land_ID
    JOIN tbl_positionen  pos ON pos.Buchungs_FS = b.Buchungs_ID
    WHERE YEAR(b.Ankunft)  = p_jahr
      AND MONTH(b.Ankunft) = p_monat
    GROUP BY
        b.Buchungs_ID, p.Vorname, p.Name,
        l.Land, b.Ankunft, b.Abreise
    ORDER BY Netto_CHF DESC;
END$$

-- ------------------------------------------------------------
-- sp_umsatz_zusammenfassung()
-- Gesamtstatistik: Buchungen, Gäste, Umsatz, Ø Aufenthalt.
-- Nur Management-Rolle darf ausführen.
-- Beispiel: CALL sp_umsatz_zusammenfassung();
-- ------------------------------------------------------------
CREATE PROCEDURE sp_umsatz_zusammenfassung()
BEGIN
    SELECT
        COUNT(DISTINCT b.Buchungs_ID)                                       AS Buchungen_Total,
        COUNT(DISTINCT b.Personen_FS)                                        AS Unique_Gaeste,
        ROUND(SUM(pos.Anzahl * pos.Preis * (1 - pos.Rabatt / 100)), 2)     AS Gesamtumsatz_CHF,
        ROUND(AVG(DATEDIFF(b.Abreise, b.Ankunft)), 1)                       AS Avg_Aufenthalt_Naechte,
        MAX(ROUND(SUM(pos.Anzahl * pos.Preis * (1 - pos.Rabatt / 100)), 2)) AS Top_Buchung_CHF
    FROM tbl_buchung b
    JOIN tbl_positionen pos ON pos.Buchungs_FS = b.Buchungs_ID;
END$$
DELIMITER ;

-- =============================================================
-- C) STORED FUNCTION
-- =============================================================

-- ------------------------------------------------------------
-- fn_buchung_netto(p_buchungs_id)
-- Gibt den Nettobetrag einer einzelnen Buchung zurück.
-- Verwendung in SELECT: SELECT fn_buchung_netto(1087);
-- Beide Rollen dürfen ausführen.
-- ------------------------------------------------------------
DELIMITER $$
CREATE FUNCTION fn_buchung_netto(p_buchungs_id INT)
RETURNS DECIMAL(10,2)
READS SQL DATA
DETERMINISTIC
BEGIN
    DECLARE v_netto DECIMAL(10,2) DEFAULT 0.00;
    SELECT ROUND(COALESCE(SUM(Anzahl * Preis * (1 - Rabatt / 100)), 0), 2)
    INTO   v_netto
    FROM   tbl_positionen
    WHERE  Buchungs_FS = p_buchungs_id;
    RETURN v_netto;
END$$
DELIMITER ;

-- =============================================================
-- D) TRIGGER
-- =============================================================

-- ------------------------------------------------------------
-- tr_buchung_datum_insert / tr_buchung_datum_update
-- Validiert: Abreise muss nach Ankunft liegen.
-- Verhindert ungültige Buchungszeiträume auf DB-Ebene.
-- SIGNAL SQLSTATE '45000' = benutzerdefinierter Fehler.
-- ------------------------------------------------------------
DELIMITER $$
CREATE TRIGGER tr_buchung_datum_insert
BEFORE INSERT ON tbl_buchung
FOR EACH ROW
BEGIN
    IF NEW.Abreise IS NOT NULL
       AND NEW.Ankunft IS NOT NULL
       AND NEW.Abreise <= NEW.Ankunft
    THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Abreise muss nach Ankunft liegen';
    END IF;
END$$

CREATE TRIGGER tr_buchung_datum_update
BEFORE UPDATE ON tbl_buchung
FOR EACH ROW
BEGIN
    IF NEW.Abreise IS NOT NULL
       AND NEW.Ankunft IS NOT NULL
       AND NEW.Abreise <= NEW.Ankunft
    THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Abreise muss nach Ankunft liegen';
    END IF;
END$$

-- ------------------------------------------------------------
-- tr_audit_pw_aenderung
-- Schreibt bei jeder Passwortänderung einen Eintrag in
-- tbl_audit_log. Der alte/neue Hash wird NICHT gespeichert
-- (Sicherheit). Trigger läuft mit Definer-Rechten → kein
-- direktes INSERT-Recht auf tbl_audit_log nötig für die Rollen.
-- ------------------------------------------------------------
CREATE TRIGGER tr_audit_pw_aenderung
AFTER UPDATE ON tbl_benutzer
FOR EACH ROW
BEGIN
    IF (OLD.Password IS NULL     AND NEW.Password IS NOT NULL)
    OR (OLD.Password IS NOT NULL AND NEW.Password IS NULL)
    OR (OLD.Password IS NOT NULL AND NEW.Password IS NOT NULL
        AND OLD.Password <> NEW.Password)
    THEN
        INSERT INTO tbl_audit_log (tabelle, datensatz_id, aktion)
        VALUES ('tbl_benutzer', NEW.Benutzer_ID, 'PASSWORD_CHANGED');
    END IF;
END$$
DELIMITER ;

-- =============================================================
-- E) GRANTS für Rollen
-- (Rollen müssen aus 02_backpacker_dcl.sql bereits existieren)
-- =============================================================

-- Views
GRANT SELECT ON backpacker_noah_lb3.v_buchung_uebersicht  TO benutzer_rolle;
GRANT SELECT ON backpacker_noah_lb3.v_buchung_uebersicht  TO management_rolle;

GRANT SELECT ON backpacker_noah_lb3.v_umsatz_pro_buchung  TO management_rolle;

GRANT SELECT ON backpacker_noah_lb3.v_top_leistungen      TO benutzer_rolle;
GRANT SELECT ON backpacker_noah_lb3.v_top_leistungen      TO management_rolle;

-- Stored Procedures
GRANT EXECUTE ON PROCEDURE backpacker_noah_lb3.sp_monatsbericht         TO management_rolle;
GRANT EXECUTE ON PROCEDURE backpacker_noah_lb3.sp_umsatz_zusammenfassung TO management_rolle;

-- Stored Function
GRANT EXECUTE ON FUNCTION backpacker_noah_lb3.fn_buchung_netto TO benutzer_rolle;
GRANT EXECUTE ON FUNCTION backpacker_noah_lb3.fn_buchung_netto TO management_rolle;

-- =============================================================
-- F) Kontrolle – Objekte auflisten
-- =============================================================
SHOW FULL TABLES IN backpacker_noah_lb3 WHERE Table_type = 'VIEW';

SELECT routine_name, routine_type
FROM information_schema.routines
WHERE routine_schema = 'backpacker_noah_lb3'
ORDER BY routine_type, routine_name;

SELECT trigger_name, event_manipulation, event_object_table, action_timing
FROM information_schema.triggers
WHERE trigger_schema = 'backpacker_noah_lb3'
ORDER BY event_object_table, action_timing;
