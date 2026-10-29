---
title: Sizing & cost planner
hide:
  - toc
---

<div id="agent-lz-planner" data-catalog-url="../../data/planner/prices.json">
  <h1 id="main">Sizing &amp; cost planner</h1>
  <p class="intro">Start with the isolated architecture. Adjust your workload and resources to see their monthly cost.</p>
  <noscript><p class="warning">This planner needs JavaScript. Enable it and reload, or use the <a href="../sizing/">sizing guidance</a> and <a href="../cost-planning/">cost-planning guidance</a>.</p></noscript>
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
    <p class="fine planner-scope">Estimate only. Workload inputs are hypothetical. Nothing is deployed. <a href="#coverage">Assumptions &amp; price sources</a></p>
    <details id="cost-drivers" class="cost-drivers">
      <summary>Largest monthly costs</summary>
      <p class="fine" id="cost-driver-note"></p>
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
        <p class="fine">Open a capability, then a resource to change it or read its sizing guidance. Optional resources start at quantity 0.</p>
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
      <div class="provenance"><span id="price-date"></span><span>USD &middot; Snapshot, not a live quote</span></div>
      <div class="coverage-grid">
        <div><h3>Public rates and sourced estimates</h3><p>The catalog combines Azure Retail Prices API records with automatically captured official pricing-page rows, not a live quote. The <code>gpt-5-nano</code> Global token rates and dedicated ACR S1 allocation rate come from exact published HTML rows, recorded with source and capture date separately from API meters. Resource details identify each source and billing unit. Operator-entered amounts are labelled separately.</p><p>Automated daily refresh publishes only a validated catalog. If collection, exact-row parsing or validation fails, the last validated catalog remains in use. Check the displayed snapshot date and any stale-data warning before relying on an estimate.</p><p>730 hours is an editable monthly convention, not a deployment default. Daily meters use hours &divide; 24. Dedicated ACR pool allocation is billed even without active builds. Hosted allocation hours are a separate billing hypothesis, not a concurrency guarantee.</p></div>
        <div><h3>Budget for your selected scope</h3><p>The inventory includes Foundry backing dependencies, application services, management networking and optional integrations. Structural configuration and shared compute must not be billed twice. Quantity zero means an option is not allocated in this scenario, not that it is free when enabled.</p><p>Review each row's included billing units and assumptions. Contract-priced options use your editable, sourced USD amounts. Additional model/tool use, ingestion, retrieval features, storage operations, retention, transfer and separately licensed services can change the bill.</p><p>Public rates do not incorporate your agreement, negotiated discounts, credits, taxes or currency conversion. Confirm availability, offer terms and the full selected scope with Azure Pricing Calculator or your account team. A difference from the reference is meaningful only with comparable scope and assumptions.</p></div>
      </div>
      <details class="assessment-details">
        <summary>Reference billing hypotheses &amp; regional differences</summary>
        <p>The fresh Foundry backing Cosmos DB account uses provisioned throughput. Its budget example assumes five manual 1,000-RU/s offers (5,000 RU/s total), 10 GB of transactional data plus indexes, a separate 10 GB of <code>Continuous30Days</code> backup and one non-zone-redundant region. This is a $296.50/month hypothesis at the captured rates, not a declaration of deployed offers. The Foundry runtime owns the actual offers.</p>
        <p>The backup selector is also a billing hypothesis: pinned Bicep AVM inherits <code>Continuous30Days</code>, while Terraform omits the backup policy and receives the API's periodic default. Selecting a backup hypothesis here does not change either provider or establish deployed parity.</p>
        <p>East US 2 starts with the shipped Basic Firewall choice. For Sweden Central, no VNet Basic Firewall rate was found in the Retail API or official Basic pricing row; a secured-vHub rate is a different topology and is not substituted. The planner offers Standard/Premium there and uses Standard as its regional reference. Deploying that reference needs a reviewed IaC change; it is not the shipped Basic default.</p>
        <p>See <a href="../cost-planning/#planner-price-and-budget-assumptions">price calculations and budget assumptions</a> for the initial token and build-pool examples. Refreshed rates and their dates are recorded in the catalog.</p>
      </details>
      <p>This planner models network-isolated standalone deployments. The reference uses <code>hosted-no-panel</code>, native Foundry IQ ingestion, no separate Agent Application Cosmos DB and no Agent App Ingestion worker. Foundry backing services are separate resources. Review <a href="../planning/">deployment choices</a>, <a href="../sizing/">sizing and capacity</a> and <a href="../cost-planning/">cost planning</a> before translating a scenario into reviewed infrastructure changes.</p>
      <div class="source-links"><a href="https://github.com/Azure/agent-landing-zone/blob/v5.5.3/main.parameters.json" target="_blank" rel="noopener">Reference deployment parameters &#8599;</a><a href="https://github.com/Azure/agent-landing-zone/blob/v5.5.3/infra/main.bicep" target="_blank" rel="noopener">Reference Bicep settings &#8599;</a><a href="https://learn.microsoft.com/en-us/rest/api/cost-management/retail-prices/azure-retail-prices" target="_blank" rel="noopener">Pricing API &#8599;</a><a href="../../data/planner/prices.json" target="_blank" rel="noopener">Price snapshot &#8599;</a></div>
      <a href="https://azure.microsoft.com/pricing/calculator/" target="_blank" rel="noopener">Confirm your estimate in Azure Pricing Calculator &#8599;</a>
      </div>
    </details>
  </div>
</div>

<script src="../../javascripts/planner/inventory.js" defer></script>
<script src="../../javascripts/planner/guidance.js" defer></script>
<script src="../../javascripts/planner/scenario.js" defer></script>
<script src="../../javascripts/planner/planner.js" defer></script>
