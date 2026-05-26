-- =============================================================
-- 01_setup.sql  –  Tag 7: Datenbank mit Testdaten testen
-- Autor: Noah Bachmann | TBZ M141
-- Schritte: User, Schema, Tabellen
-- =============================================================

-- =============================================================
-- SCHRITT 1: Login mit Test User
-- Nicht möglich, weil noch keine User existieren.
-- =============================================================

-- =============================================================
-- SCHRITT 2: User erstellen
-- =============================================================

-- Zuerst prüfen, ob User bereits existieren und ggf. löschen
DROP USER IF EXISTS 'Reader'@'%';
DROP USER IF EXISTS 'Reader'@'localhost';
DROP USER IF EXISTS 'Contributor'@'%';
DROP USER IF EXISTS 'Contributor'@'localhost';

-- User erstellen (mit % = remote und localhost)
CREATE USER 'Reader'@'%'         IDENTIFIED BY '123!';
CREATE USER 'Reader'@'localhost' IDENTIFIED BY '123!';
CREATE USER 'Contributor'@'%'         IDENTIFIED BY '123!';
CREATE USER 'Contributor'@'localhost' IDENTIFIED BY '123!';

-- WICHTIG: Einige MariaDB-Versionen erstellen automatisch 4 User
-- (je einen mit '%' mit Passwort und einen mit 'localhost' ohne Passwort)
-- Mit folgendem Befehl in phpMyAdmin prüfen:
SELECT User, Host, Password FROM mysql.user WHERE User IN ('Reader', 'Contributor');

-- Login lokal testen (in separater Session):
-- mysql -u Reader -p'123!'
-- mysql -u Contributor -p'123!'

-- =============================================================
-- SCHRITT 3: Schema und Tabellen erstellen (ohne PK und Index!)
-- Ziel: Schlechte Performance demonstrieren
-- =============================================================

DROP SCHEMA IF EXISTS `myTestDb`;
CREATE SCHEMA IF NOT EXISTS `myTestDb` DEFAULT CHARACTER SET utf8;
USE `myTestDb`;

DROP TABLE IF EXISTS `Person`;
DROP TABLE IF EXISTS `Adresse`;

CREATE TABLE Person (
    Id        INT,
    Vorname   VARCHAR(255),
    Nachname  VARCHAR(255),
    Email     VARCHAR(255),
    AdresseId INT
);

CREATE TABLE Adresse (
    Id          INT,
    Strasse     VARCHAR(255),
    Hausnummer  VARCHAR(10),
    PLZ         VARCHAR(10),
    Stadt       VARCHAR(255),
    Bundesstaat VARCHAR(10)
);

-- Tabellen prüfen
SHOW TABLES;
DESCRIBE Person;
DESCRIBE Adresse;
