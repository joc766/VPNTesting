# WireGuard VPN Performance Testing Framework

## Project Overview
This project provides a testing framework for evaluating WireGuard VPN performance across different network configurations and geographical locations.

## Current Setup
- **VPN Server**: Raspberry Pi running WireGuard service
- **VPN Client**: Programmable router (capable of being server/client endpoint)
- **Test Client**: MacBook Pro
- **Network**: Local network with port forwarding configured

## Future Setup (Chicago-New York)
- **VPN Server**: Chicago-based server
- **VPN Client**: New York-based client
- **Geographic Distance**: ~800 miles

## Project Structure
```
vpn/
├── scripts/           # Testing and automation scripts
├── configs/          # WireGuard configuration templates
├── tools/            # Performance testing utilities
├── results/          # Test results and analysis
├── docs/             # Documentation and guides
└── plans/            # Future testing plans
```

## Testing Categories
1. **Local Network Performance**
   - Same subnet testing
   - Cross-subnet testing
   - Router-to-router testing

2. **Geographic Performance** (Future)
   - Chicago-New York latency testing
   - Bandwidth analysis
   - Connection stability

3. **Configuration Optimization**
   - MTU tuning
   - Keepalive settings
   - Cryptographic algorithm performance

## Quick Start
1. Run local baseline tests: `./scripts/run_baseline_tests.sh`
2. Configure WireGuard: `./scripts/setup_wireguard.sh`
3. Run performance tests: `./scripts/run_performance_tests.sh`
4. Analyze results: `./scripts/analyze_results.sh`

## Requirements
- Python 3.8+
- iperf3
- ping
- WireGuard tools
- jq (for JSON processing) 
