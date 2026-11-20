# Validated releases

Before we recommend a release for new deployments, we deploy it for real in
Azure, end to end, with both Bicep and Terraform. Only a release that passes
that run becomes **Latest** on
[GitHub Releases](https://github.com/Azure/agent-landing-zone/releases/latest).
If you are starting a new deployment, that is the one to use.

<div class="runbook-diagram" markdown="1">

<div class="runbook-diagram__summary" markdown="1">

**A release becomes Latest only after a live, network-isolated deployment
passes with both Bicep and Terraform.** The evidence is attached to the
release, and the promotion is automatic.

</div>

[![A release is published as a pre-release after the offline checks pass. It is then deployed live with Bicep and then Terraform. When both pass, the evidence is attached and the release is promoted to Latest.](../media/runbooks/validated-releases.svg?v=3f1a9c2e7b40)](../media/runbooks/validated-releases.svg?v=3f1a9c2e7b40){: .runbook-diagram__image aria-label="Open full-size release validation diagram"}

[Open full-size diagram](../media/runbooks/validated-releases.svg?v=3f1a9c2e7b40){: .runbook-diagram__open}

</div>

## What validated means

Passing CI is a good start, but it does not prove that a landing zone actually
comes up in a real subscription. That is why every release also goes through a
live deployment that looks as close as possible to what you would run
yourself.

Each run creates a brand-new, network-isolated landing zone, where the data
plane is reachable only through private endpoints. It uses the same `azd`
commands the deployment guides ask you to run, and nothing in the landing zone
is created or patched by hand. The run only counts once the deployed agent
answers a smoke test.

We do this twice, once with Bicep and once with Terraform. They are two
implementations of the same platform, so a release is validated only when
both pass. Everything the run did is attached to the release, so you can check
it yourself.

## How a release reaches Latest

Every release starts as a pre-release. It is tagged and published once the
offline checks pass in CI. Those checks run on Linux and Windows and cover
Bicep build and lint, Terraform `fmt`, `validate` and `test`, and the contract
tests for the deployment and lifecycle hooks.

Next, the release validation workflow deploys it live, first with Bicep and
then with Terraform. The two runs go one after the other because both connect
to the same shared hub network.

When both pass, the workflow attaches the evidence and promotes the release to
Latest. Nobody promotes a release by hand. If either provider fails, the
release stays a pre-release, and the fix ships in a new patch release that
goes through the same process.

Validation does not stop at promotion. The Latest release is deployed again
every day at 09:00 UTC, which catches problems introduced by changes on the
Azure side. If a daily run fails, the workflow opens an issue.

## The scenario we validate

Every release is validated with the same settings, so results can be compared
from one release to the next.

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

Everything else keeps its default. Instead of the landing zone jumpbox, the
run uses a VNet-connected host that is peered with the landing zone, as
described in [Network design](network-isolation.md).

The other combinations described in this documentation are supported, but
this is the one we deploy live for every release.

## What happens in a run

Each provider run follows the same path an operator would. It clones the
release tag, switches `azure.yaml` to the Terraform provider when needed,
creates a fresh `azd` environment with the scenario above and runs
`azd provision`. Transient Azure errors are retried up to two times.

Once the infrastructure is up, the run connects the landing zone to the
validation host, waits for private DNS to propagate and runs the
post-provision configuration from inside the network. It then runs
`azd deploy`, whose pre-deploy check confirms private network access and runs
the agent smoke test.

Finally, the run records what was deployed and tears the environment down.
Teardown does not affect the result, and a daily cleanup removes anything a
run leaves behind.

## The evidence

You can find the evidence for each validated release in two places. The
**Validation** section of the release notes has one line per provider that
links to the workflow run. Each provider also attaches a
`validation-<tag>-<provider>-<run>.md` report to the release.

The report shows exactly what happened, so you can repeat it. It includes the
result, region and timing, every step with its exit code and duration, and the
exact operator commands. Steps that only prepare the runner are marked as
harness steps, so you can tell them apart from what an operator runs. The full
transcript is at the end.

Subscription, tenant and identity identifiers, and environment names, are
redacted before anything is published.