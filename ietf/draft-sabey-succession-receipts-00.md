---
title: "Succession Receipts: Portable Signed Evidence of Authority Succession Between Autonomous Agents"
abbrev: "Succession Receipts"
docname: draft-sabey-succession-receipts-00
category: info
submissiontype: independent
ipr: trust200902
area: Security
workgroup: Individual Submission
keyword:
  - authority succession
  - signed receipts
  - AI agents
  - offline verification
  - Ed25519
  - JSON canonicalization

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

informative:
  RFC9162:
  SR-REPO:
    title: "Succession Receipts: specifications and conformance corpus"
    target: https://github.com/jsabes24/css-succession-receipts
    date: 2026
  SR-AHR:
    title: "CSS Authority-Handoff Receipts (AHR)"
    target: https://github.com/jsabes24/css-succession-receipts/blob/main/spec/authority-handoff-receipts.md
    date: 2026
  SR-CORPUS:
    title: "Succession Receipts conformance corpus"
    target: https://github.com/jsabes24/css-succession-receipts/tree/main/corpus
    date: 2026
  VC-DATA-MODEL:
    title: "Verifiable Credentials Data Model v2.0"
    target: https://www.w3.org/TR/vc-data-model-2.0/
    date: 2025
  I-D.farley-acta-signed-receipts:
  I-D.nelson-agent-delegation-receipts:
  I-D.rampalli-pedigree:
  RFC9943:

--- abstract

Autonomous agents are upgraded, replaced, suspended, and restored while
holding real operational authority. A Succession Receipt is a portable,
signed JSON document that proves one completed, policy-gated transfer of
authority between two agents: which agent held the authority, which agent
holds it now, under what legitimacy determination the transfer ran, and
which obligations carried forward, with every claim grounded in signed
evidence events embedded in the receipt itself. Receipts are verifiable
offline by parties who do not operate the issuing system, using only the
issuer's public key. This document specifies the receipt wire format, its
canonicalization and signature scheme (JSON Canonicalization Scheme with
Ed25519), and the verification algorithm, including bidirectional claim
grounding. Where decision receipts prove what an agent did, and delegation
receipts prove what an agent may do, Succession Receipts prove that an
agent legitimately became the holder of an authority.

--- middle

# Introduction

Deployed autonomous agents hold credentials, approve transactions, and act
under delegated authority. When such an agent is upgraded, replaced,
suspended, or restored, its successor inherits real power. Existing
identity and authorization infrastructure answers "who is the successor?"
and "may this request proceed?"; it does not produce portable evidence
that authority, obligations, and accountability were legitimately carried
from predecessor to successor.

A **Succession Receipt** closes that gap. It is a self-contained JSON
document, issued by the system of record that governed the transfer,
carrying:

- the parties (predecessor and successor agents, called *stewards*);
- the authorities revoked from the predecessor and derived for the
  successor, with their recorded bases;
- the legitimacy evaluation the transfer was approved under;
- the obligation and commitment lineage carried forward; and
- the **evidence**: the signed, hash-chained events the issuing system
  recorded, embedded verbatim, so that every claim above is checkable
  against them.

A relying party — an auditor, a counterparty, a regulator — verifies a
receipt **offline** with only the issuer's Ed25519 public key: no API
call, no access to the issuing system, no trust in its operator's
infrastructure. Verification recomputes every hash from the document's
own bytes and enforces claim grounding in both directions ({{verification}}),
so a receipt can neither invent nor conceal an effect of the transfer.

This document is companion to adjacent work on signed agent evidence:
decision receipts {{I-D.farley-acta-signed-receipts}} attest individual
machine-to-machine authorization decisions, and delegation receipts
{{I-D.nelson-agent-delegation-receipts}} attest grants of permission to
act. Per-hop delegation-chain identity, as in PEDIGREE
{{I-D.rampalli-pedigree}}, attests how authority *flows downward* through
live delegation from a root; Succession Receipts attest a different event
class again — the *transfer of the authority of record itself* between
agent generations, with obligation lineage — and are complementary to all
three. The formats share primitives (Ed25519 {{RFC8032}}, JSON
Canonicalization Scheme {{RFC8785}}) deliberately.

The wire format specified here is implemented and published with a
machine-readable conformance corpus (golden vectors plus tamper cases that
MUST fail at named checks) {{SR-REPO}}, against which independent verifier
implementations can validate; the format steward additionally maintains a
reference verifier, including a no-install in-browser verifier. The same
repository publishes companion evidence formats under the same corpus
discipline — ledger exports, capability credentials, external anchoring
checkpoints, and a refusal-transparency digest attesting transitions an
agent system refused to perform — which are outside the scope of this
document.

# Conventions and Definitions

The key words "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT",
"SHOULD", "SHOULD NOT", "RECOMMENDED", "NOT RECOMMENDED", "MAY", and
"OPTIONAL" in this document are to be interpreted as described in BCP 14
{{RFC2119}} {{RFC8174}} when, and only when, they appear in all capitals,
as shown here.

Steward:
: An agent (or agent generation) that can hold authority and carry
  obligations in the issuing system's registry.

Succession:
: The governed process by which authority of record transfers from a
  predecessor steward to a successor steward. Only *completed* successions
  yield receipts.

Issuer:
: The system of record that governed the succession, recorded its events,
  and signs the receipt.

Relying party:
: Any holder of the receipt verifying it against the issuer's public keys.

Evidence event:
: One event envelope from the issuer's append-only ledger, embedded
  verbatim in the receipt.

# The Receipt Document {#document}

A Succession Receipt is a UTF-8 JSON {{RFC8259}} object shaped after the
W3C Verifiable Credentials data model {{VC-DATA-MODEL}} as plain JSON:
the `@context` member is carried for interoperability, and JSON-LD
processing is NOT REQUIRED. The complete normative member catalog, with
types and constraints, is the AHR specification {{SR-AHR}}, which publishes
version 0.1 (frozen) and version 0.2 (current); this section summarizes the
structure a verifier depends on and shows a version 0.2 receipt.

~~~
{
  "@context":     ["https://www.w3.org/ns/credentials/v2",
                   "urn:css:ahr:v0.2"],
  "type":         ["VerifiableCredential", "AuthorityHandoffReceipt"],
  "spec_version": "0.2",
  "issuer":       { "id": "urn:css:registry" },
  "validFrom":    "2026-07-04T12:00:14Z",
  "credentialSubject": {
    "id":            "urn:uuid:<succession_id>",
    "succession_id": "<uuid>",
    "predecessor":   { "steward_id": "<uuid>",
                       "revoked_authorities": [ ... ],
                       "replaced": true },
    "successor":     { "steward_id": "<uuid>",
                       "authority_id": "<uuid>",
                       "authority_scope": "...",
                       "accountability_chain_id": "<uuid>",
                       "authority_status": "granted" | "active" },
    "legitimacy":    { "legitimacy_id": "<uuid>" },
    "constitution":  { "genesis_event_hash": "<hex>",
                       "amendments_ratified": <count>,
                       "amendment_head_hash": "<hex>" },
    "ledger_binding": { "height": <int>,
                        "event_hash": "<hex>" },
    "obligations_carried": [ "<uuid>", ... ],
    "commitments_carried": [ "<uuid>", ... ]
  },
  "evidence": [ <event envelope>, ... ],
  "proof": {
    "type":                "CSSEd25519Signature",
    "created":             "<RFC 3339 timestamp>",
    "verification_method": "<key_id>",
    "receipt_hash":        "<hex SHA-256 of the canonical bytes>",
    "signature":           "ed25519:<key_id>:<base64url(signature)>"
  }
}
~~~

The `constitution` and `ledger_binding` members are **REQUIRED at version
0.2 and absent at version 0.1**. `constitution` records the constitutional
lineage the transfer ran under: `genesis_event_hash` (the hash of the
genesis event that roots the lineage), `amendments_ratified` (the count of
ratified amendments in force at completion), and `amendment_head_hash` (the
hash of the latest such amendment, omitted when the count is zero).
`ledger_binding` records the receipt's evidence horizon: `height` (the
1-based position of the receipt's final evidence event in the issuer's
ordered event stream) and `event_hash` (that event's hash). Both are
grounded in the embedded evidence ({{verification}}), so a verifier
recomputes them from the receipt alone. A version 0.1 receipt names
`urn:css:ahr:v0.1` in `@context`, sets `spec_version` to `0.1`, and omits
both members; a conforming verifier accepts either version.

Each evidence event envelope carries `event_id`, `event_type`,
`aggregate_type`, `aggregate_id`, optional `causation_id` /
`correlation_id` / `previous_event_id` / `actor_id`, `timestamp`
({{RFC3339}}), `event_version`, `payload`, `event_hash`, and an optional
`signature`. Envelopes are embedded exactly as recorded — stored bytes,
not re-derived ones.

# Canonicalization and Signatures {#canonical}

## Canonical Form

The **canonical bytes** of a receipt are its JSON serialization with the
`proof` member absent, object member names sorted lexicographically, no
insignificant whitespace, and no HTML escaping. For the receipt's value
domain (strings, integers, arrays, objects; no floating-point numbers)
this coincides with the JSON Canonicalization Scheme {{RFC8785}}.

## Hash-Then-Sign

The proof signs the lowercase hexadecimal SHA-256 digest of the canonical
bytes (the digest *string* is the signed message). `receipt_hash` records
that digest; `signature` is the canonical signature string:

~~~
<alg> ":" <key_id> ":" base64url(signature-bytes)
~~~

`ed25519` ({{RFC8032}}, deterministic signatures) is the sole algorithm
registered at spec versions 0.1 and 0.2. `key_id` is an issuer-managed
label, deliberately NOT derived from the key: a verifier holds a map from
`key_id` to public key, so key rotation adds a mapping without invalidating
already-issued receipts. An unrecognized `<alg>` prefix MUST be rejected;
new algorithms (including post-quantum schemes) are additive prefixes
registered by a new spec version, never a mutation of an existing one.

## Evidence Event Integrity {#event-hash}

Every evidence event's `event_hash` is the lowercase hexadecimal SHA-256
of the concatenation of: `event_id`, `event_type`, `aggregate_type`,
`aggregate_id`, the timestamp in UTC {{RFC3339}} with trailing
fractional-second zeros omitted, the decimal `event_version`, the
payload's JSON serialization in document member order (the producer's
serialization order, preserved by the receipt), and `previous_event_id`
(empty string when absent). An event's optional `signature` is the
canonical signature string over its `event_hash`.

# Verification {#verification}

A verifier is given the receipt document and the issuer's public keys,
pinned out of band. Verification MUST perform, in order:

1. **Proof.** Recompute the canonical hash ({{canonical}}) from the
   document. It MUST equal `proof.receipt_hash`, and `proof.signature`
   MUST verify against it under the key named by its `key_id`. A missing
   proof, an unknown `key_id`, a hash mismatch, or a failed signature
   check is fatal. Verifying against the *recomputed* hash ensures any
   content tampering — including of `receipt_hash` itself — fails here.

2. **Evidence integrity.** Every evidence event's hash MUST recompute to
   its stored `event_hash` per {{event-hash}}.

3. **Evidence authenticity.** Every *present* evidence signature MUST
   verify. An absent signature is reported, not fatal (deployments that
   sign no events still produce receipts whose proof covers the evidence
   bytes); a present-but-invalid signature is fatal.

4. **Claim grounding, both directions.** Every `credentialSubject` claim
   MUST be supported by a matching evidence event: the completion event
   anchors `succession_id` and `validFrom`; the proposal names both
   parties; the approval names the legitimacy evaluation; the successor's
   authority grant matches steward, scope, and accountability chain and is
   correlated with the completion; a claimed `replaced` predecessor has
   its replacement event; every claimed revocation has its revocation
   event with the claimed basis. Conversely, every lineage effect in
   evidence MUST be declared by the claims: an inherited obligation or
   commitment absent from the carried lists, or a revocation absent from
   `revoked_authorities`, is fatal. A receipt can therefore neither
   invent nor conceal an effect of the transfer.

   For version 0.2 receipts, two further claims are grounded.
   `constitution` MUST be supported by exactly one `GenesisInitialized`
   event in the evidence whose hash equals `genesis_event_hash`; when
   `amendments_ratified` is greater than zero, `amendment_head_hash` MUST
   equal the hash of the latest `AmendmentRatified` event in evidence and
   the count MUST match. `ledger_binding.event_hash` MUST equal the hash
   of the receipt's final evidence event, and `height` states that event's
   position in the issuer's ordered stream; against a ledger export or an
   anchored checkpoint {{SR-REPO}} a relying party can additionally confirm
   that no event at or below `height` was omitted — a completeness
   cross-check a single receipt cannot provide alone.

A conforming verifier MUST accept every golden vector and MUST reject
every tamper case of the published conformance corpus {{SR-CORPUS}} at
the named check.

# Versioning and Stability

`spec_version` identifies the wire format. Published versions are never
mutated: format changes only ever add a new version with new golden
vectors, and verifiers SHOULD continue to verify every published version.
Versions 0.1 (frozen) and 0.2 (current) are drafts on a stated stability
ladder toward a stable 1.0 {{SR-AHR}}; 0.2 adds the `constitution` and
`ledger_binding` claims additively, and a conforming verifier accepts both
versions.

# Security Considerations

**A receipt proves what the issuer recorded, not that the issuer is
honest.** The verification algorithm is designed so that a lying issuer
gains the least possible ground: re-signing altered content with an
untrusted key fails at the proof; altering embedded evidence while
re-signing with a *trusted* key (the compromised-key case) fails at
evidence integrity; hiding or inventing lineage fails at claim grounding.
The conformance corpus {{SR-CORPUS}} encodes these attacks as executable
cases.

**Key pinning is the trust root.** Verification binds evidence to *the
holder of a named key*. Relying parties MUST obtain issuer keys through a
channel they trust and SHOULD pin them; fetching keys from the issuer's
own origin proves only self-consistency. Key rotation adds a `key_id`;
it MUST NOT invalidate previously issued receipts.

**Omission and rollback are out of a single receipt's scope.** A receipt
proves one completed succession; it cannot prove that no *other* events
exist. Whole-ledger claims are the companion ledger-export format's job,
and resistance to retroactive truncation or rollback requires externally
anchored commitments to the ledger head (in the style of transparency
logs {{RFC9162}}), both published alongside this format {{SR-REPO}}. The
anchoring extension point is designed to register ledger-head commitments
with a SCITT transparency service {{RFC9943}}, so
anchoring composes with the emerging standard rather than inventing a
parallel witness ecosystem. A version 0.2 `ledger_binding` claim states
the evidence horizon (`height`) at which such a completeness cross-check
applies.

**Deterministic serialization is load-bearing.** Implementations MUST
reproduce the canonical form and the payload's document-order
serialization exactly; the corpus exists to make divergence detectable.
Implementations SHOULD reject documents whose numbers fall outside the
integer value domain rather than guess at float formatting.

# IANA Considerations

This document has no IANA actions. The signature-algorithm registry is
internal to the format's spec-version ladder ({{canonical}}); a future
version of this specification may propose a formal registry if the format
is adopted for standards-track work.

--- back

# Acknowledgments
{:numbered="false"}

The format was extracted from a production authority-succession system of
record and hardened against its red-team findings; the conformance corpus
packages those findings as executable verification cases.
