# Azure Tenant Switcher

A small, sourceable Bash utility for keeping Azure CLI sign-in state isolated by
tenant. It selects a dedicated `AZURE_CONFIG_DIR` for each short alias, exposes
the selected tenant through `AZ_TENANT` and `AZ_TENANT_LABEL`, and provides a
device-code login command.

This repository intentionally contains only fictitious examples. The Contoso,
Fabrikam, and Northwind labels and IDs are placeholders.

## Requirements

- Bash 3.2 or later (the Bash version included with macOS is supported)
- Azure CLI (`az`) available on `PATH` for sign-in and status commands

No package manager, external shell framework, or daemon is required.

## Install

Clone the repository and source the tool from your Bash startup file:

```bash
source "/path/to/azure-tenant-switcher/azure-tenant-switcher.bash"
```

Create a private, user-local configuration file:

```bash
install -d -m 700 "$HOME/.config/azure-tenant-switcher"
cp "/path/to/azure-tenant-switcher/config/tenants.example.bash" \
  "$HOME/.config/azure-tenant-switcher/tenants.bash"
chmod 600 "$HOME/.config/azure-tenant-switcher/tenants.bash"
```

Edit the copied file to replace the fictitious tenant IDs and labels. Keep it
outside the repository; the default file is intentionally ignored by Git.

To use a different location, set `AZURE_TENANT_SWITCHER_CONFIG` before sourcing
the tool. To store isolated Azure CLI directories somewhere other than
`$HOME/.azure-tenants`, set `AZURE_TENANT_SWITCHER_CONFIG_ROOT`.

## Usage

```bash
azt contoso       # Select a configured context for this shell.
azlogin            # Run az login with device code for the selected tenant.
azt_status         # Check whether Azure CLI can use a cached access token.
azt_list           # Print configured aliases and display labels.
azt_prompt_tag     # Print [az:Contoso Engineering] for use in PS1.
```

`azt` exports the selected `AZURE_CONFIG_DIR`, `AZ_TENANT`, and
`AZ_TENANT_LABEL` only to the current shell and its child processes. Switching
aliases changes where Azure CLI writes its local state; it does not copy,
export, or synchronize that state.

For a Bash prompt tag, add command substitution to `PS1`, for example:

```bash
PS1='$(azt_prompt_tag) \u:\W\$ '
```

The command is empty until a tenant is selected.

## iTerm2 dynamic profiles

`examples/iterm2-dynamic-profiles.json` supplies three sanitized profiles. Copy
it to iTerm2's DynamicProfiles directory, then open a profile after this tool
has been sourced by the shell startup file. Each profile only sets a display
name, badge, and initial `azt <alias>` command; it contains no tenant IDs,
account names, tokens, or subscriptions.

## Security and reset guidance

Tenant IDs and labels identify directory contexts but are not authentication
credentials. Treat the local mapping as private operational configuration:

- Do not commit your copied `tenants.bash` file.
- Do not place access tokens, account names, client secrets, certificates, or
  subscription details in the mapping.
- Each selected context may contain Azure CLI tokens under
  `$AZURE_CONFIG_DIR`; those files are created and managed only by Azure CLI.
- Use a restrictive configuration-file mode such as `0600`.

To sign out from one selected context, run:

```bash
az logout
```

To discard all cached Azure CLI state for one context after signing out, remove
only that context directory after confirming its path:

```bash
rm -rf "$AZURE_CONFIG_DIR"
```

To reset all tenant contexts, remove the configured context root only after
verifying it is the intended directory:

```bash
rm -rf "$HOME/.azure-tenants"
```

Deleting a context removes local Azure CLI state; it does not change resources
or identities in Azure.

## Test

```bash
make test
```

The test script uses Bash and standard shell utilities only. It creates
temporary mock Azure CLI state and never contacts Azure.
