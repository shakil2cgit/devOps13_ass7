#!/bin/bash
# ==============================================================================
# Helper Script: CPU Stress Generator for AWS Auto Scaling Testing
# Purpose: Generates CPU load to breach CloudWatch CPUUtilization threshold (e.g. >50%)
# ==============================================================================

DURATION_SECONDS=${1:-300} # Default: 5 minutes (300s)

echo "🔥 Starting CPU Stress Test for ${DURATION_SECONDS} seconds..."
echo "📊 This will push CPU utilization > 80% to trigger CloudWatch Scale-Out Alarm."

# Try using the 'stress' tool if installed
if command -v stress &> /dev/null; then
    stress --cpu $(nproc) --timeout "${DURATION_SECONDS}s"
else
    # Fallback to pure bash background math loops
    NUM_CORES=$(nproc 2>/dev/null || echo 2)
    PIDS=()
    
    echo "⚡ Spawning $NUM_CORES worker loops..."
    for ((i=1; i<=NUM_CORES; i++)); do
        (
            end=$((SECONDS + DURATION_SECONDS))
            while [ $SECONDS -lt $end ]; do
                _=$(( 123456 * 789012 ))
            done
        ) &
        PIDS+=($!)
    done

    echo "⏳ Stress running with PIDs: ${PIDS[*]}"
    echo "Press Ctrl+C or wait ${DURATION_SECONDS} seconds."
    
    # Wait for all background loops
    for pid in "${PIDS[@]}"; do
        wait "$pid" 2>/dev/null || true
    done
fi

echo "✅ CPU Stress Test Completed! CPU will cool down and trigger Scale-In."
