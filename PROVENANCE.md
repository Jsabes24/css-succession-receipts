# Provenance

This repository is the home of an open format. Anyone may implement it under
Apache-2.0 — that is the point, and nothing here tries to prevent it. What is
not transferable, and what this file records how to *prove*, is three things:

- **Attribution.** Apache-2.0 §4 and the [NOTICE](./NOTICE) require credit to
  Continuity Laboratories on redistribution.
- **Priority.** That this format was authored and first published, on a date,
  by J. Sabey / Continuity Laboratories — provable to someone who has no reason
  to take our word for it.
- **Brand.** "Succession Receipts" and "Succession Verified" are Continuity
  Laboratories' marks (see [NOTICE](./NOTICE)); passing the conformance corpus
  does not license them.

The format itself is unprotectable by design. These three are not, and the
proofs below make each of them tamper-evident.

## What already anchors this work

- **Content addressing.** Every file is fixed by its Git object hash, and the
  root commit hash covers the whole tree. Publishing that commit publicly is
  itself a dated, third-party-witnessed record.
- **Conformance corpus checksums.** corpus/SHA256SUMS fingerprints every vector. Published revisions are immutable  a revision is a new directory, never an edit  so the manifest only ever grows, and each state’s checksums are a permanent fingerprint of the vectors published to that point. The in-tree corpus/SHA256SUMS.ots is re-stamped in place as the corpus is extended; the root-level SHA256SUMS.ots is the original v0.1.1-era stamp, kept in place for lineage.
- **Internet-Draft.** draft-sabey-succession-receipts and its two companions (draft-sabey-succession-receipts-sd, draft-sabey-refusal-transparency) are filed to the IETF Datatracker, which publishes a world-readable, permanently archived, timestamped, attributed record. They are the single strongest priority anchor.

## Release provenance (per tagged version)

Each release layers independent proofs over `corpus/SHA256SUMS`, so that no one
service and no one key is load-bearing:

1. **Signed tag.** The version tag is an SSH-signed Git tag (`gpg.format=ssh`),
   made with the maintainer's release signing key — the same Ed25519 key that
   signed the root commit, so the seed and the tag verify against a single key.
   It binds the exact tree, the author, and the date.
   - Maintainer signing key (Ed25519):
     `ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIICO/HA6C/Z7cHcb4C8OcbF0Zb69duDYF3dNO6INFF8i`
   - Fingerprint: `SHA256:0VJgyx/oKDe3qzZJPjRv6qLzHAhLa5Ce2W1d1Qwwj4E`
   - Verify:
     ```
     echo '295051480+Jsabes24@users.noreply.github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIICO/HA6C/Z7cHcb4C8OcbF0Zb69duDYF3dNO6INFF8i' > allowed_signers
     git -c gpg.ssh.allowedSignersFile=allowed_signers verify-tag v0.1.1
     ```

2. **Signed checksums (transparency log).** `corpus/SHA256SUMS` is signed with
   cosign keyless signing; the Sigstore bundle carries the signing identity and
   a Rekor transparency-log entry. This is the same signing already used for the
   reference verifier's release artifacts.
   - Verify:
     ```
     cosign verify-blob SHA256SUMS --bundle SHA256SUMS.sigstore.json \
       --certificate-identity-regexp 'github\.com/[Jj]sabes24/css-succession-receipts' \
       --certificate-oidc-issuer https://token.actions.githubusercontent.com
     ```

3. **Independent timestamp (Bitcoin).** `corpus/SHA256SUMS` is stamped with
   OpenTimestamps. The proof commits the checksum digest into the Bitcoin
   blockchain through the OpenTimestamps calendars, giving an "existed no later
   than block T" attestation that depends on no operator we control and stays
   verifiable from Bitcoin's block headers alone.
   - Verify: `ots verify SHA256SUMS.ots` (against the released `SHA256SUMS`)
   - The stamp is issued at release time and is initially pending; the
     maintainer runs `ots upgrade SHA256SUMS.ots` once the Bitcoin attestation
     confirms, then commits the upgraded proof.

The three release assets — `SHA256SUMS`, `SHA256SUMS.sigstore.json`, and
`SHA256SUMS.ots` — all correspond byte-for-byte to the in-tree
[`corpus/SHA256SUMS`](./corpus/SHA256SUMS).

**Version numbering.** This repository’s first release is v0.1.1. The v0.1.2 number was consumed by the release workflow’s dispatch path and its tag retired unused. v0.1.3 is a documentation only release: it lowercases the jsabes24 casing in the Internet-Draft’s reference URLs and changes nothing under corpus/, so its SHA256SUMS (df3b122f…cf00e44) is byte-identical to v0.1.1’s and is already anchored by the same Bitcoin timestamp. Its tag was minted by the release workflow’s dispatch path and is therefore a lightweight, unsigned tag  unlike the SSH-signed v0.1.1 tag above; future releases should be cut from a signed annotated tag to preserve the signed-tag guarantee. The v0.1.0 and v0.2.0 tag names were used by a superseded lineage of this repository and are permanently retired under GitHub’s immutable-release guarantee; the wire-format spec versions and the published corpus vectors are unchanged.

**Why both a transparency log and OpenTimestamps.** The log gives an immediate,
machine-checkable entry tied to the signing identity; OpenTimestamps gives an
attestation that survives even if that log — or this project — does not. The
"we did not backdate this" claim rests on the second one, because its clock is
external to us: a transparency log we operated could not, by itself, prove our
own priority.

## Dogfooding the format's own anchoring

[`spec/external-anchoring.md`](./spec/external-anchoring.md) defines how a
ledger export commits its head to an external checkpoint, so a verifier can
prove it was not truncated or rolled back below an anchored point. The release
provenance above is that same idea applied to this repository: the checksum
digest is the head, and the OpenTimestamps proof is the external anchor.

A later revision may additionally publish the release digest to a SCITT
transparency service (RFC 9162 Merkle-tree logs; see the SCITT architecture
work referenced by the Internet-Draft), with that service's checkpoint itself
carried by the OpenTimestamps anchor — so the demonstration is real without the
priority claim ever resting on a log we run.

## Held by the maintainer (not automatable)

- The release signing key, and the acts of signing the tag and upgrading the
  timestamp proof after Bitcoin confirmation.
- Registration of the "Succession Receipts" and "Succession Verified" marks.
- Deposit of each public release into a third-party software archive, once the
  repository is public, for a durable and citable copy.

## Not done, on purpose (v0.1)
The corpus is committed to be byte-identical to its published vectors in every revision, so it carries no embedded provenance markers;adding any would break that immutability promise. A watermarking scheme, if ever wanted, belongs to a future corpus revision — never a re-edit of a published one.
