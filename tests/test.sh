#!/usr/bin/env bash

set -u

PROJECT_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TEST_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/azure-tenant-switcher.XXXXXX")

cleanup() {
  rm -rf "$TEST_ROOT"
}

trap cleanup EXIT HUP INT TERM

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

assert_equal() {
  [[ $1 == "$2" ]] || fail "expected '$2', got '$1'"
}

assert_contains() {
  case $1 in
    *"$2"*) ;;
    *) fail "expected '$1' to contain '$2'" ;;
  esac
}

export HOME="$TEST_ROOT/home"
export AZURE_TENANT_SWITCHER_CONFIG="$TEST_ROOT/tenants.conf"
export AZURE_TENANT_SWITCHER_CONFIG_ROOT="$TEST_ROOT/azure-contexts"
mkdir -p "$HOME" "$TEST_ROOT/bin"

cat > "$AZURE_TENANT_SWITCHER_CONFIG" <<'EOF'
# Test-only fictitious entries.
contoso|11111111-2222-4333-8444-555555555555|Contoso Engineering
fabrikam|22222222-3333-4444-8555-666666666666|Fabrikam Research
EOF

cat > "$TEST_ROOT/bin/az" <<'EOF'
#!/usr/bin/env bash
if [[ ${1:-} == account ]]; then
  exit "${AZT_TEST_AZ_STATUS:-0}"
fi
printf '%s\n' "$@" > "$AZT_TEST_AZ_LOG"
EOF
chmod +x "$TEST_ROOT/bin/az"
export PATH="$TEST_ROOT/bin:$PATH"
export AZT_TEST_AZ_LOG="$TEST_ROOT/az.log"

# shellcheck source=../azure-tenant-switcher.bash
source "$PROJECT_ROOT/azure-tenant-switcher.bash"

if azlogin >/dev/null 2>&1; then
  fail "login without a selected tenant must fail"
fi

if azt does-not-exist >/dev/null 2>&1; then
  fail "unknown aliases must fail"
fi

azt contoso >/dev/null
assert_equal "$AZURE_CONFIG_DIR" "$AZURE_TENANT_SWITCHER_CONFIG_ROOT/contoso"
assert_equal "$AZ_TENANT" "11111111-2222-4333-8444-555555555555"
assert_equal "$AZ_TENANT_LABEL" "Contoso Engineering"
[[ -d $AZURE_CONFIG_DIR ]] || fail "context directory was not created"

tenant_list=$(azt --list)
assert_contains "$tenant_list" $'contoso\tContoso Engineering'
assert_contains "$tenant_list" $'fabrikam\tFabrikam Research'
if [[ $tenant_list == *11111111* ]]; then
  fail "tenant list must not display tenant IDs"
fi

if azt ../escape >/dev/null 2>&1; then
  fail "invalid aliases must fail"
fi
[[ ! -e "$TEST_ROOT/escape" ]] || fail "invalid alias escaped the context root"
assert_equal "${AZURE_CONFIG_DIR-}" ""
assert_equal "${AZ_TENANT-}" ""
assert_equal "${AZ_TENANT_LABEL-}" ""

azt contoso >/dev/null

azlogin >/dev/null
login_arguments=$(cat "$AZT_TEST_AZ_LOG")
assert_contains "$login_arguments" "login"
assert_contains "$login_arguments" "--tenant"
assert_contains "$login_arguments" "11111111-2222-4333-8444-555555555555"
assert_contains "$login_arguments" "--use-device-code"
assert_contains "$login_arguments" "--allow-no-subscriptions"

active_status=$(azt_status)
assert_contains "$active_status" "active for Contoso Engineering"

export AZT_TEST_AZ_STATUS=1
if azt_status >/dev/null 2>&1; then
  fail "inactive Azure CLI session must fail"
fi
unset AZT_TEST_AZ_STATUS

printf 'contoso|not-a-uuid|Contoso Engineering\n' > "$AZURE_TENANT_SWITCHER_CONFIG"
if azt contoso >/dev/null 2>&1; then
  fail "malformed tenant IDs must fail"
fi
assert_equal "${AZURE_CONFIG_DIR-}" ""
assert_equal "${AZ_TENANT-}" ""
assert_equal "${AZ_TENANT_LABEL-}" ""

cat > "$AZURE_TENANT_SWITCHER_CONFIG" <<'EOF'
contoso|11111111-2222-4333-8444-555555555555|Contoso Engineering
fabrikam|22222222-3333-4444-8555-666666666666|Fabrikam Research
EOF
export AZURE_TENANT_SWITCHER_CONFIG_ROOT="$TEST_ROOT/not-a-directory"
printf 'x\n' > "$AZURE_TENANT_SWITCHER_CONFIG_ROOT"
if azt fabrikam >/dev/null 2>&1; then
  fail "context directory creation failures must fail"
fi
assert_equal "${AZURE_CONFIG_DIR-}" ""
assert_equal "${AZ_TENANT-}" ""
assert_equal "${AZ_TENANT_LABEL-}" ""
export AZURE_TENANT_SWITCHER_CONFIG_ROOT="$TEST_ROOT/azure-contexts"

cat > "$AZURE_TENANT_SWITCHER_CONFIG" <<'EOF'
contoso|11111111-2222-4333-8444-555555555555|Contoso Engineering
fabrikam|not-a-uuid|Fabrikam Research
EOF
if azt contoso >/dev/null 2>&1; then
  fail "a malformed later entry must fail selection"
fi

cat > "$AZURE_TENANT_SWITCHER_CONFIG" <<'EOF'
contoso|11111111-2222-4333-8444-555555555555|Contoso Engineering
contoso|22222222-3333-4444-8555-666666666666|Contoso Duplicate
EOF
if azt --list >/dev/null 2>&1; then
  fail "duplicate aliases must fail"
fi

printf '%s\n' "PASS: azure-tenant-switcher tests"
