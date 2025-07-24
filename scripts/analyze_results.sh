#!/bin/bash

# WireGuard VPN Performance Testing - Results Analysis
# This script analyzes test results and generates reports

set -e

# Configuration
RESULTS_DIR="../results"
BASELINE_DIR="$RESULTS_DIR/baseline"
VPN_DIR="$RESULTS_DIR/vpn"
ANALYSIS_DIR="$RESULTS_DIR/analysis"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Create analysis directory
mkdir -p "$ANALYSIS_DIR"

echo -e "${BLUE}=== WireGuard VPN Performance Analysis ===${NC}"
echo -e "${YELLOW}Timestamp: $TIMESTAMP${NC}"
echo ""

# Function to check if jq is available
check_dependencies() {
    if ! command -v jq &> /dev/null; then
        echo -e "${RED}Error: jq is required for JSON processing${NC}"
        echo -e "${YELLOW}Install with: brew install jq${NC}"
        exit 1
    fi
    
    if ! command -v bc &> /dev/null; then
        echo -e "${RED}Error: bc is required for calculations${NC}"
        echo -e "${YELLOW}Install with: brew install bc${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✓ Dependencies check passed${NC}"
}

# Function to generate summary report
generate_summary_report() {
    echo -e "${BLUE}=== Generating Summary Report ===${NC}"
    
    local report_file="$ANALYSIS_DIR/summary_report_${TIMESTAMP}.txt"
    
    cat > "$report_file" <<EOF
# WireGuard VPN Performance Test Summary
Generated: $(date)
Timestamp: $TIMESTAMP

## Test Overview
- Baseline tests: $(ls -1 "$BASELINE_DIR"/*.txt 2>/dev/null | wc -l | tr -d ' ') files
- VPN tests: $(ls -1 "$VPN_DIR"/*.txt 2>/dev/null | wc -l | tr -d ' ') files

## Key Metrics Summary
EOF
    
    # Analyze ping results
    if [ -f "$BASELINE_DIR/ping_gateway_latest.txt" ] && [ -f "$VPN_DIR/ping_gateway_latest.txt" ]; then
        baseline_avg=$(cat "$BASELINE_DIR/ping_gateway_latest.txt" | jq -r '.avg_ping_ms')
        vpn_avg=$(cat "$VPN_DIR/ping_gateway_latest.txt" | jq -r '.avg_ping_ms')
        overhead=$(echo "scale=2; $vpn_avg - $baseline_avg" | bc -l)
        overhead_percent=$(echo "scale=2; ($overhead / $baseline_avg) * 100" | bc -l)
        
        cat >> "$report_file" <<EOF

### Latency Analysis (Gateway)
- Baseline Average: ${baseline_avg}ms
- VPN Average: ${vpn_avg}ms
- Overhead: +${overhead}ms (+${overhead_percent}%)

EOF
    fi
    
    # Analyze DNS results
    if [ -f "$VPN_DIR/dns_resolution_latest.txt" ]; then
        dns_time=$(cat "$VPN_DIR/dns_resolution_latest.txt" | jq -r '.resolution_time_seconds')
        cat >> "$report_file" <<EOF

### DNS Resolution
- Resolution Time: ${dns_time}s

EOF
    fi
    
    echo -e "${GREEN}✓ Summary report generated: $report_file${NC}"
}

# Function to generate detailed comparison
generate_detailed_comparison() {
    echo -e "${BLUE}=== Generating Detailed Comparison ===${NC}"
    
    local comparison_file="$ANALYSIS_DIR/detailed_comparison_${TIMESTAMP}.txt"
    
    cat > "$comparison_file" <<EOF
# WireGuard VPN Detailed Performance Comparison
Generated: $(date)
Timestamp: $TIMESTAMP

## Test Targets Comparison
EOF
    
    # Compare each test target
    for target in "gateway" "google_dns" "cloudflare_dns"; do
        baseline_file="$BASELINE_DIR/ping_${target}_latest.txt"
        vpn_file="$VPN_DIR/ping_${target}_latest.txt"
        
        if [ -f "$baseline_file" ] && [ -f "$vpn_file" ]; then
            baseline_avg=$(cat "$baseline_file" | jq -r '.avg_ping_ms')
            baseline_min=$(cat "$baseline_file" | jq -r '.min_ping_ms')
            baseline_max=$(cat "$baseline_file" | jq -r '.max_ping_ms')
            baseline_loss=$(cat "$baseline_file" | jq -r '.packet_loss_percent')
            
            vpn_avg=$(cat "$vpn_file" | jq -r '.avg_ping_ms')
            vpn_min=$(cat "$vpn_file" | jq -r '.min_ping_ms')
            vpn_max=$(cat "$vpn_file" | jq -r '.max_ping_ms')
            vpn_loss=$(cat "$vpn_file" | jq -r '.packet_loss_percent')
            
            overhead=$(echo "scale=2; $vpn_avg - $baseline_avg" | bc -l)
            overhead_percent=$(echo "scale=2; ($overhead / $baseline_avg) * 100" | bc -l)
            
            cat >> "$comparison_file" <<EOF

### ${target^} (${target//_/ })
| Metric | Baseline | VPN | Difference |
|--------|----------|-----|------------|
| Min Ping | ${baseline_min}ms | ${vpn_min}ms | +$(echo "scale=2; $vpn_min - $baseline_min" | bc -l)ms |
| Avg Ping | ${baseline_avg}ms | ${vpn_avg}ms | +${overhead}ms (+${overhead_percent}%) |
| Max Ping | ${baseline_max}ms | ${vpn_max}ms | +$(echo "scale=2; $vpn_max - $baseline_max" | bc -l)ms |
| Packet Loss | ${baseline_loss}% | ${vpn_loss}% | $(echo "scale=2; $vpn_loss - $baseline_loss" | bc -l)% |

EOF
        fi
    done
    
    echo -e "${GREEN}✓ Detailed comparison generated: $comparison_file${NC}"
}

# Function to generate JSON summary
generate_json_summary() {
    echo -e "${BLUE}=== Generating JSON Summary ===${NC}"
    
    local json_file="$ANALYSIS_DIR/performance_summary_${TIMESTAMP}.json"
    
    # Initialize JSON structure
    cat > "$json_file" <<EOF
{
  "test_summary": {
    "timestamp": "$TIMESTAMP",
    "generated": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
    "baseline_tests": $(ls -1 "$BASELINE_DIR"/*.txt 2>/dev/null | wc -l | tr -d ' '),
    "vpn_tests": $(ls -1 "$VPN_DIR"/*.txt 2>/dev/null | wc -l | tr -d ' ')
  },
  "results": {
EOF
    
    # Add ping results
    first=true
    for target in "gateway" "google_dns" "cloudflare_dns"; do
        baseline_file="$BASELINE_DIR/ping_${target}_latest.txt"
        vpn_file="$VPN_DIR/ping_${target}_latest.txt"
        
        if [ -f "$baseline_file" ] && [ -f "$vpn_file" ]; then
            if [ "$first" = true ]; then
                first=false
            else
                echo "," >> "$json_file"
            fi
            
            baseline_avg=$(cat "$baseline_file" | jq -r '.avg_ping_ms')
            vpn_avg=$(cat "$vpn_file" | jq -r '.avg_ping_ms')
            overhead=$(echo "scale=2; $vpn_avg - $baseline_avg" | bc -l)
            
            cat >> "$json_file" <<EOF
    "$target": {
      "baseline_avg_ms": $baseline_avg,
      "vpn_avg_ms": $vpn_avg,
      "overhead_ms": $overhead,
      "overhead_percent": $(echo "scale=2; ($overhead / $baseline_avg) * 100" | bc -l)
    }
EOF
        fi
    done
    
    # Close JSON structure
    cat >> "$json_file" <<EOF
  }
}
EOF
    
    echo -e "${GREEN}✓ JSON summary generated: $json_file${NC}"
}

# Function to generate recommendations
generate_recommendations() {
    echo -e "${BLUE}=== Generating Recommendations ===${NC}"
    
    local recommendations_file="$ANALYSIS_DIR/recommendations_${TIMESTAMP}.txt"
    
    cat > "$recommendations_file" <<EOF
# WireGuard VPN Performance Recommendations
Generated: $(date)
Timestamp: $TIMESTAMP

## Performance Analysis
EOF
    
    # Analyze latency overhead
    if [ -f "$BASELINE_DIR/ping_gateway_latest.txt" ] && [ -f "$VPN_DIR/ping_gateway_latest.txt" ]; then
        baseline_avg=$(cat "$BASELINE_DIR/ping_gateway_latest.txt" | jq -r '.avg_ping_ms')
        vpn_avg=$(cat "$VPN_DIR/ping_gateway_latest.txt" | jq -r '.avg_ping_ms')
        overhead=$(echo "scale=2; $vpn_avg - $baseline_avg" | bc -l)
        overhead_percent=$(echo "scale=2; ($overhead / $baseline_avg) * 100" | bc -l)
        
        cat >> "$recommendations_file" <<EOF

### Latency Overhead: ${overhead}ms (${overhead_percent}%)

EOF
        
        if (( $(echo "$overhead_percent < 10" | bc -l) )); then
            cat >> "$recommendations_file" <<EOF
✅ EXCELLENT: Latency overhead is minimal (< 10%)
- WireGuard is performing optimally
- Consider this configuration for production use

EOF
        elif (( $(echo "$overhead_percent < 25" | bc -l) )); then
            cat >> "$recommendations_file" <<EOF
⚠️  GOOD: Latency overhead is acceptable (10-25%)
- Performance is within acceptable range
- Consider optimizing MTU settings

EOF
        else
            cat >> "$recommendations_file" <<EOF
❌ POOR: Latency overhead is high (> 25%)
- Investigate network configuration
- Check for routing issues
- Consider alternative VPN solutions

EOF
        fi
    fi
    
    # Add general recommendations
    cat >> "$recommendations_file" <<EOF

## General Recommendations

### For Local Network Testing
1. Test different MTU values (1420-1500)
2. Experiment with keepalive settings
3. Test with different cryptographic algorithms
4. Monitor CPU usage during tests

### For Geographic Testing (Chicago-New York)
1. Use cloud providers with low-latency connections
2. Test during different times of day
3. Monitor for packet loss and jitter
4. Consider redundant connections

### Optimization Tips
1. Use hardware acceleration if available
2. Optimize routing tables
3. Consider split tunneling for non-sensitive traffic
4. Monitor bandwidth utilization

## Next Steps
1. Run tests with different WireGuard configurations
2. Test with various network conditions
3. Implement automated testing for continuous monitoring
4. Document configuration changes and their impact
EOF
    
    echo -e "${GREEN}✓ Recommendations generated: $recommendations_file${NC}"
}

# Function to display quick stats
display_quick_stats() {
    echo -e "${BLUE}=== Quick Statistics ===${NC}"
    
    if [ -f "$BASELINE_DIR/ping_gateway_latest.txt" ] && [ -f "$VPN_DIR/ping_gateway_latest.txt" ]; then
        baseline_avg=$(cat "$BASELINE_DIR/ping_gateway_latest.txt" | jq -r '.avg_ping_ms')
        vpn_avg=$(cat "$VPN_DIR/ping_gateway_latest.txt" | jq -r '.avg_ping_ms')
        overhead=$(echo "scale=2; $vpn_avg - $baseline_avg" | bc -l)
        overhead_percent=$(echo "scale=2; ($overhead / $baseline_avg) * 100" | bc -l)
        
        echo -e "${GREEN}Gateway Latency:${NC}"
        echo "  Baseline: ${baseline_avg}ms"
        echo "  VPN: ${vpn_avg}ms"
        echo "  Overhead: +${overhead}ms (+${overhead_percent}%)"
        
        if (( $(echo "$overhead_percent < 10" | bc -l) )); then
            echo -e "${GREEN}  Status: Excellent${NC}"
        elif (( $(echo "$overhead_percent < 25" | bc -l) )); then
            echo -e "${YELLOW}  Status: Good${NC}"
        else
            echo -e "${RED}  Status: Needs Improvement${NC}"
        fi
    else
        echo -e "${YELLOW}No baseline or VPN data available for comparison${NC}"
    fi
    
    echo ""
}

# Main analysis execution
main() {
    echo -e "${BLUE}Starting WireGuard VPN performance analysis...${NC}"
    
    # Check dependencies
    check_dependencies
    
    # Display quick stats
    display_quick_stats
    
    # Generate reports
    generate_summary_report
    generate_detailed_comparison
    generate_json_summary
    generate_recommendations
    
    echo -e "${GREEN}=== Analysis Completed ===${NC}"
    echo -e "${YELLOW}Reports saved to: $ANALYSIS_DIR${NC}"
    echo ""
    echo -e "${BLUE}Generated Files:${NC}"
    ls -la "$ANALYSIS_DIR"/*"$TIMESTAMP"* 2>/dev/null || echo "No files generated"
}

# Run main function
main "$@" 