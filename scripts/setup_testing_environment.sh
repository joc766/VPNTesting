#!/bin/bash

# WireGuard VPN Performance Testing Environment Setup
# This script sets up the complete testing environment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== WireGuard VPN Performance Testing Environment Setup ===${NC}"
echo ""

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to install dependencies on macOS
install_macos_dependencies() {
    echo -e "${BLUE}Installing dependencies on macOS...${NC}"
    
    if ! command_exists brew; then
        echo -e "${RED}Homebrew not found. Please install Homebrew first:${NC}"
        echo "  /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
        exit 1
    fi
    
    echo -e "${YELLOW}Installing required packages...${NC}"
    brew install wireguard-tools iperf3 jq bc python3
    
    echo -e "${GREEN}✓ macOS dependencies installed${NC}"
}

# Function to install dependencies on Ubuntu/Debian
install_ubuntu_dependencies() {
    echo -e "${BLUE}Installing dependencies on Ubuntu/Debian...${NC}"
    
    echo -e "${YELLOW}Updating package list...${NC}"
    sudo apt update
    
    echo -e "${YELLOW}Installing required packages...${NC}"
    sudo apt install -y wireguard iperf3 jq bc python3 python3-pip
    
    echo -e "${GREEN}✓ Ubuntu/Debian dependencies installed${NC}"
}

# Function to install Python dependencies
install_python_dependencies() {
    echo -e "${BLUE}Installing Python dependencies...${NC}"
    
    if [ -f "requirements.txt" ]; then
        pip3 install -r requirements.txt
        echo -e "${GREEN}✓ Python dependencies installed${NC}"
    else
        echo -e "${YELLOW}requirements.txt not found, installing basic packages...${NC}"
        pip3 install matplotlib pandas numpy seaborn
        echo -e "${GREEN}✓ Basic Python packages installed${NC}"
    fi
}

# Function to create directories
create_directories() {
    echo -e "${BLUE}Creating directory structure...${NC}"
    
    mkdir -p results/{baseline,vpn,analysis}
    mkdir -p configs
    mkdir -p tools
    mkdir -p docs
    mkdir -p plans
    
    echo -e "${GREEN}✓ Directory structure created${NC}"
}

# Function to make scripts executable
make_scripts_executable() {
    echo -e "${BLUE}Making scripts executable...${NC}"
    
    chmod +x scripts/*.sh 2>/dev/null || true
    chmod +x tools/*.py 2>/dev/null || true
    
    echo -e "${GREEN}✓ Scripts made executable${NC}"
}

# Function to check WireGuard installation
check_wireguard() {
    echo -e "${BLUE}Checking WireGuard installation...${NC}"
    
    if command_exists wg; then
        echo -e "${GREEN}✓ WireGuard tools found${NC}"
        wg version
    else
        echo -e "${RED}✗ WireGuard tools not found${NC}"
        echo -e "${YELLOW}Please install WireGuard tools:${NC}"
        echo "  macOS: brew install wireguard-tools"
        echo "  Ubuntu: sudo apt install wireguard"
        return 1
    fi
}

# Function to check other dependencies
check_dependencies() {
    echo -e "${BLUE}Checking other dependencies...${NC}"
    
    local missing_deps=()
    
    for dep in iperf3 jq bc python3; do
        if command_exists "$dep"; then
            echo -e "${GREEN}✓ $dep found${NC}"
        else
            echo -e "${RED}✗ $dep not found${NC}"
            missing_deps+=("$dep")
        fi
    done
    
    if [ ${#missing_deps[@]} -eq 0 ]; then
        echo -e "${GREEN}✓ All dependencies found${NC}"
        return 0
    else
        echo -e "${RED}Missing dependencies: ${missing_deps[*]}${NC}"
        return 1
    fi
}

# Function to generate WireGuard keys
generate_wireguard_keys() {
    echo -e "${BLUE}Generating WireGuard keys...${NC}"
    
    local keys_dir="configs/keys"
    mkdir -p "$keys_dir"
    
    # Generate server keys
    echo -e "${YELLOW}Generating server keys...${NC}"
    wg genkey | tee "$keys_dir/server_private.key" | wg pubkey > "$keys_dir/server_public.key"
    
    # Generate client keys
    echo -e "${YELLOW}Generating client keys...${NC}"
    wg genkey | tee "$keys_dir/client_private.key" | wg pubkey > "$keys_dir/client_public.key"
    
    echo -e "${GREEN}✓ WireGuard keys generated in $keys_dir${NC}"
    echo -e "${YELLOW}Server Public Key:${NC} $(cat "$keys_dir/server_public.key")"
    echo -e "${YELLOW}Client Public Key:${NC} $(cat "$keys_dir/client_public.key")"
}

# Function to create configuration files
create_config_files() {
    echo -e "${BLUE}Creating configuration files...${NC}"
    
    if [ -f "configs/keys/server_private.key" ] && [ -f "configs/keys/client_private.key" ]; then
        # Read keys
        local server_private=$(cat configs/keys/server_private.key)
        local server_public=$(cat configs/keys/server_public.key)
        local client_private=$(cat configs/keys/client_private.key)
        local client_public=$(cat configs/keys/client_public.key)
        
        # Create server config
        cat > "configs/wg0_server.conf" <<EOF
[Interface]
PrivateKey = $server_private
Address = 10.0.0.1/24
ListenPort = 51820
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE
SaveConfig = true

[Peer]
PublicKey = $client_public
AllowedIPs = 10.0.0.2/32
EOF
        
        # Create client config template
        cat > "configs/wg0_client.conf" <<EOF
[Interface]
PrivateKey = $client_private
Address = 10.0.0.2/24
DNS = 8.8.8.8, 1.1.1.1

[Peer]
PublicKey = $server_public
Endpoint = <CHICAGO_SERVER_IP>:51820
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
EOF
        
        echo -e "${GREEN}✓ Configuration files created${NC}"
        echo -e "${YELLOW}Server config: configs/wg0_server.conf${NC}"
        echo -e "${YELLOW}Client config: configs/wg0_client.conf${NC}"
        echo -e "${YELLOW}Remember to update <CHICAGO_SERVER_IP> in the client config${NC}"
    else
        echo -e "${YELLOW}Keys not found, skipping configuration file creation${NC}"
    fi
}

# Function to run initial tests
run_initial_tests() {
    echo -e "${BLUE}Running initial baseline tests...${NC}"
    
    if [ -f "scripts/run_baseline_tests.sh" ]; then
        echo -e "${YELLOW}Running baseline tests...${NC}"
        ./scripts/run_baseline_tests.sh
        echo -e "${GREEN}✓ Initial baseline tests completed${NC}"
    else
        echo -e "${YELLOW}Baseline test script not found${NC}"
    fi
}

# Function to display next steps
display_next_steps() {
    echo ""
    echo -e "${BLUE}=== Setup Complete! ===${NC}"
    echo ""
    echo -e "${GREEN}Next steps:${NC}"
    echo ""
    echo "1. ${YELLOW}Local Network Testing:${NC}"
    echo "   - Configure WireGuard on your Raspberry Pi server"
    echo "   - Configure WireGuard client on your MacBook Pro"
    echo "   - Run: ./scripts/run_vpn_tests.sh"
    echo "   - Analyze results: ./scripts/analyze_results.sh"
    echo ""
    echo "2. ${YELLOW}Geographic Testing (Chicago-New York):${NC}"
    echo "   - Review: plans/chicago_ny_testing_plan.md"
    echo "   - Set up cloud infrastructure"
    echo "   - Deploy WireGuard server and client"
    echo "   - Run comprehensive tests"
    echo ""
    echo "3. ${YELLOW}Advanced Analysis:${NC}"
    echo "   - Use Python analyzer: python3 tools/vpn_analyzer.py"
    echo "   - Generate custom reports and visualizations"
    echo "   - Optimize configuration based on results"
    echo ""
    echo -e "${BLUE}Documentation:${NC}"
    echo "   - Testing Guide: docs/testing_guide.md"
    echo "   - Configuration Templates: configs/"
    echo "   - Analysis Tools: tools/"
    echo ""
    echo -e "${GREEN}Happy testing! 🚀${NC}"
}

# Main setup function
main() {
    echo -e "${BLUE}Starting WireGuard VPN Performance Testing Environment Setup...${NC}"
    echo ""
    
    # Detect operating system
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo -e "${YELLOW}Detected macOS${NC}"
        install_macos_dependencies
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo -e "${YELLOW}Detected Linux${NC}"
        install_ubuntu_dependencies
    else
        echo -e "${RED}Unsupported operating system: $OSTYPE${NC}"
        exit 1
    fi
    
    # Install Python dependencies
    install_python_dependencies
    
    # Create directories
    create_directories
    
    # Make scripts executable
    make_scripts_executable
    
    # Check dependencies
    if ! check_dependencies; then
        echo -e "${RED}Some dependencies are missing. Please install them and run this script again.${NC}"
        exit 1
    fi
    
    # Check WireGuard
    if ! check_wireguard; then
        echo -e "${RED}WireGuard is not properly installed. Please install it and run this script again.${NC}"
        exit 1
    fi
    
    # Generate WireGuard keys
    generate_wireguard_keys
    
    # Create configuration files
    create_config_files
    
    # Run initial tests
    run_initial_tests
    
    # Display next steps
    display_next_steps
}

# Run main function
main "$@" 