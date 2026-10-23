# Ask questions about SQL data

Use this guide to plan a read-only pilot over approved relational data with a
Fabric data agent and Foundry IQ. Agent Application includes connector code;
hosted use requires resolving the delegated-identity and preview compatibility
gaps below.

## Choose the supported route

| Route | Hosted Agent Application compatibility |
| --- | --- |
| Legacy `nl2sql` strategy | Rejected by the hosted runtime. Available only in the classic runtime. |
| Fabric data agent through a Foundry IQ knowledge base | Integration code is shipped, but service compatibility must be checked below. Fabric generates and executes read-only queries. The knowledge-source connector is a Microsoft preview. |
| Custom SQL tool | An Agent Application extension, not a supplied SQL integration. You must implement, secure, deploy and validate it with a hosted-compatible strategy. See [Agent tools](agent-tools.md). |

For Fabric SQL questions, use a **warehouse** or **lakehouse tables** exposed to
the data agent. A Power BI semantic model uses DAX rather than SQL. Fabric
handles queries and schema context, without the legacy NL2SQL plugin or its
metadata indexes.

## Prerequisites

- A working hosted Agent Application using Foundry IQ knowledge-base retrieval.
- A Fabric workspace with supported capacity and tenant settings, and an owner
  able to create, publish and share a data agent. See Microsoft's
  [Fabric data agent requirements](https://learn.microsoft.com/fabric/data-science/concept-data-agent).
- A small, non-sensitive warehouse or lakehouse table with known answers.
  Pilot users need access to the data agent **and** its underlying data.
- A platform operator able to provision the knowledge source and update its
  knowledge-base binding. The Search service and Fabric workspace must use the
  same Microsoft Entra tenant.
- An authenticated Agent Application path that supplies the end user's delegated
  identity for on-behalf-of (OBO) retrieval. This remote source requires both
  service authentication and user authorization. The connector forwards a
  Search-audience user token separately; do not paste tokens into
  configuration or commands. The pinned hosted entry point does not supply this
  delegated token. Resolve the [hosted identity boundary](foundry-iq.md) through
  a reviewed integration before running the pilot.
- Network policy allowing the required service connections. Have the platform
  owner validate connectivity along the retrieval path to Fabric and any Fabric
  workspace outbound access rules without weakening private-access policies.

The Foundry IQ **Fabric Data Agent knowledge source** is preview, independently
of the Fabric data agent's own release status. Confirm regional availability,
data residency and preview acceptance before using real business data. Review
the [connector requirements and limits](https://learn.microsoft.com/azure/search/agentic-knowledge-source-how-to-fabric-data-agent).

!!! warning "Validate preview API compatibility before connecting"
    Agent App Orchestrator v5.2.1's data-agent parser expects `dataAgentAnswer`
    and `dataAgentRawData` in retrieval references. Current Microsoft documentation
    instead describes `fabricAnswer` and `fabricEmbeddedResources`, using
    `2026-08-01-preview`; the platform and orchestrator defaults use
    `2026-05-01-preview`. Have the Agent Application owner validate the deployed
    API and response fields together before proceeding. Its separate ontology
    parser can read `fabricAnswer`,
    but does not handle `fabricEmbeddedResources` and classifies that answer
    as ontology content. Data-agent result parsing and table/chart handling
    therefore need explicit validation. If the deployed fields differ, obtain
    a compatible, validated Agent Application release covering the API and parser.

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
   Obtain the Fabric IDs from the item's URL.
   The shipped opt-in is `FABRIC_DATA_AGENT_ENABLED` with
   `FABRIC_DATA_AGENT_KNOWLEDGE_SOURCE_NAME`; `FABRIC_IQ_ENABLED` selects the
   separate ontology integration. Use the provisioning and runtime activation
   steps in that runbook rather than changing App Configuration alone.

4. **Verify the binding before testing chat.** Ask the operator to confirm that
   the knowledge base references a source of kind `fabricDataAgent` with the
   intended workspace and data-agent IDs. Use `low` or `medium` retrieval
   reasoning effort; this source does not support `minimal`.

5. **Test from hosted Agent Application.** Sign in as an authorized pilot user
   and ask the same fixed-period question. Compare the result with the Fabric
   test and the owner's expected answer. Check retrieval diagnostics for
   activity from the intended Fabric data-agent knowledge source and confirm
   that the result came from that source.

6. **Check the permission boundary.** Repeat the question with a test user
   without access to the pilot data. Confirm that no protected result is
   returned. Grant access to the data agent and its underlying data separately.

Fabric data agents enforce read-only queries. Keep source permissions
least-privileged so the data service enforces the approved access policy.

## Diagnose or undo

| Symptom | Check |
| --- | --- |
| Hosted startup or requests reject `nl2sql` | Restore the previous hosted-compatible strategy through the Agent Application deployment process. Do not remove the hosted guard or provision more SQL metadata indexes. |
| Fabric succeeds, but Agent Application returns no Fabric result | Check the preview response fields, source binding, enabled integration and OBO identity. Without a per-user OBO token, the connector skips this source. Repair delegated-token delivery while retaining scoped service permissions. |
| Access denied | Check the actual user's data-agent and underlying-data permissions, then Agent Application's OBO path. See [Agent Application authentication](application-auth.md). |
| A result is incorrect | Recheck the fixed period, selected tables, schema, business definitions and Fabric example queries. Compare the same question directly in Fabric before changing hosted Agent Application. |

To undo the pilot, remove its knowledge-source reference from the knowledge
base before deleting the source, and revoke pilot sharing in Fabric. Preserve
other knowledge sources and the underlying database. Keep deployment inputs
consistent with the rollback so later provisioning does not restore the
pilot binding; use the lifecycle procedure in [Fabric integration](fabric-iq.md).

## Need a direct SQL connection?

For a database outside Fabric, plan a
[custom tool extension](agent-tools.md): enforce read-only database permissions,
allowlisted data access, bounded query time and result size, caller
authorization and audit logging in the service that executes queries. Validate
identity and network access end to end before exposing it to the hosted agent.
This path requires custom development and security validation.
