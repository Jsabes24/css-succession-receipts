# Succession Receipts conformance corpus

The corpus is the executable definition of conformance: a verifier implementation is
conforming for an artifact version when it **accepts every golden vector and rejects
every tamper case at the named check**.

## Layout

```
corpus/
  keys/                      # PKIX PEM public keys the manifests reference
  <artifact>-v<version>/r<N>/  # one immutable revision of one artifact's cases
    manifest.json
    golden.json / chain.jsonl / …
```

Revisions are immutable snapshots: new engine behavior produces a new `rN+1`
directory; published files are never edited. Vector keys derive from published test
seeds (they exist so cases like a lying issuer re-signing altered content can be
expressed) — they are test constants, not secrets, and secure nothing.

**Reference material may be added to a revision; results may not be changed.** The
rule above forbids editing a published file and ties a new revision to new engine
behavior. A file that no case references, that changes no expected result and that
leaves every published byte identical is neither of those things, and cutting an
`rN+1` whose cases and verdicts are byte-identical to `rN` would announce a
behavior change that did not happen. Two revisions carry such material today:

- `ahr-v0.2/r2/cross-format-vector.json` — the contributed cross-format fixture,
  verbatim, carrying its own `caid_derivation` block.
- `ahr-v0.2/r3/cross-format-vector-{1of1,2of3}.json` and
  `ahr-v0.2/r3/caid-derivation.json` — the contributed native artifacts, verbatim,
  and the derivation of r3's published `caid` and `receipt_hash` values.

The r3 files were added after r3 was first published, and the reason is worth
recording rather than smoothing over: the contributed native artifacts carry only
the receipt and the claim, with no `caid_derivation` block of the kind r2's fixture
carried, and the mapping profile those values were generated under lived only in
the test sources of repositories that are not published. A relying party could read
r3's claimed identifiers and had no published way to reproduce them. That is a
conformance corpus failing at the one thing it exists for.

Adding them re-stamps `SHA256SUMS`, which every change to this tree does. No case
was added, no expected result moved, and no manifest was touched.

## Manifest format

```json
{
  "artifact": "authority-handoff-receipt",
  "spec_version": "0.1",
  "revision": 1,
  "keys": { "ahr-vector-1": "../../keys/vector.pub.pem" },
  "cases": [
    { "name": "golden", "file": "golden.json", "expect": "pass" },
    { "name": "content-altered", "file": "content-altered.json",
      "expect": "fail", "failing_check": "proof", "note": "…" }
  ]
}
```

- `keys` — key_id → key path (relative to the manifest), the trusted set for every
  case in the revision.
- `file` — the artifact document (`log` + `ledger` for anchoring cases, which pair a
  checkpoint chain with an export).
- `eval_at` — for time-windowed artifacts (CAP), the RFC 3339 instant to evaluate at.
- `expect` — `pass`, `fail`, or `not_verified`.
  - `not_verified` is the third result of `draft-sabey-succession-receipts`
    §6 step 3: the verifier **could not perform** the check. That is a fact
    about the verifier, not about the evidence, and it is not a `fail`. A
    relying party requiring a verified result must accept neither. Cases
    expecting it exist because an unregistered format, an absent
    relying-party pin, and a missing artifact all reach it — and because
    reporting them as failures is a defect corpora should catch, not
    reproduce.
  - A case whose `expect` is `not_verified` asserts what the **cross-check**
    reports, so a harness must actually run it — including when the case
    names no artifact, which is the "carried but unchecked" state itself.
    Skipping the call there and reporting the containing receipt's own
    validity is precisely the conflation this value exists to separate.
- `expect_without_native_verification` — the result for a verifier that does
  **not** implement the named foreign format's own verification procedure
  (§6 step 4). Present only on cases whose outcome depends on that
  capability; absent means the expectation holds for any verifier.

  It exists because §6 orders native verification *before* the digest and
  identifier comparisons, so a verifier lacking that procedure stops at step 4
  and reports `not_verified` — including for cases whose evidence is
  demonstrably bad. Recording only the capable verifier's expectation would
  make every other implementation look non-conforming; recording only the
  incapable one's would leave the digest and identifier rules unpinned. Two
  fields, because there are two honest answers and which applies is a fact
  about the verifier, not about the vector. Use the one that matches what your
  implementation actually does.

- `failing_check` — where a failing case must be caught. Names per artifact:
  - AHR: `proof`, `evidence_hash`, `evidence_signature`, `claim_grounding`,
    `authorization_binding`, `version_claims`
  - CLE: `structure`, `event_hash`, `linkage`, `event_signature`, `audit_chain`,
    `record_signature`, `proof`
  - CAP: `proof`, `window`, `basis`
  - Anchor: `chain_structure`, `chain_linkage`, `checkpoint_hash`,
    `checkpoint_signature`, `truncated`, `rolled_back`

The manifests are language-agnostic: consume them from your own implementation's
test harness — each case names its artifact file(s), the trusted keys, and, for
failing cases, the exact check that must catch it.
