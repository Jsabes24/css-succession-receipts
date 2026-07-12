# CSS Authorization Decisions & Capabilities — v0.1 (draft)

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
> **Reference implementation.** Decisions and credentials are issued by the proprietary
> CSS engine; the reference
> verifiers (`sr-verify`, maintained by Continuity Laboratories, including the hosted
> in-browser verifier at <https://continuitylaboratories.com/verify>) are held
> byte-compatible with it by the conformance corpus, which independent
> implementations validate against equally. This specification covers the wire format and its **verification**
> only.



**Status:** Draft, published for review. The enforcement wedge: CSS as a
**Policy Decision Point** whose signed answers an external **Policy Enforcement Point** can act on.
**Reference verifier:** `sr-verify credential` (maintained by Continuity Laboratories)
— a standalone Policy Enforcement Point check.
**Golden vectors:** [`corpus/cap-v0.1/r1/golden.json`](../corpus/cap-v0.1/r1/golden.json).

The audit's central finding (§11) is that CSS is a decision engine with no enforcement point:
its refusals gate only its own ledger writes, so "nothing external is ever gated." This spec closes
that gap **honestly**. It defines two portable, offline-verifiable artifacts:

- a **CSS Authorization Decision (CAD)** — the signed answer to one question: *is actor X the
  currently-legitimate holder of authority over accountability chain C, and may it act now?*
- a **CSS capability credential (CAP)** — a short-lived, signed bearer capability the broker issues
  **only** to a permitted holder, for a Policy Enforcement Point to check for the token's brief life.

Both reuse the platform's existing authenticity discipline (hash-then-sign with the event-signing
Ed25519 key, canonical `ed25519:<key_id>:<base64url>` signatures); no new key material is
introduced, and nothing here writes to the ledger or participates in constitutional decisions.

---

## 1. What a decision attests — and what it does not

A CAD is the registry's **signed assertion** of a decision at a point in time, composed read-only
from the recorded ledger. The decision reflects exactly the same constitutional gates the engine
enforces elsewhere — it re-implements no policy — evaluated against three conditions: the actor is
the accountability chain's current active steward; the actor holds an authority whose status is
active on that chain; and the actor's latest legitimacy determination is L3 or higher (a later
downgrade revokes the predicate).

Default-deny: any failing condition yields a decided `deny` carrying the specific machine-readable
`ground` (`not_active_steward`, `no_active_authority_on_chain`, `legitimacy_not_l3_plus`,
`chain_closed`); only all three passing yields `permit`. An unknown chain is the one undecidable
input and is an error, not a deny.

**What Verify establishes (§5 trust model):** that CSS signed *exactly these facts* as of
`decided_at`. It does **not** re-derive the authority record from evidence — the grounding fields it
carries (active steward, matched authority + status, latest legitimacy) are the issuer's asserted
basis, independently auditable through the [authority-handoff receipt](./authority-handoff-receipts.md)
(#31) and the [ledger export](./ledger-export.md) (#50). This is the same trust model as a signed
access token or an OCSP response: strong enough to enforce on, cheap enough to cache, and paired with
a heavier "verify the record yourself" path for auditors.

---

## 2. Wire format

### 2.1 Decision (CAD)

```jsonc
{
  "@context": "urn:css:cad:v0.1",
  "spec_version": "0.1",
  "issuer": { "id": "urn:css:registry" },
  "query":  { "chain_id": "…", "actor_steward_id": "…", "scope": "full" },
  "outcome": "permit",                       // "permit" | "deny"
  "ground":  "active_and_legitimate",        // machine-readable basis
  "reason":  "actor is the active steward …",// human-readable
  "grounding": {
    "active_steward_id": "…",
    "chain_closed": false,
    "authority_id": "…", "authority_status": "Active", "authority_scope": "full",
    "legitimacy_id": "…", "legitimacy_state": "L4"
  },
  "decided_at": "2026-07-06T12:00:00Z",
  "proof": {                                  // absent when the deployment runs unsigned
    "type": "CSSEd25519Signature",
    "created": "…",
    "verification_method": "<key_id>",
    "decision_hash": "<hex sha256 of the canonical bytes>",
    "signature": "ed25519:<key_id>:<base64url>"
  }
}
```

`scope` is optional and informational: it is echoed into the decision, and the matched authority's
scope is reported in the grounding, so a PEP can apply finer-grained scope matching itself. v0.1
matches at the chain + authority level.

### 2.2 Capability credential (CAP)

```jsonc
{
  "@context": "urn:css:cap:v0.1",
  "spec_version": "0.1",
  "issuer": { "id": "urn:css:registry" },
  "subject": { "steward_id": "…", "chain_id": "…", "authority_id": "…", "scope": "full" },
  "capability": "act-under-authority",
  "not_before": "2026-07-06T12:00:00Z",
  "expires_at": "2026-07-06T12:05:00Z",       // short by design
  "decision": { … the permit CAD above, unsigned … },
  "proof": { "type": "CSSEd25519Signature", "credential_hash": "…", "signature": "…", … }
}
```

The permit decision is **embedded** as the credential's basis; it carries no proof of its own — the
single credential proof covers the whole document, decision included.

---

## 3. Canonicalization & proof

Identical discipline to receipts (#31) and anchors (#8): the canonical form is UTF-8 JSON with
lexicographically sorted keys, no insignificant whitespace, no HTML escaping, and the `proof` member
absent (for this value domain — strings, bools, arrays, objects, no floats — this coincides with
RFC 8785/JCS). The proof signs the hex SHA-256 of the canonical bytes. `created` is outside the
signed content, so re-signing the same decision/credential at a different time yields the same hash.

---

## 4. Issuance

Decisions and credentials are issued by the engine on request: a decision request returns the
signed CAD (permit and deny are both a decided answer, not an error); a credential request returns
the signed CAP on permit, or a refusal to issue on deny, carrying the verbatim ground. Credential
lifetimes are short by design (minutes, not hours). Unsigned deployments return unproofed
artifacts that fail verification by design.

---

## 5. Verifying offline (the PEP's side)

`sr-verify credential` is the reference Policy Enforcement Point check — no database, no server:

```
sr-verify credential -credential cred.json -public-keys "prod-1=prod-1.pub.pem"
# exit 0: proof valid, unexpired, embedded basis is a permit
# exit 1: bad proof, expired, not-yet-valid, or non-permit basis
```

Verification recomputes the canonical hash, verifies the issuer signature against it, then (for a
credential) checks `now ∈ [not_before, expires_at)` and that the embedded decision is a permit. A
short lifetime is the revocation mechanism: a later downgrade or revocation bounds the credential's
blast radius to its TTL.

---

## 6. Extension points

- **Scope semantics.** Finer capability vocabularies and scope matching layer on top of the reported
  `authority_scope` without a wire-format change.

---

## 7. Worked examples

The golden vector [`corpus/cap-v0.1/r1/golden.json`](../corpus/cap-v0.1/r1/golden.json) is
byte-pinned in CI and verifies cold with its committed key — the exact document an external
implementer should reproduce. A wire-format change requires a `spec_version` bump and a new
corpus revision.

---

## 8. Honest scope

CSS is the **authority-record PDP and credential issuer**. The enforcement point *at the moment of
action* — the code that refuses to call the tool, issue the real credential, or complete the handoff
when the capability is missing or expired — lives in the integrator's runtime. CSS makes that point
cheap and honest to build (a signed decision, a short-lived capability); it does not replace it.
