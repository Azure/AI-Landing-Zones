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
    page.locator(f'[data-field="{field}"]').first.evaluate(
        "(element,value)=>{element.value=String(value);element.dispatchEvent(new Event('change',{bubbles:true}));}", value)


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
          assert("The total reconciles with all billable lines",Math.abs(p.snapshot.sum.total-
            p.snapshot.rows.flatMap(r=>r.lines).reduce((a,l)=>a+l.amount,0))<1e-8);
          assert("Optional application Cosmos and apps start at zero",["applicationCosmos","extraFrontendApps",
            "orchestratorApps","ingestionApps"].every(k=>p.state[k]===0));
          assert("No partial default estimate label",!document.querySelector("#live-total").parentElement.textContent.includes("Partial"));
          assert("The exact default model is priced, not a newer substitute",
            Math.abs(p.snapshot.rows.find(r=>r.id==="model").amount-
              (132*p.catalog.publishedPrices["gpt-5-nano"].prices.eastus2.input+
              22*p.catalog.publishedPrices["gpt-5-nano"].prices.eastus2.output))<1e-8);
          assert("Dedicated allocation includes all 730 idle and active hours",
            Math.abs(p.snapshot.rows.find(r=>r.id==="acr-build-pool").amount-
              730*3600*2*p.catalog.publishedPrices.acrDedicatedPool.prices.eastus2.allocation)<1e-8);
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
          for(const field of architecture.quoteFields){
            let rejected=false;
            try{p.validate({version:1,state:{[field]:1}});}catch{rejected=true;}
            assert("No silent zero for "+field,rejected);
            const s=p.validate({version:1,state:{[field]:1,[field+"MonthlyRate"]:12.5,
              [field+"PriceSource"]:"Explicit test plan price and date"}});
            assert("Sourced plan price accepted for "+field,p.calculate(s).some(r=>
              r.operatorEstimate&&r.estimateSource==="Explicit test plan price and date"&&r.amount===12.5));
          }
          for(const state of [{users:-1},{nodes:Infinity},{region:"other"},{unknown:1},{users:"100"}]){
            let rejected=false;try{p.validate({version:1,state});}catch{rejected=true;}
            assert("Malformed scenario rejected "+JSON.stringify(state),rejected);
          }
          assert("Neutral sizing baseline",p.assessment().status==="Sizing baseline"&&
            !document.querySelector("#assessment-verdict").classList.contains("needs-attention"));
          return results;
        }""")
        set_field(page, "modelTPM", 1)
        assert page.locator("#assessment-verdict").evaluate("e=>e.classList.contains('needs-attention')")
        page.locator("#reset").click()
        set_field(page, "region", "swedencentral")
        assert page.evaluate("planner.state.firewall") == page.evaluate("planner.referenceFor('swedencentral').firewall")
        if not page.evaluate("planner.firewallSkus('swedencentral').includes('Basic')"):
            assert page.locator("#scenario-message").inner_text().find("explicitly set to Standard") >= 0
        page.locator("#reset").click()
        set_field(page, "appGateway", 1)
        assert page.evaluate("planner.snapshot.rows.find(r=>r.id==='gateway-ip').amount") > 0
        page.locator("#save-scenario").click()
        page.locator("#reset").click()
        page.locator("#load-scenario").click()
        assert page.evaluate("planner.state.appGateway") == 1
        page.evaluate("""() => Object.defineProperty(navigator,"clipboard",{configurable:true,
          value:{writeText:async text=>{window.copiedScenario=text;}}})""")
        page.locator("#share-scenario").click()
        page.wait_for_function("() => typeof window.copiedScenario==='string'")
        shared = page.evaluate("window.copiedScenario")
        page.goto(shared)
        ready(page)
        assert page.evaluate("planner.state.appGateway") == 1
        with page.expect_download() as downloaded:
            page.locator("#export-scenario").click()
        report = json.loads(Path(downloaded.value.path()).read_text(encoding="utf-8"))
        assert len(report["resources"]) == 77 and report["state"]["appGateway"] == 1
        assert report["outstandingActiveCosts"] == []
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
