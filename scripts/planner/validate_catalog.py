"""Validate a structurally complete price snapshot before replacing the published catalog."""

import argparse
import datetime
import json
import math
import os
import re
from pathlib import Path
import tempfile
from urllib.parse import urlparse


ROOT = Path(__file__).resolve().parents[2]
CATALOG = ROOT / "docs" / "data" / "planner" / "prices.json"


def timestamp(value):
    if not isinstance(value, str):
        raise ValueError("A source capture timestamp is required")
    result = datetime.datetime.fromisoformat(value.replace("Z", "+00:00"))
    if result.tzinfo is None or result > datetime.datetime.now(datetime.timezone.utc) + datetime.timedelta(minutes=5):
        raise ValueError("Capture timestamps must be timezone-aware and not in the future")
    return result


FIELDS = ["skuName", "meterName", "unitOfMeasure", "tierMinimumUnits", "retailPrice", "productName",
          "meterId", "effectiveStartDate"]
TEXT_FIELDS = ("skuName", "meterName", "unitOfMeasure", "productName", "meterId")
REGIONAL = {"search", "firewall", "registry", "storage", "logs", "compute", "appconfig", "appgateway",
            "publicip", "apim", "cosmos", "vault", "bastion", "vm", "disk", "embedding", "hosted"}
GLOBAL = {"dns": "", "nat": "Global", "private": "Global"}
DEFAULT_REGION = "eastus2"
UNAVAILABLE = REGIONAL | {"model", "gpt-5-nano", "acrDedicatedPool"}


def official(query, name):
    parsed = urlparse(query) if isinstance(query, str) else None
    if not parsed or parsed.scheme != "https" or parsed.hostname != "prices.azure.com" or parsed.username or \
            parsed.password or parsed.port not in {None, 443}:
        raise ValueError(f"{name}: expected the official Retail Prices API source")


def positive(value, name, *, allow_zero=True):
    if isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(value) or \
            value < 0 or (not allow_zero and value == 0):
        raise ValueError(f"{name} must be a finite {'nonnegative' if allow_zero else 'positive'} number")


def freshness(entry, name, captured):
    """Stale entries reuse validated data and keep their original, earlier capture date."""
    when = timestamp(entry.get("retrievedAt"))
    if "stale" in entry and entry["stale"] is not True:
        raise ValueError(f"{name}: stale markers must be true when present")
    if entry.get("stale") and when > captured:
        raise ValueError(f"{name}: stale data must keep its original capture date")


def validate(snapshot):
    if not isinstance(snapshot, dict) or snapshot.get("currency") != "USD":
        raise ValueError("The catalog must declare USD")
    if snapshot.get("schemaVersion") != 2 or snapshot.get("fields") != FIELDS:
        raise ValueError("Expected the compact schema version 2 record layout")
    captured = timestamp(snapshot.get("retrievedAt"))
    regions = snapshot.get("regions")
    if not isinstance(regions, dict) or len(regions) < 2:
        raise ValueError("At least two priced regions are required")
    if snapshot.get("defaultRegion") != DEFAULT_REGION or DEFAULT_REGION not in regions:
        raise ValueError(f"The default region {DEFAULT_REGION} is required")
    for region, meta in regions.items():
        if not re.fullmatch(r"[a-z0-9]+", region) or not isinstance(meta, dict):
            raise ValueError(f"{region}: malformed region entry")
        for key in ("name", "geography"):
            if not isinstance(meta.get(key), str) or not meta[key].strip():
                raise ValueError(f"{region}: a display {key} is required")
        unavailable = meta.get("unavailable", [])
        if not isinstance(unavailable, list) or not set(unavailable) <= UNAVAILABLE or \
                len(set(unavailable)) != len(unavailable):
            raise ValueError(f"{region}: unavailable markers must list known price sources")
    queries = snapshot.get("queries")
    if not isinstance(queries, dict) or set(queries) != REGIONAL | set(GLOBAL):
        raise ValueError("Each regional and global price query must be recorded")
    for service, query in queries.items():
        official(query, f"queries/{service}")
    data = snapshot.get("data")
    if not isinstance(data, dict) or not set(data) <= set(regions):
        raise ValueError("Service catalogs must belong to a listed region")
    if not REGIONAL <= set(data.get(DEFAULT_REGION, {})):
        raise ValueError(f"{DEFAULT_REGION}: every required service catalog is required")
    for region, services in data.items():
        if not isinstance(services, dict) or not set(services) <= REGIONAL:
            raise ValueError(f"{region}: unexpected service catalog")
        for service, entry in services.items():
            validate_entry(entry, f"{region}/{service}", captured)
            if not entry["items"]:
                raise ValueError(f"{region}/{service}: omit services without records")
    for service, region in GLOBAL.items():
        entry = (snapshot.get("global") or {}).get(service)
        validate_entry(entry, f"global/{service}", captured)
        if entry.get("armRegionName") != region or not entry["items"]:
            raise ValueError(f"global/{service}: expected {region or 'unscoped'} billing records")
    models = snapshot.get("modelDiscovery")
    if not isinstance(models, dict) or not isinstance(models.get("items"), dict) or \
            not set(models["items"]) <= set(regions):
        raise ValueError("modelDiscovery: expected regional model records")
    official(models.get("query"), "modelDiscovery")
    freshness(models, "modelDiscovery", captured)
    for region, items in models["items"].items():
        validate_items(items, f"modelDiscovery/{region}")
    published = snapshot.get("publishedPrices", {})
    from published_prices import SOURCES
    if set(published) != set(SOURCES):
        raise ValueError("The default model and dedicated-pool official prices are required")
    for key, entry in published.items():
        freshness(entry, key, captured)
        if entry.get("sourceType") != "OfficialPricingPage" or entry.get("sourceUrl") != SOURCES[key]:
            raise ValueError(f"{key}: expected the exact official published source")
        prices = entry.get("prices")
        if not isinstance(prices, dict) or not set(prices) <= set(regions) or DEFAULT_REGION not in prices:
            raise ValueError(f"{key}: published prices must cover the default region and only listed regions")
        expected = {"input", "cachedInput", "output"} if key == "gpt-5-nano" else {"allocation"}
        if entry.get("unit") != ("USD/1M tokens" if key == "gpt-5-nano" else "USD/vCPU-second"):
            raise ValueError(f"{key}: unexpected published billing unit")
        for region, values in prices.items():
            if not isinstance(values, dict) or set(values) != expected:
                raise ValueError(f"{key}/{region}: unexpected published rate columns")
            for value in values.values():
                positive(value, f"{key}/{region}: a published rate", allow_zero=False)
    return snapshot


def validate_entry(entry, name, captured):
    if not isinstance(entry, dict) or not isinstance(entry.get("items"), list):
        raise ValueError(f"{name}: expected an auditable record set")
    freshness(entry, name, captured)
    if "query" in entry:
        official(entry["query"], name)
    validate_items(entry["items"], name)


def validate_items(items, name):
    if not isinstance(items, list):
        raise ValueError(f"{name}: expected records")
    for item in items:
        if not isinstance(item, list) or len(item) != len(FIELDS):
            raise ValueError(f"{name}: records must follow the declared fields")
        record = dict(zip(FIELDS, item))
        for key in TEXT_FIELDS:
            if not isinstance(record[key], str) or not record[key]:
                raise ValueError(f"{name}: missing {key}")
        if not isinstance(record["effectiveStartDate"], str):
            raise ValueError(f"{name}: missing effectiveStartDate")
        for key in ("retailPrice", "tierMinimumUnits"):
            positive(record[key], f"{name}: {key}")


def install(source, destination=CATALOG):
    snapshot = validate(json.loads(Path(source).read_text(encoding="utf-8")))
    destination = Path(destination)
    destination.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary = tempfile.mkstemp(prefix=".prices-", suffix=".json", dir=destination.parent)
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8", newline="\n") as stream:
            json.dump(snapshot, stream, ensure_ascii=True, separators=(",", ":"), allow_nan=False)
            stream.write("\n")
        os.replace(temporary, destination)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("catalog", nargs="?", type=Path, default=CATALOG)
    parser.add_argument("--install", action="store_true", help="Atomically install a previously browser-validated candidate")
    args = parser.parse_args()
    if args.install:
        install(args.catalog)
    else:
        validate(json.loads(args.catalog.read_text(encoding="utf-8")))
    print("Price catalog schema and source provenance validated")


if __name__ == "__main__":
    main()
