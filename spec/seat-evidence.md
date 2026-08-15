# CSS Seat Evidence — v0.1 (draft)

> **Publication note (Succession Receipts).** This specification is published as part of
> **Succession Receipts** — the open verification surface for CSS evidence — see the
> repository README for scope. The wire format of each version is pinned by its golden
> vectors in [`corpus/seat-evidence-v0.1/`](../corpus/seat-evidence-v0.1/) and validated by
> the conformance corpus in this repository; independent implementations conform by passing
> it — for **every** published version.
>
> **Stability ladder.** v0.1 (draft) → v1.0 (stable). A published version is never mutated:
> format changes only ever add a new version with new golden vectors, and conforming
> verifiers keep verifying every published version. Corpus revisions are append-only.

A **seat** is a model asked a governance question. This is the format it uses to submit an
answer as **evidence** — and it is built so that a seat *cannot* submit a verdict, *cannot*
overstate what its answer is worth, and *cannot be forced to lie* when it has nothing to
certify.

It is the first format in this family about **model output** rather than about the record,
which makes it relevant to anyone evaluating model claims, not only to authority succession.
A third party can build a conforming seat from this document and the corpus alone.

---

## 1. The boundary, stated first

Fidelity and legitimacy outcomes are computed by the **evaluating engine**, never asserted by
the caller. This format does not ask implementers to respect that convention — it enforces it
structurally: **there is no field, at any nesting level, in which a seat can name an
outcome.** A stance is a distribution or an abstention, and nothing else.

A verified submission establishes:

- **What answered** — the weights and prompt template, by digest. Template choice is known to
  swing a seat's stance across the full interval, so it is a required declaration, not a note.
- **What the seat says about itself** — the corpus it was calibrated on (by tree *and*
  digest), its abstention rate, its error rate among answers it did assert, and **whether it
  certifies at all**.
- **An honest ceiling** — the highest fidelity outcome the submission may support, derived
  from the calibration block and cross-checked by every verifier (§3).

It does **not** attest that the stance is correct, that the seat's self-reported rates are
honest (§5 is how that stops being self-reported), or that any particular outcome follows.

## 2. `certifies: false` is a first-class path

The honest state of a seat may be *nothing certifies at any alpha* — and may remain so
indefinitely. A format able to express only a bounded error rate leaves such a seat two
options: lie, or stay silent. Both are worse than the truth.

So `certifies: false` is a **representable, signed, verifiable statement**, and it lands on an
existing rung of the fidelity scale rather than a new one:

**`FD0` — "cannot determine"**, which maps to legitimacy state **`L0` Undetermined**.

A seat that cannot bound its error rate is therefore not a hole in the record; it is a
**governed state** the evaluating engine already knows how to hold. This is the same
refuse-rather-than-filter discipline the refusal-transparency format has: the system would
rather carry an honest "cannot determine" than a fabricated determination.

## 3. The ceiling is derived, then checked — never trusted

`fidelity_ceiling` is covered by the proof, but a conforming verifier **recomputes** it from
the submission's own calibration and rejects a mismatch at the named check
`fidelity_ceiling`.

| calibration | ceiling | why |
|---|---|---|
| `stance.abstained: true` | `FD0` | an abstention supplies no stance, so it can support nothing |
| `certifies: false` | `FD0` | no bounded error rate, so the evaluator cannot determine |
| `certifies: true` | `FD2` | "continuity uncertain; review required" — and no higher |

**Why `FD2` is the cap.** A calibrated probabilistic stance is by construction neither a
demonstration (`FD3`) nor an independent validation (`FD4`); those levels require the
evaluating engine's own evidence. Raising the cap is a governance change, not a format change.

The consequence, stated plainly: **a seat cannot talk itself up.** Raising the ceiling and
genuinely re-signing produces a document whose signature is valid and whose structure is
well-formed, and which must still fail — at `fidelity_ceiling`, not at `proof`.

## 4. Wire format

```json
{
  "spec": "css-seat-evidence",
  "spec_version": "0.1",
  "issuer": "urn:css:registry",
  "id": "…",
  "subject": {
    "chain_id": "…",
    "question": "does the proposed succession preserve constitutional continuity?",
    "evaluation_type": "Succession"
  },
  "stance": {
    "abstained": false,
    "distribution": { "preserved": "0.82", "challenged": "0.15", "failed": "0.03" }
  },
  "calibration": {
    "certifies": false,
    "corpus": { "tree": "cle-v0.1/r1", "digest": "<hex sha256 of that tree's SHA256SUMS>" },
    "abstention_rate": "0.41",
    "error_rate_asserted": "0.07",
    "sample_size": 512
  },
  "seat": {
    "weights_digest": "<hex sha256>",
    "template_digest": "<hex sha256>",
    "template_id": "seat-prompt-v3"
  },
  "fidelity_ceiling": "FD0",
  "created_at": "2026-08-15T00:00:00Z",
  "proof": {
    "type": "CSSEd25519Signature",
    "created": "2026-08-15T00:00:00Z",
    "verification_method": "seat-vector-1",
    "evidence_hash": "…",
    "signature": "ed25519:seat-vector-1:…"
  }
}
```

Rules a conforming implementation enforces:

- `alpha` is present **iff** `certifies` is true.
- `stance.abstained` and `stance.distribution` are **mutually exclusive**; a non-abstaining
  stance carries a distribution summing to 1.
- Probabilities and rates are **decimal strings in `[0,1]`** — no exponents, no signs. The
  value domain is deliberately float-free, so the canonical form coincides with RFC 8785
  (JCS) and the document survives a JavaScript verifier unchanged.
- Digests are lowercase hex SHA-256.
- `calibration.corpus.tree` names a **published** corpus revision path (for example
  `cle-v0.1/r1`), not an opaque internal identifier.

The proof is SHA-256 over the canonical bytes with the `proof` member absent, in the family's
`ed25519:<key_id>:<base64url>` form. `proof.created` is excluded from the signed message, so
re-signing identical content yields the same `evidence_hash`. **No new key material and no
second key registry**: a seat's key resolves through the same `key_id` indirection as every
other signer in the family.

## 5. Calibration that is earned, not claimed

The weakest field in any self-describing seat is the self-reported error rate: it is exactly
the part a verifier cannot check.

`calibration.precommitment_binding` is the way out. A
[**precommitment atom**](./precommitment-atoms.md) locks *claim + confidence + measurement
rule + horizon* **before the outcome is known** and resolves by re-execution. A seat that
binds its calibration to atoms is no longer asking to be believed — a verifier holding the
atoms and their resolution evidence **recomputes** the seat's record.

```json
"precommitment_binding": { "atom_hash": "<hex>", "format": "css-precommitment" }
```

The binding follows the cross-format idiom established by
[authority-handoff receipts](./authority-handoff-receipts.md) §4 step 6 rather than inventing
a second shape:

- carried and proof-covered **always**;
- **well-formedness only** when the verifier does not hold the referenced atom;
- a **full cross-check** when it does;
- **absence asserts no binding** — never an error.

## 6. Corpus references are falsifiable

`calibration.corpus` names a **published tree** and the **digest of that tree's
`SHA256SUMS`**. A verifier fetches the published corpus and recomputes. This is the difference
between a seat that *says* what it was calibrated on and one whose claim can be falsified.

## 7. Verification order

1. **`proof`** — recompute `evidence_hash` from the canonical bytes; verify the signature. An
   unauthenticated document is not worth inspecting.
2. **structure** — spec identifiers, stance/abstention exclusivity, distribution sums to 1,
   `alpha` present iff certifying, digests and corpus tree well-formed.
3. **`fidelity_ceiling`** — derived from calibration and compared to the declared value.

The ceiling check runs **last** so that a validly signed, well-formed, self-promoting
submission isolates to `fidelity_ceiling` and to nothing else.

Optional, when the verifier holds the artifacts: `precommitment_binding` (§5) and `corpus` (§6).

## 8. What this format deliberately does not do

- **No verdict path.** No outcome field exists, at any nesting level.
- **No second key registry.** One trust root, or the evidence does not cross.
- **No policy.** How much weight an `FD2`-capped stance actually receives is the evaluating
  engine's decision. This format only bounds the maximum honestly available.

## 9. Open

- **The submission event type** — how a submission enters an evaluating system as an evidence
  event — is not fixed by this version.
- **Whether `FD2` is the right cap** for a certifying seat, or whether certification should
  open `FD3` under stated conditions. `FD2` is the conservative choice and can only be
  loosened deliberately.
- **Seat key custody.** `key_id` resolution is deployment configuration and rotation works by
  holding several keys; there is no protocol-level registration ceremony, and this format
  deliberately does not invent one.

## 10. Conformance

An implementation conforms when it accepts every golden vector in
[`corpus/seat-evidence-v0.1/`](../corpus/seat-evidence-v0.1/) and rejects every tamper vector
**at the named `failing_check`**.

The corpus's distinguishing rows are the **genuinely re-signed self-promotions**: a seat that
raises its own `fidelity_ceiling` and signs the result honestly. A verifier that only checks
signatures accepts them, and is non-conforming. That is the row this format exists for.
