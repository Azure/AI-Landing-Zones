# Work IQ

Use Work IQ to ground answers in the signed-in user's Microsoft 365 context.
As a **Foundry IQ knowledge source**, Work IQ queries live information at
retrieval time; it does not require an ingestion pipeline or copying Microsoft
365 content into the landing zone.

## Check hosted support first

**The bundled hosted agent does not currently provide an end-to-end Work IQ
setup through configuration alone.** Its Work IQ connector requires a delegated
user token, but the hosted entrypoint does not supply that token to the
retrieval strategies. Signing in to the web UI or giving the agent a managed
identity does not complete this flow.

There is also a service-contract gap: the bundled provisioning targets
`2026-05-01-preview` and emits a Work IQ source without the app-authentication
properties required by Microsoft's current `2026-08-01-preview` recipe.
Changing only the API-version setting does not implement that migration.

Do not enable `WORK_IQ_ENABLED` on an existing hosted deployment as a test.
It can make retrieval require user credentials that the hosted path cannot
provide. Keep the working knowledge base unchanged while preparing a
[custom application](build-your-own-app.md). See [Foundry IQ](foundry-iq.md)
for the shared knowledge-base integration.

## Prepare the tenant

The following is preparation for a custom hosted integration, not a recipe
that enables the bundled agent.

1. **Approve the preview and billing.** Review Microsoft's
   [Work IQ knowledge-source requirements](https://learn.microsoft.com/azure/search/agentic-knowledge-source-how-to-work-iq).
   The source is preview, has no preview SLA, and is not recommended for
   production workloads. Microsoft warns that it can invoke capabilities that
   perform actions, not just retrieve information. Limit the pilot to trusted
   applications and users and review allowed operations with your tenant
   administrator.

2. **Configure Work IQ billing before tenant enablement.** The current
   [tenant setup guide](https://learn.microsoft.com/microsoft-365/copilot/extensibility/work-iq/enable-work-iq)
   requires a usage-based billing plan in Copilot Studio, an Azure subscription
   and resource group assigned to that plan, and each querying user assigned
   to it. A Microsoft 365 Copilot license alone is not a substitute for these
   prerequisites. Use the current billing requirements rather than the
   bundle's older consent-form and Copilot-license warning.

3. **Have a Global Administrator enable the tenant.** Follow that guide to
   create the Work IQ service principal, if it does not already exist.
   Confirm the enterprise application has application ID
   `fdcc1f02-fc51-4226-8753-f668596af7f7`. This enables the Work IQ resource;
   it does not grant your client application delegated access.

4. **Prepare the Foundry IQ service.** Use a region supporting agentic
   retrieval. The operator creating knowledge sources needs the service's
   **Search Service Contributor** role when using keyless authentication.
   For isolated environments, verify the supported network path before
   proceeding; private access to the landing zone alone does not prove
   connectivity to Work IQ or Microsoft Entra endpoints. See
   [Network isolation](network-isolation.md).

## Configure the authentication contract

Follow the authentication section of Microsoft's
[knowledge-source setup](https://learn.microsoft.com/azure/search/agentic-knowledge-source-how-to-work-iq)
in this order. These are prerequisites for the custom implementation.

1. **Create a single-tenant Work IQ app registration.** An Application
   Developer can create it. Under **Expose an API**, add the delegated scope
   named exactly `access_as_user`. Under **API permissions**, add Work IQ's
   delegated `WorkIQAgent.Ask` permission. A Cloud Application Administrator
   or Application Administrator must grant tenant-wide admin consent.

2. **Federate the retrieval service identity to that app.** Enable the
   service's system-assigned managed identity, or follow Microsoft's supported
   single user-assigned identity alternative. An app owner or supported
   administrator creates the federated credential on the app registration,
   trusting the service identity's principal ID. Use the documented issuer
   and `api://AzureADTokenExchange` audience; no client secret belongs in the
   knowledge-source definition.

3. **Authorize the client application.** On the app that signs users in, add
   delegated access to the Work IQ app's `access_as_user` scope and complete
   consent under your tenant policy. The client must obtain a user assertion
   for that app, not reuse a service token or a token with a different
   audience. Validate that `aud` identifies the Work IQ app, `scp` includes
   `access_as_user`, and `oid` and `tid` identify the signed-in user and app
   tenant.

4. **Implement the source and hosted request path together.** Extend the
   landing zone's provisioning template to use the current Work IQ
   authentication contract, reference the source from the intended knowledge
   base, and implement trusted per-user assertion handling through the hosted
   invocation. Use Microsoft's current retrieve authentication instructions.
   The current contract uses `x-ms-query-work-iq-source-authorization` for the
   raw app-audience user assertion, separately from service authentication.
   The bundled connector instead uses `x-ms-query-source-authorization` with
   its older delegated-token contract; that must change too.
   Do not pass bearer tokens in prompts, chat history, or unvalidated
   user-supplied metadata.

The source needs the app's **Application (client) ID** and the **object ID of
the federated credential**. Neither is the service identity's principal ID;
the credential ID is not its display name. The app's tenant ID is also required
when the app and retrieval service are in different tenants. A knowledge-source
name identifies the source object; it is not any of these IDs or an endpoint.

The bundled settings `WORK_IQ_ENABLED` and `WORK_IQ_KNOWLEDGE_SOURCE_NAME`
only select a source for retrieval; they do not establish consent, billing,
federation, or user-token delivery. Runtime settings use the `agent-lz`
App Configuration label. Do not hand-edit provisioned source definitions as a
durable fix: subsequent provisioning can overwrite them. Deliver the template
and application changes together through the
[custom application deployment](build-your-own-app.md), including a new hosted
deployment/version as required; restarting a Container App does not update a
Foundry-hosted agent.

## Verify before connecting users

Use a separate pilot knowledge base and two test accounts with deliberately
different Microsoft 365 permissions:

1. Confirm billing assignment, tenant enablement, delegated consent, and the
   federated credential's trusted principal before testing retrieval.
2. Query a known document that the first account can open, for example:
   “What approval steps does the pilot travel policy require?” Use a
   uniquely named pilot policy so you can distinguish its content from
   general model knowledge. Expect grounding from that source and a citation
   that opens for that account.
3. Repeat as the second account, which must not have access. Expect no
   protected content, excerpts, or revealing citations. Check direct grants,
   group membership, and sharing links before concluding that an ACL test
   passed.
4. Test a missing or expired user assertion. The custom hosted path must
   refuse user-scoped retrieval, not fall back to the agent's managed identity.
   Verify that simultaneous users do not share tokens or retrieval results.

Work IQ enforces Microsoft 365 permissions per request. Identity propagation
alone is not evidence that this enforcement is working. A fluent answer
without a Work IQ reference is not proof of successful grounding.

## Diagnose or back out

- **No source after provisioning:** the bundle's consent preflight skips Work IQ
  when its service-principal lookup is negative or inconclusive. Check
  provisioning logs; a successful overall deployment does not establish that
  Work IQ was created. Service-principal existence alone also does not prove
  the current app consent and federation requirements are satisfied.
- **User-token or authentication failure:** check token audience, tenant,
  delegated consent, user billing assignment, and federated credential
  subject. Do not log bearer tokens or relax authorization to make the test pass.
- **Timeout:** Microsoft notes that Work IQ can take 40–60 seconds or longer
  and recommends retrieve `maxRuntimeInSeconds` of at least `120`. Align the
  custom client's timeout with that budget; increasing it does not fix
  authentication failures.
- **Undo a pilot:** restore the previous reviewed deployment inputs and hosted
  application version. Remove the pilot source reference from its knowledge
  base before deleting the source. Revoke pilot-only client grants or
  credentials only after checking that no other application uses them; do not
  delete a shared tenant service principal as an application rollback.

## Direct Work IQ MCP is different

[Work IQ MCP](https://learn.microsoft.com/microsoft-365/copilot/extensibility/work-iq/mcp/overview)
exposes tools to an MCP client. Wiring those tools into a custom agent is not
the same as registering a `workIQ` knowledge source with Foundry IQ and does
not activate the bundle's Work IQ connector. If you choose direct tools, treat
that as [agent-tool customization](agent-tools.md), with its own authentication,
allowed operations, and permission tests—not a workaround that bypasses the
knowledge base's user-identity requirements.
