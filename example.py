#!/usr/bin/env python3
"""
Cerumbra Example - Core Cryptographic Operations

This script demonstrates the core cryptographic operations used in Cerumbra:
1. ECDH key exchange
2. HKDF key derivation
3. AES-GCM encryption/decryption

Run this to understand the cryptographic foundation of Cerumbra.
"""

from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.kdf.hkdf import HKDF
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from cryptography.hazmat.backends import default_backend
import secrets
import base64


def print_section(title):
    """Print a formatted section header"""
    print("\n" + "=" * 60)
    print(f"  {title}")
    print("=" * 60)


def demonstrate_ecdh():
    """Demonstrate ECDH key exchange"""
    print_section("1. ECDH Key Exchange")
    
    # Browser generates key pair
    print("Browser: Generating ECDH key pair...")
    browser_private = ec.generate_private_key(ec.SECP256R1(), default_backend())
    browser_public = browser_private.public_key()
    print("✓ Browser key pair generated")
    
    # TEE generates key pair
    print("\nTEE: Generating ECDH key pair...")
    tee_private = ec.generate_private_key(ec.SECP256R1(), default_backend())
    tee_public = tee_private.public_key()
    print("✓ TEE key pair generated")
    
    # Both sides perform ECDH
    print("\nPerforming ECDH key exchange...")
    browser_shared = browser_private.exchange(ec.ECDH(), tee_public)
    tee_shared = tee_private.exchange(ec.ECDH(), browser_public)
    
    # Verify both sides derived the same secret
    assert browser_shared == tee_shared
    print(f"✓ Shared secret established: {browser_shared.hex()[:32]}...")
    print(f"  Length: {len(browser_shared)} bytes")
    
    return browser_shared


def demonstrate_hkdf(shared_secret):
    """Demonstrate HKDF key derivation"""
    print_section("2. HKDF Key Derivation")
    
    print("Deriving encryption key from shared secret using HKDF...")
    print(f"Input: {shared_secret.hex()[:32]}...")
    print(f"Info: cerumbra-v1-encryption")
    
    hkdf = HKDF(
        algorithm=hashes.SHA256(),
        length=32,
        salt=None,
        info=b"cerumbra-v1-encryption",
        backend=default_backend()
    )
    encryption_key = hkdf.derive(shared_secret)
    
    print(f"✓ Derived encryption key: {encryption_key.hex()[:32]}...")
    print(f"  Length: {len(encryption_key)} bytes (256-bit)")
    
    return encryption_key


def demonstrate_aes_gcm(encryption_key):
    """Demonstrate AES-GCM encryption and decryption"""
    print_section("3. AES-GCM Encryption/Decryption")
    
    # Original message
    message = "Hello from Cerumbra! This message is end-to-end encrypted."
    print(f"Original message: '{message}'")
    print(f"Length: {len(message)} characters")
    
    # Encrypt
    print("\nEncrypting with AES-256-GCM...")
    aesgcm = AESGCM(encryption_key)
    iv = secrets.token_bytes(12)  # 96-bit nonce
    plaintext = message.encode('utf-8')
    ciphertext = aesgcm.encrypt(iv, plaintext, None)
    
    print(f"✓ Encrypted successfully")
    print(f"  IV: {iv.hex()}")
    print(f"  Ciphertext: {ciphertext.hex()[:64]}...")
    print(f"  Length: {len(ciphertext)} bytes (includes auth tag)")
    
    # Decrypt
    print("\nDecrypting...")
    decrypted = aesgcm.decrypt(iv, ciphertext, None)
    decrypted_message = decrypted.decode('utf-8')
    
    print(f"✓ Decrypted successfully")
    print(f"  Decrypted message: '{decrypted_message}'")
    
    # Verify
    assert decrypted_message == message
    print("\n✓ Message integrity verified!")


def demonstrate_attestation():
    """Demonstrate attestation quote generation"""
    print_section("4. TEE Attestation (Simulated)")
    
    print("Generating TEE attestation quote...")
    
    # Generate measurements (PCR values)
    measurements = {
        "pcr0": secrets.token_hex(32),  # Firmware
        "pcr1": secrets.token_hex(32),  # Application
        "pcr2": secrets.token_hex(32),  # Configuration
    }
    
    print("✓ TEE measurements (PCR values):")
    for pcr, value in measurements.items():
        print(f"  {pcr}: {value[:32]}...")
    
    # Generate nonce
    nonce = secrets.token_bytes(32)
    print(f"\n✓ Nonce: {nonce.hex()[:32]}...")
    
    # In production, TEE hardware would sign this
    print("\n✓ Quote would be signed by TEE hardware attestation key")
    print("✓ Certificate chain would link to hardware root of trust")


def demonstrate_full_flow():
    """Demonstrate complete Cerumbra flow"""
    print_section("Complete Cerumbra Flow")
    
    print("This demonstrates the complete cryptographic flow:")
    print("1. Browser and TEE exchange public keys (ECDH)")
    print("2. Both derive shared secret")
    print("3. Both use HKDF to derive encryption key")
    print("4. Browser encrypts prompt with AES-GCM")
    print("5. TEE decrypts, processes, and encrypts response")
    print("6. Browser decrypts response")
    
    # Step 1-3: Key exchange and derivation
    shared_secret = demonstrate_ecdh()
    encryption_key = demonstrate_hkdf(shared_secret)
    
    # Step 4-6: Encryption and decryption
    demonstrate_aes_gcm(encryption_key)
    
    # Bonus: Attestation
    demonstrate_attestation()


def main():
    """Main entry point"""
    print("\n" + "█" * 60)
    print("█" + " " * 58 + "█")
    print("█" + "  Cerumbra Cryptographic Operations Demo".center(58) + "█")
    print("█" + " " * 58 + "█")
    print("█" * 60)
    
    try:
        demonstrate_full_flow()
        
        print("\n" + "=" * 60)
        print("  Demo Complete!")
        print("=" * 60)
        print("\nKey Takeaways:")
        print("• ECDH provides secure key exchange without pre-shared secrets")
        print("• HKDF derives strong encryption keys from shared secrets")
        print("• AES-GCM provides authenticated encryption (confidentiality + integrity)")
        print("• TEE attestation proves code runs in secure environment")
        print("\nThese primitives combine to enable end-to-end encrypted AI inference.")
        print("\n✓ All cryptographic operations successful!\n")
        
    except Exception as e:
        print(f"\n❌ Error: {e}")
        import traceback
        traceback.print_exc()


if __name__ == "__main__":
    main()
