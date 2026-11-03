**Entra application administrator — UI app registration**

1. Open **API permissions** in the UI app registration.
2. Add the UI API's delegated `user_impersonation` permission.
3. Add the Foundry resource's delegated `user_impersonation` permission for downstream on-behalf-of (OBO) calls.
4. Grant the consent required by tenant policy before onboarding users.
5. Confirm the Foundry endpoint's token audience with its owner before provisioning.

These are two different APIs, despite their identical scope names.
For the standard Foundry-resource authorization scheme (`AzureRbac`, also called `Entra`),
the downstream scope is `https://ai.azure.com/.default`.

Do not substitute the UI API scope or a management-plane audience for the Foundry scope.

Protected native retrieval additionally needs Foundry-managed Search consent for `https://search.azure.com/.default`.
The UI does not acquire or forward that Search credential.
Shared Blob/ADLS citation downloads additionally need delegated Azure Storage
`user_impersonation` consent for `https://storage.azure.com/.default`.
These permissions do not grant source access.

Retain the source's role-based access control (RBAC) and access-control list (ACL) checks.

The [Foundry client authorization procedure](https://learn.microsoft.com/azure/foundry/agents/how-to/configure-agent-endpoint-authorization#authorize-the-client-to-request-a-foundry-token)
describes the downstream permission and consent.
The UI exchanges the user's API token server-side.
Consent does not grant permission to invoke the agent.

**Check:** Both API permissions have the required consent, and the Foundry audience matches the deployed authorization scheme.
