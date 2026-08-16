#!/bin/bash
# ==============================================================================
# Helper Script: ALB Traffic & Round-Robin Load Tester
# Usage: ./test-alb-traffic.sh <ALB_DNS_NAME> [NUM_REQUESTS]
# ==============================================================================

ALB_DNS=$1
TOTAL_REQUESTS=${2:-30}

if [ -z "$ALB_DNS" ]; then
    echo "Usage: $0 <ALB_DNS_URL> [NUM_REQUESTS]"
    echo "Example: $0 http://ssc-alb-123456789.us-east-1.elb.amazonaws.com 20"
    exit 1
fi

echo "================================================================="
echo " 🌐 Testing ALB DNS: $ALB_DNS"
echo " 🚀 Sending $TOTAL_REQUESTS HTTP Requests to demonstrate Round-Robin..."
echo "================================================================="

for ((i=1; i<=TOTAL_REQUESTS; i++)); do
    RESP=$(curl -s --connect-timeout 2 "$ALB_DNS/health" || echo '{"status":"FAILED"}')
    echo "Request #$i -> $RESP"
    sleep 0.2
done

echo "================================================================="
echo "✅ Test completed! Notice how requests are distributed among Target EC2s."
