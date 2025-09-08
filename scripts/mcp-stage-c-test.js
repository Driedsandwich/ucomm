const http = require('http');
const fs = require('fs');

const MCP_PORT = parseInt(process.env.MCP_PORT || '39201', 10);
const GITHUB_TOKEN = process.env.GITHUB_TOKEN;
const SECURE_MODE = process.env.UCOMM_SECURE_MODE === '1';

class GitHubAPITester {
  constructor() {
    this.results = [];
    this.violations = [];
  }

  async makeRequest(method, path, body = null, headers = {}) {
    return new Promise((resolve, reject) => {
      const options = {
        hostname: 'localhost',
        port: MCP_PORT,
        path: `/mcp/v1/tools/fetch`,
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          ...headers
        }
      };

      const req = http.request(options, (res) => {
        let data = '';
        res.on('data', chunk => data += chunk);
        res.on('end', () => {
          try {
            resolve(JSON.parse(data));
          } catch (e) {
            resolve({ error: 'Invalid JSON response', raw: data });
          }
        });
      });

      req.on('error', reject);

      const payload = {
        url: `https://api.github.com${path}`,
        method: method,
        headers: headers,
        ...(body && { body: JSON.stringify(body) })
      };

      req.write(JSON.stringify(payload));
      req.end();
    });
  }

  async testAnonymousAccess() {
    console.log('Testing anonymous access...');
    try {
      // Test public repository API access
      const result = await this.makeRequest('GET', '/repos/octocat/Hello-World');
      
      this.results.push({
        test: 'anonymous_public_repo',
        success: !result.error && result.name === 'Hello-World',
        rateLimit: result.headers && result.headers['x-ratelimit-remaining'],
        response: result
      });

      console.log('Anonymous access test completed');
      return result;
    } catch (error) {
      console.error('Anonymous access test failed:', error);
      this.results.push({
        test: 'anonymous_public_repo',
        success: false,
        error: error.message
      });
    }
  }

  async testAuthenticatedAccess() {
    if (!GITHUB_TOKEN) {
      console.log('Skipping authenticated access test (no token)');
      return;
    }

    console.log('Testing authenticated access...');
    try {
      const headers = {
        'Authorization': `Bearer ${GITHUB_TOKEN}`
      };

      const result = await this.makeRequest('GET', '/user', null, headers);
      
      this.results.push({
        test: 'authenticated_user_info',
        success: !result.error && result.login,
        rateLimit: result.headers && result.headers['x-ratelimit-remaining'],
        response: { login: result.login } // Don't log full user details
      });

      console.log('Authenticated access test completed');
      return result;
    } catch (error) {
      console.error('Authenticated access test failed:', error);
      this.results.push({
        test: 'authenticated_user_info',
        success: false,
        error: error.message
      });
    }
  }

  async testGraphQLQuery() {
    console.log('Testing GraphQL query...');
    try {
      const query = {
        query: `
          query {
            repository(owner: "octocat", name: "Hello-World") {
              name
              description
              stargazerCount
              isPrivate
            }
          }
        `
      };

      const headers = GITHUB_TOKEN ? 
        { 'Authorization': `Bearer ${GITHUB_TOKEN}` } : {};

      const result = await this.makeRequest('POST', '/graphql', query, headers);
      
      const success = !result.error && 
                     result.data && 
                     result.data.repository &&
                     result.data.repository.name === 'Hello-World';

      this.results.push({
        test: 'graphql_query',
        success: success,
        response: result.data || result.error
      });

      console.log('GraphQL query test completed');
      return result;
    } catch (error) {
      console.error('GraphQL query test failed:', error);
      this.results.push({
        test: 'graphql_query',
        success: false,
        error: error.message
      });
    }
  }

  async testBoundaryViolation() {
    console.log('Testing boundary violation detection...');
    try {
      // Attempt a write operation (should be blocked by MCP policy)
      const headers = GITHUB_TOKEN ? 
        { 'Authorization': `Bearer ${GITHUB_TOKEN}` } : {};

      const result = await this.makeRequest('POST', '/repos/octocat/Hello-World/issues', {
        title: 'Test issue',
        body: 'This should be blocked'
      }, headers);

      // If this succeeds, it's a security violation
      if (!result.error) {
        this.violations.push({
          test: 'boundary_write_attempt',
          violation: 'Write operation was not blocked',
          response: result
        });
        
        if (SECURE_MODE) {
          throw new Error('SECURITY VIOLATION: Write operation succeeded in secure mode');
        }
      }

      this.results.push({
        test: 'boundary_write_attempt',
        success: !!result.error, // Success means the write was blocked
        blocked: !!result.error,
        response: result.error || 'Write was not blocked'
      });

      console.log('Boundary violation test completed');
    } catch (error) {
      console.error('Boundary violation test failed:', error);
      this.results.push({
        test: 'boundary_write_attempt',
        success: false,
        error: error.message
      });
    }
  }

  async generateReport() {
    const report = {
      timestamp: new Date().toISOString(),
      secureMode: SECURE_MODE,
      hasToken: !!GITHUB_TOKEN,
      totalTests: this.results.length,
      passed: this.results.filter(r => r.success).length,
      failed: this.results.filter(r => !r.success).length,
      violations: this.violations,
      results: this.results
    };

    // Write detailed report
    fs.writeFileSync('stage-c-results.json', JSON.stringify(report, null, 2));
    
    // Write summary for CI
    const summary = {
      ok: report.failed === 0 && report.violations.length === 0,
      code: report.failed === 0 && report.violations.length === 0 ? 200 : 500,
      passed: report.passed,
      failed: report.failed,
      violations: report.violations.length,
      secureMode: SECURE_MODE
    };
    
    fs.writeFileSync('stage-c-summary.json', JSON.stringify(summary, null, 2));
    
    console.log('\n--- Stage C Test Report ---');
    console.log(`Tests: ${report.passed}/${report.totalTests} passed`);
    console.log(`Violations: ${report.violations.length}`);
    console.log(`Secure Mode: ${SECURE_MODE}`);
    
    if (report.violations.length > 0 && SECURE_MODE) {
      console.error('FAIL: Security violations detected in secure mode');
      process.exit(1);
    }
    
    if (report.failed > 0) {
      console.error('FAIL: Some tests failed');
      process.exit(1);
    }
    
    console.log('SUCCESS: All tests passed');
  }

  async run() {
    console.log('Starting MCP Stage C GitHub API boundary tests...');
    console.log(`MCP Port: ${MCP_PORT}`);
    console.log(`Secure Mode: ${SECURE_MODE}`);
    console.log(`GitHub Token: ${GITHUB_TOKEN ? 'Present' : 'Not present'}`);
    
    await this.testAnonymousAccess();
    await this.testAuthenticatedAccess();
    await this.testGraphQLQuery();
    await this.testBoundaryViolation();
    
    await this.generateReport();
  }
}

// Run tests
const tester = new GitHubAPITester();
tester.run().catch(error => {
  console.error('Stage C tests failed:', error);
  process.exit(1);
});