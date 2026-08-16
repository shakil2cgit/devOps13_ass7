const http = require('http');
const fs = require('fs');
const path = require('path');
const url = require('url');

const PORT = process.env.PORT || 3000;
const PUBLIC_DIR = path.join(__dirname, 'public');

let isHealthy = true;
let mockInstanceId = 'i-' + Math.random().toString(16).substring(2, 10) + 'ab89';
let mockAZ = ['us-east-1a', 'us-east-1b'][Math.floor(Math.random() * 2)];
let mockIp = '10.0.3.' + Math.floor(Math.random() * 200 + 10);

const mimeTypes = {
  '.html': 'text/html',
  '.css': 'text/css',
  '.js': 'text/javascript',
  '.json': 'application/json',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.svg': 'image/svg+xml'
};

const server = http.createServer((req, res) => {
  const parsedUrl = url.parse(req.url, true);
  const pathname = parsedUrl.pathname;

  // CORS headers
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');

  if (req.method === 'OPTIONS') {
    res.writeHead(204);
    res.end();
    return;
  }

  // 1. ALB Target Group Health Check
  if (pathname === '/health') {
    if (!isHealthy) {
      res.writeHead(500, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ status: 'DOWN', error: 'Instance marked unhealthy' }));
      return;
    }
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({
      status: 'UP',
      instanceId: mockInstanceId,
      az: mockAZ,
      privateIp: mockIp,
      timestamp: new Date().toISOString()
    }));
    return;
  }

  // 2. Unhealthy Simulation Endpoint
  if (pathname === '/unhealthy') {
    res.writeHead(500, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ status: 'DOWN', error: 'Simulated node failure' }));
    return;
  }

  // 3. Metadata API for UI
  if (pathname === '/api/metadata') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({
      instanceId: mockInstanceId,
      az: mockAZ,
      privateIp: mockIp
    }));
    return;
  }

  // 4. Toggle Health API
  if (pathname === '/api/toggle-health') {
    isHealthy = !isHealthy;
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ healthy: isHealthy }));
    return;
  }

  // 5. Static File Serving
  let filePath = path.join(PUBLIC_DIR, pathname === '/' ? 'index.html' : pathname);
  const ext = path.extname(filePath).toLowerCase();
  const contentType = mimeTypes[ext] || 'application/octet-stream';

  fs.readFile(filePath, (err, content) => {
    if (err) {
      if (err.code === 'ENOENT') {
        res.writeHead(404, { 'Content-Type': 'text/plain' });
        res.end('404 Not Found');
      } else {
        res.writeHead(500, { 'Content-Type': 'text/plain' });
        res.end('500 Server Error');
      }
    } else {
      res.writeHead(200, { 'Content-Type': contentType });
      res.end(content, 'utf-8');
    }
  });
});

server.listen(PORT, () => {
  console.log(`=======================================================`);
  console.log(` 🚀 SSC Result 2026 Node Server running on port ${PORT}`);
  console.log(` 📍 Instance ID: ${mockInstanceId} | AZ: ${mockAZ} | IP: ${mockIp}`);
  console.log(` 🌐 Open: http://localhost:${PORT}`);
  console.log(`=======================================================`);
});
