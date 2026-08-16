# 🎓 Scalable SSC Result Publishing Infrastructure (AWS Practical Assignment 7)

A production-ready, ultra-lightweight, and `t3.micro`-compatible web application designed to demonstrate a high-traffic, auto-scaling architecture on AWS for the **Module 7 Assignment (SSC Result 2026)**.

---

## ⚡ Key Highlights & `t3.micro` Compatibility

- **Ultra-lightweight footprint**: The application runs on **Nginx** consuming less than **15–30 MB of RAM** and < 1% idle CPU.
- **100% `t3.micro` Compatible**: Leaves over 970 MB of free memory on `t3.micro` (1 GiB RAM, 2 vCPUs), preventing out-of-memory (OOM) crashes during sudden traffic bursts.
- **Dynamic AWS Metadata (IMDSv2)**: Automatically fetches the running instance's **Instance ID**, **Availability Zone** (e.g., `us-east-1a`, `us-east-1b`), and **Private IP**, displaying them on the live web UI.
- **Interactive SSC Result Search**: Search by Examination, Year (2026), Board (Dhaka, Chittagong, Rajshahi, etc.), Roll, and Registration with automated marksheet generation and GPA calculation.
- **Built-in DevOps & Grading Tools**:
  - `/health` endpoint returning `200 OK` for ALB Target Group health checks.
  - `/unhealthy` simulation endpoint to trigger ALB target deregistration for testing.
  - **CPU Stress Generator** (`scripts/stress-cpu.sh`) to breach CloudWatch alarm thresholds and trigger Auto Scaling Scale-Out (2 $\to$ 10+ instances).

---

## 📂 Project Structure

```
f:\devops13\mod7\ssc-result-app\
├── public/
│   ├── index.html           # Main UI: SSC Result 2026 + Cloud Node Badges
│   ├── style.css            # Responsive Education Board theme styling
│   ├── app.js               # Search logic, dynamic GPA & DevOps simulation actions
│   └── results.json         # Mock database of student marks & grades
├── scripts/
│   ├── user-data.sh         # EC2 Launch Template bootstrap script (Amazon Linux 2023 / AL2 / Ubuntu)
│   ├── stress-cpu.sh        # Generates CPU load to test Auto Scaling Scale-Out & In
│   └── test-alb-traffic.sh  # Script to send concurrent requests to ALB DNS
├── server.js                # Lightweight Node.js server for local emulation
├── nginx.conf               # Nginx configuration with /health and /unhealthy routes
├── Dockerfile               # Alpine-based container build
├── docker-compose.yml       # Local multi-instance test setup
├── README.md                # This file
├── ASSIGNMENT_GUIDE.md      # Step-by-step AWS console walkthrough & screenshot guide
└── ASSIGNMENT_REPORT.md     # Ready-to-submit Module 7 assignment report
```

---

## 🚀 Quick Local Testing

### Option 1: Direct Node.js (No dependencies needed)
```bash
node server.js
```
Open [http://localhost:3000](http://localhost:3000) in your browser.

### Option 2: Docker / Docker Compose
```bash
docker compose up --build
```
- Node 1: [http://localhost:8081](http://localhost:8081)
- Node 2: [http://localhost:8082](http://localhost:8082)

---

## ☁️ AWS Deployment in 30 Seconds

1. Copy the contents of [`scripts/user-data.sh`](scripts/user-data.sh).
2. In AWS Console $\to$ **EC2** $\to$ **Launch Templates** $\to$ **Create Launch Template**:
   - **AMI**: Amazon Linux 2023 (or Ubuntu 22.04/24.04 LTS)
   - **Instance Type**: `t3.micro`
   - **Security Group**: Allow Port 80 (HTTP) from ALB Security Group
   - **Advanced Details $\to$ User data**: Paste [`scripts/user-data.sh`](scripts/user-data.sh)
3. Create your **Target Group** (Port 80, Health check `/health` or `/`).
4. Attach Target Group to your **Application Load Balancer** (Public Subnets).
5. Create **Auto Scaling Group** using the Launch Template in Private Subnets (Min: 2, Desired: 2, Max: 10).

Detailed step-by-step instructions and screenshot guidelines are in **[`ASSIGNMENT_GUIDE.md`](ASSIGNMENT_GUIDE.md)**!
