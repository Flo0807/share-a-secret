const encoder = new TextEncoder()
const decoder = new TextDecoder('utf-8', { fatal: true })

export const PROTOCOL_VERSION = 1
export const ROOT_BYTES = 32
export const IV_BYTES = 12
export const TAG_BYTES = 16
export const MAX_SECRET_BYTES = 64 * 1024
export const MAX_ENVELOPE_BYTES = 1 + IV_BYTES + MAX_SECRET_BYTES + TAG_BYTES

const encryptionInfo = encoder.encode('share-a-secret/v1/encryption')
const claimInfo = encoder.encode('share-a-secret/v1/claim')
const aadPrefix = 'share-a-secret\0v1\0'
const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/
const base64UrlPattern = /^[A-Za-z0-9_-]+$/

export function base64UrlEncode (bytes) {
  let binary = ''

  for (let offset = 0; offset < bytes.length; offset += 0x8000) {
    binary += String.fromCharCode(...bytes.subarray(offset, offset + 0x8000))
  }

  return btoa(binary)
    .replaceAll('+', '-')
    .replaceAll('/', '_')
    .replace(/=+$/, '')
}

export function base64UrlDecode (value, expectedLength) {
  if (typeof value !== 'string' || !base64UrlPattern.test(value)) {
    throw new Error('invalid base64url value')
  }

  const paddingLength = (4 - (value.length % 4)) % 4
  const padded = value.replaceAll('-', '+').replaceAll('_', '/') + '='.repeat(paddingLength)

  let binary

  try {
    binary = atob(padded)
  } catch (_error) {
    throw new Error('invalid base64url value')
  }

  const bytes = Uint8Array.from(binary, character => character.charCodeAt(0))

  if (base64UrlEncode(bytes) !== value) {
    throw new Error('non-canonical base64url value')
  }

  if (expectedLength !== undefined && bytes.length !== expectedLength) {
    throw new Error('invalid decoded length')
  }

  return bytes
}

export function validSecretId (id) {
  return typeof id === 'string' && uuidPattern.test(id)
}

export function randomRoot () {
  return crypto.getRandomValues(new Uint8Array(ROOT_BYTES))
}

export function randomIv () {
  return crypto.getRandomValues(new Uint8Array(IV_BYTES))
}

export function parseRootFragment (fragment) {
  const value = fragment.startsWith('#') ? fragment.slice(1) : fragment
  const parts = value.split('.')

  if (parts.length !== 2 || parts[0] !== `v${PROTOCOL_VERSION}`) {
    throw new Error('invalid secret fragment')
  }

  return base64UrlDecode(parts[1], ROOT_BYTES)
}

export function buildSecretUrl (origin, id, root) {
  assertSecretId(id)
  const rootBytes = normalizeRoot(root)
  const url = new URL(`/${id}`, origin)
  url.hash = `v${PROTOCOL_VERSION}.${base64UrlEncode(rootBytes)}`
  return url.toString()
}

export async function createEncryptedSecret (secret, options = {}) {
  if (typeof secret !== 'string') {
    throw new Error('secret must be a string')
  }

  const plaintext = encoder.encode(secret)

  if (plaintext.length === 0 || plaintext.length > MAX_SECRET_BYTES) {
    plaintext.fill(0)
    throw new Error('invalid secret length')
  }

  const id = options.id || crypto.randomUUID()
  const root = normalizeRoot(options.root || randomRoot())
  const iv = normalizeIv(options.iv || randomIv())

  assertSecretId(id)

  try {
    const { encryptionKey, claimKey } = await deriveKeys(root, id)
    const ciphertext = new Uint8Array(await crypto.subtle.encrypt({
      name: 'AES-GCM',
      iv,
      additionalData: additionalData(id),
      tagLength: TAG_BYTES * 8
    }, encryptionKey, plaintext))
    const envelope = concatenate(Uint8Array.of(PROTOCOL_VERSION), iv, ciphertext)
    const claimVerifier = new Uint8Array(await crypto.subtle.digest('SHA-256', claimKey))

    return {
      id,
      payload: base64UrlEncode(envelope),
      claimVerifier: base64UrlEncode(claimVerifier),
      root: base64UrlEncode(root)
    }
  } finally {
    plaintext.fill(0)
  }
}

export async function deriveClaimKey (id, root) {
  assertSecretId(id)
  const rootBytes = normalizeRoot(root)

  try {
    const { claimKey } = await deriveKeys(rootBytes, id)
    return base64UrlEncode(claimKey)
  } finally {
    rootBytes.fill(0)
  }
}

export async function decryptEncryptedSecret (id, encodedEnvelope, root) {
  assertSecretId(id)
  const rootBytes = normalizeRoot(root)
  const envelope = base64UrlDecode(encodedEnvelope)

  if (
    envelope.length < 1 + IV_BYTES + TAG_BYTES ||
    envelope.length > MAX_ENVELOPE_BYTES ||
    envelope[0] !== PROTOCOL_VERSION
  ) {
    rootBytes.fill(0)
    envelope.fill(0)
    throw new Error('invalid encrypted envelope')
  }

  const iv = envelope.slice(1, 1 + IV_BYTES)
  const ciphertext = envelope.slice(1 + IV_BYTES)

  try {
    const { encryptionKey } = await deriveKeys(rootBytes, id)
    const plaintext = new Uint8Array(await crypto.subtle.decrypt({
      name: 'AES-GCM',
      iv,
      additionalData: additionalData(id),
      tagLength: TAG_BYTES * 8
    }, encryptionKey, ciphertext))

    try {
      return decoder.decode(plaintext)
    } finally {
      plaintext.fill(0)
    }
  } finally {
    rootBytes.fill(0)
    envelope.fill(0)
    iv.fill(0)
    ciphertext.fill(0)
  }
}

export function clearBytes (bytes) {
  if (bytes instanceof Uint8Array) bytes.fill(0)
}

async function deriveKeys (root, id) {
  const keyMaterial = await crypto.subtle.importKey('raw', root, 'HKDF', false, ['deriveKey', 'deriveBits'])
  const salt = encoder.encode(id)

  const [encryptionKey, claimBits] = await Promise.all([
    crypto.subtle.deriveKey({
      name: 'HKDF',
      hash: 'SHA-256',
      salt,
      info: encryptionInfo
    }, keyMaterial, { name: 'AES-GCM', length: 256 }, false, ['encrypt', 'decrypt']),
    crypto.subtle.deriveBits({
      name: 'HKDF',
      hash: 'SHA-256',
      salt,
      info: claimInfo
    }, keyMaterial, ROOT_BYTES * 8)
  ])

  return { encryptionKey, claimKey: new Uint8Array(claimBits) }
}

function additionalData (id) {
  return encoder.encode(`${aadPrefix}${id}`)
}

function normalizeRoot (root) {
  const bytes = typeof root === 'string' ? base64UrlDecode(root, ROOT_BYTES) : new Uint8Array(root)

  if (bytes.length !== ROOT_BYTES) {
    bytes.fill(0)
    throw new Error('invalid root length')
  }

  return bytes
}

function normalizeIv (iv) {
  const bytes = new Uint8Array(iv)

  if (bytes.length !== IV_BYTES) {
    bytes.fill(0)
    throw new Error('invalid IV length')
  }

  return bytes
}

function assertSecretId (id) {
  if (!validSecretId(id)) throw new Error('invalid secret id')
}

function concatenate (...arrays) {
  const totalLength = arrays.reduce((length, array) => length + array.length, 0)
  const result = new Uint8Array(totalLength)
  let offset = 0

  for (const array of arrays) {
    result.set(array, offset)
    offset += array.length
  }

  return result
}
