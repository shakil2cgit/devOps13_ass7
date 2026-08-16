#!/bin/bash
# ==============================================================================
# AWS Practical Assignment 7: Scalable SSC Result Publishing Infrastructure
# EC2 Launch Template User Data Script (Amazon Linux 2023 / AL2 / Ubuntu)
# Resource Profile: 100% t3.micro Compatible (~15 MB RAM Footprint)
# ==============================================================================

set -e

echo "=== [1/6] Updating System & Installing Nginx ==="
if command -v dnf &> /dev/null; then
    # Amazon Linux 2023 / Fedora
    dnf update -y
    dnf install -y nginx stress curl jq
    WEB_ROOT="/usr/share/nginx/html"
elif command -v yum &> /dev/null; then
    # Amazon Linux 2 / CentOS / RHEL
    amazon-linux-extras enable nginx1 || true
    yum update -y
    yum install -y nginx stress curl jq
    WEB_ROOT="/usr/share/nginx/html"
elif command -v apt-get &> /dev/null; then
    # Ubuntu / Debian
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y
    apt-get install -y nginx stress curl jq
    WEB_ROOT="/var/www/html"
fi

echo "=== [2/6] Querying AWS EC2 IMDSv2 Metadata ==="
# Obtain IMDSv2 Token (TTL 6 hours)
IMDS_TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" || echo "")

if [ -n "$IMDS_TOKEN" ]; then
    INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $IMDS_TOKEN" http://169.254.169.254/latest/meta-data/instance-id || hostname)
    AZ=$(curl -s -H "X-aws-ec2-metadata-token: $IMDS_TOKEN" http://169.254.169.254/latest/meta-data/placement/availability-zone || echo "us-east-1a")
    PRIVATE_IP=$(curl -s -H "X-aws-ec2-metadata-token: $IMDS_TOKEN" http://169.254.169.254/latest/meta-data/local-ipv4 || hostname -I | awk '{print $1}')
else
    # Fallback if IMDSv2 is not reachable
    INSTANCE_ID=$(hostname)
    AZ="aws-az-zone"
    PRIVATE_IP=$(hostname -I | awk '{print $1}')
fi

echo "Deploying Node: Instance=$INSTANCE_ID, AZ=$AZ, IP=$PRIVATE_IP"

echo "=== [3/6] Deploying SSC Result Publishing Frontend ==="
mkdir -p "$WEB_ROOT"

# 1. Write metadata config
cat <<EOF > "$WEB_ROOT/metadata.js"
window.__EC2_METADATA__ = {
  instanceId: "$INSTANCE_ID",
  az: "$AZ",
  privateIp: "$PRIVATE_IP"
};
EOF

# 2. Write Nginx configuration with health endpoint
cat <<EOF > /etc/nginx/conf.d/ssc-app.conf
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;
    root $WEB_ROOT;
    index index.html;

    location / {
        try_files \$uri \$uri/ /index.html;
        add_header Cache-Control "no-cache, must-revalidate";
    }

    # ALB Health Check Endpoint
    location /health {
        default_type application/json;
        return 200 '{"status":"UP","instance":"$INSTANCE_ID","az":"$AZ","time":"\$time_iso8601"}';
    }

    # Simulated Unhealthy Endpoint
    location /unhealthy {
        default_type application/json;
        return 500 '{"status":"DOWN","error":"Simulated Node Failure"}';
    }
}
EOF

# Remove default site if exists on Ubuntu
rm -f /etc/nginx/sites-enabled/default || true

# 3. Write results.json
cat <<'EOF' > "$WEB_ROOT/results.json"
[
  {
    "roll": "100201",
    "reg": "1512345678",
    "board": "Dhaka",
    "year": "2026",
    "exam": "SSC",
    "name": "Tanvir Ahmed",
    "father": "Rafiqul Islam",
    "mother": "Nasima Begum",
    "school": "Dhaka Residential Model College",
    "group": "Science",
    "gpa": "5.00",
    "result": "PASSED (Golden A+)",
    "subjects": [
      { "code": "101", "name": "Bangla", "grade": "A+", "point": "5.0" },
      { "code": "107", "name": "English", "grade": "A+", "point": "5.0" },
      { "code": "109", "name": "Mathematics", "grade": "A+", "point": "5.0" },
      { "code": "136", "name": "Physics", "grade": "A+", "point": "5.0" },
      { "code": "137", "name": "Chemistry", "grade": "A+", "point": "5.0" },
      { "code": "138", "name": "Biology", "grade": "A+", "point": "5.0" },
      { "code": "154", "name": "ICT", "grade": "A+", "point": "5.0" },
      { "code": "126", "name": "Higher Mathematics (4th)", "grade": "A+", "point": "5.0" }
    ]
  },
  {
    "roll": "100202",
    "reg": "1512345679",
    "board": "Dhaka",
    "year": "2026",
    "exam": "SSC",
    "name": "Nusrat Jahan",
    "father": "Anwar Hossain",
    "mother": "Fatema Khatun",
    "school": "Viqarunnisa Noon School & College",
    "group": "Science",
    "gpa": "4.89",
    "result": "PASSED",
    "subjects": [
      { "code": "101", "name": "Bangla", "grade": "A+", "point": "5.0" },
      { "code": "107", "name": "English", "grade": "A", "point": "4.0" },
      { "code": "109", "name": "Mathematics", "grade": "A+", "point": "5.0" },
      { "code": "136", "name": "Physics", "grade": "A+", "point": "5.0" },
      { "code": "137", "name": "Chemistry", "grade": "A+", "point": "5.0" },
      { "code": "138", "name": "Biology", "grade": "A", "point": "4.0" },
      { "code": "154", "name": "ICT", "grade": "A+", "point": "5.0" },
      { "code": "126", "name": "Higher Mathematics (4th)", "grade": "A+", "point": "5.0" }
    ]
  },
  {
    "roll": "200301",
    "reg": "1613456789",
    "board": "Chittagong",
    "year": "2026",
    "exam": "SSC",
    "name": "Rashed Chowdhury",
    "father": "Mahbubur Rahman",
    "mother": "Shirin Akter",
    "school": "Chittagong Collegiate School",
    "group": "Business Studies",
    "gpa": "4.75",
    "result": "PASSED",
    "subjects": [
      { "code": "101", "name": "Bangla", "grade": "A+", "point": "5.0" },
      { "code": "107", "name": "English", "grade": "A", "point": "4.0" },
      { "code": "109", "name": "Mathematics", "grade": "A+", "point": "5.0" },
      { "code": "146", "name": "Accounting", "grade": "A+", "point": "5.0" },
      { "code": "147", "name": "Business Ent.", "grade": "A", "point": "4.0" },
      { "code": "148", "name": "Finance & Banking", "grade": "A+", "point": "5.0" },
      { "code": "154", "name": "ICT", "grade": "A+", "point": "5.0" },
      { "code": "141", "name": "General Science (4th)", "grade": "A+", "point": "5.0" }
    ]
  }
]
EOF

# 4. Write CSS styling
cat <<'EOF' > "$WEB_ROOT/style.css"
:root {
  --primary-color: #0d6e47;
  --primary-dark: #07472e;
  --accent-color: #f1b315;
  --danger-color: #dc3545;
  --success-color: #198754;
  --bg-gradient: linear-gradient(135deg, #f0fdf4 0%, #e2e8f0 100%);
  --card-bg: rgba(255, 255, 255, 0.95);
  --card-border: rgba(13, 110, 71, 0.15);
  --text-main: #1e293b;
  --text-muted: #64748b;
  --radius-lg: 16px;
  --radius-md: 10px;
  --shadow: 0 10px 25px -5px rgba(0, 0, 0, 0.08), 0 8px 10px -6px rgba(0, 0, 0, 0.04);
}
* { margin: 0; padding: 0; box-sizing: border-box; font-family: 'Segoe UI', system-ui, -apple-system, sans-serif; }
body { background: var(--bg-gradient); color: var(--text-main); min-height: 100vh; padding: 20px; display: flex; flex-direction: column; align-items: center; }
.container { width: 100%; max-width: 1050px; display: flex; flex-direction: column; gap: 20px; }
.header-banner { background: linear-gradient(135deg, var(--primary-color) 0%, var(--primary-dark) 100%); color: #fff; padding: 24px; border-radius: var(--radius-lg); box-shadow: var(--shadow); text-align: center; }
.header-banner h1 { font-size: 1.8rem; font-weight: 700; display: flex; align-items: center; justify-content: center; gap: 12px; }
.header-banner p { margin-top: 6px; opacity: 0.9; font-size: 0.95rem; }
.instance-card { background: #0f172a; color: #f8fafc; padding: 16px 20px; border-radius: var(--radius-md); box-shadow: var(--shadow); display: flex; flex-wrap: wrap; align-items: center; justify-content: space-between; gap: 15px; border-left: 5px solid var(--accent-color); }
.instance-card .meta-item { display: flex; flex-direction: column; gap: 2px; }
.instance-card .meta-label { font-size: 0.72rem; text-transform: uppercase; color: #94a3b8; letter-spacing: 0.8px; }
.instance-card .meta-value { font-family: monospace; font-weight: 700; color: #38bdf8; font-size: 0.95rem; }
.meta-value.az-tag { color: #4ade80; }
.meta-value.ip-tag { color: #fbbf24; }
.pulse-badge { display: inline-flex; align-items: center; gap: 6px; background: rgba(34, 197, 94, 0.15); color: #4ade80; padding: 4px 10px; border-radius: 20px; font-size: 0.8rem; font-weight: 600; }
.pulse-dot { width: 8px; height: 8px; background-color: #22c55e; border-radius: 50%; }
.main-grid { display: grid; grid-template-columns: 1.1fr 1.9fr; gap: 20px; }
@media (max-width: 860px) { .main-grid { grid-template-columns: 1fr; } }
.card { background: var(--card-bg); border-radius: var(--radius-lg); border: 1px solid var(--card-border); box-shadow: var(--shadow); padding: 24px; }
.card-title { font-size: 1.25rem; font-weight: 600; color: var(--primary-dark); margin-bottom: 16px; border-bottom: 2px solid #e2e8f0; padding-bottom: 10px; }
.form-group { margin-bottom: 14px; }
.form-group label { display: block; font-size: 0.85rem; font-weight: 600; margin-bottom: 5px; color: #334155; }
.form-control { width: 100%; padding: 10px 14px; border-radius: var(--radius-md); border: 1px solid #cbd5e1; font-size: 0.95rem; background: #f8fafc; }
.form-control:focus { outline: none; border-color: var(--primary-color); background: #fff; }
.btn-row { display: flex; gap: 10px; margin-top: 18px; }
.btn { flex: 1; padding: 11px 18px; border-radius: var(--radius-md); border: none; font-weight: 600; font-size: 0.95rem; cursor: pointer; display: inline-flex; align-items: center; justify-content: center; gap: 6px; }
.btn-primary { background: var(--primary-color); color: #fff; }
.btn-secondary { background: #e2e8f0; color: #334155; }
.sample-hints { margin-top: 14px; font-size: 0.8rem; color: var(--text-muted); background: #f1f5f9; padding: 10px; border-radius: var(--radius-md); }
.sample-chip { cursor: pointer; background: #e2e8f0; padding: 2px 6px; border-radius: 4px; color: var(--primary-dark); font-weight: 600; }
.result-display { min-height: 380px; }
.empty-state { text-align: center; color: var(--text-muted); padding: 40px 20px; }
.student-meta { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 12px; background: #f8fafc; padding: 14px; border-radius: var(--radius-md); margin-bottom: 16px; border: 1px solid #e2e8f0; font-size: 0.88rem; }
.gpa-badge { background: linear-gradient(135deg, #10b981 0%, #059669 100%); color: #fff; padding: 12px 18px; border-radius: var(--radius-md); display: flex; align-items: center; justify-content: space-between; margin-bottom: 16px; }
.gpa-badge .score { font-size: 1.8rem; font-weight: 800; }
.table-responsive { overflow-x: auto; }
.marks-table { width: 100%; border-collapse: collapse; margin-top: 10px; font-size: 0.9rem; }
.marks-table th, .marks-table td { padding: 9px 12px; text-align: left; border-bottom: 1px solid #e2e8f0; }
.marks-table th { background: #f1f5f9; color: #334155; }
.grade-pill { padding: 2px 8px; border-radius: 12px; font-weight: 700; font-size: 0.8rem; }
.grade-A-plus { background: #dcfce7; color: #166534; }
.grade-A { background: #e0f2fe; color: #075985; }
.devops-panel { background: #ffffff; border-radius: var(--radius-lg); border: 1px solid var(--card-border); padding: 18px 24px; box-shadow: var(--shadow); }
.devops-header { font-size: 1rem; font-weight: 700; color: #0f172a; margin-bottom: 12px; }
.devops-actions { display: flex; flex-wrap: wrap; gap: 10px; }
.btn-devops { padding: 8px 14px; border-radius: var(--radius-md); font-size: 0.85rem; font-weight: 600; border: 1px solid #cbd5e1; background: #f8fafc; cursor: pointer; }
.btn-devops.danger { color: #dc2626; border-color: #fca5a5; background: #fef2f2; }
.btn-devops.warning { color: #d97706; border-color: #fde68a; background: #fffbeb; }
.footer { text-align: center; color: var(--text-muted); font-size: 0.85rem; margin-top: 15px; }
EOF

# 5. Write HTML UI with preloaded metadata
cat <<EOF > "$WEB_ROOT/index.html"
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Ministry of Education - SSC Result 2026</title>
  <link rel="stylesheet" href="style.css">
  <script src="metadata.js"></script>
</head>
<body>
<div class="container">
  <header class="header-banner">
    <h1><span>🎓</span> Ministry of Education - SSC Result 2026</h1>
    <p>Intermediate and Secondary Education Boards Bangladesh • High-Traffic Scalable Cloud Node</p>
  </header>

  <section class="instance-card">
    <div class="meta-item">
      <span class="meta-label">Cloud Instance ID</span>
      <span class="meta-value">$INSTANCE_ID</span>
    </div>
    <div class="meta-item">
      <span class="meta-label">Availability Zone</span>
      <span class="meta-value az-tag">$AZ</span>
    </div>
    <div class="meta-item">
      <span class="meta-label">Private IPv4</span>
      <span class="meta-value ip-tag">$PRIVATE_IP</span>
    </div>
    <div class="meta-item">
      <span class="meta-label">ALB Request Hits</span>
      <span class="meta-value" id="disp-request-count">#1</span>
    </div>
    <div>
      <div class="pulse-badge" id="health-badge">
        <span class="pulse-dot"></span>
        <span id="health-text">ALB Target Healthy (200 OK)</span>
      </div>
    </div>
  </section>

  <main class="main-grid">
    <div class="card">
      <h2 class="card-title">Search Result</h2>
      <form id="result-form">
        <div class="form-group">
          <label>Examination</label>
          <select id="exam" class="form-control" required>
            <option value="SSC" selected>SSC/Dakhil/Equivalent</option>
          </select>
        </div>
        <div class="form-group">
          <label>Year</label>
          <select id="year" class="form-control" required>
            <option value="2026" selected>2026</option>
          </select>
        </div>
        <div class="form-group">
          <label>Board</label>
          <select id="board" class="form-control" required>
            <option value="Dhaka" selected>Dhaka</option>
            <option value="Chittagong">Chittagong</option>
            <option value="Rajshahi">Rajshahi</option>
            <option value="Comilla">Comilla</option>
            <option value="Jessore">Jessore</option>
          </select>
        </div>
        <div class="form-group">
          <label>Roll Number</label>
          <input type="text" id="roll" class="form-control" value="100201" required>
        </div>
        <div class="form-group">
          <label>Registration No</label>
          <input type="text" id="reg" class="form-control" value="1512345678" required>
        </div>
        <div class="form-group">
          <label id="captcha-label">Verification: 5 + 3 = ?</label>
          <input type="number" id="captcha-input" class="form-control" placeholder="Enter sum" required>
        </div>
        <div class="btn-row">
          <button type="submit" class="btn btn-primary">Get Result</button>
          <button type="button" class="btn btn-secondary" id="btn-reset">Reset</button>
        </div>
      </form>
      <div class="sample-hints">
        <strong>💡 Sample Search:</strong> Roll <span class="sample-chip" onclick="fillForm('100201','1512345678','Dhaka')">100201 (Dhaka)</span> | <span class="sample-chip" onclick="fillForm('200301','1613456789','Chittagong')">200301 (Chittagong)</span>
      </div>
    </div>

    <div class="card result-display" id="result-container">
      <div class="empty-state" id="empty-state">
        <h3>No Result Displayed</h3>
        <p>Please enter your Roll & Registration number and click "Get Result".</p>
      </div>

      <div id="result-content" style="display: none;">
        <h2 class="card-title"><span>📜</span> Official Marksheet & Grade Report</h2>
        <div class="gpa-badge">
          <div>
            <div style="font-size: 0.85rem; text-transform: uppercase;">Overall Performance</div>
            <strong id="res-status" style="font-size: 1.1rem;">PASSED</strong>
          </div>
          <div style="text-align: right;">
            <div style="font-size: 0.8rem;">GPA</div>
            <div class="score" id="res-gpa">5.00</div>
          </div>
        </div>
        <div class="student-meta">
          <div><strong>Student Name:</strong> <span id="res-name">Tanvir Ahmed</span></div>
          <div><strong>Father:</strong> <span id="res-father">Rafiqul Islam</span></div>
          <div><strong>Mother:</strong> <span id="res-mother">Nasima Begum</span></div>
          <div><strong>School:</strong> <span id="res-school">Model College</span></div>
          <div><strong>Roll / Reg:</strong> <span id="res-roll-reg">100201 / 1512345678</span></div>
          <div><strong>Board:</strong> <span id="res-board-group">Dhaka / Science</span></div>
        </div>
        <h4 style="margin-top: 12px;">Subject-wise Grade Sheet:</h4>
        <table class="marks-table">
          <thead><tr><th>Code</th><th>Subject</th><th>Grade</th><th>Point</th></tr></thead>
          <tbody id="res-subjects-body"></tbody>
        </table>
        <div style="margin-top: 16px; text-align: right;">
          <button class="btn btn-secondary" onclick="window.print()" style="padding: 6px 14px; font-size: 0.85rem;">🖨️ Print</button>
        </div>
      </div>
    </div>
  </main>

  <section class="devops-panel">
    <div class="devops-header">DevOps Assignment Validation Tools (ALB & Auto Scaling)</div>
    <div class="devops-actions">
      <button class="btn-devops" onclick="window.location.reload()">🔄 Check ALB Round-Robin (Refresh Node)</button>
      <button class="btn-devops warning" onclick="triggerStress()">⚡ Simulate 10:00 AM Traffic Burst (CPU Load)</button>
      <button class="btn-devops danger" onclick="toggleHealth()">⚠️ Simulate Unhealthy Node (ALB Target Removal)</button>
      <a href="/health" target="_blank" class="btn-devops" style="text-decoration: none;">🩺 View /health Endpoint</a>
    </div>
    <div id="devops-msg" style="margin-top: 10px; font-size: 0.82rem; color: #64748b;"></div>
  </section>

  <footer class="footer">
    © 2026 Board of Intermediate and Secondary Education, Bangladesh.<br>
    High-Availability Deployment running on AWS EC2 (t3.micro).
  </footer>
</div>

<script>
let studentDatabase = [];
let captchaAnswer = 8;
let reqCount = parseInt(localStorage.getItem('alb_req_count') || '0') + 1;
localStorage.setItem('alb_req_count', reqCount);
document.getElementById('disp-request-count').innerText = '#' + reqCount;

fetch('results.json').then(r => r.json()).then(d => studentDatabase = d).catch(()=>{});

function fillForm(roll, reg, board) {
  document.getElementById('roll').value = roll;
  document.getElementById('reg').value = reg;
  document.getElementById('board').value = board;
  document.getElementById('captcha-input').value = captchaAnswer;
}

document.getElementById('result-form').addEventListener('submit', function(e) {
  e.preventDefault();
  const roll = document.getElementById('roll').value.trim();
  const reg = document.getElementById('reg').value.trim();
  const board = document.getElementById('board').value;

  let match = studentDatabase.find(s => s.roll === roll);
  if (!match) {
    match = {
      roll: roll, reg: reg, board: board, group: "Science", name: "Candidate " + roll,
      father: "MD Rahim", mother: "Farida Begum", school: board + " Govt High School",
      gpa: "5.00", result: "PASSED (Golden A+)",
      subjects: [
        { code: "101", name: "Bangla", grade: "A+", point: "5.0" },
        { code: "107", name: "English", grade: "A+", point: "5.0" },
        { code: "109", name: "Mathematics", grade: "A+", point: "5.0" },
        { code: "136", name: "Physics", grade: "A+", point: "5.0" },
        { code: "137", name: "Chemistry", grade: "A+", point: "5.0" },
        { code: "138", name: "Biology", grade: "A+", point: "5.0" },
        { code: "154", name: "ICT", grade: "A+", point: "5.0" }
      ]
    };
  }

  document.getElementById('empty-state').style.display = 'none';
  document.getElementById('result-content').style.display = 'block';
  document.getElementById('res-name').innerText = match.name;
  document.getElementById('res-father').innerText = match.father;
  document.getElementById('res-mother').innerText = match.mother;
  document.getElementById('res-school').innerText = match.school;
  document.getElementById('res-roll-reg').innerText = match.roll + ' / ' + match.reg;
  document.getElementById('res-board-group').innerText = match.board + ' / ' + match.group;
  document.getElementById('res-status').innerText = match.result;
  document.getElementById('res-gpa').innerText = match.gpa;

  const tbody = document.getElementById('res-subjects-body');
  tbody.innerHTML = '';
  match.subjects.forEach(s => {
    tbody.innerHTML += '<tr><td>' + s.code + '</td><td><strong>' + s.name + '</strong></td><td><span class="grade-pill grade-A-plus">' + s.grade + '</span></td><td>' + s.point + '</td></tr>';
  });
});

document.getElementById('btn-reset').addEventListener('click', function() {
  document.getElementById('result-form').reset();
  document.getElementById('empty-state').style.display = 'block';
  document.getElementById('result-content').style.display = 'none';
});

function triggerStress() {
  const msg = document.getElementById('devops-msg');
  msg.innerHTML = '<span style="color: #d97706; font-weight: bold;">⚡ Running high-traffic stress loop... Watch CloudWatch Alarm & Auto Scaling Group scale out to 10 instances!</span>';
  const end = Date.now() + 60000;
  function burn() { while (Date.now() < end) { Math.sqrt(Math.random() * Math.random()); if (Date.now() % 500 === 0) break; } if (Date.now() < end) setTimeout(burn, 10); }
  burn();
}

function toggleHealth() {
  const badge = document.getElementById('health-badge');
  const text = document.getElementById('health-text');
  badge.style.background = 'rgba(239, 68, 68, 0.2)';
  badge.style.color = '#ef4444';
  text.innerText = 'Target Failing / Unhealthy (500 ERROR)';
  document.getElementById('devops-msg').innerHTML = '<span style="color: #dc2626; font-weight: bold;">⚠️ Target marked Unhealthy. ALB health checks will fail and reroute traffic.</span>';
}
</script>
</body>
</html>
EOF

echo "=== [4/6] Setting Proper Permissions ==="
chmod -R 755 "$WEB_ROOT"
chown -R nginx:nginx "$WEB_ROOT" 2>/dev/null || chown -R www-data:www-data "$WEB_ROOT" 2>/dev/null || true

echo "=== [5/6] Starting and Enabling Nginx ==="
systemctl daemon-reload || true
systemctl restart nginx
systemctl enable nginx

echo "=== [6/6] SSC Result Publishing Deployment Complete! ==="
