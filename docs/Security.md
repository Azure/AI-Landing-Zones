## Security

Security requirements and best practices for the AI Landing Zone.

| ID   | Specification |
|------|--------------|
| S-R1 | **Microsoft Defender for Cloud:** Align with Microsoft Defender for Cloud (MDC) recommendations by default.<br><br><strong>Best practice:</strong><br>MDC can help [discover generative AI workloads](https://learn.microsoft.com/azure/defender-for-cloud/identify-ai-workload-model) and [predeployment generative AI artifacts](https://learn.microsoft.com/azure/defender-for-cloud/explore-ai-risk). Use [AI security posture management](https://learn.microsoft.com/azure/defender-for-cloud/ai-security-posture) to automate detection and remediation of generative AI risks. Enable [AI threat protection](https://learn.microsoft.com/azure/defender-for-cloud/ai-threat-protection). |
| S-R2 | **Microsoft cloud security baseline:** Comply with [Azure security baselines](https://learn.microsoft.com/security/benchmark/azure/security-baselines-overview) and apply guidance from [Azure service guides](https://learn.microsoft.com/azure/well-architected/service-guides/?product=popular). |
| S-R3 | **Microsoft Purview:** Provide guidance to use Purview to classify, govern, and protect sensitive data.<br><br><strong>Best practice:</strong><br>Use [Purview Insider Risk Management](https://learn.microsoft.com/purview/insider-risk-management) to assess enterprise data risks and prioritize response by sensitivity. |
| S-R4 | **Industry frameworks:** Reference [MITRE ATLAS](https://atlas.mitre.org/) and [OWASP generative AI risk](https://genai.owasp.org/) to identify architecture risks and mitigation patterns. |
| S-R5 | **Prompt shielding & output monitoring:** Use Azure AI Content Safety guardrails.<br><br><strong>Best practice:</strong><br>Inspect model outputs for injection or unsafe content. Implement [prompt shields](https://learn.microsoft.com/azure/ai-services/content-safety/concepts/jailbreak-detection) to detect jailbreak attempts. |
| S-R6 | **Zero trust:** Provide implementation and guidance for zero trust principles (explicit verification, least privilege, assume breach) across identities, data, endpoints, and network. |
