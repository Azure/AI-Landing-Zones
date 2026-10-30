# Monitoring & audit

Use Application Insights and Azure Monitor to follow requests, diagnose
failures and inspect ingestion results. Audit events add structured evidence
about application operations. They do not replace user authorization, data
retention policies or service backups.

## Check an application request

1. Record the deployed application revision and the time of the request.
2. Follow its correlation information through the UI, orchestrator and the
   selected retrieval or ingestion path.
3. Check both the HTTP outcome and the operation result. An ingestion envelope
   can return HTTP success while individual records failed.
4. For denied access, inspect safe status and correlation fields. Do not
   enable token or document-content logging to investigate a permission problem.

Process health probes confirm that a process is running. They do not establish
successful indexing, correct source access or production readiness.
Use [Troubleshooting](troubleshooting.md) for boundary-specific diagnosis.

## Orchestrator audit

Orchestrator audit is off by default. To enable it:

1. Generate a 256-bit secret and store it in Key Vault.
2. Publish it as the `AUDIT_HMAC_KEY` Key Vault reference. The value must
   encode exactly 32 random bytes as Base64, Base64URL or hexadecimal.
3. Set `AUDIT_HMAC_KEY_ID` to the approved key identifier, default `v1`,
   and `AUDIT_EVENTS_ENABLED=true`.
4. Restart the affected Container Apps orchestrator or deploy a new hosted
   agent version, then verify export through the existing telemetry pipeline.

Events use the `gptrag.audit` logger and `agentlz.audit.*` custom-event names.
Delivery is best-effort, not an immutable ledger or a compliance certification.
Keep the HMAC secret out of the dashboard and diagnostic output.

Rotate the key and its identifier together. Pseudonyms produced under different
keys cannot be directly correlated. Set `AUDIT_EVENTS_ENABLED=false` and reload
to stop new orchestrator audit emission. This does not delete exported events.

## Ingestion audit and provenance

Ingestion emits audit events through its existing OpenTelemetry pipeline
without an `AUDIT_EVENTS_ENABLED` opt-in. Export depends on telemetry setup.
The event names are:

- `ingestion.run.started`
- `ingestion.run.completed`
- `ingestion.run.failed`
- `ingestion.run.cancelled`
- `ingestion.document.indexed`
- `ingestion.document.rejected`
- `ingestion.document.deleted`

They are exported under the `agentlz.audit.` prefix. Run wrappers attempt
one start event and one terminal event. Document events carry run correlation.
A completed run means its wrapper did not observe a failure, not that every
possible source document was processed. Check confirmed Search write/delete
results as well as [job status](ingestion-jobs.md).

`INGESTION_PROVENANCE_ENABLED` defaults to `false`. Enable it to add optional
provenance to indexed/deleted events.
`INGESTION_REQUIRE_GOVERNANCE_METADATA=true` also requires provenance or startup
fails. It reports classification and right-to-use only when explicitly supplied,
it does not reject indexing merely because they are absent.

Without strict metadata reporting, defaults are
`INGESTION_DEFAULT_CLASSIFICATION=unclassified` and
`INGESTION_DEFAULT_RIGHT_TO_USE=not_asserted`.
Source/version digests and checksums can reveal equality or existence even
without raw content. Review their retention and readership accordingly.
The `delete_after` provenance field is metadata, not an automatic purge schedule.

## Content capture and privacy

Keep prompt, completion and sensitive audit-content capture off unless its
purpose, access controls and retention have been approved.
For hosted orchestration, the deployment input
`HOSTED_AGENT_CAPTURE_MESSAGE_CONTENT` supplies
`OTEL_INSTRUMENTATION_GENAI_CAPTURE_MESSAGE_CONTENT`. A change requires a
new hosted version.

Sensitive orchestrator audit capture additionally requires
`AUDIT_SENSITIVE_CONTENT_ENABLED` and the explicit
`AUDIT_SENSITIVE_CONTENT_FIELDS` allowlist. Redaction reduces risk but cannot
guarantee that arbitrary user-authored content is safe to export.
Never log tokens, client credentials or authentication claims.

## Event schemas and investigation

The component repositories retain the executable audit schemas and digests:
[orchestrator contracts](https://github.com/Azure/agent-app-orchestrator/tree/main/contracts)
and [ingestion contracts](https://github.com/Azure/agent-app-ingestion/tree/main/contracts).
Use the schema corresponding to your deployed component.

Application Insights custom properties are strings. When correlating root
events, treat `parent_event_id=evt_00000000000000000000000000000000` as
no parent. Historical schema files remain available for older exported events.

Reverting an image does not restore deleted documents, undo configuration
writes or remove telemetry. Follow separately approved data restoration,
reingestion and [configuration recovery](deploy-full-stack.md#roll-back-to-a-previous-release).
For a workload evaluation and release workflow, see [AgentOps](agentops.md).
