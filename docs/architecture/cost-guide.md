**AI Landing Zone - Cost Guide**

**Template:** AI Landing Zones - Standard Deployment

**Region:** East US (adjust for your target region)

**Azure Pricing Calculator Link:** [Azure Pricing Calculator Estimate](https://azure.com/e/e92e102172054654a13cdc1cada6cecc)

---

**🔗 Quick Start**

1. Open the **[Azure Pricing Calculator](https://azure.microsoft.com/en-us/pricing/calculator/)**
2. Follow the service configurations below
3. Add each service by clicking the "+" button
4. Configure using the specifications provided

---

**📋 Service Configuration Checklist**

## **1. Networking Services**

**Application Gateway**

- **Service:** Application Gateway
- **Region:** East US
- **Tier:** WAF V2
- **Gateway hours:** 730 hours/month (24/7)
- **Zone redundancy:** Yes (3 zones)
- **Capacity Units:** Auto-scaling (estimate 10 CU average)
- **Data processed:** 100 GB/month (adjust based on traffic)
- **Outbound data transfers:** 50 GB/month

**Estimated Cost:** ~$350-450/month

---

**Azure Firewall**

- **Service:** Azure Firewall
- **Region:** East US
- **SKU:** Standard
- **Deployment hours:** 730 hours/month (24/7)
- **Zone redundancy:** Yes (3 zones)
- **Data processed:** 500 GB/month
- **Threat Intelligence:** Standard (included)
- **Firewall Policy:** 1 policy

**Estimated Cost:** ~$400-500/month

---

**Azure Bastion**

- **Service:** Azure Bastion
- **Region:** East US
- **Tier:** Standard
- **Hours:** 730 hours/month
- **Outbound data transfer:** 10 GB/month

**Estimated Cost:** ~$140/month

---

**Public IP Addresses**

- **Service:** IP Addresses
- **Region:** East US
- **Type:** Standard Public IPv4
- **Zone redundancy:** Yes
- **Quantity:** 2 (Application Gateway + Firewall)
- **Hours per IP:** 730 hours/month

**Estimated Cost:** ~$7/month

---

**Private Endpoints**

- **Service:** Private Link / Private Endpoint
- **Region:** East US
- **Number of Private Endpoints:** 10
  - App Configuration: 1
  - API Management: 1 (if deployed)
  - Container Apps Environment: 1
  - Container Registry: 1
  - Storage (Blob): 1
  - Cosmos DB: 1
  - AI Search: 1
  - Key Vault: 1
  - AI Services: 1
  - OpenAI: 1
- **Inbound data processed:** 100 GB/month total
- **Outbound data processed:** 50 GB/month total

**Estimated Cost:** ~$73/month ($7.30 per endpoint)

---

**Private DNS Zones**

- **Service:** Azure DNS (Private DNS)
- **Number of zones:** 15 zones
  - privatelink.azure-api.net
  - privatelink.cognitiveservices.azure.com
  - privatelink.openai.azure.com
  - privatelink.services.ai.azure.com
  - privatelink.search.windows.net
  - privatelink.documents.azure.com
  - privatelink.blob.core.windows.net
  - privatelink.vaultcore.azure.net
  - privatelink.azconfig.io
  - privatelink.{region}.azurecontainerapps.io
  - privatelink.azurecr.io
  - privatelink.applicationinsights.azure.com
  - (additional zones as needed)
- **DNS queries:** 1 million queries/month

**Estimated Cost:** ~$9/month

---

**Virtual Network**

- **Service:** Virtual Network
- **Address space:** 192.168.0.0/22 (1024 IPs)
- **Subnets:** 9 subnets
- **Peering:** Hub-spoke peering (optional, if configured)
- **Data transfer (peering):** 100 GB/month (if using peering)

**Estimated Cost:** ~$0 (free) + peering costs if applicable (~$10/month)

---

**Network Security Groups**

- **Service:** Network Security Groups
- **Quantity:** 8 NSGs
  - Agent subnet NSG
  - Private Endpoints subnet NSG
  - Application Gateway subnet NSG
  - API Management subnet NSG
  - Container Apps Environment subnet NSG
  - Jumpbox subnet NSG
  - DevOps Build Agents subnet NSG
  - Azure Bastion subnet NSG

**Estimated Cost:** ~$0 (free)

---

## **2. Compute Services**

**Virtual Machine - Build VM (Linux)**

- **Service:** Virtual Machines
- **Region:** East US
- **Operating System:** Linux (Ubuntu 22.04)
- **Type:** Compute Optimized
- **Tier:** Standard
- **Instance:** F4s v2
    - 4 vCPUs
    - 8 GB RAM
- **Virtual Machines:** 1
- **Hours:** 730 hours/month (24/7) or less if auto-shutdown configured
- **Managed Disks:**
    - OS Disk: Standard SSD, 128 GB
    - Delete with VM: Yes
- **Availability Zone:** Zone 1

**Estimated Cost:** ~$120/month (24/7) or ~$60/month (12 hours/day)

---

**Virtual Machine - Jump VM (Windows)**

- **Service:** Virtual Machines
- **Region:** East US
- **Operating System:** Windows Server 2022 Datacenter: Azure Edition
- **Type:** General Purpose
- **Tier:** Standard
- **Instance:** D4as v5
    - 4 vCPUs
    - 16 GB RAM
- **Virtual Machines:** 1
- **Hours:** 730 hours/month (24/7) or less if auto-shutdown configured
- **Managed Disks:**
    - OS Disk: Standard SSD, 128 GB
- **Availability Zone:** Zone 1
- **License:** Windows Server license included

**Estimated Cost:** ~$180/month (24/7) or ~$90/month (12 hours/day)

---

**Azure Container Apps**

- **Service:** Container Apps
- **Region:** East US
- **Workload Profile:** Dedicated (D4)
  - 4 vCPUs, 16 GB RAM per instance
  - Minimum instances: 1
  - Maximum instances: 3
- **Average instances running:** 2
- **Hours:** 730 hours/month per instance
- **Total vCore hours:** 2 instances × 4 vCPUs × 730 = 5,840 vCore-hours
- **HTTP requests:** 1 million requests/month

**Estimated Cost:** ~$280-350/month (depends on scaling)

---

**Azure Container Registry**

- **Service:** Container Registry
- **Region:** East US
- **SKU:** Premium
- **Storage:** 100 GB
- **Build vCPU minutes:** 500 minutes/month
- **Geo-replication:** None (1 region)
- **Data transfer out:** 10 GB/month

**Estimated Cost:** ~$40/month

---

## **3. AI & Cognitive Services**

**Azure AI Foundry / AI Services**

- **Service:** Azure AI Services (multi-service account)
- **Region:** East US
- **API Calls:** Variable (usage-based)
- **Estimate baseline:** 100,000 API calls/month

**Estimated Cost:** ~$50-200/month (highly variable based on usage)

---

**Azure OpenAI Service**

- **Service:** Azure OpenAI Service
- **Region:** East US
- **Model:** GPT-4o (latest)
- **Input tokens:** 1 million tokens/month
- **Output tokens:** 500,000 tokens/month
- **Model:** GPT-4o-mini (for lighter tasks)
- **Input tokens:** 5 million tokens/month
- **Output tokens:** 2 million tokens/month

**Estimated Cost:** ~$100-500/month (depends on model and usage)

> **Note:** Pricing varies significantly by model. Use Azure OpenAI pricing page for accurate estimates.

---

**Azure AI Search**

- **Service:** Azure AI Search (formerly Cognitive Search)
- **Region:** East US
- **Tier:** Standard (S1)
    - 25 GB storage
    - 1 replica
   - 1 partition
- **Hours:** 730 hours/month
- **Search queries:** 100,000 queries/month
- **Indexing:** 10 GB indexed data

**Estimated Cost:** ~$250/month

**Alternative - Basic Tier:** ~$75/month (for dev/test)

---

## **4. Data Services**

**Azure Cosmos DB**

- **Service:** Azure Cosmos DB
- **Region:** East US
- **API:** SQL (Core) API
- **Capacity mode:** Provisioned throughput
- **Throughput:** 1,000 RU/s (Request Units per second)
- **Storage:** 50 GB
- **Backup:** Continuous backup (7 days)
- **Multi-region writes:** No
- **Availability zones:** Yes

**Estimated Cost:** ~$175/month

**Alternative - Serverless:** ~$25-100/month (for dev/test, usage-based)

---

**Storage Account**

- **Service:** Storage Accounts
- **Region:** East US
- **Performance:** Standard
- **Redundancy:** Locally-redundant storage (LRS)
- **Account kind:** StorageV2 (general purpose v2)
- **Tier:** Hot
- **Capacity:** 100 GB
    - Blob storage: 80 GB
   - File storage: 20 GB
- **Write operations:** 100,000 operations/month
- **Read operations:** 200,000 operations/month
- **Data retrieval:** 10 GB/month

**Estimated Cost:** ~$5-10/month

---

**Azure Key Vault**

- **Service:** Key Vault
- **Region:** East US
- **Tier:** Standard
- **Secrets:** 50 secrets
- **Certificate operations:** 100 operations/month
- **Key operations:** 10,000 operations/month
- **Advanced threat protection:** No

**Estimated Cost:** ~$1-3/month

---

**App Configuration**

- **Service:** App Configuration
- **Region:** East US
- **Tier:** Standard
- **Requests:** 100,000 requests/month
- **Storage:** 1 GB

**Estimated Cost:** ~$1-2/month

**Alternative - Free Tier:** $0/month (limited to 1,000 requests/day)

---

## **5. Monitoring & Observability**

**Log Analytics Workspace**

- **Service:** Azure Monitor (Log Analytics)
- **Region:** East US
- **Data ingestion:** 50 GB/month
- **Data retention:** 30 days (default)
- **Commitment tier:** Pay-as-you-go

**Estimated Cost:** ~$125/month

---

**Application Insights**

- **Service:** Application Insights
- **Region:** East US
- **Data ingestion:** 20 GB/month (included in Log Analytics above)
- **Web tests:** 5 multi-step web tests
- **Availability tests runs:** 10,000 runs/month

**Estimated Cost:** ~$10/month (web tests, data covered by Log Analytics)

---

## **6. Optional Services**

****API Management** (if enabled in deployToggles)**

- **Service:** API Management
- **Region:** East US
- **Tier:** Premium
- **Units:** 3 (for zone redundancy)
- **Hours:** 730 hours/month
- **API calls:** 1 million calls/month
- **Cache:** 1 GB

**Estimated Cost:** ~$2,700/month (Premium tier)

**Alternative - Developer Tier:** ~$50/month (for dev/test, no SLA)

---

****Bing Search** (Grounding with Bing)**

- **Service:** Bing Search API
- **Tier:** S1
- **Transactions:** 10,000 transactions/month

**Estimated Cost:** ~$7/month

---

**💰 TOTAL COST SUMMARY**

**Standard Deployment (All Services Enabled)**

| Category | Monthly Cost (USD) |
|----------|-------------------|
| **Networking** | $980 - $1,180 |
| - Application Gateway | $350 - $450 |
| - Azure Firewall | $400 - $500 |
| - Azure Bastion | $140 |
| - Public IPs | $7 |
| - Private Endpoints | $73 |
| - Private DNS Zones | $9 |
| **Compute** | $440 - $650 |
| - Build VM (Linux) | $120 |
| - Jump VM (Windows) | $180 |
| - Container Apps | $100 - $300 |
| - Container Registry | $40 |
| **AI Services** | $400 - $950 |
| - Azure OpenAI | $100 - $500 |
| - AI Search | $250 |
| - AI Services | $50 - $200 |
| **Data** | $180 - $190 |
| - Cosmos DB | $175 |
| - Storage Account | $5 - $10 |
| - Key Vault | $1 - $3 |
| - App Configuration | $1 - $2 |
| **Monitoring** | $135 |
| - Log Analytics | $125 |
| - Application Insights | $10 |
| **Optional** | $0 - $2,707 |
| - API Management (if enabled) | $0 - $2,700 |
| - Bing Search | $7 |
| | |
| **TOTAL (without API Management)** | **$2,135 - $3,105/month** |
| **TOTAL (with API Management)** | **$4,835 - $5,812/month** |

---

**🎯 COST OPTIMIZATION SCENARIOS**

**Scenario 1: Development/Test Environment**
Estimated savings: **50-60% reduction**

**Changes:**

- Disable Azure Firewall: **-$400/month**
- Disable Azure Bastion: **-$140/month**
- Disable Jump VM: **-$180/month**
- Use AI Search Basic tier: **-$175/month**
- Use Cosmos DB Serverless: **-$100/month**
- Auto-shutdown Build VM (12h/day): **-$60/month**
- Reduce Container Apps scaling: **-$100/month**

**New Total:** ~$980 - $1,350/month

---

**Scenario 2: Minimal Production (No App Gateway/Firewall)**
Estimated savings: **40% reduction**

**Changes:**

- Disable Application Gateway: **-$400/month**
- Disable Azure Firewall: **-$400/month**
- Use Azure Front Door instead (if needed for WAF)

**New Total:** ~$1,335 - $1,925/month

---

**Scenario 3: Maximum Cost Optimization**

Estimated savings: **70% reduction**

**Changes:**

- All from Scenario 1
- Disable Container Apps (use Azure Container Instances): **-$200/month**
- Use consumption-based AI services only: **-$200/month**
- Reduce monitoring data retention to 7 days: **-$75/month**

**New Total:** ~$640 - $900/month

---

**📊 VARIABLE COSTS TO MONITOR**

These costs are **usage-based** and can vary significantly:

1. **Azure OpenAI**: Depends on tokens processed (can range from $10 to $5,000+/month)
2. **AI Services API calls**: Pay per transaction
3. **Azure AI Search queries**: Included in tier pricing, but indexing costs vary
4. **Cosmos DB**: RU/s consumption can spike with traffic
5. **Data egress**: Outbound data transfer charges (especially cross-region)
6. **Log Analytics**: Data ingestion over 5GB/day gets expensive
7. **Container Apps scaling**: Auto-scaling can increase costs during peak times

---

**🛠️ HOW TO USE THIS GUIDE**

**Step-by-Step:**

1. **Open Calculator**: Go to https://azure.microsoft.com/en-us/pricing/calculator/

2. **Select Region**: Change to your target deployment region (prices vary by region)

3. **Add Services**: Use the search box to find each service and click "+"

4. **Configure**: For each service, use the specifications in this guide

5. **Adjust**: Modify quantities based on your specific needs

6. **Export/Save**: Click "Export" to save as Excel or click "Save" to generate a shareable link

7. **Review Monthly**: Update estimates as your usage patterns become clear

---

**📌 IMPORTANT NOTES**

- **Regional Pricing Varies**: Costs shown are for East US. Some regions cost 10-30% more.
- **Currency**: All prices in USD. Use Azure's currency converter for other currencies.
- **Reserved Instances**: VMs and other compute can save 30-70% with 1-3 year reservations.
- **Azure Hybrid Benefit**: Save up to 40% on Windows VMs if you have existing licenses.
- **Dev/Test Pricing**: Special pricing for MSDN subscribers.
- **Free Services**: Some services have free tiers (App Config, DNS queries, etc.).
- **Data Transfer**: Within the same region is typically free; cross-region and outbound have costs.

---

**🔗 USEFUL LINKS**

- **Azure Pricing Calculator**: https://azure.microsoft.com/pricing/calculator/
- **Azure OpenAI Pricing**: https://azure.microsoft.com/pricing/details/cognitive-services/openai-service/
- **Azure AI Services Pricing**: https://azure.microsoft.com/pricing/details/cognitive-services/
- **Azure Cost Management**: https://portal.azure.com/#blade/Microsoft_Azure_CostManagement/Menu/overview
- **Azure TCO Calculator**: https://azure.microsoft.com/pricing/tco/calculator/
- **Azure Architecture Center**: https://learn.microsoft.com/azure/architecture/

---

**📞 NEED HELP?**

- Review the Bicep template: `bicep/infra/sample.main.bicepparam` to see which services are enabled
- Adjust `deployToggles` to disable expensive services you don't need
- Contact Azure Support for EA/CSP pricing discussions
- Use Azure Cost Management after deployment for real-time cost tracking

---

**Last Updated:** November 5, 2025  
**Template Version:** Based on Azure AI Landing Zones main.bicep v1.0
