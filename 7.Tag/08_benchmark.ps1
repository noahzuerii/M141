# =============================================================
# 08_benchmark.ps1  –  Tag 7: mysqlslap Benchmark
# Autor: Noah Bachmann | TBZ M141
# Voraussetzung: northwind-DB geladen, XAMPP läuft
# =============================================================

# Ins MariaDB bin-Verzeichnis wechseln
Set-Location "C:\xampp\mysql\bin"

Write-Host "=== Benchmark 1: Baseline (ohne Optimierung) ===" -ForegroundColor Cyan

.\mysqlslap.exe `
    --user=root `
    --password `
    --concurrency=30 `
    --iterations=5 `
    --number-of-queries=3000 `
    --query="SELECT * FROM Orders WHERE Freight > 100 ORDER BY Freight DESC;" `
    --create-schema=northwind

# Ergebnis notieren: "Average number of seconds to run all queries: X.XXX"

Write-Host ""
Write-Host "=== Optimierung: my.ini anpassen ===" -ForegroundColor Yellow
Write-Host "Öffne C:\xampp\mysql\bin\my.ini und setze:"
Write-Host "  innodb_buffer_pool_size = 512M"
Write-Host "  innodb_log_file_size    = 128M"
Write-Host "  max_connections         = 100"
Write-Host ""
Write-Host "Danach MySQL in XAMPP neu starten, dann Benchmark 2 ausführen."
Write-Host ""
Write-Host "=== Benchmark 2: Nach Optimierung ===" -ForegroundColor Cyan

.\mysqlslap.exe `
    --user=root `
    --password `
    --concurrency=30 `
    --iterations=5 `
    --number-of-queries=3000 `
    --query="SELECT * FROM Orders WHERE Freight > 100 ORDER BY Freight DESC;" `
    --create-schema=northwind

# Vergleich:
# Vorher: X.XXX Sekunden
# Nachher: Y.YYY Sekunden
# Verbesserung: (X - Y) * 1000 Millisekunden
