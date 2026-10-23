# Agent Landing Zone What's new

This page summarizes Agent Landing Zone releases and changes relevant to operators of its infrastructure and the supplied Agent Application. For site-wide announcements, see [AI Landing Zones What's New](../whatisnew.md).

## 14th October 2026

**Agent Landing Zone v4.3.0**

- **Independent ingestion deployment:** Fresh, supported native-ingestion deployments omit the ingestion Container App. Existing and custom deployments retain their component choices; disabling deployment does not delete existing applications or document data. See [ingestion application selection](configuration.md#ingestion-application-selection).
- **Ingestion-aware uploads:** Agent App UI v3.3.0 disables upload controls and rejects attachments server-side when the ingestion application is disabled. Text chat, authentication and retrieval remain available.
- **Private native Blob ingestion:** Network-isolated setup requires the exact Search shared private links to be approved and successfully provisioned. Pending links produce administrator approval instructions; no unrelated or target-side connections are approved automatically. See [private native Blob ingestion](network-isolation.md#private-native-blob-ingestion).
- **Shared-source permissions:** Deliberately shared, non-ADLS Blob sources can use explicit empty ingestion permission options; protected defaults remain unchanged. Review the [shared-source permission guidance](configuration.md#explicit-shared-source-permission-options) before opting in.
- **Isolated builds and DNS:** Build-subnet-only HTTPS egress covers the pinned Microsoft npm feeds and package-download CDN without requiring firewall DNS proxy. The separate `ENABLE_FIREWALL_DNS_PROXY` option defaults to `false` and does not change client DNS. See [image builds](network-isolation.md#image-builds-in-isolated-deployments) and [firewall DNS proxy](network-isolation.md#opt-in-firewall-dns-proxy).

See the [v4.3.0 release notes](https://github.com/Azure/agent-landing-zone/releases/tag/v4.3.0) for complete changes and reported validation, and the [v4.3.0 manifest](https://github.com/Azure/agent-landing-zone/blob/v4.3.0/manifest.json) for exact component versions. Start with the [full-stack deployment guide](deploy-full-stack.md).

## 3rd October 2026

**Agent Landing Zone v4.0.0**

- **GPT-RAG renamed to Agent Landing Zone:** This major release supports new deployments only. Existing GPT-RAG environments require redeployment; in-place upgrades are not supported.
- **Separate infrastructure and application deployment:** Deploy the infrastructure alone or include the Agent Application, with default or hosted-agent orchestration.
- **Configuration transition:** The `agent-lz` App Configuration label is primary; components still read the legacy `gpt-rag` label during the transition.

See the [v4.0.0 release notes](https://github.com/Azure/agent-landing-zone/releases/tag/v4.0.0) for complete changes and compatibility notes.
