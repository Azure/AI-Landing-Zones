# User feedback

Collect answer ratings and comments through the optional hosted-panel API.
The default **hosted-no-panel** deployment has no application feedback store
or feedback administration surface. Foundry conversation persistence does not
add either feature. [Foundry hosted agents](https://learn.microsoft.com/en-us/azure/ai-foundry/agents/concepts/hosted-agents)
provide the hosting runtime; the feedback APIs below belong to the bundled
application.

## Choose the supported path

| Deployment or control | What is available |
| --- | --- |
| `hosted-no-panel` | Hosted chat, but no supported application feedback collection. |
| `hosted-panel` | Optional Cosmos-backed feedback APIs. User-facing routes require additional gates; deploying the panel alone does not activate them. |
| `ENABLE_USER_FEEDBACK=true` | Shows the existing Chainlit thumbs controls on eligible nonempty answers. The callbacks still call the classic orchestrator, not the hosted-panel API. Do not enable this as a hosted feedback solution. |
| `USER_FEEDBACK_RATING=true` | Changes those existing controls from immediate thumbs submission to a rating/comment form. It does not change their backend. Both UI flags default to `false`; anonymous embedded sessions cannot use feedback actions. |

For hosted chat, adding a rating/comment control that calls the panel API is
**application customization**, not a Foundry setting. Keep hosted chat on
`CHAT_BACKEND=hosted_agent`; do not deploy a classic orchestrator just to make
the old callbacks work.

## Prepare a hosted-panel integration

You need an application developer, a deployment operator, and an Entra
administrator for the token audience and permissions. Use approved test
conversations and a connected development host if the application is private.

1. Follow [Deploy the full stack](deploy-full-stack.md) to select
   `DEPLOYMENT_TOPOLOGY=hosted-panel`. This selects hosted orchestration plus
   `DEPLOY_ADMINISTRATIVE_PANEL=true`; it does not move chat into Container
   Apps. Confirm that the panel metadata containers and the UI identity's
   Cosmos access have been provisioned.
2. Establish working owner-bound hosted continuity before enabling the
   user-facing panel routes. `HOSTED_CONTINUITY_ENABLED=true` is required.
   Follow [Hosted agents](hosted-agents.md) for the hosted runtime; an arbitrary
   conversation ID is not proof of ownership.
3. Configure the user-facing API gates and dependencies:

   | Runtime setting | Required behavior |
   | --- | --- |
   | `DEPLOY_ADMINISTRATIVE_PANEL` | `true`, backed by actual panel provisioning. |
   | `PANEL_HISTORY_ENABLED` | `true`; enables user history, feedback and deletion together. |
   | `PANEL_CONVERSATIONS_TOKEN_AUDIENCE` | Expected audience claim of the delegated user access token, not a UI URL. |
   | `PANEL_CONVERSATIONS_TENANT_ID` | Issuing tenant ID; falls back to `OAUTH_AZURE_AD_TENANT_ID`. |
   | `DATABASE_ACCOUNT_NAME`, `DATABASE_NAME` | Provisioned Cosmos account and database names, not endpoints. |
   | `PANEL_CONVERSATION_ENUMERATION_MODE` | Keep `owner_index`, the default. |

   The default metadata containers are `panel-conversation-owner-index` and
   `panel-feedback`, selected by `PANEL_OWNER_INDEX_DATABASE_CONTAINER` and
   `PANEL_FEEDBACK_DATABASE_CONTAINER`.

   Do not select `delegated` enumeration without
   `PANEL_HISTORY_OWNER_BINDING_VALIDATED=true` and environment-specific
   evidence: the UI configuration loader rejects that combination. This
   panel gate is separate from continuity's
   `HOSTED_CONVERSATION_OWNER_BINDING_VALIDATED` gate.

   Apply nonsecret runtime keys under label `agent-lz` using Entra
   authentication (`az appconfig kv set --auth-mode login`), following
   [Configuration](configuration.md). These settings are loaded at UI startup:
   replace/restart the UI process after an approved change, not the Foundry
   hosted agent. Check environment-variable overrides as well as remote keys.
   Provisioning republishes panel settings and forcibly resets
   `PANEL_HISTORY_OWNER_BINDING_VALIDATED` and
   `PANEL_OPERATOR_SURFACES_ENABLED` to `false`; an azd input cannot attest
   either evidence gate.
4. Add a signed-in feedback control to your UI. Send a delegated user bearer
   to the UI service's
   `POST /panel/conversations/{conversation_id}/feedback` endpoint. Obtain the
   conversation ID from `items[].id` returned by
   `GET /panel/conversations` on the same UI service, not from user input or
   another session. This ID identifies a conversation; it is not an endpoint
   or an agent name. Use the same ID for
   `GET /panel/conversations/{conversation_id}/feedback` to verify persistence.

   The bearer must include the delegated `user_impersonation` scope for the
   configured audience. Never put tokens in URLs, example bodies or command
   history. Each request validates the caller and checks the Cosmos owner
   index before accepting the conversation ID. Conversation ownership does
   not grant permission to retrieved source documents; preserve retrieval
   OBO and source ACL enforcement.

   Example JSON body for this **UI API**, not the ingestion API:

   ```json
   {
     "feedback_id": "review-001",
     "message_ref": "answer-reference",
     "rating": 1,
     "category": "answer-quality",
     "comment": "The answer needs a clearer explanation."
   }
   ```

   Generate a unique `feedback_id` for each review and retain it for retries.
   Supply your answer's reference as `message_ref`. Rating is optional and
   accepts integers from `-5` to `5`; category is limited to 64 characters and
   comment to 2,000. Unknown fields are rejected. Retrying the same feedback
   ID upserts that owner's record. Keep IDs unique across that owner's
   conversations, not just within one conversation.

   This is an API integration recipe, not a built-in hosted chat form. If you
   cannot maintain a custom control, leave the legacy feedback flags off and
   use your organization's approved support channel instead.

## Verify and recover

Submit feedback as the conversation owner, then read it back: expect the saved
fields and timestamp. Repeat with a different signed-in user: expect `404`,
the same response as a missing conversation, not disclosure of the record.

| Result | Check |
| --- | --- |
| `503` | Panel deployment, history gate and active hosted continuity are all required. |
| `401` / `403` | Validate token tenant, audience and delegated-user identity. Do not replace it with an application-only token. |
| `404` | Confirm the conversation exists in this user's owner index. Do not bypass ownership checks. |
| `422` | Check field bounds and unknown fields. |
| `502` | Investigate the metadata store or managed conversation dependency; do not treat a failed read as an empty feedback list. |

To withdraw the custom user-facing surface, set `PANEL_HISTORY_ENABLED=false`
and reload the UI process. This also disables panel history and deletion,
but does not delete stored feedback or change hosted chat routing. Do not
remove Cosmos resources as a feedback toggle.

## Administrative views

The ingestion service has a separate Admin-authorized
`GET /api/panel/feedback` API and feedback counts in
`GET /api/panel/overview`, only in hosted-panel mode. These require a validated
bearer with the Entra `Admin` app role; missing tenant configuration does not
disable authorization.

These are **not** the UI API above: ingestion uses `conversationId`,
`messageId`, `rating: "up" | "down"`, `comment` and `tags`, whereas the UI
stores `message_ref` and a numeric rating. There is no shipped adapter joining
these contracts. Do not promise that owner-submitted UI records appear in an
admin feedback view. A unified moderation view requires a deliberate schema
and authorization integration.

The separate operator overview/curation surface is gated by
`PANEL_OPERATOR_SURFACES_ENABLED=true`, actual panel deployment, an explicit
`PANEL_OPERATOR_APP_ROLE` or `PANEL_OPERATOR_GROUP_ID`, and the backend's
cursor-signing secret. It is not enabled by the `Admin` role or the user
history gate alone. Provisioning deliberately leaves this evidence gate off.

## Privacy and retention

Panel Cosmos stores ownership and feedback metadata, not chat transcripts or
citations. Comments are still user-authored data: ask users not to paste
secrets, personal data or source documents. Restrict operator access and set
an explicit retention policy for feedback separately from Foundry conversation
retention. [Cosmos DB time to live](https://learn.microsoft.com/en-us/azure/cosmos-db/time-to-live)
can expire metadata when configured; no automatic retention period is promised
by this workflow. The UI's conversation-deletion route also attempts feedback
cleanup; a partial failure is not proof that all records were erased. Include
failed cleanup and retained backups in your deletion procedure.
