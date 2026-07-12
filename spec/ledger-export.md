# CSS Ledger Export (CLE) — v0.1 (draft)

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
> **Reference implementation.** Exports are produced by the proprietary CSS engine; the reference
> verifier (`sr-verify`, maintained by Continuity Laboratories, including the hosted
> in-browser verifier at <https://continuitylaboratories.com/verify>) is held
> byte-compatible with it by the conformance corpus, which independent
> implementations validate against equally. This specification covers the wire format and its **verification** only.



**Status:** Draft, published for review. The wire format is pinned by a golden
test vector; changes follow the evolution rules in §8.
**Reference verifier:** `sr-verify ledger` (maintained by Continuity Laboratories) —
a standalone offline verifier.
**Worked example:** [`corpus/cle-v0.1/r1/golden.json`](../corpus/cle-v0.1/r1/golden.json)
— a complete, valid signed export, pinned byte-for-byte by the corpus.

A **CSS Ledger Export** is a single JSON document carrying an entire CSS ledger — every
event in publication order and every audit chain — designed to be verified **offline, by
parties who do not run CSS**: no database, no server, no deployment. Everything needed to
check it is in the document itself, plus the issuer's public key(s).

Where an [Authority-Handoff Receipt](./authority-handoff-receipts.md) proves **one
completed handoff**, a ledger export makes **the whole history** portable evidence: the
hash-chained events, the hash-chained audit records that cover them, the signatures over
both, and (when signed) the issuer's attestation that this was the complete ledger at a
point in time.

---

## 1. What an export attests — and what it does not

A verified export establishes that:

- every event in the document is **hash-intact** (its recorded SHA-256 recomputes from its
  content, per the platform event-hash rule);
- the events form **unbroken linear stream chains**: every `previous_event_id` link points
  to an earlier event and no event has two successors — dropping or reordering interior
  history breaks a link;
- every audit record is **hash-intact and chain-linked** exactly as appended;
- with the issuer's public keys: every present event and record **signature verifies**
  (authenticity), and — if the export is signed — the issuer attests **completeness**:
  "this was the whole ledger, head included, as of `exported_at`" (§3).

An export does **not** attest that anything outside the registry was enforced. CSS
refusals gate ledger transitions, not external agent actions (see the
scope-of-enforcement note in the README and the
threat model). And an **unsigned** export cannot prove
completeness: a party that controls the store can export a cleanly truncated prefix that
verifies structurally (§6).

## 2. Data model

An export is a single JSON object.

| Member | Type | Description |
|---|---|---|
| `spec` | string | Exactly `"css-ledger-export"`. |
| `spec_version` | string | `"0.1"`. Bumps on breaking wire-format change (§8). |
| `issuer` | object | `{"id": <string>}` — identifies the exporting registry operator. Default `"urn:css:registry"`. |
| `exported_at` | string (RFC 3339) | When the export was assembled (microsecond precision, UTC). Covered by the proof. |
| `event_count` | integer | Must equal `len(events)`. |
| `head_event_id` | string (UUID) | The last event's `event_id`. Absent on an empty ledger. |
| `head_event_hash` | string (hex) | The last event's `event_hash`. Absent on an empty ledger. |
| `events` | array of object | Every event envelope **verbatim in publication order** — recorded bytes, not re-derived ones. Envelope fields: `event_id`, `event_type`, `aggregate_type`, `aggregate_id`, optional `causation_id`/`correlation_id`/`previous_event_id`/`actor_id`, `timestamp`, `event_version`, `payload`, `event_hash`, optional `signature`. |
| `chain_count` | integer | Must equal `len(audit_chains)`. |
| `record_count` | integer | Must equal the total record count across all chains. |
| `audit_chains` | array of object | Every audit chain (§2.1), ordered by `chain_id` (lexicographic) for deterministic output. May be empty. |
| `proof` | object | The issuer's signature over the canonical export (§3). **Optional** — but only a signed export carries the completeness attestation. |

### 2.1 `audit_chains[]`

| Member | Type | Description |
|---|---|---|
| `chain_id` | string (UUID) | The audit chain's identity. |
| `entity_type` | string | The constitutional entity the chain covers (e.g. `"Obligation"`). Optional. |
| `entity_id` | string (UUID) | The entity instance. Optional. |
| `records` | array of object | The chain's records **verbatim, oldest first** (append order): `id`, `event_id`, `entity_type`, `entity_id`, `action_type`, optional `actor_id`, `timestamp`, optional `previous_hash`, `current_hash`, optional `metadata`, optional `signature`. |

Record `signature` is authenticity metadata over `current_hash` (hash-then-sign, audit
#46); it is excluded from the record hash, so an export of pre-#46 unsigned history still
verifies (as unsigned).

## 3. Canonicalization and proof

The canonical form of an export is UTF-8 JSON with **lexicographically sorted keys, no
insignificant whitespace, no HTML escaping, and the `proof` member absent**. For the
export's value domain (strings, integers, arrays, objects — no floats) this coincides
with RFC 8785 (JCS) output.

The proof is the platform's discipline — hash-then-sign, no new key management:

```
export_hash = hex(SHA-256(canonical_bytes))
signature   = Ed25519-sign(event-signing key, UTF-8 bytes of export_hash)
```

| Member | Description |
|---|---|
| `type` | `"CSSEd25519Signature"`. |
| `created` | Proof timestamp (presentation only; outside the signed content — the attested export time is `exported_at`, which **is** signed). |
| `verification_method` | The signing `key_id`. |
| `export_hash` | Hex SHA-256 of the canonical bytes. |
| `signature` | Canonical `ed25519:<key_id>:<base64url>` string — the same format events carry. |

A signed export is the issuer's **completeness attestation**: the signature covers the
event list, both head fields, and every count — so a later "ledger" whose history stops
below that head **contradicts a statement the issuer signed** (§6).

## 4. Verification algorithm (normative)

A verifier MUST run all steps; order matters only in that structural failures make later
steps meaningless. With no public keys configured, steps 5 and the signature half of 6–7
are skipped and the pass is **integrity-only** (report it as such).

1. **Structure.** `spec` and `spec_version` are recognized; `event_count`,
   `chain_count`, `record_count` match the arrays; `head_event_id`/`head_event_hash`
   match the last event (absent on an empty ledger); no duplicate `event_id` or
   `chain_id`. Any mismatch is fatal.
2. **Normalization.** Re-decode each event `payload` into its registered concrete type
   (required for byte-identical hash recomputation). Unregistered event types keep the
   generic JSON object — the same fallback the platform's durable store applies on read.
3. **Event integrity.** Recompute every event's hash per the platform rule
   (`event_id + event_type + aggregate_type + aggregate_id + timestamp(RFC 3339 ns) +
   event_version + payload_json + previous_event_id-or-""`). Mismatch is fatal.
4. **Stream linkage.** Walking in document order: every non-null `previous_event_id`
   MUST reference an event seen **earlier**, and no two events may claim the same
   predecessor (fork). Links are covered by the event hashes, so linkage cannot be
   rewritten without failing step 3. Violation is fatal.
5. **Event authenticity** *(keys configured)*. Every present event signature MUST verify
   (`ed25519:<key_id>:<base64url>` over the UTF-8 bytes of `event_hash`). A present but
   invalid signature is fatal; an absent one is reported, never a failure (unsigned
   deployments).
6. **Audit chains.** For each chain: recompute every record's hash
   (`id + event_id + entity_type + entity_id + action_type + actor_id-or-"" +
   timestamp(RFC 3339 ns) + previous_hash-or-"" + metadata_json`) and check the
   `previous_hash` linkage (first record has none). Fatal on mismatch. With keys: every
   present record signature (over `current_hash`) MUST verify; invalid is fatal.
   **Event anchoring is advisory:** count records whose `event_id` matches an exported
   event; a small number of record kinds cite an entity ID instead (e.g. the
   delegation-activation record), so unanchored records are reported, never failed.
7. **Proof** *(present)*. Recompute the canonical hash; it MUST equal
   `proof.export_hash` (fatal even without keys). With keys, the signature MUST verify;
   without keys, report the proof unverified.
8. **Advisories.** Report orphaned obligation streams (created but referenced by no
   genesis, chain link, or inheritance); callers MAY gate on them
   (`-fail-on-orphans`).

Exit semantics of the reference verifier (`sr-verify ledger`): `0` verified, `1` failed,
`2` usage/I-O. `-min-events` guards against verifying an unexpectedly empty document,
`-require-proof` demands the completeness attestation.

## 5. Producing an export

Exports are produced by the engine **read-only** from its recorded ledger — exporting
writes nothing and emits the document exactly as stored. Assembly rules: events verbatim
from the master stream in publication order; audit chains verbatim, wire-ordered by
`chain_id`; `exported_at` truncated to microseconds (UTC). Signing uses the event-signing
private key — the export path introduces no new key material — and only a signed export
carries the completeness attestation (§2).

Offline verification: `sr-verify ledger -ledger <file> -public-keys key_id=path[,…]`
— no database, no server, exit 0 iff the export verifies.

## 6. Trust model and limitations

- **What tampering is caught:** any alteration of event or record content, any dropped or
  reordered **interior** history (stream links break), any dropped or edited audit
  record, any metadata/count/head inconsistency, any forged signature (wrong key or
  altered content), and — for signed exports — **truncation**: a re-signed shorter
  document either fails signature verification (attacker lacks the issuer key) or
  contradicts the issuer's earlier signed head.
- **What an unsigned export cannot prove:** completeness. A cleanly truncated prefix of
  an unsigned export verifies structurally (the tail's absence severs no link). Detection
  requires a signed export, an older export/receipt held off-host, or external anchoring.
  This format is designed to be anchored (the `export_hash` is a single digest of the whole
  ledger state), and [external anchoring](./external-anchoring.md) now provides
  the older reference on a schedule: periodic signed checkpoints of the head that a later
  truncated or rolled-back export contradicts.
- **A signed export binds the issuer, not the truth of the domain:** it proves the
  registry recorded this history and attested its completeness — the same trust model as
  the platform's signatures generally (see the threat model's operator rows).
- **Verification keys travel out of band.** Like receipts, the document never embeds the
  public keys it is verified against.

## 7. Worked example

The golden vector [`corpus/cle-v0.1/r1/golden.json`](../corpus/cle-v0.1/r1/golden.json)
is a complete signed export: 4 events (a genesis, a steward assignment, a legitimacy
determination, an obligation creation) and 2 audit chains (3 signed records), signed with
the pinned test key `cle-vector-1` (Ed25519 seed bytes `00…1f`) and pinned byte-for-byte
by the corpus. The corpus tamper cases mutate it one field at a time — an altered event
payload, a forked stream, a count mismatch, an edited audit record, a flipped proof bit —
and each must fail at exactly the named check in the manifest.

## 8. Evolution and stability

- The v0.1 wire format is **pinned by the conformance corpus**: any byte-level change
  requires a `spec_version` bump, a new corpus revision, and an edit here.
- Additive, optional members MAY appear in minor revisions; verifiers MUST ignore unknown
  members (the canonical form covers whatever members are present, so added members are
  still proof-covered on signed exports).
- Breaking changes (member renames, canonicalization or hash-rule changes) bump
  `spec_version`; verifiers reject versions they do not implement — `sr-verify ledger`
  states the version it speaks.
- The event-envelope and audit-record members are the platform's stored forms; their
  hash rules are frozen with the constitutional core (schema evolution happens above
  replay via upcasting and never rewrites stored bytes, so exported history remains
  verifiable indefinitely).

## 9. Relationship to Authority-Handoff Receipts

Receipts (AHR) and ledger exports share the discipline — stored envelopes
verbatim, hash-then-sign with the event-signing key, offline verification, corpus
pinning — and differ in scope: a receipt is **one handoff's** evidence bundle for a
counterparty; an export is **the whole ledger** for an auditor, an archive, or an
anchoring pipeline. A counterparty holding either has durable off-host evidence that a
later rollback of the registry's history would contradict.
