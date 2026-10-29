"""Validate a complete price snapshot before replacing the published catalog."""

import argparse
import datetime
import json
import math
import os
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


def validate(snapshot):
    if not isinstance(snapshot, dict) or snapshot.get("currency") != "USD":
        raise ValueError("The catalog must declare USD")
    timestamp(snapshot.get("retrievedAt"))
    regions = snapshot.get("regions")
    if not isinstance(regions, dict) or set(regions) != {"eastus2", "swedencentral"}:
        raise ValueError("The validated region contract is East US 2 and Sweden Central")
    if set(snapshot.get("data", {})) != set(regions):
        raise ValueError("Every supported region must have its own service catalog")
    required = {"search", "firewall", "registry", "storage", "logs", "compute", "appconfig", "appgateway",
                "publicip", "apim", "cosmos", "private", "dns", "vault", "bastion", "nat", "vm", "disk",
                "embedding", "hosted"}
    for region, services in snapshot["data"].items():
        if not required.issubset(services):
            raise ValueError(f"{region}: a required service catalog is missing")
        for service, entry in services.items():
            validate_entry(entry, f"{region}/{service}")
    validate_entry(snapshot.get("modelDiscovery"), "modelDiscovery")
    published = snapshot.get("publishedPrices", {})
    from published_prices import SOURCES
    if set(published) != set(SOURCES):
        raise ValueError("The default model and dedicated-pool official prices are required")
    for key, entry in published.items():
        timestamp(entry.get("retrievedAt"))
        if entry.get("sourceType") != "OfficialPricingPage" or entry.get("sourceUrl") != SOURCES[key]:
            raise ValueError(f"{key}: expected the exact official published source")
        if set(entry.get("prices", {})) != set(regions):
            raise ValueError(f"{key}: each supported regional price is required")
        expected = {"input", "cachedInput", "output"} if key == "gpt-5-nano" else {"allocation"}
        if entry.get("unit") != ("USD/1M tokens" if key == "gpt-5-nano" else "USD/vCPU-second"):
            raise ValueError(f"{key}: unexpected published billing unit")
        for region, prices in entry["prices"].items():
            if set(prices) != expected:
                raise ValueError(f"{key}/{region}: unexpected published rate columns")
            for value in prices.values():
                if isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(value) or value <= 0:
                    raise ValueError(f"{key}/{region}: a positive finite published rate is required")
    return snapshot


def validate_entry(entry, name):
    if not isinstance(entry, dict) or not isinstance(entry.get("items"), list):
        raise ValueError(f"{name}: expected an auditable record set")
    timestamp(entry.get("retrievedAt"))
    query = entry.get("query", "")
    parsed = urlparse(query)
    if parsed.scheme != "https" or parsed.hostname != "prices.azure.com" or parsed.username or parsed.password:
        raise ValueError(f"{name}: expected the official Retail Prices API source")
    for item in entry["items"]:
        for key in ("skuName", "meterName", "unitOfMeasure", "productName", "meterId"):
            if not isinstance(item.get(key), str) or not item[key]:
                raise ValueError(f"{name}: missing {key}")
        if item.get("currencyCode") != "USD" or item.get("type") != "Consumption":
            raise ValueError(f"{name}: only USD consumption records are accepted")
        if not isinstance(item.get("armRegionName"), str):
            raise ValueError(f"{name}: billing geography must be explicit")
        for key in ("retailPrice", "tierMinimumUnits"):
            value = item.get(key)
            if isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(value) or value < 0:
                raise ValueError(f"{name}: {key} must be a finite nonnegative number")


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
