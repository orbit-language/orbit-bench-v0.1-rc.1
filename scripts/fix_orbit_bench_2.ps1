# fix_orbit_bench_2.ps1
# Segunda tanda de workarounds: el compilador emite SIEMPRE 'orbit_app.exe',
# pero los scripts esperan <bench>.exe (microbench) y server.exe (http).
# Ademas, como cada 'orbit build' pisa orbit_app.exe, hay que renombrarlo
# despues de cada build para que no se clobbereen entre si.
#
#   1) run_microbench.ps1 -> tras compilar, renombra orbit_app.exe -> <bench>.exe
#   2) run_http_bench.ps1  -> tras compilar server.orb, renombra orbit_app.exe -> server.exe
#
# Uso (parado en la carpeta orbit-bench):
#   powershell -ExecutionPolicy Bypass -File scripts\fix_orbit_bench_2.ps1

$ErrorActionPreference = 'Stop'

# --- Detectar la raiz orbit-bench ---
$root = (Get-Location).Path
if (-not (Test-Path (Join-Path $root 'http\orbit\server.orb'))) {
    if ($PSScriptRoot -and (Test-Path (Join-Path (Split-Path $PSScriptRoot -Parent) 'http\orbit\server.orb'))) {
        $root = Split-Path $PSScriptRoot -Parent
    } else {
        Write-Host "[X] No encuentro http\orbit\server.orb. Ejecutalo parado en orbit-bench." -ForegroundColor Red
        exit 1
    }
}
Write-Host "Raiz orbit-bench: $root" -ForegroundColor Cyan

function Backup-Once([string]$path) {
    $bak = "$path.bak"
    if (-not (Test-Path $bak)) { Copy-Item -LiteralPath $path -Destination $bak -Force }
}
function Write-NoBom([string]$path, [string]$text) {
    [System.IO.File]::WriteAllText($path, $text, (New-Object System.Text.UTF8Encoding($false)))
}

# ---------- 1) run_microbench.ps1: renombrar orbit_app.exe -> <bench>.exe ----------
$microBench = Join-Path $root 'scripts\run_microbench.ps1'
$m = Get-Content -Raw -LiteralPath $microBench
if ($m.Contains('Move-Item -Force "orbit_app.exe" "$bench.exe"')) {
    Write-Host "[=] run_microbench.ps1 ya renombra el binario, sin cambios." -ForegroundColor DarkGray
} else {
    $anchor = '    $ErrorActionPreference = $eap'
    $replacement = @'
    $ErrorActionPreference = $eap
    if (Test-Path "orbit_app.exe") { Move-Item -Force "orbit_app.exe" "$bench.exe" }
'@
    if ($m.Contains($anchor)) {
        Backup-Once $microBench
        $m = $m.Replace($anchor, $replacement)
        Write-NoBom $microBench $m
        Write-Host "[+] run_microbench.ps1: renombra orbit_app.exe -> <bench>.exe." -ForegroundColor Green
    } else {
        Write-Host "[!] No encontre el ancla en run_microbench.ps1 (corriste primero fix_orbit_bench.ps1?)." -ForegroundColor Yellow
    }
}

# ---------- 2) run_http_bench.ps1: renombrar orbit_app.exe -> server.exe ----------
$httpBench = Join-Path $root 'scripts\run_http_bench.ps1'
$h = Get-Content -Raw -LiteralPath $httpBench
if ($h.Contains('Move-Item -Force "orbit_app.exe" "server.exe"')) {
    Write-Host "[=] run_http_bench.ps1 ya renombra el binario, sin cambios." -ForegroundColor DarkGray
} else {
    $anchor2 = 'orbit build server.orb; Start-Process -PassThru -NoNewWindow -FilePath ".\server.exe"'
    $replacement2 = 'orbit build server.orb; if (Test-Path "orbit_app.exe") { Move-Item -Force "orbit_app.exe" "server.exe" }; Start-Process -PassThru -NoNewWindow -FilePath ".\server.exe"'
    if ($h.Contains($anchor2)) {
        Backup-Once $httpBench
        $h = $h.Replace($anchor2, $replacement2)
        Write-NoBom $httpBench $h
        Write-Host "[+] run_http_bench.ps1: renombra orbit_app.exe -> server.exe." -ForegroundColor Green
    } else {
        Write-Host "[!] No encontre el ancla del StartCmd de Orbit en run_http_bench.ps1." -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "Listo. Reintenta: powershell -ExecutionPolicy Bypass -File scripts\run_all.ps1" -ForegroundColor Cyan
