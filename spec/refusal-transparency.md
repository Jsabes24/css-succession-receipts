# CSS Refusal Digest — v0.2 (draft)

> **Publication note (Succession Receipts).** This specification is published as part
> of **Succession Receipts** — the open verification surface for CSS evidence — see the repository README for scope. Published
> versions: **v0.1** (frozen — never mutated) and **v0.2** "Vigilance" (current, draft;
> adds seeded variation — the required `run.seed` and the derivation checks behind it,
> §2.2). The wire format of each version is pinned by its golden vectors in
> [`corpus/`](../corpus/) and validated by the conformance corpus in this repository;
> independent verifier implementations conform by passing it — for **every** published
> version.
>
> **Stability ladder.** v0.1 (draft) → v0.2 (draft) → v1.0 (stable). A published version is never
> mutated: format changes only ever add a new version with new golden vectors, and
> conforming verifiers keep verifying every published version. Corpus revisions
> (`r1`, `r2`, …) are additive snapshots, never edits.
>
> **Algorithm registry.** Signatures use the canonical
> `<alg>:<key_id>:<base64url(signature)>` string. `ed25519` (hash-then-sign over the
> hex SHA-256 of the canonical bytes) is the sole registered algorithm at v0.1 and
> v0.2. New algorithms are additive prefixes registered by a new spec version;
> verifiers reject unregistered prefixes.
>
> **Reference implementation.** Digests are produced by the proprietary CSS engine; the reference
> verifier (`sr-verify`, maintained by Continuity Laboratories, including the hosted
> in-browser verifier at <https://continuitylaboratories.com/verify>) is held
> byte-compatible with it by the conformance corpus, which independent
> implementations validate against equally. This specification covers the wire format and its **verification** only.

A **refusal digest** (`css-refusal-digest`) is the signed record of a *standing
adversarial probe run*: a suite of known attacks executed against a governance
system on a cadence, where the product being demonstrated is what the system
**refused**. Each probe carries the attack's framing, the guard expected to
refuse it, the system's verbatim refusal ground, and the complete signed event
ledger of the isolated attempt — in which the refused transition is **provably
absent**. The digest turns "our system refuses these attacks" from a marketing
claim into an artifact anyone can verify offline: no database, no server, no
trust in the issuer's infrastructure.

**v0.2 "Vigilance"** answers the canned-transcript objection: a v0.2 digest
carries the run's variation seed, and every quantity that varies between runs
— the staged identities of each probe's setup, the order of its independent
staging steps — derives deterministically from it (§2.2). A verifier
recomputes the derivations and requires the probe ledgers to have used them,
so a replayed ledger cannot match a fresh seed, while every run stays
independently recomputable. What is attacked and what must refuse it never
vary.

## 1. What a digest attests — and what it does not

A verified digest establishes, offline:

- **The run is the issuer's attestation.** The digest is signed over its full
  canonical content; every probe ledger event is hash-verified and (when
  signed) signature-verified. At v0.1 the run attestation is always `"self"`:
  the operator attests its own run. Independently countersigned runs are a
  future version's addition.
- **Each refusal is grounded.** A refused probe carries the verbatim refusal
  message the producing system emitted — the reason, not just the outcome.
- **The refused transition is absent.** Each probe declares the event types
  its attack would have appended had it succeeded; verification fails any
  refused probe whose ledger contains one. The ledger's per-event hashes and
  signatures make that absence a property of a tamper-evident record, not of
  trust in the reporter.
- **The headline is recounted.** `summary.attempted` and `summary.refused`
  must equal what the probes themselves show; a digest cannot claim a score
  its own contents do not support.

A digest does **not** attest that the probe suite is complete or adversarially
sufficient — it proves what was attempted and refused, not that nothing else
would succeed. It also does not, by itself, prove *when* the run occurred:
`run.started_at`/`run.completed_at` are issuer statements unless the digest is
separately anchored (see the external-anchoring specification).

A digest that honestly records a **failed** run — a guard that did not fire —
still *verifies*: validity and `all_refused` are separate statements (§4), so
a bad day is a published fact rather than a silent gap.

## 2. Data model

A digest is one JSON document:

| member | type | meaning |
|---|---|---|
| `spec` | string | `"css-refusal-digest"` |
| `spec_version` | string | `"0.2"` (published: `"0.1"`, `"0.2"`); verifiers reject versions they do not implement |
| `issuer` | object | `{ "id": <string> }` — who ran the probes and signed the digest |
| `run` | object | `{ "started_at", "completed_at": <RFC 3339>, "attestation": "self", "seed": <hex> }` — `seed` is **v0.2, required**: the run's variation seed, exactly 64 lowercase hex characters (32 bytes; §2.2). Absent on v0.1 digests — a v0.1 digest carrying a seed is malformed. |
| `probes[]` | array | the attempted attacks (§2.1); at least one |
| `summary` | object | `{ "attempted", "refused": <int> }` — restated, verification recounts |
| `proof` | object | the issuer's signature over the canonical bytes (§3) |

### 2.1 `probes[]`

| member | type | meaning |
|---|---|---|
| `id` | string | stable slug, unique within the digest |
| `name` | string | human-readable attack name |
| `attack` | string | what was attempted |
| `guard` | string | the rule expected to refuse it |
| `outcome` | string | `"refused"` or `"unexpected_pass"` |
| `refusal_ground` | string | the producing system's verbatim refusal message; required when refused |
| `engine_summary` | string | optional narrative of what the run showed |
| `forbidden_event_types[]` | array | event types the attack would have appended had it succeeded; at least one |
| `events[]` | array | the complete event ledger of the probe's isolated attempt |

Each probe runs on an **isolated, freshly constructed system instance**, so its
`events` list is the complete ledger of that attempt and probes cannot
contaminate one another. Events are the platform's standard envelopes — the
same shape ledger exports carry — with `event_hash` per the platform
event-hash rule (SHA-256 over the envelope's identifying fields plus the
payload bytes re-serialized in document key order; see the ledger-export
specification §2) and an optional `signature` over the stored `event_hash`
string.

### 2.2 Seeded variation (v0.2)

Every quantity that varies between v0.2 runs derives deterministically from
`run.seed`:

- **Derived identifiers** — the staged actors and aggregates of each probe's
  setup are UUIDv5 chains: a run namespace
  `NS = UUIDv5(NS_URL, "css-refusal-digest/v0.2|" + seed)` (where `NS_URL` is
  the RFC 4122 URL namespace, `6ba7b811-9dad-11d1-80b4-00c04fd430c8`), then
  each staged identifier `UUIDv5(NS, "<probe-id>|<quantity-label>")`.
- **Orderings** — where a probe's staging has causally-independent steps,
  candidates are ordered by the hex digest of
  `SHA-256(seed_bytes || "<probe-id>|<candidate-label>")`, ascending
  (`seed_bytes` is the 32-byte decoded seed).

**What never varies — the line the claim lives on:** the probe set and each
probe's `id`, the guard under test, the attack's semantics, and
`forbidden_event_types`. Vary those and runs stop being independently
recomputable — a reader could no longer say *what* was attacked, only that
something was. Variation exists to defeat the canned-transcript objection (a
replayed ledger cannot match a fresh seed), never to make the attack itself a
moving target.

The **derivation table** for the standing probe suite — the labels a verifier
recomputes and checks (§4 step 5), pinned by the
[`refusal-v0.2` corpus](../corpus/refusal-v0.2/):

| probe id | identifier labels (must appear as an `aggregate_id` in the probe's ledger) | ordered pair |
|---|---|---|
| `false-restoration` | `steward`, `chain`, `intent-evidence`, `recovery` | (`chain`, `intent-evidence`) |
| `uninherited-authority` | `steward`, `chain`, `intent-evidence`, `recovery` | (`chain`, `intent-evidence`) |
| `illegal-amendment` | `amendment` | — |
| `clock-overreach` | `successor-steward`, `successor-identity`, `predecessor-chain`, `successor-chain`, `succession` | — (the attack-route order is also seed-derived, but refused routes append no events, so it has no ledger check) |

Stagings may derive further identifiers beyond the table (they vary with the
seed like everything else); the table names the ones a verifier MUST check.
Probes not in the table — a grown suite — still get the whole of §4 plus the
seed structure rule.

**Seed choice is deliberately unconstrained**: because nothing seed-derived
affects what is attacked or what must be refused, grinding seeds buys an
operator nothing — any seed's run must refuse. RECOMMENDED: chain runs by
`seed = hex(SHA-256(ASCII bytes of the previous digest's hex digest_hash))`,
which makes a sequence of digests self-linking — the streak claim ("N
consecutive runs, all refused") inherits the same tamper evidence as the
digests themselves.

## 3. Canonicalization and proof

The canonical form is the digest document with the `proof` member absent,
serialized as UTF-8 JSON with lexicographically sorted keys, no insignificant
whitespace, and no HTML escaping — for this value domain (strings, integers,
arrays, objects; no floats) this coincides with RFC 8785 (JCS). The proof:

```json
"proof": {
  "type": "CSSEd25519Signature",
  "created": "2026-07-11T00:00:00Z",
  "verification_method": "<key_id>",
  "digest_hash": "<hex SHA-256 of the canonical bytes>",
  "signature": "ed25519:<key_id>:<base64url>"
}
```

The signature is over the **hex hash string** (hash-then-sign, the platform
discipline). `proof.created` sits inside the excluded `proof` member, so
re-signing identical content yields the same `digest_hash`.

## 4. Verification algorithm (normative)

1. **Structure.** `spec` must match §2 and `spec_version` must be a version
   the verifier implements (`"0.1"` or `"0.2"`); per version, the seed rule:
   a v0.1 digest must carry **no** `run.seed`, a v0.2 digest must carry one
   of exactly 64 lowercase hex characters. `run.attestation` must be
   `"self"` (the only value defined at v0.1 and v0.2); at least one probe;
   every probe has a unique non-empty `id`, a non-empty
   `forbidden_event_types`, an `outcome` from the closed vocabulary, and —
   when refused — a non-empty `refusal_ground`.
2. **Proof.** The digest must carry a proof, and verification requires trusted
   keys: unlike ledger exports there is no integrity-only mode, because the
   refusal claim *is* the issuer's attestation. Recompute the canonical hash;
   it must equal `digest_hash`; the signature must verify against the named
   key.
3. **Probe evidence.** For every event of every probe: recompute `event_hash`
   per the platform event-hash rule; a present `signature` must verify against
   the trusted keys (absent signatures are counted as unsigned, never failed).
4. **Absence.** For every **refused** probe: no event's `event_type` may
   appear in the probe's `forbidden_event_types`. This is the digest's central
   claim — the refused transition is not on the record.
5. **Seed derivation (v0.2 only).** For every probe in the derivation table
   (§2.2): recompute the derived identifiers from `run.seed`; each MUST appear
   as an `aggregate_id` in that probe's ledger. For a probe with an ordered
   pair: the first occurrences of the pair's derived ids must appear in the
   seed's order (first-occurrence index in `events[]`). Probes the verifier's
   table does not cover are exempt from this step only.
6. **Summary.** Recount: `summary.attempted` must equal the number of probes,
   `summary.refused` the number whose outcome is `"refused"`. Report
   `all_refused = (refused == attempted)` from the recount, never from the
   stored summary.

A digest failing any step is invalid. A valid digest with
`all_refused = false` is an honest record of a failed run; consumers gating on
the headline claim (e.g. `sr-verify refusal` without `-allow-not-refused`)
should treat it as a failure with the digest itself as the evidence.

## 5. Trust model and limitations

- **Self-attestation (v0.1).** The issuer runs its own probes. The digest
  proves internal consistency, grounded refusals, and transition absence — it
  does not prove the probes were adversarially chosen or the run un-curated.
  Cadenced publication (so gaps are visible), anchoring (so timing is
  provable), and third-party countersigned runs (a future version) each
  tighten that.
- **Key custody.** A digest is exactly as trustworthy as the binding between
  the issuer and the verification keys the consumer supplies. Keys travel out
  of band (the keyset specification applies).
- **A complicit issuer cannot rewrite history quietly.** Because every probe
  event is individually hashed and signed, even the holder of the issuing key
  cannot alter a probe ledger without either breaking per-event verification
  or producing detectably re-signed events — the conformance corpus's
  `*-resigned` tamper cases pin exactly this.
- **A canned transcript cannot follow a fresh seed (v0.2).** The staged
  identities in a probe ledger are derived from `run.seed`, so replaying a
  previously-recorded ledger under a new seed fails the derivation checks —
  even fully re-signed by the issuing key. The corpus's `seed-flipped`,
  `derivation-mismatch` and `ordering-violated` cases pin this: the seed rows
  are exactly the forgeries only §4 step 5 refuses.
- **Artifact and suite binding (future — v0.3 asks, recorded from the first
  external review, 2026-07-19/20).** A digest proves the probes ran and were
  refused, but binds neither *what code attacked* (no probe-suite digest) nor
  *what build was attacked* (no engine artifact digest), so "the deployed
  production engine was probed" rests on the operator's word even when the
  digest verifies — the self-attestation scope above, stated from the other
  direction. Candidate v0.3 fields: `run.suite_digest` (hash of the pinned
  probe-suite source or binary) and `run.artifact` (engine version/commit plus
  a binary digest or build attestation), with an independent challenger or
  witness as the party that checks them.

## 6. Conformance

The corpora pin this format, one directory per published version — an
implementation that passes both conforms, and conforming verifiers keep
verifying every published version:

- [`corpus/refusal-v0.1/`](../corpus/refusal-v0.1/) — the golden vector must
  verify; every tamper case must fail at exactly the `failing_check` its
  manifest names (`structure`, `proof`, `event_hash`, `event_signature`,
  `forbidden_event`, `summary`).
- [`corpus/refusal-v0.2/`](../corpus/refusal-v0.2/) — the seeded golden
  vector (the published byte(i) seed, its ledgers using the derived
  identifiers in the derived order) must verify; the v0.1 transform set
  applies over it, plus the seed rows: wire-rule malformations fail at
  `structure`, and the fully re-signed derivation forgeries — flipped seed,
  swapped aggregate id, violated block order — fail at `seed_derivation`.

Published revisions are immutable; new cases arrive as new revisions
(`r2`, …), and new format versions as new directories with their own golden
vectors.

## 7. Relationship to the other Succession Receipts formats

The digest composes with the family rather than duplicating it: probe events
are CLE-shaped envelopes (ledger-export spec §2); the proof is the standard
artifact proof (§3 here, identical discipline to receipts and exports); and an
anchored deployment can bind digests into its checkpoint chain
(external-anchoring spec) so a digest's existence time becomes provable. A
governance system that publishes receipts for what it *did*, exports for what
it *recorded*, and digests for what it *refused* is verifiable on all three
axes with one toolchain.
