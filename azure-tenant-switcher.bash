#!/usr/bin/env bash
# Source this file from Bash to switch Azure CLI configuration directories by tenant.

if [ -z "${BASH_VERSION:-}" ]; then
    printf '%s\n' 'azure-tenant-switcher requires Bash.' >&2
    return 1 2>/dev/null || exit 1
fi

AZURE_TENANT_SWITCHER_SLUGS=()
AZURE_TENANT_SWITCHER_LABELS=()
AZURE_TENANT_SWITCHER_IDS=()

_azt_config_path() {
    if [ -n "${AZURE_TENANT_SWITCHER_CONFIG:-}" ]; then
        printf '%s\n' "$AZURE_TENANT_SWITCHER_CONFIG"
    else
        printf '%s\n' "$HOME/.config/azure-tenant-switcher/tenants.bash"
    fi
}

_azt_valid_slug() {
    [[ "$1" =~ ^[a-z][a-z0-9-]*$ ]]
}

_azt_valid_tenant_id() {
    [[ "$1" =~ ^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-4[0-9A-Fa-f]{3}-[89AaBb][0-9A-Fa-f]{3}-[0-9A-Fa-f]{12}$ ]]
}

azure_tenant_switcher_add_tenant() {
    local slug label tenant_id existing_slug

    if [ "$#" -ne 3 ]; then
        printf '%s\n' 'Expected: azure_tenant_switcher_add_tenant <slug> <label> <tenant-id>' >&2
        return 1
    fi

    slug=$1
    label=$2
    tenant_id=$3

    if ! _azt_valid_slug "$slug"; then
        printf 'Invalid tenant slug: %s\n' "$slug" >&2
        return 1
    fi

    if [ -z "$label" ]; then
        printf 'Tenant label cannot be empty: %s\n' "$slug" >&2
        return 1
    fi

    if ! _azt_valid_tenant_id "$tenant_id"; then
        printf 'Invalid tenant ID for %s\n' "$slug" >&2
        return 1
    fi

    if [ "${#AZURE_TENANT_SWITCHER_SLUGS[@]}" -gt 0 ]; then
        for existing_slug in "${AZURE_TENANT_SWITCHER_SLUGS[@]}"; do
            if [ "$existing_slug" = "$slug" ]; then
                printf 'Duplicate tenant slug: %s\n' "$slug" >&2
                return 1
            fi
        done
    fi

    AZURE_TENANT_SWITCHER_SLUGS[${#AZURE_TENANT_SWITCHER_SLUGS[@]}]=$slug
    AZURE_TENANT_SWITCHER_LABELS[${#AZURE_TENANT_SWITCHER_LABELS[@]}]=$label
    AZURE_TENANT_SWITCHER_IDS[${#AZURE_TENANT_SWITCHER_IDS[@]}]=$tenant_id
}

_azt_load_config() {
    local config_path

    config_path=$(_azt_config_path)
    if [ ! -r "$config_path" ]; then
        printf 'Tenant configuration not found: %s\n' "$config_path" >&2
        return 1
    fi

    AZURE_TENANT_SWITCHER_SLUGS=()
    AZURE_TENANT_SWITCHER_LABELS=()
    AZURE_TENANT_SWITCHER_IDS=()
    unset -f azure_tenant_switcher_config 2>/dev/null || true

    # The user-owned file defines data through azure_tenant_switcher_add_tenant.
    source "$config_path" || return 1

    if ! declare -f azure_tenant_switcher_config >/dev/null 2>&1; then
        printf 'Tenant configuration must define azure_tenant_switcher_config().\n' >&2
        return 1
    fi

    azure_tenant_switcher_config || return 1

    if [ "${#AZURE_TENANT_SWITCHER_SLUGS[@]}" -eq 0 ]; then
        printf 'Tenant configuration did not define any tenants.\n' >&2
        return 1
    fi
}

azt() {
    local slug config_root index

    if [ "$#" -ne 1 ]; then
        printf '%s\n' 'Usage: azt <tenant-slug>' >&2
        return 2
    fi

    slug=$1
    _azt_load_config || return 1

    index=0
    while [ "$index" -lt "${#AZURE_TENANT_SWITCHER_SLUGS[@]}" ]; do
        if [ "${AZURE_TENANT_SWITCHER_SLUGS[$index]}" = "$slug" ]; then
            config_root=${AZURE_TENANT_SWITCHER_CONFIG_ROOT:-"$HOME/.azure-tenants"}
            AZURE_CONFIG_DIR="$config_root/$slug"
            AZ_TENANT_LABEL=${AZURE_TENANT_SWITCHER_LABELS[$index]}
            AZ_TENANT=${AZURE_TENANT_SWITCHER_IDS[$index]}
            AZURE_TENANT_SWITCHER_ACTIVE_SLUG=$slug
            export AZURE_CONFIG_DIR AZ_TENANT_LABEL AZ_TENANT AZURE_TENANT_SWITCHER_ACTIVE_SLUG
            printf 'Selected Azure tenant: %s\n' "$AZ_TENANT_LABEL"
            return 0
        fi
        index=$((index + 1))
    done

    printf 'Unknown tenant slug: %s\n' "$slug" >&2
    return 1
}

azt_list() {
    local index

    _azt_load_config || return 1
    index=0
    while [ "$index" -lt "${#AZURE_TENANT_SWITCHER_SLUGS[@]}" ]; do
        printf '%s\t%s\n' "${AZURE_TENANT_SWITCHER_SLUGS[$index]}" "${AZURE_TENANT_SWITCHER_LABELS[$index]}"
        index=$((index + 1))
    done
}

azt_completion() {
    _azt_load_config || return 1
    printf '%s\n' "${AZURE_TENANT_SWITCHER_SLUGS[@]}"
}

_azt_complete() {
    local current_word

    current_word=${COMP_WORDS[COMP_CWORD]}
    COMPREPLY=($(compgen -W "$(azt_completion)" -- "$current_word"))
}

azlogin() {
    if [ -z "${AZ_TENANT:-}" ]; then
        printf '%s\n' 'No Azure tenant is selected. Run: azt <tenant-slug>' >&2
        return 1
    fi

    if ! command -v az >/dev/null 2>&1; then
        printf '%s\n' 'Azure CLI (az) is not available on PATH.' >&2
        return 127
    fi

    command az login --tenant "$AZ_TENANT" --use-device-code --allow-no-subscriptions "$@"
}

azt_status() {
    if [ -z "${AZ_TENANT:-}" ] || [ -z "${AZ_TENANT_LABEL:-}" ]; then
        printf '%s\n' 'No Azure tenant is selected.'
        return 1
    fi

    if ! command -v az >/dev/null 2>&1; then
        printf 'Selected, Azure CLI unavailable: %s\n' "$AZ_TENANT_LABEL"
        return 1
    fi

    if command az account get-access-token --tenant "$AZ_TENANT" --resource https://management.azure.com/ --only-show-errors >/dev/null 2>&1; then
        printf 'Signed in (cached): %s\n' "$AZ_TENANT_LABEL"
    else
        printf 'Not signed in: %s\n' "$AZ_TENANT_LABEL"
        return 1
    fi
}

azt_prompt_tag() {
    if [ -n "${AZ_TENANT_LABEL:-}" ]; then
        printf '[az:%s]' "$AZ_TENANT_LABEL"
    fi
}

azt_help() {
    printf '%s\n' \
        'azt <tenant-slug>  Select a tenant-specific Azure CLI configuration directory.' \
        'azt_list            List configured tenant slugs and labels.' \
        'azlogin [az args]   Sign in to the selected tenant with device code.' \
        'azt_status          Report whether the selected tenant has a usable cached token.' \
        'azt_prompt_tag      Print a compact label for use in a Bash prompt.'
}

if [[ $- == *i* ]]; then
    complete -F _azt_complete azt
fi
