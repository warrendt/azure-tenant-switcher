# Azure Tenant Switcher
#
# Source this file from an interactive Bash session. Tenant mappings are read
# from a plain-text, user-local configuration file; this script never stores
# Azure CLI credentials or tokens itself.

: "${AZURE_TENANT_SWITCHER_CONFIG:=${XDG_CONFIG_HOME:-$HOME/.config}/azure-tenant-switcher/tenants.conf}"
: "${AZURE_TENANT_SWITCHER_CONFIG_ROOT:=$HOME/.azure-tenants}"

_azt_error() {
  printf 'azure-tenant-switcher: %s\n' "$*" >&2
}

_azt_valid_alias() {
  [[ $1 =~ ^[[:alnum:]][[:alnum:]_-]*$ ]]
}

_azt_valid_tenant_id() {
  [[ $1 =~ ^[[:xdigit:]]{8}-[[:xdigit:]]{4}-[[:xdigit:]]{4}-[[:xdigit:]]{4}-[[:xdigit:]]{12}$ ]]
}

_azt_valid_label() {
  [[ -n $1 && $1 =~ ^[[:print:]]+$ ]]
}

_azt_find_tenant() {
  local requested_alias=$1
  local alias='' tenant_id='' label='' extra=''
  local seen_aliases='' selected=0

  AZT_ALIAS=
  AZT_TENANT_ID=
  AZT_LABEL=

  if ! _azt_valid_alias "$requested_alias"; then
    _azt_error "invalid tenant alias: $requested_alias"
    return 1
  fi

  if [[ ! -r $AZURE_TENANT_SWITCHER_CONFIG ]]; then
    _azt_error "configuration is not readable: $AZURE_TENANT_SWITCHER_CONFIG"
    return 1
  fi

  while IFS='|' read -r alias tenant_id label extra || [[ -n $alias$tenant_id$label$extra ]]; do
    label=${label%$'\r'}
    [[ -z $alias || $alias == \#* ]] && continue

    if [[ -n $extra ]] || ! _azt_valid_alias "$alias" || ! _azt_valid_tenant_id "$tenant_id" || ! _azt_valid_label "$label"; then
      _azt_error "invalid configuration entry for alias: $alias"
      return 1
    fi

    case " $seen_aliases " in
      *" $alias "*)
        _azt_error "duplicate configuration entry for alias: $alias"
        return 1
        ;;
    esac
    seen_aliases="$seen_aliases $alias"

    if [[ $alias == "$requested_alias" ]]; then
      AZT_ALIAS=$alias
      AZT_TENANT_ID=$tenant_id
      AZT_LABEL=$label
      selected=1
    fi
  done < "$AZURE_TENANT_SWITCHER_CONFIG"

  if [[ $selected -eq 1 ]]; then
    return 0
  fi

  _azt_error "unknown tenant alias: $requested_alias"
  return 1
}

_azt_list_tenants() {
  local alias='' tenant_id='' label='' extra=''
  local seen_aliases='' entries=''

  if [[ ! -r $AZURE_TENANT_SWITCHER_CONFIG ]]; then
    _azt_error "configuration is not readable: $AZURE_TENANT_SWITCHER_CONFIG"
    return 1
  fi

  while IFS='|' read -r alias tenant_id label extra || [[ -n $alias$tenant_id$label$extra ]]; do
    label=${label%$'\r'}
    [[ -z $alias || $alias == \#* ]] && continue

    if [[ -n $extra ]] || ! _azt_valid_alias "$alias" || ! _azt_valid_tenant_id "$tenant_id" || ! _azt_valid_label "$label"; then
      _azt_error "invalid configuration entry for alias: $alias"
      return 1
    fi

    case " $seen_aliases " in
      *" $alias "*)
        _azt_error "duplicate configuration entry for alias: $alias"
        return 1
        ;;
    esac
    seen_aliases="$seen_aliases $alias"
    entries+="$alias"$'\t'"$label"$'\n'
  done < "$AZURE_TENANT_SWITCHER_CONFIG"

  printf '%s' "$entries"
}

_azt_completion_aliases() {
  local alias='' tenant_id='' label='' extra=''

  [[ -r $AZURE_TENANT_SWITCHER_CONFIG ]] || return 0

  while IFS='|' read -r alias tenant_id label extra || [[ -n $alias$tenant_id$label$extra ]]; do
    label=${label%$'\r'}
    [[ -z $alias || $alias == \#* ]] && continue

    if [[ -z $extra ]] && _azt_valid_alias "$alias" && _azt_valid_tenant_id "$tenant_id" && _azt_valid_label "$label"; then
      printf '%s\n' "$alias"
    fi
  done < "$AZURE_TENANT_SWITCHER_CONFIG"
}

_azt_usage() {
  cat <<'EOF'
Usage:
  azt <alias>       Select an Azure CLI context for an alias.
  azt --list         List configured aliases and labels.
  azt current        Show the selected tenant context.
  azt --help         Show this help.

Run azlogin after selecting a tenant to start a device-code sign-in.
EOF
}

azt() {
  local context_directory

  case ${1:-} in
    --help|-h)
      _azt_usage
      return 0
      ;;
    --list|-l)
      [[ $# -eq 1 ]] || {
        _azt_usage >&2
        return 1
      }
      _azt_list_tenants
      return
      ;;
    current)
      [[ $# -eq 1 ]] || {
        _azt_usage >&2
        return 1
      }
      if [[ -z ${AZ_TENANT:-} || -z ${AZ_TENANT_LABEL:-} ]]; then
        _azt_error "no tenant context is selected"
        return 1
      fi
      printf 'Selected Azure tenant: %s\n' "$AZ_TENANT_LABEL"
      return 0
      ;;
    ''|--*)
      _azt_usage >&2
      return 1
      ;;
  esac

  if [[ $# -ne 1 ]]; then
    _azt_usage >&2
    return 1
  fi

  unset AZURE_CONFIG_DIR AZ_TENANT AZ_TENANT_LABEL

  _azt_find_tenant "$1" || return 1
  context_directory=$AZURE_TENANT_SWITCHER_CONFIG_ROOT/$AZT_ALIAS

  if [[ ! -d $context_directory ]]; then
    (umask 077 && mkdir -p "$context_directory") || {
      _azt_error "unable to create Azure CLI context directory: $context_directory"
      return 1
    }
  fi

  export AZURE_CONFIG_DIR=$context_directory
  export AZ_TENANT=$AZT_TENANT_ID
  export AZ_TENANT_LABEL=$AZT_LABEL
  printf 'Selected Azure tenant: %s\n' "$AZ_TENANT_LABEL"
}

azlogin() {
  if [[ -z ${AZ_TENANT:-} || -z ${AZ_TENANT_LABEL:-} ]]; then
    _azt_error "select a tenant first: azt <alias>"
    return 1
  fi

  if ! command -v az >/dev/null 2>&1; then
    _azt_error "Azure CLI (az) is not installed or not on PATH"
    return 1
  fi

  command az login --tenant "$AZ_TENANT" --use-device-code --allow-no-subscriptions
}

azt_status() {
  if [[ -z ${AZ_TENANT:-} || -z ${AZ_TENANT_LABEL:-} ]]; then
    _azt_error "no tenant context is selected"
    return 1
  fi

  if ! command -v az >/dev/null 2>&1; then
    _azt_error "Azure CLI (az) is not installed or not on PATH"
    return 1
  fi

  if command az account get-access-token --tenant "$AZ_TENANT" --resource https://management.azure.com/ --only-show-errors >/dev/null 2>&1; then
    printf 'Azure CLI session is active for %s.\n' "$AZ_TENANT_LABEL"
    return 0
  fi

  printf 'No active Azure CLI session for %s. Run azlogin.\n' "$AZ_TENANT_LABEL" >&2
  return 1
}

azt_prompt_tag() {
  [[ -n ${AZ_TENANT_LABEL:-} ]] && printf ' [az:%s]' "$AZ_TENANT_LABEL"
}

_azt_complete() {
  local current aliases

  current=${COMP_WORDS[COMP_CWORD]}
  aliases=$(_azt_completion_aliases)
  COMPREPLY=($(compgen -W "$aliases" -- "$current"))
}

if type complete >/dev/null 2>&1; then
  complete -F _azt_complete azt
fi
