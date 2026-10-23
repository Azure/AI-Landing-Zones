# Work IQ

Use Work IQ to ground answers in the signed-in user's Microsoft 365 context.
As a **Foundry IQ knowledge source**, Work IQ queries live information at
retrieval time, without an ingestion pipeline or a copy of the Microsoft 365
corpus in the landing zone.

## Check hosted support first

**Hosted Agent Application does not currently provide an end-to-end Work IQ
setup through configuration alone.** Its Work IQ connector requires a delegated
user token, but the hosted entrypoint does not supply that token to the
retrieval strategies. A custom integration must deliver the trusted user token
separately from the agent's service authentication.

Source registration also needs an update: Agent Landing Zone provisioning targets
`2026-05-01-preview` and emits a Work IQ source without the app-authentication
properties required by Microsoft's current `2026-08-01-preview` recipe.
Migration requires coordinated provisioning, authentication and connector changes.

Keep `WORK_IQ_ENABLED` disabled on an unmodified hosted deployment: enabling
it can make retrieval require user credentials that the hosted path cannot
provide. Keep the working knowledge base unchanged while preparing a
[custom application](build-your-own-app.md). See [Foundry IQ](foundry-iq.md)
for the shared knowledge-base integration.

## Prepare the tenant

Complete the following tenant setup while developing the custom hosted integration.

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
   to it. These billing requirements apply separately from Microsoft 365 Copilot
   licensing. Use the current requirements rather than the
   Agent Landing Zone's older consent-form and Copilot-license warning.

3. **Have a Global Administrator enable the tenant.** Follow that guide to
   create the Work IQ service principal, if it does not already exist.
   Confirm the enterprise application has application ID
   `fdcc1f02-fc51-4226-8753-f668596af7f7`. Then configure the client application's
   delegated access in the authentication steps below.

4. **Prepare the Foundry IQ service.** Use a region supporting agentic
   retrieval. The operator creating knowledge sources needs the service's
   **Search Service Contributor** role when using keyless authentication.
   For isolated environments, verify the supported network path before
   proceeding. Verify connectivity to Work IQ and Microsoft Entra endpoints
   from the services making those calls. See
   [Network isolation](network-isolation.md).

<span id="configure-the-authentication-contract"></span>

## Configure authentication

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
   consent under your tenant policy. The client must obtain a user assertion,
   a delegated access token for that app, rather than reuse a service token or a token with a different
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
   The Agent Application connector instead uses `x-ms-query-source-authorization` with
   its older delegated-token contract; that must change too.
   Do not pass bearer tokens in prompts, chat history, or unvalidated
   user-supplied metadata.

The source needs the app's **Application (client) ID** and the **object ID of
the federated credential**. Record each ID from its corresponding Entra object.
The app's tenant ID is also required
when the app and retrieval service are in different tenants. A knowledge-source
name identifies the registered source object in Search.

After consent, billing, federation and user-token delivery are ready, select the
retrieval source through App Configuration with label `agent-lz`. The runtime
keys are `WORK_IQ_ENABLED` and `WORK_IQ_KNOWLEDGE_SOURCE_NAME`.
Maintain provisioned source definitions in the template;
subsequent provisioning can overwrite portal edits. Deliver the template
and Agent Application changes together through the
[custom application deployment](build-your-own-app.md), including a new hosted
deployment/version so a fresh hosted process loads the changes.

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

Work IQ enforces Microsoft 365 permissions per request. Inspect retrieved
document IDs and references: the allowed user should retrieve the pilot policy,
and the denied user's results must exclude it.

## Diagnose or back out

- **No source after provisioning:** Agent Landing Zone's consent preflight skips Work IQ
  when its service-principal lookup is negative or inconclusive. Check
  provisioning logs and confirm the source exists in Search. Verify app consent
  and federation separately against the current requirements.
- **User-token or authentication failure:** check token audience, tenant,
  delegated consent, user billing assignment, and federated credential
  subject. Do not log bearer tokens or relax authorization to make the test pass.
- **Timeout:** Microsoft notes that Work IQ can take 40–60 seconds or longer
  and recommends retrieve `maxRuntimeInSeconds` of at least `120`. Align the
  custom client's timeout with that budget; increasing it does not fix
  authentication failures.
- **Undo a pilot:** restore the previous reviewed deployment inputs and hosted
  Agent Application version. Remove the pilot source reference from its knowledge
  base before deleting the source. Revoke pilot-only client grants or
  credentials only after checking that no other application uses them; do not
  delete a shared tenant service principal as an Agent Application rollback.

## Direct Work IQ MCP is different

[Work IQ MCP](https://learn.microsoft.com/microsoft-365/copilot/extensibility/work-iq/mcp/overview)
exposes tools to an MCP client. Choose between direct tools and a `workIQ`
knowledge source based on where you want retrieval to run. Direct tools require
[agent-tool customization](agent-tools.md), with their own authentication,
allowed operations and permission tests. The knowledge-source route uses
Agent Application's Work IQ connector and requires the user-identity integration
described above.
