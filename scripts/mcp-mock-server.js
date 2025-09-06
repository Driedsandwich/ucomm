const http = require('http');
const host = '127.0.0.1';
const port = parseInt(process.env.MCP_PORT || '39200', 10);
// Trigger workflow for measurement

const server = http.createServer((req, res) => {
  const start = Date.now();
  const url = new URL(req.url, `http://${host}:${port}`);
  res.setHeader('Content-Type','application/json; charset=utf-8');

  if (req.method !== 'GET') {
    res.statusCode = 405;
    return res.end(JSON.stringify({ ok:false, code:405, ts:Date.now(), err:"method-not-allowed" }));
  }
  if (url.pathname === '/health') {
    const latency = Date.now() - start;
    return res.end(JSON.stringify({ ok:true, code:200, ts:Date.now(), latency_ms:latency, server:"mcp-mock" }));
  }
  res.statusCode = 403;
  res.end(JSON.stringify({ ok:false, code:403, ts:Date.now(), err:"forbidden" }));
});

server.listen(port, host, () => {
  console.log(JSON.stringify({ ok:true, code:200, ts:Date.now(), msg:`listening ${host}:${port}` }));
});