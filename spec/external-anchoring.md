# CSS External Anchoring — v0.1 (draft)

> **Publication note (Succession Receipts).** This specification is published as part
> of **Succession Receipts** — the open verification surface for CSS evidence — see the repository README for scope. It is **v0.1,
> draft**: the wire format is pinned by the golden vectors in [`corpus/`](../corpus/)
> and validated by the conformance corpus in this repository; independent
> verifier implementations conform by passing it.
>
> **Stability ladder.** v0.1 (draft) → v1.0 (stable). A published version is never
> mutated: format changes only ever add a new version with new golden vectors, and
> conforming verifiers keep verifying every published version. Corpus revisions
> (`r1`, `r2`, …) are additive snapshots, never edits.
>
> **Algorithm registry.** Signatures use the canonical
> `<alg>:<key_id>:<base64url(signature)>` string. `ed25519` (hash-then-sign over the
> hex SHA-256 of the canonical bytes) is the sole registered algorithm at v0.1. New
> algorithms (e.g. post-quantum schemes) are additive prefixes registered by a new
> spec version; verifiers reject unregistered prefixes.
>
> **Reference implementation.** Checkpoints are produced by the proprietary CSS engine; the reference
> verifier (`sr-verify`, maintained by Continuity Laboratories, including the hosted
> in-browser verifier at <https://continuitylaboratories.com/verify>) is held
> byte-compatible with it by the conformance corpus, which independent
> implementations validate against equally.
> This specification covers the wire format and its **verification** only.



**Status:** Draft, published for review. Implements the "periodic signed checkpoints"
approach; the transparency-log / RFC 3161 witness approach is a documented extension
point (§6).
**Reference verifier:** `sr-verify anchors` (maintained by Continuity Laboratories) —
a standalone offline verifier.

A [CSS Ledger Export](./ledger-export.md) is self-verifying — but a self-verifying export
cannot, on its own, prove it is **complete**. Truncating an *unsigned* export (dropping the
most recent events) or rolling it back (rewriting history below the head) produces a
shorter document that still passes every internal hash and linkage check: nothing inside it
contradicts the lie. The only defence is an **earlier, independent reference** to what the
head was. External anchoring produces exactly that reference.

An **anchor checkpoint** is a small, Ed25519-signed commitment to the ledger head —
its height and head-event hash — at a point in time. Checkpoints are hash-linked into an
append-only chain and published somewhere durable. A later export that drops **below**, or
**diverges from**, an anchored head then contradicts a checkpoint the operator cannot
silently rewrite.

This closes the honest limit called out by the ledger export spec and audit item #50:
*"truncation of an unsigned export is undetectable without an older export/receipt or
anchoring."* Anchoring is that older reference, produced on a schedule.

---

## 1. What a checkpoint attests — and what it does not

A verified anchor chain, cross-checked against an export, establishes:

- **No truncation below an anchor** — the export holds at least as many events as every
  checkpoint's `height`; an already-committed head is still present.
- **No rollback at an anchor** — at each anchored height, the export's event is byte-for-byte
  the head that was anchored (same `event_id`, same `event_hash`).
- **Chain authenticity** — each checkpoint is signed by a known key and hash-linked to its
  predecessor, so the anchor history itself cannot be reordered or re-linked.

It does **not** attest anything about events *after* the latest checkpoint (they are not yet
anchored), and it introduces **no new trust root**: checkpoints are signed with the same
event-signing Ed25519 key discipline the platform already uses. Anchoring is authenticity
metadata only — it never participates in replay or constitutional decision-making.

The strength of the guarantee equals the durability of where the chain is published. A
chain kept only next to the ledger it anchors protects against accidental truncation and an
after-the-fact insider edit, but not an attacker who rewrites both together — for that,
publish checkpoints to an independent witness (§6).

## 2. Checkpoint wire format

One checkpoint is a JSON object. Canonicalization sorts keys, so the wire bytes (and thus
the signed hash) are independent of field order — the same JCS discipline as the ledger
export.

| Field | Meaning |
|---|---|
| `spec` / `spec_version` | `"css-ledger-anchor"` / `"0.1"` |
| `issuer` | anchoring registry id (default `urn:css:registry`) |
| `sequence` | 0-based position in the chain |
| `prev_checkpoint_hash` | hex SHA-256 of the preceding checkpoint's canonical bytes (absent at sequence 0) |
| `height` | anchored ledger event count |
| `head_event_id` / `head_event_hash` | the ledger head at `height` |
| `checkpointed_at` | RFC 3339 UTC timestamp (covered by the signature) |
| `proof` | issuer signature (§3), optional |

The append-only chain is stored as **JSONL** — one checkpoint per line, oldest first.

## 3. Proof

The proof mirrors the ledger export proof: SHA-256 over the canonical checkpoint bytes
(proof member absent), signed with the event-signing key in the canonical
`ed25519:<key_id>:<base64url>` format.

```json
"proof": {
  "type": "CSSEd25519Signature",
  "created": "2026-07-06T01:25:25.208025Z",
  "verification_method": "prod-1",
  "checkpoint_hash": "7a6ecbe1…",
  "signature": "ed25519:prod-1:gpKLJo4Q…"
}
```

`created` is excluded from the signed message, so re-signing identical content yields the
same `checkpoint_hash`. `checkpointed_at`, `height`, and the head fields **are** covered.

## 4. Verification algorithm

Given a checkpoint chain and (optionally) a ledger export and public keys:

1. **Chain structure** — for each checkpoint: `spec`/`spec_version` match; `sequence` equals
   its position; `prev_checkpoint_hash` equals the prior checkpoint's recomputed canonical
   hash (empty at sequence 0).
2. **Chain authenticity** (keys configured) — recompute each checkpoint's canonical hash,
   require it to equal `proof.checkpoint_hash`, and verify the signature.
3. **Cross-check against an export** — for every checkpoint whose `height` is within the
   export: fail **truncation** if `export.event_count < height`; fail **rollback** if the
   export's event at that height differs from the anchored `head_event_id` / `head_event_hash`.

Without public keys the pass is integrity-only (structure and linkage, no authenticity).
`sr-verify anchors` exits `0` on success, `1` on any anchoring violation, `2` on usage/I-O
error.

## 5. Operating model

Checkpoints are produced on a schedule (e.g. hourly) against a fresh export, appended to
the chain, and the chain is published. Checkpoint cadence bounds the exposure window:
anything anchored is protected; only events since the last checkpoint are not.

## 6. Extension point: external witnesses

The shipped anchor is the offline signed-checkpoint log — self-hostable, `$0`, no external
dependency. The same checkpoint can additionally be committed to an independent witness
whose record the operator cannot rewrite:

- an **RFC 3161** timestamp authority (a countersigned timestamp over `checkpoint_hash`);
- a **transparency log** (Rekor / Certificate-Transparency-style) that gossips an
  append-only Merkle log of checkpoint hashes.

These strengthen §1's durability assumption; they are not required for the truncation /
rollback detection above, which the local signed chain already provides. Wiring a witness
sink is future work and deliberately kept out of the core so verification stays offline.

## 7. Evolution

`spec_version` is pinned; changes follow the same additive-evolution discipline as the
ledger export spec (new optional fields tolerated by older verifiers; breaking changes bump
the version).
