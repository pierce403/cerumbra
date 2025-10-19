#!/bin/bash
# Cerumbra Quick Start Script
# This script helps you get Cerumbra up and running quickly

set -e

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                                                                ║"
echo "║                    🔐 Cerumbra Quick Start                     ║"
echo "║                                                                ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Check if Python is available
if ! command -v python3 &> /dev/null; then
    echo "❌ Error: Python 3 is not installed"
    echo "Please install Python 3.7 or higher"
    exit 1
fi

echo "✓ Python 3 found: $(python3 --version)"
echo ""

# Install dependencies
echo "📦 Installing Python dependencies..."
pip install -q -r requirements.txt
echo "✓ Dependencies installed"
echo ""

# Run verification
echo "🔍 Running verification checks..."
if python3 verify.py; then
    echo ""
    echo "════════════════════════════════════════════════════════════════"
    echo ""
    echo "🚀 Starting Cerumbra TEE Server..."
    echo ""
    echo "The server will start on ws://localhost:8765"
    echo "Open index.html in your browser to use the demo"
    echo ""
    echo "Press Ctrl+C to stop the server"
    echo ""
    echo "════════════════════════════════════════════════════════════════"
    echo ""
    
    # Start the server
    python3 server.py
else
    echo ""
    echo "❌ Verification failed. Please check the errors above."
    exit 1
fi
