# Agent Landing Zone What's new

This page summarizes ingestion and private-connectivity capabilities for the
supplied Agent Application. The [Deploy full stack](deploy-full-stack.md)
runbook contains the default deployment procedure.

<span id="14th-october-2026"></span>

## Ingestion and private connectivity

- **Managed knowledge ingestion:** Foundry IQ prepares and retrieves documents
  for agent responses. Its native ingestion uses service-managed processing
  and is the default. Custom processing and conversation uploads need the
  optional Agent App Ingestion component.
  [Ingestion](ingestion.md) explains the paths.
- **Private file access:** Native ingestion supports private Azure Blob Storage
  sources, where the documents are stored as files,
  through approved Search shared private links, which let Azure AI Search
  connect privately to source storage and processing services. See
  [private native Blob ingestion](network-isolation.md#private-native-blob-ingestion).
- **Isolated image builds:** Outbound encrypted web (HTTPS) rules let the
  image-build network reach required package feeds.
  [Network isolation](network-isolation.md#image-builds-in-isolated-deployments)
  explains the connectivity requirements.

These capabilities do not establish user-authorized retrieval: checking that
the person asking a question may read each returned document.
[Agent Application access](application-auth.md#3-verify-the-retrieval-identity-boundary)
explains the hosted identity integration required before exposing protected data.

<span id="3rd-october-2026"></span>
