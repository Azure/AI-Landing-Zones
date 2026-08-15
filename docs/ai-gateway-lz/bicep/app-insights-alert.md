# 🔔 AI Gateway — Application Insights Alerting

Provisions **Azure Monitor alert rules** on the gateway's `AI Gateway Alert` custom metric
(namespace `ai-gateway-alerts`) emitted by the [`raise-alert-events`](../modules/apim/policies/frag-raise-alert-events.xml)
APIM policy fragment, plus an **email Action Group** that notifies your team when a rule fires.

One alert rule is created per entry in the `alerts` parameter, each **filtered by the `alertType`
dimension** and wired to a single shared action group. This turns the gateway's opt-in alert metrics
into actionable notifications.

## Two alerting modes (`alertMode`)

| Mode | Resource | Availability | Use when |
|------|----------|--------------|----------|
| **`logQuery`** (default) | `Microsoft.Insights/scheduledQueryRules` (log search alert on the `customMetrics` table) | **Immediate** — customMetrics telemetry is written to the App Insights **Logs** the moment the gateway emits it. | Always safe to deploy up front, including on a fresh hub before any traffic. |
| `metric` | `Microsoft.Insights/metricAlerts` (on the `ai-gateway-alerts` namespace) | **Delayed** — the pre-aggregated custom metric **namespace only registers *after* the metric has first been emitted** (minutes), and until then it is not visible under App Insights → Metrics/Alerts. | Once the namespace has registered; slightly lower latency/cost than log queries. |

> **Why `logQuery` is the default:** an Azure Monitor **metric** alert can only target a metric
> namespace that already exists. APIM `emit-metric` custom metrics land in the `customMetrics` **log**
> table immediately, but the pre-aggregated **metric** namespace is created lazily on first emission —
> so a metric alert can't reliably be created before any traffic has flowed. The log-query mode reads
> the same telemetry from Logs and works right away. Switch to `metric` once
> `az monitor metrics list-namespaces` shows `ai-gateway-alerts`.

> **Background:** the alerting model (one metric, many alert types, opt-in per access contract) is
> described in [Throttling & Critical Event Alerting](../../../guides/throttling-events-handling.md)
> and [Resiliency Guide — Alerting on Critical Events](../../../guides/resiliency-guide.md#5-alerting-on-critical-events).

## What gets deployed

| Resource | Purpose |
|----------|---------|
| `Microsoft.Insights/actionGroups` | Email notification target (common alert schema — the email includes the rule description and the fired dimension values). |
| `Microsoft.Insights/scheduledQueryRules` **or** `Microsoft.Insights/metricAlerts` (one per `alerts` entry) | Alert on `AI Gateway Alert`, filtered by `alertType` (and optionally `productName`). Which type is created depends on `alertMode`. |

The default `alerts` create **throttling**, **quota-exceeded**, and **backend-failure** rules. Extend the array with
`auth-failure`, `content-safety`, or `pii-failure` entries (only meaningful once those categories are
opted-in on the relevant access contracts).

## Prerequisites

- A deployed Citadel Governance Hub (APIM emitting the alert metric to an Application Insights component).
- The Application Insights component name. The hub creates one named `appi-apim-<token>` by default; the
  APIM `appinsights-logger` points at it.
- Permission to create alert rules / action groups in the App Insights resource group.

## Parameters

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `appInsights` | ✅ | — | `{ subscriptionId, resourceGroupName, name }` of the App Insights component. |
| `alertEmailAddress` | ✅ | — | Primary email that receives notifications. |
| `alertResourceGroupName` | | App Insights RG | RG to create the alert rules + action group in. |
| `additionalEmailReceivers` | | `[]` | Extra recipients: `[{ name, email }]`. |
| `metricNamespace` | | `ai-gateway-alerts` | Custom metric namespace (matches the fragment). |
| `metricName` | | `AI Gateway Alert` | Custom metric name (matches the fragment). |
| `productNameFilter` | | `''` | Scope **all** rules to one access contract. Use the APIM product **display name** (space-separated, e.g. `LLM Ops AlertProbe DEV`) — matches the `productName` dimension, **not** the hyphenated product id. |
| `alertMode` | | `logQuery` | `logQuery` = scheduled query (log search) alerts on `customMetrics` (immediate). `metric` = metric alerts on the `ai-gateway-alerts` namespace (after it registers). |
| `namePrefix` | | `ai-gateway` | Prefix for the action group + rule names. |
| `actionGroupShortName` | | `aigwalerts` | Action group short name (≤ 12 chars). |
| `alertsEnabled` | | `true` | Enable rules on creation. |
| `alerts` | | throttling + quota-exceeded + backend-failure | Array of rule definitions (see below). |

Each `alerts` entry:

```bicep
{
  name: 'throttling'          // unique suffix for the rule name
  alertType: 'throttling'     // throttling | backend-failure | auth-failure | content-safety | pii-failure
  severity: 2                 // 0 Critical .. 4 Verbose
  operator: 'GreaterThan'
  threshold: 10               // event count over the window
  timeAggregation: 'Total'
  windowSize: 'PT5M'
  evaluationFrequency: 'PT1M'
  description: 'Included verbatim in the alert email.'
}
```

> **Note (`logQuery` mode):** the rule runs a KQL query over `customMetrics` (`sum(valueSum)` of the
> `AI Gateway Alert` events, filtered by `alertType`) — no dependency on the metric namespace, so it
> works immediately. **Note (`metric` mode):** the metric alert uses `skipMetricValidation: true` so it
> deploys even before the custom metric namespace registers, but it only starts **evaluating** once the
> namespace exists (which happens after the first emission).

## Deploy

```bash
# 1) Fill in bicepparam values (or export the azd env vars it reads).
#    Required: appInsights.name, appInsights.resourceGroupName, alertEmailAddress.

# 2) Deploy at subscription scope.
az deployment sub create \
  --name ai-gateway-alerts \
  --location <region> \
  --template-file bicep/infra/app-insights-alert/main.bicep \
  --parameters bicep/infra/app-insights-alert/main.bicepparam
```

## Validate

Trigger and verify an alert end-to-end with the
[citadel-alerting-tests.ipynb](../../../validation/citadel-alerting-tests.ipynb) notebook: it deploys a
restrictive access contract, bursts load to force `429` throttling **and** exhausts the token-quota to
force `403` (`quota-exceeded`), deploys these alert rules, and confirms the `AI Gateway Alert` metric +
alert rule state.