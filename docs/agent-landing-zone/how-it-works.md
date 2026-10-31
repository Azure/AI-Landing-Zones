---
search:
  exclude: true
---

<span id="how-the-template-works"></span>
<span id="how-it-works"></span>

# Template guidance

The explanation of the template is now part of the
[Agent Landing Zone overview](index.md#how-the-template-works).
Use the guides below for the corresponding details.

<span id="how-to-read-deployment-settings"></span>
<span id="parameters-describe-the-environment"></span>

## Deployment settings

[Deployment settings](configuration.md#deployment-inputs) explains input
formats, generated files and environment bindings. Use
[Deployment choices](planning.md) to plan infrastructure and
[Network design](network-isolation.md) to prepare connectivity.

<span id="repository-boundaries"></span>
<span id="the-manifest-records-a-validated-combination"></span>

## Repositories and source versions

[Customize components](customize-components.md#choose-the-owner) identifies
the owning repositories. [Source pinning](build-your-own-app.md#source-pinning)
explains the manifest and application definition for customizations.

<span id="azureyaml-connects-azd-to-the-lifecycle"></span>
<span id="deployment-lifecycle"></span>
<span id="why-hosted-agents-need-image-preparation"></span>

## Deployment

Choose the [Bicep](deploy-full-stack.md#step-4-deploy) or
[Terraform](deploy-terraform-full-stack.md#step-4-deploy-the-application)
guide for execution. [Hosted agents](hosted-agents.md#image-and-deployment-handoff)
explains image preparation and reuse.

<span id="app-configuration-carries-runtime-settings"></span>
<span id="who-publishes-settings"></span>
<span id="how-applications-load-settings"></span>
<span id="secrets-and-environment-boundaries"></span>

## Application configuration

Use [configuration ownership](configuration.md#configuration-ownership-and-declarations)
for platform publication and [Application settings](application-settings.md)
for loading, effective values and reloads. See
[Environment boundaries](configuration.md#environment-boundaries) for separation.

<span id="from-understanding-to-deployment"></span>

## Next steps

Return to [Where do I start?](index.md#where-do-i-start) to choose your path.
