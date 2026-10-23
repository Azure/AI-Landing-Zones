# Ask questions about SQL data

Evaluate a Fabric data agent through Foundry IQ for read-only questions about
approved relational data. This is the shipped integration path for the bundled
application hosted in Foundry—not a turnkey connection to an arbitrary SQL server.

## Choose the supported route

| Route | Hosted application compatibility |
| --- | --- |
| Legacy `nl2sql` strategy | Not supported. The hosted runtime explicitly rejects this strategy. Its SQL plugin and schema/example indexes do not enable it in hosted mode. |
| Fabric data agent through a Foundry IQ knowledge base | Integration code is shipped, but service compatibility must be checked below. Fabric generates and executes read-only queries. The knowledge-source connector is a Microsoft preview. |
| Custom SQL tool | An application extension, not a supplied SQL integration. You must implement, secure, deploy and validate it with a hosted-compatible strategy. See [Agent tools](agent-tools.md). |

For Fabric SQL questions, use a **warehouse** or **lakehouse tables** exposed to
the data agent. A Power BI semantic model uses DAX rather than SQL. This route
does not install the legacy NL2SQL plugin or require its metadata indexes.

## Prerequisites

- A working hosted application using Foundry IQ knowledge-base retrieval.
- A Fabric workspace with supported capacity and tenant settings, and an owner
  able to create, publish and share a data agent. See Microsoft's
  [Fabric data agent requirements](https://learn.microsoft.com/fabric/data-science/concept-data-agent).
- A small, non-sensitive warehouse or lakehouse table with known answers.
  Pilot users need access to the data agent **and** its underlying data.
- A platform operator able to provision the knowledge source and update its
  knowledge-base binding. The Search service and Fabric workspace must use the
  same Microsoft Entra tenant.
- An authenticated application path that supplies the end user's delegated
  identity for on-behalf-of (OBO) retrieval. A managed identity alone is not
  sufficient for this remote source. The connector forwards a Search-audience
  user token separately from service authentication; do not paste tokens into
  configuration or commands.
- Network policy allowing the required service connections. A working private
  Foundry endpoint does not by itself prove connectivity to Fabric. Have the
  platform owner validate the retrieval path and any Fabric workspace outbound
  access rules without weakening private-access policies.

The Foundry IQ **Fabric Data Agent knowledge source** is preview, independently
of the Fabric data agent's own release status. Confirm regional availability,
data residency and preview acceptance before using real business data. Review
the [connector requirements and limits](https://learn.microsoft.com/azure/search/agentic-knowledge-source-how-to-fabric-data-agent).

!!! warning "Check the preview contract before connecting"
    The bundled orchestrator v5.2.1's data-agent parser expects `dataAgentAnswer`
    and `dataAgentRawData` in retrieval references. Current Microsoft documentation
    instead describes `fabricAnswer` and `fabricEmbeddedResources`, using
    `2026-08-01-preview`; the platform and orchestrator defaults use
    `2026-05-01-preview`. This is not a confirmed turnkey hosted combination.
    Have the application owner verify the deployed API and response contract
    before proceeding. Its separate ontology parser can read `fabricAnswer`,
    but does not handle `fabricEmbeddedResources` and classifies that answer
    as ontology content. Do not assume correct data-agent evidence or table/chart
    support. If the deployed contract differs, obtain a compatible, validated
    application release; changing an API-version setting alone is insufficient.

## Run a read-only pilot

1. **Establish an expected answer.** Have the data owner choose an approved
   table and record a known aggregate for a fixed period, such as an order count.
   Use the same date boundaries and business definition throughout the pilot.
   For example, ask “How many orders were placed in September 2026?” only if
   the selected table and its date column represent that definition.

2. **Create and test the Fabric data agent.** Follow Microsoft's
   [create a data agent procedure](https://learn.microsoft.com/fabric/data-science/how-to-create-data-agent).
   Select only the pilot warehouse or lakehouse and the tables needed for the
   question. Add the business definition and an example question/query where
   supported. Ask the question in Fabric and compare its answer with the
   owner's expected result before publishing and sharing it.

3. **Bind the published agent to Foundry IQ.** Follow
   [Fabric integration](fabric-iq.md), selecting the **data-agent** route,
   not the ontology route. Provide the Fabric workspace ID and data-agent
   item ID, plus a name for the Search knowledge source. The IDs identify
   Fabric objects; the knowledge-source name identifies the binding in Search.
   They are not SQL connection strings or endpoints.
   The shipped opt-in is `FABRIC_DATA_AGENT_ENABLED` with
   `FABRIC_DATA_AGENT_KNOWLEDGE_SOURCE_NAME`; `FABRIC_IQ_ENABLED` selects the
   separate ontology integration. Use the provisioning and runtime activation
   steps in that runbook rather than changing App Configuration alone.

4. **Verify the binding before testing chat.** Ask the operator to confirm that
   the knowledge base references a source of kind `fabricDataAgent` with the
   intended workspace and data-agent IDs. Use `low` or `medium` retrieval
   reasoning effort; this source does not support `minimal`.

5. **Test from the hosted application.** Sign in as an authorized pilot user
   and ask the same fixed-period question. Compare the result with the Fabric
   test and the owner's expected answer. Check retrieval diagnostics for
   activity from the intended Fabric data-agent knowledge source; a plausible
   answer alone is not proof that the integration ran.

6. **Check the permission boundary.** Repeat the question with a test user
   without access to the pilot data. Confirm that no protected result is
   returned. Sharing a data agent must not be treated as granting access to
   its underlying data.

Fabric data agents enforce read-only queries. Keep source permissions
least-privileged too; a prompt such as “do not modify data” is not an
authorization control.

## Diagnose or undo

| Symptom | Check |
| --- | --- |
| Hosted startup or requests reject `nl2sql` | Restore the previous hosted-compatible strategy through the application deployment process. Do not remove the hosted guard or provision more SQL metadata indexes. |
| Fabric succeeds, but the application returns no Fabric result | Check the preview response contract, source binding, enabled integration and OBO identity. Without a per-user OBO token, the connector skips this source. Do not substitute a broadly privileged service identity. |
| Access denied | Check the actual user's data-agent and underlying-data permissions, then the application's OBO path. See [Application authentication](application-auth.md). |
| A result is incorrect | Recheck the fixed period, selected tables, schema, business definitions and Fabric example queries. Compare the same question directly in Fabric before changing the hosted application. |

To undo the pilot, remove its knowledge-source reference from the knowledge
base before deleting the source, and revoke pilot sharing in Fabric. Preserve
other knowledge sources and the underlying database. Keep deployment inputs
consistent with the rollback so later provisioning does not restore the
pilot binding; use the lifecycle procedure in [Fabric integration](fabric-iq.md).

## Need a direct SQL connection?

There is no shipped hosted switch that turns an arbitrary database into a
safe NL2SQL tool. If Fabric is unsuitable, plan a
[custom tool extension](agent-tools.md): enforce read-only database permissions,
allowlisted data access, bounded query time and result size, caller
authorization and audit logging in the service that executes queries. Validate
identity and network access end to end before exposing it to the hosted agent.
This is development work, not a configuration alternative to the pilot above.
