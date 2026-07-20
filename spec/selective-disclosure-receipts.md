# CSS Selective-Disclosure Receipts (SDR) — v0.1 (draft)

> **Publication note (Succession Receipts).** This specification is published as part
> of **Succession Receipts** — the open verification surface for CSS evidence — see the repository README for scope. Published
> versions: **v0.1** (current, draft). The wire format is pinned by its golden vectors
> in [`corpus/`](../corpus/) and validated by the conformance corpus in this
> repository; independent verifier implementations conform by passing it — for
> **every** published version.
>
> **Stability ladder.** v0.1 (draft) → v1.0 (stable). A published version is never
> mutated: format changes only ever add a new version with new golden vectors, and
> conforming verifiers keep verifying every published version. Corpus revisions
> (`r1`, `r2`, …) are additive snapshots, never edits.
>
> **Algorithm registry.** Signatures use the canonical
> `<alg>:<key_id>:<base64url(signature)>` string. `ed25519` (hash-then-sign over the
> hex SHA-256 of the canonical bytes) is the sole registered algorithm at v0.1. New
> algorithms are additive prefixes registered by a new spec version; verifiers reject
> unregistered prefixes.
>
> **Reference implementation.** SDRs are issued by the proprietary CSS engine; the reference
> verifier (`sr-verify sdr`, maintained by Continuity Laboratories, including the hosted
> in-browser verifier at <https://continuitylaboratories.com/verify>) is held
> byte-compatible with it by the conformance corpus, which independent
> implementations validate against equally. This specification covers the wire format and its **verification** only.

**Status:** Draft, published for review. The wire format is pinned by golden test
vectors; changes follow the evolution rules in §10.
**Companion format:** the [Authority-Handoff Receipt](./authority-handoff-receipts.md)
(AHR) v0.2 — an SDR carries exactly the AHR v0.2 claim set, restructured for
disclosure. SDR versions independently of AHR; SDR v0.1 pins the AHR v0.2 claim
semantics.
**Worked examples:** [`corpus/sdr-v0.1/r1/golden.json`](../corpus/sdr-v0.1/r1/golden.json)
— a complete, valid v0.1 SDR (every commitment opened) — and
[`corpus/sdr-v0.1/r1/golden-regulator.json`](../corpus/sdr-v0.1/r1/golden-regulator.json)
— the §5.1 regulator projection of the **same signed document**, pinned byte-for-byte
by the corpus. The vectors reproduce from this document alone: the published test salts
derive per path as `hex(SHA-256("sdr-vector-1|" + path))` (production salts are
CSPRNG-only, §2.3).

An Authority-Handoff Receipt is all-or-nothing: whoever holds it holds every claim and
every evidence event. That is right for the parties to the handoff and wrong for almost
everyone else — a regulator, a counterparty, and the public are each entitled to
*different projections of the same signed fact*. A **Selective-Disclosure Receipt** is
the receipt rebuilt for that reality: the issuer signs **salted commitments** to each
claim and each evidence event, the disclosures travel outside the signature, and a
**projection** — the envelope plus any subset of the disclosures — still verifies against
the one issuer signature. Withholding never breaks the proof, and disclosing never
requires re-signing. One signature, many audiences: the authority proof at every
entitlement level.

---

## 1. What a projection attests — and what it does not

A verified projection establishes, offline:

- **The issuer signed the whole receipt** — the proof covers every commitment, disclosed
  or not. No party can add, alter, or substitute a claim after issuance; a holder can
  only *withhold*.
- **Every disclosed claim is exactly what the issuer committed to** — each disclosure
  reopens one salted commitment; a digest mismatch is fatal.
- **Disclosed evidence is genuine engine output** — disclosed evidence events verify
  hash-by-hash and signature-by-signature, exactly like AHR evidence.
- **Withholding is visible, never silent** — the commitment arrays are inside the signed
  envelope, so a verifier always knows *how many* claims and evidence events exist and
  which of them it is not seeing. An undisclosed claim is known-withheld, never absent.

A projection does **not** attest what it withholds. Grounding — the claim↔evidence
correspondence that makes an AHR strong — runs over the disclosed subset only (§4 step
5), and the completeness rules ("may neither invent nor conceal") require the complete
projection (§4.2). A projection that hides the predecessor's revoked authorities proves
nothing about them either way; what it can never do is misrepresent them. And, as with
the AHR, nothing here attests enforcement outside the registry: an SDR is evidence of
*recorded, policy-gated authority state*, projected.

## 2. Wire format

An SDR is a single JSON object. Canonicalization sorts keys (§3), so the wire bytes are
independent of field order — the same discipline as receipts, digests, ledger exports,
and anchor checkpoints.

### 2.1 The envelope (signed)

| Member | Type | Description |
|---|---|---|
| `@context` | array of string | Exactly `["https://www.w3.org/ns/credentials/v2", "urn:css:sdr:v0.1"]`. |
| `type` | array of string | Exactly `["VerifiableCredential", "SelectiveDisclosureReceipt"]`. |
| `spec_version` | string | `"0.1"`. Bumps on breaking change (§10); verifiers reject versions they do not implement. |
| `issuer` | object | `{"id": <string>}` — the issuing registry operator (default `"urn:css:registry"`). |
| `validFrom` | string (RFC 3339) | The `SuccessionCompleted` timestamp, as in the AHR. In clear deliberately: it anchors *when* the attested state holds (and see §7 row 8). |
| `credentialSubject` | object | Exactly `{"id": "urn:uuid:" + succession_id, "succession_id": <UUID>}` — the subject pointer stays in clear: a receipt no one can address answers nothing. Every other claim lives behind a commitment. |
| `sd` | object | The disclosure commitments (§2.2). |
| `proof` | object | The issuer's signature over the canonical envelope (§3). |

### 2.2 `sd` — the disclosure commitments

| Member | Type | Description |
|---|---|---|
| `alg` | string | `"sha-256"` (v0.1's only value). |
| `claims` | array of string | Exactly **seven** digests (§2.4 fixes the unit set), lowercase hex, sorted lexicographically, unique. Fixed cardinality is deliberate: the claim-commitment count itself reveals nothing about the handoff. |
| `evidence` | array of string | One digest per evidence event, lowercase hex, sorted lexicographically, unique, at least one. (The count reveals the evidence-set size — §7 row 6.) |

Sorting is the wire order only — it carries no information about disclosure order or
evidence order. Canonical evidence order (`(timestamp, event_id)`, as in the AHR)
re-emerges from the disclosed events themselves.

### 2.3 Disclosures (outside the signature)

The issued document carries the full disclosure set in a top-level `disclosures` array;
a projection carries any subset (including, degenerately, none). **`disclosures` is
excluded from the canonical form (§3)** — redacting entries is the projection mechanism
and never touches the signature.

One disclosure:

| Member | Type | Description |
|---|---|---|
| `salt` | string | 64 lowercase hex characters (32 bytes). Fresh from a CSPRNG per disclosure per issuance; never reused across units or issuances (§7 row 3). |
| `path` | string | The disclosure unit (§2.4): a claim-unit path, or `"evidence/" + event_id`. |
| `value` | JSON | The unit's value, verbatim (§2.4). |

**Commitment rule.** The digest of a disclosure is:

```
digest = lowercase hex( SHA-256( canonical bytes of [salt, path, value] ) )
```

— the three-element JSON array serialized under the §3 canonical rules (elements in
array order; object keys inside `value` sorted; no insignificant whitespace; minimal
escaping). An issuer puts each digest in `sd.claims` or `sd.evidence`; a verifier
recomputes it from the disclosure and requires membership (§4 step 3).

### 2.4 The v0.1 disclosure units

Disclosure granularity is pinned as data, like the
[refusal digest](./refusal-transparency.md)'s derivation table — implementations and
the golden vector agree on exactly these units:

| Path | Value |
|---|---|
| `credentialSubject/predecessor` | The AHR `predecessor` object, verbatim (steward, optional identity, `revoked_authorities`, `replaced`). |
| `credentialSubject/successor` | The AHR `successor` object, verbatim (steward, optional identity, authority, scope, chain, status). |
| `credentialSubject/legitimacy` | The AHR `legitimacy` object, verbatim. |
| `credentialSubject/obligations_carried` | The full array of inherited obligation IDs, sorted lexicographically; possibly empty. |
| `credentialSubject/commitments_carried` | The full array of inherited commitment IDs, sorted lexicographically; possibly empty. **Always a unit** — the AHR's omit-when-none rule does not apply here: under salted commitments, the empty set must be committed to, not omitted, or absence would be distinguishable from withholding. |
| `credentialSubject/constitution` | The AHR v0.2 `constitution` claim, verbatim. |
| `credentialSubject/ledger_binding` | The AHR v0.2 `ledger_binding` claim, verbatim. |
| `evidence/<event_id>` | One CSS event envelope, verbatim as stored (AHR §2.2) — one unit per evidence event; `<event_id>` is the event's lowercase hyphenated UUID. |

Array claims disclose as **whole units** in v0.1. Per-element disclosure of the lineage
arrays ("we carried 14 obligations; here are the 2 you are party to") is a recorded
evolution (§10), not a v0.1 capability — it changes the commitment cardinality rules and
the counting analysis in §7, so it arrives with its own version, never quietly.

The evidence set, its collection rules, and its canonical order are exactly the AHR's
(AHR §2.2): the SDR commits to the same events the equivalent AHR would carry.

## 3. Canonicalization and proof

**Canonical form.** The canonical bytes of an SDR are the UTF-8 JSON serialization of
the document **with the `proof` and `disclosures` members absent**, under the AHR §3
rules: object members sorted lexicographically by key, no insignificant whitespace,
minimal string escaping. The value domain excludes floating-point numbers, so this
coincides with RFC 8785 (JCS) output. The same rules canonicalize the `[salt, path,
value]` commitment input (§2.3).

**Proof.** Identical to the AHR §3 proof — `receipt_hash = lowercase hex(SHA-256(
canonical bytes))`, signed as an ASCII hash string with the registry's event-signing
Ed25519 key, carried as `CSSEd25519Signature` with `created` outside the signed content.
One authenticity discipline across the platform; nothing new to trust.

## 4. Verification algorithm (normative)

Input: a projection (envelope + zero or more disclosures) and the issuer's Ed25519
public key(s), keyed by `key_id`. A verifier MUST perform all six steps. Steps 1–4
failing invalidates the projection outright; step 5 distinguishes *fatal contradiction*
from *reported non-grounding*; step 6 applies to complete projections.

1. **Structure.** `@context`, `type`, `spec_version` match §2.1 exactly; `sd.alg` is
   `"sha-256"`; `sd.claims` has exactly seven entries and `sd.evidence` at least one,
   each 64 lowercase hex, sorted, unique; `credentialSubject` has exactly the two §2.1
   members with `id` equal to `"urn:uuid:" + succession_id`; every disclosure is
   well-formed (§2.3) with a path from the §2.4 table, and no path appears twice.
2. **Proof.** Reject if `proof` is absent. Compute the canonical bytes (§3) of the
   received document with `proof` and `disclosures` removed; recompute `receipt_hash`;
   reject unless it equals `proof.receipt_hash`; verify `proof.signature` over the
   **recomputed** hash string with the key named by the signature's `key_id`.
3. **Disclosure binding.** For every disclosure, recompute the commitment digest (§2.3)
   and reject unless it appears in `sd.claims` (claim-unit paths) or `sd.evidence`
   (evidence paths). Reject if two disclosures bind the same digest. For an evidence
   disclosure, reject unless its `path` equals `"evidence/" + value.event_id`.
4. **Evidence integrity and authenticity.** For every disclosed evidence event: restore
   the payload's concrete type from the event-type registry (the AHR normalization
   discipline — generic re-serialization will not reproduce the hash), recompute the
   platform event hash (fatal on mismatch), and verify a present signature (present but
   invalid is fatal; absent is reported, never a failure).
5. **Disclosed-claim grounding.** Recast of AHR §4 step 4 over the disclosed subset.
   Two baseline rules always apply:
   - if a disclosed `SuccessionCompleted` event matches `succession_id`, `validFrom`
     MUST equal its timestamp;
   - a disclosed claim **contradicted** by a disclosed evidence event is fatal —
     contradiction means a §4.1 rule whose required inputs are all disclosed and whose
     check fails.

   Each claim unit is then assigned a status: **`grounded`** — the unit is disclosed,
   every §4.1 rule for it had its required evidence disclosed, and all of them passed;
   **`disclosed`** — the unit is disclosed but at least one rule could not run for lack
   of disclosed evidence (nothing failed); **`undisclosed`** — the unit's commitment is
   unopened. The report carries all three per unit; what a consumer may *rely on* is the
   status, and a projection profile (§5) states which statuses it promises.
6. **Completeness escalation (§4.2).** If every digest in `sd.claims` and `sd.evidence`
   is bound by a disclosure, the projection is **complete**: the verifier MUST
   reconstruct the full claim set and enforce the entirety of AHR §4 steps 4–6 — both
   directions of the lineage and revocation rules ("may neither invent nor conceal"),
   the constitution recount (5a), the ledger binding (5b), and the optional
   authorization binding (step 6) when disclosed. Any failure is fatal. A
   complete projection is exactly as strong as the equivalent AHR v0.2.

The pass yields a report: `receipt_hash`, per-unit statuses, disclosed/undisclosed
evidence counts, signed/unsigned counts, and the `complete` flag. **"Verified" and
"grounded" are separate statements**, the same honesty split the refusal digest draws
between "valid" and "all refused": a projection can verify while grounding almost
nothing — it is then an issuer-signed assertion whose supporting record was withheld,
and the report says so per claim.

### 4.1 Per-unit grounding rules

Each rule names the evidence it needs. A rule whose evidence is not disclosed **cannot
run** — the unit's status caps at `disclosed`. A rule whose evidence is disclosed and
whose check fails is a **contradiction** — fatal (§4 step 5).

| Unit | Rules |
|---|---|
| `predecessor` | A disclosed `SuccessionProposed` for `succession_id` must name the claimed predecessor steward. Each `revoked_authorities` entry needs a disclosed `AuthorityRevoked` matching its ID; a disclosed match with a different basis is a contradiction. `replaced: true` needs a disclosed `StewardReplaced` for the predecessor. **Contradiction check that runs partially:** a disclosed `AuthorityRevoked` absent from the declared `revoked_authorities` contradicts the unit — the declared list is the complete claim. |
| `successor` | A disclosed `SuccessionProposed` for `succession_id` must name the claimed successor steward. Grounding the authority needs a disclosed `AuthorityGranted` matching `authority_id` — which must then match `steward_id`, `authority_scope`, and `accountability_chain_id`, and carry the completion's `correlation_id` (this last part additionally needs the disclosed `SuccessionCompleted`). `authority_status: "active"` needs a disclosed `AuthorityValidated` for the authority; `"granted"` needs nothing further; any other value is fatal wherever the unit is disclosed. |
| `legitimacy` | A disclosed `SuccessionApproved` for `succession_id` must record `legitimacy_id` (a nil-recorded ID constrains nothing, as in the AHR). A claimed `legitimacy_state` needs a disclosed `LegitimacyDetermined` for that evaluation, whose state must match. |
| `obligations_carried` | Each claimed ID needs a disclosed `ObligationInherited` with that obligation ID; when the `successor` unit is also disclosed, the event must name the claimed successor steward. **Contradiction check that runs partially:** when the `successor` unit is disclosed, a disclosed `ObligationInherited` naming the claimed successor whose obligation ID is absent from the claimed array contradicts the unit — the array is the complete claim. |
| `commitments_carried` | As `obligations_carried`, over `CommitmentInherited`. |
| `constitution` | Grounding needs a disclosed `GenesisInitialized` whose recomputed hash equals `genesis_event_hash`; two disclosed `GenesisInitialized` events, or one with a different hash, is a contradiction. When `amendments_ratified` > 0, grounding the head needs the disclosed `AmendmentRatified` whose recomputed hash equals `amendment_head_hash`; any disclosed `AmendmentRatified` postdating `validFrom` is a contradiction. When the count is 0, a present `amendment_head_hash` — or any disclosed `AmendmentRatified` at or before `validFrom` — is a contradiction. The **recount** of `amendments_ratified` belongs to step 6, not to this unit's grounding: a partial projection cannot prove an unopened commitment is not another amendment, so a grounded `constitution` on a partial projection pins genesis and head, and attests the count on the issuer's signature alone. |
| `ledger_binding` | Groundable **only on complete projections**: "final evidence event in canonical order" is a whole-set property. On a partial projection a disclosed `ledger_binding` reports `disclosed`, and remains what it is in the AHR — the horizon an auditor takes to a ledger export or an anchored checkpoint (AHR §6), out of band. |

The full completeness directions of the AHR rules — the lineage arrays equal to the
inheritance events *as sets* in both directions, every revocation declared regardless of
what else is disclosed — belong to step 6. The partial contradiction checks above catch
what is catchable from the disclosed subset; the rest is unenforceable on a partial
projection by construction, and this spec says so rather than pretending otherwise.

### 4.2 Complete projections

A complete projection is the SDR's own full-strength mode: every commitment opened,
AHR-equivalent verification enforced. It exists for two reasons: it is the **issuance
gate** (§6 — an SDR MUST verify complete before it leaves the issuer), and it is the
**holder's acceptance check** (a holder verifying the complete projection once knows
every future partial projection is a pure subset of an issuer-signed, fully-grounded
record — a lying issuer is caught at acceptance, not discovered by a regulator later).

## 5. Projection profiles

A profile is a named, published subset — which claim units and which evidence events a
projection discloses, and which per-unit statuses it promises. Profiles are agreements
about *what to disclose*; they add no cryptography. v0.1 pins one reference profile;
the others below are informative sketches a deployment tunes to its own payload content.

### 5.1 `regulator` — the reference profile (pinned)

The projection for an auditor entitled to the governance facts but not the business
surface.

| | Disclosed |
|---|---|
| Claim units | `legitimacy`, `constitution`, `ledger_binding` |
| Evidence events | `SuccessionCompleted`, `SuccessionApproved`, `LegitimacyDetermined` (when on record), `GenesisInitialized`, every `AmendmentRatified` |
| Withheld | `predecessor`, `successor`, `obligations_carried`, `commitments_carried`, and all other evidence — the business-identifying surface: authority scopes, revocation bases, lineage IDs, party bindings |

What the regulator can verify: succession `succession_id` completed at `validFrom`
(anchor rule, step 5); it was approved under legitimacy evaluation `legitimacy_id` at
the determined state (`legitimacy` **grounded**); it ran under the constitution rooted
at `genesis_event_hash` with the claimed amendment head (`constitution` **grounded** up
to the recount, which is issuer-attested here, not independently recounted); the
evidence extends to a stated ledger height (`ledger_binding` **disclosed**, auditable
against a CLE or anchored checkpoint out of band). Every disclosed payload in this
profile carries only pseudonymous UUIDs — the profile's disclosed event types
(`SuccessionCompleted`, `SuccessionApproved`, `LegitimacyDetermined`,
`GenesisInitialized`, `AmendmentRatified`) contain no scope strings, bases, or free
text by construction. The withheld remainder is visible as exactly four unopened claim
commitments and the undisclosed evidence digests: the regulator knows the shape of what
it is not seeing.

### 5.2 Informative sketches (not pinned in v0.1)

- **`counterparty`** — for a party deciding whether to honor the successor: disclose
  `successor`, `legitimacy`, `constitution`, and the evidence grounding them
  (`SuccessionProposed`, `SuccessionCompleted`, `SuccessionApproved`,
  `AuthorityGranted`, any `AuthorityValidated`, the genesis/amendment events). Reveals
  the successor's scope — that is the point — while withholding the predecessor's
  retired surface and the lineage arrays.
- **`public`** — the minimal standing statement: no claim units beyond the clear
  envelope, `SuccessionCompleted` alone disclosed. Proves *a governed handoff of this
  succession completed at this time under this issuer* — an existence proof with the
  entire record visibly committed but withheld.

## 6. Issuance

Like the AHR, an SDR is assembled **read-only** from already-recorded events — issuance
writes nothing and cannot alter constitutional state, and SDRs exist only for completed
successions. The builder collects the same claim values and evidence set the AHR
builder would, generates one fresh CSPRNG salt per disclosure (never logged, never
derived from content), assembles the commitment arrays, and signs the envelope with the
registry's event-signing key.

Issuance discipline (normative):

- The issuer MUST verify the **complete projection** (§4.2) before releasing an SDR; an
  SDR whose complete projection does not verify is never issued.
- The full disclosure set is delivered to the holder with the envelope. Projections are
  produced — by the holder, or by the issuer on request — by **dropping disclosures,
  never by re-signing**. There is no such thing as re-issuing a projection.
- A holder SHOULD verify the complete projection at acceptance (§4.2).
- An SDR and an AHR for the same succession MAY both exist; they are independently
  signed artifacts over the same recorded facts (§8).

## 7. Threat model

Assets: confidentiality of withheld claims and evidence; integrity and attributability
of disclosed ones; the verifier's ability to know what it is not seeing.

| # | Adversary / attack | Defense |
|---|---|---|
| 1 | **Forging holder** — alters a disclosed value, salt, or path | The commitment digest changes; membership in the signed `sd` arrays fails (§4 step 3). Fatal. |
| 2 | **Splicing holder** — presents a disclosure from a different receipt (same claim shape, even the same value) | Digest membership is per-envelope: a foreign disclosure's digest is not in this envelope's `sd` arrays. Salt freshness per issuance (§2.3) means even identical values commit differently across receipts. Fatal. |
| 3 | **Guessing verifier** — dictionary-attacks unopened commitments; several claim values are low-entropy (`replaced` is a boolean, `authority_status` a two-value enum, scopes are often short strings) | 256-bit salts from a CSPRNG, unique per disclosure, never reused. Without the salt, a commitment is unguessable regardless of the value's entropy. Salt reuse across units or issuances voids this — hence the MUST in §2.3. |
| 4 | **Lying issuer** — commits to claims the record does not ground, counting on partial projections to hide it | Same trust root as the AHR: issuer-rooted, caught by grounding. The complete-projection gates (§4.2, §6) put the catch at issuance and acceptance: a holder who verified complete once knows every projection it later makes is a subset of a grounded record. A regulator receiving only a partial projection relies on the reported per-unit statuses, not on trust. |
| 5 | **Concealing holder** — withholds inconvenient units and presents the projection as the whole story | Withholding is the feature, and it is **visible**: the commitment counts are signed, unopened digests are enumerable, and the §4 report names every undisclosed unit. What a projection cannot do is misrepresent — an undisclosed revocation is undisclosed, never deniable. Consumers decide sufficiency per profile (§5). |
| 6 | **Counting verifier** — infers structure from commitment counts | `sd.claims` is a constant seven (§2.2) and leaks nothing. `sd.evidence` leaks the evidence-set size (roughly: lineage volume and amendment count). Decoy digests would hide it but destroy complete-projection semantics (§4.2) — deliberately **not** in v0.1; recorded as evolution with explicit signaling if ever wanted (§10). |
| 7 | **Correlating verifiers** — two recipients of different projections link them | Projections of one SDR share `receipt_hash`, signature, and digest sets: they are trivially linkable, **by design and stated plainly**. Unlinkability across projections requires batch issuance (multiple salt-fresh SDRs over the same facts) — recorded evolution (§10), out of scope for v0.1. |
| 8 | **Correlating on clear fields** — `succession_id` and `validFrom` are visible in every projection | Deliberate floor (§2.1): the subject pointer makes the receipt answerable, the timestamp anchors when. Both are pseudonymous/temporal, not business-identifying; a deployment for which even these correlate too much wants batch issuance (row 7), not a mutated envelope. |
| 9 | **Ledger-linking recipient** — a disclosed evidence event carries its real `event_hash`, linkable to ledger exports, checkpoints, and other receipts carrying it | That is the point — disclosed evidence is *meant* to be auditable against the ledger's own instruments. It is also why evidence disclosure is per-event and deliberate: disclose what the profile grounds, no more. |
| 10 | **Forwarding recipient** — anyone holding a projection can pass it on; possession is not entitlement | True, and true of the AHR today. v0.1 defines no holder binding (no key-bound presentation); a recipient-bound presentation is recorded evolution (§10), aligned with SD-JWT's KB-JWT if wanted. Profiles are access decisions made at disclosure time; treat projections accordingly. |

## 8. Trust model and limitations

- **Issuer-rooted, exactly like the AHR** (AHR §6): an SDR proves what the issuing
  registry recorded, under keys you trust for it. Omission of an entire succession or a
  forked history is detectable only against the ledger and its anchors — not from any
  receipt, projected or not.
- **A projection is a floor, not a summary.** It proves the disclosed subset and the
  existence-with-shape of the remainder. Decisions needing the whole record need the
  complete projection (or the AHR).
- **No revocation of SDRs**, as with receipts: an SDR speaks as of `validFrom`; newer
  history produces newer receipts. Consumers check currency when it matters.
- **Coexistence with the AHR.** Both may exist for one succession; they are separate
  signed artifacts with different hashes. Nothing binds them cryptographically in v0.1
  (a deliberate omission — binding would make every projection linkable to the full
  receipt's hash by construction); their agreement is enforced by both being grounded
  in the same recorded events.
- **Key trust is out of band**, per the platform's signing-key operations; `key_id`
  supports rotation; verifiers hold a key set.

## 9. Interoperability

**SD-JWT / SD-JWT-VC.** The mechanism is deliberately the same as IETF SD-JWT
(salted per-claim digests inside the signed body; disclosures outside; projections by
omission), so the design inherits its analysis. The encoding is not: CSS receipts are
plain JSON canonicalized by the §3/JCS discipline with the platform's
`CSSEd25519Signature` proof, where SD-JWT is JWS-based with base64url-encoded
disclosure arrays. Deltas recorded honestly: no decoy digests (§7 row 6), no key
binding (§7 row 10), fixed unit granularity (§2.4). If a conformant SD-JWT-VC profile
is wanted later, the claim set maps mechanically and the migration is additive — the
same `eddsa-jcs-2022` door the AHR keeps open (AHR §8).

**W3C Verifiable Credentials.** The envelope keeps the VC shape the AHR established
(same members, same caveats — AHR §8): VC-aware tooling can carry a projection
unmodified; it is not a conformant VC.

## 10. Evolution

Versioning follows the AHR rules (AHR §9): additive optional members without a bump;
breaking changes (units, commitment rule, canonicalization, proof) bump `spec_version`;
published versions are never mutated; the golden vectors pin the wire format, and a new
version adds a corpus directory, never edits one.

**Recorded evolutions** (each arrives with a version and its own threat-model delta,
never quietly): per-element lineage disclosure; decoy digests with explicit signaling;
holder binding (key-bound presentations); batch issuance for cross-projection
unlinkability; service issuance route.
