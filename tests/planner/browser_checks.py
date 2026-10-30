"""Check the real built MkDocs page, not a standalone planner fixture."""

import argparse
import functools
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
import threading

from playwright.sync_api import sync_playwright


ROOT = Path(__file__).resolve().parents[2]
PATH = "/agent-landing-zone/sizing-cost-planner/"


class Handler(SimpleHTTPRequestHandler):
    def log_message(self, *_):
        pass


def ready(page):
    page.wait_for_function("""() => typeof window.planner?.calculate === "function" ||
      document.querySelector("#agent-lz-planner #load-status")?.getAttribute("role") === "alert" """)
    assert page.evaluate("typeof window.planner?.calculate") == "function", page.locator("#load-status").inner_text()


def set_field(page, field, value):
    element = page.locator(f'[data-field="{field}"]').first
    assert element.is_enabled(), f"{field} must be editable"
    element.evaluate(
        "(element,value)=>{element.value=String(value);element.dispatchEvent(new Event('change',{bubbles:true}));}", value)


def edit_resource_field(page, field, value):
    control = page.locator(f'[data-field="{field}"]').first
    control.evaluate("""element=>{
      for(let node=element.parentElement;node;node=node.parentElement){
        if(node.tagName==='DETAILS')node.open=true;
      }
    }""")
    control.fill(str(value))
    control.press("Tab")


def run(base, candidate=None):
    with sync_playwright() as playwright:
        browser = playwright.chromium.launch()
        context = browser.new_context(viewport={"width": 1440, "height": 1000})
        if candidate:
            context.route("**/data/planner/prices.json", lambda route: route.fulfill(
                status=200, content_type="application/json", body=candidate))
        page = context.new_page()
        errors = []
        page.on("pageerror", lambda error: errors.append(str(error)))
        page.goto(base + PATH)
        ready(page)
        matrix = page.evaluate("""() => {
          const p=planner, results=[];
          const assert=(name,ok)=>{if(!ok)throw Error(name);results.push(name);};
          assert("All 77 architecture resources are present",p.snapshot.rows.length===77);
          assert("Every active default resource has a price",p.snapshot.rows.every(r=>r.amount!==null));
          const embedding=p.snapshot.rows.find(r=>r.id==="embeddings");
          assert("Embedding deployment type and capacities are explicit",
            embedding.sku==="text-embedding-3-large / GlobalStandard"&&
            embedding.detail.includes("declared capacity 100")&&
            embedding.detail.includes("fallback keeps capacity 10"));
          assert("Embedding processing boundary and regional override are explicit",
            embedding.detail.includes("outside the resource region")&&
            embedding.detail.includes("sku.name to Standard"));
          assert("Embedding price proxy is not presented as verified Global pricing",
            embedding.detail.includes("regional price meter as a budgeting proxy")&&
            embedding.detail.includes("not a verified Global Standard quote"));
          assert("Embedding estimate retains its exact regional meter and token calculation",
            embedding.lines.length===1&&
            embedding.lines[0].meter.skuName==="text-embedding-3-large-regional"&&
            Math.abs(embedding.amount-p.state.embeddingMillions*1000*
              embedding.lines[0].meter.retailPrice)<1e-8);
          assert("The total reconciles with all billable lines",Math.abs(p.snapshot.sum.total-
            p.snapshot.rows.flatMap(r=>r.lines).reduce((a,l)=>a+l.amount,0))<1e-8);
          assert("Optional application Cosmos and apps start at zero",["applicationCosmos","extraFrontendApps",
            "orchestratorApps","ingestionApps"].every(k=>p.state[k]===0));
          assert("No partial default estimate label",!document.querySelector("#live-total").parentElement.textContent.includes("Partial"));
          assert("Capabilities start compact",document.querySelectorAll(".capability[open]").length===0);
          assert("Advanced panels start closed",["decision","estimate","coverage"].every(id=>!document.getElementById(id).open));
          assert("No unexplained default delta",document.getElementById("cost-change-summary").hidden);
          assert("All resource editors remain available",document.querySelectorAll("[data-resource]").length===77);
          assert("Additional app quantities remain editable at zero",
            ["extraFrontendApps","orchestratorApps","ingestionApps"].every(field=>
              !document.querySelector('[data-field="'+field+'"]').matches(":disabled")));
          assert("Cost drivers reconcile to the total",Math.abs(
            [...document.querySelectorAll("[data-driver-amount]")].reduce((sum,e)=>sum+Number(e.dataset.driverAmount),0)-
            p.snapshot.sum.total)<1e-8);
          assert("Cost driver assumptions are explicit",document.querySelector("#cost-driver-items").textContent.includes(
            "5,000 RU/s billing hypothesis")&&document.querySelector("#build-budget-note").textContent.includes(
            "1 deployment(s)/day x 30 days/month x 40 allocated minutes = 20 hours/month"));
          assert("The exact default model is priced, not a newer substitute",
            Math.abs(p.snapshot.rows.find(r=>r.id==="model").amount-
              (132*p.catalog.publishedPrices["gpt-5-nano"].prices.eastus2.input+
              22*p.catalog.publishedPrices["gpt-5-nano"].prices.eastus2.output))<1e-8);
          assert("Daily deployments price 20 allocated hours, not a whole month",
            Math.abs(p.snapshot.rows.find(r=>r.id==="acr-build-pool").amount-
              20*3600*2*p.catalog.publishedPrices.acrDedicatedPool.prices.eastus2.allocation)<1e-8);
          assert("No scale-to-zero automation is claimed",document.querySelector("#build-budget-note").textContent.includes(
            "not automation provided by this planner or the default deployment"));
          for (const [override,hours] of [
            [{buildDeploymentsPerDay:2},40], [{buildDays:31},31*40/60],
            [{buildMinutes:60},30], [{buildDeploymentsPerDay:0},0],
            [{buildDays:0},0], [{buildMode:"allocated",buildHours:730},730],
            [{buildMode:"allocated",buildHours:12.5},12.5]]) {
            const s=p.validate({version:2,state:override});
            assert("Exact build schedule "+JSON.stringify(override),
              Math.abs(p.calculate(s).find(r=>r.id==="acr-build-pool").amount-
                hours*3600*2*p.catalog.publishedPrices.acrDedicatedPool.prices.eastus2.allocation)<1e-8);
          }
          for(const legacy of [{},{buildHours:20},{buildHours:0}]){
            const s=p.validate({version:1,state:legacy});
            const packed=scenarios.pack(s,p.defaults);
            const reloaded=p.validate(packed);
            assert("Legacy allocation preserved "+JSON.stringify(legacy),
              s.buildMode==="allocated"&&reloaded.buildMode==="allocated"&&
              architecture.buildAllocatedHours(reloaded)===(legacy.buildHours??730)&&packed.version===2);
          }
          for(const option of architecture.deploymentOptions){
            const row=p.snapshot.rows.find(r=>r.id===option.id);
            assert("Allocation option has a real resource "+option.field,!!row&&
              !!document.querySelector('[data-field="'+option.field+'"]'));
            assert("Allocation control remains editable "+option.field,
              !document.querySelector('[data-field="'+option.field+'"]').matches(":disabled"));
            const changed=p.calculate({[option.field]:0});
            const omitted=changed.find(r=>r.id===option.id);
            assert("Zero excludes new allocation "+option.field,omitted.amount===0&&
              omitted.lines.every(l=>l.quantity===0&&l.amount===0));
            assert("Totals reconcile after exclusion "+option.field,Math.abs(
              p.totals(changed).total-changed.reduce((sum,r)=>sum+r.amount,0))<1e-8);
          }
          for(const [field,children] of [
            ["searchServices",["search","pe-app-search"]],
            ["containerRegistries",["registry","acr-build-pool","pe-acr"]],
            ["containerEnvironments",["aca-environment","compute","frontend-app","pe-aca"]],
            ["jumpboxes",["jumpbox","jumpbox-disk","bastion","bastion-ip","nat","nat-ip"]],
            ["firewalls",["firewall","firewall-ip","firewall-management-ip","firewall-policy","routes"]],
            ["logWorkspaces",["logs","insights","ampls","pe-monitor"]],
            ["agentServices",["hosted","backing-search","backing-storage","backing-cosmos","foundry-vault",
              "pe-foundry-search","pe-foundry-storage","pe-foundry-cosmos","pe-foundry-vault"]]]){
            assert("Linked allocations follow "+field,p.calculate({[field]:0}).filter(r=>children.includes(r.id))
              .every(r=>!r.included&&r.amount===0));
          }
          const noSearch=p.calculate({searchServices:0});
          assert("Application Search does not remove backing Search",
            noSearch.find(r=>r.id==="backing-search").amount===p.snapshot.rows.find(r=>r.id==="backing-search").amount);
          assert("Shared Search DNS zone is not incorrectly removed",
            noSearch.find(r=>r.id==="dns").amount===p.snapshot.rows.find(r=>r.id==="dns").amount);
          assert("Entire new allocation scope can be excluded",p.totals(p.calculate(
            Object.fromEntries(architecture.deploymentOptions.map(o=>[o.field,0])))).total===0);
          assert("Five provisioned Cosmos offers and separate backup/storage are included",
            p.snapshot.rows.find(r=>r.id==="backing-cosmos").lines.map(l=>l.quantity).join(",")==="36500,10,10");
          for(const region of Object.keys(p.catalog.regions)){
            for(const override of [{},...["Basic","Standard S1","Standard S2"].map(searchSku=>({searchSku})),
              ...p.firewallSkus(region).map(firewall=>({firewall})),
              ...["Standard","Premium"].map(appconfig=>({appconfig})),
              ...["Standard v2","Premium v2"].map(apimSku=>({apimSku,apimUnits:3})),
              {apimUnits:0},{apimUnits:1},{apimUnits:10},
              {appGateway:1,applicationCosmos:1},{profile:"D8",nodes:2},{storageTier:"Cool LRS"},
              {model:"gpt-4.1-nano"},{backingCosmosMode:"autoscale"},
              {backingBackupMode:"periodic"},{backingBackupMode:"continuous7"}]){
              const rows=p.calculate({...p.referenceFor(region),...override});
              assert(region+" complete "+JSON.stringify(override),rows.every(r=>r.amount!==null));
              assert(region+" finite prices "+JSON.stringify(override),rows.every(r=>Number.isFinite(r.amount)&&r.amount>=0));
            }
            assert(region+" uses an explicit priced Firewall reference",
              p.firewallSkus(region).includes(p.referenceFor(region).firewall));
          }
          for(const [field,sku,id] of [
            ["searchPartitions","Standard S1","search"],["backingPartitions","Standard S1","backing-search"],
            ["searchPartitions","Standard S2","search"]]){
            for(const partitions of [1,2,3,4,6,12]){
              const s=p.validate({version:2,state:{searchSku:sku,[field]:partitions}});
              assert("Supported Search partitions "+sku+" "+field+" "+partitions,
                scenarios.assess(s).findings.find(f=>f.id===id+"-topology").status==="checked");
            }
            for(const partitions of [5,7,8,9,10,11]){
              for(const version of [1,2]){
                let rejected=false;
                try{p.validate({version,state:{searchSku:sku,[field]:partitions}});}catch{rejected=true;}
                assert("Unsupported Search partitions rejected "+sku+" "+field+" "+partitions+" v"+version,rejected);
              }
              assert("Invalid Search partitions never pass assessment "+field+" "+partitions,
                scenarios.assess({...p.state,searchSku:sku,[field]:partitions}).findings
                  .find(f=>f.id===id+"-topology").status==="action");
            }
          }
          for(const state of [{searchSku:"Basic",searchPartitions:4},{searchSku:"Basic",searchReplicas:4},
            {searchReplicas:4,searchPartitions:12},{backingReplicas:4,backingPartitions:12}]){
            let rejected=false;try{p.validate({version:2,state});}catch{rejected=true;}
            assert("Unsupported tier combination rejected "+JSON.stringify(state),rejected);
          }
          for(const partitions of [1,2,3]){
            assert("Basic Search supports fresh-service partitions "+partitions,
              p.validate({version:2,state:{searchSku:"Basic",searchPartitions:partitions}}).searchPartitions===partitions);
          }
          for(const field of architecture.quoteFields){
            let rejected=false;
            try{p.validate({version:1,state:{[field]:1}});}catch{rejected=true;}
            assert("No silent zero for "+field,rejected);
            const zeroQuote={[field]:3,[field+"MonthlyRate"]:0,
              [field+"PriceSource"]:"Public plan reference, date and billing scope"};
            for(const version of [1,2]){
              let unconfirmedRejected=false;
              try{p.validate({version,state:zeroQuote});}catch{unconfirmedRejected=true;}
              assert("Unconfirmed zero quote rejected "+field+" v"+version,unconfirmedRejected);
            }
            assert("Cost boundary does not treat an unconfirmed zero as free "+field,
              p.calculate(zeroQuote).some(r=>r.amount===null&&r.quoteRequired));
            const confirmed=p.validate({version:2,state:{...zeroQuote,[field+"ZeroCostConfirmed"]:true}});
            const packed=scenarios.pack(confirmed,p.defaults);
            const restored=p.validate(packed);
            assert("Explicit zero quote accepted and preserved "+field,
              restored[field+"ZeroCostConfirmed"]===true&&p.calculate(restored).some(r=>
                r.operatorEstimate&&r.zeroCostConfirmed&&r.amount===0&&r.lines[0].quantity===3));
            const s=p.validate({version:1,state:{[field]:1,[field+"MonthlyRate"]:12.5,
              [field+"PriceSource"]:"Explicit test plan price and date"}});
            assert("Sourced plan price accepted for "+field,p.calculate(s).some(r=>
              r.operatorEstimate&&r.estimateSource==="Explicit test plan price and date"&&r.amount===12.5));
          }
          for(const state of [{users:-1},{nodes:Infinity},{region:"other"},{unknown:1},{users:"100"},
            {buildMinutes:0},{buildDays:32},{buildDeploymentsPerDay:37},{buildMode:"weekly"},
            {searchServices:2},{searchServices:.5},{searchReplicas:0},{searchPartitions:0},
            {vpnGatewaysZeroCostConfirmed:"true"},{vpnGatewaysZeroCostConfirmed:1},
            {vpnGateways:1,vpnGatewaysZeroCostConfirmed:true,vpnGatewaysPriceSource:"   "}]){
            let rejected=false;try{p.validate({version:2,state});}catch{rejected=true;}
            assert("Malformed scenario rejected "+JSON.stringify(state),rejected);
          }
          assert("Neutral sizing baseline",p.assessment().status==="Sizing baseline"&&
            !document.querySelector("#assessment-verdict").classList.contains("needs-attention"));
          return results;
        }""")
        nav = page.locator(".md-sidebar--primary")
        assert not nav.locator("a").evaluate_all(
            "links=>links.some(a=>/\\/(sizing|cost-planning)\\/$/.test(new URL(a.href).pathname))")
        assert nav.locator("a").evaluate_all(
            "links=>links.filter(a=>new URL(a.href).pathname.endsWith('/sizing-cost-planner/')).length") == 1
        baseline = page.evaluate("planner.snapshot.sum.total")
        for field in ("searchPartitions", "backingPartitions"):
            control = page.locator(f'[data-field="{field}"]')
            assert control.locator("option").evaluate_all("nodes=>nodes.map(e=>Number(e.value))") == [1, 2, 3, 4, 6, 12]
            for value in (4, 6, 12, 1):
                control.evaluate("""element=>{
                  for(let node=element.parentElement;node;node=node.parentElement){
                    if(node.tagName==='DETAILS')node.open=true;
                  }
                }""")
                control.select_option(str(value))
                assert page.evaluate(f"planner.state.{field}") == value
            control.evaluate("""element=>{
              element.add(new Option("Unsupported 5 partitions","5"));
              element.value="5";
              element.dispatchEvent(new Event("change",{bubbles:true}));
            }""")
            assert page.evaluate(f"planner.state.{field}") == 1
            assert page.locator("#input-error").is_visible()
            assert "Choose a supported combination" in page.locator("#input-error").inner_text()
            assert abs(page.evaluate("planner.snapshot.sum.total") - baseline) < 1e-8
            page.locator("#reset").click()
        set_field(page, "searchSku", "Basic")
        assert page.locator('[data-field="searchPartitions"] option').evaluate_all(
            "nodes=>nodes.map(e=>Number(e.value))") == [1, 2, 3]
        assert page.locator('[data-field="searchReplicas"]').get_attribute("max") == "3"
        set_field(page, "searchPartitions", 3)
        set_field(page, "searchReplicas", 3)
        assert page.evaluate("planner.assessment().findings.find(f=>f.id==='search-topology').status") == "checked"
        page.locator("#reset").click()
        set_field(page, "searchReplicas", 12)
        assert page.locator('[data-field="searchPartitions"] option').evaluate_all(
            "nodes=>nodes.map(e=>Number(e.value))") == [1, 2, 3]
        page.locator("#reset").click()
        for field in page.evaluate("architecture.quoteFields"):
            assert page.locator(f'[data-field="{field}"]').is_disabled()
        edit_resource_field(page, "vpnGatewaysPriceSource", "Public plan reference, date and billing scope")
        assert page.locator('[data-field="vpnGateways"]').is_disabled()
        assert page.locator('[data-field="vpnGatewaysZeroCostConfirmed"]').is_enabled()
        page.locator('[data-field="vpnGateways"]').evaluate("""element=>{
          element.value="3";element.dispatchEvent(new Event("change",{bubbles:true}));
        }""")
        assert page.evaluate("planner.state.vpnGateways") == 0
        assert page.locator("#input-error").is_visible()
        assert "explicitly confirm no incremental charge" in page.locator("#input-error").inner_text()
        assert abs(page.evaluate("planner.snapshot.sum.total") - baseline) < 1e-8
        page.locator('[data-field="vpnGatewaysZeroCostConfirmed"]').check()
        assert page.evaluate("planner.state.vpnGatewaysZeroCostConfirmed") is True
        assert page.locator('[data-field="vpnGateways"]').is_enabled()
        edit_resource_field(page, "vpnGateways", 3)
        assert "Operator-confirmed $0" in page.locator('#entry-vpn [data-row-total="vpn"]').inner_text()
        assert page.evaluate("planner.snapshot.rows.find(r=>r.id==='vpn').amount") == 0
        edit_resource_field(page, "vpnGatewaysMonthlyRate", 12.5)
        assert page.evaluate("planner.state.vpnGatewaysZeroCostConfirmed") is False
        assert page.evaluate("planner.snapshot.rows.find(r=>r.id==='vpn').amount") == 37.5
        edit_resource_field(page, "vpnGateways", 0)
        edit_resource_field(page, "vpnGatewaysMonthlyRate", 0)
        assert page.locator('[data-field="vpnGateways"]').is_disabled()
        page.locator('[data-field="vpnGatewaysZeroCostConfirmed"]').check()
        edit_resource_field(page, "vpnGatewaysPriceSource", "Updated public plan scope and date")
        assert page.evaluate("planner.state.vpnGatewaysZeroCostConfirmed") is False
        assert page.locator('[data-field="vpnGateways"]').is_disabled()
        page.locator("#reset").click()
        for field, resource in [
            ("extraFrontendApps", "extra-frontends"), ("orchestratorApps", "orchestrator-app"),
            ("ingestionApps", "ingestion-app")]:
            for quantity in (1, 2, 0):
                edit_resource_field(page, field, quantity)
                assert page.evaluate(f"planner.state.{field}") == quantity
                assert page.locator(f'[data-field="{field}"]').is_enabled()
                assert page.evaluate(f"planner.snapshot.rows.find(r=>r.id==='{resource}').included") == bool(quantity)
                assert page.evaluate("""() => Math.abs(planner.snapshot.sum.total-
                  planner.snapshot.rows.flatMap(r=>r.lines).reduce((sum,line)=>sum+line.amount,0))<1e-8""")
            for parent in ("containerEnvironments", "frontendDeployments"):
                edit_resource_field(page, field, 2)
                edit_resource_field(page, parent, 0)
                assert page.locator(f'[data-field="{field}"]').is_disabled()
                assert page.evaluate(f"planner.snapshot.rows.find(r=>r.id==='{resource}').amount") == 0
                assert page.evaluate(f"planner.snapshot.rows.find(r=>r.id==='{resource}').included") is False
                edit_resource_field(page, parent, 1)
                assert page.locator(f'[data-field="{field}"]').is_enabled()
                assert page.locator(f'[data-field="{field}"]').input_value() == "2"
                assert page.evaluate(f"planner.snapshot.rows.find(r=>r.id==='{resource}').included") is True
                edit_resource_field(page, field, 0)
            assert abs(page.evaluate("planner.snapshot.sum.total") - baseline) < 1e-8
        page.locator("#capabilities details[open]").evaluate_all("nodes=>nodes.forEach(node=>node.open=false)")
        page.locator("#operations > summary").click()
        page.locator("#entry-acr-build-pool > summary").click()
        assert page.locator('[data-field="buildDeploymentsPerDay"]').input_value() == "1"
        assert page.locator('[data-field="buildMinutes"]').input_value() == "40"
        set_field(page, "buildMinutes", 60)
        assert abs(page.evaluate("planner.exportReport().buildAllocation.allocatedHoursPerMonth") - 30) < 1e-8
        set_field(page, "buildMode", "allocated")
        assert page.locator('[data-field="buildHours"]').input_value() == "730"
        assert "No automatic scale-to-zero" in page.locator("#build-budget-note").text_content()
        set_field(page, "buildPools", 0)
        assert page.evaluate("planner.exportReport().buildAllocation.included") is False
        assert page.evaluate("planner.exportReport().buildAllocation.allocatedHoursPerMonth") == 0
        assert page.evaluate("planner.snapshot.rows.find(r=>r.id==='acr-build-pool').amount") == 0
        page.locator("#reset").click()
        page.locator("#knowledge > summary").click()
        page.locator("#entry-search > summary").click()
        search_cost = page.evaluate("planner.snapshot.rows.filter(r=>['search','pe-app-search'].includes(r.id)).reduce((s,r)=>s+r.amount,0)")
        page.locator('[data-field="searchServices"]').fill("0")
        page.locator('[data-field="searchServices"]').press("Tab")
        assert page.evaluate("planner.state.searchServices") == 0
        assert page.locator("#entry-search [data-row-total=search]").inner_text().startswith("$0.00")
        assert page.locator("#excluded-scope-note").is_visible()
        assert page.locator('[data-field="searchReplicas"]').is_disabled()
        assert abs(baseline - page.evaluate("planner.snapshot.sum.total") - search_cost) < 1e-8
        assert not any(f["id"].startswith("search-") and f["status"] == "action"
                       for f in page.evaluate("planner.assessment().findings"))
        set_field(page, "searchServices", 1)
        assert page.locator('[data-field="searchReplicas"]').is_enabled()
        assert abs(page.evaluate("planner.snapshot.sum.total") - baseline) < 1e-8
        page.locator("#starting-point-note").click()
        assert page.locator("#cost-drivers").evaluate("e=>e.open")
        assert page.locator("#cost-driver-items").is_visible()
        page.locator("#networking > summary").click()
        page.locator("#entry-appgateway > summary").click()
        gateway = page.locator('[data-field="appGateway"]')
        assert gateway.count() == 1
        assert gateway.is_enabled(), "The gateway allocation control must remain editable at quantity zero"
        gateway_baseline = page.evaluate("planner.snapshot.sum.total")
        for quantity in (1, 0, 1):
            gateway.fill(str(quantity))
            gateway.press("Tab")
            assert page.evaluate("planner.state.appGateway") == quantity
            assert gateway.is_enabled()
            assert page.locator('[data-field="gatewayCU"]').is_enabled() == bool(quantity)
            assert page.evaluate("planner.snapshot.rows.find(r=>r.id==='gateway-ip').amount > 0") == bool(quantity)
            assert (page.evaluate("planner.snapshot.sum.total") > gateway_baseline) == bool(quantity)
        set_field(page, "frontendDeployments", 0)
        assert gateway.is_enabled()
        assert page.locator('[data-field="gatewayCU"]').is_disabled()
        gateway.fill("0")
        gateway.press("Tab")
        gateway.fill("1")
        gateway.press("Tab")
        assert page.evaluate("planner.state.appGateway") == 1
        assert page.evaluate("planner.snapshot.rows.filter(r=>['appgateway','gateway-ip'].includes(r.id)).every(r=>r.amount===0)")
        set_field(page, "frontendDeployments", 1)
        assert page.locator('[data-field="gatewayCU"]').is_enabled()
        assert page.evaluate("planner.snapshot.rows.find(r=>r.id==='gateway-ip').amount") > 0
        gateway.fill("0")
        gateway.press("Tab")
        assert abs(page.evaluate("planner.snapshot.sum.total") - gateway_baseline) < 1e-8
        page.locator("#entry-apim > summary").click()
        assert page.locator("#entry-apim .option-preview").is_visible()
        page.locator('[data-field="apimUnits"]').fill("1")
        page.locator('[data-field="apimUnits"]').press("Tab")
        assert page.evaluate("planner.state.apimUnits") == 1
        assert page.locator("#cost-change-summary").is_visible()
        assert "Already included in the total" in page.locator("#cost-change-summary").inner_text()
        assert page.locator("#cost-change-items li").count() == 2
        assert "API Management / AI Gateway" in page.locator("#cost-change-items").inner_text()
        assert "API Management private endpoint" in page.locator("#cost-change-items").inner_text()
        assert page.evaluate("""() => Math.abs([...document.querySelectorAll("[data-cost-delta]")]
          .reduce((sum,el)=>sum+Number(el.dataset.costDelta),0)-
          (planner.snapshot.sum.total-planner.exportReport().reference.subtotal.total))<1e-8""")
        page.locator("#cost-change-items a").last.click()
        assert page.locator("#networking").evaluate("e=>e.open")
        assert page.locator("#cost-change-items a").last.get_attribute("href") == page.evaluate("location.hash")
        page.locator("#reset").click()
        assert page.locator("#cost-change-summary").is_hidden()
        set_field(page, "modelTPM", 1)
        assert page.locator("#assessment-verdict").evaluate("e=>e.classList.contains('needs-attention')")
        assert page.locator("#sizing-alert").is_visible()
        page.locator("#sizing-alert a").click()
        assert page.locator("#decision").evaluate("e=>e.open")
        page.locator("#reset").click()
        set_field(page, "region", "swedencentral")
        assert page.evaluate("planner.state.firewall") == page.evaluate("planner.referenceFor('swedencentral').firewall")
        if not page.evaluate("planner.firewallSkus('swedencentral').includes('Basic')"):
            assert page.locator("#scenario-message").inner_text().find("explicitly set to Standard") >= 0
        page.locator("#reset").click()
        set_field(page, "appGateway", 1)
        assert page.evaluate("planner.snapshot.rows.find(r=>r.id==='gateway-ip').amount") > 0
        edit_resource_field(page, "vpnGatewaysPriceSource", "Covered agreement, public reference and date")
        page.locator('[data-field="vpnGatewaysZeroCostConfirmed"]').check()
        edit_resource_field(page, "vpnGateways", 3)
        if not page.locator("#estimate").evaluate("e=>e.open"):
            page.locator("#estimate > summary").click()
        page.locator("#save-scenario").click()
        page.locator("#reset").click()
        page.locator("#load-scenario").click()
        assert page.evaluate("planner.state.appGateway") == 1
        assert page.evaluate("planner.state.vpnGatewaysZeroCostConfirmed") is True
        assert page.evaluate("planner.state.vpnGateways") == 3
        page.evaluate("""() => Object.defineProperty(navigator,"clipboard",{configurable:true,
          value:{writeText:async text=>{window.copiedScenario=text;}}})""")
        page.locator("#share-scenario").click()
        page.wait_for_function("() => typeof window.copiedScenario==='string'")
        shared = page.evaluate("window.copiedScenario")
        page.goto(shared)
        ready(page)
        assert page.evaluate("planner.state.appGateway") == 1
        assert page.evaluate("planner.state.vpnGatewaysZeroCostConfirmed") is True
        assert page.evaluate("planner.state.vpnGateways") == 3
        if not page.locator("#estimate").evaluate("e=>e.open"):
            page.locator("#estimate > summary").click()
        with page.expect_download() as downloaded:
            page.locator("#export-scenario").click()
        report = json.loads(Path(downloaded.value.path()).read_text(encoding="utf-8"))
        assert len(report["resources"]) == 77 and report["state"]["appGateway"] == 1
        assert report["scenario"]["version"] == 2
        assert report["buildAllocation"]["allocatedHoursPerMonth"] == 20
        assert "not automation" in report["buildAllocation"]["assumption"]
        assert report["outstandingActiveCosts"] == []
        vpn = next(resource for resource in report["resources"] if resource["id"] == "vpn")
        assert vpn["zeroCostConfirmed"] is True and vpn["monthlyUSD"] == 0
        assert vpn["lines"][0]["quantity"] == 3
        assert report["scenario"]["state"]["vpnGatewaysZeroCostConfirmed"] is True
        model = next(resource for resource in report["resources"] if resource["id"] == "model")
        assert all(line["source"] == "https://azure.microsoft.com/en-us/pricing/details/azure-openai/"
                   and "meterId" not in line["meter"] for line in model["lines"])
        for width in (390, 800, 1440):
            page.set_viewport_size({"width": width, "height": 900})
            page.wait_for_timeout(50)
            assert page.evaluate("document.documentElement.scrollWidth<=document.documentElement.clientWidth"), width
            assert page.locator("#agent-lz-planner input,#agent-lz-planner select,#agent-lz-planner textarea").evaluate_all(
                "nodes=>nodes.every(e=>e.labels.length||e.getAttribute('aria-label'))")
            original = page.evaluate("planner.snapshot.sum.total")
            page.locator("#resource-search").fill("no matching resource")
            assert page.locator("#no-resources").is_visible()
            assert page.evaluate("planner.snapshot.sum.total") == original
            page.locator("#clear-filters").click()
        set_field(page, "region", "swedencentral")
        assert page.evaluate("planner.state.vpnGatewaysZeroCostConfirmed") is False
        assert page.evaluate("planner.state.vpnGateways") == 0
        assert page.evaluate("planner.state.vpnGatewaysPriceSource") == ""
        page.locator("#reset").click()
        set_field(page, "users", 0)
        assert "less than the starting point" in page.locator("#live-delta").inner_text()
        assert page.evaluate("""() => Math.abs([...document.querySelectorAll("[data-cost-delta]")]
          .reduce((sum,e)=>sum+Number(e.dataset.costDelta),0)-
          (planner.snapshot.sum.total-planner.exportReport().reference.subtotal.total))<1e-8""")
        page.locator("#reset").click()
        legacy = context.new_page()
        legacy.goto(base + PATH + "?scenario=" + json.dumps({"version": 1, "state": {}}))
        ready(legacy)
        assert legacy.evaluate("planner.state.buildMode") == "allocated"
        assert legacy.evaluate("planner.exportReport().buildAllocation.allocatedHoursPerMonth") == 730
        legacy.locator("#estimate > summary").click()
        legacy.evaluate("localStorage.setItem(scenarios.storageKey,JSON.stringify({version:1,state:{buildHours:20}}))")
        legacy.locator("#load-scenario").click()
        assert legacy.evaluate("planner.state.buildMode") == "allocated"
        assert legacy.evaluate("planner.exportReport().buildAllocation.allocatedHoursPerMonth") == 20
        legacy.close()
        invalid_scenarios = [
            {"searchPartitions": 5}, {"backingPartitions": 7},
            {"vpnGateways": 3, "vpnGatewaysPriceSource": "Source without a price or confirmation"},
        ]
        for version in (1, 2):
            for state in invalid_scenarios:
                rejected = context.new_page()
                payload = {"version": version, "state": state}
                rejected.goto(base + PATH + "?scenario=" + json.dumps(payload))
                ready(rejected)
                assert "Scenario rejected" in rejected.locator("#scenario-message").inner_text()
                assert rejected.evaluate("planner.state.searchPartitions") == 1
                assert rejected.evaluate("planner.state.backingPartitions") == 1
                assert rejected.evaluate("planner.state.vpnGateways") == 0
                assert abs(rejected.evaluate("planner.snapshot.sum.total") - baseline) < 1e-8
                rejected.evaluate("(payload)=>localStorage.setItem(scenarios.storageKey,JSON.stringify(payload))", payload)
                rejected.locator("#estimate > summary").click()
                rejected.locator("#load-scenario").click()
                assert "Could not load the saved scenario" in rejected.locator("#scenario-message").inner_text()
                assert abs(rejected.evaluate("planner.snapshot.sum.total") - baseline) < 1e-8
                rejected.close()
        for old, anchor, parent in [
            ("sizing", "application-hosting", "decision"),
            ("sizing", "workload-baseline", "decision"),
            ("cost-planning", "planner-price-and-budget-assumptions", "coverage"),
            ("cost-planning", "control-spend-without-weakening-the-design", "coverage")]:
            moved = context.new_page()
            moved.goto(base + f"/agent-landing-zone/{old}/#{anchor}")
            moved.wait_for_url("**/sizing-cost-planner/**")
            ready(moved)
            assert moved.url.endswith("#" + anchor)
            assert moved.locator("#" + anchor).count() == 1
            assert moved.locator("#" + parent).evaluate("e=>e.open")
            moved.close()
        assert not errors, errors
        stale = context.new_page()
        original_catalog = candidate or (ROOT / "docs" / "data" / "planner" / "prices.json").read_text(encoding="utf-8")
        stale_catalog = json.loads(original_catalog)
        stale_catalog["retrievedAt"] = "2020-01-01T00:00:00Z"
        stale.route("**/data/planner/prices.json", lambda route: route.fulfill(
            status=200, content_type="application/json", body=json.dumps(stale_catalog)))
        stale.goto(base + PATH)
        ready(stale)
        assert stale.locator("#stale-warning").is_visible()
        assert stale.evaluate("planner.snapshot.sum.total") > 0
        malformed = context.new_page()
        malformed.route("**/data/planner/prices.json", lambda route: route.fulfill(
            status=200, content_type="application/json", body='{"currency":"USD"}'))
        malformed.goto(base + PATH)
        malformed.locator("#load-status[role=alert]").wait_for()
        assert malformed.locator("#planner").is_hidden()
        failure = context.new_page()
        failure.route("**/data/planner/prices.json", lambda route: route.fulfill(status=503, body="Unavailable"))
        failure.goto(base + PATH)
        failure.locator("#load-status[role=alert]").wait_for()
        assert failure.locator("#planner").is_hidden()
        assert failure.evaluate("typeof window.planner?.calculate") != "function"
        context.close()
        browser.close()
        print(f"PASS: {len(matrix)} pricing/contract assertions, scenario/save/share/download, responsive and catalog-failure checks")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--site-dir", type=Path, default=ROOT / "site")
    parser.add_argument("--catalog", type=Path, help="Validate a candidate without replacing the committed catalog")
    args = parser.parse_args()
    server = ThreadingHTTPServer(("127.0.0.1", 0), functools.partial(Handler, directory=str(args.site_dir)))
    worker = threading.Thread(target=server.serve_forever, daemon=True)
    worker.start()
    try:
        run(f"http://127.0.0.1:{server.server_port}", args.catalog.read_text(encoding="utf-8") if args.catalog else None)
    finally:
        server.shutdown()
        server.server_close()
        worker.join()


if __name__ == "__main__":
    main()
