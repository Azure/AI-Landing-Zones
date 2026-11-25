"""Read exact, independently published prices absent from the Retail Prices API."""

import datetime
import hashlib
import http.client
from html.parser import HTMLParser
import json
import logging
import math
import random
import re
import time
import urllib.error
import urllib.parse
import urllib.request


SOURCES = {
    "gpt-5-nano": "https://azure.microsoft.com/en-us/pricing/details/azure-openai/",
    "acrDedicatedPool": "https://azure.microsoft.com/en-us/pricing/details/container-registry/",
}


ATTEMPTS = 6
TIMEOUT = 90
MAX_WAIT = 120
TRANSIENT = {408, 429, 500, 502, 503, 504}
EXCLUDED_GEOGRAPHIES = {"Azure Government"}
STATS = {"requests": 0}


def normalize(value):
    return re.sub(r"[^a-z0-9]", "", value.lower())


class RegionOptions(HTMLParser):
    """Read the public region selector shared by Azure pricing pages."""

    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.inside = False
        self.group = None
        self.option = None
        self.regions = []

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag == "select" and attrs.get("id") == "region-selector":
            self.inside = True
        elif self.inside and tag == "optgroup":
            self.group = attrs.get("label")
        elif self.inside and tag == "option" and attrs.get("value"):
            self.option = {"slug": attrs["value"], "geography": self.group, "text": []}

    def handle_data(self, data):
        if self.option is not None:
            self.option["text"].append(data)

    def handle_endtag(self, tag):
        if tag == "option" and self.option is not None:
            name = " ".join(" ".join(self.option.pop("text")).split())
            if name and self.option["geography"] and self.option["geography"] not in EXCLUDED_GEOGRAPHIES:
                self.regions.append({**self.option, "name": name})
            self.option = None
        elif tag == "optgroup":
            self.group = None
        elif tag == "select":
            self.inside = False


def page_regions(html):
    """Public commercial regions offered by an official pricing page, without Azure Government."""
    parser = RegionOptions()
    parser.feed(html)
    return parser.regions


def region_slugs(regions, arm_regions):
    """Map pricing-page slugs to Retail API armRegionName values by their display names."""
    mapping = {}
    for region in regions:
        for candidate in (normalize(region["name"]), normalize(region["slug"])):
            if candidate in arm_regions:
                mapping[candidate] = region["slug"]
                break
    return mapping


class PriceRows(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.rows = []
        self.row = None
        self.cell = None

    def handle_starttag(self, tag, attrs):
        if tag == "tr":
            self.row = {"cells": [], "amounts": []}
        elif tag in {"td", "th"} and self.row is not None:
            self.cell = []
        if self.row is not None:
            amount = dict(attrs).get("data-amount")
            if amount is not None:
                self.row["amounts"].append(json.loads(amount))

    def handle_data(self, data):
        if self.cell is not None:
            self.cell.append(data)

    def handle_endtag(self, tag):
        if tag in {"td", "th"} and self.row is not None and self.cell is not None:
            self.row["cells"].append(" ".join(" ".join(self.cell).split()))
            self.cell = None
        elif tag == "tr" and self.row is not None:
            self.rows.append(self.row)
            self.row = None
            self.cell = None


def extract(html, key, slugs):
    parser = PriceRows()
    parser.feed(html)
    label = "GPT-5-nano Global" if key == "gpt-5-nano" else "Dedicated agent pool"
    matches = [row for row in parser.rows if row["cells"] and row["cells"][0] == label]
    if len(matches) != 1:
        raise ValueError(f"{key}: the exact official pricing row must match once, found {len(matches)}")
    row = matches[0]
    names = ["input", "cachedInput", "output"] if key == "gpt-5-nano" else ["allocation"]
    if len(row["amounts"]) != len(names):
        raise ValueError(f"{key}: published rate columns changed")
    if key == "gpt-5-nano":
        positions = [row["cells"][1].find(word) for word in ("Input", "Cached Input", "Output")]
        if min(positions) < 0 or positions != sorted(positions) or len(set(positions)) != 3:
            raise ValueError("The GPT-5-nano input/cached/output column ordering changed")
    if key == "acrDedicatedPool" and "second of instance allocation" not in " ".join(row["cells"]):
        raise ValueError("The dedicated-pool allocation billing unit changed")
    prices = {}
    for region, source_region in sorted(slugs.items()):
        values = {name: amount.get("regional", {}).get(source_region) for name, amount in zip(names, row["amounts"])}
        if all(value is None for value in values.values()):
            continue
        for name, value in values.items():
            if isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(value) or value <= 0:
                raise ValueError(f"{key}/{region}/{name}: a positive published rate is required")
        prices[region] = values
    return {
        "sourceType": "OfficialPricingPage",
        "sourceUrl": SOURCES[key],
        "sourceLabel": label,
        "retrievedAt": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "sourceRowSha256": hashlib.sha256(json.dumps(row, sort_keys=True).encode()).hexdigest(),
        "unit": "USD/1M tokens" if key == "gpt-5-nano" else "USD/vCPU-second",
        "prices": prices,
    }


def backoff(attempt):
    """Exponential backoff with up to 25% added jitter: 10, 20, 40, 80 then 120 seconds."""
    base = min(10 * 2 ** attempt, MAX_WAIT)
    return round(base * (1 + 0.25 * random.random()), 1)


def read_source(url, *, expected_host="azure.microsoft.com"):
    request = urllib.request.Request(url, headers={
        "User-Agent": "AgentLandingZone-PriceCatalog/1.0",
        "Accept": "application/json" if expected_host == "prices.azure.com" else "text/html",
    })
    for attempt in range(ATTEMPTS):
        STATS["requests"] += 1
        try:
            with urllib.request.urlopen(request, timeout=TIMEOUT) as response:
                target = urllib.parse.urlparse(response.geturl())
                if target.scheme != "https" or target.hostname != expected_host or target.username or \
                        target.password or target.port not in {None, 443}:
                    raise ValueError("Unexpected official-source redirect")
                raw = response.read(10_000_001)
            if len(raw) > 10_000_000:
                raise ValueError("Unexpected official-source size")
            return raw.decode("utf-8")
        except (urllib.error.URLError, TimeoutError, ConnectionError, http.client.IncompleteRead) as error:
            if isinstance(error, urllib.error.HTTPError) and error.code not in TRANSIENT:
                raise
            if attempt == ATTEMPTS - 1:
                logging.error("Official source %s unavailable after %s attempts: %s", request.full_url, ATTEMPTS, error)
                raise
            retry_after = (error.headers or {}).get("Retry-After", "") \
                if isinstance(error, urllib.error.HTTPError) else ""
            wait = min(int(retry_after), MAX_WAIT) if retry_after.isdigit() else backoff(attempt)
            logging.warning("Official source %s unavailable (%s), retrying in %s seconds (attempt %s/%s)",
                            request.full_url, error, wait, attempt + 2, ATTEMPTS)
            time.sleep(wait)


def collect(arm_regions, previous=None):
    """Read each official row once. Regions without a published rate are omitted, not zero-priced.

    Returns (published prices, public region metadata). A failed page reuses the previous
    validated entry, marked stale with its original capture date, when one exists.
    """
    results, regions = {}, {}
    for key, url in SOURCES.items():
        try:
            html = read_source(url)
            offered = page_regions(html)
            for region in offered:
                regions.setdefault(region["slug"], region)
            results[key] = extract(html, key, region_slugs(offered, arm_regions))
            logging.info("published/%s: %s regional rates", key, len(results[key]["prices"]))
        except Exception as error:  # noqa: BLE001 - every failure is either replaced by stale data or re-raised
            fallback = (previous or {}).get(key)
            if not fallback:
                raise
            logging.error("published/%s failed (%s). Reusing the validated rates captured %s.",
                          key, error, fallback.get("retrievedAt"))
            results[key] = {**fallback, "stale": True}
    return results, list(regions.values())
