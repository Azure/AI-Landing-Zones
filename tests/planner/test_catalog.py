"""Contract failures must never overwrite the last validated public catalog."""

import copy
import http.client
import io
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch
from urllib.error import HTTPError, URLError


ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts" / "planner"))
import validate_catalog as catalog
import collect_prices as collector
import published_prices as published
from published_prices import extract

PRICE = catalog.FIELDS.index("retailPrice")
METER_ID = catalog.FIELDS.index("meterId")
OLD = "2026-01-01T00:00:00+00:00"
SLUGS = {"eastus2": "us-east-2", "swedencentral": "sweden-central", "brazilsouth": "brazil-south"}
SELECTOR = ("<select id='region-selector'><optgroup label='United States'><option value='us-east-2'>East US 2</option>"
            "<option value='us-west'>West US</option></optgroup><optgroup label='Sweden'>"
            "<option value='sweden-central'>Sweden Central</option></optgroup><optgroup label='Brazil'>"
            "<option value='brazil-south'>Brazil South</option></optgroup><optgroup label='Azure Government'>"
            "<option value='usgov-virginia'>US Gov Virginia</option></optgroup></select>")


def nano_row(regional):
    amounts = "".join("<span data-amount='" + json.dumps({"regional": {slug: value for slug in regional}}) +
                      "'></span>" for value in [0.05, 0.005, 0.4])
    return "<tr><td>GPT-5-nano Global</td><td>Input Cached Input Output" + amounts + "</td></tr>"


def record(definition, region):
    sku, meter = sorted(definition["skus"])[0], sorted(definition["meters"])[0]
    return {"skuName": sku, "meterName": meter, "unitOfMeasure": "1 Hour", "tierMinimumUnits": 0.0,
            "retailPrice": 0.5, "productName": "Product", "meterId": f"{region}-{meter}",
            "effectiveStartDate": "2025-01-01T00:00:00Z", "armRegionName": region,
            "type": "Consumption", "currencyCode": "USD"}


def published_entry(key, regions):
    columns = {"input": 0.05, "cachedInput": 0.005, "output": 0.4} if key == "gpt-5-nano" else {"allocation": 0.0001}
    return {"sourceType": "OfficialPricingPage", "sourceUrl": published.SOURCES[key], "sourceLabel": key,
            "retrievedAt": collector.now(), "sourceRowSha256": "0" * 64,
            "unit": "USD/1M tokens" if key == "gpt-5-nano" else "USD/vCPU-second",
            "prices": {region: dict(columns) for region in regions}}


class CatalogTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.snapshot = json.loads(catalog.CATALOG.read_text(encoding="utf-8"))

    def other_region(self):
        return next(region for region in self.snapshot["data"] if region != "eastus2")

    def test_committed_snapshot(self):
        catalog.validate(self.snapshot)
        self.assertGreater(len(self.snapshot["regions"]), 2)
        self.assertEqual(self.snapshot["defaultRegion"], "eastus2")

    def test_required_region(self):
        for remove in (lambda s: s["data"].pop("eastus2"), lambda s: s["regions"].pop("eastus2")):
            snapshot = copy.deepcopy(self.snapshot)
            remove(snapshot)
            with self.assertRaises(ValueError):
                catalog.validate(snapshot)

    def test_incomplete_service_set(self):
        snapshot = copy.deepcopy(self.snapshot)
        del snapshot["data"]["eastus2"]["hosted"]
        with self.assertRaises(ValueError):
            catalog.validate(snapshot)

    def test_other_regions_may_mark_prices_unavailable(self):
        snapshot = copy.deepcopy(self.snapshot)
        region = self.other_region()
        snapshot["data"][region].pop("firewall", None)
        snapshot["regions"][region]["unavailable"] = sorted(
            set(snapshot["regions"][region].get("unavailable", [])) | {"firewall"})
        catalog.validate(snapshot)
        for marker in (["firewall", "firewall"], ["unknown-service"], "firewall"):
            with self.subTest(marker=marker):
                broken = copy.deepcopy(snapshot)
                broken["regions"][region]["unavailable"] = marker
                with self.assertRaises(ValueError):
                    catalog.validate(broken)

    def test_malformed_region_entries(self):
        for change in (lambda s: s["regions"].__setitem__("East US", {"name": "East", "geography": "US"}),
                       lambda s: s["regions"]["eastus2"].__setitem__("name", ""),
                       lambda s: s["regions"].__setitem__("eastus2", "East US 2"),
                       lambda s: s["data"].__setitem__("nowhere", {})):
            snapshot = copy.deepcopy(self.snapshot)
            change(snapshot)
            with self.assertRaises(ValueError):
                catalog.validate(snapshot)

    def test_invalid_rate_and_provenance(self):
        for index, value in [(PRICE, -1), (PRICE, float("nan")), (PRICE, True), (METER_ID, "")]:
            with self.subTest(index=index, value=value):
                snapshot = copy.deepcopy(self.snapshot)
                snapshot["data"]["eastus2"]["hosted"]["items"][0][index] = value
                with self.assertRaises(ValueError):
                    catalog.validate(snapshot)
        snapshot = copy.deepcopy(self.snapshot)
        snapshot["data"]["eastus2"]["hosted"]["items"][0].append("extra")
        with self.assertRaises(ValueError):
            catalog.validate(snapshot)

    def test_stale_markers_keep_their_original_capture_date(self):
        snapshot = copy.deepcopy(self.snapshot)
        entry = snapshot["data"][self.other_region()]["registry"]
        entry.update(stale=True, retrievedAt=OLD)
        snapshot["publishedPrices"]["gpt-5-nano"].update(stale=True, retrievedAt=OLD)
        catalog.validate(snapshot)
        for stale, captured in [(False, OLD), ("yes", OLD), (True, snapshot["retrievedAt"].replace("20", "21", 1))]:
            with self.subTest(stale=stale, captured=captured):
                broken = copy.deepcopy(snapshot)
                broken["data"][self.other_region()]["registry"].update(stale=stale, retrievedAt=captured)
                with self.assertRaises(ValueError):
                    catalog.validate(broken)

    def test_invalid_candidate_preserves_published_file(self):
        with tempfile.TemporaryDirectory() as directory:
            published_file = Path(directory) / "prices.json"
            published_file.write_text("last known good", encoding="utf-8")
            candidate = Path(directory) / "candidate.json"
            candidate.write_text('{"currency":"EUR"}', encoding="utf-8")
            with self.assertRaises(ValueError):
                catalog.install(candidate, published_file)
            self.assertEqual(published_file.read_text(encoding="utf-8"), "last known good")

    def test_atomic_install_is_valid_json(self):
        with tempfile.TemporaryDirectory() as directory:
            destination = Path(directory) / "prices.json"
            catalog.install(catalog.CATALOG, destination)
            self.assertEqual(json.loads(destination.read_text(encoding="utf-8")), self.snapshot)
            self.assertEqual(list(Path(directory).glob(".prices-*")), [])

    def test_published_sources_fail_closed(self):
        for field, value in [("sourceUrl", "https://example.com/price"), ("unit", "USD/hour"),
                             ("sourceType", "RetailApi")]:
            with self.subTest(field=field):
                snapshot = copy.deepcopy(self.snapshot)
                snapshot["publishedPrices"]["gpt-5-nano"][field] = value
                with self.assertRaises(ValueError):
                    catalog.validate(snapshot)
        snapshot = copy.deepcopy(self.snapshot)
        del snapshot["publishedPrices"]["gpt-5-nano"]["prices"]["eastus2"]
        with self.assertRaises(ValueError):
            catalog.validate(snapshot)

    def test_published_rate_is_not_a_silent_zero(self):
        snapshot = copy.deepcopy(self.snapshot)
        snapshot["publishedPrices"]["acrDedicatedPool"]["prices"]["eastus2"]["allocation"] = 0
        with self.assertRaises(ValueError):
            catalog.validate(snapshot)

    def test_exact_published_row_and_regional_prices(self):
        row = nano_row(["us-east-2", "sweden-central"])
        result = extract(row, "gpt-5-nano", SLUGS)
        self.assertEqual(result["prices"]["eastus2"]["input"], 0.05)
        self.assertEqual(result["prices"]["swedencentral"]["output"], 0.4)
        self.assertNotIn("brazilsouth", result["prices"], "a region without a published rate is omitted, not zero")
        partial = row.replace('"sweden-central": 0.4', '"sweden-central": null')
        for html in [row + row, row.replace("GPT-5-nano", "GPT-5.4-nano"), partial,
                     row.replace("Input Cached Input Output", "Output Cached Input Input")]:
            with self.assertRaises(ValueError):
                extract(html, "gpt-5-nano", SLUGS)

    def test_region_discovery_from_the_official_selector(self):
        regions = published.page_regions(SELECTOR)
        self.assertEqual([region["name"] for region in regions], ["East US 2", "West US", "Sweden Central", "Brazil South"])
        self.assertEqual(published.region_slugs(regions, {"eastus2", "swedencentral", "westus"}),
                         {"eastus2": "us-east-2", "westus": "us-west", "swedencentral": "sweden-central"})
        result = collector.region_catalog({"eastus2", "swedencentral", "brazilsouth", "usgovvirginia"}, regions, {})
        self.assertEqual(list(result), ["brazilsouth", "eastus2", "swedencentral"])
        self.assertEqual(result["swedencentral"], {"name": "Sweden Central", "geography": "Sweden"})

    def test_split_keeps_exact_meters_per_region(self):
        definition = collector.REGIONAL["registry"]
        older = record(definition, "eastus2")
        newer = {**older, "retailPrice": 0.6, "effectiveStartDate": "2026-01-01T00:00:00Z"}
        other = {**record(definition, "westeurope"), "skuName": "Basic"}
        with self.assertLogs(level="WARNING"):
            result = collector.split("registry", definition, [older, newer, other, record(definition, "westeurope")])
        self.assertEqual(sorted(result), ["eastus2", "westeurope"])
        self.assertEqual([row[PRICE] for row in result["eastus2"]], [0.6])
        self.assertEqual(len(result["westeurope"]), 1)

    def synthetic_build(self, failing, previous, gpt_regions=("eastus2", "westeurope")):
        jobs = {("regional", key): d for key, d in collector.REGIONAL.items()}
        jobs.update({("global", key): d for key, d in collector.GLOBAL.items()})
        jobs[("model", "model")] = collector.MODEL
        results, failures = {}, {}
        for job, definition in jobs.items():
            if job in failing:
                failures[job] = HTTPError(collector.BASE, 429, "throttled", {}, None)
                continue
            regions = [definition["region"]] if definition["region"] is not None else ["eastus2", "westeurope"]
            if job == ("regional", "firewall"):
                regions = ["eastus2"]
            results[job] = {"query": collector.url_for(definition["query"]), "retrievedAt": collector.now(),
                            "items": [record(definition, region) for region in regions]}
        pages = [{"slug": "us-east-2", "geography": "United States", "name": "East US 2"},
                 {"slug": "west-europe", "geography": "Europe", "name": "West Europe"}]
        prices = {"gpt-5-nano": published_entry("gpt-5-nano", gpt_regions),
                  "acrDedicatedPool": published_entry("acrDedicatedPool", ["eastus2", "westeurope"])}
        with patch.object(collector, "run_queries", return_value=(jobs, results, failures)), \
                patch.object(collector.published_prices, "collect", return_value=(prices, pages)), \
                self.assertLogs(level="INFO"):
            return collector.build(previous)

    def test_multi_region_build_marks_missing_prices_unavailable(self):
        snapshot = catalog.validate(self.synthetic_build(set(), {}, gpt_regions=["eastus2"]))
        self.assertEqual(snapshot["regions"]["westeurope"]["name"], "West Europe")
        self.assertEqual(snapshot["regions"]["westeurope"]["unavailable"], ["firewall", "gpt-5-nano"])
        self.assertNotIn("unavailable", snapshot["regions"]["eastus2"])
        self.assertNotIn("firewall", snapshot["data"]["westeurope"])

    def test_failed_source_reuses_last_validated_regional_data(self):
        previous = copy.deepcopy(self.snapshot)
        previous["retrievedAt"] = OLD
        for entry in previous["data"]["eastus2"].values():
            entry["retrievedAt"] = OLD
        snapshot = catalog.validate(self.synthetic_build({("regional", "hosted")}, previous))
        reused = snapshot["data"]["eastus2"]["hosted"]
        self.assertTrue(reused["stale"])
        self.assertEqual(reused["retrievedAt"], OLD)
        self.assertEqual(reused["items"], self.snapshot["data"]["eastus2"]["hosted"]["items"])
        self.assertNotIn("stale", snapshot["data"]["eastus2"]["registry"])

    def test_default_region_without_fallback_fails_the_run(self):
        with self.assertRaisesRegex(RuntimeError, "eastus2 is missing: hosted"):
            self.synthetic_build({("regional", "hosted")}, {})
        failing = {("regional", key) for key in list(collector.REGIONAL)[:12]}
        with self.assertRaisesRegex(RuntimeError, "price sources failed"):
            self.synthetic_build(failing, self.snapshot)

    def test_published_page_failure_reuses_validated_rates(self):
        previous = {"gpt-5-nano": {**published_entry("gpt-5-nano", ["eastus2"]), "retrievedAt": OLD}}
        acr = "<tr><td>Dedicated agent pool</td><td>per second of instance allocation<span data-amount='" + \
            json.dumps({"regional": {"us-east-2": 0.0001}}) + "'></span></td></tr>"
        responses = {published.SOURCES["gpt-5-nano"]: HTTPError("x", 404, "gone", {}, None),
                     published.SOURCES["acrDedicatedPool"]: SELECTOR + acr}

        def read(url):
            value = responses[url]
            if isinstance(value, Exception):
                raise value
            return value
        with patch.object(published, "read_source", side_effect=read), self.assertLogs(level="ERROR"):
            result, regions = published.collect({"eastus2", "swedencentral"}, previous)
        self.assertTrue(result["gpt-5-nano"]["stale"])
        self.assertEqual(result["gpt-5-nano"]["retrievedAt"], OLD)
        self.assertEqual(result["acrDedicatedPool"]["prices"], {"eastus2": {"allocation": 0.0001}})
        self.assertIn("Sweden Central", [region["name"] for region in regions])
        with patch.object(published, "read_source", side_effect=read), self.assertRaises(HTTPError):
            published.collect({"eastus2"}, None)

    def test_collection_retries_throttling_without_touching_published_prices(self):
        response = io.BytesIO(b'{"Items":[],"NextPageLink":null}')
        response.geturl = lambda: collector.BASE
        throttled = HTTPError(collector.BASE, 429, "throttled", {"Retry-After": "0"}, None)
        with patch.object(published.urllib.request, "urlopen", side_effect=[throttled, response]) as request, \
                patch.object(published.time, "sleep") as sleep, self.assertLogs(level="WARNING"):
            result = collector.fetch("serviceName eq 'Foundry Tools'")
        self.assertEqual(result["items"], [])
        self.assertEqual(request.call_count, 2)
        sleep.assert_called_once_with(0)

    def test_collection_has_a_bounded_retry_limit(self):
        unavailable = HTTPError(collector.BASE, 503, "unavailable", {}, None)
        with patch.object(published.urllib.request, "urlopen", side_effect=unavailable) as request, \
                patch.object(published.time, "sleep"), self.assertLogs(level="WARNING"):
            with self.assertRaises(HTTPError):
                collector.fetch("serviceName eq 'Foundry Tools'")
        self.assertEqual(request.call_count, 6)

    def test_collection_rejects_non_official_pagination(self):
        response = io.BytesIO(b'{"Items":[],"NextPageLink":"https://example.com/prices"}')
        response.geturl = lambda: collector.BASE
        with patch.object(published.urllib.request, "urlopen", return_value=response):
            with self.assertRaisesRegex(ValueError, "pagination source"):
                collector.fetch("serviceName eq 'Foundry Tools'")

    def test_published_collection_retries_a_read_timeout(self):
        url = published.SOURCES["gpt-5-nano"]
        html = (SELECTOR + nano_row(["us-east-2", "sweden-central"])).encode()
        interrupted = io.BytesIO(b"")
        interrupted.geturl = lambda: url
        response = io.BytesIO(html)
        response.geturl = lambda: url
        with patch.dict(published.SOURCES, {"gpt-5-nano": url}, clear=True), \
                patch.object(interrupted, "read", side_effect=TimeoutError("The read operation timed out")), \
                patch.object(published.urllib.request, "urlopen", side_effect=[interrupted, response]) as request, \
                patch.object(published.random, "random", return_value=0), \
                patch.object(published.time, "sleep") as sleep, self.assertLogs(level="WARNING"):
            result, regions = published.collect({"eastus2", "swedencentral"})
        self.assertEqual(result["gpt-5-nano"]["prices"]["eastus2"]["input"], 0.05)
        self.assertEqual(sorted(result["gpt-5-nano"]["prices"]), ["eastus2", "swedencentral"])
        self.assertEqual(len(regions), 4)
        self.assertEqual(request.call_count, 2)
        self.assertTrue(interrupted.closed)
        sleep.assert_called_once_with(10)

    def test_official_sources_retry_only_transient_request_errors(self):
        url = published.SOURCES["gpt-5-nano"]
        errors = [TimeoutError("timeout"), URLError("connection interrupted"),
                  ConnectionResetError("connection reset"), http.client.IncompleteRead(b"partial", 100)]
        errors.extend(HTTPError(url, code, "temporary", {"Retry-After": "0"}, None)
                      for code in (408, 429, 500, 502, 503, 504))
        for error in errors:
            response = io.BytesIO(b"official source")
            response.geturl = lambda: url
            with self.subTest(error=error), \
                    patch.object(published.urllib.request, "urlopen", side_effect=[error, response]) as request, \
                    patch.object(published.random, "random", return_value=0), \
                    patch.object(published.time, "sleep") as sleep, self.assertLogs(level="WARNING"):
                self.assertEqual(published.read_source(url), "official source")
                self.assertEqual(request.call_count, 2)
                self.assertEqual(request.call_args.kwargs["timeout"], 90)
                sleep.assert_called_once_with(0 if isinstance(error, HTTPError) else 10)

        for code in (400, 401, 403, 404):
            error = HTTPError(url, code, "permanent", {}, None)
            with self.subTest(code=code), \
                    patch.object(published.urllib.request, "urlopen", side_effect=error) as request, \
                    patch.object(published.time, "sleep") as sleep:
                with self.assertRaises(HTTPError):
                    published.read_source(url)
                self.assertEqual(request.call_count, 1)
                sleep.assert_not_called()

    def test_official_source_timeout_retries_back_off_exponentially_and_are_logged(self):
        before = catalog.CATALOG.read_bytes()
        with patch.object(published.urllib.request, "urlopen", side_effect=TimeoutError("timeout")) as request, \
                patch.object(published.random, "random", return_value=0), \
                patch.object(published.time, "sleep") as sleep, self.assertLogs(level="WARNING") as logs:
            with self.assertRaises(TimeoutError):
                published.collect({"eastus2"})
        self.assertEqual(request.call_count, 6)
        self.assertEqual([call.args[0] for call in sleep.call_args_list], [10, 20, 40, 80, 120])
        self.assertTrue(any("ERROR" in entry and "6 attempts" in entry for entry in logs.output))
        self.assertEqual(catalog.CATALOG.read_bytes(), before)

    def test_backoff_jitter_is_bounded(self):
        for attempt, base in enumerate([10, 20, 40, 80, 120, 120]):
            with patch.object(published.random, "random", return_value=1):
                self.assertEqual(published.backoff(attempt), base * 1.25)

    def test_official_source_retry_after_is_capped(self):
        url = published.SOURCES["gpt-5-nano"]
        response = io.BytesIO(b"official source")
        response.geturl = lambda: url
        error = HTTPError(url, 429, "throttled", {"Retry-After": "9999"}, None)
        with patch.object(published.urllib.request, "urlopen", side_effect=[error, response]), \
                patch.object(published.time, "sleep") as sleep, self.assertLogs(level="WARNING"):
            self.assertEqual(published.read_source(url), "official source")
        sleep.assert_called_once_with(120)

    def test_official_source_validation_is_not_retried(self):
        url = published.SOURCES["gpt-5-nano"]
        cases = [
            ("https://example.com/prices", b"page"),
            ("http://azure.microsoft.com/prices", b"page"),
            ("https://azure.microsoft.com:444/prices", b"page"),
            ("https://user@azure.microsoft.com/prices", b"page"),
            (url, b"x" * 10_000_001),
            (url, b"\xff"),
        ]
        for target, body in cases:
            response = io.BytesIO(body)
            response.geturl = lambda: target
            with self.subTest(target=target, size=len(body)), \
                    patch.object(published.urllib.request, "urlopen", return_value=response) as request, \
                    patch.object(published.time, "sleep") as sleep:
                with self.assertRaises(ValueError):
                    published.read_source(url)
                self.assertEqual(request.call_count, 1)
                sleep.assert_not_called()

    def test_collection_retries_only_the_interrupted_api_page(self):
        following = collector.BASE + "?$skip=100"
        first = io.BytesIO(json.dumps({"Items": [{"meterId": "first"}], "NextPageLink": following}).encode())
        first.geturl = lambda: collector.BASE
        interrupted = io.BytesIO(b"partial")
        interrupted.geturl = lambda: following
        final = io.BytesIO(b'{"Items":[{"meterId":"second"}],"NextPageLink":null}')
        final.geturl = lambda: following
        with patch.object(interrupted, "read", side_effect=TimeoutError("read timed out")), \
                patch.object(published.urllib.request, "urlopen", side_effect=[first, interrupted, final]) as request, \
                patch.object(published.random, "random", return_value=0), \
                patch.object(published.time, "sleep") as sleep, self.assertLogs(level="WARNING"):
            result = collector.fetch("serviceName eq 'Foundry Tools'")
        self.assertEqual([item["meterId"] for item in result["items"]], ["first", "second"])
        self.assertEqual(request.call_count, 3)
        self.assertEqual([call.args[0].full_url for call in request.call_args_list[1:]], [following, following])
        self.assertTrue(interrupted.closed)
        sleep.assert_called_once_with(10)

    def test_collection_never_retries_malformed_source_json(self):
        response = io.BytesIO(b'{"Items":')
        response.geturl = lambda: collector.BASE
        with patch.object(published.urllib.request, "urlopen", return_value=response) as request, \
                patch.object(published.time, "sleep") as sleep:
            with self.assertRaises(json.JSONDecodeError):
                collector.fetch("serviceName eq 'Foundry Tools'")
        self.assertEqual(request.call_count, 1)
        sleep.assert_not_called()


if __name__ == "__main__":
    unittest.main()
