# Images and voice

For the bundled application hosted in Foundry, start by choosing **where the
image is processed**. Extracting a diagram during ingestion is not the same as
sending image pixels with a chat prompt.

## Choose a scenario

| You want to… | Shipped hosted path |
| --- | --- |
| Ask about diagrams in a shared document collection | Native Foundry IQ Blob ingestion can verbalize images; the hosted agent retrieves the resulting content through the knowledge base. |
| Attach a document to this conversation | Optional Agent App Ingestion processes PDF uploads. This is conversation-scoped retrieval, not direct image input to the model. |
| Paste a screenshot and ask the model to inspect it | Not implemented by the bundled hosted adapter. Its Responses input is text-only; the UI upload handler accepts PDFs, not standalone images. |
| Speak to the agent or receive spoken answers | No shipped end-to-end voice flow in the bundled UI/hosted adapter. A Speech resource or an audio-capable model does not enable one. |

Use the hosted default strategy, `maf_lite`, for these recipes.
**`multimodal` is not admitted by the hosted runtime.** Do not select that classic
strategy to enable hosted image retrieval.

## Ground answers in document images

**Result:** a text answer grounded in content extracted from documents, including
image descriptions. This does not make the hosted agent a direct vision endpoint.

Before starting, use a working [hosted deployment](hosted-agents.md) with Foundry
IQ retrieval. You need deployment/configuration access, permission to upload test
documents to the configured Blob container, and an approved test document with a
clearly identifiable diagram. Use a test environment for model or ingestion changes.
The Search ingestion identity needs source/model access independently of the
signed-in user's retrieval access. In private deployments, follow
[Network isolation](network-isolation.md) for connected-runner and native Blob
connectivity checks. Do not remove source permissions or switch to a service
identity to make an allow/deny test pass.

1. Select native Blob ingestion before following the
   [full-stack deployment workflow](deploy-full-stack.md):

   ```bash
   azd env set RETRIEVAL_BACKEND foundry_iq
   azd env set FOUNDRY_IQ_PATTERN azureBlob
   azd env set FOUNDRY_IQ_KNOWLEDGE_SOURCE_KIND azureBlob
   azd env set FOUNDRY_IQ_CONTENT_EXTRACTION_MODE standard
   ```

2. Check the deployed model and extraction prerequisites. The shipped template
   enables image verbalization and supplies a chat completion model only for its
   supported Content Understanding model names. `gpt-4.1` is one supported choice;
   the checked-in default chat model, `gpt-5-nano`, is **not** in that template
   allowlist. Do not assume the default enables this image-processing path.
   Use the [model configuration](configuration.md) and Microsoft's
   [Blob knowledge source prerequisites](https://learn.microsoft.com/en-us/azure/search/agentic-knowledge-source-how-to-blob)
   to select an available model/version and supported Content Understanding
   region. Standard extraction also needs the Foundry AI Services endpoint and
   an embedding deployment.
   In the checked-in `main.parameters.json`, the chat entry in
   `modelDeploymentList` has `canonical_name: CHAT_DEPLOYMENT_NAME`: its
   `model.name` is the model family, while its `name` is the deployment name.
   Keep the selected model version and regional quota compatible with that entry.
3. Apply changes through the full deployment workflow. Inspect the provisioned
   Blob knowledge source: expect `contentExtractionMode` to be `standard`,
   `disableImageVerbalization` to be `false`, and a non-null `chatCompletionModel`
   bound to the intended deployment. Native Blob ingestion does not require the
   optional ingestion Container App.
4. Upload the approved document to the configured source container/folder and
   wait for its ingestion to complete. Ask a specific question whose answer
   depends on the diagram, not just its surrounding prose.
5. Check the answer against the diagram and open its source reference. Repeat as
   a user who must not see the document: that content must not appear.
   A correct answer for one user is not an authorization test.

Microsoft's service documentation can describe newer API capabilities than the
pinned release. Keep the release's API configuration; do not upgrade an API
version merely to match a documentation example.

## Attach a PDF to a conversation

**Result:** the PDF is ingested and retrieved within the caller's conversation.
It is not forwarded as an image attachment to the chat model.
Start with a text-bearing PDF. A scanned PDF or a diagram-only page needs
successful extraction; upload acceptance alone does not prove its visual content
is available to retrieval.

1. Follow [Ingestion and conversation uploads](ingestion.md) to select
   `DEPLOY_INGESTION_CONTAINER_APP=true` through the full deployment workflow.
   Fresh bundled deployments default to `false`, which hides and rejects uploads.
2. For a native Blob primary source, configure the Foundry IQ conversation-upload
   source as well: `FOUNDRY_IQ_CONVERSATION_UPLOAD_ENABLED=true` and a provisioned
   `FOUNDRY_IQ_CONVERSATION_KNOWLEDGE_SOURCE_NAME`. Retain the pinned
   `2026-05-01-preview` API required by this upload filter. Enabling ingestion
   alone does not connect uploads to knowledge-base retrieval.
   The source name identifies the registered knowledge source, not a URL or
   conversation ID. Runtime settings use App Configuration label `agent-lz`;
   they are not automatically `azd env set` deployment inputs.
   An operator with App Configuration data-write permission can set the nonsecret
   opt-in using Entra authentication (replace `<store-name>` with the store name,
   not its endpoint):

   ```bash
   az appconfig kv set --name "<store-name>" --auth-mode login --label agent-lz --key FOUNDRY_IQ_CONVERSATION_UPLOAD_ENABLED --value true
   ```

   Retain the provisioned source name and rerun the full workflow to reconcile
   the knowledge source and deploy applications with the updated settings.
3. Sign in with an eligible user and send a text message first to establish the
   hosted conversation identifier. Attach a small PDF and ask a question specific
   to its contents. The handler accepts at most five PDFs, 15 MiB each and
   25 MiB combined. Anonymous Copilot sessions cannot upload.
4. Expect a processed-files confirmation and an answer grounded in that PDF.
   Test a different user's conversation to confirm the upload is not exposed.

The optional ingestion component also has a `MULTIMODAL` document-processing
setting for extracting and captioning figures. It does not enable the hosted
`multimodal` strategy, add image prompt input, or alter native Blob processing.
Do not change it as a workaround for rejected screenshot uploads.

## Diagnose a missing image answer

- **No attachment control:** check the effective ingestion selection first.
  Native Blob ingestion alone never enables conversation uploads.
- **PDF processing failed:** the UI does not send the question after an ingestion
  failure. Reattach the PDF and retry after resolving the reported ingestion
  problem; retain the UI's reference ID for support.
- **PDF processed, but answer uses only the shared collection:** verify the
  conversation-upload knowledge source, conversation ID and authenticated caller
  ownership. The optional upload source can be skipped or fail without failing
  shared-corpus retrieval. A successful chat response is not proof it used the PDF.
- **Diagram missing from the answer:** check ingestion completion, extracted
  content and the provisioned chat model binding before changing prompts.
  An unsupported model name can leave the Blob source's `chatCompletionModel`
  null.

Record the previous model/source settings before changing them. Restore those
inputs and rerun the matching full workflow to undo a configuration experiment;
do not delete indexes or documents as a retry step. Provisioning-managed settings
can overwrite portal edits. Runtime settings load at startup: deploy a new hosted
agent version and reload the affected UI/ingestion services through the documented
deployment workflow, rather than trying to restart a classic orchestrator
Container App. See [Configuration](configuration.md) and
[Hosted agents](hosted-agents.md).

## Direct images or voice need an application extension

For screenshot inspection, implement a caller and adapter that validate and
forward image content to a compatible model; changing only the model deployment
does not change this application's text-only contract. See Microsoft's
[vision input guide](https://learn.microsoft.com/en-us/azure/ai-services/openai/how-to/gpt-with-vision).

For voice, build a client/service integration for capture, transcription or
realtime audio and playback. Microsoft's
[Realtime audio guide](https://learn.microsoft.com/en-us/azure/ai-services/openai/how-to/realtime-audio)
describes the service capability, not a bundled UI feature. Use
[Build your own application](build-your-own-app.md) for the extension boundary.
Preserve user authentication, OBO and source authorization when connecting either
extension to retrieval.
