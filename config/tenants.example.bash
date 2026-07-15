# Copy this file to ~/.config/azure-tenant-switcher/tenants.bash, then replace
# the example IDs with the directory (tenant) IDs that you are authorized to use.
#
# Keep this file outside a cloned repository. It identifies your Azure tenants,
# but it must never contain credentials, tokens, account names, or subscriptions.

azure_tenant_switcher_config() {
    azure_tenant_switcher_add_tenant \
        "contoso" \
        "Contoso Engineering" \
        "2f7d0a91-6c4e-4a82-9f10-3b5d8c6e1a27"

    azure_tenant_switcher_add_tenant \
        "fabrikam" \
        "Fabrikam Research" \
        "8a3c5e71-1d9b-4f63-a8e2-6c0d4b9f7a15"

    azure_tenant_switcher_add_tenant \
        "northwind" \
        "Northwind Retail" \
        "5e1b9d42-7a6c-4d80-b3f1-9c2e8a5d6f04"
}
