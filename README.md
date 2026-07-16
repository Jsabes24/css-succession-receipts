# Succession Receipts

**The open wire format for cryptographic evidence of authority succession —
verifiable offline with only a public key.**

**Succession Receipts** is the format family for evidence of *authority succession*:
who held authority over an autonomous agent, who holds it now, under what legitimacy
determination it transferred, and which obligations carried forward. Where decision
receipts prove what an agent *did* and delegation receipts prove what it *may do*,
Succession Receipts prove the agent legitimately *became* the authority holder.

This repository is the format's home — the **specifications**, the **conformance
corpus**, and the **Internet-Draft**. It deliberately contains no verifier or engine
code: the format is public so that anyone can implement an independent verifier and
prove conformance against the corpus, and so that the evidence never requires taking
the operator's word for anything.

[CSS](https://continuitylaboratories.com) (the Constitutional Stewardship System) is
the system of record that *produces* this evidence: when an AI agent is upgraded,
replaced, suspended, or restored, CSS decides whether the successor legitimately
inherits authority, refuses invalid transfers, and records every decision in a
signed, hash-linked ledger. The CSS engine — and its reference verifier — are
proprietary software of Continuity Laboratories; this repository is the open format
they implement.

## Format commitments

- **Published versions are never mutated.** Format changes only ever add a new
  version with new golden vectors; conforming verifiers keep verifying every
  published version (see the stability ladder in each spec).
- **Corpus revisions are immutable.** New engine behavior means a new revision
  directory, never an edit.
- **Algorithm agility.** The `<alg>:<key_id>:<base64url(sig)>` signature string
  carries an algorithm prefix by construction; new schemes (e.g. post-quantum) are
  additive prefixes, never breaking changes.

## The artifacts

| Artifact | Spec | What it proves |
|---|---|---|
| **Authority-Handoff Receipt** (AHR) | [spec/authority-handoff-receipts.md](./spec/authority-handoff-receipts.md) | One completed, policy-gated authority handoff: parties, revoked and derived authorities, the legitimacy evaluation it ran under, and the full obligation/commitment lineage — every claim grounded in signed evidence events |
| **CSS Ledger Export** (CLE) | [spec/ledger-export.md](./spec/ledger-export.md) | An entire ledger: every event in publication order, hash-chain linkage, signatures, every audit chain, and the issuer's completeness attestation |
| **Capability credential** (CAP) | [spec/authorization-decisions.md](./spec/authorization-decisions.md) §2.2 | A short-lived signed capability: the issuer proof, the validity window, and that its basis is a genuine permit decision |
| **Anchoring checkpoints** | [spec/external-anchoring.md](./spec/external-anchoring.md) | That a ledger export was not truncated or rolled back below any externally anchored head |
| **Refusal digest** | [spec/refusal-transparency.md](./spec/refusal-transparency.md) | A standing adversarial probe run: each attack, the guard that refused it, the verbatim refusal ground, and the complete signed ledger of the attempt — in which the refused transition is provably absent |

Key discovery and pinning: [spec/keyset.md](./spec/keyset.md).

## Verify CSS evidence today

- **In the browser, no install:** <https://continuitylaboratories.com/receipts> — paste
  a receipt or drop a file; everything runs locally in the page and nothing you paste
  leaves the browser.
- **Reference verifier:** `sr-verify` (one subcommand per artifact) is maintained by
  Continuity Laboratories and held byte-compatible with the engine by this corpus.

## Implementing your own verifier

The format is deliberately public so third parties can implement independent
verifiers. Everything needed is here: the specs define the canonical forms and check
algorithms (including the byte-level serialization rules — Go `encoding/json`-compatible
escaping, order-preserving payload re-serialization, an RFC 8785-coinciding canonical
form), and the [conformance corpus](./corpus/) tells you whether you got it right: a
conforming implementation **accepts every golden vector and rejects every tamper case
at the named check**. If your implementation passes every corpus case, it verifies
real CSS evidence.

The corpus is the substrate of the planned **"Succession Verified"** conformance
program for third-party verifier implementations (mark reserved — see
[NOTICE](./NOTICE)).

## Internet-Draft

[`ietf/`](./ietf/) carries `draft-sabey-succession-receipts-00` in kramdown-rfc
source form — the citable, venue-appropriate statement of the format and its
verification algorithm, derived from the AHR spec.

## Boundary

This repository describes the **wire format and its verification only**. A standing
CI guard ([`scripts/boundary-sweep.sh`](./scripts/boundary-sweep.sh)) checks every
change against a deny-list of engine-internal reference patterns, so spec prose can
never disclose how the engine that produces the evidence is built.

## License

[Apache-2.0](./LICENSE). See [NOTICE](./NOTICE) for trademark reservations. The CSS
engine and its reference verifier are separate, proprietary software of Continuity
Laboratories — this repository grants no rights to either.
