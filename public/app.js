// State Management
let studentDatabase = [];
let captchaAnswer = 0;
let requestCounter = parseInt(localStorage.getItem('alb_req_count') || '0') + 1;
localStorage.setItem('alb_req_count', requestCounter);

// Initialize Page
document.addEventListener('DOMContentLoaded', async () => {
  generateCaptcha();
  loadResultsDatabase();
  loadServerDiagnostics();

  // Handle Form Submission
  document.getElementById('result-form').addEventListener('submit', handleSearch);
  document.getElementById('btn-reset').addEventListener('click', resetForm);
});

// Generate Random Math Captcha
function generateCaptcha() {
  const num1 = Math.floor(Math.random() * 9) + 1;
  const num2 = Math.floor(Math.random() * 9) + 1;
  captchaAnswer = num1 + num2;
  const label = document.getElementById('captcha-label');
  if (label) {
    label.innerText = `Verification: ${num1} + ${num2} = ?`;
  }
}

// Fetch Sample Results Database
async function loadResultsDatabase() {
  try {
    const res = await fetch('results.json');
    if (res.ok) {
      studentDatabase = await res.json();
    }
  } catch (e) {
    console.warn('Using fallback memory database:', e);
  }
}

// Fetch Cloud Server Diagnostics (Instance ID, AZ, Private IP)
async function loadServerDiagnostics() {
  const reqEl = document.getElementById('disp-request-count');
  if (reqEl) reqEl.innerText = `#${requestCounter}`;

  try {
    const res = await fetch('/api/metadata', { cache: 'no-store' });
    if (res.ok) {
      const data = await res.json();
      if (data.instanceId) document.getElementById('disp-instance-id').innerText = data.instanceId;
      if (data.az) document.getElementById('disp-az').innerText = data.az;
      if (data.privateIp) document.getElementById('disp-private-ip').innerText = data.privateIp;
    }
  } catch (err) {
    // If running pure static without backend, check if window.__EC2_METADATA__ was injected by user-data.sh
    if (window.__EC2_METADATA__) {
      const m = window.__EC2_METADATA__;
      if (m.instanceId) document.getElementById('disp-instance-id').innerText = m.instanceId;
      if (m.az) document.getElementById('disp-az').innerText = m.az;
      if (m.privateIp) document.getElementById('disp-private-ip').innerText = m.privateIp;
    }
  }
}

// Fill sample form values
function fillForm(roll, reg, board) {
  document.getElementById('roll').value = roll;
  document.getElementById('reg').value = reg;
  document.getElementById('board').value = board;
  document.getElementById('captcha-input').value = captchaAnswer;
}

// Handle Search
function handleSearch(e) {
  e.preventDefault();

  const enteredCaptcha = parseInt(document.getElementById('captcha-input').value);
  if (enteredCaptcha !== captchaAnswer) {
    alert('Incorrect captcha sum. Please try again.');
    generateCaptcha();
    return;
  }

  const roll = document.getElementById('roll').value.trim();
  const reg = document.getElementById('reg').value.trim();
  const board = document.getElementById('board').value;
  const exam = document.getElementById('exam').value;
  const year = document.getElementById('year').value;

  let match = studentDatabase.find(s => s.roll === roll && (s.reg === reg || !s.reg));

  // If not found in mock JSON, generate a realistic result dynamically!
  if (!match) {
    match = generateDynamicResult(roll, reg, board, exam, year);
  }

  displayResult(match);
}

// Display Result Marksheet
function displayResult(data) {
  document.getElementById('empty-state').style.display = 'none';
  const content = document.getElementById('result-content');
  content.style.display = 'block';

  document.getElementById('res-name').innerText = data.name;
  document.getElementById('res-father').innerText = data.father;
  document.getElementById('res-mother').innerText = data.mother;
  document.getElementById('res-school').innerText = data.school;
  document.getElementById('res-roll-reg').innerText = `${data.roll} / ${data.reg}`;
  document.getElementById('res-board-group').innerText = `${data.board} / ${data.group}`;
  document.getElementById('res-status').innerText = data.result;
  document.getElementById('res-gpa').innerText = data.gpa;

  const tbody = document.getElementById('res-subjects-body');
  tbody.innerHTML = '';

  data.subjects.forEach(sub => {
    const tr = document.createElement('tr');
    let pillClass = 'grade-A';
    if (sub.grade === 'A+') pillClass = 'grade-A-plus';
    else if (sub.grade === 'A-') pillClass = 'grade-A-minus';

    tr.innerHTML = `
      <td>${sub.code}</td>
      <td><strong>${sub.name}</strong></td>
      <td><span class="grade-pill ${pillClass}">${sub.grade}</span></td>
      <td>${sub.point}</td>
    `;
    tbody.appendChild(tr);
  });

  // Smooth scroll to result
  document.getElementById('result-container').scrollIntoView({ behavior: 'smooth', block: 'nearest' });
}

// Generate Realistic Dynamic Result for any Roll Number
function generateDynamicResult(roll, reg, board, exam, year) {
  return {
    roll: roll,
    reg: reg || "1982736451",
    board: board,
    year: year,
    exam: exam,
    name: "Student Candidate " + roll.slice(-3),
    father: "Mohammad Ali",
    mother: "Salma Begum",
    school: `${board} Model Govt. High School`,
    group: "Science",
    gpa: "5.00",
    result: "PASSED (Golden A+)",
    subjects: [
      { code: "101", name: "Bangla", grade: "A+", point: "5.0" },
      { code: "107", name: "English", grade: "A+", point: "5.0" },
      { code: "109", name: "Mathematics", grade: "A+", point: "5.0" },
      { code: "136", name: "Physics", grade: "A+", point: "5.0" },
      { code: "137", name: "Chemistry", grade: "A+", point: "5.0" },
      { code: "138", name: "Biology", grade: "A+", point: "5.0" },
      { code: "154", name: "ICT", grade: "A+", point: "5.0" },
      { code: "126", name: "Higher Mathematics (4th)", grade: "A+", point: "5.0" }
    ]
  };
}

// Reset Form
function resetForm() {
  document.getElementById('result-form').reset();
  generateCaptcha();
  document.getElementById('empty-state').style.display = 'block';
  document.getElementById('result-content').style.display = 'none';
}

// DevOps Simulation Functions
function refreshServerInfo() {
  window.location.reload();
}

async function triggerCpuStress() {
  const msgEl = document.getElementById('devops-msg');
  msgEl.innerHTML = '⚡ <em>Triggering CPU stress test to simulate 10:00 AM traffic burst...</em>';

  try {
    const res = await fetch('/api/stress?seconds=60', { method: 'POST' });
    if (res.ok) {
      msgEl.innerHTML = '<span style="color: #d97706; font-weight: bold;">⚡ High CPU load activated for 60 seconds! Watch CloudWatch Alarm & Auto Scaling Group scale out to 10 instances.</span>';
    } else {
      // Client-side fallback computation stress
      startClientCpuStress();
      msgEl.innerHTML = '<span style="color: #d97706; font-weight: bold;">⚡ Running client-side high traffic simulation loop...</span>';
    }
  } catch (e) {
    startClientCpuStress();
    msgEl.innerHTML = '<span style="color: #d97706; font-weight: bold;">⚡ Running local high traffic simulation loop...</span>';
  }
}

function startClientCpuStress() {
  const end = Date.now() + 30000;
  function burn() {
    while (Date.now() < end) {
      Math.sqrt(Math.random() * Math.random());
      if (Date.now() % 500 === 0) break;
    }
    if (Date.now() < end) setTimeout(burn, 10);
  }
  burn();
}

async function toggleServerHealth() {
  const badge = document.getElementById('health-badge');
  const text = document.getElementById('health-text');
  const msgEl = document.getElementById('devops-msg');

  try {
    const res = await fetch('/api/toggle-health', { method: 'POST' });
    if (res.ok) {
      const data = await res.json();
      if (data.healthy) {
        badge.style.background = 'rgba(34, 197, 94, 0.15)';
        badge.style.color = '#4ade80';
        text.innerText = 'ALB Target Healthy (200 OK)';
        msgEl.innerHTML = '<span style="color: #16a34a;">Target marked Healthy (200 OK).</span>';
      } else {
        badge.style.background = 'rgba(239, 68, 68, 0.2)';
        badge.style.color = '#ef4444';
        text.innerText = 'Target Failing / Unhealthy (500 ERROR)';
        msgEl.innerHTML = '<span style="color: #dc2626; font-weight: bold;">⚠️ Target marked Unhealthy (500 Internal Server Error)! ALB health check will fail and deregister this target within ~15-30s.</span>';
      }
      return;
    }
  } catch (e) {}

  // Fallback UI simulation
  badge.style.background = 'rgba(239, 68, 68, 0.2)';
  badge.style.color = '#ef4444';
  text.innerText = 'Target Failing / Unhealthy (500 ERROR)';
  msgEl.innerHTML = '<span style="color: #dc2626; font-weight: bold;">⚠️ Node simulated as UNHEALTHY. ALB health checks will fail and reroute traffic.</span>';
}
