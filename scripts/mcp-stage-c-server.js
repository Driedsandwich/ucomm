const http = require('http');
const fs = require('fs');
const path = require('path');

const host = '127.0.0.1';
const port = parseInt(process.env.MCP_PORT || '39201', 10);

class MCPStageCSserver {
  constructor() {
    this.allowedDomains = [
      'api.github.com',
      'raw.githubusercontent.com'
    ];
    this.allowedMethods = ['GET', 'POST'];
    this.secureMode = process.env.UCOMM_SECURE_MODE === '1';
    this.requestLog = [];
  }

  isAllowedURL(url) {
    try {
      const urlObj = new URL(url);
      return this.allowedDomains.some(domain => 
        urlObj.hostname === domain || urlObj.hostname.endsWith('.' + domain)
      );
    } catch {
      return false;
    }
  }

  isWriteOperation(method, url) {
    // Detect write operations that should be blocked
    const writePatterns = [
      '/repos/.*/issues',     // Creating issues
      '/repos/.*/pulls',      // Creating PRs  
      '/repos/.*/contents/',  // Writing files
      '/user/repos'           // Creating repos
    ];
    
    if (method !== 'GET' && method !== 'POST') {
      return true; // PUT, DELETE, PATCH are write operations
    }
    
    if (method === 'POST') {
      // GraphQL queries are allowed POST operations
      if (url.includes('/graphql')) {
        return false;
      }
      // Other POST operations to write endpoints should be blocked
      return writePatterns.some(pattern => 
        new RegExp(pattern.replace('*', '.*')).test(url)
      );
    }
    
    return false;
  }

  async proxyRequest(req, res) {
    try {
      const body = JSON.parse(req.body);
      const { url, method, headers = {} } = body;

      console.log(`[MCP] ${method} ${url}`);

      if (!this.isAllowedURL(url)) {
        return this.sendError(res, 403, 'URL not in allowlist');
      }

      if (!this.allowedMethods.includes(method)) {
        return this.sendError(res, 405, 'Method not allowed');
      }

      if (this.isWriteOperation(method, url)) {
        console.log(`[SECURITY] Blocked write operation: ${method} ${url}`);
        if (this.secureMode) {
          return this.sendError(res, 403, 'Write operations not allowed in secure mode');
        } else {
          return this.sendError(res, 403, 'Write operations not allowed');
        }
      }

      // Log the request
      this.requestLog.push({
        timestamp: new Date().toISOString(),
        method,
        url,
        hasAuth: !!(headers.Authorization || headers.authorization),
        blocked: false
      });

      // Simulate successful responses for testing
      if (url.includes('/repos/octocat/Hello-World')) {
        return this.sendJSON(res, {
          name: 'Hello-World',
          full_name: 'octocat/Hello-World',
          description: 'This your first repo!',
          private: false,
          html_url: 'https://github.com/octocat/Hello-World'
        });
      }

      if (url.includes('/user') && (headers.Authorization || headers.authorization)) {
        return this.sendJSON(res, {
          login: 'testuser',
          id: 123456,
          type: 'User'
        });
      }

      if (url.includes('/graphql')) {
        const query = JSON.parse(req.body).body;
        if (query && query.query && query.query.includes('repository')) {
          return this.sendJSON(res, {
            data: {
              repository: {
                name: 'Hello-World',
                description: 'This your first repo!',
                stargazerCount: 50,
                isPrivate: false
              }
            }
          });
        }
      }

      // Default success response
      this.sendJSON(res, { 
        message: 'Mocked response for testing',
        url: url,
        method: method 
      });

    } catch (error) {
      console.error('[MCP] Error:', error);
      this.sendError(res, 500, 'Internal server error');
    }
  }

  sendJSON(res, data) {
    res.writeHead(200, { 
      'Content-Type': 'application/json',
      'X-RateLimit-Remaining': '4999',
      'X-RateLimit-Limit': '5000'
    });
    res.end(JSON.stringify(data));
  }

  sendError(res, code, message) {
    res.writeHead(code, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ 
      error: message, 
      code: code,
      ts: Date.now() 
    }));
  }

  createServer() {
    const server = http.createServer((req, res) => {
      let body = '';
      
      req.on('data', chunk => body += chunk);
      req.on('end', () => {
        req.body = body;
        
        if (req.url === '/health') {
          const latency = Math.floor(Math.random() * 50) + 10; // 10-60ms
          return this.sendJSON(res, { 
            ok: true, 
            code: 200, 
            ts: Date.now(), 
            latency_ms: latency,
            server: 'mcp-stage-c',
            requestCount: this.requestLog.length
          });
        }

        if (req.url === '/deny') {
          res.writeHead(403, { 'Content-Type': 'application/json' });
          return res.end(JSON.stringify({ 
            ok: false, 
            code: 403, 
            ts: Date.now(), 
            err: 'forbidden' 
          }));
        }

        if (req.url === '/mcp/v1/tools/fetch' && req.method === 'POST') {
          return this.proxyRequest(req, res);
        }

        // Default 404
        res.writeHead(404, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ 
          ok: false, 
          code: 404, 
          ts: Date.now(), 
          err: 'not-found' 
        }));
      });
    });

    return server;
  }

  start() {
    const server = this.createServer();
    
    server.listen(port, host, () => {
      console.log(JSON.stringify({ 
        ok: true, 
        code: 200, 
        ts: Date.now(), 
        msg: `MCP Stage C server listening ${host}:${port}`,
        secureMode: this.secureMode
      }));
    });

    // Graceful shutdown
    process.on('SIGINT', () => {
      console.log('\n[MCP] Shutting down...');
      
      // Save request log
      fs.writeFileSync('mcp-stage-c-requests.json', 
        JSON.stringify(this.requestLog, null, 2));
      
      server.close();
      process.exit(0);
    });
  }
}

const mcpServer = new MCPStageCSserver();
mcpServer.start();