# Validated releases

Every Agent Landing Zone release is deployed live in Azure with both Bicep and
Terraform before it is offered for new deployments. The validated release is
the **Latest** release on
[GitHub Releases](https://github.com/Azure/agent-landing-zone/releases/latest).
Use it for new deployments.

<div class="runbook-diagram" markdown="1">

<div class="runbook-diagram__summary" markdown="1">

**A release becomes Latest only after a live, network-isolated deployment
passes with both providers.** The workflow publishes the evidence and promotes
the release. No release is promoted by hand.

</div>

[![A release is published as a pre-release after the offline checks pass. It is then deployed live with Bicep and then Terraform. When both pass, the evidence is attached and the release is promoted to Latest.](../media/runbooks/validated-releases.svg?v=3f1a9c2e7b40)](../media/runbooks/validated-releases.svg?v=3f1a9c2e7b40){: .runbook-diagram__image aria-label="Open full-size release validation diagram"}

[Open full-size diagram](../media/runbooks/validated-releases.svg?v=3f1a9c2e7b40){: .runbook-diagram__open}

</div>

## What validated means

A validated release meets every condition below:

- **Both providers.** The same release deploys successfully with Bicep and with
  Terraform. They are co-maintained implementations of the same platform.
- **Network isolated.** The landing zone runs with `NETWORK_ISOLATION=true`, so
  the data plane is reached only through private endpoints.
- **Documented commands.** The run uses the same `azd` commands an operator
  runs from the deployment guides. No landing zone resource is created or
patched by hand.
- **Working agent.** Deployment ends with an agent smoke test that invokes the
  deployed agent and checks its response.
- **Fresh environment.** Each run creates a new landing zone from scratch.
- **Public evidence.** The commands, step results and transcript are attached to
  the release.

## Release lifecycle

| Stage | What happens | Gate |
| --- | --- | --- |
| Pre-release | The release is tagged and published as a pre-release. | Offline checks pass in CI |
| Live validation | The release validation workflow deploys it with Bicep, then with Terraform. | Both providers pass |
| Latest | The workflow attaches the evidence and promotes the release. It is deployed again every day at 09:00 UTC. | A failed revalidation opens an issue |

The offline checks run on Linux and Windows. They cover Bicep build and lint,
Terraform `fmt`, `validate` and `test`, and the deployment and lifecycle hook
contract tests.

If either provider fails, the release stays a pre-release. The fix ships in a
new patch release, which goes through the same validation. The providers run
one after the other because both connect to the same shared hub network.

## Standard scenario

Both providers are validated with the same `azd` settings:

| Setting | Value |
| --- | --- |
| `NETWORK_ISOLATION` | `true` |
| `ORCHESTRATION_HOST` | `hosted` |
| `APPLICATION_MODE` | `conversational` |
| `BUILD_MODE` | `acr-task` |
| `DEPLOY_ACR_TASK_AGENT_POOL` | `true` |
| `DEPLOY_INGESTION_CONTAINER_APP` | `false` |
| `DEPLOY_JUMPBOX`, `DEPLOY_BASTION` | `false` |
| Region | `swedencentral` |

Every other parameter keeps its default. Instead of the landing zone jumpbox,
the workflow runs from a VNet-connected host that is peered with the landing
zone, as described in [Network design](network-isolation.md).

Other combinations are supported as documented, but only this scenario is
validated live for every release.

## What each run does

Each provider run follows the operator flow from the deployment guides:

1. Clones the release tag. For Terraform, selects the Terraform provider in
   `azure.yaml`.
2. Creates a new `azd` environment with the standard scenario.
3. Runs `azd provision`. Transient Azure errors are retried up to two times.
4. Connects the landing zone to the VNet-connected host and waits for private
   DNS to propagate.
5. Runs the post-provision configuration from inside the network.
6. Runs `azd deploy`. Its pre-deploy check verifies private network access and
   runs the agent smoke test.
7. Records the deployed resources and tears the environment down.

Teardown does not affect the result. A daily cleanup removes anything a run
leaves behind.

## Evidence

Each validated release carries its evidence:

- One line per provider under **Validation** in the release notes, linking the
  workflow run.
- A `validation-<tag>-<provider>-<run>.md` release asset per provider.

The evidence report contains:

- The result, region and timing of the run.
- Every step with its exit code and duration. Each step is marked as an
  operator command or as a harness step, which prepares the runner and is not
  part of the operator flow.
- The exact operator commands, so you can repeat the deployment.
- The full transcript.

Subscription, tenant and identity identifiers, and environment names, are
redacted before the evidence is published.