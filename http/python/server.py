# Servidor HTTP en FastAPI + uvicorn, para comparar un stack "moderno y
# realista" de Python contra Orbit.
#
# Instalar dependencias:
#   pip install fastapi uvicorn[standard]
#
# Correr:
#   uvicorn server:app --host 0.0.0.0 --port 8083 --workers 1

from fastapi import FastAPI
from fastapi.responses import PlainTextResponse

app = FastAPI()


def fib(n: int) -> int:
    if n < 2:
        return n
    return fib(n - 1) + fib(n - 2)


@app.get("/ping", response_class=PlainTextResponse)
def ping():
    return "pong"


@app.get("/json")
def json_route():
    return {"message": "hello", "status": "ok", "value": 42}


@app.get("/compute")
def compute():
    result = fib(27)
    return {"fib": result}
