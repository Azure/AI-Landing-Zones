"""Contract failures must never overwrite the last validated public catalog."""

import copy
import io
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch
from urllib.error import HTTPError


ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts" / "planner"))
import validate_catalog as catalog
import collect_prices as collector
from published_prices import extract


class CatalogTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.snapshot = json.loads(catalog.CATALOG.read_text(encoding="utf-8"))

    def test_committed_snapshot(self):
        catalog.validate(self.snapshot)

    def test_required_region(self):
        snapshot = copy.deepcopy(self.snapshot)
        del snapshot["data"]["eastus2"]
        with self.assertRaises(ValueError):
            catalog.validate(snapshot)

    def test_incomplete_service_set(self):
        snapshot = copy.deepcopy(self.snapshot)
        del snapshot["data"]["eastus2"]["hosted"]
        with self.assertRaises(ValueError):
            catalog.validate(snapshot)

    def test_invalid_rate_and_provenance(self):
        for field, value in [("retailPrice", -1), ("retailPrice", float("nan")),
                             ("retailPrice", True), ("currencyCode", "EUR"), ("meterId", "")]:
            with self.subTest(field=field, value=value):
                snapshot = copy.deepcopy(self.snapshot)
                snapshot["data"]["eastus2"]["hosted"]["items"][0][field] = value
                with self.assertRaises(ValueError):
                    catalog.validate(snapshot)

    def test_invalid_candidate_preserves_published_file(self):
        with tempfile.TemporaryDirectory() as directory:
            published = Path(directory) / "prices.json"
            published.write_text("last known good", encoding="utf-8")
            candidate = Path(directory) / "candidate.json"
            candidate.write_text('{"currency":"EUR"}', encoding="utf-8")
            with self.assertRaises(ValueError):
                catalog.install(candidate, published)
            self.assertEqual(published.read_text(encoding="utf-8"), "last known good")

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

    def test_published_rate_is_not_a_silent_zero(self):
        snapshot = copy.deepcopy(self.snapshot)
        snapshot["publishedPrices"]["acrDedicatedPool"]["prices"]["eastus2"]["allocation"] = 0
        with self.assertRaises(ValueError):
            catalog.validate(snapshot)

    def test_exact_published_row_and_regional_prices(self):
        rates = [0.05, 0.005, 0.4]
        amounts = "".join("<span data-amount='" + json.dumps(
            {"regional": {"us-east-2": value, "sweden-central": value}}) + "'></span>" for value in rates)
        row = "<tr><td>GPT-5-nano Global</td><td>Input Cached Input Output" + amounts + "</td></tr>"
        result = extract(row, "gpt-5-nano")
        self.assertEqual(result["prices"]["eastus2"]["input"], 0.05)
        self.assertEqual(result["prices"]["swedencentral"]["output"], 0.4)
        for html in [row + row, row.replace("GPT-5-nano", "GPT-5.4-nano"),
                     row.replace("sweden-central", "another-region"),
                     row.replace("Input Cached Input Output", "Output Cached Input Input")]:
            with self.assertRaises(ValueError):
                extract(html, "gpt-5-nano")

    def test_collection_retries_throttling_without_touching_published_prices(self):
        response = io.BytesIO(b'{"Items":[],"NextPageLink":null}')
        throttled = HTTPError(collector.BASE, 429, "throttled", {"Retry-After": "0"}, None)
        with patch.object(collector.urllib.request, "urlopen", side_effect=[throttled, response]) as request, \
                patch.object(collector.time, "sleep") as sleep:
            result = collector.fetch("serviceName eq 'Foundry Tools'")
        self.assertEqual(result["items"], [])
        self.assertEqual(request.call_count, 2)
        sleep.assert_called_once_with(0)

    def test_collection_has_a_bounded_retry_limit(self):
        unavailable = HTTPError(collector.BASE, 503, "unavailable", {}, None)
        with patch.object(collector.urllib.request, "urlopen", side_effect=unavailable) as request, \
                patch.object(collector.time, "sleep"):
            with self.assertRaises(HTTPError):
                collector.fetch("serviceName eq 'Foundry Tools'")
        self.assertEqual(request.call_count, 4)

    def test_collection_rejects_non_official_pagination(self):
        response = io.BytesIO(b'{"Items":[],"NextPageLink":"https://example.com/prices"}')
        with patch.object(collector.urllib.request, "urlopen", return_value=response):
            with self.assertRaisesRegex(ValueError, "pagination source"):
                collector.fetch("serviceName eq 'Foundry Tools'")


if __name__ == "__main__":
    unittest.main()
