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
- `expect` — `pass` or `fail`.
- `failing_check` — where a failing case must be caught. Names per artifact:
  - AHR: `proof`, `evidence_hash`, `evidence_signature`, `claim_grounding`
  - CLE: `structure`, `event_hash`, `linkage`, `event_signature`, `audit_chain`,
    `record_signature`, `proof`
  - CAP: `proof`, `window`, `basis`
  - Anchor: `chain_structure`, `chain_linkage`, `checkpoint_hash`,
    `checkpoint_signature`, `truncated`, `rolled_back`

The manifests are language-agnostic: consume them from your own implementation's
test harness — each case names its artifact file(s), the trusted keys, and, for
failing cases, the exact check that must catch it.
