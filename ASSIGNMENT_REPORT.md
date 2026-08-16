# 📑 AWS Practical Assignment 7: Short Report
## Scalable SSC Result Publishing Infrastructure

**Course**: DevOps & Cloud Engineering  
**Module**: Module 7 Assignment  
**Scenario**: Handling High-Spike Traffic for SSC Result 2026 at 10:00 AM  

---

### 1. VPC & Network Architecture
The infrastructure is built inside a custom Amazon Virtual Private Cloud (VPC) with CIDR `10.0.0.0/16` across two Availability Zones (`us-east-1a` and `us-east-1b`) for High Availability (HA) and Fault Tolerance:
- **2 Public Subnets** (`10.0.1.0/24`, `10.0.2.0/24`): Host the internet-facing Application Load Balancer (ALB) and the NAT Gateway. These subnets route internet-bound traffic directly through the Internet Gateway (IGW).
- **2 Private Subnets** (`10.0.3.0/24`, `10.0.4.0/24`): Host the EC2 compute nodes running the SSC Result web application. These instances do not have public IPv4 addresses and cannot be reached directly from the internet.
- **Route Tables**: Separate Public Route Table (direct default route `0.0.0.0/0` $\to$ IGW) and Private Route Table (default route `0.0.0.0/0` $\to$ NAT Gateway).

---

### 2. ALB and EC2 Traffic Flow & Security Isolation
1. **Candidate Access**: Students and parents access the official SSC result portal via the Application Load Balancer's public DNS name (`http://<ALB-DNS-Name>`).
2. **Ingress Filtering**: The ALB Security Group (`alb-sg`) accepts HTTP/HTTPS traffic from the public internet (`0.0.0.0/0`).
3. **Internal Forwarding**: The ALB distributes incoming requests across healthy EC2 targets in the Private Subnets using a Round-Robin algorithm.
4. **Zero Direct Ingress**: The EC2 Security Group (`ec2-private-sg`) strictly restricts port 80/443 inbound access exclusively to the source `alb-sg`. Any direct internet connection attempt is blocked at the network perimeter.
5. **Health Checks**: The ALB periodically probes the `/health` endpoint every 15 seconds. If an EC2 target fails two consecutive health checks, ALB instantly isolates it from the active routing pool.

---

### 3. Purpose of NAT Gateway
Since the EC2 instances reside inside Private Subnets without public IP addresses, they cannot communicate directly with the internet. The **NAT Gateway** (placed in the Public Subnet) enables the private EC2 instances to:
- Securely fetch system updates (`dnf update` / `apt update`), install Nginx, and retrieve application dependencies during instance initialization via User Data.
- Prevent unsolicited inbound connections from reaching private instances, ensuring strict compliance with AWS security best practices.

---

### 4. Auto Scaling Strategy
The Auto Scaling Group (ASG) uses a **dual proactive-reactive scaling strategy**:
1. **Baseline Capacity**: Set to Minimum: 2, Desired: 2, Maximum: 10+ instances across multiple Availability Zones.
2. **Proactive Scheduled Scaling (10:00 AM Result Spike)**: Because the exact result publication time (10:00 AM) is known in advance, a **Scheduled Action** is configured to pre-scale the cluster to **10 instances at 09:50 AM (10 minutes prior)**. This prevents cold-start latency and ensures immediate capacity is ready when traffic hits.
3. **Reactive Dynamic Target Tracking Policy**: Configured to track **Average CPU Utilization at 50%**. If traffic surges beyond expectations, additional `t3.micro` instances are spawned within 60 seconds.
4. **Scale-In Policy**: When traffic subsides after peak hours, CloudWatch monitors lowered CPU utilization and gradually terminates excess instances down to the minimum baseline of 2, minimizing cloud operational costs.

---

### 5. Why `t3.micro` is the Optimal Choice
The SSC Result web application was engineered with an ultra-lightweight Nginx static and cached dynamic rendering model:
- **Memory Footprint**: Consumes under **30 MB RAM**, leaving > 970 MB of free memory on `t3.micro`'s 1 GB allocation.
- **Cost Efficiency**: Fully covered under AWS Free Tier eligibility while providing burstable compute performance across 10 distributed nodes to serve tens of thousands of concurrent requests seamlessly.
