# CSS Precommitment Atoms — v0.1 (draft)

> **Publication note (Succession Receipts).** This specification is published as part of
> **Succession Receipts** — the open verification surface for CSS evidence — see the
> repository README for scope. The wire format of each version is pinned by its golden
> vectors in [`corpus/precommit-v0.1/`](../corpus/precommit-v0.1/) and validated by the
> conformance corpus in this repository; independent implementations conform by passing it —
> for **every** published version.
>
> **Stability ladder.** v0.1 (draft) → v1.0 (stable). A published version is never mutated:
> format changes only ever add a new version with new golden vectors, and conforming
> verifiers keep verifying every published version. Corpus revisions are append-only.

A signature proves *who said a thing*; it does not prove the thing was said *before the
outcome was known*. The cheap epistemic cheat is hindsight — asserting a prediction after
seeing how it turned out, or quietly moving the goalposts (the metric, the deadline) once the
answer is in.

A **precommitment atom** removes that move. It locks *the question and the rule that resolves
it* — never the answer — into a signed, canonically-hashed, optionally externally-anchored
object, so that a later verifier can:

1. **re-execute the public rule** against the evidence and get the same verdict anyone would, and
2. **prove the commitment predated the evidence** (when anchored).

Provenance ≠ truth. The atom buys the one thing cryptography can buy honestly — *the question
was fixed first* — and defers truth to a re-runnable rule.

---

## 1. What an atom attests — and what it does not

A verified, resolved atom establishes:

- **The rule was fixed first.** The measurement method, its parameters, the horizon and the
  update rule are covered by the signature (and, when anchored, by an external existence-time
  witness), so none can be changed after the fact without breaking the proof.
- **The verdict is re-executable.** Applying the atom's own public rule to the supplied
  resolution evidence yields a deterministic `met` / `not_met` / `indeterminate` that any
  party recomputes identically. The atom never asserts the outcome; it asserts the **rule**.

It does **not** attest that the claim is *true*, that the evidence supplied at resolution is
itself honest (§6), or — from the signature alone — *when* it was created: a `created_at` in a
signed document is self-asserted, and existence-before-outcome is only as strong as the
external anchor (§5).

It introduces **no new trust root**: atoms are signed with the same Ed25519 key discipline and
the same `ed25519:<key_id>:<base64url>` signature form as every other format in this family.

## 2. Wire format

One atom is a JSON object. Canonicalization sorts keys, so the wire bytes — and therefore the
signed hash — are independent of field order. This is the same JCS discipline as the ledger
export, the handoff receipt and the anchor checkpoint.

| Field | Meaning |
|---|---|
| `spec` / `spec_version` | `"css-precommitment"` / `"0.1"` |
| `issuer` | issuing registry id (default `urn:css:registry`) |
| `id` | atom UUID |
| `claim` | the prediction or assertion, in prose |
| `confidence` | stated probability in `[0, 1]` |
| `measurement` | `{ method, params, context_digest? }` — the deterministic resolution rule |
| `horizon` | RFC 3339 UTC deadline by which the atom resolves |
| `update_rule` | what evidence resolves it / how the belief updates, in prose |
| `created_at` | RFC 3339 UTC — covered by the signature, but self-asserted (anchor to strengthen) |
| `proof` | issuer signature (§3) |

`measurement` is the machine-checkable core:

- **`method`** — a registered evaluator id. v0.1 registers four: `numeric-threshold`,
  `numeric-range`, `string-equals` and `boolean-equals`. The `precommit-v0.1` corpus exercises
  `numeric-threshold`; the others are registered and available.
- **`params`** — method-specific and fixed at commit time. For `numeric-threshold`:
  `{ "field": "<key>", "op": ">=" | ">" | "<=" | "<" | "==" | "!=", "threshold": "<decimal>" }`.
- **`context_digest`** — optional hex SHA-256 over inputs *known at commit time* (a dataset
  spec, a model version) that the resolver confirms unchanged. It never digests the future
  outcome.

## 3. Proof

SHA-256 over the canonical atom bytes with the `proof` member **absent**, signed in the
family's canonical signature form:

```json
"proof": {
  "type": "CSSEd25519Signature",
  "created": "2026-07-24T06:30:00Z",
  "verification_method": "precommit-vector-1",
  "precommitment_hash": "…",
  "signature": "ed25519:precommit-vector-1:…"
}
```

`created` is **excluded** from the signed message, so re-signing identical content yields the
same `precommitment_hash`. Every §2 content field **is** covered.

## 4. Resolution by re-execution

Resolution is a separate step, run at or after `horizon`, over evidence that is not part of
the signed atom. Given a verified atom and a resolution evidence object:

1. **Well-formedness and proof.** Recompute the canonical hash and require it to equal
   `proof.precommitment_hash`; verify the signature; require `confidence` in `[0,1]`, a
   registered `method`, and a parseable `horizon`.
2. **Context.** If `context_digest` is set, require the supplied context to hash to it.
3. **Re-execute.** Look up the evaluator for `measurement.method` and apply `params` to the
   evidence. The result is `met`, `not_met`, or `indeterminate` (evidence missing or
   ill-typed for the rule). The evaluator is a **pure, deterministic function of
   `(params, evidence)`** — no clocks, no network, no state — so the verdict is reproducible
   by anyone.

The verdict is the atom's own rule applied to the world, not the issuer's say-so.

**Note on `indeterminate`.** Evidence that does not answer the rule is not a failed claim. An
implementation that collapses `indeterminate` into `not_met` is non-conforming: the
distinction is the difference between *the claim was wrong* and *we cannot tell*.

## 5. Existence-before-outcome (anchoring)

The signature fixes the content; it does not fix the *time*. To make "the rule was committed
before the evidence" externally checkable, the atom's canonical bytes — whose SHA-256 is the
`precommitment_hash` (§3) — are anchored exactly as an anchor checkpoint is, through an
OpenTimestamps witness (see [external anchoring](./external-anchoring.md)).

The confirmed proof attests that the atom existed no later than a given Bitcoin block,
depending on no key or service the issuer controls.

Anchoring is a **sidecar**: the wire format (§2) and resolution (§4) are unchanged,
verification stays fully offline (the witness is consulted only at stamping time), and it
reuses the existing anchor discipline — no new cryptography, no new keys.

## 6. Honest limits

- **Garbage in.** Re-execution is only as meaningful as the resolution evidence. The atom
  fixes the *rule*; it does not vouch for the *evidence*. Pair it with a signed evidence
  source — a ledger export, a signed metric report — when the evidence itself must be trusted.
- **Self-asserted time without an anchor.** Absent §5, `created_at` is the issuer's word.
- **Expressiveness.** The registered evaluators are deliberately simple. The format is
  method-agnostic by construction.

## 7. Evolution

`spec_version` is pinned; changes follow the additive-evolution discipline of the other
formats in this family: older verifiers tolerate new optional fields, a new
`measurement.method` is a **registration rather than a version bump**, and breaking changes
bump the version. Published versions are never mutated.

## 8. Conformance

An implementation conforms when it accepts every golden vector in
[`corpus/precommit-v0.1/`](../corpus/precommit-v0.1/), recomputes the stated `resolution` for
each vector that names `evidence`, and rejects every tamper vector **at the named
`failing_check`** — not merely rejecting it, but failing for the stated reason.

The corpus includes tamper rows that are **validly signed by the issuer** — content changed
after signing, a confidence outside `[0,1]`, an unregistered method. These exist because a
verifier that only checks signatures passes a corpus of forgeries by an honest-keyed liar.
