# ⚠️ Deprecation Notice

> **This Bicep implementation is legacy code and is no longer maintained.** The Bicep code has been moved to [bicep-ptn-aiml-landing-zone](https://github.com/Azure/bicep-ptn-aiml-landing-zone). For the Portal-based deployment, please refer to the `main` branch. This branch is preserved for historical reference only and will not receive updates or bug fixes.

# AI Landing Zones - Bicep Implementation

## Getting Started with Azure Developer CLI (azd)

If you still need to use this legacy Bicep implementation, you can deploy it using the [Azure Developer CLI (azd)](https://learn.microsoft.com/en-us/azure/developer/azure-developer-cli/overview).

### Prerequisites

- [Azure Developer CLI (azd)](https://learn.microsoft.com/en-us/azure/developer/azure-developer-cli/install-azd) installed
- [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli) installed
- An active Azure subscription

### Steps

1. **Initialize the project from this branch:**

   ```bash
   azd init -t Azure/AI-Landing-Zones -b legacy-bicep
   ```

2. **Authenticate with Azure:**

   ```bash
   azd auth login
   ```

3. **Provision the infrastructure:**

   ```bash
   azd provision
   ```

   You will be prompted to select an Azure subscription and a target region. The pre-provision hook will guide you through the Bicep parameter configuration before deployment begins.

> **Tip:** Review the sample parameter files in `bicep/infra/` (e.g., `sample.standalone.bicepparam`, `sample.foundry-minimal-no-vnet.bicepparam`) for different deployment scenarios.

---

For comprehensive documentation on using this Bicep template, including parameter reference, configuration guidance, and deployment examples, please use the official documentation site at [AI Landing Zone Docs Site](https://azure.github.io/AI-Landing-Zones/bicep/how-to-use/). If you are getting started, begin there.

