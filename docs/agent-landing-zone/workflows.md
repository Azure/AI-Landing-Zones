# Workflows & human input

A Microsoft Agent Framework (MAF) Workflow is a published process with explicit
steps, conditions and typed input. It is not a chat prompt that happens to ask
for approval. Use a conversational Agent for open-ended chat and a Workflow
when the application must track a process and wait for an authorized person.

## Select the process experience

`APPLICATION_MODE` selects `conversational`, `workflow` or `both`; the default
is `conversational`. The UI presents a named process alongside chat when both
are selected. It does not expose a hosting or strategy picker.

`ORCHESTRATION_HOST` selects `hosted` or `container_apps`.
Hosted publishes the conversation and workflow **separately**, with distinct
endpoints. Container Apps uses the official standalone Durable Extension
worker/client and Durable Task Scheduler (DTS).
See [Agent hosting](hosted-agents.md) and
[native execution selection](configuration.md#native-execution-selection).

## Human review

The research/review process is intentionally bounded: research or draft using
the configured agent/tools, request human review, then produce an approved or
rejected result. Approval is not permission to write to a business system.
Connecting a production write action requires its own tool authorization,
idempotency and approval policy.

The native registrations are `agent-lz-conversation` for the conversational Agent
and `agent-lz-research-review` for the review Workflow.
The process business input is:

```json
{"topic":"Summarize the document retention policy"}
```

Human review supplies the typed business reply:

```json
{"decision":"approve","comment":"The summary is ready to use"}
```

`decision` is `approve` or `reject`. These are business inputs passed through
the selected host's native client, not one universal HTTP protocol.
Hosted topic input is at most 8,000 characters and review comment at most
4,000. Native terminal output is `ResearchReviewResult`, not an invented
conversation envelope.
The pending request/run identifiers come from native state and must match
before a reply is sent.

1. Sign in and start the published process with the required input.
2. The workflow performs its configured research/draft step and reaches native
   pending human input.
3. Chainlit displays actions for that pending request. Review the content
   before submitting the requested choice.
4. The BFF checks the authenticated owner, run and currently pending request
   before forwarding the reply through the selected official client.
5. The native workflow resumes and returns the approved or rejected result.
   A rejected request must not execute the approved branch.

The authenticated UI exposes `/api/native/sessions/{id}/start`, `/progress`
and `/actions`. Start carries `topic`; actions carry the current `request_id`,
`revision` and business `response`. Progress returns `id`, `status`, `pending`,
`revision` and `output`. Unknown/nonowned IDs return `404` before backend
access and stale/duplicate actions return `409`.

Delivery reported as **submitted** is not worker admission or completion.
Read progress for the actual native result.

Hosted start uses stored Responses input. Pending `request_info` is a native
`function_call` with `arguments.request`; reply uses `previous_response_id`
and `function_call_output` with its actual `call_id`.

DTS uses native typed
state/output and the runtime's `native.contracts` codecs. Do not flatten
typed list/yield output or replace it with a custom workflow protocol.
Private attachments are not supported in this workflow.

## Disconnect and resume

Foundry or DTS persists the pending human input. A browser socket, Chainlit
timeout or waiting Python coroutine is not the system of record.
Closing the browser does not approve or reject a process.

Reconnect through the authenticated UI and reopen the same owner-bound run.
Known workflow resume is available with `ENABLE_CHAT_HISTORY=false`;
saved listing and history reads require that flag to be enabled.

The client reads current native state before displaying a pending action.
Replies for a stale request, another run or an already completed action
must not advance an execution. Duplicate submission is not a second approval.

Do not recreate a workflow as a new run simply because a progress stream
disconnected. Check the existing native run and report state-read failures.

## Configuration and authorization

A run captures its functional App Configuration values when it starts.
Supported dynamic changes affect new runs after refresh, not the functional
snapshot of a run already waiting for review.

Authorization is **not** part of that frozen snapshot. Recheck the current
user, ownership, pending request and source/tool permissions on each
interaction. A shared managed identity, session/run ID or body-supplied user
claim is not end-user authorization. Missing trusted context fails closed.
See [Sign-in & access](application-auth.md).

## Operate each host explicitly

| Concern | Hosted | Container Apps |
| --- | --- | --- |
| State and pending requests | Native Foundry workflow persistence | Native durable workflow state in DTS |
| Client | Official Hosted Responses integration | Official durable client |
| Availability | Published workflow and its service dependencies | Worker availability, scheduler connectivity and dependency access |
| UI progress | Selected Hosted protocol | Durable process progress; not a promise of per-token streaming |

The product metadata store keeps owner maps, display information and feedback,
with `/principal_id` set to `tid:oid`; it contains no transcripts, file bytes
or tokens. Workflow mode and `both` select it even when history and feedback
are off. It is not a second copy of execution checkpoints. Redis is not required to imitate
Hosted streaming. No ALZ queue, scheduler or custom workflow-state engine is
introduced.

For operational failures, follow [Troubleshooting](troubleshooting.md).

## Acceptance checks

Before admitting users, verify the exact deployed application:

- A process reaches pending review and is read from a fresh authenticated
  client after disconnect.
- A Container Apps workflow remains pending across an owned worker restart,
  then resumes to the deterministic expected result.
- Approval and rejection select the intended different outcomes.
- Duplicate, stale, wrong-request, wrong-run and different-owner replies do
  not advance another or completed execution.
- A functional configuration update affects a new run while the waiting run
  retains its snapshot; revoked authorization still blocks interaction.

Use published compatible SDK packages and bounded tests with synthetic data.
Local mocks and a sample-only cloud run do not establish support for a
different product image, private-network parity, long-duration recovery or
exactly-once external writes.
