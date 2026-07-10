# run_http_bench.ps1
# Levanta cada servidor HTTP (Orbit, C, Node, FastAPI), le pega carga con
# 'hey' contra /ping, /json y /compute, y guarda los resultados en CSV.
#
# Requisitos:
#   - orbit, zig, node, python (con fastapi + uvicorn instalados) en PATH
#   - hey.exe en PATH (https://github.com/rakyll/hey/releases)
#
# Uso:
#   powershell -ExecutionPolicy Bypass -File scripts/run_http_bench.ps1

param(
    [int]$DurationSeconds = 10,
    [int]$Concurrency = 1,       # el runtime actual de Orbit es single-threaded/blocking:
                                  # arrancar en concurrencia 1 da una lectura honesta.
    [int]$HighConcurrency = 50    # segunda pasada para mostrar el techo bajo carga concurrente.
)

$ErrorActionPreference = "Continue"
$root = Split-Path -Parent $PSScriptRoot
$httpDir = Join-Path $root "http"
$resultsDir = Join-Path $root "results"
New-Item -ItemType Directory -Force -Path $resultsDir | Out-Null

function Test-CommandExists {
    param([string]$Name)
    return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

if (-not (Test-CommandExists "hey")) {
    Write-Host "[!] 'hey' no esta en PATH. Descargalo de https://github.com/rakyll/hey/releases" -ForegroundColor Red
    Write-Host "    (binario unico hey_windows_amd64.exe, sin dependencias)" -ForegroundColor Red
    exit 1
}

$servers = @(
    @{ Name = "Orbit"; Port = 3000; Dir = Join-Path $httpDir "orbit"; StartCmd = { orbit build server.orb; if (Test-Path "orbit_app.exe") { Move-Item -Force "orbit_app.exe" "server.exe" }; Start-Process -PassThru -NoNewWindow -FilePath ".\server.exe" } },
    @{ Name = "C";     Port = 8081; Dir = Join-Path $httpDir "c";     StartCmd = { zig cc server.c -O3 -o server.exe -lws2_32; Start-Process -PassThru -NoNewWindow -FilePath ".\server.exe" } },
    @{ Name = "Node";  Port = 8082; Dir = Join-Path $httpDir "node";  StartCmd = { Start-Process -PassThru -NoNewWindow -FilePath "node" -ArgumentList "server.js" } },
    @{ Name = "Python";Port = 8083; Dir = Join-Path $httpDir "python";StartCmd = { Start-Process -PassThru -NoNewWindow -FilePath "uvicorn" -ArgumentList "server:app","--host","0.0.0.0","--port","8083" } }
)

$routes = @("/ping", "/json", "/compute")
$results = @()

function Wait-ForPort {
    param([int]$Port, [int]$TimeoutSeconds = 15)
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        try {
            $conn = New-Object System.Net.Sockets.TcpClient
            $conn.Connect("127.0.0.1", $Port)
            $conn.Close()
            return $true
        } catch {
            Start-Sleep -Milliseconds 300
        }
    }
    return $false
}

function Parse-HeyOutput {
    param([string]$RawOutput)
    $rps = $null
    $p50 = $null
    $p99 = $null

    foreach ($line in $RawOutput -split "`n") {
        if ($line -match "Requests/sec:\s+([\d\.]+)") { $rps = [double]$matches[1] }
        if ($line -match "50% in\s+([\d\.]+)\s*(\w+)") { $p50 = $matches[1] + " " + $matches[2] }
        if ($line -match "99% in\s+([\d\.]+)\s*(\w+)") { $p99 = $matches[1] + " " + $matches[2] }
    }
    return [PSCustomObject]@{ RequestsPerSec = $rps; P50 = $p50; P99 = $p99 }
}

foreach ($server in $servers) {
    Write-Host ""
    Write-Host "=== Servidor: $($server.Name) ===" -ForegroundColor Cyan

    if (-not (Test-Path $server.Dir)) {
        Write-Host "  [!] No existe $($server.Dir), se salta." -ForegroundColor Red
        continue
    }

    Push-Location $server.Dir
    $proc = $null
    try {
        Write-Host "  Compilando / iniciando..."
        $proc = & $server.StartCmd

        if (-not (Wait-ForPort -Port $server.Port)) {
            Write-Host "  [!] El servidor no respondio en el puerto $($server.Port) a tiempo." -ForegroundColor Red
            continue
        }
        Write-Host "  Servidor listo en puerto $($server.Port)."
        Start-Sleep -Seconds 1

        foreach ($route in $routes) {
            foreach ($concLevel in @($Concurrency, $HighConcurrency)) {
                $url = "http://127.0.0.1:$($server.Port)$route"
                Write-Host "  hey -z ${DurationSeconds}s -c $concLevel $url"

                $heyOutput = & hey -z "${DurationSeconds}s" -c $concLevel $url 2>&1 | Out-String
                $parsed = Parse-HeyOutput -RawOutput $heyOutput
                if ($null -eq $parsed.RequestsPerSec) {
                    Write-Host "  [!] No pude parsear 'Requests/sec' de hey. Salida cruda:" -ForegroundColor Yellow
                    Write-Host $heyOutput
                }

                $results += [PSCustomObject]@{
                    Server         = $server.Name
                    Route          = $route
                    Concurrency    = $concLevel
                    RequestsPerSec = $parsed.RequestsPerSec
                    P50            = $parsed.P50
                    P99            = $parsed.P99
                }
            }
        }
    } finally {
        if ($proc -and -not $proc.HasExited) {
            Write-Host "  Deteniendo servidor (PID $($proc.Id))..."
            Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
        }
        # Por si el runtime lanza un proceso hijo con otro nombre (uvicorn/python)
        Start-Sleep -Milliseconds 500
        Pop-Location
    }
}

$csvPath = Join-Path $resultsDir "http_bench_results.csv"
$results | Export-Csv -Path $csvPath -NoTypeInformation
Write-Host ""
Write-Host "Resultados guardados en $csvPath" -ForegroundColor Green

Write-Host ""
Write-Host "=== Resumen (Requests/sec, mayor es mejor) ===" -ForegroundColor Cyan
$results | Format-Table Server, Route, Concurrency, RequestsPerSec, P50, P99 -AutoSize
