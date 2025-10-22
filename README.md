# Cerumbra 🔐

**End-to-End Encrypted Conversations with GPUs**

Cerumbra is a protocol and implementation for private, secure AI inference using browser-to-TEE (Trusted Execution Environment) encryption. It enables completely private conversations with GPU-accelerated AI models running in NVIDIA Blackwell TEEs, ensuring your prompts and responses remain encrypted throughout the entire inference process.
The reference deployment targets NVIDIA DGX Spark systems and defaults to the `gpt-oss-20b` open model for shielded inference.

## 🌟 Features

- **🔒 End-to-End Encryption**: Data encrypted from browser to GPU TEE using AES-256-GCM
- **✓ Remote Attestation**: Cryptographically verify TEE authenticity before sharing data
- **⚡ GPU Acceleration**: Leverage NVIDIA Blackwell TEE for high-performance encrypted inference
- **🔑 ECDH Key Exchange**: Secure key establishment with forward secrecy
- **🌊 Streaming Responses**: Low-latency streaming of encrypted inference results
- **🌐 Decentralized Ready**: Foundation for the decentralized Cerumbra Network

## 🏗️ Architecture

Cerumbra implements a secure communication protocol between web browsers and GPU TEEs:

1. **Browser Client**: Generates ephemeral ECDH key pair using Web Crypto API
2. **TEE Attestation**: GPU TEE provides cryptographic proof of authenticity
3. **Key Exchange**: ECDH establishes shared secret, HKDF derives encryption keys
4. **Encrypted Inference**: Prompts encrypted in browser, decrypted in TEE, responses encrypted before streaming back

### Technology Stack

- **Browser**: Web Crypto API (ECDH P-256, AES-GCM, HKDF)
- **TEE**: NVIDIA Blackwell Trusted Execution Environment (simulated in demo)
- **Transport**: WebSocket for real-time bidirectional communication
- **Server**: Python with cryptography library

## 🚀 Quick Start

### Prerequisites

- Python 3.7 or higher
- Modern web browser with Web Crypto API support
- pip (Python package manager)

### Installation

1. Clone the repository:
```bash
git clone https://github.com/pierce403/cerumbra.git
cd cerumbra
```

2. Install Python dependencies:
```bash
pip install websockets cryptography
```

### Running the Demo

1. Start the simulated TEE server:
```bash
python3 server.py
```

You should see:
```
============================================================
Cerumbra TEE Server (Simulated)
============================================================
Starting server on ws://localhost:8765
Waiting for browser connections...
```

2. Open `index.html` in your web browser:
```bash
# On macOS:
open index.html

# On Linux:
xdg-open index.html

# Or simply open the file in your browser
```

3. Click "Connect to TEE" and follow the demo to experience:
   - Key pair generation
   - Attestation verification
   - ECDH key exchange
   - Encrypted inference

### DGX Spark Launcher Scripts

For day-to-day use on a DGX Spark, the repo now includes launchers that wire up the simulated shielded inference stack:

- `./cerumbra-server.sh`  
  Creates (or reuses) a virtual environment at `.cerumbra-venv` (override with `CERUMBRA_VENV_DIR`), installs Python dependencies (bootstrapping with `CERUMBRA_PYTHON_BIN` if provided), runs the Cerumbra verification suite, and performs a NVIDIA Blackwell + confidential-compute preflight before starting `server.py`. If the host is missing a Blackwell GPU or confidential computing is disabled, the launcher drops into an explicit simulation mode and prints remediation steps. By default it binds to `0.0.0.0:8765`; override via `CERUMBRA_SERVER_HOST` and `CERUMBRA_SERVER_PORT` or `--host/--port`. The launcher exports `CERUMBRA_MODEL_ID`, which defaults to `gpt-oss-20b`; set this variable to swap in a different model id.
  If confidential computing is still disabled, run `sudo ./ccadm-setup.sh` on the DGX Spark node to switch the GPU into SECURE mode and reboot. The helper bootstraps NVIDIA's CUDA and confidential-computing apt repositories (via `cuda-keyring`), normalizes legacy `Signed-By` directives, disables duplicate entries, and installs `nvidia-ccadm` automatically (falling back to direct package downloads) before enabling secure mode. Repository checks look for the `InRelease`/`Release` metadata files (URLs end with `.../Release`, no trailing slash). If anything fails, the script prints a link to the official NVIDIA documentation for manual remediation.
- `./cerumbra-client.sh`  
  Serves the static web client with `python -m http.server` (bind/port configurable through `CERUMBRA_CLIENT_BIND` and `CERUMBRA_CLIENT_PORT`, defaulting to `0.0.0.0:8080`). Set `CERUMBRA_SERVER_URL` or append `?server=ws://host:port` to the browser URL so the UI points at your DGX Spark backend.

The intent is to run the server launcher directly on the DGX Spark node and point browser clients at it, but you can run both scripts on the same workstation for local development.

## 📖 How It Works

### 1. Key Generation

The browser generates an ephemeral ECDH key pair:

```javascript
const keyPair = await crypto.subtle.generateKey(
    { name: "ECDH", namedCurve: "P-256" },
    true,
    ["deriveKey", "deriveBits"]
);
```

### 2. Attestation

The TEE provides a cryptographic attestation quote proving its authenticity:

```python
def generate_attestation(self, nonce: bytes) -> Dict:
    quote = {
        "measurements": self.state.measurements,  # PCR values
        "nonce": base64.b64encode(nonce).decode(),
        "teePublicKey": jwk
    }
    signature = self._sign_quote(quote)
    return {"quote": quote, "signature": signature, "certChain": ...}
```

### 3. Key Exchange

ECDH key exchange establishes a shared secret:

```javascript
const sharedSecret = await crypto.subtle.deriveBits(
    { name: "ECDH", public: teePublicKey },
    keyPair.privateKey,
    256
);

// Derive encryption key using HKDF
const encryptionKey = await deriveKey(sharedSecret, "cerumbra-v1");
```

### 4. Encrypted Inference

Prompts are encrypted before sending:

```javascript
const iv = crypto.getRandomValues(new Uint8Array(12));
const encrypted = await crypto.subtle.encrypt(
    { name: "AES-GCM", iv },
    encryptionKey,
    encoder.encode(prompt)
);
```

## 🔐 Security Model

### Security Guarantees

- **Forward Secrecy**: Ephemeral keys ensure past communications remain secure
- **Authenticated Encryption**: AES-GCM provides confidentiality and authenticity
- **TEE Protection**: Hardware-isolated execution with memory encryption
- **Remote Attestation**: Cryptographic proof of TEE authenticity

### Threat Model

**Protected Against:**
- Network eavesdropping
- Malicious server operators
- Cloud infrastructure providers
- Man-in-the-middle attacks (with proper attestation verification)

**Assumptions:**
- TEE hardware is trustworthy
- Attestation infrastructure is trustworthy
- Client browser implements Web Crypto API correctly

**Out of Scope:**
- Physical attacks on TEE hardware
- Side-channel attacks on TEE
- Compromised client endpoints

## 📁 Project Structure

```
cerumbra/
├── index.html          # Main website and documentation
├── styles.css          # Website styling
├── demo.js             # Browser-side cryptographic implementation
├── server.py           # Simulated TEE server
├── README.md           # This file
├── LICENSE             # Apache 2.0 license
└── .gitignore         # Git ignore rules
```

## 🧪 Development

### Browser-Side Development

The browser implementation is pure JavaScript using Web Crypto API. Key files:

- `demo.js`: Contains `CerumbraClient` class implementing:
  - Key generation
  - Attestation verification
  - ECDH key exchange
  - AES-GCM encryption/decryption

### Server-Side Development

The server is Python-based using:
- `websockets`: WebSocket server
- `cryptography`: ECDH, HKDF, AES-GCM implementations

Key class: `CerumbraTEE` in `server.py`

### Testing Locally

1. Start server: `python3 server.py`
2. Open browser console (F12)
3. Watch protocol logs for cryptographic operations
4. Verify encryption/decryption in console

## 🌐 Cerumbra Network

This implementation serves as the foundation for the decentralized Cerumbra Network:

### Roadmap

- **Phase 1** (Current): Protocol specification and demo
- **Phase 2**: Production TEE integration (NVIDIA Blackwell)
- **Phase 3**: Network protocol and node discovery
- **Phase 4**: Tokenomics and incentive mechanism
- **Phase 5**: Multi-model support and governance

### Network Features (Planned)

- Decentralized node network
- Automatic node discovery
- Reputation and staking system
- Multi-model marketplace
- Privacy-preserving payments

## 🤝 Contributing

Contributions are welcome! Areas of interest:

1. Production TEE integration
2. Additional cryptographic protocols
3. Performance optimizations
4. Security audits
5. Documentation improvements

## 📄 License

Copyright 2025 Cerumbra

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

## 🔗 Resources

- [Web Crypto API Documentation](https://developer.mozilla.org/en-US/docs/Web/API/Web_Crypto_API)
- [NVIDIA Confidential Computing](https://www.nvidia.com/en-us/data-center/solutions/confidential-computing/)
- [ECDH Key Exchange](https://en.wikipedia.org/wiki/Elliptic-curve_Diffie%E2%80%93Hellman)
- [AES-GCM Encryption](https://en.wikipedia.org/wiki/Galois/Counter_Mode)
- [Remote Attestation](https://en.wikipedia.org/wiki/Trusted_Computing#Remote_attestation)

## 💬 Contact

For questions, issues, or contributions, please open an issue on GitHub.

---

**Building the future of private AI inference** 🚀
