# CSS Issuer Keyset — v0.1 (draft)

> **Publication note (Succession Receipts).** Part of **Succession Receipts** — the open verification surface for CSS evidence. v0.1,
> draft; the stability ladder and algorithm registry in the other specs apply here
> unchanged.

Every CSS evidence artifact is verified against **operator-pinned Ed25519 public
keys**, resolved by the `key_id` embedded in each canonical signature string
(`<alg>:<key_id>:<base64url(signature)>`). `key_id` is operator-managed — it is *not*
derived from the key — which makes rotation a pure key-distribution concern: a verifier
holds several keys at once and selects per signature; an unknown `key_id` is an
authenticity failure only.

This document names the two interchange forms for those keys.

## 1. PEM files + key spec (CLI form)

Each public key is a PEM-encoded PKIX/SPKI Ed25519 key (`-----BEGIN PUBLIC KEY-----`).
A set of keys is named by the canonical **key spec** string:

```
key_id=path[,key_id=path...]
```

This is the format every verifier CLI accepts via `-public-keys`, and the
`CSS_SIGNING_PUBLIC_KEYS` environment variable carries the same string.

## 2. JSON keyset (web form)

A keyset document maps `key_id` to key material, for browser verifiers and automated
key discovery:

```json
{
  "prod-1": { "alg": "ed25519", "public_key": "<base64url(raw 32-byte key)>" },
  "prod-2": { "alg": "ed25519", "public_key": "..." }
}
```

- `alg` — a registered algorithm label (`ed25519` at v0.1).
- `public_key` — the raw 32-byte Ed25519 public key, base64url-encoded (unpadded).

**Discovery.** An issuer that publishes its keyset over HTTPS SHOULD serve it at
`/.well-known/css-keyset.json`. Verifiers MUST allow keys to be supplied out of band
instead — the trust decision is always the relying party's, and fetching a keyset from
the issuer's own origin only proves consistency with that origin, not authenticity of
the origin itself.

## 3. Trust model

Verification establishes that *the holder of the named key* produced the evidence. What
binds a `key_id` to a real-world issuer is out-of-band pinning: obtain the keyset from
the issuer through a channel you trust (a contract exhibit, a security review, a signed
release), then pin it. Key rotation adds a new `key_id`; it never invalidates
already-issued evidence, which continues to verify against the retired key.
