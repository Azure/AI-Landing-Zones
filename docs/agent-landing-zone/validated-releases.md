# Validated releases

The validated Agent Landing Zone release is the **Latest** release on
[GitHub Releases](https://github.com/Azure/agent-landing-zone/releases/latest).
Use it for new deployments.

## How a release becomes Latest

1. Every release is first published as a **pre-release**. Pre-releases have
   passed the offline checks (Bicep build and lint, Terraform `fmt`, `validate`
   and `test`, deployment and hook contracts) but not yet a live deployment.
2. The release validation workflow deploys the release live in Azure with
   **Bicep** and then with **Terraform**, using the standard scenario below. Each
   run provisions a fresh landing zone, runs the documented operator commands
   (`azd provision`, `azd deploy` and an agent smoke test) and tears the
   environment down.
3. When both providers pass, the workflow attaches the evidence to the release
   and promotes it from pre-release to Latest. If either provider fails, the
   release stays a pre-release and the fix ships in a new patch release that
   goes through the same validation.

The Latest release is also revalidated every week. A failure is tracked as an
issue in the repository and fixed in a new patch release.

## Standard scenario

Both providers are validated with the same `azd` settings:

| Setting | Value |
| --- | --- |
| `NETWORK_ISOLATION` | `true` |
| `ORCHESTRATION_HOST` | `hosted` |
| `APPLICATION_MODE` | `conversational` |
| `BUILD_MODE` | `acr-task`, with the ACR Tasks agent pool |
| `DEPLOY_INGESTION_CONTAINER_APP` | `false` |
| `DEPLOY_JUMPBOX`, `DEPLOY_BASTION` | `false` |
| Region | `swedencentral` |

Every other parameter keeps its default. Deployment and post-provision
configuration run from a VNet-connected host connected to the landing zone
through VNet peering, as described in [Network design](network-isolation.md).
Other combinations are supported as documented, but only this scenario is
validated live for every release.

## Evidence

Each validated release carries its evidence:

- One line per provider under **Validation** in the release notes, linking the
  workflow run.
- A `validation-<tag>-<provider>-<run>.md` release asset per provider with the
  commands that ran, the step results and the sanitized transcript.

Subscription, tenant and identity identifiers are redacted before the evidence
is published.
