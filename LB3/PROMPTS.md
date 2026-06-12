# KI-Prompt-Log (Urheberbeweis LB3)

**Autor:** Noah Bachmann · TBZ M141 LB3
**Verwendete Tools:** ChatGPT (GPT-5), Claude (Opus 4.7) als Coding-Begleiter
**Grundregel:** Alle KI-Antworten wurden manuell geprüft, angepasst und in eigenen Worten in die Skripte/Dokumente übertragen. Ich kann jede Code-Zeile erklären.

> Gemäss LB3-Vorgabe („KI-Einsatz wird vorausgesetzt – Prompts müssen dokumentiert sein“) liste ich unten meine wichtigsten Prompts und beschreibe knapp, was ich übernommen, geändert oder verworfen habe.

---

## 1. DDL & Normalisierung (Skript 01)

**Prompt 1**
> „Hier ist ein Access-DDL-Dump (phpMyAdmin v2.9, MyISAM, latin1) für eine Jugendherberge. Migriere mir das Schema nach MariaDB 10.4: InnoDB, utf8mb4, sinnvolle FKs, NULL-Defaults beibehalten. Erkläre, warum du welche FK-ON-DELETE-Regel wählst.“

→ **Übernommen:** Vorschlag InnoDB + utf8mb4_unicode_ci, ON DELETE CASCADE für `tbl_positionen → tbl_buchung`, ON DELETE SET NULL für `tbl_positionen → tbl_leistung`, ON DELETE RESTRICT für `tbl_positionen → tbl_benutzer` (Audit).
→ **Selbst geändert:** `tbl_land.Land_ID` ist im Original ohne PK – ich habe selbst entschieden, PK + AI hinzuzufügen, weil sonst FK von `tbl_buchung.Land_FS` nicht greifbar ist.

**Prompt 2**
> „Welche CHECK-Constraints sind sinnvoll für tbl_positionen, ohne den ursprünglichen Datenstand zu verletzen?“

→ **Übernommen:** `Preis >= 0`, `Anzahl >= 0`, `Rabatt BETWEEN 0 AND 100`.
→ **Verworfen:** Vorschlag, `Konto` auf Whitelist (4000–4999) einzuschränken – passt nicht zur Kontoplan-Vielfalt im Beispiel.

## 2. DCL & Zugriffsmatrix (Skript 02)

**Prompt 3**
> „Setze diese Zugriffsmatrix (Pasten der Tabelle aus README.md) in MySQL-8.0-Rollen + Column-Grants um. Sensible Spalte ist `Password`. Rezeptionsrolle darf `Password` weder lesen noch schreiben.“

→ **Übernommen:** Struktur mit zwei Rollen + Spalten-GRANTS.
→ **Selbst geändert:** Vorschlag enthielt `SET DEFAULT ROLE ALL TO …` – das funktioniert auf MariaDB 10.4 nicht ohne Plugin, deshalb habe ich die Rolle direkt bei `GRANT` mit angegeben (`WITH ADMIN OPTION` weggelassen).

**Prompt 4**
> „Wie verhindere ich, dass `benutzer_rolle` den Trigger `tr_audit_pw_aenderung` durch einen UPDATE umgeht?“

→ Antwort half mir zu erkennen, dass column-level `UPDATE` auf `Password` für die Rezeption komplett verweigert werden muss – nicht nur ein BEFORE-Trigger.

## 3. CSV-Import & Bereinigung (Skript 03)

**Prompt 5**
> „Schreibe LOAD DATA INFILE statements für 6 CSVs (Spalten siehe DDL). CSVs sind UTF-8, Trennzeichen `;`, NULL ist Leerstring. Vor dem Aktivieren der FK-Constraints muss ich Waisen entfernen können.“

→ **Übernommen:** `SET foreign_key_checks=0; … LOAD … ; SET foreign_key_checks=1;`-Pattern + `NULLIF`-Konvertierungen.
→ **Selbst geändert:** Pfade auf `C:/xampp/tmp/backpacker_csv/...` angepasst, weil XAMPP `LOAD DATA LOCAL INFILE` nur aus diesem Whitelist-Pfad zulässt.

**Prompt 6**
> „SHA-256-Hash für bestehende Klartext-Passwörter, aber nur wenn LENGTH < 64 (sonst doppelt-gehasht).“

→ Übernommen 1:1 – clever genug, dass ich den Trick selbst nicht gehabt hätte. Notiert in Bereinigungs-Schritt B7.

## 4. Views, Stored Procedures, Trigger (Skript 07)

**Prompt 7**
> „Brauche View `v_buchung_uebersicht` (Gast, Land, Nächte) und `v_umsatz_pro_buchung` (mit Rabatt). Wichtig: `benutzer_rolle` darf `v_buchung_uebersicht` sehen, aber nicht `v_umsatz_pro_buchung`. Verwende SQL SECURITY DEFINER, damit ich keine Basistabellen-Grants extra geben muss.“

→ Übernommen.
→ **Selbst ergänzt:** `SQL SECURITY INVOKER` testweise versucht – funktionierte nicht für `ben_noah`, weil dieser keine `SELECT`-Rechte auf `tbl_leistung.Preis` hat. DEFINER ist daher Pflicht.

**Prompt 8**
> „Trigger, der jede Passwortänderung auf `tbl_benutzer` in eine Audit-Tabelle schreibt – inkl. alter und neuer Hash. Schema schlag selbst vor.“

→ Übernommen mit kleinem Cleanup (Spaltennamen deutsch statt englisch).

## 5. Testing (Skript 04 & 06)

**Prompt 9**
> „Generiere mir 30 Positiv- und Negativ-Tests für die obigen Rollen, in einem mysql-CLI-tauglichen SQL-Skript. Jeder Test mit Kommentar: `-- Erwartet: …` und `-- Ergebnis: ✓ OK` als Platzhalter, den ich nach dem Lauf ausfülle.“

→ Format komplett übernommen, jeden Test selbst ausgeführt und das tatsächliche Resultat eingefügt (siehe [08_testprotokoll_lokal.md](./08_testprotokoll_lokal.md)).

## 6. Cloud-Pivot AWS → Aiven

**Prompt 10**
> „Ich habe für die Klasse kein AWS-Konto. Welche EU-basierten DBaaS bieten einen kostenlosen MySQL-8.0-Trial, sind regelkonform mit DACH-Datenschutz und haben eine Region in der Schweiz?“

→ Übernommen: Vorschlag Aiven, Google Cloud SQL, Azure, Oracle. → Eigene Evaluation in README, Entscheid Aiven wegen Setup-Geschwindigkeit + Region west6.

**Prompt 11**
> „Wie ersetze ich `--ssl-mode=REQUIRED` (AWS-Style) durch das Aiven-Pendant mit CA-Datei?“

→ Antwort `--ssl-mode=VERIFY_CA --ssl-ca=ca.pem` übernommen, Pfad nach `C:\backup\aiven_ca.pem` selbst gewählt.

## 7. Allgemein

**Prompt 12** (Doku)
> „Hilf mir aus diesen 7 Skripten einen LB3-konformen README.md zu bauen, der MS A–D abbildet, eine Cloud-Evaluation enthält, Mermaid-ERD zeigt und die Zugriffsmatrix gegenüber dem Skript visualisiert.“

→ Struktur übernommen, Inhalte personalisiert (mein Name, DB-Name `backpacker_noah_lb3`, Region west6, Aiven-Endpoint).

---

## Was die KI **nicht** gemacht hat

| Aufgabe                                        | Wer?    |
|------------------------------------------------|---------|
| Datenanalyse der CSV (Konsistenzcheck)         | Ich, manuell mit Excel + `LOAD …` IGNORE-Logs |
| Tatsächliche Tests gegen MariaDB/Aiven         | Ich, am Laptop + Aiven-Console |
| Wahl des Cloud-Anbieters                       | Ich, basierend auf KI-Vorschlägen + Restrisiko/Kosten |
| Personalisierung (Namen, IPs, Trial-Account)   | Ich |
| Bewertung der Trigger-Designs gegen Security   | Ich (KI dachte initial, BEFORE-Trigger reicht) |
| Verifikation der Tests via `EXPLAIN`           | Ich |
