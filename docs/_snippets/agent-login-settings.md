**Entra application administrator and configuration operator — UI registration, environment Key Vault and App Configuration**

1. Open **Certificates & secrets** in the UI app registration.
2. Create a client secret under the tenant's expiry policy.
3. Open **Secrets > Generate/Import** in this environment's Key Vault.
4. Select **Manual**.
5. Name the secret `ui-oauth-client-secret`.
6. Enter the client secret's **value**, not its secret ID, through the approved secure process.
7. Select **Create**.
8. Record the secret's expiry and rotation owner.

Do not copy the value into source, shell commands or logs.

9. Open **Configuration explorer** in this environment's App Configuration store.
10. Create a **Key Vault reference** named `OAUTH_AZURE_AD_CLIENT_SECRET`, with label `agent-lz`, pointing to `ui-oauth-client-secret`.
11. Select the Key Vault reference type, not an ordinary string containing a secret or URI.
12. Generate a stable `CHAINLIT_AUTH_SECRET` of at least 32 UTF-8 bytes through the approved credential-management process.
13. Open **Secrets > Generate/Import** in the same Key Vault.
14. Select **Manual**.
15. Name this secret `ui-session-signing-secret`.
16. Enter the generated session-signing value through the approved secure process.
17. Select **Create**.
18. Create its **Key Vault reference** named `CHAINLIT_AUTH_SECRET`, with label `agent-lz`, in the same App Configuration store.

Do not regenerate an existing session-signing secret during a routine update.

19. Create the following nonsecret keys through **Configuration explorer > Create > Key-value**.
20. Apply label `agent-lz` to each key.
21. Enter each value as plain text.

| Key | Value |
| --- | --- |
| `OAUTH_AZURE_AD_CLIENT_ID` | Application (client) ID from the UI registration |
| `OAUTH_AZURE_AD_TENANT_ID` | Directory (tenant) ID from the UI registration |
| `OAUTH_AZURE_AD_ENABLE_SINGLE_TENANT` | `true` |
| `OAUTH_AZURE_AD_SCOPES` | `api://<client-id>/user_impersonation,openid,profile,offline_access`, with the UI client ID |
| `CHAINLIT_URL` | Canonical UI HTTPS origin from the callback setup |
| `ALLOW_ANONYMOUS` | `false` |
| `HOSTED_AGENT_AUTH_MODE` | `user_delegated` for the default; `service_identity` only for the explicitly selected alternative |

Do not add Graph scopes such as `User.Read` or the Foundry scope to `OAUTH_AZURE_AD_SCOPES`.
Do not set the platform-derived `RETRIEVAL_AUTH_MODE` independently to bypass source authorization.
Do not use arbitrary `azd env set` inputs to publish these UI runtime keys.
Keep reviewed deployment declarations aligned with these values.

The configuration operator needs App Configuration Data Owner to write keys.
The frontend needs App Configuration Data Reader and Key Vault Secrets User at the relevant scopes.
The default lifecycle reconciles the frontend's secret-scoped grants from its Key Vault references during deployment.
See [default hosted permissions](../bicep/permissions.md#frontend-container-app).

22. Remove or update conflicting UI process-environment or other selected-label overrides.
23. Preserve the platform's [configuration ownership](configuration.md#configuration-ownership-and-declarations).

[Application settings](application-settings.md#overrides-and-effective-values) describes precedence.

**Check:** Both secrets are Key Vault references.
The nonsecret keys have the intended values.
The actual frontend identity must resolve the references before user acceptance.

Do not display resolved credentials as verification.
