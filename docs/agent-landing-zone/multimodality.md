# Images and voice

Agent Application can ground text answers in image descriptions extracted
from documents. This differs from passing an image or audio directly to a
model. The default hosted `maf_lite` path uses text input and retrieved text.
This page explains capability boundaries; the
[Deploy full stack runbook](deploy-full-stack.md) contains deployment procedures.

<span id="choose-a-scenario"></span>

## Supported content

| Content | Hosted application behavior |
| --- | --- |
| Diagrams in a shared collection | Native Foundry IQ Blob ingestion can produce image descriptions when its model and extraction requirements are met. |
| Conversation PDF | Optional Agent App Ingestion processes uploads; native Search permissions and a conversation filter authorize hosted retrieval. |
| Screenshot or standalone image | Not accepted by the supplied hosted input adapter or PDF upload handler. |
| Voice | No supplied capture, transcription, realtime audio or playback integration. |

<span id="ground-answers-in-document-images"></span>

## Document image grounding

Native Blob ingestion can verbalize images during document processing. The
knowledge base then returns extracted content to the orchestrator; the model
receives text, not the original image.

This path uses `RETRIEVAL_BACKEND=foundry_iq`,
`FOUNDRY_IQ_PATTERN=azureBlob`, `FOUNDRY_IQ_KNOWLEDGE_SOURCE_KIND=azureBlob`
and `FOUNDRY_IQ_CONTENT_EXTRACTION_MODE=standard`.
Agent App Ingestion is not required.

The provisioning template sets `disableImageVerbalization=false`, but only
supplies `chatCompletionModel` for its supported Content Understanding model
names. `gpt-4.1` is supported; the default `gpt-5-nano` is not in that allowlist.
The flag alone therefore does **not** establish working image verbalization
in a fresh deployment. Standard extraction also requires a compatible region,
Foundry AI Services endpoint and embedding deployment.
[Blob source prerequisites](https://learn.microsoft.com/en-us/azure/search/agentic-knowledge-source-how-to-blob)
describe service requirements.

In `main.parameters.json`, the chat entry of `modelDeploymentList` uses
`canonical_name: CHAT_DEPLOYMENT_NAME`; `model.name` identifies the family
and `name` identifies the deployment. A model change affects availability,
quota and extraction compatibility.
[Deployment settings](configuration.md) identifies the configuration inputs.
The rendered source's model binding and extracted diagram content are the
evidence of successful processing, not the model name alone.

The ingestion identity's source/model access is independent of the user's
retrieval permissions. Private connectivity follows
[Network isolation](network-isolation.md). Protected hosted retrieval uses the
[integrated delegated identity path](application-auth.md#3-verify-the-retrieval-identity-boundary)
and still needs allow/deny validation; image extraction does not authorize users.

<span id="attach-a-pdf-to-a-conversation"></span>

## Conversation PDFs

`DEPLOY_INGESTION_CONTAINER_APP` defaults to `false`, so fresh deployments hide
and reject uploads. Optional Agent App Ingestion is required for eligible PDF
attachments, as described in [Ingestion and conversation uploads](ingestion.md).

With a native Blob primary source, conversation retrieval requires
`FOUNDRY_IQ_CONVERSATION_UPLOAD_ENABLED=true` and provisioned
`FOUNDRY_IQ_CONVERSATION_KNOWLEDGE_SOURCE_NAME`. The name identifies a Search
knowledge source, not a URL or conversation ID. Keep the source and retrieval
API settings compatible with the configured knowledge base. A missing or failed
configured upload source stops required retrieval rather than silently returning
only shared-corpus results.

The UI needs an established hosted conversation ID and an eligible signed-in
session. It accepts at most five PDFs, 15 MiB each and 25 MiB combined.
Anonymous embedded sessions cannot upload.

The UI validates the authenticated uploader's object ID before ingestion.
Every uploaded chunk receives that user's ACL and the hosted conversation ID;
group and RBAC grants remain empty. Native Search evaluates that ACL using the
delegated Search token, while an additional conversation filter prevents results
from other conversations. The runtime does not treat an opaque hosted partition
key as an uploader identity or decode the forwarded token to invent one.
Processing confirmation alone is not retrieval-isolation evidence: test both
the uploader and a different user, including citations and download attempts.

Agent App Ingestion's separate `MULTIMODAL` setting controls figure extraction
and captioning in its custom pipeline. It does not enable direct screenshot
input. Scanned or diagram-only PDFs depend on the extracted content.

<span id="diagnose-a-missing-image-answer"></span>

## Evidence and configuration lifecycle

Grounded image answers depend on completed ingestion, extracted content, a
compatible model binding and the intended source reference. A processed PDF
can still be absent from retrieval; shared-source answers alone do not prove
conversation-upload retrieval works.

Runtime configuration is cached. A changed hosted setting needs a new agent
version; affected UI and ingestion processes also need to reload. Source/model
changes follow the [Deploy full stack runbook](deploy-full-stack.md).
The pinned API remains part of the application contract rather than an
independent setting to change without compatibility validation.

<span id="direct-images-or-voice-need-an-application-extension"></span>
<span id="direct-images-or-voice-need-an-agent-application-extension"></span>

## Direct image and voice extensions

Screenshot input requires caller and adapter development to validate and
forward image content to a compatible model. Microsoft's
[vision input guide](https://learn.microsoft.com/en-us/azure/ai-services/openai/how-to/gpt-with-vision)
describes model APIs, not an enabled Agent Application feature.

Voice requires client/service integration for capture, transcription or
realtime audio, and playback. The
[Realtime audio guide](https://learn.microsoft.com/en-us/azure/ai-services/openai/how-to/realtime-audio)
describes those APIs. [Bring your own app](build-your-own-app.md) covers the
application boundary. Both extensions need authentication, input limits and
source authorization when connected to retrieval.
