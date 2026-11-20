import assert from 'node:assert/strict'
import { describe, it } from 'node:test'

import {
  IV_BYTES,
  MAX_SECRET_BYTES,
  base64UrlDecode,
  base64UrlEncode,
  buildSecretUrl,
  createEncryptedSecret,
  decryptEncryptedSecret,
  deriveClaimKey,
  parseRootFragment
} from './secretCrypto.js'

const id = '123e4567-e89b-42d3-a456-426614174000'
const otherId = '123e4567-e89b-42d3-a456-426614174001'
const root = Uint8Array.from({ length: 32 }, (_value, index) => index)
const otherRoot = Uint8Array.from({ length: 32 }, (_value, index) => index + 1)
const iv = Uint8Array.from({ length: 12 }, (_value, index) => 255 - index)

describe('base64url encoding', () => {
  it('round trips binary values without padding', () => {
    const encoded = base64UrlEncode(Uint8Array.of(0, 1, 2, 253, 254, 255))

    assert.equal(encoded, 'AAEC_f7_')
    assert.deepEqual(base64UrlDecode(encoded), Uint8Array.of(0, 1, 2, 253, 254, 255))
  })

  it('rejects padding and non-canonical input', () => {
    assert.throws(() => base64UrlDecode('AA=='), /invalid base64url/)
    assert.throws(() => base64UrlDecode('A'), /base64url|canonical/)
  })
})

describe('v1 encryption protocol', () => {
  it('matches the fixed protocol fixture', async () => {
    const encrypted = await createEncryptedSecret('correct horse battery staple', { id, root, iv })

    assert.deepEqual(encrypted, {
      id,
      payload: 'Af_-_fz7-vn49_b19B7pLUjNfeoGG5LeWS0G9LnN0eVLIkKFBWoJGRoOd63pv7AVxSLjr-lbF1yQ',
      claimVerifier: '9URLEMHDMbZwI2xKzigZU9UFkK9DQXJZ2Vm5Gd3Lo3s',
      root: 'AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8'
    })
  })

  it('round trips Unicode and control characters', async () => {
    const secret = 'emoji: 🔐\nNUL:\u0000\r\n日本語'
    const encrypted = await createEncryptedSecret(secret)

    assert.equal(await decryptEncryptedSecret(encrypted.id, encrypted.payload, encrypted.root), secret)
  })

  it('derives a claim key independently of the encryption key', async () => {
    const encrypted = await createEncryptedSecret('secret', { id, root, iv })
    const claimKey = await deriveClaimKey(id, encrypted.root)

    assert.equal(claimKey, 'zmFvL4XUsBPGBpbLwocP-ca6Z0kD7yFr8GStBk8E6xw')
    assert.notEqual(claimKey, encrypted.root)
  })

  it('rejects a wrong root, a different id, and tampering', async () => {
    const encrypted = await createEncryptedSecret('secret', { id, root, iv })
    const tampered = base64UrlDecode(encrypted.payload)
    tampered[tampered.length - 1] ^= 1

    await assert.rejects(decryptEncryptedSecret(id, encrypted.payload, otherRoot))
    await assert.rejects(decryptEncryptedSecret(otherId, encrypted.payload, root))
    await assert.rejects(decryptEncryptedSecret(id, base64UrlEncode(tampered), root))
  })

  it('enforces the plaintext byte limit', async () => {
    await assert.rejects(createEncryptedSecret('a'.repeat(MAX_SECRET_BYTES + 1)), /invalid secret length/)
    await assert.rejects(createEncryptedSecret(''), /invalid secret length/)
  })

  it('uses independent roots, IVs, and ciphertexts for each link', async () => {
    const first = await createEncryptedSecret('same secret')
    const second = await createEncryptedSecret('same secret')

    assert.notEqual(first.id, second.id)
    assert.notEqual(first.root, second.root)
    assert.notEqual(first.claimVerifier, second.claimVerifier)
    assert.notEqual(first.payload, second.payload)

    const firstIv = base64UrlDecode(first.payload).slice(1, 1 + IV_BYTES)
    const secondIv = base64UrlDecode(second.payload).slice(1, 1 + IV_BYTES)
    assert.notDeepEqual(firstIv, secondIv)
  })
})

describe('fragment URLs', () => {
  it('builds and parses a root that stays in the fragment', () => {
    const url = new URL(buildSecretUrl('https://secrets.example.test', id, root))

    assert.equal(url.pathname, `/${id}`)
    assert.equal(url.search, '')
    assert.deepEqual(parseRootFragment(url.hash), root)
  })

  it('rejects unknown versions and malformed roots', () => {
    assert.throws(() => parseRootFragment('#v2.AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8'))
    assert.throws(() => parseRootFragment('#v1.short'))
    assert.throws(() => parseRootFragment('#v1.key.extra'))
  })
})
