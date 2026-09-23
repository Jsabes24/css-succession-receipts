---
title: "Succession Receipts: Portable Signed Evidence of Authority Succession Between Autonomous Agents"
abbrev: "Succession Receipts"
docname: draft-sabey-succession-receipts-05
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
  I-D.schrock-ep-authorization-receipts:
  I-D.schrock-canonical-action-identifier:

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
  I-D.schrock-ep-quorum:
  I-D.sahu-agent-action-receipts:
  I-D.mih-scitt-agent-action-capsule:
  I-D.mih-scitt-agent-action-capsule-sel-disc:
  I-D.noa-scitt-ai-agent-receipt:
  I-D.emirdag-scitt-ai-agent-execution:
  I-D.fassbender-scitt-time-anchor:
  I-D.kuehlewind-audit-architecture:
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
Ed25519), the verification algorithm including bidirectional claim
grounding, and an optional claim that binds a pre-execution authorization
of the handoff to the succession evidence. Where decision receipts prove
what an agent did, and delegation receipts prove what an agent may do,
Succession Receipts prove that an agent legitimately became the holder of
an authority.

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

Pre-execution authorization of individual material actions is a fourth
adjacent class: an authorization receipt
{{I-D.schrock-ep-authorization-receipts}} establishes that a named human
authorized an exact action before it ran, where a Succession Receipt
establishes that the authority of record itself moved legitimately
between agent generations. The two compose by treating the handoff itself
as a material action: this document defines an OPTIONAL
`authorization_binding` claim ({{authorization-binding}}) that binds the
handoff's canonical action identifier and the hash of the authorization
receipt that approved it into the succession evidence, connecting the
exact human-approved handoff to the exact transfer event without
conflating the two formats. The claim is additive — a receipt that omits
it verifies exactly as one that predates it — and a cross-format
conformance vector, contributed by the authorization-receipt format's
author, pins the binding in the published corpus {{SR-CORPUS}}.

A wider set of agent-evidence formats has grown up alongside these, and
nearly all of it records **what an agent did**: hash-chained action
receipts {{I-D.sahu-agent-action-receipts}}, SCITT statement profiles for
agent actions {{I-D.mih-scitt-agent-action-capsule}} and their
selective-disclosure form
{{I-D.mih-scitt-agent-action-capsule-sel-disc}}, AI-agent receipts
{{I-D.noa-scitt-ai-agent-receipt}}, execution profiles
{{I-D.emirdag-scitt-ai-agent-execution}}, and existence-time anchoring
{{I-D.fassbender-scitt-time-anchor}}. An architecture for the layer they
occupy is developing in {{I-D.kuehlewind-audit-architecture}}, whose
Authorization Transition Record work item asks for a record carrying
previous state, new state, triggering event and responsible actor,
replayable to reconstruct the authorization in force. This document
instantiates that shape for one consequential class of transition — the
handoff of the authority of record between agent generations — and is
complementary to the action-level formats rather than an alternative to
any of them.

The wire format specified here is implemented and published with a
machine-readable conformance corpus (golden vectors plus tamper cases that
MUST fail at named checks) {{SR-REPO}}, against which independent verifier
implementations can validate; the format steward additionally maintains a
reference verifier, including a no-install in-browser verifier. The same
repository publishes companion evidence formats under the same corpus
discipline — ledger exports, capability credentials, external anchoring
checkpoints, a refusal-transparency digest attesting transitions an
agent system refused to perform, and selective-disclosure projections of
the receipts specified here (partial views that verify against the one
issuer signature) — which are outside the scope of this document.

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
    "commitments_carried": [ "<uuid>", ... ],
    "authorization_binding": {              // OPTIONAL (see below)
      "caid":         "<authorization-format action identifier>",
      "receipt_hash": "<64 lowercase hex, authorization receipt>",
      "format":       "EP-AUTHORIZATION-RECEIPT-v1" }
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

The `authorization_binding` member is **OPTIONAL** and additive. A receipt
that omits it verifies exactly as a receipt that predates the claim, and
its presence does not change `spec_version`. When present, it binds the
succession to a pre-execution authorization of the handoff; its members and
verification are specified in {{authorization-binding}}.

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

5. **Authorization binding (optional).** If
   `credentialSubject.authorization_binding` is present, perform the
   cross-format check of {{authorization-binding}}; if it is absent, the
   receipt asserts no cross-format binding and this step is satisfied.

A conforming verifier MUST accept every golden vector and MUST reject
every tamper case of the published conformance corpus {{SR-CORPUS}} at
the named check.

# Optional Authorization Binding {#authorization-binding}

`credentialSubject.authorization_binding` is an OPTIONAL claim binding a
succession to a separately verifiable authorization artifact for the
handoff. It contains three string members:

- `caid` — the canonical action identifier obtained from the natively
  verified authorization artifact under a mapping profile independently
  pinned by the relying party. Where the format carries a native
  identifier, its specification determines that identifier. A derived
  identifier is a composition value, not an additional member of the
  native artifact. For the EMILIA Protocol formats the derivation is
  specified in {{I-D.schrock-canonical-action-identifier}}.
- `receipt_hash` — exactly 64 lowercase hexadecimal characters, encoding
  SHA-256 of the complete native authorization artifact under the
  canonicalization specified for the named format. For
  `EP-AUTHORIZATION-RECEIPT-v1` this is SHA-256 of the JCS
  canonicalization of the complete, unchanged Trust Receipt, **including**
  `log_proof` and `approver_key_proofs`
  ({{I-D.schrock-ep-authorization-receipts}}). No member is added or
  removed. This is not the action hash, not a Merkle leaf hash, and not
  the succession receipt's own `proof.receipt_hash`.
- `format` — a non-empty identifier naming the native artifact format and
  its verification procedure. For the Trust Receipt of
  {{I-D.schrock-ep-authorization-receipts}} Section 7.2 the identifier is
  `EP-AUTHORIZATION-RECEIPT-v1`. `EP-RECEIPT-v1` names a different generic
  envelope and MUST NOT dispatch to that verifier. `EP-QUORUM-v1` names
  the quorum reference suite of {{I-D.schrock-ep-quorum}}; it does not by
  itself identify a complete receipt carrier, a canonicalization, or a
  native receipt-verification procedure. A multi-approver binding MUST
  identify an applicable carrier format and independently authenticate
  its quorum policy and member mapping.

Unknown additional members of `authorization_binding` are ignored. This
does not permit unknown members to be inserted into an authorization
artifact whose native schema is closed.

A verifier that implements this claim processes it as follows.

1. If the claim is absent, report that no authorization binding is
   asserted. Absence does not invalidate the succession receipt.
2. If present, check its well-formedness as above. A malformed claim
   invalidates the succession receipt.
3. If the native artifact, its supported format definition, or the inputs
   required for native verification are unavailable, report that the
   binding is **not verified**. Successful well-formedness checking and
   the succession issuer's proof do not establish the binding. This
   incomplete result is not a demonstrated hash or identifier mismatch,
   and a relying party requiring a verified binding MUST NOT accept it as
   satisfied.
4. With the artifact and required inputs available, verify the unchanged
   artifact using its native verification procedure and independently
   selected trust inputs. An artifact that fails native verification
   cannot establish the binding. For an EP Trust Receipt, follow
   {{I-D.schrock-ep-authorization-receipts}} Section 7.3; the succession
   issuer's signature is not a substitute for that verification.
5. Recompute the complete artifact digest and require equality with
   `receipt_hash`. A mismatch invalidates the binding and the succession
   receipt under this claim's verification rule.
6. Obtain the artifact's action identifier as its format defines. For the
   EMILIA Protocol formats, project the verified Action Object under the
   exact relying-party-pinned CAID mapping of
   {{I-D.schrock-canonical-action-identifier}}. Do not add the derived
   identifier to the native receipt and do not change any native
   signature input. A missing, failed, lossy, or unpinned mapping is
   indeterminate, not an action match. Where derivation succeeds, require
   byte-for-byte equality with `caid`; a mismatch invalidates the binding
   and the succession receipt.

The digest comparison precedes the identifier comparison.
Native-verification failure, incomplete verification, and demonstrated
binding mismatch are three distinct results; the descriptive names used
here add no wire members to either format.

The binding preserves each format's scope. A Trust Receipt records
approval evidence and terminal consumption under its native profile; it
does not itself grant authority or prove external execution. Succession
verification establishes the succession issuer's recorded transfer,
subject to this document's trust model. Cross-format equality does not
strengthen either guarantee — and neither format speaks for the other.

The published corpus {{SR-CORPUS}} pins this rule and its evaluation
order. Corpus revision `ahr-v0.2/r2` pinned the earlier composition
contract and remains unchanged as historical evidence of it: its bytes,
hashes and expected results are not edited, and a corpus revision alone
must never silently reinterpret an existing format identifier. The
corrected native-artifact example is therefore published as a **new**
revision, `ahr-v0.2/r3`, once the native artifacts contributed by the
authorization-receipt format's author are integrated.


# Versioning and Stability

`spec_version` identifies the wire format. Published versions are never
mutated: format changes only ever add a new version with new golden
vectors, and verifiers SHOULD continue to verify every published version.
Versions 0.1 (frozen) and 0.2 (current) are drafts on a stated stability
ladder toward a stable 1.0 {{SR-AHR}}; 0.2 adds the `constitution` and
`ledger_binding` claims additively, and a conforming verifier accepts both
versions.

New OPTIONAL claims are additive and do NOT bump `spec_version`: a verifier
that does not implement such a claim ignores it while still verifying the
receipt. The `authorization_binding` claim ({{authorization-binding}}) is
introduced under exactly this rule — it is version-independent and changes
no existing receipt's bytes.

# Security Considerations

**A receipt proves what the issuer recorded, not that the issuer is
honest.** Verification establishes internal consistency under the
issuer's key, not tamper evidence against the issuer. A lying issuer
gains the least possible ground: re-signing altered content with an
untrusted key fails at the proof; altering embedded evidence while
re-signing the receipt without recomputing event hashes fails at
evidence integrity; hiding or inventing lineage fails at claim grounding.
A malicious or compromised issuer that additionally recomputes event
hashes and re-signs both the events and the receipt, however, can
produce an internally consistent receipt for a history its ledger never
recorded. Relying parties requiring stronger-than-issuer guarantees
SHOULD pin the event-signing key independently of the receipt-signing
key where the deployment separates them, and SHOULD rely on the
externally anchored ledger-head commitments discussed below, against
which such a fabrication becomes detectable. The conformance corpus
{{SR-CORPUS}} encodes these attacks as executable cases, including
re-signed variants.

The event-hash input of {{event-hash}} concatenates adjacent
variable-length fields without length framing, so distinct field tuples
can in principle produce identical hash input: `event_type` and
`aggregate_type` are adjacent, individually unconstrained strings, and a
shifted boundary between them yields the same bytes. Within a single
receipt every evidence byte is additionally covered by the issuer proof,
but an event signature is a signature over the hash string alone and is
therefore reusable wherever the same hash input can be reproduced.
Verifiers SHOULD reject events whose `event_type` or `aggregate_type`
fall outside the vocabulary the issuing format publishes (the
conformance corpus pins the reference vocabulary, in which no two event
types stand in a prefix relation), and a future format version will
adopt length-prefixed hash components; published versions are never
mutated and continue to verify under the current rule.

**The authorization binding does not extend trust to the other format.**
When `authorization_binding` is verified against a held authorization
receipt, the guarantee is a byte-exact correspondence between this
succession and that pre-execution approval, no stronger than the
authorization receipt's own proof under the keys a relying party trusts
for it. The binding neither vouches for the authorization issuer nor lets
either issuer speak for the other; a verifier lacking the authorization
receipt learns only that the claim is well-formed. Relying parties apply
the same key-pinning discipline to the authorization format's issuer as to
this one.

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

Iman Schrock provided detailed external review of the -00 revision, and
contributed the cross-format conformance vector that pins the authorization
binding of {{authorization-binding}}; this document incorporates both. The
-02 review identified that {{authorization-binding}}'s cross-check could
not be implemented from the documents this specification cited, which -03
corrects. For -04 the same reviewer supplied the complete native
authorization artifacts and executable checks on which the corrected
{{authorization-binding}} is based, and identified that the illustrative r2 cross-format vector carried the
claim at a path the normative text does not use. The -04 review identified
that the illustrative receipt in {{document}} still carried the `format`
value {{authorization-binding}} forbids dispatching on, which -05 corrects.

# Change Log
{:numbered="false"}

-05: Corrected the illustrative receipt in {{document}}, whose
`authorization_binding.format` still read `EP-RECEIPT-v1`. -04 removed that
value from the normative text of {{authorization-binding}} and stated that it
names a different generic envelope which MUST NOT dispatch to the detailed
verifier, but left it standing in the one place a reader copies from. The
example now reads `EP-AUTHORIZATION-RECEIPT-v1`, agreeing with
{{authorization-binding}} and with the `ahr-v0.2` corpus. Editorial only: no
normative statement changed, no wire-format change, no change to
`spec_version`, and the published corpus bytes, hashes and expected results
are untouched.

-04: Corrected {{authorization-binding}} against the native
authorization-receipt format. The -02 and -03 text derived the action
identifier, embedded it, and then hashed; it also offered `EP-RECEIPT-v1`
and `EP-QUORUM-v1` as example `format` values. Both were wrong.
`EP-RECEIPT-v1` names a generic envelope that
{{I-D.schrock-ep-authorization-receipts}} forbids dispatching to the
detailed verifier, `EP-QUORUM-v1` names the reference conformance suite
of {{I-D.schrock-ep-quorum}} rather than a receipt carrier, and the
correct identifier for the Trust Receipt is
`EP-AUTHORIZATION-RECEIPT-v1`. The verification order is now: verify the
unchanged native artifact, recompute the digest over the **complete**
artifact including its proof members, and only then derive and compare
the identifier under a separately pinned lossless mapping — the derived
identifier is never inserted into the native artifact. Named
**incomplete verification** as a third result distinct from native
failure and from demonstrated mismatch, so an unavailable input can
neither pass nor be reported as a mismatch. {{I-D.schrock-ep-quorum}} is
cited informatively: no conforming implementation needs it, and a
normative reference would add a publication dependency this document does
not require. Added informative references situating this format among the
agent-evidence work published since -00. No wire-format change and no
change to `spec_version`: a receipt that omits the claim is unaffected,
and the existing `ahr-v0.2/r2` bytes, hashes and expected results are
untouched.

-03: Moved {{I-D.schrock-ep-authorization-receipts}} to Normative
References and added {{I-D.schrock-canonical-action-identifier}} there,
and cited both at each point in {{authorization-binding}} where the
cross-check delegates to the named format. The -02 revision stated the
cross-check as a MUST while citing the authorization-receipt format
informatively and the canonical-action-identifier specification not at
all, so the mandatory branch could not be implemented from the cited
documents; this revision closes that gap. Because this document is
Informational, the normative references introduce no downward reference
(RFC 3967 applies to standards-track documents). Also stated
explicitly that a verifier lacking the named format's specification
falls back to the well-formedness-only check rather
than accepting the binding unverified. No wire-format change, no change to
`spec_version`, and no change to any claim, proof, canonicalization, or
event-hash rule.

-02: Defined the OPTIONAL `authorization_binding` claim
({{authorization-binding}}), which binds a pre-execution authorization
receipt's canonical action identifier and canonical hash to the
succession, with its verification rule and evaluation order (recomputed
hash before identifier; a derived identifier is part of the hashed
canonical representation — derive, embed, then hash). The claim is
additive and version-independent: it
does not change `spec_version` and does not alter the wire format of any
receipt that omits it. Added the cross-format conformance vector (corpus
revision `ahr-v0.2/r2`) to the published corpus. No change to any existing
claim or to the proof, canonicalization, or event-hash rules.

-01: Added the pre-execution authorization composition note and the
{{I-D.schrock-ep-authorization-receipts}} reference; restated the
trusted-issuer security consideration as internal consistency under the
issuer's key; added the event-hash framing consideration. No wire-format
change.
