# User feedback

Feedback is a UI/BFF product feature, separate from native agent or workflow
execution. Foundry and Durable Task Scheduler persist execution state;
neither automatically supplies the application's owner-scoped ratings,
comments or operator views.

Select `ENABLE_USER_FEEDBACK=true` explicitly; its default is `false`.
Provision the UI metadata store and frontend-only permissions. The UI consumes
`DATABASE_ACCOUNT_NAME`, `DATABASE_NAME` and `NATIVE_UI_METADATA_CONTAINER`
(default `native-ui-metadata`, partition key `/principal_id`).
Do not require optional ingestion or an additional execution service merely
to store a user's feedback.
See [Conversations & files](conversations.md) for state ownership and
[Application settings](application-settings.md) for configuration.

<span id="choose-the-supported-path"></span>

## User controls and storage

When feedback is enabled and its dependencies are ready, the chat control
submits to the authenticated UI/BFF. The BFF checks the current owner mapping
and associates feedback with the intended conversation/run and message/result.
The product store holds feedback metadata, not native execution checkpoints.
The route is `POST /api/native/sessions/{id}/feedback` with
`native_ref`, `rating` (`-1` or `1`) and `comment` (at most 2,000 characters).
The UI UUID must belong to the authenticated owner. Unknown/nonowned IDs
return `404` before backend access; a native reference alone grants nothing.
Feedback uses the native UI route above; `/panel/conversations` is not mounted.

Do not display working-looking controls for an unavailable integration.
A clicked thumb or accepted browser event is not evidence that feedback was
saved. Report storage failures rather than confirming a successful write.
Anonymous embedding does not establish an authenticated conversation owner.

## Ownership contract

Every feedback read or mutation must:

1. Validate the authenticated user at the BFF boundary.
2. Resolve a server-owned mapping to the selected native session/run.
3. Check that the target message/result belongs to that owner and execution.
4. Validate the feedback payload and persist it in the declared product store.
5. Return the actual result without forwarding credentials into the feedback
   document, prompt or telemetry.

A known run ID, user ID in the body or a shared managed identity is not
authorization. Missing mappings or dependencies fail closed; they must not
fall back to another user's execution or an unrelated backend.

<span id="verify-and-recover"></span>

## Verify and recover

Verify the feedback write response and authorized metadata persistence,
that another user cannot submit against that session, and that an unavailable
store produces an explicit failure. Do not invent a native feedback-list
endpoint from the old panel API.
Check the result after retries so that a transport interruption does not
silently create unrelated records.

Disabling a product surface is not data deletion. Retain existing feedback
according to policy and verify cleanup separately when a conversation or run
is removed. Native state and product metadata have different lifecycle APIs.

## Administrative views

User feedback authorization is not operator authorization.
Expose administrative reads only through an explicitly supported operator
surface with its own roles, aggregation and privacy controls.
Do not assume the optional ingestion dashboard shares the UI's schema or
provides a consolidated native history/feedback administration API.
See [Administration](operations.md).

## Privacy and retention

Comments can contain sensitive user-authored data even when the store contains
no transcript. Define retention, allowed operator access, export/deletion
handling and backup policy separately from native conversation retention.
Audit identifiers and outcomes without recording tokens or unnecessary content.
[Monitoring & audit](application-monitoring.md) covers operational evidence.
