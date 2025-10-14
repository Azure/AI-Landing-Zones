## Secur|  S-R5  | **Monitor outputs and apply prompt shielding:** The AI Landing Zone should implement/guide on using AI Content Safety. <br><br>Best Practice:<br><br>Regularly inspect the data returned by AI models to detect and mitigate risks associated with malicious or unpredictable user prompts. Implement [Prompt Shields](https://learn.microsoft.com/en-us/azure/ai-services/content-safety/concepts/jailbreak-detection) to scan text for the risk of a user input attack on generative Al models. |
|  S-R6  | The AI Landing Zone must provide implementation and guidance on zero trust. |

## Define and Maintain Data Boundaries

- Use [Microsoft Purview](https://learn.microsoft.com/en-us/purview/create-sensitivity-labels) to classify data sensitivity and define access policies.
- Implement [Azure RBAC](https://learn.microsoft.com/en-us/azure/role-based-access-control/overview) to restrict data access by workload and user group.
- Use [Azure Private Link](https://learn.microsoft.com/en-us/azure/private-link/private-link-overview) for network-level data isolation between AI applications.

## Implement Comprehensive Data Loss Prevention

- Use [Microsoft Purview DLP](https://learn.microsoft.com/en-us/purview/dlp-learn-about-dlp) to scan and block sensitive data in AI workflows.
- Configure [content filtering](https://learn.microsoft.com/en-us/azure/ai-services/content-safety/overview) to prevent leakage of sensitive information.
- Implement custom filters to detect and redact organization-specific sensitive data.
- For [Microsoft Copilot Studio](https://learn.microsoft.com/en-us/microsoft-copilot-studio/dlp-example-6), configure DLP policies for agents.

## Protect AI Artifacts from Compromise

- Store models and datasets in [Azure Blob Storage](https://learn.microsoft.com/en-us/azure/storage/blobs/storage-blob-overview) with [private endpoints](https://learn.microsoft.com/en-us/azure/storage/common/storage-private-endpoints).
- Apply [encryption at rest](https://learn.microsoft.com/en-us/azure/storage/common/storage-service-encryption) and [in transit](https://learn.microsoft.com/en-us/azure/storage/common/storage-require-secure-transfer).
- Enforce strict access policies and monitor for unauthorized access attempts.y

| ID    | Specification |
|-------|--------------|
|  S-R1  | **Microsoft Defender for Cloud**: The AI Landing Zone must align with MDC Recommendations by default. <br><br>Best Practice:<br><br> MDC can help [discover generative AI workloads](https://learn.microsoft.com/en-us/azure/defender-for-cloud/identify-ai-workload-model) and in [predeployment generative AI artifacts.](https://learn.microsoft.com/en-us/azure/defender-for-cloud/explore-ai-risk) Also [AI security posture management](https://learn.microsoft.com/en-us/azure/defender-for-cloud/ai-security-posture) in Microsoft Defender for Cloud can be used to automate detection and remediation of generative AI risks. Defender for Cloud provides a cost-effective approach for detecting configurations in your deployed resources that aren't secure. You should also enable [AI threat protection.](https://learn.microsoft.com/en-us/azure/defender-for-cloud/ai-threat-protection)|
|  S-R2  | **Microsoft Cloud Security Baseline**: The AI Landing Zone must comply with [Azure security baselines](https://learn.microsoft.com/en-us/security/benchmark/azure/security-baselines-overview) and follow [Azure Service Guides](https://learn.microsoft.com/en-us/azure/well-architected/service-guides/?product=popular) for security guidance.|
|  S-R3  | **Microsoft Purview:** The AI Landing Zone should provide guidance on how Purview can be leveraged to secure data in an AI landing zone.<br><br>Best Practice:<br><br> Sensitive data in AI workflows increases the risk of insider threats, data leaks and data oversharing. Use tools like [Microsoft Purview Insider Risk Management](https://learn.microsoft.com/en-us/purview/insider-risk-management)to assess enterprise-wide data risks and prioritize them based on data sensitivity. |
|  S-R4  | **Industry Security Standards for AI**: The AI Landing Zone should align with frameworks like [MITRE ATLAS](https://atlas.mitre.org/) and [OWASP Generative AI risk](https://genai.owasp.org/) for identifying risks across the architecture. |
|  S-R5  | **Monitor outputs and apply prompt shielding:** The AI Landing Zone should implement/guide on using AI Content Safety. <br><br>Best Practice:<br><br>Regularly inspect the data returned by AI models to detect and mitigate risks associated with malicious or unpredictable user prompts. Implement [Prompt Shields](https://learn.microsoft.com/en-us/azure/ai-services/content-safety/concepts/jailbreak-detection) to scan text for the risk of a user input attack on generative Al models. |
|  S-R6  | The AI Landing Zone must provide implementation and guidance on zero trust. |