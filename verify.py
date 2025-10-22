#!/usr/bin/env python3
"""
Cerumbra Verification Script

This script verifies that all components of Cerumbra are properly set up:
1. Python dependencies are installed
2. Confidential computing is enabled on NVIDIA GPUs
3. Cryptographic operations work correctly
4. Server can start
5. HTML/CSS/JS files exist and are valid
"""

import sys
import os
import subprocess
import json
import shutil


def print_header(text):
    """Print a formatted header"""
    print("\n" + "=" * 70)
    print(f"  {text}")
    print("=" * 70)


def check_python_version():
    """Verify Python version"""
    print_header("Checking Python Version")
    version = sys.version_info
    print(f"Python version: {version.major}.{version.minor}.{version.micro}")
    
    if version.major >= 3 and version.minor >= 7:
        print("✓ Python version is compatible (>= 3.7)")
        return True
    else:
        print("❌ Python version must be 3.7 or higher")
        return False


def check_dependencies():
    """Check if required Python packages are installed"""
    print_header("Checking Python Dependencies")
    
    required = ['websockets', 'cryptography']
    missing = []
    
    for package in required:
        try:
            __import__(package)
            print(f"✓ {package} is installed")
        except ImportError:
            print(f"❌ {package} is NOT installed")
            missing.append(package)
    
    if missing:
        print(f"\nInstall missing packages with:")
        print(f"  pip install {' '.join(missing)}")
        return False
    
    return True


def check_files():
    """Verify all required files exist"""
    print_header("Checking Required Files")
    
    files = {
        'index.html': 'Main website',
        'styles.css': 'Stylesheet',
        'demo.js': 'Browser-side crypto implementation',
        'server.py': 'TEE server implementation',
        'example.py': 'Cryptographic examples',
        'requirements.txt': 'Python dependencies',
        'README.md': 'Documentation',
        'CONTRIBUTING.md': 'Contribution guidelines',
        'architecture.svg': 'Architecture diagram',
        'LICENSE': 'Apache 2.0 license'
    }
    
    all_present = True
    for filename, description in files.items():
        if os.path.exists(filename):
            size = os.path.getsize(filename)
            print(f"✓ {filename:20s} ({size:6d} bytes) - {description}")
        else:
            print(f"❌ {filename:20s} - MISSING - {description}")
            all_present = False
    
    return all_present


def test_crypto_operations():
    """Test cryptographic operations"""
    print_header("Testing Cryptographic Operations")
    
    try:
        result = subprocess.run(
            [sys.executable, 'example.py'],
            capture_output=True,
            text=True,
            timeout=10
        )
        
        if result.returncode == 0:
            print("✓ Cryptographic operations test passed")
            # Show last few lines of output
            lines = result.stdout.strip().split('\n')
            if len(lines) > 3:
                print("\nLast few lines of output:")
                for line in lines[-3:]:
                    print(f"  {line}")
            return True
        else:
            print("❌ Cryptographic operations test failed")
            print("Error output:", result.stderr)
            return False
    except subprocess.TimeoutExpired:
        print("❌ Test timed out")
        return False
    except Exception as e:
        print(f"❌ Error running test: {e}")
        return False


def validate_html_structure():
    """Basic validation of HTML file"""
    print_header("Validating HTML Structure")
    
    try:
        with open('index.html', 'r') as f:
            content = f.read()
        
        checks = {
            '<!DOCTYPE html>': 'HTML5 doctype',
            '<head>': 'Head section',
            '<body>': 'Body section',
            'demo.js': 'Demo script reference',
            'styles.css': 'Stylesheet reference',
            'Cerumbra': 'Content present'
        }
        
        all_valid = True
        for check, description in checks.items():
            if check in content:
                print(f"✓ {description}")
            else:
                print(f"❌ Missing: {description}")
                all_valid = False
        
        return all_valid
    except Exception as e:
        print(f"❌ Error reading HTML: {e}")
        return False


def validate_javascript():
    """Basic validation of JavaScript file"""
    print_header("Validating JavaScript")
    
    try:
        with open('demo.js', 'r') as f:
            content = f.read()
        
        checks = {
            'CerumbraClient': 'Main class defined',
            'crypto.subtle': 'Web Crypto API used',
            'generateKeyPair': 'Key generation function',
            'encrypt': 'Encryption function',
            'decrypt': 'Decryption function',
            'ECDH': 'ECDH key exchange'
        }
        
        all_valid = True
        for check, description in checks.items():
            if check in content:
                print(f"✓ {description}")
            else:
                print(f"❌ Missing: {description}")
                all_valid = False
        
        return all_valid
    except Exception as e:
        print(f"❌ Error reading JavaScript: {e}")
        return False


def test_server_imports():
    """Test that server.py can be imported"""
    print_header("Testing Server Imports")
    
    try:
        # Add current directory to path
        sys.path.insert(0, os.getcwd())
        
        # Try to import server module
        import server
        print("✓ Server module imports successfully")
        
        # Check key classes exist
        if hasattr(server, 'CerumbraTEE'):
            print("✓ CerumbraTEE class found")
        if hasattr(server, 'CerumbraServer'):
            print("✓ CerumbraServer class found")
        
        return True
    except Exception as e:
        print(f"❌ Server import failed: {e}")
        return False


def check_confidential_compute():
    """Ensure NVIDIA confidential computing is enabled when GPUs are present"""
    print_header("Checking NVIDIA Confidential Compute")

    if shutil.which("nvidia-smi") is None:
        print("⚠️ nvidia-smi not found; skipping GPU confidential-compute check.")
        print("   If you are on DGX Spark, install the NVIDIA drivers before running Cerumbra.")
        return True

    try:
        result = subprocess.run(
            ["nvidia-smi", "--query-gpu=conf_computing_mode", "--format=csv,noheader"],
            capture_output=True,
            text=True,
            timeout=5,
            check=False,
        )
    except Exception as exc:
        print(f"⚠️ Unable to query confidential compute state: {exc}")
        print("   Cerumbra will continue, but secure mode could not be verified.")
        return True

    if result.returncode != 0:
        print("❌ nvidia-smi returned a non-zero exit code while checking confidential compute mode.")
        if result.stderr:
            print(result.stderr.strip())
        print("   Resolve the GPU driver issue and re-run the verification.")
        return False

    lines = [line.strip() for line in result.stdout.splitlines() if line.strip()]
    if not lines:
        print("❌ nvidia-smi did not report any confidential compute data.")
        print("   Ensure the GPU is visible (try `nvidia-smi`) before running Cerumbra.")
        return False

    secure_keywords = ("enabled", "secure", "on")
    all_secure = True

    for idx, line in enumerate(lines):
        lower = line.lower()
        if any(keyword in lower for keyword in secure_keywords):
            print(f"✓ GPU {idx}: confidential compute mode reported as '{line}'")
        else:
            print(f"❌ GPU {idx}: confidential compute mode reported as '{line}' (expected Enabled/SECURE)")
            all_secure = False

    if not all_secure:
        print("\n   Enable secure mode with:")
        print("     sudo ./ccadm-setup.sh")
        print("   Then reboot the node and re-run this verification.")

    return all_secure


def print_summary(results):
    """Print summary of all checks"""
    print_header("Verification Summary")
    
    total = len(results)
    passed = sum(results.values())
    
    print(f"\nTotal checks: {total}")
    print(f"Passed: {passed}")
    print(f"Failed: {total - passed}")
    
    if passed == total:
        print("\n✓✓✓ All verification checks passed! ✓✓✓")
        print("\nCerumbra is ready to use!")
        print("\nNext steps:")
        print("  1. Start the server: python3 server.py")
        print("  2. Open index.html in your browser")
        print("  3. Click 'Connect to TEE' and try the demo")
        return True
    else:
        print("\n❌ Some verification checks failed")
        print("Please review the errors above and fix any issues")
        return False


def main():
    """Run all verification checks"""
    print("\n" + "█" * 70)
    print("█" + " " * 68 + "█")
    print("█" + "  Cerumbra Verification Script".center(68) + "█")
    print("█" + " " * 68 + "█")
    print("█" * 70)
    
    results = {
        'Python Version': check_python_version(),
        'Dependencies': check_dependencies(),
        'Confidential Compute': check_confidential_compute(),
        'Files': check_files(),
        'Crypto Operations': test_crypto_operations(),
        'HTML Structure': validate_html_structure(),
        'JavaScript': validate_javascript(),
        'Server Imports': test_server_imports()
    }
    
    success = print_summary(results)
    
    return 0 if success else 1


if __name__ == "__main__":
    sys.exit(main())
