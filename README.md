# Orbit Benchmark Suite

Suite de benchmarks para medir el rendimiento de **Orbit** (lenguaje compilado)
frente a **C**, **Node.js** y **Python**, en dos dimensiones:

- **Microbenchmarks** — CPU/runtime puro (fibonacci recursivo, loops, strings, suma de arrays).
- **HTTP** — throughput de un servidor mínimo (`/ping`, `/json`, `/compute`).

## Requisitos

Todo debe estar en el `PATH`:

| Herramienta | Uso | Instalación |
|---|---|---|
| `orbit` | Compilar los `.orb` | Compilador de Orbit |
| `zig` | `zig cc -O3` compila los targets en C (y es backend de Orbit) | ziglang.org |
| `node` | Servidor y microbench de Node | nodejs.org |
| `python` + `fastapi` + `uvicorn` | Servidor y microbench de Python | `pip install fastapi uvicorn` |
| `hey` | Generador de carga HTTP | `go install github.com/rakyll/hey@latest` |
| PowerShell 5+ | Orquesta los scripts | Windows |

## Estructura

orbit-bench/
├── http/            # Servidores HTTP equivalentes en cada lenguaje
│   ├── c/server.c
│   ├── node/server.js
│   ├── orbit/server.orb
│   └── python/server.py
├── microbench/      # Microbenchmarks equivalentes en cada lenguaje
│   ├── c/           # fib, loop, strings, array_sum
│   ├── node/
│   ├── orbit/
│   └── python/
├── results/         # CSVs generados (ignorados por git)
├── scripts/
│   ├── run_all.ps1          # Corre todo
│   ├── run_microbench.ps1   # Fase 1 (CPU)
│   └── run_http_bench.ps1   # Fase 2 (HTTP)
└── README.md

## Uso

### Suite completa
```ps
powershell -ExecutionPolicy Bypass -File scriptsrun_all.ps1
```

### O por fases
```ps
powershell -ExecutionPolicy Bypass -File scriptsrun_microbench.ps1
```

```ps
powershell -ExecutionPolicy Bypass -File scriptsrun_http_bench.ps1
```

Los resultados se guardan en `results/*.csv`.

## Resultados

> Entorno: Windows. Orbit y C compilados nativos (`zig cc -O3`).
> Medición: mediana de 5 corridas (microbench) y `Requests/sec` de `hey` (HTTP).

### Microbenchmarks — mediana en ms (menor es mejor)

| Benchmark | Orbit | C (-O3) | Node | Python |
|---|---|---|---|---|
| fib | **41,1** | 42,2 | 281,0 | 940,5 |
| loop | **25,0** | 28,1 | 407,7 | 29.958,2 |
| strings | 567,9 | **21,6** | 173,7 | 249,6 |
| array_sum | — | **25,4** | 288,7 | 336,2 |

### HTTP — Requests/sec (mayor es mejor)

| Ruta | Conc. | Orbit | C | Node | Python |
|---|---|---|---|---|---|
| /ping | 1 | 1.000,8 | 1.624,5 | **4.045,6** | 512,9 |
| /ping | 50 | 2.968,4 | 2.976,8 | **7.383,4** | 576,2 |
| /json | 1 | 1.604,3 | 1.448,2 | **4.942,1** | 444,8 |
| /json | 50 | 3.004,1 | 3.026,8 | **7.674,9** | 255,9 |
| /compute | 1 | 446,3 | **451,9** | 174,6 | 5,4 |
| /compute | 50 | **2.172,9** | 2.264,0 | 186,0 | 10,6 |

### Conclusiones

- **Cómputo nativo:** en `fib` y `loop` Orbit rinde a la par de C con `-O3`; en
  `/compute` (CPU-bound) empata a C y supera ampliamente a Node y Python.
- **Strings:** punto débil actual de Orbit (~26x más lento que C). Principal
  candidato de optimización (estrategia de allocation en la concatenación).
- **I/O:** en rutas de I/O puro (`/ping`, `/json`) Node lidera por su event loop;
  Orbit y C (single-threaded/blocking) quedan parejos por debajo.

## Notas y limitaciones

- `array_sum` aún no compila en Orbit (usa arrays dinámicos + `for-in`, todavía no soportados).
- Los servidores de Orbit y C son single-threaded/blocking a propósito, para una
  lectura honesta a baja concurrencia.
- En Windows, `hey` reporta latencias por-request en ~0 para respuestas locales
  muy rápidas, por lo que P50/P99 pueden salir vacías. El `Requests/sec` es la
  métrica confiable.

## Licencia

MIT — ver [LICENSE](LICENSE).

