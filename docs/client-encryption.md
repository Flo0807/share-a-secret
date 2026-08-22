# Client encryption protocol

This document specifies version 1 of Share a Secret's browser encryption format. Protocol changes require a new version and test vectors; deployed version 1 data must not be reinterpreted in place.

## Security properties

For new links, plaintext and the root encryption capability remain in the browser. The server receives and stores:

- an opaque UUID;
- a versioned authenticated ciphertext;
- a SHA-256 verifier for an independently derived, high-entropy claim capability;
- expiry and creation timestamps.

The server can observe record size, creation time, expiration, public ID, creation IP/network metadata, and reveal timing. It cannot decrypt a version 1 record from the stored values.

This design does not make a hosted web application fully trustless. Whoever controls the JavaScript delivered to a browser can change it to capture plaintext or the fragment root. Browser extensions, clipboard managers, browser history, link previews, and compromised endpoints can also disclose a link or plaintext. Production deployments therefore require HTTPS/HSTS, the checked-in Content Security Policy, no third-party scripts or analytics, pinned dependencies, reviewed builds, and prompt security updates.

## Cryptographic construction

All byte generation uses `crypto.getRandomValues`. All cryptographic operations use the browser's native Web Crypto API.

1. Generate a 32-byte root and a lowercase canonical UUID per link.
2. Import the root as HKDF key material.
3. Use the UUID's UTF-8 bytes as the HKDF-SHA-256 salt.
4. Derive a 256-bit AES-GCM key with info `share-a-secret/v1/encryption`.
5. Derive a separate 256-bit claim key with info `share-a-secret/v1/claim`.
6. Generate a fresh 12-byte AES-GCM IV.
7. Encrypt the UTF-8 plaintext with a 128-bit tag. The authenticated additional data is `share-a-secret\0v1\0<uuid>`.
8. Encode the envelope as `0x01 || IV || ciphertext || tag`, using canonical unpadded base64url.
9. Store `SHA-256(claim key)` as the claim verifier.

The maximum UTF-8 plaintext size is 65,536 bytes. A version 1 envelope is therefore 30 to 65,565 bytes. Server and database constraints independently enforce the version byte, lengths, versioned nullability, UUID form, allowed expiration, and maximum batch size.

The encryption and claim keys are domain-separated. A claim key authorizes only an atomic ciphertext retrieval; it cannot be used as the AES key.

## Link and request flow

The link is `https://host/<uuid>#v1.<base64url-root>`. The root is never placed in a query parameter, path, form field, LiveView assign, server-rendered markup, or persistent browser storage.

Phoenix LiveView normally includes `window.location.href` in its WebSocket join payload. The application therefore captures every fragment into module memory and calls `history.replaceState` before constructing `LiveSocket`. The reveal hook consumes that captured value once. Reloading the scrubbed page loses the root by design.

Creation sends only `{id, payload, claim_verifier}` records plus the selected expiry. The server validates and inserts the whole batch transactionally. Links are assembled in the browser only after acknowledgement.

Reveal derives the claim key in the browser and sends it to the server. PostgreSQL performs one conditional `DELETE ... RETURNING` operation matching ID, version, verifier, and expiry. Exactly one claimant receives the ciphertext. The browser then authenticates and decrypts it and assigns plaintext through `textarea.value`; decrypted data is never interpreted as HTML.

The consume-before-return policy provides at-most-once delivery. A process crash, connection loss, or client decryption failure after the atomic delete can permanently lose the secret. Retrying delivery would weaken strict one-time semantics, so this tradeoff is intentional and must remain visible in product behavior.

## Legacy migration

Rows created by older releases are version 0. Their links use a query-string key and are decrypted server-side. Version 0 reveal is isolated to a row-locked legacy path and cannot reveal version 1 rows. New creation uses only version 1. Legacy support can be removed after the longest previously supported expiry has elapsed from the production rollout.

## Required verification

Changes to this protocol must retain tests for:

- the independently reproduced deterministic test vector;
- Unicode round trips, size boundaries, wrong roots, changed IDs, tag corruption, and unknown versions;
- strict canonical base64url and UUID parsing;
- independent roots and IVs for multiple links;
- no plaintext or fragment root in outgoing WebSocket frames, HTML, database plaintext columns, or rendered links;
- fragment removal before the LiveView socket join;
- wrong-claim preservation and exactly-once claim behavior;
- expiry, batch rollback, request size limits, database constraints, and legacy isolation;
- browser handling of HTML-like plaintext without DOM interpretation;
- restrictive CSP, no-store, and referrer headers.
