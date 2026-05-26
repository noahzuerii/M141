-- Demo: Transaktionen und Locking (Tag 3)
-- Zwei Konsolenfenster öffnen und die Befehle zeitlich abgestimmt ausführen.

-- === SETUP (einmalig ausführen) ===

CREATE DATABASE IF NOT EXISTS innotest;
USE innotest;

CREATE TABLE IF NOT EXISTS tbl_konto (
    id_k  INT AUTO_INCREMENT,
    Name  VARCHAR(30),
    Saldo DECIMAL(10,2),
    PRIMARY KEY (id_k)
) ENGINE = InnoDB;

INSERT INTO tbl_konto (id_K, Name, Saldo) VALUES
    (1, 'Von',  10000),
    (2, 'Nach',     0)
ON DUPLICATE KEY UPDATE Name = VALUES(Name), Saldo = VALUES(Saldo);

CREATE DATABASE IF NOT EXISTS test;
USE test;

CREATE TABLE IF NOT EXISTS table1 (
    colA INT AUTO_INCREMENT,
    colB INT,
    PRIMARY KEY (colA)
) ENGINE = InnoDB;

INSERT INTO table1 (colB) VALUES (10)
ON DUPLICATE KEY UPDATE colB = VALUES(colB);


-- ============================================================
-- DEMO 1: Transaktion – Kontoübertrag
-- ============================================================

USE innotest;

SET @uebertrag_var = 1000;

BEGIN;

  -- Prüfen ob Saldo ausreicht (sonst Übertrag auf 0 setzen)
  SELECT IF(Saldo >= @uebertrag_var, @uebertrag_var, 0) INTO @uebertrag_var
    FROM tbl_konto WHERE name = 'Von';

  -- Abbuchen
  UPDATE tbl_konto SET Saldo = Saldo - @uebertrag_var WHERE name = 'Von';
  -- Gutbuchen
  UPDATE tbl_konto SET Saldo = Saldo + @uebertrag_var WHERE name = 'Nach';

COMMIT;

SELECT * FROM tbl_konto;


-- ============================================================
-- DEMO 2: Transaktion mit ROLLBACK
-- ============================================================

USE innotest;

BEGIN;

  UPDATE tbl_konto SET Saldo = Saldo - 9999 WHERE name = 'Von';

  SELECT * FROM tbl_konto;   -- Sieht "falsch" aus
  -- Fehler erkannt → rückgängig machen

ROLLBACK;

SELECT * FROM tbl_konto;   -- Originalzustand wiederhergestellt


-- ============================================================
-- DEMO 3: Zwei Verbindungen – InnoDB Row-Level-Locking
--
-- Verbindung A (dieses Fenster):  Zeitpunkt 1, 3
-- Verbindung B (anderes Fenster): Zeitpunkt 2, 4, 5
-- ============================================================

USE test;

-- ---- Verbindung A – Zeitpunkt 1 ----
BEGIN;
UPDATE table1 SET colB = colB + 1 WHERE colA = 1;
-- colB ist jetzt 11 (nur für A sichtbar)
SELECT * FROM table1;   -- A sieht 11

-- ---- Verbindung B – Zeitpunkt 2 ----
-- (in zweitem Fenster ausführen)
-- BEGIN;
-- UPDATE table1 SET colB = colB + 3 WHERE colA = 1;
-- → blockiert! Wartet auf Freigabe durch A

-- ---- Verbindung A – Zeitpunkt 3 ----
COMMIT;
-- Jetzt kann B das UPDATE abschliessen (colB = 11 + 3 = 14)

-- ---- Verbindung B – Zeitpunkt 4 ----
-- SELECT * FROM table1;   -- B sieht 14
-- ROLLBACK;               -- B macht alles rückgängig

-- ---- Zeitpunkt 5 ----
SELECT * FROM table1;   -- Beide sehen 11


-- ============================================================
-- DEMO 4: Einfaches LOCK TABLE (MyISAM)
-- ============================================================

-- Tabelle temporär auf MyISAM umstellen (nur für Demo)
ALTER TABLE table1 ENGINE = MyISAM;

-- User 1:
LOCK TABLE table1 WRITE;
UPDATE table1 SET colB = 99 WHERE colA = 1;
-- User 2 kann jetzt weder lesen noch schreiben (blockiert)
UNLOCK TABLES;

-- Zurück auf InnoDB:
ALTER TABLE table1 ENGINE = InnoDB;


-- ============================================================
-- DEMO 5: SELECT … FOR UPDATE (InnoDB Exclusive Lock)
-- ============================================================

USE innotest;

-- Verbindung A:
BEGIN;
SELECT * FROM tbl_konto WHERE id_k = 1 FOR UPDATE;
-- Datensatz id_k=1 ist exklusiv gesperrt

-- Verbindung B (anderes Fenster):
-- UPDATE tbl_konto SET Saldo = 0 WHERE id_k = 1;
-- → blockiert bis A COMMIT oder ROLLBACK macht

-- Verbindung A:
UPDATE tbl_konto SET Saldo = Saldo - 500 WHERE id_k = 1;
COMMIT;


-- ============================================================
-- DEMO 6: SELECT … LOCK IN SHARE MODE (InnoDB Shared Lock)
-- ============================================================

USE innotest;

-- Verbindung A:
BEGIN;
SELECT * FROM tbl_konto WHERE id_k = 1 LOCK IN SHARE MODE;
-- Shared Lock: andere können lesen, aber nicht schreiben

-- Verbindung B (anderes Fenster):
-- SELECT * FROM tbl_konto WHERE id_k = 1 LOCK IN SHARE MODE;
-- → erlaubt (beide halten Shared Lock)

-- Verbindung B:
-- UPDATE tbl_konto SET Saldo = 0 WHERE id_k = 1;
-- → blockiert, bis A seinen Shared Lock freigibt

-- Verbindung A:
COMMIT;


-- ============================================================
-- DEMO 7: Deadlock-Diagnose
-- ============================================================

SHOW ENGINE INNODB STATUS;
-- Abschnitt "LATEST DETECTED DEADLOCK" zeigt Details
