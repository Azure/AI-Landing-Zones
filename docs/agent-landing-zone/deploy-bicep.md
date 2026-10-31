---
search:
  exclude: true
---

<span id="bicep-deployment-guidance-has-moved"></span>

# Deploy with Bicep

Follow the guide for the required result:

- [Deploy infra only](deploy-infra-only.md): provision the foundation from
  Agent Landing Zone without building or deploying application images.
- [Deploy full stack](deploy-full-stack.md): provision the Agent
  foundation and deploy the Agent Application.

<a id="how-azd-uses-bicep"></a>
<a id="change-parameters"></a>
<a id="resource-naming"></a>
<a id="do-not-call-bicep-directly"></a>
<a id="reference"></a>
<a id="related-pages"></a>

For the Bicep entry point, lifecycle hooks, generated parameters and manifest
contract, read [How it works](how-it-works.md).
For supported settings and naming, use [Deployment settings](configuration.md) and
the [foundation parameter reference](../bicep/parameterization.md).
Run the supported lifecycle from the platform root: calling `infra/bicep/main.bicep`
directly omits required validation, configuration and application work.
