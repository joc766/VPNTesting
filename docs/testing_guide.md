# WireGuard VPN Performance Testing Guide

## Overview
This guide provides step-by-step instructions for testing WireGuard VPN performance using the provided testing framework. The framework supports both local network testing and geographic testing (Chicago-New York).

## Prerequisites

### System Requirements
- **Operating System**: macOS, Linux, or Windows (WSL)
- **Python**: 3.8 or higher
- **WireGuard**: Installed and configured
- **Network Tools**: ping, iperf3, jq, bc

### Required Software
```bash
# macOS (using Homebrew)
brew install wireguard-tools iperf3 jq bc python3

# Ubuntu/Debian
sudo apt update
sudo apt install wireguard iperf3 jq bc python3 python3-pip

# Install Python dependencies
pip3 install -r requirements.txt
```

## Quick Start

### 1. Initial Setup
```bash
# Clone or navigate to the project directory
cd vpn

# Install dependencies
pip3 install -r requirements.txt

# Make scripts executable (if not already done)
chmod +x scripts/*.sh tools/*.py
```

### 2. Run Baseline Tests
```bash
# Run baseline network performance tests (without VPN)
./scripts/run_baseline_tests.sh
```

This will:
- Test ping latency to common targets
- Measure network information
- Save results to `results/baseline/`

### 3. Run VPN Tests
```bash
# Run performance tests through WireGuard VPN
./scripts/run_vpn_tests.sh
```

This will:
- Verify WireGuard interface status
- Test ping latency through VPN
- Measure DNS resolution time
- Compare with baseline results
- Save results to `results/vpn/`

### 4. Analyze Results
```bash
# Generate comprehensive analysis
./scripts/analyze_results.sh

# Or use the Python analyzer for advanced analysis
python3 tools/vpn_analyzer.py
```

## Detailed Testing Procedures

### Local Network Testing

#### Test Scenario 1: Same Subnet
**Purpose**: Test VPN performance when client and server are on the same local network.

**Setup**:
1. Ensure WireGuard server (Raspberry Pi) is running
2. Configure client to connect to local server IP
3. Run baseline tests
4. Connect to VPN and run VPN tests

**Expected Results**:
- Latency overhead: < 5ms
- Bandwidth efficiency: > 90%
- Packet loss: < 0.1%

#### Test Scenario 2: Cross-Subnet
**Purpose**: Test VPN performance across different network segments.

**Setup**:
1. Configure client on different subnet
2. Ensure proper routing through VPN
3. Run comprehensive tests

**Expected Results**:
- Latency overhead: < 10ms
- Bandwidth efficiency: > 85%
- Packet loss: < 0.1%

#### Test Scenario 3: Router-to-Router
**Purpose**: Test VPN performance between two programmable routers.

**Setup**:
1. Configure both routers as WireGuard endpoints
2. Set up routing between networks
3. Test end-to-end performance

**Expected Results**:
- Latency overhead: < 15ms
- Bandwidth efficiency: > 80%
- Packet loss: < 0.5%

### Geographic Testing (Chicago-New York)

#### Phase 1: Infrastructure Setup
1. **Provision Cloud Resources**
   ```bash
   # Chicago Server (AWS US-East-2)
   - Instance: t3.medium
   - OS: Ubuntu 22.04 LTS
   - Security Group: Allow UDP 51820
   
   # New York Client (AWS US-East-1)
   - Instance: t3.medium
   - OS: Ubuntu 22.04 LTS
   - Security Group: Allow outbound traffic
   ```

2. **Install WireGuard**
   ```bash
   # On both instances
   sudo apt update
   sudo apt install wireguard
   ```

3. **Generate Keys**
   ```bash
   # Generate server keys
   wg genkey | tee server_private.key | wg pubkey > server_public.key
   
   # Generate client keys
   wg genkey | tee client_private.key | wg pubkey > client_public.key
   ```

#### Phase 2: Configuration
1. **Server Configuration** (`/etc/wireguard/wg0.conf`)
   ```ini
   [Interface]
   PrivateKey = <server_private_key>
   Address = 10.0.0.1/24
   ListenPort = 51820
   PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
   PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE

   [Peer]
   PublicKey = <client_public_key>
   AllowedIPs = 10.0.0.2/32
   ```

2. **Client Configuration** (`/etc/wireguard/wg0.conf`)
   ```ini
   [Interface]
   PrivateKey = <client_private_key>
   Address = 10.0.0.2/24
   DNS = 8.8.8.8

   [Peer]
   PublicKey = <server_public_key>
   Endpoint = <chicago_server_ip>:51820
   AllowedIPs = 0.0.0.0/0
   PersistentKeepalive = 25
   ```

#### Phase 3: Testing
1. **Start WireGuard**
   ```bash
   # On server
   sudo wg-quick up wg0
   
   # On client
   sudo wg-quick up wg0
   ```

2. **Run Tests**
   ```bash
   # Copy testing framework to both instances
   # Run baseline tests on client
   ./scripts/run_baseline_tests.sh
   
   # Run VPN tests on client
   ./scripts/run_vpn_tests.sh
   ```

## Performance Benchmarks

### Local Network Benchmarks
| Metric | Excellent | Good | Acceptable | Poor |
|--------|-----------|------|------------|------|
| Latency Overhead | < 5ms | < 10ms | < 25ms | > 25ms |
| Bandwidth Efficiency | > 90% | > 80% | > 60% | < 60% |
| Packet Loss | < 0.1% | < 0.5% | < 1% | > 1% |
| DNS Resolution | < 10ms | < 50ms | < 100ms | > 100ms |

### Geographic Benchmarks (Chicago-NY)
| Metric | Excellent | Good | Acceptable | Poor |
|--------|-----------|------|------------|------|
| Latency Overhead | < 10ms | < 20ms | < 50ms | > 50ms |
| Bandwidth Efficiency | > 80% | > 60% | > 40% | < 40% |
| Packet Loss | < 0.1% | < 0.5% | < 1% | > 1% |
| Connection Stability | > 99.9% | > 99% | > 95% | < 95% |

## Configuration Optimization

### MTU Tuning
```bash
# Test different MTU values
for mtu in 1420 1440 1460 1480 1500; do
    echo "Testing MTU: $mtu"
    # Update WireGuard config with MTU = $mtu
    # Run performance tests
    # Record results
done
```

### Keepalive Settings
```bash
# Test different keepalive intervals
for keepalive in 15 20 25 30 60; do
    echo "Testing Keepalive: ${keepalive}s"
    # Update WireGuard config with PersistentKeepalive = $keepalive
    # Run stability tests
    # Record results
done
```

### Cryptographic Algorithms
WireGuard uses ChaCha20 for encryption and Poly1305 for authentication by default. These are optimized for performance and security.

## Troubleshooting

### Common Issues

#### 1. WireGuard Interface Not Found
```bash
# Check if WireGuard is installed
wg version

# Check if interface exists
ip link show wg0

# Start WireGuard service
sudo systemctl start wg-quick@wg0
```

#### 2. Connection Issues
```bash
# Check WireGuard status
sudo wg show

# Check routing
ip route show

# Test connectivity
ping 10.0.0.1  # From client to server
```

#### 3. Performance Issues
```bash
# Check system resources
htop
iotop
nethogs

# Check network interface
ethtool wg0

# Monitor WireGuard statistics
sudo wg show wg0 dump
```

### Debug Commands
```bash
# Enable WireGuard debugging
sudo wg-quick up wg0 --debug

# Check system logs
sudo journalctl -u wg-quick@wg0 -f

# Monitor network traffic
sudo tcpdump -i wg0 -n
```

## Results Interpretation

### Understanding Test Results

#### Latency Analysis
- **Baseline Latency**: Network latency without VPN
- **VPN Latency**: Network latency through VPN tunnel
- **Overhead**: Additional latency introduced by VPN
- **Overhead Percentage**: Relative impact of VPN on latency

#### Bandwidth Analysis
- **Baseline Bandwidth**: Network throughput without VPN
- **VPN Bandwidth**: Network throughput through VPN tunnel
- **Efficiency**: Percentage of baseline bandwidth achieved through VPN

#### Packet Loss Analysis
- **Baseline Loss**: Packet loss without VPN
- **VPN Loss**: Packet loss through VPN tunnel
- **Impact**: Additional packet loss introduced by VPN

### Performance Ratings

#### Excellent Performance
- Latency overhead < 10%
- Bandwidth efficiency > 80%
- Packet loss < 0.1%
- Suitable for production use

#### Good Performance
- Latency overhead < 25%
- Bandwidth efficiency > 60%
- Packet loss < 0.5%
- Suitable for most use cases

#### Needs Improvement
- Latency overhead > 25%
- Bandwidth efficiency < 60%
- Packet loss > 1%
- Requires optimization or alternative solutions

## Advanced Analysis

### Using the Python Analyzer
```bash
# Basic analysis
python3 tools/vpn_analyzer.py

# Analyze specific test run
python3 tools/vpn_analyzer.py --test-type 20231201_143022

# Generate analysis without charts
python3 tools/vpn_analyzer.py --no-charts

# Custom results directory
python3 tools/vpn_analyzer.py --results-dir /path/to/results
```

### Custom Test Scenarios
1. **Load Testing**: Multiple concurrent connections
2. **Stress Testing**: High bandwidth utilization
3. **Stability Testing**: Long-term connection monitoring
4. **Failover Testing**: Network interruption scenarios

## Best Practices

### Testing Best Practices
1. **Consistent Environment**: Use same hardware and network conditions
2. **Multiple Runs**: Run tests multiple times for statistical significance
3. **Documentation**: Record all configuration changes and their impact
4. **Baseline Comparison**: Always compare against baseline measurements

### Configuration Best Practices
1. **Security**: Use strong cryptographic keys
2. **Performance**: Optimize MTU and keepalive settings
3. **Monitoring**: Implement comprehensive logging and monitoring
4. **Backup**: Maintain backup configurations and recovery procedures

### Analysis Best Practices
1. **Statistical Significance**: Use sufficient sample sizes
2. **Trend Analysis**: Monitor performance over time
3. **Correlation Analysis**: Identify factors affecting performance
4. **Documentation**: Maintain detailed analysis reports

## Next Steps

### Immediate Actions
1. Run baseline tests on your current setup
2. Configure and test WireGuard VPN
3. Analyze results and identify optimization opportunities
4. Document findings and recommendations

### Future Enhancements
1. Implement automated testing for continuous monitoring
2. Develop custom test scenarios for specific use cases
3. Integrate with monitoring and alerting systems
4. Expand testing framework for other VPN protocols

### Chicago-New York Setup
1. Review the detailed plan in `plans/chicago_ny_testing_plan.md`
2. Allocate resources for cloud infrastructure
3. Set up monitoring and logging systems
4. Execute the testing plan according to the timeline

## Support and Resources

### Documentation
- [WireGuard Official Documentation](https://www.wireguard.com/)
- [WireGuard Quick Start Guide](https://www.wireguard.com/quickstart/)
- [WireGuard Configuration Examples](https://github.com/WireGuard/wireguard-examples)

### Community Resources
- [WireGuard Mailing List](https://lists.zx2c4.com/mailman/listinfo/wireguard)
- [WireGuard GitHub Repository](https://github.com/WireGuard/wireguard)
- [WireGuard Reddit Community](https://www.reddit.com/r/WireGuard/)

### Tools and Utilities
- [WireGuard Tools](https://git.zx2c4.com/wireguard-tools/)
- [WireGuard UI](https://github.com/ngoduykhanh/wireguard-ui)
- [WireGuard Easy](https://github.com/WeeJeWel/wg-easy) 