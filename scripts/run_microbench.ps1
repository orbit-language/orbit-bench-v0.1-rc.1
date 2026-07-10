# run_microbench.ps1
# Compila y ejecuta los microbenchmarks de Orbit, C, Node.js y Python,
# midiendo tiempo de pared (wall time) de cada ejecucion.
#
# Uso:
#   powershell -ExecutionPolicy Bypass -File scripts/run_microbench.ps1
#
# Requisitos en PATH: orbit, zig (o cl.exe / gcc), node, python

param(
    [int]$Runs = 5
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$microbenchDir = Join-Path $root "microbench"
$resultsDir = Join-Path $root "results"
New-Item -ItemType Directory -Force -Path $resultsDir | Out-Null

$benchmarks = @("fib", "loop", "strings", "array_sum")
$results = @()

function Measure-Runs {
    param(
        [string]$Name,
        [string]$Lang,
        [scriptblock]$Action,
        [int]$Runs
    )

    $times = @()
    $output = $null
    for ($i = 0; $i -lt $Runs; $i++) {
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $output = & $Action
        $sw.Stop()
        $times += $sw.Elapsed.TotalMilliseconds
        Write-Host ("  [{0}/{1}] {2,-10} {3,-10} {4,10:N2} ms" -f ($i+1), $Runs, $Lang, $Name, $sw.Elapsed.TotalMilliseconds)
    }

    $sorted = $times | Sort-Object
    $median = $sorted[[int]([math]::Floor($sorted.Count / 2))]
    $min = $sorted[0]
    $max = $sorted[-1]
    $avg = ($times | Measure-Object -Average).Average

    return [PSCustomObject]@{
        Benchmark = $Name
        Language  = $Lang
        MedianMs  = [math]::Round($median, 2)
        AvgMs     = [math]::Round($avg, 2)
        MinMs     = [math]::Round($min, 2)
        MaxMs     = [math]::Round($max, 2)
        Output    = ($output | Out-String).Trim()
    }
}

Write-Host "=== Compilando binarios nativos (Orbit y C) ===" -ForegroundColor Cyan

foreach ($bench in $benchmarks) {
    $orbitSrc = Join-Path $microbenchDir "orbit\$bench.orb"
    $cSrc = Join-Path $microbenchDir "c\$bench.c"
    $cOut = Join-Path $microbenchDir "c\$bench.exe"

    Write-Host "Building Orbit: $bench.orb"
    Push-Location (Join-Path $microbenchDir "orbit")
    $eap = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    orbit build "$bench.orb" 2>&1 | Out-Null
    $ErrorActionPreference = $eap
    if (Test-Path "orbit_app.exe") { Move-Item -Force "orbit_app.exe" "$bench.exe" }
    Pop-Location

    Write-Host "Building C: $bench.c"
    zig cc $cSrc -O3 -o $cOut 2>&1 | Out-Null
}

Write-Host ""
Write-Host "=== Ejecutando microbenchmarks ($Runs corridas cada uno) ===" -ForegroundColor Cyan

foreach ($bench in $benchmarks) {
    Write-Host ""
    Write-Host "--- $bench ---" -ForegroundColor Yellow

    # Orbit (ya compilado a .exe por 'orbit build' en el directorio orbit/)
    $orbitExe = Join-Path $microbenchDir "orbit\$bench.exe"
    if (Test-Path $orbitExe) {
        $results += Measure-Runs -Name $bench -Lang "Orbit" -Runs $Runs -Action {
            & $orbitExe
        }
    } else {
        Write-Host "  [!] No se encontro $orbitExe, se salta Orbit para $bench" -ForegroundColor Red
    }

    # C
    $cExe = Join-Path $microbenchDir "c\$bench.exe"
    if (Test-Path $cExe) {
        $results += Measure-Runs -Name $bench -Lang "C" -Runs $Runs -Action {
            & $cExe
        }
    }

    # Node.js
    $nodeSrc = Join-Path $microbenchDir "node\$bench.js"
    $results += Measure-Runs -Name $bench -Lang "Node" -Runs $Runs -Action {
        node $nodeSrc
    }

    # Python
    $pySrc = Join-Path $microbenchDir "python\$bench.py"
    $results += Measure-Runs -Name $bench -Lang "Python" -Runs $Runs -Action {
        python $pySrc
    }
}

$csvPath = Join-Path $resultsDir "microbench_results.csv"
$results | Select-Object Benchmark, Language, MedianMs, AvgMs, MinMs, MaxMs | Export-Csv -Path $csvPath -NoTypeInformation
Write-Host ""
Write-Host "Resultados guardados en $csvPath" -ForegroundColor Green

Write-Host ""
Write-Host "=== Resumen (mediana en ms, menor es mejor) ===" -ForegroundColor Cyan
$results | Sort-Object Benchmark, MedianMs | Format-Table Benchmark, Language, MedianMs, AvgMs, MinMs, MaxMs -AutoSize
