"""Collect a candidate catalog for every public Azure region without replacing the published prices.

Each service is requested once for all regions (paginated), then split by region. When a source
fails after its retries, the last validated data in the published catalog is reused and marked stale
with its original capture date. The run fails only when the default region cannot be fully sourced
or most sources fail.
"""

import argparse
import concurrent.futures
import datetime
import json
import logging
import pathlib
import time
import urllib.parse

import published_prices
from published_prices import read_source

ROOT = pathlib.Path(__file__).resolve().parents[2]
CATALOG = ROOT / "docs" / "data" / "planner" / "prices.json"
BASE = "https://prices.azure.com/api/retail/prices"
DEFAULT_REGION = "eastus2"
WORKERS = 3
MAX_FAILED_SHARE = 0.5
FIELDS = ["skuName", "meterName", "unitOfMeasure", "tierMinimumUnits", "retailPrice", "productName",
          "meterId", "effectiveStartDate"]
# Restricted, edge or sovereign locations that are not generally deployable public regions.
EXCLUDED_PREFIXES = ("att", "jio", "usgov", "usdod", "usnat", "ussec", "china", "germanycentral",
                     "germanynortheast", "sgx", "taiwannorthwest")


def any_of(field, values):
    return "(" + " or ".join(f"{field} eq '{value}'" for value in values) + ")"


def spec(where, skus, meters, *, region=None):
    """A Retail API query plus the exact meters kept from it. region=None keeps every region."""
    query = " and ".join([*where, any_of("skuName", skus), "priceType eq 'Consumption'"])
    return {"query": query, "skus": set(skus), "meters": set(meters), "region": region}


REGIONAL = {
    "search": spec(["serviceName eq 'Azure Cognitive Search'"], ["Basic", "Standard S1", "Standard S2"],
                   ["Basic Unit", "Standard S1 Unit", "Standard S2 Unit"]),
    "firewall": spec(["serviceName eq 'Azure Firewall'"], ["Basic", "Standard", "Premium"],
                     [f"{sku} {meter}" for sku in ("Basic", "Standard", "Premium")
                      for meter in ("Deployment", "Data Processed")]),
    "registry": spec(["serviceName eq 'Container Registry'"], ["Premium"], ["Premium Registry Unit"]),
    "storage": spec(["serviceName eq 'Storage'", "productName eq 'General Block Blob v2'"], ["Hot LRS", "Cool LRS"],
                    ["Hot LRS Data Stored", "Cool LRS Data Stored", "Hot Read Operations", "Cool Read Operations",
                     "Hot LRS Write Operations", "Cool LRS Write Operations"]),
    "logs": spec(["serviceName eq 'Log Analytics'"], ["Analytics Logs"], ["Analytics Logs Data Ingestion"]),
    "compute": spec(["serviceName eq 'Azure Container Apps'"], ["Dedicated", "Environment"],
                    ["Dedicated vCPU Usage", "Dedicated Memory Usage", "Dedicated Plan Management",
                     "Environment Private Endpoint"]),
    "appconfig": spec(["serviceName eq 'App Configuration'"], ["Standard", "Premium"],
                      ["Standard Instance", "Premium Instance"]),
    "appgateway": spec(["serviceName eq 'Application Gateway'", "productName eq 'Application Gateway WAF v2'"],
                       ["Standard"], ["Standard Fixed Cost", "Standard Capacity Units"]),
    "publicip": spec(["serviceName eq 'Virtual Network'", "productName eq 'IP Addresses'"], ["Standard"],
                     ["Standard IPv4 Static Public IP"]),
    "apim": spec(["serviceName eq 'API Management'"], ["Standard v2", "Premium v2"],
                 ["Standard v2 Unit", "Standard v2 Secondary Unit", "Premium v2 Unit", "Premium v2 Secondary Unit"]),
    "cosmos": spec(["serviceName eq 'Azure Cosmos DB'"], ["RUs", "Backup", "AP1"],
                   ["AP1 100 RUs", "100 RU/s", "Data Stored", "1M RUs", "Cont 30D Bckp Continuous Backup"]),
    "vault": spec(["serviceName eq 'Key Vault'", "productName eq 'Key Vault'"], ["Standard"], ["Operations"]),
    "vm": spec(["serviceName eq 'Virtual Machines'", "armSkuName eq 'Standard_D2s_v3'",
                "productName eq 'Virtual Machines DSv3 Series Windows'"], ["D2s v3"], ["D2s v3"]),
    "disk": spec(["serviceName eq 'Storage'", "productName eq 'Standard HDD Managed Disks'"], ["S15 LRS"],
                 ["S15 LRS Disk"]),
    "bastion": spec(["serviceName eq 'Azure Bastion'"], ["Standard"], ["Standard Gateway"]),
    "embedding": spec(["serviceName eq 'Foundry Models'"], ["text-embedding-3-large-regional"],
                      ["text-embedding-3-large-regional Tokens"]),
    "hosted": spec(["serviceName eq 'Foundry Tools'", "productName eq 'Foundry Agents'"], ["Hosted"],
                   ["Hosted vCPU Usage", "Hosted Memory Usage"]),
}
GLOBAL = {
    "dns": spec(["serviceName eq 'Azure DNS'"], ["Private"], ["Private Zone", "Private Queries"], region=""),
    "nat": spec(["serviceName eq 'NAT Gateway'", "armRegionName eq 'Global'"], ["Standard"],
                ["Standard Gateway", "Standard Data Processed"], region="Global"),
    "private": spec(["productName eq 'Virtual Network Private Link'", "armRegionName eq 'Global'"], ["Standard"],
                    ["Standard Private Endpoint", "Standard Data Processed - Ingress",
                     "Standard Data Processed - Egress"], region="Global"),
}
MODEL = spec([], ["gpt 4.1 nano Inp glbl", "gpt 4.1 nano Outp glbl"],
             ["gpt 4.1 nano Inp glbl Tokens", "gpt 4.1 nano Outp glbl Tokens"])
STATS = {"pages": 0}


def now():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def url_for(query):
    return BASE + "?" + urllib.parse.urlencode({"$filter": query, "currencyCode": "'USD'"})


def fetch(query):
    url = url_for(query)
    source = url
    records = []
    while url:
        page = json.loads(read_source(url, expected_host="prices.azure.com"))
        STATS["pages"] += 1
        records.extend(page["Items"])
        url = page.get("NextPageLink")
        if url:
            parsed = urllib.parse.urlparse(url)
            if parsed.scheme != "https" or parsed.hostname != "prices.azure.com" or parsed.username or parsed.password or parsed.port not in {None, 443}:
                raise ValueError("Unexpected pagination source")
    return {"query": source, "retrievedAt": now(), "items": records}


def to_tuple(item):
    return [item[field] for field in FIELDS]


def split(name, definition, items):
    """Keep exact consumption meters and group them by billing region, one record per meter key."""
    grouped = {}
    for item in items:
        if (item.get("type") != "Consumption" or item.get("currencyCode") != "USD" or
                item.get("skuName") not in definition["skus"] or item.get("meterName") not in definition["meters"]):
            continue
        region = item.get("armRegionName")
        if not isinstance(region, str) or (definition["region"] is not None and region != definition["region"]):
            continue
        key = (item["skuName"], item["meterName"], item["unitOfMeasure"], item["tierMinimumUnits"], item["productName"])
        current = grouped.setdefault(region, {}).get(key)
        if current and current["retailPrice"] != item["retailPrice"]:
            logging.warning("%s/%s: duplicate %s, keeping the latest effective record", region, name, key)
        if not current or item.get("effectiveStartDate", "") > current.get("effectiveStartDate", ""):
            grouped[region][key] = item
    return {region: [to_tuple(item) for item in sorted(records.values(), key=lambda r: tuple(map(str, to_tuple(r))))]
            for region, records in grouped.items()}


def legacy_items(items, fields, definition=None):
    """Previous records as tuples, accepting both the compact and the original object catalog."""
    rows = [[item[fields.index(field)] if field in fields else None for field in FIELDS] if isinstance(item, list)
            else [item.get(field) for field in FIELDS] for item in items]
    if definition:
        rows = [row for row in rows if row[0] in definition["skus"] and row[1] in definition["meters"]]
    return rows


def previous_regional(previous, key):
    fields = previous.get("fields", FIELDS)
    result = {}
    for region, services in (previous.get("data") or {}).items():
        entry = services.get(key)
        rows = legacy_items(entry["items"], fields, REGIONAL[key]) if entry and entry.get("items") else []
        if rows:
            result[region] = {"retrievedAt": entry.get("retrievedAt") or previous.get("retrievedAt"), "items": rows}
    return result


def previous_global(previous, key):
    fields = previous.get("fields", FIELDS)
    if key in (previous.get("global") or {}):
        entry = previous["global"][key]
        return {"retrievedAt": entry["retrievedAt"], "items": legacy_items(entry["items"], fields, GLOBAL[key])}
    # The original catalog copied global meters into each regional entry.
    for services in (previous.get("data") or {}).values():
        entry = services.get(key)
        if entry and entry.get("items"):
            region = GLOBAL[key]["region"]
            items = [item for item in entry["items"] if isinstance(item, list) or item.get("armRegionName") == region]
            return {"retrievedAt": entry.get("retrievedAt") or previous["retrievedAt"],
                    "items": legacy_items(items, fields, GLOBAL[key])}
    return None


def previous_models(previous):
    discovery = previous.get("modelDiscovery") or {}
    items = discovery.get("items")
    if isinstance(items, dict):
        fields = previous.get("fields", FIELDS)
        return {"retrievedAt": discovery["retrievedAt"],
                "items": {region: legacy_items(rows, fields, MODEL) for region, rows in items.items()}}
    if isinstance(items, list):
        grouped = {}
        for item in items:
            grouped.setdefault(item.get("armRegionName"), []).extend(legacy_items([item], FIELDS, MODEL))
        return {"retrievedAt": discovery.get("retrievedAt") or previous.get("retrievedAt"),
                "items": {region: rows for region, rows in grouped.items() if rows}}
    return None


def run_queries():
    jobs = {("regional", key): definition for key, definition in REGIONAL.items()}
    jobs.update({("global", key): definition for key, definition in GLOBAL.items()})
    jobs[("model", "model")] = MODEL
    results, failures = {}, {}
    with concurrent.futures.ThreadPoolExecutor(max_workers=WORKERS) as pool:
        futures = {pool.submit(fetch, definition["query"]): job for job, definition in jobs.items()}
        for future in concurrent.futures.as_completed(futures):
            job = futures[future]
            try:
                results[job] = future.result()
                logging.info("%s/%s: %s source records", *job, len(results[job]["items"]))
            except Exception as error:  # noqa: BLE001 - failures are recorded and handled by the keep policy
                failures[job] = error
                logging.error("%s/%s failed after retries: %s", *job, error)
    return jobs, results, failures


def region_catalog(retail_regions, page_regions, previous):
    regions = {}
    for region in page_regions:
        arm = published_prices.normalize(region["name"])
        if arm in retail_regions and not arm.startswith(EXCLUDED_PREFIXES):
            regions[arm] = {"name": region["name"], "geography": region["geography"]}
    if not regions:
        logging.error("No public region metadata was captured. Reusing the published region list.")
        for arm, meta in (previous.get("regions") or {}).items():
            if arm in retail_regions:
                regions[arm] = ({"name": meta["name"], "geography": meta["geography"]} if isinstance(meta, dict)
                                else {"name": meta, "geography": "Other"})
    return dict(sorted(regions.items()))


def build(previous):
    started = time.monotonic()
    jobs, results, failures = run_queries()
    snapshot = {
        "schemaVersion": 2,
        "retrievedAt": now(),
        "currency": "USD",
        "source": BASE,
        "deploymentVersion": "v5.5.3",
        "defaultRegion": DEFAULT_REGION,
        "fields": FIELDS,
        "queries": {key: url_for(definition["query"]) for key, definition in {**REGIONAL, **GLOBAL}.items()},
        "regions": {},
        "data": {},
        "global": {},
    }
    regional = {}
    for key, definition in REGIONAL.items():
        job = ("regional", key)
        if job in results:
            regional[key] = {region: {"retrievedAt": results[job]["retrievedAt"], "items": items}
                             for region, items in split(key, definition, results[job]["items"]).items()}
        else:
            regional[key] = {region: {**entry, "stale": True} for region, entry in previous_regional(previous, key).items()}
            logging.warning("regional/%s: reusing validated data for %s regions", key, len(regional[key]))
    retail_regions = {region for entries in regional.values() for region in entries}

    model_job = ("model", "model")
    if model_job in results:
        models = {"query": results[model_job]["query"], "retrievedAt": results[model_job]["retrievedAt"],
                  "items": split("model", MODEL, results[model_job]["items"])}
    else:
        fallback = previous_models(previous)
        if not fallback:
            raise RuntimeError("Model discovery failed and no validated fallback exists")
        models = {"query": url_for(MODEL["query"]), **fallback, "stale": True}

    published, page_regions = published_prices.collect(retail_regions, previous.get("publishedPrices"))
    snapshot["regions"] = region_catalog(retail_regions, page_regions, previous)
    allowed = set(snapshot["regions"])
    for key, entries in regional.items():
        for region, entry in entries.items():
            if region in allowed:
                snapshot["data"].setdefault(region, {})[key] = entry
    snapshot["data"] = dict(sorted(snapshot["data"].items()))
    models["items"] = {region: items for region, items in sorted(models["items"].items()) if region in allowed}
    snapshot["modelDiscovery"] = models
    for key, definition in GLOBAL.items():
        job = ("global", key)
        if job in results:
            entry = split(key, definition, results[job]["items"]).get(definition["region"], [])
            snapshot["global"][key] = {"armRegionName": definition["region"], "retrievedAt": results[job]["retrievedAt"],
                                       "items": entry}
        else:
            fallback = previous_global(previous, key)
            if not fallback:
                raise RuntimeError(f"global/{key} failed and no validated fallback exists")
            snapshot["global"][key] = {"armRegionName": definition["region"], **fallback, "stale": True}
    for entry in published.values():
        entry["prices"] = {region: prices for region, prices in sorted(entry["prices"].items()) if region in allowed}
    snapshot["publishedPrices"] = published

    for region in snapshot["regions"]:
        services = snapshot["data"].get(region, {})
        missing = [key for key in REGIONAL if not services.get(key, {}).get("items")]
        missing += [key for key, entry in published.items() if region not in entry["prices"]]
        if not models["items"].get(region):
            missing.append("model")
        if missing:
            snapshot["regions"][region]["unavailable"] = missing
        stale = sorted(key for key, entry in services.items() if entry.get("stale"))
        logging.info("%s (%s): %s services, %s records%s%s", region, snapshot["regions"][region]["name"],
                     len(services), sum(len(entry["items"]) for entry in services.values()),
                     f", unavailable: {', '.join(missing)}" if missing else "",
                     f", stale: {', '.join(stale)}" if stale else "")

    enforce_minimum(snapshot, jobs, failures)
    logging.info("Collected %s regions with %s Retail API pages, %s HTTP requests and %s failed sources in %.1f seconds",
                 len(snapshot["regions"]), STATS["pages"], published_prices.STATS["requests"], len(failures),
                 time.monotonic() - started)
    return snapshot


def enforce_minimum(snapshot, jobs, failures):
    if len(failures) > MAX_FAILED_SHARE * len(jobs):
        raise RuntimeError(f"{len(failures)} of {len(jobs)} price sources failed. The published catalog is kept.")
    default = snapshot["data"].get(DEFAULT_REGION)
    if DEFAULT_REGION not in snapshot["regions"] or not default:
        raise RuntimeError(f"The default region {DEFAULT_REGION} has no price data")
    missing = [key for key in REGIONAL if not default.get(key, {}).get("items")]
    missing += [key for key, entry in snapshot["publishedPrices"].items() if DEFAULT_REGION not in entry["prices"]]
    if missing:
        raise RuntimeError(f"The default region {DEFAULT_REGION} is missing: {', '.join(missing)}")


def load_previous(path):
    try:
        return json.loads(pathlib.Path(path).read_text(encoding="utf-8"))
    except (OSError, ValueError) as error:
        logging.warning("No previous catalog for stale fallback (%s)", error)
        return {}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=pathlib.Path, default=ROOT / "candidate-prices.json")
    parser.add_argument("--previous", type=pathlib.Path, default=CATALOG,
                        help="Last validated catalog reused, marked stale, for sources that fail")
    args = parser.parse_args()
    logging.basicConfig(level=logging.INFO, format="%(levelname)s %(message)s")
    snapshot = build(load_previous(args.previous))
    from validate_catalog import validate
    validate(snapshot)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(snapshot, separators=(",", ":"), allow_nan=False) + "\n", encoding="utf-8")
    logging.info("Candidate written to %s (%s bytes). Browser validation is required before publication.",
                 args.output, args.output.stat().st_size)


if __name__ == "__main__":
    main()
