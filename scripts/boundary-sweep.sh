#!/usr/bin/env sh
# Boundary sweep — the standing guard behind this repository's one rule:
# it describes the wire format and its verification only. Nothing here may
# reference how the proprietary CSS engine is built. The sweep fails CI on
# any reappearance of engine-internal reference classes.
#
# Exits non-zero listing every hit. Zero hits is the only passing state.
set -u

# Engine-internal reference patterns: producer commands, storage/config
# shapes, key-file conventions, internal package/function paths, and
# engine-repo document paths. Extend the list; never narrow it.
PATTERNS='
cmd/ledgerexport
cmd/apiserver
cmd/auditcheck
CSS_DB_DSN
postgres://
signing_priv
/etc/css/
internal/ledger
internal/pdp
internal/broker
internal/registry
internal/recovery
receipt\.Build
ledger\.Build
stewardagg
docs/protocol/
docs/audit/
remediation-status
'

FAIL=0
for pat in $PATTERNS; do
  hits=$(grep -RIn --exclude-dir=.git --exclude="boundary-sweep.sh" -e "$pat" . 2>/dev/null)
  if [ -n "$hits" ]; then
    echo "BOUNDARY VIOLATION — pattern '$pat':"
    echo "$hits"
    FAIL=1
  fi
done

if [ "$FAIL" -ne 0 ]; then
  echo ""
  echo "The sweep found engine-internal references. This repository publishes the"
  echo "wire format and its verification only — rewrite the offending prose to"
  echo "describe observable bytes, not the engine that produces them."
  exit 1
fi
echo "boundary sweep: clean (0 hits)"
