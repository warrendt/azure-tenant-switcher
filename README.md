# Azure Tenant Switcher

**One shell. Many tenants. Far fewer "why am I in _that_ portal?" moments.**

Azure CLI is excellent at remembering you. This small, sourceable Bash helper
gives each Azure Entra tenant its own local Azure CLI context, so cached
sign-ins do not wander between tenants. Pick a short alias, then use Azure CLI
as usual.

It is intentionally boring where it matters:

- Bash 3.2+ compatible, including the Bash bundled with macOS
- no framework, daemon, or package manager
- no credential handling beyond invoking your installed Azure CLI
- a private, user-local mapping file that is ignored by Git

The tenants in this repository are entirely fictional: Contoso, Fabrikam, and
Northwind are examples, not destinations.

## The two-minute tour

```bash
# Select a tenant-specific Azure CLI context for this shell.
azt contoso

# Sign in to the selected tenant using Azure CLI device code.
azlogin

# Confirm that Azure CLI can use the selected context's cached token.
azt_status
```

Switching to another alias is equally unceremonious:

```bash
azt fabrikam
azlogin
```

No subscriptions, account names, or tenant IDs are printed by normal listing
and status commands. Context is the feature; oversharing is not.

## Install and quick start

**Requirements:** Bash 3.2 or newer. Install Azure CLI (`az`) before using
`azlogin` or `azt_status`.

1. Clone or download this repository to a directory you control.
2. Create a private mapping file from the sanitized template:

   ```bash
   config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/azure-tenant-switcher"
   mkdir -p "$config_dir"
   chmod 700 "$config_dir"
   cp "<repo-directory>/tenants.conf.example" "$config_dir/tenants.conf"
   chmod 600 "$config_dir/tenants.conf"
   ```

3. Edit `"$config_dir/tenants.conf"` and replace the fictional tenant IDs and
   labels with only the directories you are authorized to use.
4. Source the helper from your interactive Bash startup file:

   ```bash
   source "<repo-directory>/azure-tenant-switcher.bash"
   ```

5. Start with the tour:

   ```bash
   azt --list
   azt contoso
   azlogin
   ```

`<repo-directory>` is the directory where you placed this repository. The
mapping stays in your user configuration directory, outside the repository.

## How context isolation works

After `azt <alias>`, the helper validates the entire mapping and exports:

| Variable | Meaning |
| --- | --- |
| `AZURE_CONFIG_DIR` | Azure CLI state directory for the selected alias |
| `AZ_TENANT` | Selected tenant ID, used only by `azlogin` |
| `AZ_TENANT_LABEL` | Friendly label for messages and the optional prompt tag |

By default, the Azure CLI directory is:

```text
$HOME/.azure-tenants/<alias>
```

The helper creates that directory with a restrictive `umask` if needed. Azure
CLI then owns its usual sign-in state inside that directory. The helper never
copies tokens between aliases, reads token contents, or sends credentials
anywhere.

This separation is practical isolation for local Azure CLI state, not a
security boundary between processes that can already read the same user
account. Treat each context directory as sensitive local authentication state.

## Configure tenants safely

The mapping is plain text: one tenant per line.

```text
alias|tenant-id|display label
```

For example, the included template uses fictional data:

```text
contoso|11111111-2222-4333-8444-555555555555|Contoso Engineering
```

Aliases must begin with a letter or number and may contain letters, numbers,
underscores, and hyphens. Tenant IDs must be UUIDs. Labels must be non-empty,
printable text. Avoid `|` in labels because it is the field separator.

The helper validates the **whole** mapping before it selects or lists a
tenant. A malformed or duplicate line fails closed rather than producing a
partially trusted context.

### Custom locations

Set these variables **before** sourcing the helper to relocate the mapping or
isolated Azure CLI directories:

```bash
export AZURE_TENANT_SWITCHER_CONFIG="$HOME/.config/azure-tenant-switcher/tenants.conf"
export AZURE_TENANT_SWITCHER_CONFIG_ROOT="$HOME/.azure-tenants"
source "<repo-directory>/azure-tenant-switcher.bash"
```

Keep the mapping outside a Git worktree. It identifies where you work, even
though it must never contain credentials, tokens, account names, client
secrets, certificates, or subscription information.

## Everyday commands

| Command | What it does |
| --- | --- |
| `azt --list` | Shows configured aliases and labels, never tenant IDs |
| `azt <alias>` | Selects an alias and exports its Azure CLI context |
| `azt current` | Shows the selected label in the current shell |
| `azlogin` | Runs device-code sign-in for the selected tenant |
| `azt_status` | Checks whether Azure CLI has a usable cached token |
| `azt_prompt_tag` | Prints a small selected-tenant prompt tag |
| `azt --help` | Shows command usage |

`azlogin` deliberately runs this exact Azure CLI command:

```bash
az login --tenant "$AZ_TENANT" --use-device-code --allow-no-subscriptions
```

That makes it suitable for tenants where you need to authenticate before any
subscription is available to you.

### A tiny prompt reminder

The optional `azt_prompt_tag` function is empty until a tenant is selected,
then prints a leading-space tag such as ` [az:Contoso Engineering]`. Add it to
a Bash prompt if a visual nudge helps:

```bash
PS1='\u:\W\$(azt_prompt_tag)\$ '
```

Tab completion for aliases is registered when the helper is sourced.

## iTerm2 dynamic profiles

`examples/iterm2-dynamic-profiles.json` contains three sanitized iTerm2
profiles for the fictional aliases. Each profile has a display name, badge,
fictitious profile GUID, and initial command such as `azt contoso`; it has no
tenant ID, account detail, credential, or subscription data.

To use it:

1. Ensure the helper is sourced by the Bash startup file opened by iTerm2.
2. Copy and adapt the JSON into iTerm2's DynamicProfiles directory:

   ```text
   ~/Library/Application Support/iTerm2/DynamicProfiles/
   ```

3. Replace the fictional labels and generate new profile GUIDs before using
   the profiles for your own aliases.

iTerm2 reloads valid dynamic-profile JSON as it changes. Opening a profile
runs its `Initial Text`, which selects the alias; it does not sign in
automatically.

## Recovery and reset

Most recovery is pleasantly dull:

| Situation | Safe next step |
| --- | --- |
| No context selected | Run `azt <alias>` |
| Cached sign-in is unavailable | Select the alias, then run `azlogin` |
| Need to confirm the active context | Run `azt current` |
| Need to sign out of one context | Select it, then run `az logout` |

To discard one alias's cached Azure CLI state, first select it and inspect the
target:

```bash
azt contoso
printf '%s\n' "$AZURE_CONFIG_DIR"
```

After confirming the printed directory is the intended alias context, remove
it:

```bash
rm -rf "$AZURE_CONFIG_DIR"
```

To reset every context managed by this tool, inspect the configured root first:

```bash
printf '%s\n' "$AZURE_TENANT_SWITCHER_CONFIG_ROOT"
```

Only after confirming that value, remove it:

```bash
rm -rf "$AZURE_TENANT_SWITCHER_CONFIG_ROOT"
```

These commands remove **local Azure CLI state only**. They do not alter Azure
resources, identities, tenant configuration, or the local mapping file.

## Security notes

- `.gitignore` excludes common Azure CLI cache directories and local mapping
  names, but ignored files can still be added deliberately. Review staged files
  before committing.
- Use restrictive permissions such as `0600` for the mapping and keep its
  contents minimal.
- Azure CLI, not this helper, writes authentication cache data beneath the
  selected `AZURE_CONFIG_DIR`.
- Environment variables are inherited by child processes. Avoid running
  untrusted programs from a shell with a selected tenant context.
- The included examples are fictional. Do not repurpose their IDs as real
  configuration.

## Test, contribute, and license

Run the self-contained shell test suite with:

```bash
make test
```

The tests use a temporary directory and a stub `az` executable; they do not
contact Azure or leave persistent credential data.

Contributions are welcome. Please keep changes Bash 3.2-compatible, preserve
the fail-closed mapping validation, add or update tests for behavior changes,
and never include tenant mappings, credentials, account data, subscriptions,
or local machine details in commits, examples, issues, or pull requests.

This project is released under the [MIT License](LICENSE).
