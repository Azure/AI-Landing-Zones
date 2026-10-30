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
        response.geturl = lambda: collector.BASE
        throttled = HTTPError(collector.BASE, 429, "throttled", {"Retry-After": "0"}, None)
        with patch.object(published.urllib.request, "urlopen", side_effect=[throttled, response]) as request, \
                patch.object(published.time, "sleep") as sleep:
            result = collector.fetch("serviceName eq 'Foundry Tools'")
        self.assertEqual(result["items"], [])
        self.assertEqual(request.call_count, 2)
        sleep.assert_called_once_with(0)

    def test_collection_has_a_bounded_retry_limit(self):
        unavailable = HTTPError(collector.BASE, 503, "unavailable", {}, None)
        with patch.object(published.urllib.request, "urlopen", side_effect=unavailable) as request, \
                patch.object(published.time, "sleep"):
            with self.assertRaises(HTTPError):
                collector.fetch("serviceName eq 'Foundry Tools'")
        self.assertEqual(request.call_count, 4)

    def test_collection_rejects_non_official_pagination(self):
        response = io.BytesIO(b'{"Items":[],"NextPageLink":"https://example.com/prices"}')
        response.geturl = lambda: collector.BASE
        with patch.object(published.urllib.request, "urlopen", return_value=response):
            with self.assertRaisesRegex(ValueError, "pagination source"):
                collector.fetch("serviceName eq 'Foundry Tools'")

    def test_published_collection_retries_a_read_timeout(self):
        url = published.SOURCES["gpt-5-nano"]
        amounts = "".join("<span data-amount='" + json.dumps(
            {"regional": {region: value for region in published.REGIONS.values()}}) + "'></span>"
            for value in [0.05, 0.005, 0.4])
        html = ("<tr><td>GPT-5-nano Global</td><td>Input Cached Input Output" + amounts + "</td></tr>").encode()
        interrupted = io.BytesIO(b"")
        interrupted.geturl = lambda: url
        response = io.BytesIO(html)
        response.geturl = lambda: url
        with patch.dict(published.SOURCES, {"gpt-5-nano": url}, clear=True), \
                patch.object(interrupted, "read", side_effect=TimeoutError("The read operation timed out")), \
                patch.object(published.urllib.request, "urlopen", side_effect=[interrupted, response]) as request, \
                patch.object(published.time, "sleep") as sleep, self.assertLogs(level="WARNING"):
            result = published.collect()
        self.assertEqual(result["gpt-5-nano"]["prices"]["eastus2"]["input"], 0.05)
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

    def test_official_source_timeout_retries_are_bounded_and_logged(self):
        before = catalog.CATALOG.read_bytes()
        with patch.object(published.urllib.request, "urlopen", side_effect=TimeoutError("timeout")) as request, \
                patch.object(published.time, "sleep") as sleep, self.assertLogs(level="WARNING") as logs:
            with self.assertRaises(TimeoutError):
                published.collect()
        self.assertEqual(request.call_count, 4)
        self.assertEqual([call.args[0] for call in sleep.call_args_list], [10, 20, 30])
        self.assertTrue(any("ERROR" in entry and "4 attempts" in entry for entry in logs.output))
        self.assertEqual(catalog.CATALOG.read_bytes(), before)

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
