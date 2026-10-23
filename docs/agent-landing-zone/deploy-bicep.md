---
search:
  exclude: true
---

# Bicep deployment guidance has moved

This compatibility address directs existing links to the current runbooks.
Choose the procedure for your intended result:

- [Deploy infrastructure only](deploy-infra-only.md): choose the Agent
  foundation or independent AI Landing Zone Bicep source, then provision it.
- [Deploy the full stack](deploy-full-stack.md): provision the Agent
  foundation and deploy the Agent Application.

<a id="how-azd-uses-bicep"></a>
<a id="change-parameters"></a>
<a id="resource-naming"></a>
<a id="do-not-call-bicep-directly"></a>
<a id="reference"></a>
<a id="related-pages"></a>

For the Bicep entry point, lifecycle hooks, generated parameters and manifest
contract, read [How it works](how-it-works.md).
For supported settings and naming, use [Configuration](configuration.md) and
the [foundation parameter reference](../bicep/parameterization.md).
Run the supported lifecycle from the platform root: calling `infra/main.bicep`
directly omits required validation, configuration and application work.
