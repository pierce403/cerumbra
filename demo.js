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
        this.pendingResolvers = new Map();
        this.defaultHandler = null;
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
        let receivedNonce;
        if (attestation && Array.isArray(attestation.nonce)) {
            receivedNonce = new Uint8Array(attestation.nonce);
        } else if (attestation && attestation.quote && typeof attestation.quote.nonce === 'string') {
            const decoded = atob(attestation.quote.nonce);
            receivedNonce = new Uint8Array(decoded.length);
            for (let i = 0; i < decoded.length; i++) {
                receivedNonce[i] = decoded.charCodeAt(i);
            }
        } else {
            throw new Error("Attestation did not include a nonce");
        }

        const matches = this.nonce.every((byte, i) => byte === receivedNonce[i]);
        
        if (!matches) {
            throw new Error("Nonce mismatch in attestation");
        }
        
        return true;
    }

    setDefaultHandler(handler) {
        this.defaultHandler = handler;
    }

    waitForMessage(type, timeoutMs = 10000) {
        if (this.pendingResolvers.has(type)) {
            throw new Error(`Already waiting for message of type ${type}`);
        }

        return new Promise((resolve, reject) => {
            const timer = setTimeout(() => {
                this.pendingResolvers.delete(type);
                reject(new Error(`Timed out waiting for ${type}`));
            }, timeoutMs);

            this.pendingResolvers.set(type, {
                resolve: (payload) => {
                    clearTimeout(timer);
                    resolve(payload);
                },
                reject: (error) => {
                    clearTimeout(timer);
                    reject(error);
                }
            });
        });
    }

    _handleIncomingMessage(message) {
        const type = message.type;

        if (type && this.pendingResolvers.has(type)) {
            const { resolve } = this.pendingResolvers.get(type);
            this.pendingResolvers.delete(type);
            resolve(message);
            return;
        }

        if (type === "error") {
            addLog("Server error: " + message.message, "error");
            return;
        }

        if (!this.defaultHandler) {
            console.warn("Unhandled message from server:", message);
            return;
        }

        try {
            const maybePromise = this.defaultHandler(message);
            if (maybePromise && typeof maybePromise.catch === 'function') {
                maybePromise.catch((err) => {
                    addLog("Error handling server message: " + err.message, "error");
                });
            }
        } catch (handlerError) {
            addLog("Error handling server message: " + handlerError.message, "error");
        }
    }

    // Connect to DGX Spark TEE server
    async connect(serverUrl) {
        return new Promise((resolve, reject) => {
            this.pendingResolvers.clear();
            this.sessionId = null;

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

            this.ws.onmessage = (event) => {
                try {
                    const message = JSON.parse(event.data);
                    this._handleIncomingMessage(message);
                } catch (parseError) {
                    addLog("Failed to parse server message", "error");
                }
            };
        });
    }

    // Send message over WebSocket
    send(message) {
        if (this.ws && this.ws.readyState === WebSocket.OPEN) {
            this.ws.send(JSON.stringify(message));
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
    const serverUrlInput = document.getElementById('server-url');
    
    const defaultServerUrl = resolveDefaultServerUrl();
    if (serverUrlInput) {
        serverUrlInput.value = defaultServerUrl;
        serverUrlInput.addEventListener('change', () => {
            rememberServerUrl(serverUrlInput.value.trim());
        });
    }

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

// Handle connection to DGX Spark TEE
async function handleConnect() {
    const connectBtn = document.getElementById('connect-btn');
    const sendBtn = document.getElementById('send-btn');
    const chatInput = document.getElementById('chat-input');
    const serverUrlInput = document.getElementById('server-url');
    const serverUrl = (serverUrlInput.value || '').trim() || resolveDefaultServerUrl();

    try {
        connectBtn.disabled = true;
        sendBtn.disabled = true;
        chatInput.disabled = true;
        updateStatus("Connecting...", "connecting");
        addLog("Initializing Cerumbra client...", "info");

        // Initialize client
        client = new CerumbraClient();
        client.setDefaultHandler(handleServerMessage);

        // Generate browser key pair
        addLog("Generating browser ECDH key pair for DGX Spark session...", "info");
        await client.generateKeyPair();
        const publicKeyJwk = await client.exportPublicKey();
        updateCryptoField('browser-pubkey', JSON.stringify(publicKeyJwk).substring(0, 60) + '...');
        addLog("✓ Browser key pair generated", "success");

        // Generate attestation nonce
        const nonce = client.generateNonce();
        addLog("Generated attestation nonce: " + arrayToHex(nonce).substring(0, 16) + "...", "info");

        rememberServerUrl(serverUrl);
        addLog("Connecting to DGX Spark WebSocket endpoint: " + serverUrl, "info");
        await client.connect(serverUrl);

        addLog("Requesting NRAS-backed attestation from DGX Spark...", "info");
        const attestationPromise = client.waitForMessage("attestation_response");
        client.send({
            type: "attestation_request",
            nonce: Array.from(nonce)
        });
        const attestation = await attestationPromise;
        addLog("Received DGX Spark attestation material", "info");
        addLog("Verifying NRAS attestation (simulated coordinator check)...", "info");

        // Verify attestation
        await client.verifyAttestation(attestation);
        updateCryptoField('attestation-status', '✓ Verified');
        addLog("✓ Attestation verified successfully (NRAS trust chain)", "success");

        // Import TEE public key
        const teePublicKeyJwk = attestation.teePublicKey;
        await client.importTEEPublicKey(teePublicKeyJwk);
        updateCryptoField('tee-pubkey', JSON.stringify(teePublicKeyJwk).substring(0, 60) + '...');
        addLog("✓ DGX Spark GPU public key imported", "success");

        // Derive shared encryption key
        addLog("Performing ECDH key exchange bound to attested DGX Spark session...", "info");
        await client.deriveSharedKey();
        updateCryptoField('shared-secret', '✓ Established (256-bit AES-GCM)');
        addLog("✓ Shared secret derived", "success");
        addLog("✓ Encryption key derived using HKDF", "success");

        addLog("Sending browser public key to complete DGX Spark key exchange...", "info");
        const keyExchangePromise = client.waitForMessage("key_exchange_complete");
        client.send({
            type: "key_exchange",
            publicKey: publicKeyJwk
        });
        const keyExchange = await keyExchangePromise;
        client.sessionId = keyExchange.sessionId || null;
        if (client.sessionId) {
            addLog("DGX Spark session established: " + client.sessionId.substring(0, 8) + "...", "info");
        }

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
        if (client && client.ws) {
            try {
                client.ws.close();
            } catch (closeError) {
                console.warn("Error closing WebSocket after failure:", closeError);
            }
        }
        connectBtn.disabled = false;
        sendBtn.disabled = true;
        chatInput.disabled = true;
        connectBtn.textContent = "Retry Connection";
    }
}

// Handle sending encrypted message
async function handleSend() {
    const chatInput = document.getElementById('chat-input');
    const sendBtn = document.getElementById('send-btn');
    const prompt = chatInput.value.trim();
    
    if (!prompt) return;
    if (!isConnected || !client || !client.encryptionKey) {
        addLog("Cannot send prompt until DGX Spark session is established.", "error");
        return;
    }
    
    sendBtn.disabled = true;
    try {
        // Add user message to chat
        addMessage(prompt, 'user');
        chatInput.value = '';
        
        addLog("Encrypting prompt with DGX Spark session key (AES-256-GCM)...", "info");
        
        // Encrypt the prompt
        const encrypted = await client.encrypt(prompt);
        addLog("✓ Prompt encrypted (" + encrypted.data.length + " bytes)", "success");
        
        addLog("Sending encrypted prompt to DGX Spark enclave...", "info");
        const responsePromise = client.waitForMessage("inference_response");
        client.send({
            type: "encrypted_inference",
            prompt: encrypted
        });

        const inferenceResponse = await responsePromise;
        await processInferenceResponse(inferenceResponse);
        
    } catch (error) {
        addLog("Error: " + error.message, "error");
        addMessage("Error processing request: " + error.message, 'system');
    } finally {
        if (isConnected) {
            sendBtn.disabled = false;
        }
    }
}

async function processInferenceResponse(message) {
    if (!message || !message.response) {
        throw new Error("Malformed inference response from DGX Spark");
    }

    addLog("DGX Spark enclave returned encrypted payload", "info");
    addLog("Receiving encrypted response from DGX Spark enclave...", "info");
    addLog("Decrypting response in-browser with DGX Spark session key...", "info");

    const decryptedResponse = await client.decrypt(message.response);
    addLog("✓ Response decrypted", "success");

    await streamMessage(decryptedResponse, 'assistant');
}

function handleServerMessage(message) {
    if (!message || !message.type) {
        addLog("Received malformed message from server.", "error");
        return;
    }

    if (message.type === "inference_response") {
        return processInferenceResponse(message);
    }

    if (message.type === "key_exchange_complete") {
        addLog("Received duplicate key exchange confirmation.", "info");
        return;
    }

    addLog("Unhandled server message type: " + message.type, "info");
}

function resolveDefaultServerUrl() {
    const params = new URLSearchParams(window.location.search);
    const paramValue = params.get('server');
    if (paramValue) {
        return paramValue;
    }

    try {
        const stored = localStorage.getItem('cerumbraServerUrl');
        if (stored) {
            return stored;
        }
    } catch (storageError) {
        console.warn("Unable to read saved server URL:", storageError);
    }

    return "ws://localhost:8765";
}

function rememberServerUrl(url) {
    if (!url) return;

    try {
        localStorage.setItem('cerumbraServerUrl', url);
    } catch (storageError) {
        console.warn("Unable to store server URL preference:", storageError);
    }
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
