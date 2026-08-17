# ==============================================================================
# AWS Practical Assignment 7: 100% Pure AWS CLI Clean Deployment (Ubuntu t3.micro)
# Region: ap-southeast-1
# ==============================================================================
$ErrorActionPreference = "Continue"
$REGION = "ap-southeast-1"
$AMI_ID = "ami-06afb763249172368" # Ubuntu 22.04 LTS

Write-Host "===============================================================" -ForegroundColor Cyan
Write-Host " 🚀 STARTING CLEAN AWS DEPLOYMENT FROM SCRATCH" -ForegroundColor Cyan
Write-Host " Region: $REGION | AMI: $AMI_ID | Instance Type: t3.micro" -ForegroundColor Cyan
Write-Host "===============================================================" -ForegroundColor Cyan

# 1. Create VPC
Write-Host "`n[1/10] Creating VPC (10.0.0.0/16)..." -ForegroundColor Yellow
$VPC_ID = (aws ec2 create-vpc --cidr-block 10.0.0.0/16 --region $REGION --query "Vpc.VpcId" --output text)
aws ec2 create-tags --resources $VPC_ID --tags Key=Name,Value=ssc-result-vpc --region $REGION
aws ec2 modify-vpc-attribute --vpc-id $VPC_ID --enable-dns-hostnames "{\`"Value\`":true}" --region $REGION
aws ec2 modify-vpc-attribute --vpc-id $VPC_ID --enable-dns-support "{\`"Value\`":true}" --region $REGION
Write-Host "✅ VPC Created: $VPC_ID" -ForegroundColor Green

# 2. Create 4 Subnets across 2 AZs (ap-southeast-1a, ap-southeast-1b)
Write-Host "`n[2/10] Creating 4 Subnets in 2 Availability Zones..." -ForegroundColor Yellow
$PUB_SUB_1 = (aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.1.0/24 --availability-zone ${REGION}a --region $REGION --query "Subnet.SubnetId" --output text)
aws ec2 create-tags --resources $PUB_SUB_1 --tags Key=Name,Value=ssc-public-subnet-1 --region $REGION
aws ec2 modify-subnet-attribute --subnet-id $PUB_SUB_1 --map-public-ip-on-launch --region $REGION

$PUB_SUB_2 = (aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.2.0/24 --availability-zone ${REGION}b --region $REGION --query "Subnet.SubnetId" --output text)
aws ec2 create-tags --resources $PUB_SUB_2 --tags Key=Name,Value=ssc-public-subnet-2 --region $REGION
aws ec2 modify-subnet-attribute --subnet-id $PUB_SUB_2 --map-public-ip-on-launch --region $REGION

$PRIV_SUB_1 = (aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.3.0/24 --availability-zone ${REGION}a --region $REGION --query "Subnet.SubnetId" --output text)
aws ec2 create-tags --resources $PRIV_SUB_1 --tags Key=Name,Value=ssc-private-subnet-1 --region $REGION

$PRIV_SUB_2 = (aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.4.0/24 --availability-zone ${REGION}b --region $REGION --query "Subnet.SubnetId" --output text)
aws ec2 create-tags --resources $PRIV_SUB_2 --tags Key=Name,Value=ssc-private-subnet-2 --region $REGION
Write-Host "✅ Subnets: Public($PUB_SUB_1, $PUB_SUB_2) | Private($PRIV_SUB_1, $PRIV_SUB_2)" -ForegroundColor Green

# 3. Create & Attach Internet Gateway
Write-Host "`n[3/10] Creating Internet Gateway..." -ForegroundColor Yellow
$IGW_ID = (aws ec2 create-internet-gateway --region $REGION --query "InternetGateway.InternetGatewayId" --output text)
aws ec2 create-tags --resources $IGW_ID --tags Key=Name,Value=ssc-result-igw --region $REGION
aws ec2 attach-internet-gateway --vpc-id $VPC_ID --internet-gateway-id $IGW_ID --region $REGION
Write-Host "✅ IGW Attached: $IGW_ID" -ForegroundColor Green

# 4. Create Elastic IP & NAT Gateway in Public Subnet 1
Write-Host "`n[4/10] Creating NAT Gateway..." -ForegroundColor Yellow
$EIP_ALLOC = (aws ec2 allocate-address --domain vpc --region $REGION --query "AllocationId" --output text)
aws ec2 create-tags --resources $EIP_ALLOC --tags Key=Name,Value=ssc-nat-eip --region $REGION

$NAT_GW_ID = (aws ec2 create-nat-gateway --subnet-id $PUB_SUB_1 --allocation-id $EIP_ALLOC --region $REGION --query "NatGateway.NatGatewayId" --output text)
aws ec2 create-tags --resources $NAT_GW_ID --tags Key=Name,Value=ssc-nat-gw --region $REGION
Write-Host "⏳ Waiting for NAT Gateway to become available..." -ForegroundColor Yellow
aws ec2 wait nat-gateway-available --nat-gateway-ids $NAT_GW_ID --region $REGION
Write-Host "✅ NAT Gateway Available: $NAT_GW_ID" -ForegroundColor Green

# 5. Route Tables
Write-Host "`n[5/10] Creating Route Tables..." -ForegroundColor Yellow
$PUB_RT = (aws ec2 create-route-table --vpc-id $VPC_ID --region $REGION --query "RouteTable.RouteTableId" --output text)
aws ec2 create-tags --resources $PUB_RT --tags Key=Name,Value=ssc-public-rt --region $REGION
aws ec2 create-route --route-table-id $PUB_RT --destination-cidr-block 0.0.0.0/0 --gateway-id $IGW_ID --region $REGION | Out-Null
aws ec2 associate-route-table --subnet-id $PUB_SUB_1 --route-table-id $PUB_RT --region $REGION | Out-Null
aws ec2 associate-route-table --subnet-id $PUB_SUB_2 --route-table-id $PUB_RT --region $REGION | Out-Null

$PRIV_RT = (aws ec2 create-route-table --vpc-id $VPC_ID --region $REGION --query "RouteTable.RouteTableId" --output text)
aws ec2 create-tags --resources $PRIV_RT --tags Key=Name,Value=ssc-private-rt --region $REGION
aws ec2 create-route --route-table-id $PRIV_RT --destination-cidr-block 0.0.0.0/0 --nat-gateway-id $NAT_GW_ID --region $REGION | Out-Null
aws ec2 associate-route-table --subnet-id $PRIV_SUB_1 --route-table-id $PRIV_RT --region $REGION | Out-Null
aws ec2 associate-route-table --subnet-id $PRIV_SUB_2 --route-table-id $PRIV_RT --region $REGION | Out-Null
Write-Host "✅ Route Tables Configured: Public($PUB_RT) | Private($PRIV_RT)" -ForegroundColor Green

# 6. Security Groups
Write-Host "`n[6/10] Creating Security Groups..." -ForegroundColor Yellow
$ALB_SG = (aws ec2 create-security-group --group-name "ssc-alb-sg" --description "ALB Public HTTP Ingress" --vpc-id $VPC_ID --region $REGION --query "GroupId" --output text)
aws ec2 create-tags --resources $ALB_SG --tags Key=Name,Value=ssc-alb-sg --region $REGION
aws ec2 authorize-security-group-ingress --group-id $ALB_SG --protocol tcp --port 80 --cidr 0.0.0.0/0 --region $REGION | Out-Null

$EC2_SG = (aws ec2 create-security-group --group-name "ssc-ec2-private-sg" --description "Private EC2 HTTP from ALB only" --vpc-id $VPC_ID --region $REGION --query "GroupId" --output text)
aws ec2 create-tags --resources $EC2_SG --tags Key=Name,Value=ssc-ec2-private-sg --region $REGION
aws ec2 authorize-security-group-ingress --group-id $EC2_SG --protocol tcp --port 80 --source-group $ALB_SG --region $REGION | Out-Null
Write-Host "✅ Security Groups: ALB($ALB_SG) | EC2 Private($EC2_SG)" -ForegroundColor Green

# 7. Launch Template (Ubuntu 22.04 LTS, t3.micro)
Write-Host "`n[7/10] Creating Launch Template..." -ForegroundColor Yellow
$USER_DATA_PATH = Join-Path $PSScriptRoot "user-data.sh"
$USER_DATA_BASE64 = [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($USER_DATA_PATH))

$LT_DATA = @"
{
  "ImageId": "$AMI_ID",
  "InstanceType": "t3.micro",
  "SecurityGroupIds": ["$EC2_SG"],
  "UserData": "$USER_DATA_BASE64",
  "MetadataOptions": {
    "HttpEndpoint": "enabled",
    "HttpTokens": "required",
    "HttpPutResponseHopLimit": 2
  },
  "TagSpecifications": [
    {
      "ResourceType": "instance",
      "Tags": [
        {"Key": "Name", "Value": "ssc-result-ubuntu-node"}
      ]
    }
  ]
}
"@

$LT_FILE = Join-Path $PSScriptRoot "lt_config.json"
Set-Content -Path $LT_FILE -Value $LT_DATA

aws ec2 delete-launch-template --launch-template-name "ssc-ubuntu-template" --region $REGION 2>$null
$LT_ID = (aws ec2 create-launch-template --launch-template-name "ssc-ubuntu-template" --version-description "v1" --launch-template-data file://$LT_FILE --region $REGION --query "LaunchTemplate.LaunchTemplateId" --output text)
Remove-Item $LT_FILE -Force
Write-Host "✅ Launch Template Created: $LT_ID" -ForegroundColor Green

# 8. Target Group & Application Load Balancer
Write-Host "`n[8/10] Creating Target Group & Application Load Balancer..." -ForegroundColor Yellow
$TG_ARN = (aws elbv2 create-target-group --name "ssc-result-tg" --protocol HTTP --port 80 --vpc-id $VPC_ID --target-type instance --health-check-path "/health" --health-check-interval-seconds 15 --healthy-threshold-count 2 --unhealthy-threshold-count 2 --region $REGION --query "TargetGroups[0].TargetGroupArn" --output text)
aws elbv2 add-tags --resource-arns $TG_ARN --tags Key=Name,Value=ssc-result-tg --region $REGION

$ALB_DATA = (aws elbv2 create-load-balancer --name "ssc-result-alb" --subnets $PUB_SUB_1 $PUB_SUB_2 --security-groups $ALB_SG --scheme internet-facing --type application --region $REGION --query "LoadBalancers[0]" --output json | ConvertFrom-Json)
$ALB_ARN = $ALB_DATA.LoadBalancerArn
$ALB_DNS = $ALB_DATA.DNSName
aws elbv2 add-tags --resource-arns $ALB_ARN --tags Key=Name,Value=ssc-result-alb --region $REGION

aws elbv2 create-listener --load-balancer-arn $ALB_ARN --protocol HTTP --port 80 --default-actions Type=forward,TargetGroupArn=$TG_ARN --region $REGION | Out-Null
Write-Host "✅ ALB Created: http://$ALB_DNS" -ForegroundColor Green

# 9. Auto Scaling Group (Min 2, Desired 2, Max 10)
Write-Host "`n[9/10] Creating Auto Scaling Group across Private Subnets..." -ForegroundColor Yellow
aws autoscaling delete-auto-scaling-group --auto-scaling-group-name "ssc-result-asg" --force-delete --region $REGION 2>$null

aws autoscaling create-auto-scaling-group `
  --auto-scaling-group-name "ssc-result-asg" `
  --launch-template "LaunchTemplateId=$LT_ID,Version=`$Latest" `
  --min-size 2 `
  --max-size 10 `
  --desired-capacity 2 `
  --target-group-arns $TG_ARN `
  --vpc-zone-identifier "$PRIV_SUB_1,$PRIV_SUB_2" `
  --health-check-type ELB `
  --health-check-grace-period 180 `
  --tags "Key=Name,Value=ssc-result-worker,PropagateAtLaunch=true" `
  --region $REGION

# 10. Auto Scaling Policy: Target Tracking (CPU 50%)
Write-Host "`n[10/10] Configuring CPU Target Tracking Scaling Policy (50%)..." -ForegroundColor Yellow
$POLICY_FILE = Join-Path $PSScriptRoot "policy.json"
Set-Content -Path $POLICY_FILE -Value '{"PredefinedMetricSpecification":{"PredefinedMetricType":"ASGAverageCPUUtilization"},"TargetValue":50.0}'

aws autoscaling put-scaling-policy `
  --auto-scaling-group-name "ssc-result-asg" `
  --policy-name "ssc-cpu-target-tracking-50" `
  --policy-type TargetTrackingScaling `
  --target-tracking-configuration file://$POLICY_FILE `
  --region $REGION | Out-Null
Remove-Item $POLICY_FILE -Force

Write-Host "===============================================================" -ForegroundColor Green
Write-Host " 🎉 FRESH AWS DEPLOYMENT COMPLETED SUCCESSFULLY!" -ForegroundColor Green
Write-Host "===============================================================" -ForegroundColor Green
Write-Host " 🌐 Website URL (ALB DNS): http://$ALB_DNS" -ForegroundColor Cyan
Write-Host " 📍 VPC ID: $VPC_ID" -ForegroundColor Cyan
Write-Host " 📍 Auto Scaling Group: ssc-result-asg (Min: 2, Desired: 2, Max: 10)" -ForegroundColor Cyan
Write-Host "===============================================================" -ForegroundColor Green
