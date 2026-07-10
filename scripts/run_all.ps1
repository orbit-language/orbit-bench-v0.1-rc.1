# run_all.ps1
# Corre microbenchmarks + benchmark HTTP en una sola pasada.
#
# Uso:
#   powershell -ExecutionPolicy Bypass -File scripts/run_all.ps1

$ErrorActionPreference = "Continue"
$scriptDir = $PSScriptRoot

Write-Host "############################################" -ForegroundColor Magenta
Write-Host "# Orbit Benchmark Suite                    #" -ForegroundColor Magenta
Write-Host "############################################" -ForegroundColor Magenta

Write-Host ""
Write-Host ">>> Fase 1: Microbenchmarks (CPU / runtime puro)" -ForegroundColor Magenta
powershell -ExecutionPolicy Bypass -File (Join-Path $scriptDir "run_microbench.ps1")

Write-Host ""
Write-Host ">>> Fase 2: Benchmark HTTP (throughput / latencia)" -ForegroundColor Magenta
powershell -ExecutionPolicy Bypass -File (Join-Path $scriptDir "run_http_bench.ps1")

Write-Host ""
Write-Host "Listo. Revisa la carpeta 'results/' para los CSV generados." -ForegroundColor Green
