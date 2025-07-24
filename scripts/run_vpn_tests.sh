#!/bin/bash

# WireGuard VPN Performance Testing - VPN Tests
# This script runs performance tests through the WireGuard VPN tunnel

set -e

# Configuration
RESULTS_DIR="../results"
VPN_DIR="$RESULTS_DIR/vpn"
BASELINE_DIR="$RESULTS_DIR/baseline"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
TEST_DURATION=30
PING_COUNT=100

# WireGuard interface name (modify as needed)
WG_INTERFACE="wg0"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Create results directory
mkdir -p "$VPN_DIR"

echo -e "${BLUE}=== WireGuard VPN Performance Tests ===${NC}"
echo -e "${YELLOW}Timestamp: $TIMESTAMP${NC}"
echo -e "${YELLOW}Test Duration: ${TEST_DURATION}s${NC}"
echo -e "${YELLOW}Ping Count: $PING_COUNT${NC}"
echo -e "${YELLOW}WireGuard Interface: $WG_INTERFACE${NC}"
echo ""

# Function to check WireGuard status
check_wireguard_status() {
    echo -e "${BLUE}=== Checking WireGuard Status ===${NC}"
    
    if ! command -v wg &> /dev/null; then
        echo -e "${RED}Error: WireGuard tools not installed${NC}"
        exit 1
    fi
    
    if ! wg show "$WG_INTERFACE" &> /dev/null; then
        echo -e "${RED}Error: WireGuard interface $WG_INTERFACE not found${NC}"
        echo -e "${YELLOW}Available interfaces:${NC}"
        wg show interfaces 2>/dev/null || echo "No WireGuard interfaces found"
        exit 1
    fi
    
    echo -e "${GREEN}✓ WireGuard interface $WG_INTERFACE is active${NC}"
    
    # Show WireGuard status
    echo -e "${BLUE}WireGuard Status:${NC}"
    wg show "$WG_INTERFACE"
    echo ""
}

# Function to log results
log_result() {
    local test_name="$1"
    local result="$2"
    echo "$result" >> "$VPN_DIR/${test_name}_${TIMESTAMP}.txt"
    echo "$result" >> "$VPN_DIR/${test_name}_latest.txt"
}

# Function to run ping test through VPN
run_ping_test() {
    local target="$1"
    local test_name="$2"
    
    echo -e "${GREEN}Running ping test to $target through VPN...${NC}"
    
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
  "packet_loss_percent": $packet_loss,
  "interface": "$WG_INTERFACE"
}
EOF
)
    
    log_result "$test_name" "$json_result"
    echo -e "${GREEN}✓ Ping test completed${NC}"
    echo "  Min: ${min_ping}ms, Avg: ${avg_ping}ms, Max: ${max_ping}ms, Loss: ${packet_loss}%"
}

# Function to run iperf3 test through VPN
run_iperf_test() {
    local target="$1"
    local test_name="$2"
    local direction="$3"  # "upload" or "download"
    
    echo -e "${GREEN}Running iperf3 $direction test to $target through VPN...${NC}"
    
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
  "bandwidth_mbps": $bandwidth_mbps,
  "interface": "$WG_INTERFACE"
}
EOF
)
    
    log_result "$test_name" "$json_result"
    echo -e "${GREEN}✓ iperf3 $direction test completed${NC}"
    echo "  Bandwidth: ${bandwidth_mbps} Mbps"
}

# Function to test DNS resolution through VPN
run_dns_test() {
    echo -e "${GREEN}Testing DNS resolution through VPN...${NC}"
    
    # Test DNS resolution
    local start_time=$(date +%s.%N)
    nslookup google.com &>/dev/null
    local end_time=$(date +%s.%N)
    local dns_time=$(echo "$end_time - $start_time" | bc -l)
    
    # Create JSON result
    local json_result=$(cat <<EOF
{
  "test_name": "dns_resolution",
  "domain": "google.com",
  "timestamp": "$TIMESTAMP",
  "resolution_time_seconds": $dns_time,
  "interface": "$WG_INTERFACE"
}
EOF
)
    
    log_result "dns_resolution" "$json_result"
    echo -e "${GREEN}✓ DNS resolution test completed${NC}"
    echo "  Resolution time: ${dns_time}s"
}

# Function to get VPN network information
get_vpn_network_info() {
    echo -e "${BLUE}=== VPN Network Information ===${NC}"
    
    # Get VPN IP
    vpn_ip=$(ifconfig "$WG_INTERFACE" | grep "inet " | awk '{print $2}')
    echo "VPN IP: $vpn_ip"
    
    # Get VPN interface status
    vpn_status=$(ifconfig "$WG_INTERFACE" | grep "status" | awk '{print $2}')
    echo "VPN Status: $vpn_status"
    
    # Get routing information
    echo -e "${BLUE}Routing through VPN:${NC}"
    route -n get 8.8.8.8 | grep -E "(gateway|interface)" || echo "No specific route found"
    
    # Save VPN network info
    cat > "$VPN_DIR/vpn_network_info_${TIMESTAMP}.txt" <<EOF
{
  "timestamp": "$TIMESTAMP",
  "vpn_interface": "$WG_INTERFACE",
  "vpn_ip": "$vpn_ip",
  "vpn_status": "$vpn_status"
}
EOF
}

# Function to compare with baseline
compare_with_baseline() {
    echo -e "${BLUE}=== Comparing with Baseline ===${NC}"
    
    if [ -f "$BASELINE_DIR/ping_gateway_latest.txt" ] && [ -f "$VPN_DIR/ping_gateway_latest.txt" ]; then
        baseline_avg=$(cat "$BASELINE_DIR/ping_gateway_latest.txt" | jq -r '.avg_ping_ms')
        vpn_avg=$(cat "$VPN_DIR/ping_gateway_latest.txt" | jq -r '.avg_ping_ms')
        
        overhead=$(echo "scale=2; $vpn_avg - $baseline_avg" | bc -l)
        overhead_percent=$(echo "scale=2; ($overhead / $baseline_avg) * 100" | bc -l)
        
        echo -e "${YELLOW}Latency Overhead: +${overhead}ms (+${overhead_percent}%)${NC}"
        
        # Save comparison
        cat > "$VPN_DIR/comparison_${TIMESTAMP}.txt" <<EOF
{
  "timestamp": "$TIMESTAMP",
  "baseline_avg_ping_ms": $baseline_avg,
  "vpn_avg_ping_ms": $vpn_avg,
  "overhead_ms": $overhead,
  "overhead_percent": $overhead_percent
}
EOF
    else
        echo -e "${YELLOW}Baseline data not available for comparison${NC}"
    fi
}

# Main test execution
main() {
    echo -e "${BLUE}Starting WireGuard VPN performance tests...${NC}"
    
    # Check WireGuard status
    check_wireguard_status
    
    # Get VPN network information
    get_vpn_network_info
    
    # Test targets (modify these for your network)
    vpn_targets=(
        "192.168.1.1:gateway"
        "8.8.8.8:google_dns"
        "1.1.1.1:cloudflare_dns"
    )
    
    # Run ping tests through VPN
    echo -e "${BLUE}=== Ping Tests Through VPN ===${NC}"
    for target_info in "${vpn_targets[@]}"; do
        target=$(echo "$target_info" | cut -d':' -f1)
        test_name=$(echo "$target_info" | cut -d':' -f2)
        run_ping_test "$target" "ping_${test_name}"
    done
    
    # Run DNS test
    run_dns_test
    
    # Run iperf3 tests through VPN (requires iperf3 server on target)
    echo -e "${BLUE}=== Bandwidth Tests Through VPN ===${NC}"
    echo -e "${YELLOW}Note: iperf3 tests require a server running on the target${NC}"
    
    # Uncomment and modify these lines when you have iperf3 servers available
    # run_iperf_test "192.168.1.100" "iperf_upload" "upload"
    # run_iperf_test "192.168.1.100" "iperf_download" "download"
    
    # Compare with baseline
    compare_with_baseline
    
    echo -e "${GREEN}=== VPN Tests Completed ===${NC}"
    echo -e "${YELLOW}Results saved to: $VPN_DIR${NC}"
    echo -e "${YELLOW}Next: Analyze results with: ./scripts/analyze_results.sh${NC}"
}

# Run main function
main "$@" 