#!/usr/bin/env bash

set -eu

REPO_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TEST_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/azure-tenant-switcher.XXXXXX")
trap 'rm -rf "$TEST_ROOT"' EXIT

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

assert_equals() {
    if [ "$1" != "$2" ]; then
        fail "expected [$1], got [$2]"
    fi
}

mkdir -p "$TEST_ROOT/bin" "$TEST_ROOT/config"
cat >"$TEST_ROOT/config/tenants.bash" <<'EOF'
azure_tenant_switcher_config() {
    azure_tenant_switcher_add_tenant "contoso" "Contoso Engineering" "2f7d0a91-6c4e-4a82-9f10-3b5d8c6e1a27"
    azure_tenant_switcher_add_tenant "fabrikam" "Fabrikam Research" "8a3c5e71-1d9b-4f63-a8e2-6c0d4b9f7a15"
}
EOF

cat >"$TEST_ROOT/bin/az" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >"$TEST_AZ_LOG"
printf '%s\n' "$AZURE_CONFIG_DIR" >"$TEST_AZ_CONFIG_DIR"
if [ "$1" = "account" ] && [ "$2" = "get-access-token" ]; then
    exit "${MOCK_AZ_STATUS:-0}"
fi
EOF
chmod +x "$TEST_ROOT/bin/az"

export PATH="$TEST_ROOT/bin:$PATH"
export TEST_AZ_LOG="$TEST_ROOT/az-args"
export TEST_AZ_CONFIG_DIR="$TEST_ROOT/az-config-dir"
export AZURE_TENANT_SWITCHER_CONFIG="$TEST_ROOT/config/tenants.bash"
export AZURE_TENANT_SWITCHER_CONFIG_ROOT="$TEST_ROOT/azure-contexts"

# shellcheck disable=SC1090
source "$REPO_ROOT/azure-tenant-switcher.bash"

if azlogin >/dev/null 2>&1; then
    fail 'login succeeded without a selected tenant'
fi

azt contoso >/dev/null
assert_equals "$AZ_TENANT" "2f7d0a91-6c4e-4a82-9f10-3b5d8c6e1a27"
assert_equals "$AZ_TENANT_LABEL" "Contoso Engineering"
assert_equals "$AZURE_CONFIG_DIR" "$TEST_ROOT/azure-contexts/contoso"
assert_equals "$(azt_prompt_tag)" "[az:Contoso Engineering]"

azlogin --scope https://management.azure.com//.default
assert_equals \
    "$(cat "$TEST_AZ_LOG")" \
    "login --tenant 2f7d0a91-6c4e-4a82-9f10-3b5d8c6e1a27 --use-device-code --allow-no-subscriptions --scope https://management.azure.com//.default"
assert_equals "$(cat "$TEST_AZ_CONFIG_DIR")" "$TEST_ROOT/azure-contexts/contoso"

assert_equals "$(azt_completion)" "$(printf 'contoso\nfabrikam')"
assert_equals "$(azt_status)" "Signed in (cached): Contoso Engineering"

export MOCK_AZ_STATUS=1
if azt_status >/dev/null 2>&1; then
    fail 'status succeeded without a usable cached token'
fi
unset MOCK_AZ_STATUS

if azt missing >/dev/null 2>&1; then
    fail 'unknown tenant was accepted'
fi

cat >"$TEST_ROOT/config/invalid.bash" <<'EOF'
azure_tenant_switcher_config() {
    azure_tenant_switcher_add_tenant "invalid" "Invalid Tenant" "not-a-tenant-id"
}
EOF
export AZURE_TENANT_SWITCHER_CONFIG="$TEST_ROOT/config/invalid.bash"
if azt invalid >/dev/null 2>&1; then
    fail 'invalid tenant ID was accepted'
fi

printf '%s\n' 'All tests passed.'
