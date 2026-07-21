---
title: "Refusal Transparency: Signed, Replay-Resistant Evidence of Refused Agent-System Transitions"
abbrev: "Refusal Transparency"
docname: draft-sabey-refusal-transparency-02
category: info
submissiontype: independent
ipr: trust200902
area: Security
workgroup: Individual Submission
keyword:
  - refusal transparency
  - adversarial probes
  - AI agents
  - signed evidence
  - offline verification
  - Ed25519

stand_alone: yes
pi: [toc, sortrefs, symrefs]

author:
  - ins: J. Sabey
    name: Jaryn Mervin Sabey
    organization: Continuity Laboratories
    email: hello@continuitylaboratories.com

normative:
  RFC2119:
  RFC8174:
  RFC8032:
  RFC8259:
  RFC8785:
  RFC3339:
  RFC9562:

informative:
  RFC9162:
  RFC9943:
  I-D.schrock-ep-authorization-receipts:
  SR-REPO:
    title: "Succession Receipts: specifications and conformance corpus"
    target: https://github.com/jsabes24/css-succession-receipts
    date: 2026
  SR-REFUSAL:
    title: "CSS Refusal Digest"
    target: https://github.com/jsabes24/css-succession-receipts/blob/main/spec/refusal-transparency.md
    date: 2026
  SR-CORPUS:
    title: "Succession Receipts conformance corpus"
    target: https://github.com/jsabes24/css-succession-receipts/tree/main/corpus
    date: 2026
  SR-ID:
    title: "Succession Receipts: Portable Signed Evidence of Authority Succession Between Autonomous Agents"
    target: https://datatracker.ietf.org/doc/draft-sabey-succession-receipts/
    date: 2026

--- abstract

A governance system for autonomous agents is defined as much by what it
refuses as by what it permits, yet refusals are the one behavior vendors
only ever assert. A Refusal Digest is a portable, signed JSON document
recording one adversarial probe run against a live agent-governance
system: for every attack attempted, the system's verbatim refusal ground,
the event types the attack would have recorded had it succeeded, and the
complete signed event ledger of the attempt — in which the refused
transition is provably absent. Digests verify offline, by parties who do
not operate the probed system, using only the issuer's public key. From
version 0.2, every quantity that varies between runs derives
deterministically from a per-run seed carried in the digest, so a relying
party can recompute the derivations and a replayed or pre-recorded ledger
cannot match a fresh digest. This document specifies the digest wire
format, its canonicalization and signature scheme, the seeded-variation
derivations, and the verification algorithm. Where succession receipts
prove that an agent legitimately became the holder of an authority,
refusal digests prove what the governing system declined to let happen.

--- middle

# Introduction

Any vendor of agent-governance infrastructure claims that its guards
hold: that the illegal transition is blocked, that the unauthorized
actor is refused, that the forbidden state change cannot be recorded.
The claim is load-bearing — buyers adopt such systems precisely for what
they will not do — and it is almost never checkable. Audit logs show
what happened; nothing shows, verifiably, what was *prevented* from
happening.

A **Refusal Digest** makes the claim checkable. It is a self-contained
JSON document, produced by running a published suite of adversarial
probes against the governing system, carrying for each probe:

- the attack attempted and the guard expected to refuse it, in plain
  language;
- the outcome — `refused`, or `unexpected_pass` when a guard did not
  fire (recorded and published, never hidden);
- the system's **verbatim refusal ground** — the actual error the guard
  returned, not a summary of it;
- the **forbidden event types**: the records the attack would have
  produced had it succeeded; and
- the **complete signed event ledger of the attempt**, embedded
  verbatim, in which every forbidden event type is provably absent.

A relying party verifies a digest **offline** with only the issuer's
Ed25519 public key: the proof over the whole document, every embedded
event's hash and signature, the absence of every forbidden transition,
and the summary counts. Refusal-before-recording is the probed system's
discipline — an illegal transition is refused *before* anything is
appended — so a successful refusal leaves exactly the shape the digest
records: a ledger carrying the attempt's setup and no completion.

One objection survives that verification: a dishonest operator could
replay a single recorded probe run forever. Version 0.2 of the format
answers it with **seeded variation** ({{seeding}}): every quantity that
varies between runs — the staged identifiers of each probe's setup, the
ordering of causally independent steps — derives deterministically from
a fresh per-run seed carried in the digest. A verifier recomputes the
derivations from the seed; a ledger recorded under any other seed cannot
match. A sequence of runs MAY additionally chain seeds, making the
sequence itself tamper-evident.

This document is a companion to Succession Receipts {{SR-ID}}, with
which it shares its canonicalization and signature discipline
({{canonical}}) and its conformance-corpus discipline: the format is
published with golden vectors and tamper cases that MUST fail at named
checks {{SR-REPO}}, against which independent verifier implementations
validate. Succession receipts attest that an agent legitimately became
the holder of an authority; refusal digests attest the transitions the
same class of system refused to perform. Pre-execution authorization of
individual material actions — a named human approving the exact action
before it runs, as in {{I-D.schrock-ep-authorization-receipts}} — is a
third, complementary evidence class: what was authorized, what
transferred, and what was refused compose without overlap. The transfer
leg of that composition is realized at the receipt layer, where the
succession-receipt format binds a pre-execution authorization receipt to
the transfer through an optional claim {{SR-ID}}; a refusal digest
attests the same class of system's refusals and requires no such binding
of its own. In the transparency-log sense,
a digest is a signed statement suitable for registration with
transparency services (in the style of {{RFC9162}} and SCITT
{{RFC9943}}); anchoring is discussed in {{security}}.

# Conventions and Definitions

The key words "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT",
"SHOULD", "SHOULD NOT", "RECOMMENDED", "NOT RECOMMENDED", "MAY", and
"OPTIONAL" in this document are to be interpreted as described in BCP 14
{{RFC2119}} {{RFC8174}} when, and only when, they appear in all capitals,
as shown here.

Probe:
: One adversarial attack attempted against a freshly constructed,
  isolated instance of the governed system, together with the staged
  setup it requires.

Refusal ground:
: The verbatim error with which the governed system refused the probe's
  attack — the same string an ordinary caller would receive.

Forbidden event types:
: The event types the probe's attack would have appended to the ledger
  had it succeeded. Their absence from the probe's embedded ledger is
  what verification checks.

Run seed:
: A 32-byte value, carried as 64 lowercase hexadecimal characters in a
  version 0.2 digest, from which every run-varying quantity derives
  ({{seeding}}).

Issuer:
: The operator that ran the probe suite and signs the digest. At the
  versions specified here the issuer attests its own run
  (`run.attestation` is `"self"`); see {{security}}.

Relying party:
: Any holder of the digest verifying it against the issuer's public
  keys.

# The Digest Document {#document}

A Refusal Digest is a UTF-8 JSON {{RFC8259}} object. The complete
normative member catalog, with types and constraints, is the published
digest specification {{SR-REFUSAL}}, which publishes version 0.1
(frozen) and version 0.2 (current); this section summarizes the
structure a verifier depends on and shows a version 0.2 digest.

~~~
{
  "spec":         "css-refusal-digest",
  "spec_version": "0.2",
  "issuer":       { "id": "urn:css:registry" },
  "run": {
    "started_at":   "<RFC 3339 timestamp>",
    "completed_at": "<RFC 3339 timestamp>",
    "attestation":  "self",
    "seed":         "<64 lowercase hex characters>"
  },
  "probes": [
    {
      "id":              "illegal-amendment",
      "name":            "Illegal Amendment Attempt",
      "attack":          "<the attack, in plain language>",
      "guard":           "<the rule expected to refuse it>",
      "outcome":         "refused" | "unexpected_pass",
      "refusal_ground":  "<the system's verbatim refusal error>",
      "engine_summary":  "<one-line explanation>",
      "forbidden_event_types": [ "AmendmentRatified", ... ],
      "events":          [ <event envelope>, ... ]
    },
    ...
  ],
  "summary": { "attempted": <count>, "refused": <count> },
  "proof": {
    "type":                "CSSEd25519Signature",
    "created":             "<RFC 3339 timestamp>",
    "verification_method": "<key_id>",
    "digest_hash":         "<hex SHA-256 of the canonical bytes>",
    "signature":           "ed25519:<key_id>:<base64url(signature)>"
  }
}
~~~

`run.seed` is **REQUIRED at version 0.2 and absent at version 0.1**. A
version 0.1 digest sets `spec_version` to `0.1` and carries no seed; a
conforming verifier accepts either version, each under its own rules
({{verification}}).

Timestamps throughout are {{RFC3339}} UTC instants. Each probe runs on
an isolated, freshly constructed instance of the governed system, so its
`events` member is the *complete* ledger of that attempt and probes
cannot contaminate one another. Event envelopes carry
the same members, integrity rules, and optional signatures as succession
receipt evidence ({{SR-ID}}; the event-hash rule is identical) and are
embedded exactly as recorded.

The probe suite is expected to grow. Adding a probe is additive within a
spec version: verification is per-probe, and the summary is recounted,
never trusted.

# Seeded Variation {#seeding}

Version 0.2 exists to defeat the replayed-ledger objection. Its rule:
**every quantity that varies between runs derives deterministically from
`run.seed`**, so any relying party can recompute the variation, and no
pre-recorded ledger can satisfy a digest carrying a different seed.

The standing derivations, over the seed's lowercase-hex string form and
its 32 raw bytes:

- **Run namespace.** `NS = UUIDv5(NameSpaceURL,
  "css-refusal-digest/v0.2|" + seed)`, where UUIDv5 and the URL
  namespace are as defined in {{RFC9562}}.

- **Derived identifiers.** Each staged identifier of a probe's setup is
  `UUIDv5(NS, "<probe-id>|<quantity-label>")`. The identifier labels
  each probe MUST derive — and the ledger positions where they MUST
  appear — are pinned per probe by the published specification and its
  conformance corpus {{SR-REFUSAL}} {{SR-CORPUS}}.

- **Derived orderings.** Where a probe contains causally independent
  steps (or attack routes) whose order is real run-to-run variation,
  the candidates are sorted by the lowercase-hex SHA-256 digest of the
  concatenation of the seed's raw bytes and
  `"<probe-id>|<candidate-label>"`.

**What never varies** is the line the transparency claim lives on: the
probe set, each probe's `id`, the guard under test, the attack's
semantics, and the `forbidden_event_types`. If those varied, a run would
stop being independently recomputable — a reader could no longer say
*what* was attacked, only that something was — and the claim would
collapse to trust in the operator. Variation exists to make replay
detectable, never to make the attack a moving target.

Seed choice is deliberately unconstrained: because nothing seed-derived
affects what is attacked or what must be refused, grinding seeds buys an
issuer nothing — any seed's run must refuse. For a sequence of runs it
is RECOMMENDED to chain seeds as the lowercase-hex SHA-256 of the ASCII
bytes of the previous digest's `digest_hash` (first run: issuer's
choice). A chained sequence is self-linking: the claim "N consecutive
runs, all refused" then inherits the same tamper evidence as the digests
themselves.

# Canonicalization and Signatures {#canonical}

The digest reuses the Succession Receipts discipline ({{SR-ID}})
unchanged:

- **Canonical bytes**: the JSON serialization with the `proof` member
  absent, member names sorted lexicographically, no insignificant
  whitespace, no HTML escaping — coinciding with the JSON
  Canonicalization Scheme {{RFC8785}} for the format's value domain
  (no floating-point numbers).
- **Hash-then-sign**: the proof signs the lowercase hexadecimal SHA-256
  digest of the canonical bytes (the digest *string* is the signed
  message); `digest_hash` records it; `signature` is the canonical
  `<alg>:<key_id>:base64url(signature-bytes)` string, with `ed25519`
  ({{RFC8032}}) the sole algorithm registered at versions 0.1 and 0.2.
- **Event integrity**: each embedded event's `event_hash` recomputes
  under the same event-hash rule as receipt evidence, and a present
  event `signature` verifies over it.

`proof.created` is outside the signed content: re-signing identical
content yields the same `digest_hash`.

# Verification {#verification}

A verifier is given the digest document and the issuer's public keys,
pinned out of band. Verification MUST perform, in order:

1. **Structure.** `spec` and `spec_version` match; `run.attestation` is
   `"self"`; at least one probe is present; every probe carries an
   `id`, a non-empty `forbidden_event_types`, and an outcome of
   `refused` or `unexpected_pass`; a refused probe carries a non-empty
   `refusal_ground`. At version 0.2, `run.seed` is present and is
   exactly 64 lowercase hexadecimal characters; at version 0.1 it is
   absent. Unknown versions MUST be rejected.

2. **Proof.** Recompute the canonical hash ({{canonical}}). It MUST
   equal `proof.digest_hash`, and `proof.signature` MUST verify against
   it under the key named by its `key_id`. A missing proof, an unknown
   `key_id`, a hash mismatch, or a failed signature check is fatal.

3. **Probe evidence.** For every event of every probe: the event hash
   MUST recompute to its stored value, and a *present* event signature
   MUST verify (absent signatures are reported, not fatal; a
   present-but-invalid signature is fatal).

4. **Refused-transition absence.** For every probe with outcome
   `refused`: no embedded event's type appears in that probe's
   `forbidden_event_types`. A digest claiming a refusal while carrying
   the completed transition is invalid.

5. **Summary integrity.** `summary.attempted` MUST equal the probe
   count and `summary.refused` the count of `refused` outcomes.

6. **Seed derivation (version 0.2).** For every probe whose derivation
   table the verifier implements (the standing suite, pinned by the
   published corpus), recompute the derived identifiers and orderings
   of {{seeding}} from `run.seed` and require the probe's ledger to
   have used them. For probes it does not know, a verifier MUST still
   enforce steps 1–5 in full.

**"Valid" and "all refused" are separate statements.** A digest
recording an `unexpected_pass` can verify — it is an honest record of a
failed run, published rather than hidden — and a relying party whose
standing question is "were all attacks refused?" MUST additionally check
that `summary.refused` equals `summary.attempted`. Reference tooling
distinguishes the two outcomes deliberately.

A conforming verifier MUST accept every golden vector and MUST reject
every tamper case of the published conformance corpus (trees
`refusal-v0.1` and `refusal-v0.2`) at the named check {{SR-CORPUS}}.

# Operating Model

Cadence is the operator's dial, not the format's: a digest attests one
probe run, and nothing in it changes with how often runs happen. An
issuer publishing on a cadence SHOULD publish the cadence alongside the
digests; a digest says nothing about attacks it does not contain, and
nothing about intervals it does not cover.

A guard that does not fire is a **published fact, never a silent gap**:
the `unexpected_pass` outcome is recorded in the digest, the digest
still signs and still verifies, and the operational response happens
outside the format. Continuous operation naturally combines with seed
chaining ({{seeding}}): a long-running issuer emits a self-linking
sequence in which each run's seed commits to the previous run's content.

# Versioning and Stability

`spec_version` identifies the wire format. Published versions are never
mutated: format changes only ever add a new version with new golden
vectors, and verifiers SHOULD continue to verify every published
version. Version 0.1 (frozen) carries no seed and verifies under steps
1–5 forever; version 0.2 (current) adds `run.seed` and the derivation
checks additively {{SR-REFUSAL}}.

# Security Considerations {#security}

**Self-attestation is the stated trust model, not a hidden one.** A
digest proves its content is intact, its embedded ledgers are genuine
output of the probed system's signing keys, and the refused transitions
are absent. It does not prove *who operated* the probes: at the versions
specified here the issuer attests its own run. Probes run by an
independent operator and countersigned — the proof becoming a set — are
the format's recorded evolution and change who signs, not the format.
Relying parties weighing operator honesty get exactly the leverage the
seed provides ({{seeding}}): whatever else a dishonest operator can do,
it cannot serve yesterday's ledger under today's seed.

**A digest is a positive record with stated scope.** It attests the
probes it contains, on the cadence its issuer publishes — not the
absence of other vulnerabilities, and not behavior between runs.
Consumers SHOULD treat the probe suite's composition (pinned, public,
versioned) as part of what they are trusting.

**Binding to the artifact under test is a recorded evolution.** A digest
names what was attacked and what was refused; the versions specified
here do not bind *which build* of the governed system was probed, so the
claim that the probes ran against the deployed production artifact rests
on the operator, exactly as the self-attestation model states. The
recorded strengthening path is a probe-suite digest and a
deployed-artifact digest or build attestation carried in the run
metadata, with the independent challenger or witness of the
countersignature evolution above checking them.

**Seed grinding is neutralized by construction.** Nothing seed-derived
affects what is attacked or what must be refused, so an issuer gains
nothing by choosing seeds adversarially; the seed exists to bind the
ledger bytes to the run, not to randomize the test.

**Key pinning is the trust root**, exactly as for succession receipts:
relying parties MUST obtain issuer keys through a channel they trust.
The digest additionally embeds the probed system's event signatures, so
a relying party that pins the system's event-signing keys separately
from the digest-signing key narrows the forgery surface further.

**Existence time composes with transparency infrastructure.** A
digest's `digest_hash` is a natural registrant for transparency and
timestamping services — a SCITT transparency service {{RFC9943}} or
comparable append-only witness — giving each published digest an
existence proof independent of its issuer. Issuers operating on a
cadence SHOULD anchor digests so that backdating a "clean" digest after
an incident is detectable.

**Deterministic serialization is load-bearing.** Implementations MUST
reproduce the canonical form and the event payloads' document-order
serialization exactly; the conformance corpus exists to make divergence
detectable, and its version 0.2 trees include re-signed derivation
forgeries that only the seed checks refuse.

# IANA Considerations

This document has no IANA actions. The signature-algorithm registry is
internal to the format's spec-version ladder ({{canonical}}), shared
with Succession Receipts {{SR-ID}}.

--- back

# Acknowledgments
{:numbered="false"}

The format was extracted from a production authority-succession system
of record, where the probe suite runs on a standing cadence against the
system's own constitutional guards; the conformance corpus packages the
resulting attack classes — including fully re-signed derivation
forgeries — as executable verification cases.

Iman Schrock provided detailed external review of the -00 document
family; this revision incorporates it.

# Change Log
{:numbered="false"}

-02: Updated the composition framing to note that the transfer leg of the
authorized/transferred/refused composition is now realized at the receipt
layer, where the succession-receipt format normatively defines an optional
binding to pre-execution authorization receipts {{SR-ID}}. The refusal
digest's own wire format, verification, and seeded-variation rules are
unchanged.

-01: Added the pre-execution authorization composition note and the
{{I-D.schrock-ep-authorization-receipts}} reference; added the
artifact-binding security consideration (probe-suite digest and
deployed-artifact attestation as the recorded strengthening path). No
wire-format change.
