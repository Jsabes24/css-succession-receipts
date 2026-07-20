# CSS Authority-Handoff Receipts (AHR) — v0.2 (draft)

> **Publication note (Succession Receipts).** This specification is published as part
> of **Succession Receipts** — the open verification surface for CSS evidence — see the repository README for scope. Published
> versions: **v0.1** (frozen — never mutated) and **v0.2** (current, draft; adds the
> `constitution` and `ledger_binding` claims, §2.1). The wire format of each version is
> pinned by its golden vectors in [`corpus/`](../corpus/) and validated by the
> conformance corpus in this repository; independent verifier implementations conform
> by passing it — for **every** published version.
>
> **Stability ladder.** v0.1 (draft) → v0.2 (draft) → v1.0 (stable). A published version is never
> mutated: format changes only ever add a new version with new golden vectors, and
> conforming verifiers keep verifying every published version. Corpus revisions
> (`r1`, `r2`, …) are additive snapshots, never edits.
>
> **Algorithm registry.** Signatures use the canonical
> `<alg>:<key_id>:<base64url(signature)>` string. `ed25519` (hash-then-sign over the
> hex SHA-256 of the canonical bytes) is the sole registered algorithm at v0.1 and
> v0.2. New algorithms (e.g. post-quantum schemes) are additive prefixes registered by
> a new spec version; verifiers reject unregistered prefixes.
>
> **Reference implementation.** Receipts are issued by the proprietary CSS engine; the reference
> verifier (`sr-verify`, maintained by Continuity Laboratories, including the hosted
> in-browser verifier at <https://continuitylaboratories.com/verify>) is held
> byte-compatible with it by the conformance corpus, which independent
> implementations validate against equally.
> This specification covers the wire format and its **verification** only.



**Status:** Draft, published for review. The wire format is pinned by golden
test vectors; changes follow the evolution rules in §9.
**Reference verifier:** `sr-verify receipt` (maintained by Continuity Laboratories) —
a standalone offline verifier.
**Worked example:** [`corpus/ahr-v0.2/r1/golden.json`](../corpus/ahr-v0.2/r1/golden.json)
— a complete, valid v0.2 receipt, pinned byte-for-byte by the corpus
([`corpus/ahr-v0.1/r1/golden.json`](../corpus/ahr-v0.1/r1/golden.json) is the frozen
v0.1 vector).

An **Authority-Handoff Receipt** is a portable JSON document that proves one completed,
policy-gated transfer of authority between two agents (stewards), including the obligation
and commitment lineage the transfer carried forward. It is designed to be verified
**offline, by parties who do not run CSS**: everything needed to check it — the evidence
events, their hashes, their signatures, and the issuer's signature over the whole — is in
the document itself, plus the issuer's public key(s).

The receipt answers, verifiably: *who held this authority, who holds it now, under what
legitimacy determination did the transfer run, which obligations and commitments carried
forward, and what recorded evidence supports each of those claims.*

---

## 1. What a receipt attests — and what it does not

A valid receipt attests that the issuing registry **recorded**:

- a succession that was proposed, validated, approved under a named legitimacy
  evaluation, and completed (the succession state machine permits no other path to
  Completed);
- the revocation of each predecessor authority the completion superseded, with the
  succession recorded as its basis;
- the derivation of the successor's authority, bound to the successor's accountability
  chain, with its scope;
- the inheritance of every obligation and commitment the transfer carried; and
- the replacement of the predecessor steward.

A receipt does **not** attest that anything outside the registry was enforced. CSS
refusals gate ledger transitions, not external agent actions (see the scope-of-enforcement
note in the README and the
threat model). A receipt is evidence of *recorded,
policy-gated authority state* — the artifact an integrator, auditor, or counterparty
checks before honoring a successor agent.

## 2. Data model

A receipt is a single JSON object. It is **shaped like a W3C Verifiable Credential 2.0**
(same top-level members, so VC-aware tooling can carry it), but it is plain JSON: JSON-LD
processing is not required, and the proof is the CSS suite defined in §3, not a W3C Data
Integrity suite (§8 discusses interop honestly).

| Member | Type | Description |
|---|---|---|
| `@context` | array of string | Exactly `["https://www.w3.org/ns/credentials/v2", "urn:css:ahr:v0.2"]` (v0.1 receipts carry `urn:css:ahr:v0.1`). Informative; identifies the vocabulary. |
| `type` | array of string | Exactly `["VerifiableCredential", "AuthorityHandoffReceipt"]`. |
| `spec_version` | string | `"0.2"` (published: `"0.1"`, `"0.2"`). Bumps on breaking wire-format or claim-semantics change (§9); verifiers reject versions they do not implement. |
| `issuer` | object | `{"id": <string>}` — identifies the issuing registry operator. Default `"urn:css:registry"` when the operator has not configured one. |
| `validFrom` | string (RFC 3339) | The timestamp of the `SuccessionCompleted` evidence event. The authority state the receipt describes holds from this instant. |
| `credentialSubject` | object | The claims (§2.1). |
| `evidence` | array of object | The grounding event envelopes, verbatim (§2.2). |
| `proof` | object | The issuer's signature over the canonical receipt (§3). Present on issued receipts; a receipt without `proof` MUST fail verification. |

### 2.1 `credentialSubject` — the claims

| Member | Type | Description |
|---|---|---|
| `id` | string | `"urn:uuid:" + succession_id`. |
| `succession_id` | UUID | The succession this receipt describes. |
| `predecessor.steward_id` | UUID | The outgoing steward. |
| `predecessor.identity_id` | UUID, optional | The identity bound at the predecessor's assignment, when on record. |
| `predecessor.revoked_authorities` | array | Every authority the completion superseded: `{"authority_id": UUID, "revocation_basis": string}`. The basis records the succession (`"superseded by succession <id>"`). Empty array when the predecessor held none. |
| `predecessor.replaced` | bool | Whether a `StewardReplaced` event is on record. |
| `successor.steward_id` | UUID | The incoming steward. |
| `successor.identity_id` | UUID, optional | The identity bound at the successor's assignment, when on record. |
| `successor.authority_id` | UUID | The succession-derived authority. |
| `successor.authority_scope` | string | The derived authority's scope, verbatim from `AuthorityGranted`. |
| `successor.accountability_chain_id` | UUID | The accountability chain the authority is bound to (GIR2). |
| `successor.authority_status` | string | `"granted"` — derived but not yet validated into force (post-succession governance review still open) — or `"active"` — an `AuthorityValidated` event is on record. |
| `legitimacy.legitimacy_id` | UUID | The legitimacy evaluation the transfer ran under (recorded by `SuccessionApproved`). |
| `legitimacy.legitimacy_state` | string, optional | The determined state (`"L3"`, `"L4"`, `"L5"`), when the determination event is on record. |
| `obligations_carried` | array of UUID | Every obligation inherited by the successor in this completion. Sorted lexicographically. |
| `commitments_carried` | array of UUID, optional | Every commitment inherited. Sorted lexicographically; omitted when none. |
| `constitution` | object | **v0.2, required.** The constitutional lineage the handoff ran under: `genesis_event_hash` (the `GenesisInitialized` event hash — the lineage root every deployment has exactly one of), `amendments_ratified` (count of `AmendmentRatified` events in force at completion), and `amendment_head_hash` (event hash of the latest such amendment; omitted when the count is 0). All referenced events are carried in `evidence`, so the claim is recomputable from the receipt alone: a verifier proves not just *that* the transfer was governed but *by which* constitution. Absent on v0.1 receipts. |
| `ledger_binding` | object | **v0.2, required.** The evidence horizon: `height` (1-based master-stream position of the receipt's final evidence event) and `event_hash` (that event's hash). Offline, the hash must match the final evidence event; against a [ledger export](./ledger-export.md) or an [anchored checkpoint](./external-anchoring.md), an auditor can additionally prove no correlated event at or below `height` was omitted — the completeness cross-check a bare evidence list cannot provide. Absent on v0.1 receipts. |
| `authorization_binding` | object | **Optional** (additive 2026-07-20 — no `spec_version` bump, §9). The cross-format authorization binding: when the handoff itself was authorized pre-execution as a material action under an authorization-receipt format, this claim binds that exact authorization to this exact transfer. Members, all strings: `caid` — the canonical action identifier of the handoff, verbatim (byte-identical) as it appears in the authorization receipt; `receipt_hash` — lowercase-hex SHA-256 over the canonical representation of the authorization receipt, as defined by its format; `format` — the authorization-receipt format identifier, naming the canonicalization to apply (`"EP-RECEIPT-v1"`; `"EP-QUORUM-v1"` for the multi-party case). Verified per §4 step 6 when present. When absent, the receipt verifies exactly as before this claim was defined and asserts no cross-format binding — neither format absorbs the other. |

### 2.2 `evidence` — the grounding events

Each evidence entry is one CSS event envelope, **verbatim as stored**:

```json
{
  "event_id": "…", "event_type": "…", "aggregate_type": "…", "aggregate_id": "…",
  "correlation_id": "…", "previous_event_id": "…", "timestamp": "…",
  "event_version": 1, "payload": { … }, "event_hash": "…", "signature": "…"
}
```

`event_hash` is the platform's SHA-256 event hash; `signature` (optional — absent in
unsigned deployments) is the platform's Ed25519 event signature. Both verify with the
rules in §4. `causation_id` and `actor_id` may also appear; they are carried verbatim
but play no role in receipt verification.

The evidence set for a receipt comprises: the succession stream (`SuccessionProposed`,
`SuccessionValidated`, `SuccessionApproved`, `SuccessionCompleted`); every event sharing
the completion's `correlation_id` (inheritance, chain linkage, authority supersession and
derivation, steward replacement); the steward assignment events binding each party's
identity; the `LegitimacyDetermined` event for the approving evaluation, when on record;
any `AuthorityValidated` on the derived authority's stream; and — v0.2 — the
`GenesisInitialized` event plus every `AmendmentRatified` recorded at or before the
completion in master-stream order (the constitution in force, §2.1). Entries are
deduplicated by `event_id` and sorted by `(timestamp, event_id)`.

Every claim in §2.1 corresponds to one or more evidence events; §4 step 4 defines the
correspondence normatively.

## 3. Canonicalization and proof

**Canonical form.** The canonical bytes of a receipt are the UTF-8 JSON serialization of
the receipt **with the `proof` member absent**, with:

- object members sorted lexicographically by key (byte order of the UTF-8 key),
- no insignificant whitespace,
- minimal string escaping (no HTML escaping; non-ASCII characters literal UTF-8).

The receipt value domain is strings, booleans, integers, arrays, and objects — no
floating-point numbers — so this coincides with RFC 8785 (JCS) output for every receipt
this spec can produce. Implementations MAY use a JCS library.

**Receipt hash.** `receipt_hash = lowercase hex( SHA-256( canonical bytes ) )`.

**Proof.** The issuer signs the **receipt hash string** (its ASCII bytes, not the raw
digest) — the same hash-then-sign discipline the platform applies to events and audit
records — with the registry's event-signing Ed25519 key:

| Member | Description |
|---|---|
| `type` | `"CSSEd25519Signature"`. |
| `created` | Proof timestamp (RFC 3339). Outside the signed content: re-issuing an identical receipt later yields the same `receipt_hash` and a different `created`. |
| `verification_method` | The signing `key_id` (operator-managed label; supports rotation). |
| `receipt_hash` | As defined above. Informative — verifiers MUST recompute it (§4). |
| `signature` | `"ed25519:<key_id>:<base64url-no-padding(signature)>"` — the platform's canonical signature format. |

## 4. Verification algorithm (normative)

Input: a receipt document and the issuer's Ed25519 public key(s), keyed by `key_id`.
A verifier MUST perform all six steps; any failure invalidates the receipt.

1. **Proof.** Reject if `proof` is absent. Compute the canonical bytes (§3) of the
   received document with `proof` removed; recompute `receipt_hash`; verify
   `proof.signature` over the **recomputed** hash string using the public key named by
   the signature's `key_id`. (Verifying against the recomputed hash — never the stored
   `proof.receipt_hash` — makes tampering with either the content or the stored hash
   fail closed.)
2. **Evidence integrity.** For every evidence event, recompute the event hash and reject
   on mismatch. The platform event-hash rule:

   ```
   event_hash = lowercase hex( SHA-256(
       event_id ∥ event_type ∥ aggregate_type ∥ aggregate_id
       ∥ RFC3339Nano(timestamp) ∥ decimal(event_version)
       ∥ payload_json ∥ previous_event_id_or_empty ) )
   ```

   UUIDs as lowercase hyphenated strings; `payload_json` is the payload's compact JSON
   serialization **in the stored field order** (the reference implementation restores
   each payload's concrete type from the event-type registry before re-serializing —
   generic re-serialization with re-ordered keys will not reproduce the hash).
   `correlation_id`, `causation_id`, `actor_id`, and `signature` are excluded from the
   hash by construction.

   *Framing note (2026-07-20, from the first external review).* The hash input
   concatenates adjacent variable-length fields with no length framing, so the map from
   field tuple to hash input is not injective in general — `event_type ∥
   aggregate_type`, two adjacent, individually unconstrained strings, is the sharp
   boundary. Within a receipt every evidence byte is additionally covered by the issuer
   proof (§3), but an event signature is a signature over the hash string alone and is
   therefore reusable wherever the same hash input can be reproduced. Verifiers SHOULD
   reject events whose `event_type` or `aggregate_type` fall outside the vocabulary the
   issuing format publishes — the conformance corpus pins the reference vocabulary, in
   which no two event types stand in a proper-prefix relation — and the next
   event-format version adopts length-prefixed hash components; published versions are
   never mutated (§9) and keep verifying under the current rule.
3. **Evidence authenticity.** For every evidence event carrying a `signature`, verify it
   over the event's `event_hash` string with the key named by its `key_id`. A present
   but invalid signature is a failure. An absent signature is **reported, not a
   failure** (unsigned deployments exist; the receipt proof from step 1 still covers the
   evidence bytes) — verifiers SHOULD surface signed/unsigned counts.
4. **Claim grounding.** Reject unless all of the following hold:
   - a `SuccessionCompleted` evidence event matches `succession_id`, and `validFrom`
     equals its timestamp; `credentialSubject.id` equals `"urn:uuid:" + succession_id`;
   - a `SuccessionProposed` evidence event names exactly the claimed predecessor and
     successor stewards;
   - a `SuccessionApproved` evidence event exists and, when it records a legitimacy ID,
     it equals `legitimacy.legitimacy_id`;
   - an `AuthorityGranted` evidence event matches the claimed successor authority
     (`authority_id`, `steward_id`, `authority_scope`, `accountability_chain_id`) and
     carries the completion's `correlation_id`;
   - if `authority_status` is `"active"`, an `AuthorityValidated` evidence event exists
     for the successor authority; `"granted"` requires nothing further; any other value
     is invalid;
   - if `predecessor.replaced` is true, a `StewardReplaced` evidence event exists for
     the predecessor;
   - each entry of `revoked_authorities` matches an `AuthorityRevoked` evidence event
     (ID and basis), **and every `AuthorityRevoked` evidence event is declared** — a
     receipt may neither invent nor conceal a revocation;
   - `obligations_carried` equals — as a set — the `ObligationInherited` evidence events
     naming the successor, and `commitments_carried` likewise for
     `CommitmentInherited` — a receipt may neither invent nor conceal carried lineage.
5. **Version claims.** Dispatch on `spec_version`; reject versions not implemented.
   - `"0.1"`: reject if `constitution` or `ledger_binding` is present (published versions
     are never mutated — v0.1 receipts carry neither claim).
   - `"0.2"`: reject unless all of the following hold:
     - **constitution (5a):** the claim is present; exactly one `GenesisInitialized`
       event is in evidence and its recomputed hash equals `genesis_event_hash`; the
       `AmendmentRatified` events in evidence recount to `amendments_ratified`, each
       timestamped at or before `validFrom`; when the count is 0, `amendment_head_hash`
       is absent, otherwise it equals the hash of the last `AmendmentRatified` in
       canonical evidence order;
     - **ledger binding (5b):** the claim is present; `event_hash` equals the recomputed
       hash of the **final** evidence event in canonical order; `height` is at least the
       evidence count. (The exact master-stream position is auditable against a ledger
       export or an anchored checkpoint, not from the receipt alone — §6.)
6. **Authorization binding (optional claim).** If
   `credentialSubject.authorization_binding` is absent, this step passes — the receipt
   asserts no cross-format binding. If present, reject unless the claim is well-formed:
   an object whose `caid` is a non-empty string, whose `receipt_hash` is exactly 64
   lowercase hex characters (SHA-256 — the platform-wide convention), and whose
   `format` is a non-empty authorization-format identifier; unknown additional members
   are ignored (§9). A verifier that also holds the authorization receipt MUST
   additionally recompute that receipt's canonical hash as its `format` defines and
   reject unless the recomputed hash equals `receipt_hash` and the authorization
   receipt's canonical action identifier equals `caid`, byte-identical. A verifier
   without the authorization receipt performs the well-formedness check only: the
   binding is then carried, proof-covered, for a consumer that can complete the
   cross-check.

The tamper matrix exercises each step's failure mode. The re-signed cases model a lying
issuer who alters content and re-signs the receipt: steps 2–4 catch every alteration
that leaves the receipt inconsistent with its carried evidence, even though step 1
passes. That is the precise strength of the claim — **internal consistency under the
issuer's key**, not tamper-proofness against the issuer: an issuer who also recomputes
evidence hashes and (holding the event-signing key, §3) re-signs the events produces an
internally consistent receipt for a history the ledger never recorded. Exposing that
requires the §6 instruments — the ledger itself, independently pinned event keys, or an
externally witnessed head.

## 5. Issuance

Receipts are assembled **read-only** from already-recorded events — issuance writes
nothing and cannot alter constitutional state. Receipts exist **only for completed
successions**: a proposed, rejected, or in-flight succession has no receipt. Deployments
running unsigned issue receipts without `proof`; such receipts fail §4 verification by
design — verifiable issuance requires signing to be configured.

Offline verification: `sr-verify receipt -receipt <file> -public-keys key_id=path[,…]`
— no database, no server, exit 0 iff the receipt verifies.

## 6. Trust model and limitations

- **Issuer-rooted.** A receipt proves what the issuing registry recorded, under the keys
  you trust for it. It does not prove the registry recorded everything — omission of an
  entire succession, or a receipt for a fork of history, is detectable only against the
  ledger itself (a full [ledger export](./ledger-export.md) replays the complete hash
  chain) or an external anchor ([external anchoring](./external-anchoring.md) defines
  periodic signed checkpoints of the head): a rollback by a
  storage-privileged insider after issuance is out of the receipt's detection scope,
  though any receipt already in a counterparty's hands becomes durable evidence against
  exactly that class of tampering. Deployments wanting stronger-than-issuer evidence
  SHOULD pin the event-signing key independently of the receipt-issuing key and/or
  witness the ledger head externally — then a compromised issuer key alone can no
  longer fabricate internally consistent evidence.
- **Evidence subset, not chain proof.** Evidence events verify individually (hash +
  signature) but are a cross-stream subset: a receipt does not prove stream contiguity
  or completeness of the surrounding ledger. Chain-position verification is the ledger's
  job (`sr-verify ledger` over a full export); the two-direction rules in §4 step 4 do
  guarantee the receipt cannot misstate the lineage *within its own evidence*, and —
  v0.2 — the `ledger_binding` claim states the master-stream position the evidence
  extends to, so an auditor holding a ledger export or an anchored checkpoint can prove
  no correlated event at or below that height was omitted.
- **Key trust is out of band.** Distribution, rotation, and pinning of the registry's
  public keys follow [`keyset.md`](./keyset.md). `key_id` labels support rotation;
  verifiers hold a key set.
- **No revocation of receipts.** A receipt is a statement about recorded history at
  `validFrom`; later constitutional events (a further succession, an authority
  revocation) do not invalidate it — they produce newer receipts. Consumers MUST treat
  `authority_status` as of `validFrom` and check for newer successions when currency
  matters.

## 7. Worked example

[`corpus/ahr-v0.1/r1/golden.json`](../corpus/ahr-v0.1/r1/golden.json)
is a complete valid receipt over a fixed succession (deterministic UUIDs, timestamps, and
a published test key), pinned byte-for-byte by the corpus. Its vector
key is the Ed25519 seed `00 01 02 … 1f` under `key_id` `ahr-vector-1` — an implementer
can reproduce every hash and signature in the file from this spec alone. Canonical
receipt hash of the vector:

```
8b32bca8faaee70b2ff41cfffa4ff5ef0f51f024af18553dc01676310984cf9f
```

## 8. Interoperability

**W3C Verifiable Credentials 2.0.** The receipt reuses the VC envelope members
(`@context`, `type`, `issuer`, `validFrom`, `credentialSubject`, `proof`) with compatible
semantics, so credential-shaped tooling (wallets, registries, policy engines that route
VCs) can carry receipts unmodified. It is **not** a conformant VC: the proof suite is the
CSS discipline of §3 rather than a registered Data Integrity cryptosuite, `issuer.id` and
`credentialSubject.id` are URNs rather than resolvable DIDs, and no JSON-LD context
resolution is defined. If a conformant profile is wanted later, the migration path is an
`eddsa-jcs-2022` proof alongside the CSS proof — the canonical form in §3 was chosen to
be JCS-compatible precisely to keep that door open (additive, §9).

**in-toto / SLSA.** A receipt is conceptually an attestation in the in-toto sense —
signed evidence that a step (the handoff) was performed by authorized parties under a
policy (the constitutional gates). The `evidence` array plays the role of link metadata;
the succession state machine plays the role of the layout. Mapping a receipt onto an
in-toto attestation predicate (`predicateType: urn:css:ahr:v0.1`) is mechanical if an
integration needs it.

## 9. Evolution and stability

The stability contract mirrors the platform's
event schema evolution strategy:

- **Additive changes** (new optional members, new optional claims) do not bump
  `spec_version`; verifiers MUST ignore unknown members (they are covered by the
  canonical form and the proof, but carry no verification rules).
- **Breaking changes** (member removal/rename, canonicalization or proof changes,
  claim-semantics changes) bump `spec_version`; verifiers reject versions they do not
  implement.
- The golden vector pins the v0.1 wire format: any byte-level drift fails the
  conformance corpus and forces an explicit versioning decision.
- Evidence envelopes evolve under the platform's own rules (`event_version` +
  upcasters); receipts always carry events **verbatim as stored**, so receipt
  verification is independent of upcasting (which sits strictly above stored history).
