#!/bin/bash
# Smoke test: static checks only (no root, no systemd required).
# Run: bash tests/smoke.sh
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

check() { echo "[ CHECK ] $*"; }
ok()    { echo "[  OK   ] $*"; }
err()   { echo "[ FAIL  ] $*" >&2; FAIL=1; }

# 1. shellcheck
check "shellcheck"
if command -v shellcheck >/dev/null 2>&1; then
  if shellcheck \
      "$REPO_DIR/install.sh" \
      "$REPO_DIR/uninstall.sh" \
      "$REPO_DIR/bin/safe-server-lockdown" \
      "$REPO_DIR/bin/safe-server-healthcheck"; then
    ok "shellcheck passed"
  else
    err "shellcheck reported issues"
  fi
else
  echo "[  SKIP  ] shellcheck not installed"
fi

# 2. shfmt
check "shfmt formatting"
if command -v shfmt >/dev/null 2>&1; then
  if shfmt -d \
      "$REPO_DIR/install.sh" \
      "$REPO_DIR/uninstall.sh" \
      "$REPO_DIR/bin/safe-server-lockdown" \
      "$REPO_DIR/bin/safe-server-healthcheck"; then
    ok "shfmt: no formatting issues"
  else
    err "shfmt: formatting issues found (run: shfmt -w <file>)"
  fi
else
  echo "[  SKIP  ] shfmt not installed"
fi

# 3. systemd unit template placeholders are resolvable
check "systemd unit templates have no leftover placeholders after substitution"
GRACE=60 IFACE=tailscale0
for tmpl in "$REPO_DIR"/systemd/*.service "$REPO_DIR"/systemd/*.timer; do
  result=$(sed -e "s|@GRACE_MINUTES@|$GRACE|g" -e "s|@PRIVATE_IFACE@|$IFACE|g" "$tmpl")
  if echo "$result" | grep -q '@[A-Z_]*@'; then
    err "$tmpl: unresolved placeholder after substitution"
  else
    ok "$(basename "$tmpl"): no leftover placeholders"
  fi
done

# 4. Required files exist
check "required files exist"
required=(
  install.sh uninstall.sh config.env.example
  bin/safe-server-lockdown bin/safe-server-healthcheck
  systemd/safe-server-lockdown.service systemd/safe-server-lockdown.timer
  systemd/safe-server-healthcheck.service systemd/safe-server-healthcheck.timer
)
for f in "${required[@]}"; do
  if [[ -f "$REPO_DIR/$f" ]]; then
    ok "$f"
  else
    err "missing: $f"
  fi
done

echo
if [[ $FAIL -eq 0 ]]; then
  echo "All smoke tests passed."
else
  echo "One or more smoke tests FAILED."
  exit 1
fi
