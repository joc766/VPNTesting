# Chicago-New York WireGuard VPN Testing Plan

## Overview
This document outlines the comprehensive testing plan for deploying and testing a WireGuard VPN between Chicago and New York locations, with a focus on performance analysis and optimization.

## Infrastructure Requirements

### Chicago (VPN Server)
- **Location**: Chicago, IL
- **Provider Options**:
  - AWS US-East-2 (Ohio - closest to Chicago)
  - Google Cloud us-central1 (Iowa - good latency to Chicago)
  - Azure East US 2 (Virginia - acceptable latency)
  - DigitalOcean Chicago datacenter
  - Linode Chicago datacenter

### New York (VPN Client)
- **Location**: New York, NY
- **Provider Options**:
  - AWS US-East-1 (N. Virginia - closest to NYC)
  - Google Cloud us-east1 (South Carolina - good latency to NYC)
  - Azure East US (Virginia - good latency to NYC)
  - DigitalOcean NYC datacenter
  - Linode NYC datacenter

### Recommended Setup
```
Chicago Server: AWS US-East-2 (Ohio) - t3.medium or larger
New York Client: AWS US-East-1 (N. Virginia) - t3.medium or larger
Expected Latency: ~15-25ms between locations
```

## Network Architecture

### Chicago Server Configuration
```bash
# Server Specifications
- Instance Type: t3.medium (2 vCPU, 4GB RAM)
- OS: Ubuntu 22.04 LTS
- Network: Enhanced networking enabled
- Security Groups: Allow UDP 51820 (WireGuard)
- Elastic IP: Static public IP

# WireGuard Server Setup
- Interface: wg0
- IP Range: 10.0.0.0/24
- Server IP: 10.0.0.1
- Client IPs: 10.0.0.2-254
```

### New York Client Configuration
```bash
# Client Specifications
- Instance Type: t3.medium (2 vCPU, 4GB RAM)
- OS: Ubuntu 22.04 LTS
- Network: Enhanced networking enabled
- WireGuard Client: wg0 interface
- Client IP: 10.0.0.2
```

## Testing Phases

### Phase 1: Infrastructure Setup (Week 1)
1. **Provision Cloud Resources**
   - Deploy Chicago server
   - Deploy New York client
   - Configure security groups and networking
   - Set up monitoring and logging

2. **WireGuard Installation**
   - Install WireGuard on both instances
   - Generate key pairs
   - Configure server and client
   - Test basic connectivity

3. **Baseline Network Tests**
   - Measure direct latency between instances
   - Test bandwidth without VPN
   - Document network characteristics

### Phase 2: VPN Configuration (Week 2)
1. **Basic WireGuard Setup**
   - Configure server wg0.conf
   - Configure client wg0.conf
   - Establish tunnel connection
   - Verify routing

2. **Performance Tuning**
   - Test different MTU values (1420-1500)
   - Optimize keepalive settings
   - Test different cryptographic algorithms
   - Monitor CPU and memory usage

3. **Security Configuration**
   - Implement firewall rules
   - Configure DNS over VPN
   - Set up logging and monitoring
   - Test security measures

### Phase 3: Comprehensive Testing (Week 3-4)
1. **Latency Testing**
   ```bash
   # Test scenarios
   - Direct connection (no VPN)
   - WireGuard tunnel
   - Different times of day
   - Different days of week
   - Peak vs off-peak hours
   ```

2. **Bandwidth Testing**
   ```bash
   # iperf3 tests
   - Upload speed tests
   - Download speed tests
   - Bidirectional tests
   - Different packet sizes
   - TCP vs UDP tests
   ```

3. **Stability Testing**
   ```bash
   # Long-term tests
   - 24-hour continuous ping
   - Connection stability over time
   - Reconnection behavior
   - Failover scenarios
   ```

4. **Load Testing**
   ```bash
   # Stress tests
   - Multiple concurrent connections
   - High bandwidth utilization
   - CPU and memory stress
   - Network congestion simulation
   ```

## Test Scenarios

### Scenario 1: Basic Performance
- **Duration**: 1 hour
- **Tests**: Ping, iperf3, DNS resolution
- **Metrics**: Latency, bandwidth, packet loss
- **Frequency**: 3 times per day (morning, afternoon, evening)

### Scenario 2: Extended Stability
- **Duration**: 24 hours
- **Tests**: Continuous ping, periodic bandwidth tests
- **Metrics**: Connection stability, performance consistency
- **Frequency**: Once per week

### Scenario 3: Load Testing
- **Duration**: 2 hours
- **Tests**: Multiple iperf3 sessions, concurrent connections
- **Metrics**: Throughput under load, resource utilization
- **Frequency**: Once per week

### Scenario 4: Geographic Variation
- **Duration**: 1 week
- **Tests**: Performance at different times
- **Metrics**: Peak vs off-peak performance
- **Frequency**: Continuous monitoring

## Performance Benchmarks

### Expected Performance Metrics
```
Latency (Chicago ↔ New York):
- Direct: 15-25ms
- WireGuard: 20-35ms (5-10ms overhead)

Bandwidth:
- Direct: 1-10 Gbps (depending on instance type)
- WireGuard: 80-95% of direct bandwidth

Packet Loss:
- Target: < 0.1%
- Acceptable: < 1%

Jitter:
- Target: < 5ms
- Acceptable: < 10ms
```

### Success Criteria
- **Latency Overhead**: < 10ms additional latency
- **Bandwidth**: > 80% of direct connection
- **Packet Loss**: < 0.1%
- **Uptime**: > 99.9%
- **Reconnection Time**: < 5 seconds

## Monitoring and Logging

### Metrics to Monitor
1. **Network Performance**
   - Latency (ping times)
   - Bandwidth utilization
   - Packet loss percentage
   - Jitter measurements

2. **System Performance**
   - CPU utilization
   - Memory usage
   - Disk I/O
   - Network interface statistics

3. **WireGuard Specific**
   - Interface status
   - Peer connection status
   - Handshake frequency
   - Transfer statistics

### Logging Strategy
```bash
# Log locations
/var/log/wireguard/
/var/log/syslog
/var/log/cloud-init-output.log

# Monitoring tools
- Prometheus + Grafana
- CloudWatch (AWS)
- Custom scripts for metrics collection
```

## Optimization Strategies

### Network Optimization
1. **MTU Tuning**
   - Test values: 1420, 1440, 1460, 1480, 1500
   - Use path MTU discovery
   - Monitor for fragmentation

2. **Keepalive Settings**
   - Default: 25 seconds
   - Test values: 15, 20, 30, 60 seconds
   - Balance between responsiveness and overhead

3. **Routing Optimization**
   - Use specific routes for VPN traffic
   - Implement split tunneling where appropriate
   - Optimize routing tables

### System Optimization
1. **Kernel Parameters**
   ```bash
   # /etc/sysctl.conf optimizations
   net.core.rmem_max = 134217728
   net.core.wmem_max = 134217728
   net.ipv4.tcp_rmem = 4096 87380 134217728
   net.ipv4.tcp_wmem = 4096 65536 134217728
   ```

2. **CPU Optimization**
   - Use CPU affinity for WireGuard processes
   - Enable hardware acceleration if available
   - Monitor CPU usage patterns

## Cost Estimation

### AWS Pricing (Monthly)
```
Chicago Server (t3.medium):
- Compute: ~$30/month
- Data Transfer: ~$10-50/month (depending on usage)
- Storage: ~$5/month

New York Client (t3.medium):
- Compute: ~$30/month
- Data Transfer: ~$10-50/month
- Storage: ~$5/month

Total Estimated Cost: $90-170/month
```

### Alternative Providers
- **DigitalOcean**: $24-48/month total
- **Linode**: $20-40/month total
- **Google Cloud**: $60-120/month total

## Risk Mitigation

### Technical Risks
1. **Network Congestion**
   - Monitor during peak hours
   - Implement QoS if needed
   - Consider redundant connections

2. **Instance Failures**
   - Use auto-scaling groups
   - Implement health checks
   - Set up automated recovery

3. **Security Vulnerabilities**
   - Regular security updates
   - Monitor for suspicious activity
   - Implement intrusion detection

### Operational Risks
1. **Cost Overruns**
   - Set up billing alerts
   - Monitor usage patterns
   - Implement cost controls

2. **Data Loss**
   - Regular backups
   - Test recovery procedures
   - Document configurations

## Timeline

### Week 1: Infrastructure
- Day 1-2: Provision cloud resources
- Day 3-4: Install and configure WireGuard
- Day 5: Basic connectivity testing

### Week 2: Configuration
- Day 1-2: Performance tuning
- Day 3-4: Security configuration
- Day 5: Initial performance testing

### Week 3: Testing
- Day 1-3: Comprehensive performance tests
- Day 4-5: Load and stability testing

### Week 4: Optimization
- Day 1-3: Analyze results and optimize
- Day 4-5: Final testing and documentation

## Success Metrics

### Quantitative Metrics
- Latency overhead < 10ms
- Bandwidth utilization > 80%
- Packet loss < 0.1%
- Uptime > 99.9%

### Qualitative Metrics
- Consistent performance across time periods
- Reliable connection stability
- Acceptable user experience
- Cost-effective solution

## Next Steps

1. **Immediate Actions**
   - Review and approve this plan
   - Allocate budget for cloud resources
   - Set up monitoring infrastructure

2. **Preparation**
   - Create cloud accounts if needed
   - Prepare WireGuard configurations
   - Set up testing scripts

3. **Execution**
   - Follow the timeline above
   - Document all findings
   - Adjust plan based on results

4. **Post-Testing**
   - Analyze all results
   - Create final report
   - Plan for production deployment
   - Consider scaling strategies 