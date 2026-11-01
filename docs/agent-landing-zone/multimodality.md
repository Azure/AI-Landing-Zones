<span id="images-and-voice"></span>

# Document formats & images

Agent Application can ground text answers in image descriptions extracted
from documents. This differs from passing an image or audio directly to a
model. The conversational interface and registered retrieval capability have
their own input/output contracts; a host choice does not enable image or audio
input.
This page explains capability boundaries. The
[full-stack deployment guide](deploy-full-stack.md) contains deployment procedures.

<span id="choose-a-scenario"></span>

## Supported content

| Content | Application boundary |
| --- | --- |
| Diagrams in a shared collection | Native Foundry IQ Blob ingestion can produce image descriptions when its model and extraction requirements are met. |
| Private conversational file | Optional inline TXT/Markdown, PDF, PNG or JPEG; at most three files, 64 KiB each and 256 KiB per serialized inline turn. No workflow attachments. |
| Screenshot or standalone image in chat | PNG/JPEG attachment transport is implemented; model image understanding is not verified. |
| Voice | No supplied capture, transcription, realtime audio or playback integration. |

<span id="ground-answers-in-document-images"></span>

## Document image grounding

Native Blob ingestion can verbalize images during document processing. The
knowledge base then returns extracted content to the orchestrator. The model
receives text, not the original image.

This path uses `RETRIEVAL_BACKEND=foundry_iq`,
`FOUNDRY_IQ_PATTERN=azureBlob`, `FOUNDRY_IQ_KNOWLEDGE_SOURCE_KIND=azureBlob`
and `FOUNDRY_IQ_CONTENT_EXTRACTION_MODE=standard`.
Agent App Ingestion is not required.

The provisioning template sets `disableImageVerbalization=false`, but only
supplies `chatCompletionModel` for its supported Content Understanding model
names. `gpt-4.1` is supported. The default `gpt-5-nano` is not in that allowlist.
The flag alone therefore does **not** establish working image verbalization
in a fresh deployment. Standard extraction also requires a compatible region,
Foundry AI Services endpoint and embedding deployment.
[Blob source prerequisites](https://learn.microsoft.com/en-us/azure/search/agentic-knowledge-source-how-to-blob)
describe service requirements.

In `main.parameters.json`, the chat entry of `modelDeploymentList` uses
`canonical_name: CHAT_DEPLOYMENT_NAME`. `model.name` identifies the family
and `name` identifies the deployment. A model change affects availability,
quota and extraction compatibility.
[Deployment settings](configuration.md) identifies the configuration inputs.
The rendered source's model binding and extracted diagram content are the
evidence of successful processing, not the model name alone.

The ingestion identity's source/model access is independent of the user's
retrieval permissions. Private connectivity follows
[Network design](network-isolation.md). Protected hosted retrieval uses the
[integrated delegated identity path](application-auth.md#3-verify-the-retrieval-identity-boundary)
and still needs allow/deny validation. Image extraction does not authorize users.

## Custom document formats

The optional [Agent App Ingestion](ingestion.md) service chooses a chunker from
the file extension. This table describes that custom pipeline, not the native
Foundry IQ Blob source's format contract and not the chat upload allowlist.

| Input | Custom processing | Conditional dependencies |
| --- | --- | --- |
| PDF, PNG, JPEG/JPG, BMP, TIFF | Document analysis, with optional figure extraction. | Content Understanding by default, or Document Intelligence when selected. |
| DOCX, PPTX | Document analysis, with optional figures. | Content Understanding or a Document Intelligence version supporting Office formats. Older Document Intelligence APIs reject these formats. |
| XLSX | Dedicated spreadsheet chunker, with sheet-based or optional row-based processing. | Spreadsheet parser, model and embedding deployments. Row-wise Blob processing can use staging storage. |
| JSON | Dedicated JSON chunking. | Embedding deployment for indexed content. |
| VTT | Transcript processing. | Transcript text and model/embedding services used by that chunker. This is not audio transcription. |
| TXT, Markdown, HTML/HTM/SHTML, Python, CSV, XML | Format-aware text splitting. | Readable source text and embedding deployment for indexing. |
| NL2SQL metadata | Dedicated metadata processing and jobs. | The schema/example indexes described in [NL2SQL](nl2sql.md), not document OCR. |

An unrecognized extension falls to the text chunker, which still rejects formats
outside its supported set. That fallback does not mean every file type is
supported. The factory also routes `.xls` to the spreadsheet chunker, but its
OpenPyXL parser expects an Open XML workbook, not a legacy binary Excel file.
Convert legacy workbooks to `.xlsx` before ingestion.
A source connector can impose a narrower allowlist, such as
SharePoint's default `pdf,docx,pptx`. This custom processing table is not a
native chat upload allowlist.

### Select analysis and chunking

Configure these values through [Application settings](application-settings.md).
They affect the custom ingestion service, not native Search source extraction.

- `USE_DOCUMENT_INTELLIGENCE=false` selects Content Understanding using
  `AI_FOUNDRY_ACCOUNT_ENDPOINT`, `CONTENT_UNDERSTANDING_ANALYZER`
  (default `prebuilt-layout`) and `CONTENT_UNDERSTANDING_API_VERSION`.
- `USE_DOCUMENT_INTELLIGENCE=true` selects Document Intelligence and its
  `DOC_INTELLIGENCE_API_VERSION`. Office support depends on that version.
  The selected service needs its own permissions, model availability and
  network path.
- `CHUNKING_NUM_TOKENS` defaults to `2048`, `CHUNKING_MIN_CHUNK_SIZE` to `100`,
  and `TOKEN_OVERLAP` to `200` in document/text chunking. Minimum-size filtering
  and splitting can affect what reaches retrieval.
- `MAX_PAGES_PER_ANALYSIS` defaults to `300` for document analysis.
- `SPREADSHEET_CHUNKING_BY_ROW=false` and
  `SPREADSHEET_CHUNKING_BY_ROW_INCLUDE_HEADER=false` are the spreadsheet defaults.
  `SPREADSHEET_CHUNKING_NUM_TOKENS` defaults to `0`, leaving that extra token
  limit disabled. Review row/header choices against the actual workbook.

Analysis-service dependencies are conditional. Selecting a text or spreadsheet
chunker does not mean it performs OCR. Indexing still needs its configured
embedding deployment and compatible vector dimensions. Transcript processing
generates a summary, and sheet-based spreadsheet processing can summarize large
content, so those paths can also call the chat model.

### Extract and retrieve figures

`MULTIMODAL=false` is the custom ingestion default. Enabling it selects figure
processing for supported document/image inputs. The pipeline extracts figures,
stores images, generates captions and attaches related-image URLs, caption text
and caption embeddings to chunks.

Configure `DOCUMENTS_IMAGES_STORAGE_CONTAINER` (default `documents-images`),
storage write access and an image-capable model. `VISION_DEPLOYMENT_NAME` selects
the captioning model and falls back to `CHAT_DEPLOYMENT_NAME` when unset.
A text-only model is not made image-capable by that fallback.
`MINIMUM_FIGURE_AREA_PERCENTAGE` defaults to `4.0`, so small figures can be
excluded. Missing or failed caption generation can leave `No caption available.`
rather than a useful description.

The registered retrieval tool determines which indexed text and image fields
reach an Agent or Workflow. Extracting figures in ingestion does not register
an image tool, change the chat input contract or automatically pass original
images to a model. Check actual tool output and model inputs instead of
selecting a legacy multimodal strategy.

Review the separate image cleanup configuration in
[Jobs & schedules](ingestion-jobs.md#index-purge-and-cleanup-effects).
It can delete stored figures and does not infer its index/container from every
chunker setting.

<span id="attach-a-pdf-to-a-conversation"></span>

## Private attachment boundary

`ENABLE_PRIVATE_ATTACHMENTS` enables conversational attachments in
`conversational` or `both`, not workflow input. Accepted files are UTF-8
TXT/Markdown, PDF, PNG and JPEG, at most three files and 64 KiB per file.
Both native envelopes must fit a 256 KiB serialized inline turn, including
text, encoding/escaping and metadata overhead.
Entries use `name`, `content_type` and `data_base64`, with strict Base64,
format/signature and owner validation.

Hosted uses official `input_file`/image input; DTS uses native
`context_messages` and IDs. There is no Blob URL, SAS, ingestion dispatch
or corporate publication. UI metadata retains descriptors only, not bytes,
transcripts or tokens. Do not infer this allowlist from shared ingestion.
Selecting `DEPLOY_INGESTION_CONTAINER_APP=true` only deploys that separate
processing service. Transport tests do not verify model PDF/image understanding.
See [Conversations & files](conversations.md#private-attachments).

<span id="diagnose-a-missing-image-answer"></span>

## Evidence and configuration lifecycle

Grounded image answers depend on completed ingestion, extracted content, a
compatible model binding and the intended source reference. A processed shared
PDF can still be absent from retrieval. Successful shared-source processing
does not establish a private attachment feature.

Supported functional parameters use scoped App Configuration refresh; existing
workflows retain their functional snapshot. Structural source/model bindings,
tool registration and host/publication changes need compatible deployment.
UI and ingestion have their own reload rules. Follow
[Application settings](application-settings.md) and the
[full-stack deployment guide](deploy-full-stack.md).
The pinned API remains part of the application contract rather than an
independent setting to change without compatibility validation.

<span id="direct-images-or-voice-need-an-application-extension"></span>
<span id="direct-images-or-voice-need-an-agent-application-extension"></span>

## Direct images and voice

PNG/JPEG can use the optional inline conversational attachment path.
Verify the selected model's actual interpretation separately. Microsoft's
[vision input guide](https://learn.microsoft.com/en-us/azure/ai-services/openai/how-to/gpt-with-vision)
describes model APIs, not proof that this application's model understands
every accepted image.

Voice requires client/service integration for capture, transcription or
realtime audio, and playback. The
[Realtime audio guide](https://learn.microsoft.com/en-us/azure/ai-services/openai/how-to/realtime-audio)
describes those APIs. [Bring your own app](build-your-own-app.md) covers the
application boundary. Voice integration needs authentication, input limits and
source authorization when connected to retrieval.
