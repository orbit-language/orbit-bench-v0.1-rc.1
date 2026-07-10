# fix_orbit_bench.ps1
# Aplica los workarounds al repo orbit-bench (lado de archivos que vos tenes):
#   1) http/orbit/server.orb  -> agrega fn main() vacio (destraba el error
#      'call to undeclared function orbit_main' al compilar el server)
#   2) scripts/run_http_bench.ps1 -> puerto Orbit 8080 -> 3000 (el que emite
#      hoy el codegen; si no, Wait-ForPort da timeout)
#   3) scripts/run_http_bench.ps1 -> imprime la salida cruda de 'hey' cuando
#      no se puede parsear 'Requests/sec' (para diagnosticar por que sale vacio)
#   4) scripts/run_microbench.ps1 -> evita que los logs de stderr de orbit
#      aborten la Fase 1 (NativeCommandError)
#
# NO toca el compilador de Orbit (no esta en este repo). El fix de fondo del
# codegen -emitir siempre orbit_main + logs de debug detras de un flag- va en
# el proyecto del compilador.
#
# Uso (parado en la carpeta orbit-bench):
#   powershell -ExecutionPolicy Bypass -File scripts\fix_orbit_bench.ps1

$ErrorActionPreference = 'Stop'

# --- Detectar la raiz orbit-bench ---
$root = (Get-Location).Path
if (-not (Test-Path (Join-Path $root 'http\orbit\server.orb'))) {
    if ($PSScriptRoot -and (Test-Path (Join-Path (Split-Path $PSScriptRoot -Parent) 'http\orbit\server.orb'))) {
        $root = Split-Path $PSScriptRoot -Parent
    } else {
        Write-Host "[X] No encuentro http\orbit\server.orb." -ForegroundColor Red
        Write-Host "    Ejecutalo parado en la carpeta orbit-bench, o desde scripts\." -ForegroundColor Red
        exit 1
    }
}
Write-Host "Raiz orbit-bench: $root" -ForegroundColor Cyan

function Backup-Once([string]$path) {
    $bak = "$path.bak"
    if (-not (Test-Path $bak)) { Copy-Item -LiteralPath $path -Destination $bak -Force }
}

# Escribe UTF-8 SIN BOM (importante: el lexer de Orbit no quiere BOM)
function Write-NoBom([string]$path, [string]$text) {
    [System.IO.File]::WriteAllText($path, $text, (New-Object System.Text.UTF8Encoding($false)))
}

# ---------- 1) server.orb: fn main() vacio ----------
$serverOrb = Join-Path $root 'http\orbit\server.orb'
$c = Get-Content -Raw -LiteralPath $serverOrb
if ($c -match '(?m)^\s*fn\s+main\s*\(') {
    Write-Host "[=] server.orb ya tiene fn main(), sin cambios." -ForegroundColor DarkGray
} else {
    Backup-Once $serverOrb
    $append = "`r`n`r`nfn main() -> int {`r`n    return 0`r`n}`r`n"
    Write-NoBom $serverOrb ($c.TrimEnd() + $append)
    Write-Host "[+] server.orb: agregado fn main() vacio." -ForegroundColor Green
}

# ---------- 2 y 3) run_http_bench.ps1 ----------
$httpBench = Join-Path $root 'scripts\run_http_bench.ps1'
$h = Get-Content -Raw -LiteralPath $httpBench
$hOrig = $h

# 2) puerto Orbit 8080 -> 3000 (reemplazo literal)
$h = $h.Replace('Name = "Orbit"; Port = 8080', 'Name = "Orbit"; Port = 3000')

# 3) mostrar salida cruda de hey si el parseo dio vacio
$anchor = '                $parsed = Parse-HeyOutput -RawOutput $heyOutput'
$diag = @'
                $parsed = Parse-HeyOutput -RawOutput $heyOutput
                if ($null -eq $parsed.RequestsPerSec) {
                    Write-Host "  [!] No pude parsear 'Requests/sec' de hey. Salida cruda:" -ForegroundColor Yellow
                    Write-Host $heyOutput
                }
'@
if (-not $h.Contains("No pude parsear 'Requests/sec' de hey")) {
    $h = $h.Replace($anchor, $diag)
}

if ($h -ne $hOrig) {
    Backup-Once $httpBench
    Write-NoBom $httpBench $h
    Write-Host "[+] run_http_bench.ps1: puerto Orbit=3000 + diagnostico de hey." -ForegroundColor Green
} else {
    Write-Host "[=] run_http_bench.ps1 sin cambios (ya estaba parcheado)." -ForegroundColor DarkGray
}

# ---------- 4) run_microbench.ps1: stderr no aborta la Fase 1 ----------
$microBench = Join-Path $root 'scripts\run_microbench.ps1'
$m = Get-Content -Raw -LiteralPath $microBench
$oldBuild = '    orbit build "$bench.orb" 2>&1 | Out-Null'
$newBuild = @'
    $eap = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    orbit build "$bench.orb" 2>&1 | Out-Null
    $ErrorActionPreference = $eap
'@
if ($m.Contains("`$ErrorActionPreference = 'Continue'")) {
    Write-Host "[=] run_microbench.ps1 ya estaba parcheado." -ForegroundColor DarkGray
} elseif ($m.Contains($oldBuild)) {
    Backup-Once $microBench
    $m = $m.Replace($oldBuild, $newBuild)
    Write-NoBom $microBench $m
    Write-Host "[+] run_microbench.ps1: stderr de orbit ya no aborta la Fase 1." -ForegroundColor Green
} else {
    Write-Host "[!] No encontre la linea de build en run_microbench.ps1; revisalo a mano." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Listo. Se guardaron backups *.bak junto a cada archivo modificado." -ForegroundColor Cyan
Write-Host "Reintenta con: powershell -ExecutionPolicy Bypass -File scripts\run_all.ps1" -ForegroundColor Cyan
