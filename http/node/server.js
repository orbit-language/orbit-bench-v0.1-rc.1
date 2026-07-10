// Servidor HTTP en Node.js usando el modulo http nativo (sin frameworks),
// para comparar el runtime "puro" contra Orbit.

const http = require("http");

function fib(n) {
  if (n < 2) return n;
  return fib(n - 1) + fib(n - 2);
}

const server = http.createServer((req, res) => {
  if (req.url === "/ping") {
    res.writeHead(200, { "Content-Type": "text/plain" });
    res.end("pong");
  } else if (req.url === "/json") {
    res.writeHead(200, { "Content-Type": "application/json" });
    res.end(JSON.stringify({ message: "hello", status: "ok", value: 42 }));
  } else if (req.url === "/compute") {
    const result = fib(27);
    res.writeHead(200, { "Content-Type": "application/json" });
    res.end(JSON.stringify({ fib: result }));
  } else {
    res.writeHead(404, { "Content-Type": "text/plain" });
    res.end("Not Found");
  }
});

const PORT = 8082;
server.listen(PORT, () => {
  console.log(`Node server listening on port ${PORT}`);
});
