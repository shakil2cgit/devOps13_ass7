#!/bin/bash
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y nginx curl jq

# Fetch IMDSv2 Token & Metadata
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id || hostname)
AZ=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/placement/availability-zone || echo "ap-southeast-1a")
PRIVATE_IP=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/local-ipv4 || hostname -I | awk '{print $1}')

mkdir -p /var/www/html

cat <<EOF > /var/www/html/index.html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>Ministry of Education - SSC Result 2026</title>
  <style>
    body { font-family: 'Segoe UI', Tahoma, sans-serif; background: #f0fdf4; margin: 0; padding: 20px; display: flex; justify-content: center; }
    .box { width: 100%; max-width: 800px; background: white; border-radius: 12px; box-shadow: 0 4px 15px rgba(0,0,0,0.08); overflow: hidden; border: 1px solid #e2e8f0; }
    .header { background: #0d6e47; color: white; padding: 20px; text-align: center; }
    .meta-bar { background: #0f172a; color: #fff; padding: 15px; display: flex; justify-content: space-around; font-family: monospace; font-size: 0.95rem; }
    .meta-bar span { color: #38bdf8; font-weight: bold; }
    .content { padding: 25px; }
    .form-group { margin-bottom: 12px; }
    label { font-weight: 600; font-size: 0.9rem; }
    input, select, button { width: 100%; padding: 10px; border-radius: 6px; border: 1px solid #cbd5e1; box-sizing: border-box; margin-top: 4px; font-size: 0.95rem; }
    button { background: #0d6e47; color: white; font-weight: bold; cursor: pointer; border: none; margin-top: 15px; }
    button:hover { background: #074a30; }
    .result { display: none; margin-top: 20px; background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 8px; padding: 15px; }
    .tools { margin-top: 20px; padding: 15px; background: #f1f5f9; border-radius: 8px; display: flex; gap: 8px; flex-wrap: wrap; }
    .btn-t { width: auto; flex: 1; padding: 8px 12px; background: white; color: #334155; border: 1px solid #cbd5e1; font-size: 0.85rem; }
  </style>
</head>
<body>
  <div class="box">
    <div class="header">
      <h2>🎓 Ministry of Education, Bangladesh</h2>
      <p>SSC Result 2026 • High-Availability Cloud Infrastructure (Ubuntu on t3.micro)</p>
    </div>
    <div class="meta-bar">
      <div>Instance: <span>$INSTANCE_ID</span></div>
      <div>AZ: <span style="color:#4ade80;">$AZ</span></div>
      <div>IP: <span style="color:#fbbf24;">$PRIVATE_IP</span></div>
    </div>
    <div class="content">
      <h3>Search Result 2026</h3>
      <div class="form-group"><label>Examination:</label><select><option>SSC/Dakhil/Equivalent 2026</option></select></div>
      <div class="form-group"><label>Board:</label><select id="board"><option>Dhaka</option><option>Chittagong</option><option>Rajshahi</option><option>Comilla</option></select></div>
      <div class="form-group"><label>Roll Number:</label><input type="text" id="roll" value="100201"></div>
      <div class="form-group"><label>Registration No:</label><input type="text" id="reg" value="1512345678"></div>
      <button onclick="showResult()">Get Result</button>
      
      <div class="result" id="res-box">
        <h4 style="color:#0d6e47; margin:0 0 8px 0;">🎉 PASSED - GPA: 5.00 (Golden A+)</h4>
        <p>Candidate: <strong id="c-name">Tanvir Ahmed</strong> | Roll: <span id="c-roll">100201</span> | Board: <span id="c-board">Dhaka</span></p>
        <table style="width:100%; border-collapse:collapse; margin-top:10px; font-size:0.85rem;">
          <tr style="background:#e2e8f0; text-align:left;"><th style="padding:6px;">Subject</th><th style="padding:6px;">Grade</th><th style="padding:6px;">Point</th></tr>
          <tr><td style="padding:6px; border-bottom:1px solid #eee;">Bangla</td><td style="padding:6px; border-bottom:1px solid #eee;">A+</td><td style="padding:6px; border-bottom:1px solid #eee;">5.0</td></tr>
          <tr><td style="padding:6px; border-bottom:1px solid #eee;">English</td><td style="padding:6px; border-bottom:1px solid #eee;">A+</td><td style="padding:6px; border-bottom:1px solid #eee;">5.0</td></tr>
          <tr><td style="padding:6px; border-bottom:1px solid #eee;">Mathematics</td><td style="padding:6px; border-bottom:1px solid #eee;">A+</td><td style="padding:6px; border-bottom:1px solid #eee;">5.0</td></tr>
          <tr><td style="padding:6px; border-bottom:1px solid #eee;">Physics/Chem/Bio</td><td style="padding:6px; border-bottom:1px solid #eee;">A+</td><td style="padding:6px; border-bottom:1px solid #eee;">5.0</td></tr>
        </table>
      </div>

      <div class="tools">
        <button class="btn-t" onclick="window.location.reload()">🔄 Refresh (Test ALB Round-Robin)</button>
        <button class="btn-t" onclick="alert('Simulating 10:00 AM Traffic Spike on Node $INSTANCE_ID')">⚡ Simulate 10 AM Traffic Spike</button>
        <a href="/health" target="_blank" style="text-decoration:none;"><button class="btn-t">🩺 /health Check</button></a>
      </div>
    </div>
  </div>
  <script>
    function showResult() {
      const r = document.getElementById('roll').value;
      const b = document.getElementById('board').value;
      document.getElementById('c-roll').innerText = r;
      document.getElementById('c-board').innerText = b;
      document.getElementById('c-name').innerText = 'Student Candidate ' + r;
      document.getElementById('res-box').style.display = 'block';
    }
  </script>
</body>
</html>
EOF

# Configure Nginx with /health endpoint
cat <<EOF > /etc/nginx/sites-available/default
server {
    listen 80 default_server;
    root /var/www/html;
    index index.html;
    location / { try_files \$uri \$uri/ =404; }
    location /health { default_type application/json; return 200 '{"status":"UP","instance":"$INSTANCE_ID","az":"$AZ"}'; }
}
EOF

systemctl restart nginx
systemctl enable nginx
