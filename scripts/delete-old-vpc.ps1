$ErrorActionPreference = "Continue"
$oldVpc = "vpc-0a0a12771efb32f85"
$region = "ap-southeast-1"

Write-Host "Cleaning up old VPC ($oldVpc)..." -ForegroundColor Yellow

# 1. Detach & Delete IGW
$igws = (aws ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=$oldVpc" --region $region --query "InternetGateways[*].InternetGatewayId" --output text)
if ($igws) {
    foreach ($igw in $igws.Split()) {
        if ($igw -and $igw -ne "None") {
            aws ec2 detach-internet-gateway --internet-gateway-id $igw --vpc-id $oldVpc --region $region
            aws ec2 delete-internet-gateway --internet-gateway-id $igw --region $region
            Write-Host "Deleted IGW: $igw"
        }
    }
}

# 2. Delete Subnets
$subs = (aws ec2 describe-subnets --filters "Name=vpc-id,Values=$oldVpc" --region $region --query "Subnets[*].SubnetId" --output text)
if ($subs) {
    foreach ($sub in $subs.Split()) {
        if ($sub -and $sub -ne "None") {
            aws ec2 delete-subnet --subnet-id $sub --region $region
            Write-Host "Deleted Subnet: $sub"
        }
    }
}

# 3. Delete Route Tables
$rts = (aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$oldVpc" --region $region --query "RouteTables[?Associations[0].Main!=true].RouteTableId" --output text)
if ($rts) {
    foreach ($rt in $rts.Split()) {
        if ($rt -and $rt -ne "None") {
            aws ec2 delete-route-table --route-table-id $rt --region $region
            Write-Host "Deleted Route Table: $rt"
        }
    }
}

# 4. Delete Security Groups
$sgs = (aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$oldVpc" --region $region --query "SecurityGroups[?GroupName!='default'].GroupId" --output text)
if ($sgs) {
    foreach ($sg in $sgs.Split()) {
        if ($sg -and $sg -ne "None") {
            aws ec2 delete-security-group --group-id $sg --region $region
            Write-Host "Deleted Security Group: $sg"
        }
    }
}

# 5. Delete Old VPC
aws ec2 delete-vpc --vpc-id $oldVpc --region $region
Write-Host "✅ Old VPC ($oldVpc - project-vpc) deleted successfully!" -ForegroundColor Green
