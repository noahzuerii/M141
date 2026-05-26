-- =============================================================
-- 01_backpacker_ddl.sql
-- Datenbank: backpacker_noah_lb3
-- Autor: Noah Bachmann | TBZ M141 LB3
-- =============================================================
-- Beschreibung:
--   Basiert auf dem gegebenen DDL (phpMyAdmin-Export, MyISAM/latin1).
--   Änderungen gegenüber Original:
--     - Engine: MyISAM → InnoDB  (Fremdschlüssel, Transaktionen)
--     - Charset: latin1 → utf8mb4 (Unicode, Umlaute, Emoji)
--     - Fremdschlüssel hinzugefügt (fehlten im Original)
--     - tbl_land: PRIMARY KEY und AUTO_INCREMENT ergänzt
--     - Alle NULL-Defaults beibehalten (originalgetreu)
-- =============================================================

DROP DATABASE IF EXISTS backpacker_noah_lb3;

CREATE DATABASE backpacker_noah_lb3
  DEFAULT CHARACTER SET utf8mb4
  DEFAULT COLLATE utf8mb4_unicode_ci;

USE backpacker_noah_lb3;

-- -------------------------------------------------------------
-- tbl_land – Ländercodes
-- Original: kein PK, kein AI → ergänzt
-- -------------------------------------------------------------
CREATE TABLE tbl_land (
    Land_ID INT(11) NOT NULL AUTO_INCREMENT,
    Land    TEXT    COLLATE utf8mb4_unicode_ci NOT NULL,
    PRIMARY KEY (Land_ID)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_unicode_ci
  COMMENT = 'enthält die Ländercodes';

-- -------------------------------------------------------------
-- tbl_leistung – Leistungskatalog
-- Original: kein AI → bleibt ohne AI (manuelle ID-Vergabe)
-- -------------------------------------------------------------
CREATE TABLE tbl_leistung (
    LeistungID    INT(11)      NOT NULL DEFAULT 0,
    Beschreibung  VARCHAR(70)  COLLATE utf8mb4_unicode_ci DEFAULT NULL,
    PRIMARY KEY (LeistungID)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_unicode_ci;

-- -------------------------------------------------------------
-- tbl_personen – Gästedaten
-- Original: kein LandID (Land kommt über tbl_buchung)
-- -------------------------------------------------------------
CREATE TABLE tbl_personen (
    Personen_ID INT(11)   NOT NULL AUTO_INCREMENT,
    Titel       TEXT      COLLATE utf8mb4_unicode_ci,
    Vorname     TEXT      COLLATE utf8mb4_unicode_ci,
    Name        TEXT      COLLATE utf8mb4_unicode_ci,
    Strasse     TEXT      COLLATE utf8mb4_unicode_ci,
    PLZ         TEXT      COLLATE utf8mb4_unicode_ci,
    Ort         TEXT      COLLATE utf8mb4_unicode_ci,
    Anrede      TEXT      COLLATE utf8mb4_unicode_ci,
    Telefon     TEXT      COLLATE utf8mb4_unicode_ci,
    erfasst     DATETIME  DEFAULT NULL,
    Sprache     TEXT      COLLATE utf8mb4_unicode_ci,
    PRIMARY KEY (Personen_ID)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_unicode_ci
  COMMENT = 'enthält alle Gäste'
  AUTO_INCREMENT = 2042;

-- -------------------------------------------------------------
-- tbl_benutzer – Mitarbeiter-Logins
-- Wichtig für Zugriffsmatrix:
--   Password  → kein Zugriff für Benutzer-Gruppe
--   deaktiviert → nur SELECT für Benutzer-Gruppe
-- -------------------------------------------------------------
CREATE TABLE tbl_benutzer (
    Benutzer_ID    INT(11)      NOT NULL AUTO_INCREMENT,
    Benutzername   VARCHAR(20)  COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
    Password       TEXT         COLLATE utf8mb4_unicode_ci,
    Vorname        VARCHAR(20)  COLLATE utf8mb4_unicode_ci DEFAULT NULL,
    Name           TEXT         COLLATE utf8mb4_unicode_ci,
    Benutzergruppe TINYINT(4)   DEFAULT 1,
    erfasst        TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    deaktiviert    DATE         DEFAULT '1000-01-01',
    aktiv          TINYINT(4)   DEFAULT 1,
    PRIMARY KEY (Benutzer_ID)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_unicode_ci
  COMMENT = 'Mitarbeiter'
  AUTO_INCREMENT = 28;

-- -------------------------------------------------------------
-- tbl_buchung – Buchungsköpfe
-- Land_FS: Herkunftsland des Gastes (auf Buchungsebene)
-- -------------------------------------------------------------
CREATE TABLE tbl_buchung (
    Buchungs_ID INT(11)   NOT NULL AUTO_INCREMENT,
    Personen_FS INT(11)   DEFAULT NULL,
    Ankunft     DATETIME  DEFAULT NULL,
    Abreise     DATETIME  DEFAULT NULL,
    Land_FS     INT(11)   DEFAULT NULL,
    PRIMARY KEY (Buchungs_ID),
    INDEX idx_buch_pers (Personen_FS),
    INDEX idx_buch_land (Land_FS),
    CONSTRAINT fk_buch_pers
        FOREIGN KEY (Personen_FS) REFERENCES tbl_personen (Personen_ID)
        ON UPDATE CASCADE ON DELETE SET NULL,
    CONSTRAINT fk_buch_land
        FOREIGN KEY (Land_FS)     REFERENCES tbl_land (Land_ID)
        ON UPDATE CASCADE ON DELETE SET NULL
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_unicode_ci
  COMMENT = 'Buchungszeilen'
  AUTO_INCREMENT = 1087;

-- -------------------------------------------------------------
-- tbl_positionen – Buchungspositionen
-- Benutzer_FS: Mitarbeiter, der die Position erfasst hat
-- Leistung_FS: Referenz auf Leistungskatalog
-- -------------------------------------------------------------
CREATE TABLE tbl_positionen (
    Positions_ID  INT(11)       NOT NULL AUTO_INCREMENT,
    Buchungs_FS   INT(11)       DEFAULT NULL,
    Konto         INT(11)       NOT NULL DEFAULT 0,
    Anzahl        INT(11)       NOT NULL DEFAULT 0,
    Preis         DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    Rabatt        DECIMAL(4,2)  NOT NULL DEFAULT 0.00,
    Benutzer_FS   INT(11)       NOT NULL DEFAULT 0,
    erfasst       DATETIME      NOT NULL DEFAULT '2000-01-01 00:00:00',
    Leistung_Text TEXT          COLLATE utf8mb4_unicode_ci NOT NULL,
    Leistung_FS   INT(11)       DEFAULT NULL,
    PRIMARY KEY (Positions_ID),
    INDEX idx_pos_buch  (Buchungs_FS),
    INDEX idx_pos_leist (Leistung_FS),
    INDEX idx_pos_ben   (Benutzer_FS),
    CONSTRAINT fk_pos_buch
        FOREIGN KEY (Buchungs_FS) REFERENCES tbl_buchung  (Buchungs_ID)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_pos_leist
        FOREIGN KEY (Leistung_FS) REFERENCES tbl_leistung (LeistungID)
        ON UPDATE CASCADE ON DELETE SET NULL,
    CONSTRAINT fk_pos_ben
        FOREIGN KEY (Benutzer_FS) REFERENCES tbl_benutzer (Benutzer_ID)
        ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_unicode_ci
  COMMENT = 'enthält einzelne Buchungspositionen'
  AUTO_INCREMENT = 4055;

-- -------------------------------------------------------------
-- Schema überprüfen
-- -------------------------------------------------------------
SHOW TABLE STATUS FROM backpacker_noah_lb3;

SELECT table_name, engine, table_collation
FROM information_schema.tables
WHERE table_schema = 'backpacker_noah_lb3';
