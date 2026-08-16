# 📘 Step-by-Step AWS Setup & Screenshot Guide

This guide provides the complete blueprint for deploying the **Scalable SSC Result Publishing Infrastructure** on AWS according to the requirements of **Module 7 Assignment (`ass7.txt`)**.

---

## 🏛️ Architecture Overview

```mermaid
flowchart TD
    Internet([🌐 Internet Users / SSC Candidates]) -->|HTTP Port 80 / HTTPS 443| ALB[Application Load Balancer\nPublic Subnets: 10.0.1.0/24 & 10.0.2.0/24]
    
    subgraph VPC ["Custom AWS VPC (10.0.0.0/16)"]
        subgraph PublicSubnets ["Public Subnets (AZ-a & AZ-b)"]
            ALB
            NATGW[NAT Gateway in Public Subnet A]
            IGW[Internet Gateway]
        end
        
        subgraph PrivateSubnets ["Private Subnets (AZ-a & AZ-b)"]
            ASG[Auto Scaling Group\nMin: 2 | Desired: 2 | Max: 10+]
            EC2_1[EC2 Node A\nPrivate IP: 10.0.3.x\nNginx + SSC App]
            EC2_2[EC2 Node B\nPrivate IP: 10.0.4.x\nNginx + SSC App]
            ASG --- EC2_1
            ASG --- EC2_2
        end
    end
    
    ALB -->|Forward Port 80| EC2_1
    ALB -->|Forward Port 80| EC2_2
    EC2_1 -.->|Outbound Internet via Private Route| NATGW
    EC2_2 -.->|Outbound Internet via Private Route| NATGW
    NATGW -.->|Route 0.0.0.0/0| IGW
```

---

## 🛠️ Step 1: VPC & Network Configuration

### 1.1 Create VPC
- **Name tag**: `ssc-result-vpc`
- **IPv4 CIDR block**: `10.0.0.0/16`

### 1.2 Create 4 Subnets (across 2 Availability Zones)
| Subnet Name | Type | Availability Zone | CIDR Block | Auto-assign Public IP |
| :--- | :--- | :--- | :--- | :--- |
| `ssc-public-subnet-1` | Public | `us-east-1a` | `10.0.1.0/24` | **Yes** |
| `ssc-public-subnet-2` | Public | `us-east-1b` | `10.0.2.0/24` | **Yes** |
| `ssc-private-subnet-1` | Private | `us-east-1a` | `10.0.3.0/24` | No |
| `ssc-private-subnet-2` | Private | `us-east-1b` | `10.0.4.0/24` | No |

### 1.3 Internet Gateway (IGW)
- Create IGW: `ssc-result-igw`
- Attach to `ssc-result-vpc`.

### 1.4 NAT Gateway
- Create NAT Gateway: `ssc-nat-gw`
- **Subnet**: Select `ssc-public-subnet-1`
- **Elastic IP**: Allocate new Elastic IP.

### 1.5 Route Tables
1. **Public Route Table (`ssc-public-rt`)**:
   - Routes: `0.0.0.0/0` $\to$ Target: `ssc-result-igw`
   - Subnet Associations: Associate `ssc-public-subnet-1` and `ssc-public-subnet-2`.
2. **Private Route Table (`ssc-private-rt`)**:
   - Routes: `0.0.0.0/0` $\to$ Target: `ssc-nat-gw`
   - Subnet Associations: Associate `ssc-private-subnet-1` and `ssc-private-subnet-2`.

---

## 🔒 Step 2: Security Groups

### 2.1 ALB Security Group (`alb-sg`)
- **Inbound Rules**:
  - HTTP (Port 80) $\to$ Source: `0.0.0.0/0` (Anywhere)
- **Outbound Rules**:
  - All Traffic $\to$ `0.0.0.0/0`

### 2.2 EC2 Security Group (`ec2-private-sg`)
- **Inbound Rules**:
  - HTTP (Port 80) $\to$ Source: **Select `alb-sg`** (Restricts access exclusively from ALB!)
  - SSH (Port 22) $\to$ (Optional: Your IP or Bastion Host SG)
- **Outbound Rules**:
  - All Traffic $\to$ `0.0.0.0/0` (Allows Yum/DNF/Apt package downloads through NAT Gateway)

---

## 💻 Step 3: EC2 Launch Template

1. Navigate to **EC2 $\to$ Launch Templates $\to$ Create Launch Template**.
2. **Template Name**: `ssc-app-launch-template`
3. **AMI**: Amazon Linux 2023 (or Ubuntu 22.04 LTS)
4. **Instance Type**: `t3.micro`
5. **Key Pair**: Select or create your key pair.
6. **Network Settings**:
   - Select Security Group: `ec2-private-sg`
7. **Advanced Details**:
   - **IAM Instance Profile**: (Optional) SSM role if using Systems Manager.
   - **Metadata version (IMDS)**: V2 enabled.
   - **User Data**: Paste the complete code from [`scripts/user-data.sh`](scripts/user-data.sh).

---

## ⚖️ Step 4: Application Load Balancer & Target Group

### 4.1 Create Target Group
- **Target Type**: Instances
- **Target Group Name**: `ssc-app-tg`
- **Protocol / Port**: HTTP / 80
- **VPC**: `ssc-result-vpc`
- **Health Checks**:
  - Protocol: HTTP
  - Health check path: `/health` (or `/`)
  - Healthy threshold: `2`
  - Unhealthy threshold: `2`
  - Timeout: `5` seconds
  - Interval: `15` seconds

### 4.2 Create Application Load Balancer (ALB)
- **Name**: `ssc-result-alb`
- **Scheme**: Internet-facing
- **IP address type**: IPv4
- **VPC**: `ssc-result-vpc`
- **Mappings**:
  - AZ 1 (`us-east-1a`) $\to$ `ssc-public-subnet-1`
  - AZ 2 (`us-east-1b`) $\to$ `ssc-public-subnet-2`
- **Security Groups**: Select `alb-sg`
- **Listeners and Routing**:
  - Protocol: HTTP | Port: 80 $\to$ Forward to: `ssc-app-tg`

---

## 📈 Step 5: Auto Scaling Group (ASG)

1. Navigate to **EC2 $\to$ Auto Scaling Groups $\to$ Create Auto Scaling Group**.
2. **Name**: `ssc-result-asg`
3. **Launch Template**: Select `ssc-app-launch-template`.
4. **Network**:
   - VPC: `ssc-result-vpc`
   - Subnets: Select `ssc-private-subnet-1` and `ssc-private-subnet-2`.
5. **Load Balancing**:
   - Attach to an existing load balancer: Select `ssc-app-tg`.
   - Health checks: Turn on **Elastic Load Balancing (ELB) health checks**.
   - Health check grace period: `180` seconds.
6. **Group Size**:
   - **Desired Capacity**: `2`
   - **Minimum Capacity**: `2`
   - **Maximum Capacity**: `10`
7. **Scaling Policies**:
   - **Policy 1: Target Tracking Policy**
     - Metric type: *Average CPU utilization*
     - Target value: `50%`
     - Instance warm-up: `60` seconds
   - **Policy 2: Scheduled Scaling (for 10:00 AM Result Spike)**
     - Create Scheduled Action: `pre-scale-ssc-results-10am`
     - Recurrence / Specific Time: e.g., `09:50 AM`
     - Desired: `10`, Min: `10`, Max: `15`

---

## 📸 Checklist: 14 Required Screenshots for Assignment

| # | Screenshot Item | AWS Console Location | What to Show |
| :-: | :--- | :--- | :--- |
| **1** | **VPC** | VPC Dashboard $\to$ Your VPCs | `ssc-result-vpc` with `10.0.0.0/16` |
| **2** | **Subnets** | VPC $\to$ Subnets | 2 Public & 2 Private Subnets with respective CIDRs |
| **3** | **Internet Gateway** | VPC $\to$ Internet Gateways | `ssc-result-igw` attached to `ssc-result-vpc` |
| **4** | **Route Tables** | VPC $\to$ Route Tables | Routes showing `0.0.0.0/0` $\to$ IGW (Public) and `0.0.0.0/0` $\to$ NAT GW (Private) |
| **5** | **NAT Gateway** | VPC $\to$ NAT Gateways | `ssc-nat-gw` in `ssc-public-subnet-1` with State: *Available* |
| **6** | **Launch Template** | EC2 $\to$ Launch Templates | `ssc-app-launch-template` details showing `t3.micro` & User Data |
| **7** | **EC2 Instances** | EC2 $\to$ Instances | EC2 instances running in private subnets without public IPs |
| **8** | **Nginx Web Page through ALB** | Web Browser | Webpage open at `http://<ALB-DNS-Name>` showing *SSC Result 2026* |
| **9** | **Target Group & Health** | EC2 $\to$ Target Groups $\to$ Targets | Both targets showing Status: **Healthy** |
| **10** | **Application Load Balancer** | EC2 $\to$ Load Balancers | `ssc-result-alb` showing DNS name, scheme, and public subnets |
| **11** | **Auto Scaling Group** | EC2 $\to$ Auto Scaling Groups | `ssc-result-asg` showing Min: 2, Desired: 2, Max: 10 |
| **12** | **Scale-Out Activity** | ASG $\to$ Activity tab | Activity log showing new instances launching during load test |
| **13** | **Scale-In Activity** | ASG $\to$ Activity tab | Activity log showing instances terminating after load cools down |
| **14** | **CloudWatch Metric / Alarm** | CloudWatch $\to$ Alarms | CPUUtilization alarm in *In Alarm* state during stress test |
| **+** | **Unhealthy Target Test** | EC2 $\to$ Target Groups $\to$ Targets | 1 instance showing Status: **Unhealthy** after failure simulation |

---

## 🧪 Testing & Verification Steps

### 1. Test Load Balancing & Multi-AZ Distribution
Refresh the browser at `http://<ALB-DNS-Name>`. Observe how the **Instance ID**, **Availability Zone**, and **Private IP** switch between `us-east-1a` and `us-east-1b`.

### 2. Trigger Auto Scaling Scale-Out
Run the CPU stress test either by clicking **"Simulate 10:00 AM Traffic Burst"** on the webpage or via SSM / SSH using:
```bash
./scripts/stress-cpu.sh 300
```
- Within 2–3 minutes, CloudWatch alarm will transition to `ALARM`.
- Auto Scaling will trigger and scale capacity from 2 to 10 instances.

### 3. Verify Unhealthy Target Removal
Click **"Simulate Unhealthy Node"** on the web page or stop Nginx on one instance.
- ALB health check will fail on that target within ~30s.
- The target will be marked `Unhealthy` and ALB will immediately stop routing candidate traffic to it.
- Auto Scaling will terminate the unhealthy instance and launch a replacement automatically!
