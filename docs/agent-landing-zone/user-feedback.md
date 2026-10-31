# User feedback

The default `hosted-no-panel` application has no supported feedback collection
or feedback administration surface. Optional `hosted-panel` provides
Cosmos-backed APIs, but the supplied chat controls do not call those APIs.
Hosted feedback requires a custom UI control and validated conversation
ownership. [Foundry hosted agents](https://learn.microsoft.com/en-us/azure/ai-foundry/agents/concepts/hosted-agents)
provide the container runtime, not this feedback integration.

This page describes those boundaries. The [full-stack deployment guide](deploy-full-stack.md)
covers deployment and redeployment, not a ready-made feedback customization.

<span id="choose-the-supported-path"></span>

## Available surfaces

| Surface | Supplied behavior |
| --- | --- |
| `hosted-no-panel` | Chat without application feedback storage. |
| `hosted-panel` | Metadata storage and gated APIs; selection alone does not activate feedback. |
| `ENABLE_USER_FEEDBACK` | Default `false`. Existing Chainlit thumbs call the non-hosted orchestrator backend, not the panel API. |
| `USER_FEEDBACK_RATING` | Default `false`. Changes those same controls to a rating/comment form; it does not connect them to hosted feedback. |

Anonymous embedded sessions cannot use feedback actions.
Keeping both control flags off avoids presenting a hosted feedback integration
that is not supplied.

<span id="prepare-a-hosted-panel-integration"></span>

## Hosted-panel integration contract

User-facing history, feedback and deletion share the same gates.

| Dependency | Contract |
| --- | --- |
| Panel deployment | `DEPLOY_ADMINISTRATIVE_PANEL` reflects actual `hosted-panel` provisioning. |
| Continuity | Active owner-bound hosted continuity, not just `HOSTED_CONTINUITY_ENABLED=true`. |
| User surfaces | `PANEL_HISTORY_ENABLED` defaults to `false`. |
| Token validation | `PANEL_CONVERSATIONS_TOKEN_AUDIENCE` identifies the delegated token audience; tenant comes from `PANEL_CONVERSATIONS_TENANT_ID` or the OAuth tenant. |
| Metadata | Provisioned `DATABASE_ACCOUNT_NAME`, `DATABASE_NAME` and UI identity access to Cosmos. |
| Enumeration | `PANEL_CONVERSATION_ENUMERATION_MODE=owner_index` is the default. Delegated mode requires its own evidence gate. |

The default containers are `panel-conversation-owner-index` and `panel-feedback`.
`HOSTED_CONVERSATION_OWNER_BINDING_VALIDATED` gates delegated continuity;
`PANEL_HISTORY_OWNER_BINDING_VALIDATED` independently gates delegated panel
enumeration. Neither grants permissions. Provisioning resets owner-validation
and operator-surface gates to `false`; they remain false until deployment-specific
authorization evidence exists. [Agent hosting](hosted-agents.md) describes the
continuity protocol and permission requirements.

The custom control calls the **UI service**, not the hosted container:

<div class="reference-fields responsive-reference" markdown="1">
<table role="table" markdown="1">
<thead role="rowgroup" markdown="1">
<tr role="row" markdown="1">
<th scope="col" role="columnheader" markdown="span">UI endpoint</th>
<th scope="col" role="columnheader" markdown="span">Purpose</th>
</tr>
</thead>
<tbody role="rowgroup" markdown="1">
<tr role="row" markdown="1">
<th scope="row" role="rowheader" markdown="span">`GET /panel/conversations`</th>
<td role="cell" data-label="Purpose" markdown="span">Lists the caller's conversation IDs.</td>
</tr>
<tr role="row" markdown="1">
<th scope="row" role="rowheader" markdown="span">`POST /panel/conversations/{conversation_id}/feedback`</th>
<td role="cell" data-label="Purpose" markdown="span">Creates or upserts that owner's feedback.</td>
</tr>
<tr role="row" markdown="1">
<th scope="row" role="rowheader" markdown="span">`GET /panel/conversations/{conversation_id}/feedback`</th>
<td role="cell" data-label="Purpose" markdown="span">Reads feedback after the same ownership check.</td>
</tr>
</tbody>
</table>
</div>
Every request requires a delegated user bearer with `user_impersonation`,
valid tenant/audience and active gates. Listing is scoped to the caller;
per-conversation operations require a Cosmos owner-index match.
A conversation ID alone grants no access.

The body contains `feedback_id` and `message_ref` (1–128 characters each),
optional integer `rating` from `-5` to `5`, `category` up to 64 characters and
`comment` up to 2,000. Unknown fields are rejected. The feedback ID is unique
across that owner's conversations; retrying it upserts the owner's record.
Tokens are not body fields or URL parameters.

Runtime settings normally use App Configuration label `agent-lz` and load at
UI startup. [Application settings](application-settings.md#overrides-and-effective-values)
describes overrides.
Changes require a UI process reload. Source changes require a compatible
application build. Neither enabling flags nor deploying the panel implements
the missing control.

<span id="verify-and-recover"></span>

## Expected isolation and failures

An owner can submit and read back saved fields and timestamp. Another user
receives `404`, indistinguishable from a missing conversation. Missing active
gates return `503`; invalid identity returns `401`/`403`; invalid input returns
`422`. Metadata or managed-conversation failures can return `502`, not an
empty successful feedback list.

`PANEL_HISTORY_ENABLED=false` disables user history, feedback and deletion after
reload without deleting stored metadata or changing hosted chat routing.

## Administrative views

See [Administration](operations.md) for panel setup and operator access.

When the ingestion service is selected, its separate hosted-panel API exposes
`GET /api/panel/feedback` and counts in `GET /api/panel/overview`. It validates
an Entra bearer with the `Admin` app role and rejects missing tenant configuration.
Its schema uses `conversationId`, `messageId`, `rating: "up" | "down"`, `comment`
and `tags`.

The UI schema instead uses `message_ref` and numeric ratings.
There is no shipped adapter joining these schemas into an administrative view.

Operator overview/curation is separately gated by
`PANEL_OPERATOR_SURFACES_ENABLED`, actual deployment, an explicit
`PANEL_OPERATOR_APP_ROLE` or `PANEL_OPERATOR_GROUP_ID`, and the backend
cursor-signing secret. Provisioning leaves it disabled pending authorization
validation. The `Admin` role and user-history gate do not substitute for this
operator contract.

## Privacy and retention

Panel Cosmos stores ownership and feedback metadata, not chat transcripts or
citations. Comments are still user-authored data and can contain sensitive
content. Operator authorization and feedback retention need explicit policy
separate from Foundry conversation retention.
[Cosmos DB time to live](https://learn.microsoft.com/en-us/azure/cosmos-db/time-to-live)
can expire configured metadata; this integration sets no automatic retention
period. Conversation deletion attempts feedback cleanup, which can fail and
needs result verification. Backups have their own retention boundary.
