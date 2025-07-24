#!/usr/bin/env python3
"""
WireGuard VPN Performance Analyzer
A comprehensive tool for analyzing VPN performance test results
"""

import json
import os
import sys
import argparse
import matplotlib.pyplot as plt
import pandas as pd
import numpy as np
from datetime import datetime
from pathlib import Path
import seaborn as sns

class VPNAnalyzer:
    def __init__(self, results_dir="../results"):
        self.results_dir = Path(results_dir)
        self.baseline_dir = self.results_dir / "baseline"
        self.vpn_dir = self.results_dir / "vpn"
        self.analysis_dir = self.results_dir / "analysis"
        
        # Create directories if they don't exist
        self.analysis_dir.mkdir(parents=True, exist_ok=True)
        
        # Set up plotting style
        plt.style.use('seaborn-v0_8')
        sns.set_palette("husl")
        
    def load_test_data(self, test_type="latest"):
        """Load test data from JSON files"""
        data = {
            'baseline': {},
            'vpn': {}
        }
        
        # Load baseline data
        if self.baseline_dir.exists():
            for file_path in self.baseline_dir.glob(f"*_{test_type}.txt"):
                test_name = file_path.stem.replace(f"_{test_type}", "")
                try:
                    with open(file_path, 'r') as f:
                        content = f.read().strip()
                        if content:
                            data['baseline'][test_name] = json.loads(content)
                except (json.JSONDecodeError, FileNotFoundError) as e:
                    print(f"Warning: Could not load {file_path}: {e}")
        
        # Load VPN data
        if self.vpn_dir.exists():
            for file_path in self.vpn_dir.glob(f"*_{test_type}.txt"):
                test_name = file_path.stem.replace(f"_{test_type}", "")
                try:
                    with open(file_path, 'r') as f:
                        content = f.read().strip()
                        if content:
                            data['vpn'][test_name] = json.loads(content)
                except (json.JSONDecodeError, FileNotFoundError) as e:
                    print(f"Warning: Could not load {file_path}: {e}")
        
        return data
    
    def analyze_latency(self, data):
        """Analyze latency performance"""
        results = {}
        
        # Find matching ping tests
        baseline_ping = {k: v for k, v in data['baseline'].items() if k.startswith('ping_')}
        vpn_ping = {k: v for k, v in data['vpn'].items() if k.startswith('ping_')}
        
        for test_name in baseline_ping:
            if test_name in vpn_ping:
                baseline = baseline_ping[test_name]
                vpn = vpn_ping[test_name]
                
                # Calculate overhead
                overhead_ms = vpn['avg_ping_ms'] - baseline['avg_ping_ms']
                overhead_percent = (overhead_ms / baseline['avg_ping_ms']) * 100
                
                results[test_name] = {
                    'baseline_avg': baseline['avg_ping_ms'],
                    'vpn_avg': vpn['avg_ping_ms'],
                    'overhead_ms': overhead_ms,
                    'overhead_percent': overhead_percent,
                    'baseline_min': baseline['min_ping_ms'],
                    'baseline_max': baseline['max_ping_ms'],
                    'vpn_min': vpn['min_ping_ms'],
                    'vpn_max': vpn['max_ping_ms'],
                    'baseline_loss': baseline['packet_loss_percent'],
                    'vpn_loss': vpn['packet_loss_percent']
                }
        
        return results
    
    def analyze_bandwidth(self, data):
        """Analyze bandwidth performance"""
        results = {}
        
        # Find matching iperf tests
        baseline_iperf = {k: v for k, v in data['baseline'].items() if k.startswith('iperf_')}
        vpn_iperf = {k: v for k, v in data['vpn'].items() if k.startswith('iperf_')}
        
        for test_name in baseline_iperf:
            if test_name in vpn_iperf:
                baseline = baseline_iperf[test_name]
                vpn = vpn_iperf[test_name]
                
                # Calculate bandwidth ratio
                bandwidth_ratio = vpn['bandwidth_mbps'] / baseline['bandwidth_mbps']
                bandwidth_loss_percent = (1 - bandwidth_ratio) * 100
                
                results[test_name] = {
                    'baseline_mbps': baseline['bandwidth_mbps'],
                    'vpn_mbps': vpn['bandwidth_mbps'],
                    'bandwidth_ratio': bandwidth_ratio,
                    'bandwidth_loss_percent': bandwidth_loss_percent,
                    'direction': baseline.get('direction', 'unknown')
                }
        
        return results
    
    def generate_latency_chart(self, latency_data):
        """Generate latency comparison chart"""
        if not latency_data:
            print("No latency data available for charting")
            return
        
        fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(15, 6))
        
        # Prepare data for plotting
        test_names = []
        baseline_avgs = []
        vpn_avgs = []
        overheads = []
        
        for test_name, data in latency_data.items():
            test_names.append(test_name.replace('ping_', '').replace('_', ' ').title())
            baseline_avgs.append(data['baseline_avg'])
            vpn_avgs.append(data['vpn_avg'])
            overheads.append(data['overhead_ms'])
        
        # Latency comparison chart
        x = np.arange(len(test_names))
        width = 0.35
        
        ax1.bar(x - width/2, baseline_avgs, width, label='Baseline', alpha=0.8)
        ax1.bar(x + width/2, vpn_avgs, width, label='VPN', alpha=0.8)
        
        ax1.set_xlabel('Test Target')
        ax1.set_ylabel('Latency (ms)')
        ax1.set_title('Latency Comparison: Baseline vs VPN')
        ax1.set_xticks(x)
        ax1.set_xticklabels(test_names, rotation=45)
        ax1.legend()
        ax1.grid(True, alpha=0.3)
        
        # Overhead chart
        colors = ['green' if x < 10 else 'orange' if x < 25 else 'red' for x in overheads]
        ax2.bar(test_names, overheads, color=colors, alpha=0.8)
        ax2.set_xlabel('Test Target')
        ax2.set_ylabel('Overhead (ms)')
        ax2.set_title('VPN Latency Overhead')
        ax2.tick_params(axis='x', rotation=45)
        ax2.grid(True, alpha=0.3)
        
        # Add threshold lines
        ax2.axhline(y=10, color='green', linestyle='--', alpha=0.7, label='Excellent (<10ms)')
        ax2.axhline(y=25, color='orange', linestyle='--', alpha=0.7, label='Good (<25ms)')
        
        plt.tight_layout()
        
        # Save chart
        chart_path = self.analysis_dir / f"latency_analysis_{datetime.now().strftime('%Y%m%d_%H%M%S')}.png"
        plt.savefig(chart_path, dpi=300, bbox_inches='tight')
        print(f"Latency chart saved: {chart_path}")
        
        plt.show()
    
    def generate_bandwidth_chart(self, bandwidth_data):
        """Generate bandwidth comparison chart"""
        if not bandwidth_data:
            print("No bandwidth data available for charting")
            return
        
        fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(15, 6))
        
        # Prepare data for plotting
        test_names = []
        baseline_mbps = []
        vpn_mbps = []
        ratios = []
        
        for test_name, data in bandwidth_data.items():
            test_names.append(test_name.replace('iperf_', '').replace('_', ' ').title())
            baseline_mbps.append(data['baseline_mbps'])
            vpn_mbps.append(data['vpn_mbps'])
            ratios.append(data['bandwidth_ratio'] * 100)
        
        # Bandwidth comparison chart
        x = np.arange(len(test_names))
        width = 0.35
        
        ax1.bar(x - width/2, baseline_mbps, width, label='Baseline', alpha=0.8)
        ax1.bar(x + width/2, vpn_mbps, width, label='VPN', alpha=0.8)
        
        ax1.set_xlabel('Test Type')
        ax1.set_ylabel('Bandwidth (Mbps)')
        ax1.set_title('Bandwidth Comparison: Baseline vs VPN')
        ax1.set_xticks(x)
        ax1.set_xticklabels(test_names, rotation=45)
        ax1.legend()
        ax1.grid(True, alpha=0.3)
        
        # Bandwidth ratio chart
        colors = ['green' if x > 80 else 'orange' if x > 60 else 'red' for x in ratios]
        ax2.bar(test_names, ratios, color=colors, alpha=0.8)
        ax2.set_xlabel('Test Type')
        ax2.set_ylabel('VPN/Baseline Ratio (%)')
        ax2.set_title('VPN Bandwidth Efficiency')
        ax2.tick_params(axis='x', rotation=45)
        ax2.grid(True, alpha=0.3)
        
        # Add threshold lines
        ax2.axhline(y=80, color='green', linestyle='--', alpha=0.7, label='Excellent (>80%)')
        ax2.axhline(y=60, color='orange', linestyle='--', alpha=0.7, label='Good (>60%)')
        
        plt.tight_layout()
        
        # Save chart
        chart_path = self.analysis_dir / f"bandwidth_analysis_{datetime.now().strftime('%Y%m%d_%H%M%S')}.png"
        plt.savefig(chart_path, dpi=300, bbox_inches='tight')
        print(f"Bandwidth chart saved: {chart_path}")
        
        plt.show()
    
    def generate_summary_report(self, latency_data, bandwidth_data):
        """Generate comprehensive summary report"""
        report_path = self.analysis_dir / f"comprehensive_report_{datetime.now().strftime('%Y%m%d_%H%M%S')}.txt"
        
        with open(report_path, 'w') as f:
            f.write("WireGuard VPN Performance Analysis Report\n")
            f.write("=" * 50 + "\n")
            f.write(f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n\n")
            
            # Latency Analysis
            f.write("LATENCY ANALYSIS\n")
            f.write("-" * 20 + "\n")
            if latency_data:
                for test_name, data in latency_data.items():
                    f.write(f"\n{test_name.replace('ping_', '').replace('_', ' ').title()}:\n")
                    f.write(f"  Baseline Average: {data['baseline_avg']:.2f}ms\n")
                    f.write(f"  VPN Average: {data['vpn_avg']:.2f}ms\n")
                    f.write(f"  Overhead: +{data['overhead_ms']:.2f}ms (+{data['overhead_percent']:.1f}%)\n")
                    
                    # Performance rating
                    if data['overhead_percent'] < 10:
                        rating = "EXCELLENT"
                    elif data['overhead_percent'] < 25:
                        rating = "GOOD"
                    else:
                        rating = "NEEDS IMPROVEMENT"
                    f.write(f"  Rating: {rating}\n")
            else:
                f.write("No latency data available\n")
            
            # Bandwidth Analysis
            f.write("\n\nBANDWIDTH ANALYSIS\n")
            f.write("-" * 20 + "\n")
            if bandwidth_data:
                for test_name, data in bandwidth_data.items():
                    f.write(f"\n{test_name.replace('iperf_', '').replace('_', ' ').title()}:\n")
                    f.write(f"  Baseline: {data['baseline_mbps']:.2f} Mbps\n")
                    f.write(f"  VPN: {data['vpn_mbps']:.2f} Mbps\n")
                    f.write(f"  Efficiency: {data['bandwidth_ratio']*100:.1f}%\n")
                    
                    # Performance rating
                    if data['bandwidth_ratio'] > 0.8:
                        rating = "EXCELLENT"
                    elif data['bandwidth_ratio'] > 0.6:
                        rating = "GOOD"
                    else:
                        rating = "NEEDS IMPROVEMENT"
                    f.write(f"  Rating: {rating}\n")
            else:
                f.write("No bandwidth data available\n")
            
            # Overall Assessment
            f.write("\n\nOVERALL ASSESSMENT\n")
            f.write("-" * 20 + "\n")
            
            if latency_data and bandwidth_data:
                avg_latency_overhead = np.mean([d['overhead_percent'] for d in latency_data.values()])
                avg_bandwidth_efficiency = np.mean([d['bandwidth_ratio'] for d in bandwidth_data.values()])
                
                f.write(f"Average Latency Overhead: {avg_latency_overhead:.1f}%\n")
                f.write(f"Average Bandwidth Efficiency: {avg_bandwidth_efficiency*100:.1f}%\n")
                
                if avg_latency_overhead < 10 and avg_bandwidth_efficiency > 0.8:
                    overall_rating = "EXCELLENT"
                elif avg_latency_overhead < 25 and avg_bandwidth_efficiency > 0.6:
                    overall_rating = "GOOD"
                else:
                    overall_rating = "NEEDS IMPROVEMENT"
                
                f.write(f"Overall Rating: {overall_rating}\n")
            else:
                f.write("Insufficient data for overall assessment\n")
        
        print(f"Comprehensive report saved: {report_path}")
    
    def run_analysis(self, test_type="latest", generate_charts=True):
        """Run complete analysis"""
        print("Loading test data...")
        data = self.load_test_data(test_type)
        
        print("Analyzing latency performance...")
        latency_data = self.analyze_latency(data)
        
        print("Analyzing bandwidth performance...")
        bandwidth_data = self.analyze_bandwidth(data)
        
        if generate_charts:
            print("Generating charts...")
            if latency_data:
                self.generate_latency_chart(latency_data)
            if bandwidth_data:
                self.generate_bandwidth_chart(bandwidth_data)
        
        print("Generating summary report...")
        self.generate_summary_report(latency_data, bandwidth_data)
        
        print("Analysis complete!")
        return {
            'latency': latency_data,
            'bandwidth': bandwidth_data
        }

def main():
    parser = argparse.ArgumentParser(description='WireGuard VPN Performance Analyzer')
    parser.add_argument('--results-dir', default='../results', help='Results directory path')
    parser.add_argument('--test-type', default='latest', help='Test type to analyze (latest or timestamp)')
    parser.add_argument('--no-charts', action='store_true', help='Skip chart generation')
    
    args = parser.parse_args()
    
    analyzer = VPNAnalyzer(args.results_dir)
    results = analyzer.run_analysis(args.test_type, not args.no_charts)
    
    # Print quick summary
    if results['latency']:
        print(f"\nLatency Analysis: {len(results['latency'])} tests analyzed")
    if results['bandwidth']:
        print(f"Bandwidth Analysis: {len(results['bandwidth'])} tests analyzed")

if __name__ == "__main__":
    main() 