-- Firma_DDL.sql
-- Erstellt die Datenbank "firma" mit allen Tabellen, Indizes und Fremdschlüsseln.

CREATE DATABASE IF NOT EXISTS firma
  DEFAULT CHARACTER SET utf8mb4
  DEFAULT COLLATE utf8mb4_unicode_ci;

USE firma;

-- -------------------------------------------------------
-- Tabelle: tbl_plz_ort
-- -------------------------------------------------------
CREATE TABLE IF NOT EXISTS tbl_plz_ort (
    PLZ   CHAR(4)      NOT NULL,
    Ort   VARCHAR(100) NOT NULL,
    PRIMARY KEY (PLZ)
) ENGINE = MyISAM
  DEFAULT CHARSET = utf8mb4;

-- -------------------------------------------------------
-- Tabelle: tbl_abteilung
-- -------------------------------------------------------
CREATE TABLE IF NOT EXISTS tbl_abteilung (
    Abtlg_ID    INT          NOT NULL,
    Bezeichnung VARCHAR(50)  NOT NULL,
    PRIMARY KEY (Abtlg_ID)
) ENGINE = MyISAM
  DEFAULT CHARSET = utf8mb4;

-- -------------------------------------------------------
-- Tabelle: tbl_mitarbeiter
-- -------------------------------------------------------
CREATE TABLE IF NOT EXISTS tbl_mitarbeiter (
    MA_ID          INT           NOT NULL AUTO_INCREMENT,
    Name           VARCHAR(50)   NOT NULL,
    Vorname        VARCHAR(50)   NOT NULL,
    Geburtsdatum   DATE,
    Eintrittsdatum DATE,
    Abtlg_ID       INT,
    PLZ            CHAR(4),
    Gehalt         DECIMAL(10,2),
    PRIMARY KEY (MA_ID),
    INDEX idx_name (Name),
    INDEX idx_abtlg (Abtlg_ID)
) ENGINE = MyISAM
  DEFAULT CHARSET = utf8mb4;

-- -------------------------------------------------------
-- Beispieldaten: tbl_plz_ort
-- -------------------------------------------------------
INSERT INTO tbl_plz_ort (PLZ, Ort) VALUES
('8000', 'Zürich'),
('8001', 'Zürich'),
('3000', 'Bern'),
('4000', 'Basel'),
('6000', 'Luzern'),
('9000', 'St. Gallen'),
('1000', 'Lausanne'),
('2000', 'Neuchâtel');

-- -------------------------------------------------------
-- Beispieldaten: tbl_abteilung
-- -------------------------------------------------------
INSERT INTO tbl_abteilung (Abtlg_ID, Bezeichnung) VALUES
(1, 'Geschäftsleitung'),
(2, 'Informatik'),
(3, 'Buchhaltung'),
(4, 'Personalwesen'),
(5, 'Verkauf');

-- -------------------------------------------------------
-- Beispieldaten: tbl_mitarbeiter
-- -------------------------------------------------------
INSERT INTO tbl_mitarbeiter (Name, Vorname, Geburtsdatum, Eintrittsdatum, Abtlg_ID, PLZ, Gehalt) VALUES
('Müller',    'Hans',     '1975-03-12', '2005-01-01', 1, '8000', 9800.00),
('Meier',     'Anna',     '1982-07-24', '2010-06-01', 2, '8001', 8200.00),
('Keller',    'Peter',    '1990-11-05', '2015-03-15', 2, '3000', 7500.00),
('Huber',     'Sandra',   '1988-01-30', '2012-09-01', 3, '4000', 7800.00),
('Schmid',    'Thomas',   '1979-05-18', '2008-04-01', 4, '6000', 8500.00),
('Fischer',   'Laura',    '1995-08-22', '2020-02-01', 5, '9000', 6500.00),
('Weber',     'Markus',   '1983-12-10', '2011-07-01', 5, '8000', 7200.00),
('Zimmermann','Christine','1992-04-14', '2018-01-01', 2, '3000', 7900.00);

-- -------------------------------------------------------
-- Index löschen (Beispiel aus Aufgabe 4.4)
-- -------------------------------------------------------
-- ALTER TABLE tbl_mitarbeiter DROP INDEX idx_name;

-- -------------------------------------------------------
-- Tabellentyp auf InnoDB ändern (Aufgabe 4.4)
-- -------------------------------------------------------
ALTER TABLE tbl_plz_ort     ENGINE = InnoDB;
ALTER TABLE tbl_abteilung   ENGINE = InnoDB;
ALTER TABLE tbl_mitarbeiter ENGINE = InnoDB;

-- Fremdschlüssel nach Engine-Wechsel hinzufügen
ALTER TABLE tbl_mitarbeiter
    ADD CONSTRAINT fk_abtlg FOREIGN KEY (Abtlg_ID) REFERENCES tbl_abteilung(Abtlg_ID),
    ADD CONSTRAINT fk_plz   FOREIGN KEY (PLZ)       REFERENCES tbl_plz_ort(PLZ);

-- -------------------------------------------------------
-- Eigene Tabelle: tbl_projekt (Aufgabe 4.5)
-- -------------------------------------------------------
CREATE TABLE IF NOT EXISTS tbl_projekt (
    Proj_ID      INT            NOT NULL AUTO_INCREMENT,
    Bezeichnung  VARCHAR(100)   NOT NULL,
    Start_Datum  DATE,
    End_Datum    DATE,
    Budget       DECIMAL(12,2),
    PRIMARY KEY (Proj_ID)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4;

-- Mitarbeiter ↔ Projekt (N:M)
CREATE TABLE IF NOT EXISTS tbl_ma_proj (
    MA_ID    INT         NOT NULL,
    Proj_ID  INT         NOT NULL,
    Funktion VARCHAR(50),
    PRIMARY KEY (MA_ID, Proj_ID),
    FOREIGN KEY (MA_ID)   REFERENCES tbl_mitarbeiter(MA_ID) ON DELETE CASCADE,
    FOREIGN KEY (Proj_ID) REFERENCES tbl_projekt(Proj_ID)   ON DELETE CASCADE
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4;

INSERT INTO tbl_projekt (Bezeichnung, Start_Datum, End_Datum, Budget) VALUES
('ERP-Migration',    '2024-01-01', '2024-06-30', 150000.00),
('Website Relaunch', '2024-03-01', '2024-04-30',  20000.00),
('Security-Audit',   '2024-05-01', '2024-05-31',   8000.00);

INSERT INTO tbl_ma_proj (MA_ID, Proj_ID, Funktion) VALUES
(1, 1, 'Projektleiter'),
(2, 1, 'Entwickler'),
(3, 1, 'Entwickler'),
(2, 2, 'Projektleiter'),
(6, 2, 'Designer'),
(4, 3, 'Analyst');

-- -------------------------------------------------------
-- Tabellen-Status prüfen
-- -------------------------------------------------------
SHOW TABLE STATUS FROM firma;
