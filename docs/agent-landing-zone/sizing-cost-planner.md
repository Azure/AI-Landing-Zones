---
title: Sizing & cost planner
hide:
  - toc
---

<div id="agent-lz-planner" data-catalog-url="../../data/planner/prices.json">
  <h1 id="main">Sizing &amp; cost planner</h1>
  <p class="intro">Start with the isolated architecture. Adjust your workload and resources to see their monthly cost.</p>
  <noscript><p class="warning">The interactive planner needs JavaScript. Enable it and reload. The <a href="../planning/">deployment choices</a> and <a href="https://azure.microsoft.com/pricing/calculator/">Azure Pricing Calculator</a> remain available without this planner.</p></noscript>
  <div id="load-status" role="status">Loading the public price snapshot...</div>
  <div id="planner" hidden>
    <div class="scenario-bar">
      <label>Region<select id="region" data-field="region"></select></label>
      <div class="scenario-note"><span id="network-isolation">Network isolated &middot; standalone &middot; hosted-no-panel</span><small id="configuration-status">Starting configuration</small></div>
      <button type="button" class="secondary" id="reset">Reset to defaults</button>
    </div>
    <div id="stale-warning" class="warning" hidden></div>
    <div id="scenario-message" class="notice" role="status" hidden></div>
    <div class="live-summary" aria-label="Live scenario summary">
      <div class="current-total"><span class="live-label">Estimated monthly cost &middot; USD</span><strong id="live-total" aria-live="polite" aria-atomic="true"></strong><small id="live-scope"></small></div>
      <a id="starting-point-note" href="#cost-drivers">What drives this cost?</a>
      <a id="cost-change-link" href="#cost-change-summary" hidden>Why the cost changed</a>
    </div>
    <div id="cost-change-summary" hidden><span id="live-delta"></span><small>Already included in the total, not an extra charge.</small><ul id="cost-change-items"></ul></div>
    <p class="fine planner-scope">Estimate only. Workload and build schedules are hypothetical. Nothing is deployed. <a href="#coverage">Assumptions &amp; price sources</a></p>
    <details id="cost-drivers" class="cost-drivers">
      <summary>Largest monthly costs</summary>
      <p class="fine" id="cost-driver-note"></p>
      <p class="fine" id="build-budget-note"></p>
      <ul id="cost-driver-items"></ul>
    </details>
    <p id="sizing-alert" class="warning" hidden></p>
    <details id="workload" class="workload">
      <summary><span><strong>Adjust workload</strong></span><span id="workload-summary"></span><span class="disclosure" aria-hidden="true">+</span></summary>
      <div class="workload-body">
        <p>These inputs describe demand, not what the deployment guarantees. Resource choices use the isolated standalone reference, with regional differences and billing hypotheses described below. Network isolation stays enabled. Changing demand does not automatically resize resources.</p>
        <div class="input-grid">
          <label>Active users / business day<input type="number" min="0" max="1000000" step="1" data-field="users"></label>
          <label>Turns / user / business day<input type="number" min="0" max="10000" step="1" data-field="turns"></label>
          <label>Business days / month<input type="number" min="1" max="31" step="1" data-field="days"></label>
          <label>Peak concurrent turns<input type="number" min="0" max="1000000" step="1" data-field="concurrency"></label>
          <label>Model calls / turn, average<input type="number" min="0" max="100" step="0.1" data-field="calls"></label>
          <label>Input tokens / model call<input type="number" min="0" max="10000000" step="1" data-field="inputTokens"></label>
          <label>Output tokens / model call<input type="number" min="0" max="10000000" step="1" data-field="outputTokens"></label>
          <label>Allocated hours / month<input type="number" min="0" max="744" step="1" data-field="hours"></label>
          <label>Mean turn duration, seconds<input type="number" min="1" max="3600" step="1" data-field="turnSeconds"></label>
          <label>Search queries / turn, average<input type="number" min="0" max="100" step="0.1" data-field="searchQueries"></label>
          <label>Application index GB, hypothesis<input type="number" min="0" max="1000000" step="0.1" data-field="indexGB"></label>
          <label>Vector index GB, hypothesis<input type="number" min="0" max="1000000" step="0.1" data-field="vectorGB"></label>
        </div>
        <div class="workload-math" id="workload-math"></div>
        <p class="fine">Peak planning rate assumes sustained concurrency at the entered mean turn duration. Calls and queries are distributed over that duration. This is a demand hypothesis, not a burst limit or measured performance. Index and vector footprints are entered separately from corpus bytes. Resource capacity is never resized automatically.</p>
        <div class="presets" role="group" aria-label="Illustrative workload presets"><span>Try a workload:</span><button type="button" data-preset="small">Smaller example</button><button type="button" data-preset="reference">Reference example</button><button type="button" data-preset="larger">Larger example</button></div>
        <p class="fine">Presets change demand and its assessment, not allocated infrastructure. They are not validated Low / Medium / High capacity profiles.</p>
      </div>
    </details>
    <div id="input-error" class="warning" role="alert" hidden></div>
    <section class="planner-layout" aria-labelledby="architecture-title">
      <div class="resource-ledger">
        <div class="ledger-heading"><h2 id="architecture-title">Adjust architecture</h2></div>
        <p class="fine">Open a capability, then a resource to change it or read its sizing guidance. Options not deployed by default start at 0. Where supported, set an included resource's quantity to 0 to exclude its new allocation and linked costs. Keep replicas and partitions at valid values for an included service.</p>
        <p class="fine" id="excluded-scope-note" hidden></p>
        <div class="resource-tools">
          <label>Find a resource<input type="search" id="resource-search" placeholder="For example, API Management or Cosmos DB"></label>
          <label>Show resources<select id="resource-filter"><option value="all">All resources</option><option value="included">Included in this scenario</option><option value="optional">Optional architecture resources</option><option value="unpriced">Your plan prices</option><option value="changed">Changed vs. starting point</option></select></label>
          <button type="button" id="clear-filters">Clear filters</button>
        </div>
        <p id="resource-count" class="fine" role="status"></p>
        <div id="no-resources" class="notice" hidden>No resources match. Clear the search or filters to return to the complete inventory.</div>
        <div id="capabilities"></div>
      </div>
    </section>
    <details id="decision" class="planner-panel decision-section">
      <summary><h2 id="decision-title">Check sizing</h2><span id="live-sizing"></span><span class="disclosure" aria-hidden="true">+</span></summary>
      <div class="panel-body">
      <details id="sizing-guidance" class="assessment-details">
        <summary>How to size this architecture</summary>
        <span id="sizing-and-capacity"></span><span id="establish-a-workload-baseline"></span>
        <h3 id="workload-baseline">Establish the workload</h3>
        <p>Start with peak concurrent turns, turn duration, model/tool calls, input/output tokens, corpus and vector-index size, update rate and ingestion deadlines. Users alone do not determine capacity. Measure ingestion alongside interactive traffic, not only in isolation.</p>
        <h3 id="models-and-quota">Models and quota</h3>
        <p>The reference deploys <code>gpt-5-nano</code> and <code>text-embedding-3-large</code>, each with <code>sku.capacity=100</code>. This allocates model-specific quota, not 100 users or a prepaid token budget. Check actual TPM/RPM, retries and regional availability. More application replicas do not increase model quota. <a href="https://learn.microsoft.com/azure/ai-services/openai/quotas-limits" target="_blank" rel="noopener">Model limits &#8599;</a></p>
        <p>The current embedding default is <code>text-embedding-3-large</code> version <code>1</code>, <code>GlobalStandard</code>, declared capacity <code>100</code>; the empty-list foundation fallback keeps capacity <code>10</code>. Model/deployment names, API versions and vector dimensions are unchanged. <a href="https://learn.microsoft.com/azure/foundry/foundry-models/concepts/models-sold-directly-by-azure-region-availability#global-standard" target="_blank" rel="noopener">Global Standard availability &#8599;</a> confirms model support. Global deployment processing may occur outside the resource region. If regional processing is required, explicitly set the embedding entry's <code>sku.name</code> to <code>Standard</code> and verify regional availability and quota. The separate embedding cost row retains its existing regional price meter as a budgeting proxy, not a verified Global Standard quote; confirm the applicable price before deployment. The pinned source links below remain historical reference inputs, not evidence of the current embedding deployment type.</p>
        <h3 id="search-capacity">Search capacity</h3>
        <p>Application Search and Foundry backing Search are separate services, each initially S1 with one replica and one partition. Partitions address index/vector footprint and growth. Replicas address retrieval/indexing load and availability. One replica is not a high-availability design. Validate limits for the service's region and creation date. Private native ingestion also needs approved, ready shared private links, not just more Search capacity.</p>
        <p>Standard S1/S2 supports 1, 2, 3, 4, 6 or 12 partitions, up to 12 replicas and at most 36 search units. New Basic services in the offered regions support 1, 2 or 3 partitions, up to 3 replicas and at most 9 search units. The controls and saved/shared scenario validation enforce these <a href="https://learn.microsoft.com/azure/search/search-capacity-planning#partition-and-replica-combinations" target="_blank" rel="noopener">documented combinations</a>. Other capacity, availability and workload checks still apply.</p>
        <p>Search SKU and counts are infrastructure literals, not root environment scaling flags. Persist changes in reviewed Bicep/Terraform source. Portal-only changes can be reset by provisioning. <code>aiSearchResourceId</code> reuses Foundry's backing service, not Application Search.</p>
        <h3 id="application-hosting">Host the components separately</h3>
        <p>The hosted orchestrator starts at 2 CPU / 4 GiB. Its child <code>hosted-agent/azure.yaml</code> declares literal sizes: changing provisioning environment variables alone does not resize it. Review the child definition and deployment metadata, then deploy a compatible agent version.</p>
        <p>The frontend starts at 0.5 CPU / 1 GiB and one minimum/maximum replica. Optional application ingestion starts at 1 CPU / 3 GiB. They share the D4 Container Apps profile, whose node bounds start at 0 to 1. Minimum app replicas can retain a billable node. Raising app replicas does not raise the node ceiling or resize the Foundry host.</p>
        <h3 id="data-builds-and-observability">Data and operations</h3>
        <p>Budget Foundry backing Cosmos separately from optional application Cosmos. Verify actual throughput offers, data/index size, retention and backup policy. Build memory and parallel jobs size the build pool, not chat traffic. Registry storage persists when that pool is scaled to zero. Set logging retention/sampling from investigation and compliance needs, without capturing message content merely to size the system.</p>
        <span id="validate-the-initial-capacity"></span>
        <h3 id="capacity-validation">Validate the bottleneck</h3>
        <p>Use representative nonproduction tests with response-time, error-rate, ingestion-delay and concurrency targets. Include real tools, document sizes, authentication and document allow/deny behavior. Traces distinguish model throttling, Search limits, tool waits and host CPU/memory pressure. Compare before and after a capacity change.</p>
        <span id="turn-the-result-into-a-cost-plan"></span>
        <h3 id="capacity-and-cost">Apply reviewed settings</h3>
        <p>Keep platform inputs in the root <code>main.parameters.json</code>. The tracked Bicep seed <code>infra/bicep/main.parameters.json</code> is regenerated. Terraform inputs and its preflight-only diagnostic <code>infra/shared/main.parameters.json</code> are generated and ignored. Never commit resolved environment values. Verify the composed deployment, component versions and actual metrics rather than treating placeholders as measured capacity. Preserve Bicep/Terraform parity and use the <a href="../deploy-infra-only/">infrastructure</a> or <a href="../deploy-full-stack/">full-stack</a> guide for execution.</p>
      </details>
      <div id="demand-metrics" class="demand-metrics"></div>
      <div id="assessment-verdict" class="assessment-verdict"></div>
      <details class="assessment-details"><summary id="assessment-summary">Review constraints &amp; evidence</summary><div id="assessment-findings"></div></details>
      <details class="evidence-settings">
        <summary>Add availability requirements, quotas &amp; measured evidence</summary>
        <p class="fine">Zero means not supplied, not zero capacity. Benchmarks apply only to the matching configuration and are cleared when it changes. They are operator-reported, not independently validated by this page.</p>
        <div class="input-grid">
          <label>Search availability objective<select data-field="availability"><option value="evaluation">Evaluation, no HA claim</option><option value="queries">Query availability</option><option value="query-index">Query + indexing availability</option></select></label>
          <label>Assigned model TPM<input type="number" min="0" max="1000000000" step="1" data-field="modelTPM"></label>
          <label>Assigned model RPM<input type="number" min="0" max="10000000" step="1" data-field="modelRPM"></label>
          <label>Measured Search QPS, this configuration<input type="number" min="0" max="1000000" step="0.1" data-field="testedSearchQPS"></label>
          <label>Tested hosted concurrent turns<input type="number" min="0" max="1000000" step="1" data-field="testedHostedConcurrency"></label>
        </div>
      </details>
      </div>
    </details>
    <details class="planner-panel estimate" id="estimate">
      <summary><h2 id="estimate-title">Save, compare &amp; export</h2><span class="disclosure" aria-hidden="true">+</span></summary>
      <div class="panel-body">
      <div class="cost-comparison">
        <div><span class="field-label">Selected scenario / month</span><strong id="total-price"></strong><p id="cost-composition"></p></div>
        <div><span class="field-label">Starting point / same region</span><strong id="reference-price"></strong></div>
      </div>
      <p id="comparison-note"></p>
      <div class="pending-prices"><h3 id="pending-title">Estimate scope</h3><ul id="pending-prices"></ul><p class="fine">Compare the included resources, usage and price sources as well as the total. A scenario difference is not a guaranteed saving or an exact invoice.</p></div>
      <details><summary>Cost breakdown &amp; changed inputs</summary>
        <dl id="estimate-breakdown"></dl>
        <div class="estimate-foot"><span>Allocated capacity</span><strong id="fixed-price"></strong></div>
        <div class="estimate-foot"><span>Assumed consumption</span><strong id="usage-price"></strong></div>
        <p class="coverage-note" id="coverage-count"></p>
        <div id="scenario-changes"></div>
        <h3>Deployment handoff</h3><p class="fine">Review guidance only, not generated deployment-ready IaC. Infrastructure changes must preserve Bicep/Terraform parity.</p><ul id="deployment-handoff"></ul>
      </details>
      <details class="operator-prices"><summary>Edit sourced price assumptions</summary>
        <p class="fine">Edit USD price assumptions with a source/date, not confidential quote details. These are your planning inputs, not negotiated prices discovered by this tool. Token rates apply to the selected model and region; hosted/build amounts replace the whole row. Build amounts cover pool allocation, not active build time. Changing region/model clears these entries so you can reconfirm their scope.</p>
        <div class="input-grid">
          <label>Model input USD / million tokens<input type="number" min="0" max="100000" step="0.000001" data-field="modelInputRate"></label>
          <label>Model output USD / million tokens<input type="number" min="0" max="100000" step="0.000001" data-field="modelOutputRate"></label>
          <label>Hosted runtime USD / month<input type="number" min="0" max="10000000" step="0.01" data-field="hostedMonthly"></label>
          <label>Private build pool allocation USD / month<input type="number" min="0" max="10000000" step="0.01" data-field="buildMonthly"></label>
        </div>
        <label>Estimate source and date, no secrets<input type="text" maxlength="300" data-field="priceEvidence" placeholder="Public price page or non-confidential quote reference, date, and scope"></label>
        <p id="quote-status" class="warning" hidden></p>
      </details>
      <div class="scenario-actions" role="group" aria-label="Scenario handoff">
        <button type="button" id="save-scenario">Save on this device</button>
        <button type="button" id="load-scenario">Load saved</button>
        <button type="button" id="share-scenario">Copy scenario link</button>
        <button type="button" id="copy-summary">Copy summary</button>
        <button type="button" id="export-scenario">Export JSON report</button>
      </div>
      <label id="copy-fallback" hidden>Manual copy, clipboard unavailable<textarea id="copy-output" rows="8" readonly></textarea></label>
      <p id="action-message" class="notice" role="status" hidden></p>
      <p class="fine">Links and exports contain planning inputs and estimate notes. Do not enter credentials, confidential information or private identifiers. Saving on this device is explicit. Reload keeps a shared scenario URL, not unsaved edits.</p>
      </div>
    </details>
    <details id="coverage" class="planner-panel coverage">
      <summary><h2>Assumptions &amp; price sources</h2><span class="disclosure" aria-hidden="true">+</span></summary>
      <div class="panel-body">
      <span id="cost-planning"></span><span id="build-the-estimate"></span>
      <h3 id="estimate-inputs">Build a comparable estimate</h3>
      <p>Record the owner, date, region/currency, platform/component versions, selected and reused resources, expected monthly usage and contingency. Budget initial ingestion/reindexing separately from steady-state traffic. Resource counts, allocated hours, token usage, tool calls, transfer and retained storage are independent inputs. Changing topology, models, corpus or traffic can invalidate the estimate.</p>
      <div class="provenance"><span id="price-date"></span><span>USD &middot; Snapshot, not a live quote</span></div>
      <div class="coverage-grid">
        <div><h3>Public rates and sourced estimates</h3><p>The catalog combines Azure Retail Prices API records with automatically captured official pricing-page rows, not a live quote. The <code>gpt-5-nano</code> Global token rates and dedicated ACR S1 allocation rate come from exact published HTML rows, recorded with source and capture date separately from API meters. Resource details identify each source and billing unit. Operator-entered amounts are labelled separately.</p><p>Automated daily refresh is scheduled for 00:00 UTC. GitHub Actions can delay scheduled runs. API and official pricing-page requests use a 90-second timeout and up to four attempts for timeouts, interrupted connections and transient HTTP errors. Retries wait 10, 20 and 30 seconds, or respect a numeric Retry-After header up to 120 seconds. Only a validated catalog is published. If collection still fails, or exact-row parsing or validation fails, the last validated catalog remains in use. Check the displayed snapshot date and any stale-data warning before relying on an estimate.</p><p>730 hours is an editable monthly convention, not a deployment default. Daily meters use hours &divide; 24. Dedicated ACR pool allocation is billed even without active builds. Hosted allocation hours are a separate billing hypothesis, not a concurrency guarantee.</p></div>
        <div><h3>Budget for your selected scope</h3><p>The inventory includes Foundry backing dependencies, application services, management networking and optional integrations. Structural configuration and shared compute must not be billed twice. Quantity zero means an option is not allocated in this scenario, not that it is free when enabled.</p><p>Review each row's included billing units and assumptions. Contract-priced options require a source and a positive monthly unit price before adding quantity. If an agreement already covers the incremental cost, enter zero and explicitly confirm that the source covers the selected scope. Confirmed zero-cost estimates are labelled and preserved in saved/shared scenarios and JSON exports. A source alone does not establish a free service. Older scenarios with unsupported Search topologies or unconfirmed zero-price options are rejected with an explanation, not silently corrected. Additional model/tool use, ingestion, retrieval features, storage operations, retention, transfer and separately licensed services can change the bill.</p><p>Public rates do not incorporate your agreement, negotiated discounts, credits, taxes or currency conversion. Confirm availability, offer terms and the full selected scope with Azure Pricing Calculator or your account team. A difference from the reference is meaningful only with comparable scope and assumptions.</p></div>
      </div>
      <details class="assessment-details" id="planner-price-and-budget-assumptions">
        <summary>Reference billing hypotheses &amp; regional differences</summary>
        <p>The initial build schedule is 1 deployment/day for 30 days, with an editable 40 allocated minutes per deployment including startup, build and shutdown: 20 hours/month. At the captured S1 rate of $0.0001/vCPU-second and 2 vCPU, that is $14.40/month. Scale the pool to zero outside those windows in the actual operating process. Neither the planner nor this assumption implements that automation. Leaving it allocated for 730 hours costs $525.60 at the same rate. Use the pool's monthly-hours mode for continuous allocation or an already measured schedule.</p>
        <p>The initial model workload is 132 million input tokens and 22 million output tokens per month. Captured <code>gpt-5-nano</code> Global rates are $0.05 and $0.40 per million respectively, producing $15.40. Billable reasoning tokens belong in output tokens. Review each resource's live calculation for refreshed rates and your selected quantities.</p>
        <p>The fresh Foundry backing Cosmos DB account uses provisioned throughput. Its budget example assumes five manual 1,000-RU/s offers (5,000 RU/s total), 10 GB of transactional data plus indexes, a separate 10 GB of <code>Continuous30Days</code> backup and one non-zone-redundant region. This is a $296.50/month hypothesis at the captured rates, not a declaration of deployed offers. The Foundry runtime owns the actual offers.</p>
        <p>The backup selector is also a billing hypothesis: pinned Bicep AVM inherits <code>Continuous30Days</code>, while Terraform omits the backup policy and receives the API's periodic default. Selecting a backup hypothesis here does not change either provider or establish deployed parity.</p>
        <h3 id="standalone-firewall-selection">Standalone firewall selection</h3>
        <p>East US 2 starts with the shipped Basic Firewall choice. Include allocation, processed data, its separate management public IP and subnet, diagnostics and transfer. Choose security features before price. Standard DNS proxy is not a Basic capability. For Sweden Central, no VNet Basic rate was found in the Retail API or official Basic pricing row, so Standard is the regional reference. A secured-vHub price is not substituted. Deploying that reference needs a reviewed IaC change.</p>
      </details>
      <span id="check-the-agent-specific-cost-drivers"></span><h3 id="agent-specific-cost-drivers">Keep the scope explicit</h3>
      <p>Hosted compute, frontend compute, two Search services, backing data services and private management networking are separate costs. Count shared Container Apps nodes and workspace-based Application Insights ingestion only once. An omitted new resource can require a compatible existing service or a different feature selection, not a free replacement. DNS zones, disks, registry images and other retained allocations do not necessarily disappear with their consumers.</p>
      <span id="control-spend-without-weakening-the-design"></span><h3 id="spend-controls-and-security">Control spend without weakening the design</h3>
      <p>Measure idle allocations, retries, logs and retained resources. Tune model choice, capacity, replicas and retention against quality, latency, availability and compliance. Budgets and alerts notify, they do not stop services or cap spend. Keep private networking, authentication and document-level authorization intact. Shared infrastructure needs approved ownership, routes and permissions. Review backup, dependencies and access before deleting existing resources. A quantity of 0 here never deletes them.</p>
      <p>This planner models network-isolated standalone deployments. The reference uses <code>hosted-no-panel</code>, native Foundry IQ ingestion, no separate Agent Application Cosmos DB and no Agent App Ingestion worker. Foundry backing services are separate resources. Review <a href="../planning/">deployment choices</a>, <a href="../configuration/">deployment settings</a> and the <a href="../deploy-full-stack/">deployment guide</a> before applying a scenario. The <a href="../../architecture/cost-guide/">shared cost guide</a> has additional dated pricing examples, not current Agent defaults.</p>
      <div class="source-links"><a href="https://github.com/Azure/agent-landing-zone/blob/v5.5.3/main.parameters.json" target="_blank" rel="noopener">Reference deployment parameters &#8599;</a><a href="https://github.com/Azure/agent-landing-zone/blob/v5.5.3/infra/main.bicep" target="_blank" rel="noopener">Reference Bicep settings &#8599;</a><a href="https://learn.microsoft.com/en-us/rest/api/cost-management/retail-prices/azure-retail-prices" target="_blank" rel="noopener">Pricing API &#8599;</a><a href="../../data/planner/prices.json" target="_blank" rel="noopener">Price snapshot &#8599;</a></div>
      <a href="https://azure.microsoft.com/pricing/calculator/" target="_blank" rel="noopener">Confirm your estimate in Azure Pricing Calculator &#8599;</a>
      </div>
    </details>
  </div>
</div>

<script src="../../javascripts/planner/inventory.js?v=4" defer></script>
<script src="../../javascripts/planner/guidance.js" defer></script>
<script src="../../javascripts/planner/scenario.js?v=3" defer></script>
<script src="../../javascripts/planner/planner.js?v=6" defer></script>
