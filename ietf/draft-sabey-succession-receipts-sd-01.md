---
title: "Selective Disclosure for Succession Receipts"
abbrev: "SD Succession Receipts"
docname: draft-sabey-succession-receipts-sd-01
category: info
submissiontype: independent
ipr: trust200902
area: Security
workgroup: Individual Submission
keyword:
  - selective disclosure
  - authority succession
  - signed receipts
  - salted commitments
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

informative:
  SD-JWT: RFC9901
  SD-JWT-VC: I-D.ietf-oauth-sd-jwt-vc
  I-D.schrock-ep-authorization-receipts:

  VC-DATA-MODEL:
    title: "Verifiable Credentials Data Model v2.0"
    target: https://www.w3.org/TR/vc-data-model-2.0/
    date: 2025
  SR-REPO:
    title: "Succession Receipts: specifications and conformance corpus"
    target: https://github.com/jsabes24/css-succession-receipts
    date: 2026
  SR-SDR:
    title: "CSS Selective-Disclosure Receipts (SDR)"
    target: https://github.com/jsabes24/css-succession-receipts/blob/main/spec/selective-disclosure-receipts.md
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

A Succession Receipt proves one completed, policy-gated transfer of
authority between autonomous agents, and it is all-or-nothing: whoever
holds the receipt holds every claim and every evidence event in it. In
regulated deployments the parties entitled to verify a transfer are not
all entitled to read it in full — a regulator, a counterparty, and the
public each warrant a different view. This document specifies a
selective-disclosure form of the receipt: the issuer signs salted
commitments to each claim unit and each evidence event, disclosures
travel outside the signature, and a projection — the signed envelope
plus any subset of the disclosures — still verifies against the one
issuer signature. Withholding never breaks the proof, disclosing never
re-signs, withheld content remains visibly committed, and a projection
that opens every commitment is verifiable to exactly the strength of the
underlying receipt. The disclosure mechanism deliberately follows the
salted-digest analysis of SD-JWT, restated for plain-JSON documents
canonicalized with the JSON Canonicalization Scheme.

--- middle

# Introduction

Succession Receipts {{SR-ID}} make one completed transfer of authority
between agents verifiable offline: the claims, the legitimacy
determination, the obligation lineage, and the signed evidence events
grounding all of it travel in one signed document. That completeness is
the format's strength and its disclosure problem. The evidence names
parties, scopes, and lineage; a receipt handed to a regulator to prove
*this transfer was approved under that legitimacy evaluation* also hands
over every business-identifying detail it carries.

A **Selective-Disclosure Receipt (SDR)** is the receipt rebuilt for that
reality. The issuer signs, once, an envelope containing **salted
commitments** — one per claim unit, one per evidence event. The values
themselves travel as **disclosures** outside the signed content. A
**projection** is the envelope plus any subset of the disclosures, and
it verifies against the one issuer signature: each disclosure reopens
its commitment or the projection fails; nothing about withholding a
disclosure disturbs the proof; and producing a narrower view for a new
audience is dropping disclosures, never re-signing.

Three properties distinguish the design:

- **Withholding is visible, never silent.** The commitment arrays are
  inside the signed envelope, so a verifier of any projection knows
  exactly how many claims and evidence events exist and which it is not
  seeing. An undisclosed claim is known-withheld, never deniable.
- **"Verified" and "grounded" are separate statements.** Verification
  reports each claim unit as grounded (its supporting evidence was
  disclosed and checks out), disclosed (bound to the issuer's signature,
  supporting evidence withheld), or undisclosed. A projection cannot
  misrepresent; what it proves is exactly what its report says.
- **Complete projections escalate.** A projection that opens every
  commitment MUST be verified under the full Succession Receipts claim
  semantics {{SR-ID}}, including the bidirectional completeness rules no
  partial view can enforce. This is both the issuance gate and the
  holder's acceptance check: a lying issuer is caught at acceptance, not
  discovered by a regulator later.

The mechanism is deliberately that of SD-JWT {{SD-JWT}} and its
credential profile {{SD-JWT-VC}} — salted digests of the hidden values
inside the signed body, disclosures shipped alongside, projection by
omission — and this document inherits that work's analysis. What it
contributes is the mechanism's application to the succession claim set,
and an encoding for **plain-JSON documents** under the JSON
Canonicalization Scheme {{RFC8785}} with the Succession Receipts
signature discipline, where SD-JWT is JWS-based. It composes with
SD-JWT rather than competing with it: a deployment already carrying
SD-JWT credentials can treat an SDR as the same discipline applied to a
different document class.

The format is published with a machine-readable conformance corpus
(golden vectors — a complete SDR and a reference projection — plus
tamper cases that MUST fail at named checks) {{SR-REPO}} {{SR-CORPUS}}.

The underlying receipt format is designed to compose with adjacent
evidence classes, including pre-execution authorization receipts
{{I-D.schrock-ep-authorization-receipts}}; such composition is defined
at the receipt layer ({{SR-ID}}) and carries no selective-disclosure
semantics of its own in this version.

# Conventions and Definitions

The key words "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT",
"SHOULD", "SHOULD NOT", "RECOMMENDED", "NOT RECOMMENDED", "MAY", and
"OPTIONAL" in this document are to be interpreted as described in BCP 14
{{RFC2119}} {{RFC8174}} when, and only when, they appear in all capitals,
as shown here.

Envelope:
: The signed part of the document: everything except `proof` and
  `disclosures`.

Commitment:
: The salted digest of one disclosure, carried in the envelope's `sd`
  member.

Disclosure:
: One `{salt, path, value}` object that reopens a commitment.

Disclosure unit:
: The granularity at which content may be disclosed: one of seven fixed
  claim units, or one evidence event ({{units}}).

Projection:
: The envelope plus any subset of the disclosures — the form a relying
  party receives.

Complete projection:
: A projection in which every commitment is opened by a disclosure.

Profile:
: A named, published subset stating which units a projection disclosed
  for a given audience. Profiles add no cryptography.

# The Document {#document}

An SDR is a UTF-8 JSON {{RFC8259}} object. The complete normative member
catalog is the published SDR specification {{SR-SDR}}; this section
summarizes the structure a verifier depends on.

~~~
{
  "@context":     ["https://www.w3.org/ns/credentials/v2",
                   "urn:css:sdr:v0.1"],
  "type":         ["VerifiableCredential",
                   "SelectiveDisclosureReceipt"],
  "spec_version": "0.1",
  "issuer":       { "id": "urn:css:registry" },
  "validFrom":    "<RFC 3339 timestamp>",
  "credentialSubject": {
    "id":            "urn:uuid:<succession_id>",
    "succession_id": "<uuid>"
  },
  "sd": {
    "alg":      "sha-256",
    "claims":   [ "<hex digest>", ...exactly seven... ],
    "evidence": [ "<hex digest>", ...one per evidence event... ]
  },
  "proof": {
    "type":                "CSSEd25519Signature",
    "created":             "<RFC 3339 timestamp>",
    "verification_method": "<key_id>",
    "receipt_hash":        "<hex SHA-256 of the canonical bytes>",
    "signature":           "ed25519:<key_id>:<base64url(signature)>"
  },
  "disclosures": [
    { "salt":  "<64 lowercase hex characters>",
      "path":  "credentialSubject/legitimacy",
      "value": { ... } },
    { "salt":  "<64 lowercase hex characters>",
      "path":  "evidence/<event_id>",
      "value": { <event envelope, verbatim as recorded> } },
    ...
  ]
}
~~~

Only the subject pointer and `validFrom` (an {{RFC3339}} UTC instant)
stay in clear: a receipt no one can address answers nothing, and the
timestamp anchors when the attested state held. Every other claim, and
every evidence event, lives behind a commitment. The document keeps the shape of the W3C Verifiable
Credentials data model {{VC-DATA-MODEL}} as plain JSON, with the same
caveats as the underlying receipt format {{SR-ID}}.

## Commitments

The commitment digest of a disclosure is the lowercase hexadecimal
SHA-256 of the **canonical bytes of the three-element array**
`[salt, path, value]`, serialized under the canonical form of
{{canonical}}. Salts are 32 bytes, carried as 64 lowercase hexadecimal
characters, generated from a cryptographically secure random source,
fresh per disclosure per issuance, and never reused — see {{security}}.

The commitment arrays in `sd` are sorted lexicographically and unique;
the wire order carries no information. `sd.alg` is `"sha-256"`, the sole
registered value at version 0.1.

## The Version 0.1 Disclosure Units {#units}

Disclosure granularity is pinned as data. The claim units are exactly
seven, carrying the underlying receipt's claim members verbatim
{{SR-ID}}:

~~~
credentialSubject/predecessor
credentialSubject/successor
credentialSubject/legitimacy
credentialSubject/obligations_carried
credentialSubject/commitments_carried
credentialSubject/constitution
credentialSubject/ledger_binding
~~~

Every issued SDR commits to exactly these seven, so the claim-commitment
count itself reveals nothing about the handoff. The lineage arrays
disclose as whole units, and `commitments_carried` is always a unit even
when empty: under salted commitments the empty set is committed to,
never omitted, or absence would be distinguishable from withholding.

Each evidence event is one unit at path `evidence/<event_id>`, its value
the event envelope verbatim as recorded. The evidence set is exactly the
set the equivalent plain receipt would carry.

Finer granularity (per-element lineage disclosure) is a recorded
evolution of the published specification, arriving only with a new
`spec_version`; it changes the commitment-counting analysis of
{{security}} and MUST NOT be improvised within version 0.1.

# Canonicalization and Signatures {#canonical}

The **canonical bytes** of an SDR are its JSON serialization with the
`proof` **and** `disclosures` members absent, object member names sorted
lexicographically, no insignificant whitespace, and no HTML escaping —
coinciding with the JSON Canonicalization Scheme {{RFC8785}} for the
format's value domain (no floating-point numbers). Excluding
`disclosures` from the signed content is the projection mechanism:
dropping entries never touches the signature.

The proof is the Succession Receipts proof unchanged {{SR-ID}}:
hash-then-sign over the lowercase hexadecimal SHA-256 of the canonical
bytes, `ed25519` ({{RFC8032}}) as the sole registered algorithm at
version 0.1, the canonical `<alg>:<key_id>:base64url(signature-bytes)`
signature string, and `proof.created` outside the signed content. The
same canonical rules serialize the `[salt, path, value]` commitment
input.

# Verification {#verification}

A verifier is given a projection and the issuer's public keys, pinned
out of band. Verification MUST perform, in order:

1. **Structure.** The `@context`, `type`, and `spec_version` members
   match {{document}} exactly; `sd.alg` is `"sha-256"`; `sd.claims`
   holds exactly seven digests and `sd.evidence` at least one, each 64
   lowercase hexadecimal characters, sorted, unique;
   `credentialSubject.id` encodes `succession_id`; every disclosure is
   well-formed with a path from {{units}}, and no path appears twice.

2. **Proof.** Recompute the canonical hash ({{canonical}}) from the
   received document with `proof` and `disclosures` removed. It MUST
   equal `proof.receipt_hash`, and `proof.signature` MUST verify against
   it under the key named by its `key_id`.

3. **Disclosure binding.** For every disclosure, recompute the
   commitment digest. It MUST appear in `sd.claims` (claim-unit paths)
   or `sd.evidence` (evidence paths); no two disclosures may bind the
   same digest; an evidence disclosure's path MUST name its own event's
   `event_id`.

4. **Evidence integrity and authenticity.** Every disclosed evidence
   event's hash MUST recompute to its stored value under the event-hash
   rule of {{SR-ID}}; a present event signature MUST verify (absent
   signatures are reported, not fatal).

5. **Disclosed-claim grounding.** The underlying receipt's claim-
   grounding rules {{SR-ID}} are applied over the disclosed subset, and
   each disclosed claim unit is assigned a status: **grounded** (every
   rule for it had its required evidence disclosed, and all passed),
   **disclosed** (at least one rule could not run for lack of disclosed
   evidence; nothing failed), or **undisclosed**. A disclosed claim
   **contradicted** by disclosed evidence is fatal — including the
   partial completeness checks a concealing holder would need to
   survive: a disclosed revocation absent from a disclosed
   `revoked_authorities` list, or a disclosed inheritance event for the
   disclosed successor absent from a disclosed lineage array,
   invalidates the projection. The exact per-unit rule table is
   normative in the published specification {{SR-SDR}}.

6. **Completeness escalation.** If every digest in both commitment
   arrays is opened, the projection is **complete**, and the verifier
   MUST reconstruct the full claim set and enforce the entirety of the
   underlying receipt's verification semantics {{SR-ID}} — both
   directions of the lineage and revocation rules, the constitution
   recount, and the ledger binding. Any failure is fatal. A complete
   projection is exactly as strong as the equivalent plain receipt.

The pass yields a report: the envelope hash, each unit's status,
disclosed and undisclosed evidence counts, signed and unsigned counts,
and the complete flag. What a relying party may *rely on* is the
per-unit status, never the mere fact of verification: a projection can
verify while grounding almost nothing, and the report says so.

A conforming verifier MUST accept every golden vector and MUST reject
every tamper case of the published conformance corpus (tree `sdr-v0.1`)
at the named check {{SR-CORPUS}}.

# Projection Profiles {#profiles}

A profile is a named, published statement of which units a projection
disclosed for a given audience — an agreement about *what to disclose*,
adding no cryptography. Version 0.1 pins one reference profile:

**`regulator`** — the projection for an auditor entitled to the
governance facts but not the business surface. Disclosed: the
`legitimacy`, `constitution`, and `ledger_binding` claim units, plus the
evidence events grounding them (the succession's completion and
approval, the legitimacy determination, the genesis event, and the
ratified amendments — all of whose payloads carry only opaque
identifiers). Withheld, but visibly committed: the parties, the
authority scope, the revocation bases, and the lineage identifiers. The
regulator verifies that the named succession completed at `validFrom`,
was approved under the named legitimacy evaluation at its determined
state, and ran under the committed constitutional lineage — without
receiving a single business-identifying string.

Other profiles (counterparty, public existence proof) are sketched
informatively in the published specification {{SR-SDR}}; a deployment
tunes profiles to its own payload content.

# Versioning and Stability

`spec_version` identifies the wire format. Published versions are never
mutated: format changes only ever add a new version with new golden
vectors, and verifiers SHOULD continue to verify every published
version. Version 0.1 is the current draft on the format family's stated
stability ladder toward a stable 1.0 {{SR-SDR}}.

# Security Considerations {#security}

The design inherits SD-JWT's salted-digest analysis {{SD-JWT}}; the
considerations below restate the consequences for this document class
and add the receipt-specific ones.

**Forgery and splicing fail at the commitment.** Altering a disclosed
value, salt, or path changes the commitment digest, which no longer
appears in the signed arrays. Commitment membership is per-envelope and
salts are fresh per issuance, so a disclosure lifted from another
receipt — even one committing an identical value — cannot bind.

**Salt entropy is what protects withheld values.** Several claim values
are low-entropy (booleans, two-value enums, short scope strings); an
unsalted or salt-reused commitment would be trivially confirmable by
dictionary. Salts MUST be 32 bytes from a cryptographically secure
random source, fresh per disclosure per issuance, never reused, and
never derived from content. Test vectors use published fixed salts;
production issuance MUST NOT.

**Projections of one SDR are mutually linkable, by design.** They share
the envelope hash, the signature, and the digest sets. Unlinkability
across audiences requires issuing multiple salt-fresh SDRs over the same
facts (batch issuance) — a recorded evolution, out of scope for version
0.1. State this plainly to deploying parties; do not imply otherwise.

**Commitment counts are public metadata.** The claim-commitment count is
a constant seven and reveals nothing. The evidence-commitment count
reveals the evidence-set size (roughly, lineage volume). Decoy digests
would hide it but are deliberately **not** part of version 0.1: an
unopenable commitment would make the complete projection — the
escalation gate this design's issuer-honesty story rests on —
undecidable. Any future decoy mechanism arrives with explicit signaling
and its own version.

**Possession is not entitlement.** Version 0.1 defines no holder
binding: anyone holding a projection can forward it. A recipient-bound
presentation (in the style of SD-JWT key binding {{SD-JWT}}) is a
recorded evolution. Profiles are access decisions made at disclosure
time; treat projections accordingly.

**A lying issuer is caught at acceptance.** An issuer could commit to
claims the record does not ground, counting on partial projections to
hide it. The complete-projection escalation is the countermeasure
placed where it works: issuance MUST verify the complete projection
before release, and a holder SHOULD verify it at acceptance — after
which every projection the holder makes is a pure subset of a fully
grounded, issuer-signed record. A relying party receiving only a partial
projection relies on the reported per-unit statuses, not on trust.

**Key pinning is the trust root**, exactly as for the underlying
receipts {{SR-ID}}: relying parties MUST obtain issuer keys through a
channel they trust and SHOULD pin them.

# IANA Considerations

This document has no IANA actions. The signature-algorithm and
`sd.alg` registries are internal to the format's spec-version ladder
({{canonical}}), shared with Succession Receipts {{SR-ID}}.

--- back

# Acknowledgments
{:numbered="false"}

The disclosure mechanism follows the analysis of SD-JWT deliberately;
the contribution here is its application to an existing plain-JSON
receipt format without changing that format's proof discipline. The
format was extracted from a production authority-succession system of
record; the conformance corpus packages its threat model — forging,
splicing, concealing, and complicit-issuer re-signing attacks — as
executable verification cases.

Iman Schrock provided detailed external review of the -00 document
family; this revision incorporates it.

# Change Log
{:numbered="false"}

-01: Added the composition note and the
{{I-D.schrock-ep-authorization-receipts}} reference. No wire-format
change.
