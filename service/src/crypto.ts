import crypto from 'node:crypto';

function getOrHashKey(): Buffer {
  const keySource = process.env.CODINGPLAN_CRYPTO_KEY || "codingplan-dev-key-change-in-prod";
  return crypto.createHash('sha256').update(keySource).digest();
}

export function decrypt_api_key(base64Encoded: string): string {
  if (!base64Encoded) return "";
  try {
    const combined = Buffer.from(base64Encoded, 'base64');
    const key = getOrHashKey();
    
    // GCM standard: 12-byte nonce
    const nonce = combined.subarray(0, 12);
    const ciphertextWithTag = combined.subarray(12);
    
    // Auth tag is the last 16 bytes in standard GCM combined output
    const ciphertext = ciphertextWithTag.subarray(0, ciphertextWithTag.length - 16);
    const authTag = ciphertextWithTag.subarray(ciphertextWithTag.length - 16);

    const decipher = crypto.createDecipheriv('aes-256-gcm', key, nonce);
    decipher.setAuthTag(authTag);
    
    let decrypted = decipher.update(ciphertext, undefined, 'utf8');
    decrypted += decipher.final('utf8');
    return decrypted;
  } catch (err) {
    console.error(`[Crypto] Decryption failed: ${err}`);
    return "";
  }
}

export function encrypt_api_key(plainText: string): string {
  if (!plainText) return "";
  try {
    const key = getOrHashKey();
    const nonce = crypto.randomBytes(12);
    const cipher = crypto.createCipheriv('aes-256-gcm', key, nonce);
    
    let ciphertext = cipher.update(plainText, 'utf8');
    ciphertext = Buffer.concat([ciphertext, cipher.final()]);
    const authTag = cipher.getAuthTag();
    
    return Buffer.concat([nonce, ciphertext, authTag]).toString('base64');
  } catch (err) {
    console.error(`[Crypto] Encryption failed: ${err}`);
    return "";
  }
}
