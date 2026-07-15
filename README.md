# Azure Tenant Switcher

Azure Tenant Switcher is a small, sourceable Bash helper for keeping separate
Azure CLI contexts for multiple Entra tenants. It requires Bash 3.2 or later
and the Azure CLI (`az`) only when you sign in or check session status.

Tenant mappings are a plain local file, not shell code. The repository contains
only fictitious Contoso, Fabrikam, and Northwind examples.

## Install

1. Copy or clone this repository to a directory you control.
2. Create a private local configuration directory and copy the template:

   ```bash
   config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/azure-tenant-switcher"
   mkdir -p "$config_dir"
   chmod 700 "$config_dir"
   cp tenants.conf.example "$config_dir/tenants.conf"
   chmod 600 "$config_dir/tenants.conf"
   ```

3. Edit `"$config_dir/tenants.conf"` and replace the sample UUIDs with the
   tenant IDs you are authorized to use.
4. Source the helper from your interactive Bash startup file:

   ```bash
   source "/path/to/azure-tenant-switcher/azure-tenant-switcher.bash"
   ```

For a different configuration file or context root, set these variables before
sourcing the helper:

```bash
export AZURE_TENANT_SWITCHER_CONFIG="$HOME/.config/azure-tenant-switcher/tenants.conf"
export AZURE_TENANT_SWITCHER_CONFIG_ROOT="$HOME/.azure-tenants"
source "/path/to/azure-tenant-switcher/azure-tenant-switcher.bash"
```

## Configure tenants

Each non-comment line uses this exact format:

```text
alias|tenant-id|display label
```

Aliases must begin with a letter or number and may contain letters, numbers,
underscores, and hyphens. Tenant IDs must be UUIDs. Labels must be non-empty,
printable text. Invalid entries fail closed: selecting or listing tenants stops
with an error rather than using a partial mapping.

## Use

```bash
azt --list
azt contoso
azlogin
azt_status
```

`azt <alias>` exports these variables in the current shell:

| Variable | Purpose |
| --- | --- |
| `AZURE_CONFIG_DIR` | Alias-specific Azure CLI directory, defaulting to `~/.azure-tenants/<alias>` |
| `AZ_TENANT` | Selected tenant UUID, passed to `az login` |
| `AZ_TENANT_LABEL` | Selected display label |

`azlogin` runs:

```bash
az login --tenant "$AZ_TENANT" --use-device-code --allow-no-subscriptions
```

`azt_status` checks whether the selected context has an active Azure CLI
session without printing account, subscription, or sign-in details.

For an optional prompt component, add `$(azt_prompt_tag)` where appropriate in
your Bash prompt configuration. The function is empty until a tenant is
selected.

Tab completion is registered for `azt` aliases when the file is sourced.

## iTerm2 dynamic profiles

`examples/iterm2-dynamic-profiles.json` provides sanitized profiles for the
sample aliases. Replace the display labels and generate unique profile GUIDs
before use. Copy the resulting JSON file to:

```text
~/Library/Application Support/iTerm2/DynamicProfiles/
```

iTerm2 reloads valid dynamic-profile files as they change. The sample profiles
contain only a name, badge, and `Initial Text` command such as `azt contoso`;
they do not contain tenant IDs or credentials.

## Security and reset

- Never commit your local `tenants.conf`; `.gitignore` excludes common local
  mapping locations and Azure CLI cache directories.
- This tool does not write login tokens. Azure CLI writes its own cached
  authentication data under the selected `AZURE_CONFIG_DIR`.
- Use a separate config root if you want to isolate this tool further:
  `AZURE_TENANT_SWITCHER_CONFIG_ROOT=/secure/location`.
- To clear one alias-specific Azure CLI session, sign out in that selected
  context with `az logout`, then remove only that alias directory under the
  configured context root. To reset every context managed by this tool, remove
  the configured context root after signing out.
- Removing the local mapping file prevents future selection but does not delete
  Azure CLI cache directories. Remove those separately if required.

## Test

Run the portable shell test suite:

```bash
make test
```

The tests use a temporary directory and a stub `az` executable. They do not
contact Azure or create persistent credential data.
