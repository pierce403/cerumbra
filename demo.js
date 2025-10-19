// Cerumbra Demo - Browser-side Cryptographic Implementation
// Simulates the DGX Spark attestation + key provisioning flow captured in the design brief

class CerumbraClient {
    constructor() {
        this.keyPair = null;
        this.teePublicKey = null;
        this.encryptionKey = null;
        this.ws = null;
        this.nonce = null;
        this.sessionId = null;
    }

    // Generate browser-side ECDH key pair
    async generateKeyPair() {
        this.keyPair = await crypto.subtle.generateKey(
            {
                name: "ECDH",
                namedCurve: "P-256"
            },
            true,
            ["deriveKey", "deriveBits"]
        );
        
        return this.keyPair;
    }

    // Export public key in JWK format
    async exportPublicKey() {
        return await crypto.subtle.exportKey("jwk", this.keyPair.publicKey);
    }

    // Generate random nonce for attestation
    generateNonce() {
        this.nonce = crypto.getRandomValues(new Uint8Array(32));
        return this.nonce;
    }

    // Import TEE public key from JWK
    async importTEEPublicKey(jwk) {
        this.teePublicKey = await crypto.subtle.importKey(
            "jwk",
            jwk,
            {
                name: "ECDH",
                namedCurve: "P-256"
            },
            true,
            []
        );
        return this.teePublicKey;
    }

    // Perform ECDH key exchange and derive encryption key
    async deriveSharedKey() {
        // Derive bits from ECDH
        const sharedBits = await crypto.subtle.deriveBits(
            {
                name: "ECDH",
                public: this.teePublicKey
            },
            this.keyPair.privateKey,
            256
        );

        // Use HKDF to derive actual encryption key
        const hkdfKey = await crypto.subtle.importKey(
            "raw",
            sharedBits,
            "HKDF",
            false,
            ["deriveKey"]
        );

        this.encryptionKey = await crypto.subtle.deriveKey(
            {
                name: "HKDF",
                hash: "SHA-256",
                salt: new Uint8Array(32), // In production, use proper salt
                info: new TextEncoder().encode("cerumbra-v1-encryption")
            },
            hkdfKey,
            {
                name: "AES-GCM",
                length: 256
            },
            false,
            ["encrypt", "decrypt"]
        );

        return this.encryptionKey;
    }

    // Encrypt data with AES-GCM
    async encrypt(data) {
        const iv = crypto.getRandomValues(new Uint8Array(12));
        const encoded = new TextEncoder().encode(data);
        
        const encrypted = await crypto.subtle.encrypt(
            {
                name: "AES-GCM",
                iv: iv
            },
            this.encryptionKey,
            encoded
        );

        return {
            iv: Array.from(iv),
            data: Array.from(new Uint8Array(encrypted))
        };
    }

    // Decrypt data with AES-GCM
    async decrypt(encryptedData) {
        const iv = new Uint8Array(encryptedData.iv);
        const data = new Uint8Array(encryptedData.data);

        const decrypted = await crypto.subtle.decrypt(
            {
                name: "AES-GCM",
                iv: iv
            },
            this.encryptionKey,
            data
        );

        return new TextDecoder().decode(decrypted);
    }

    // Simulate attestation verification (simplified for demo)
    async verifyAttestation(attestation) {
        // In production, this would:
        // 1. Verify certificate chain
        // 2. Check signatures
        // 3. Verify measurements
        // 4. Validate nonce freshness
        
        // For demo, we just check nonce matches
        const receivedNonce = new Uint8Array(attestation.nonce);
        const matches = this.nonce.every((byte, i) => byte === receivedNonce[i]);
        
        if (!matches) {
            throw new Error("Nonce mismatch in attestation");
        }
        
        return true;
    }

    // Connect to simulated TEE server
    async connect(serverUrl) {
        return new Promise((resolve, reject) => {
            this.ws = new WebSocket(serverUrl);
            
            this.ws.onopen = () => {
                addLog("WebSocket connection established", "success");
                resolve();
            };
            
            this.ws.onerror = (error) => {
                addLog("WebSocket error: " + error, "error");
                reject(error);
            };
            
            this.ws.onclose = () => {
                addLog("WebSocket connection closed", "info");
                updateStatus("Not Connected", "disconnected");
            };
        });
    }

    // Send message over WebSocket
    send(message) {
        if (this.ws && this.ws.readyState === WebSocket.OPEN) {
            this.ws.send(JSON.stringify(message));
        }
    }

    // Set message handler
    onMessage(handler) {
        if (this.ws) {
            this.ws.onmessage = (event) => {
                const message = JSON.parse(event.data);
                handler(message);
            };
        }
    }
}

// Demo UI State
let client = null;
let isConnected = false;

// Initialize demo when page loads
document.addEventListener('DOMContentLoaded', () => {
    const connectBtn = document.getElementById('connect-btn');
    const sendBtn = document.getElementById('send-btn');
    const chatInput = document.getElementById('chat-input');

    connectBtn.addEventListener('click', handleConnect);
    sendBtn.addEventListener('click', handleSend);
    chatInput.addEventListener('keypress', (e) => {
        if (e.key === 'Enter' && !sendBtn.disabled) {
            handleSend();
        }
    });

    addLog("Cerumbra DGX Spark demo ready. Click 'Connect to TEE' to begin.", "info");
    addLog("Note: This demo targets the DGX Spark Blackwell confidential computing stack only.", "info");
});

// Handle connection to simulated TEE
async function handleConnect() {
    const connectBtn = document.getElementById('connect-btn');
    const sendBtn = document.getElementById('send-btn');
    const chatInput = document.getElementById('chat-input');

    try {
        connectBtn.disabled = true;
        updateStatus("Connecting...", "connecting");
        addLog("Initializing Cerumbra client...", "info");

        // Initialize client
        client = new CerumbraClient();

        // Generate browser key pair
        addLog("Generating browser ECDH key pair for DGX Spark session...", "info");
        await client.generateKeyPair();
        const publicKeyJwk = await client.exportPublicKey();
        updateCryptoField('browser-pubkey', JSON.stringify(publicKeyJwk).substring(0, 60) + '...');
        addLog("✓ Browser key pair generated", "success");

        // Generate attestation nonce
        const nonce = client.generateNonce();
        addLog("Generated attestation nonce: " + arrayToHex(nonce).substring(0, 16) + "...", "info");
        addLog("Calling DGX Spark `/attest` endpoint with nonce challenge (simulated GET /attest?nonce=…)", "info");

        // For demo purposes, simulate TEE connection
        // In production, this would connect to actual TEE server
        await simulateTEEConnection(client, publicKeyJwk, nonce);

        updateStatus("Connected & Encrypted", "connected");
        isConnected = true;
        sendBtn.disabled = false;
        chatInput.disabled = false;
        connectBtn.textContent = "Connected";
        addLog("✓ Secure channel established with DGX Spark Blackwell TEE", "success");
        addLog("Ready for encrypted inference on DGX Spark!", "success");

    } catch (error) {
        addLog("Connection failed: " + error.message, "error");
        updateStatus("Connection Failed", "disconnected");
        connectBtn.disabled = false;
        connectBtn.textContent = "Retry Connection";
    }
}

// Simulate DGX Spark attestation flow and key exchange
async function simulateTEEConnection(client, browserPublicKey, nonce) {
    addLog("DGX Spark node returning NRAS-signed attestation bundle + ephemeral GPU ECDH key bound to your nonce...", "info");
    
    // Simulate TEE generating its own key pair
    const teeKeyPair = await crypto.subtle.generateKey(
        {
            name: "ECDH",
            namedCurve: "P-256"
        },
        true,
        ["deriveKey", "deriveBits"]
    );
    
    const teePublicKeyJwk = await crypto.subtle.exportKey("jwk", teeKeyPair.publicKey);
    
    // Simulate attestation response
    const attestation = {
        type: "attestation_response",
        nonce: Array.from(nonce),
        quote: {
            measurements: "simulated_pcr_values",
            signature: "simulated_signature"
        },
        certChain: ["simulated_cert_chain"],
        teePublicKey: teePublicKeyJwk
    };
    
    addLog("Received DGX Spark attestation material", "info");
    addLog("Verifying NRAS attestation (simulated coordinator check)...", "info");
    
    // Verify attestation
    await client.verifyAttestation(attestation);
    updateCryptoField('attestation-status', '✓ Verified');
    addLog("✓ Attestation verified successfully (NRAS trust chain)", "success");
    
    // Import TEE public key
    await client.importTEEPublicKey(teePublicKeyJwk);
    updateCryptoField('tee-pubkey', JSON.stringify(teePublicKeyJwk).substring(0, 60) + '...');
    addLog("✓ DGX Spark GPU public key imported", "success");
    
    // Derive shared encryption key
    addLog("Performing ECDH key exchange bound to attested DGX Spark session...", "info");
    await client.deriveSharedKey();
    updateCryptoField('shared-secret', '✓ Established (256-bit AES-GCM)');
    addLog("✓ Shared secret derived", "success");
    addLog("✓ Encryption key derived using HKDF", "success");
    
    // Store TEE key pair for simulation
    client.teeKeyPair = teeKeyPair;
}

// Handle sending encrypted message
async function handleSend() {
    const chatInput = document.getElementById('chat-input');
    const prompt = chatInput.value.trim();
    
    if (!prompt) return;
    
    try {
        // Add user message to chat
        addMessage(prompt, 'user');
        chatInput.value = '';
        
        addLog("Encrypting prompt with DGX Spark session key (AES-256-GCM)...", "info");
        
        // Encrypt the prompt
        const encrypted = await client.encrypt(prompt);
        addLog("✓ Prompt encrypted (" + encrypted.data.length + " bytes)", "success");
        
        // Simulate sending to TEE and getting response
        addLog("Sending encrypted prompt to DGX Spark enclave...", "info");
        await simulateEncryptedInference(client, encrypted, prompt);
        
    } catch (error) {
        addLog("Error: " + error.message, "error");
        addMessage("Error processing request: " + error.message, 'system');
    }
}

// Simulate encrypted inference in TEE
async function simulateEncryptedInference(client, encryptedPrompt, originalPrompt) {
    // Simulate network delay
    await new Promise(resolve => setTimeout(resolve, 500));
    
    addLog("DGX Spark TEE received encrypted prompt", "info");
    addLog("DGX Spark TEE decrypting with shared key...", "info");
    
    // Simulate TEE decrypting (in reality, this happens server-side)
    await new Promise(resolve => setTimeout(resolve, 300));
    addLog("✓ DGX Spark TEE decrypted prompt", "success");
    
    // Simulate inference
    addLog("Running inference inside the attested DGX Spark TEE...", "info");
    const response = generateMockResponse(originalPrompt);
    
    // Simulate streaming response
    addLog("Simulating DGX Spark TEE encrypting response...", "info");
    const encryptedResponse = await client.encrypt(response);
    addLog("✓ Response encrypted (" + encryptedResponse.data.length + " bytes)", "success");
    
    addLog("Receiving encrypted response from DGX Spark enclave...", "info");
    await new Promise(resolve => setTimeout(resolve, 300));
    
    addLog("Decrypting response in-browser with DGX Spark session key...", "info");
    const decryptedResponse = await client.decrypt(encryptedResponse);
    addLog("✓ Response decrypted", "success");
    
    // Display response with streaming effect
    await streamMessage(decryptedResponse, 'assistant');
}

// Generate mock response for demo
function generateMockResponse(prompt) {
    const responses = [
        "This is a simulated response showing the DGX Spark flow: prompts stay encrypted until they reach the attested NVIDIA Blackwell TEE.",
        "Your prompt was encrypted with AES-256-GCM before leaving your browser. The DGX Spark enclave decrypted it, processed it, and encrypted the response before sending it back.",
        "The encryption keys were established using ECDH after verifying the NRAS-backed attestation from the DGX Spark node. This keeps your data private end-to-end.",
        "In the Cerumbra Network, this DGX Spark attestation + encryption pattern will extend to other NVIDIA confidential-compute nodes."
    ];
    
    return responses[Math.floor(Math.random() * responses.length)];
}

// UI Helper Functions
function updateStatus(text, status) {
    const statusText = document.getElementById('status-text');
    const statusIndicator = document.getElementById('status-indicator');
    
    statusText.textContent = text;
    statusIndicator.className = 'status-indicator status-' + status;
}

function updateCryptoField(fieldId, value) {
    const field = document.getElementById(fieldId);
    if (field) {
        field.textContent = value;
    }
}

function addLog(message, type = 'info') {
    const logsContainer = document.getElementById('protocol-logs');
    const timestamp = new Date().toLocaleTimeString();
    
    const logEntry = document.createElement('div');
    logEntry.className = 'log-entry log-' + type;
    logEntry.textContent = `[${timestamp}] ${message}`;
    
    logsContainer.appendChild(logEntry);
    logsContainer.scrollTop = logsContainer.scrollHeight;
}

function addMessage(text, type) {
    const messagesContainer = document.getElementById('chat-messages');
    
    const message = document.createElement('div');
    message.className = 'message ' + type + '-message';
    message.textContent = text;
    
    messagesContainer.appendChild(message);
    messagesContainer.scrollTop = messagesContainer.scrollHeight;
}

async function streamMessage(text, type) {
    const messagesContainer = document.getElementById('chat-messages');
    
    const message = document.createElement('div');
    message.className = 'message ' + type + '-message';
    messagesContainer.appendChild(message);
    
    // Simulate streaming by adding characters progressively
    for (let i = 0; i < text.length; i++) {
        message.textContent += text[i];
        messagesContainer.scrollTop = messagesContainer.scrollHeight;
        await new Promise(resolve => setTimeout(resolve, 20));
    }
}

function arrayToHex(array) {
    return Array.from(array)
        .map(b => b.toString(16).padStart(2, '0'))
        .join('');
}

// Export for potential use in other modules
if (typeof module !== 'undefined' && module.exports) {
    module.exports = { CerumbraClient };
}
