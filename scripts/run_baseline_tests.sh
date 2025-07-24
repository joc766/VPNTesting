#!/bin/bash

# WireGuard VPN Performance Testing - Baseline Tests
# This script runs baseline network performance tests without VPN

set -e

# Configuration
RESULTS_DIR="../results"
BASELINE_DIR="$RESULTS_DIR/baseline"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
TEST_DURATION=30
PING_COUNT=100

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Create results directory
mkdir -p "$BASELINE_DIR"

echo -e "${BLUE}=== WireGuard VPN Baseline Performance Tests ===${NC}"
echo -e "${YELLOW}Timestamp: $TIMESTAMP${NC}"
echo -e "${YELLOW}Test Duration: ${TEST_DURATION}s${NC}"
echo -e "${YELLOW}Ping Count: $PING_COUNT${NC}"
echo ""

# Function to log results
log_result() {
    local test_name="$1"
    local result="$2"
    echo "$result" >> "$BASELINE_DIR/${test_name}_${TIMESTAMP}.txt"
    echo "$result" >> "$BASELINE_DIR/${test_name}_latest.txt"
}

# Function to run ping test
run_ping_test() {
    local target="$1"
    local test_name="$2"
    
    echo -e "${GREEN}Running ping test to $target...${NC}"
    
    # Run ping and capture results
    ping_result=$(ping -c "$PING_COUNT" -i 0.2 "$target" 2>/dev/null | tail -n 4)
    
    # Extract statistics
    local min_ping=$(echo "$ping_result" | grep "min/avg/max" | awk '{print $4}' | cut -d'/' -f1)
    local avg_ping=$(echo "$ping_result" | grep "min/avg/max" | awk '{print $4}' | cut -d'/' -f2)
    local max_ping=$(echo "$ping_result" | grep "min/avg/max" | awk '{print $4}' | cut -d'/' -f3)
    local packet_loss=$(echo "$ping_result" | grep "packet loss" | awk '{print $6}' | sed 's/%//')
    
    # Create JSON result
    local json_result=$(cat <<EOF
{
  "test_name": "$test_name",
  "target": "$target",
  "timestamp": "$TIMESTAMP",
  "ping_count": $PING_COUNT,
  "min_ping_ms": $min_ping,
  "avg_ping_ms": $avg_ping,
  "max_ping_ms": $max_ping,
  "packet_loss_percent": $packet_loss
}
EOF
)
    
    log_result "$test_name" "$json_result"
    echo -e "${GREEN}✓ Ping test completed${NC}"
    echo "  Min: ${min_ping}ms, Avg: ${avg_ping}ms, Max: ${max_ping}ms, Loss: ${packet_loss}%"
}

# Function to run iperf3 test
run_iperf_test() {
    local target="$1"
    local test_name="$2"
    local direction="$3"  # "upload" or "download"
    
    echo -e "${GREEN}Running iperf3 $direction test to $target...${NC}"
    
    # Run iperf3 test
    if [ "$direction" = "upload" ]; then
        iperf_result=$(iperf3 -c "$target" -t "$TEST_DURATION" -J 2>/dev/null)
    else
        iperf_result=$(iperf3 -c "$target" -t "$TEST_DURATION" -R -J 2>/dev/null)
    fi
    
    # Extract bandwidth
    local bandwidth=$(echo "$iperf_result" | jq -r '.end.sum_received.bits_per_second')
    local bandwidth_mbps=$(echo "scale=2; $bandwidth / 1000000" | bc -l)
    
    # Create JSON result
    local json_result=$(cat <<EOF
{
  "test_name": "$test_name",
  "target": "$target",
  "direction": "$direction",
  "timestamp": "$TIMESTAMP",
  "duration_seconds": $TEST_DURATION,
  "bandwidth_bps": $bandwidth,
  "bandwidth_mbps": $bandwidth_mbps
}
EOF
)
    
    log_result "$test_name" "$json_result"
    echo -e "${GREEN}✓ iperf3 $direction test completed${NC}"
    echo "  Bandwidth: ${bandwidth_mbps} Mbps"
}

# Function to get network information
get_network_info() {
    echo -e "${BLUE}=== Network Information ===${NC}"
    
    # Get local IP
    local_ip=$(ifconfig | grep "inet " | grep -v 127.0.0.1 | awk '{print $2}' | head -n 1)
    echo "Local IP: $local_ip"
    
    # Get default gateway
    gateway=$(route -n get default | grep gateway | awk '{print $2}')
    echo "Default Gateway: $gateway"
    
    # Get DNS servers
    dns_servers=$(scutil --dns | grep "nameserver\[" | awk '{print $3}' | head -n 2 | tr '\n' ' ')
    echo "DNS Servers: $dns_servers"
    
    # Save network info
    cat > "$BASELINE_DIR/network_info_${TIMESTAMP}.txt" <<EOF
{
  "timestamp": "$TIMESTAMP",
  "local_ip": "$local_ip",
  "gateway": "$gateway",
  "dns_servers": "$dns_servers"
}
EOF
}

# Main test execution
main() {
    echo -e "${BLUE}Starting baseline performance tests...${NC}"
    
    # Get network information
    get_network_info
    
    # Test targets (modify these for your network)
    local_targets=(
        "192.168.1.1:gateway"
        "8.8.8.8:google_dns"
        "1.1.1.1:cloudflare_dns"
    )
    
    # Run ping tests
    echo -e "${BLUE}=== Ping Tests ===${NC}"
    for target_info in "${local_targets[@]}"; do
        target=$(echo "$target_info" | cut -d':' -f1)
        test_name=$(echo "$target_info" | cut -d':' -f2)
        run_ping_test "$target" "ping_${test_name}"
    done
    
    # Run iperf3 tests (requires iperf3 server on target)
    echo -e "${BLUE}=== Bandwidth Tests ===${NC}"
    echo -e "${YELLOW}Note: iperf3 tests require a server running on the target${NC}"
    echo -e "${YELLOW}To start iperf3 server: iperf3 -s${NC}"
    
    # Uncomment and modify these lines when you have iperf3 servers available
    # run_iperf_test "192.168.1.100" "iperf_upload" "upload"
    # run_iperf_test "192.168.1.100" "iperf_download" "download"
    
    echo -e "${GREEN}=== Baseline Tests Completed ===${NC}"
    echo -e "${YELLOW}Results saved to: $BASELINE_DIR${NC}"
    echo -e "${YELLOW}Next: Run WireGuard tests with: ./scripts/run_vpn_tests.sh${NC}"
}

# Run main function
main "$@" 