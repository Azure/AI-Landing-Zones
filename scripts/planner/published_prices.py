"""Read exact, independently published prices absent from the Retail Prices API."""

import datetime
import hashlib
import http.client
from html.parser import HTMLParser
import json
import logging
import math
import time
import urllib.error
import urllib.parse
import urllib.request


REGIONS = {"eastus2": "us-east-2", "swedencentral": "sweden-central"}
SOURCES = {
    "gpt-5-nano": "https://azure.microsoft.com/en-us/pricing/details/azure-openai/",
    "acrDedicatedPool": "https://azure.microsoft.com/en-us/pricing/details/container-registry/",
}


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


def extract(html, key):
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
    for region, source_region in REGIONS.items():
        prices[region] = {}
        for name, amount in zip(names, row["amounts"]):
            value = amount.get("regional", {}).get(source_region)
            if isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(value) or value <= 0:
                raise ValueError(f"{key}/{region}/{name}: a positive published rate is required")
            prices[region][name] = value
    return {
        "sourceType": "OfficialPricingPage",
        "sourceUrl": SOURCES[key],
        "sourceLabel": label,
        "retrievedAt": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "sourceRowSha256": hashlib.sha256(json.dumps(row, sort_keys=True).encode()).hexdigest(),
        "unit": "USD/1M tokens" if key == "gpt-5-nano" else "USD/vCPU-second",
        "prices": prices,
    }


def read_source(url, *, expected_host="azure.microsoft.com"):
    request = urllib.request.Request(url, headers={
        "User-Agent": "AgentLandingZone-PriceCatalog/1.0",
        "Accept": "application/json" if expected_host == "prices.azure.com" else "text/html",
    })
    for attempt in range(4):
        try:
            with urllib.request.urlopen(request, timeout=90) as response:
                target = urllib.parse.urlparse(response.geturl())
                if target.scheme != "https" or target.hostname != expected_host or target.username or \
                        target.password or target.port not in {None, 443}:
                    raise ValueError("Unexpected official-source redirect")
                raw = response.read(10_000_001)
            if len(raw) > 10_000_000:
                raise ValueError("Unexpected official-source size")
            return raw.decode("utf-8")
        except (urllib.error.URLError, TimeoutError, ConnectionError, http.client.IncompleteRead) as error:
            if isinstance(error, urllib.error.HTTPError) and error.code not in {408, 429, 500, 502, 503, 504}:
                raise
            if attempt == 3:
                logging.error("Official source %s unavailable after 4 attempts: %s", request.full_url, error)
                raise
            retry_after = (error.headers or {}).get("Retry-After", "") \
                if isinstance(error, urllib.error.HTTPError) else ""
            wait = min(int(retry_after), 120) if retry_after.isdigit() else 10 * (attempt + 1)
            logging.warning("Official source %s unavailable (%s), retrying in %s seconds (attempt %s/4)",
                            request.full_url, error, wait, attempt + 2)
            time.sleep(wait)


def collect():
    return {key: extract(read_source(url), key) for key, url in SOURCES.items()}
