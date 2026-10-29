"""Collect a candidate catalog without replacing the last validated public prices."""

import argparse
import concurrent.futures
import datetime
import json
import logging
import pathlib
import time
import urllib.error
import urllib.parse
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parents[2]
BASE = "https://prices.azure.com/api/retail/prices"
REGIONS = {"eastus2": "East US 2", "swedencentral": "Sweden Central"}
SERVICES = {
    "search": "Azure Cognitive Search",
    "firewall": "Azure Firewall",
    "registry": "Container Registry",
    "storage": "Storage",
    "logs": "Log Analytics",
    "compute": "Azure Container Apps",
    "appconfig": "App Configuration",
    "appgateway": "Application Gateway",
    "publicip": "Virtual Network",
    "apim": "API Management",
    "cosmos": "Azure Cosmos DB",
    "private": "Virtual Network",
    "dns": "Azure DNS",
    "vault": "Key Vault",
    "bastion": "Azure Bastion",
    "nat": "NAT Gateway",
    "vm": "Virtual Machines",
    "disk": "Storage",
    "embedding": "Foundry Models",
    "hosted": "Foundry Tools",
}


def fetch(query):
    url = BASE + "?" + urllib.parse.urlencode({"$filter": query, "currencyCode": "'USD'"})
    source = url
    records = []
    while url:
        for attempt in range(4):
            try:
                with urllib.request.urlopen(url, timeout=90) as response:
                    page = json.load(response)
                break
            except urllib.error.HTTPError as error:
                if error.code not in {429, 503} or attempt == 3:
                    raise
                retry_after = error.headers.get("Retry-After", "")
                wait = min(int(retry_after), 120) if retry_after.isdigit() else 10 * (attempt + 1)
                logging.warning("Azure pricing HTTP %s, retrying in %s seconds", error.code, wait)
                time.sleep(wait)
        records.extend(page["Items"])
        url = page.get("NextPageLink")
        if url:
            parsed = urllib.parse.urlparse(url)
            if parsed.scheme != "https" or parsed.hostname != "prices.azure.com" or parsed.username or parsed.password or parsed.port not in {None, 443}:
                raise ValueError("Unexpected pagination source")
    return {
        "query": source,
        "retrievedAt": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "items": records,
    }


def collect(region, key, service):
    query = (
        f"serviceName eq '{service}' and armRegionName eq '{region}' "
        "and priceType eq 'Consumption'"
    )
    if key == "storage":
        query += " and productName eq 'General Block Blob v2'"
    elif key == "appgateway":
        query += " and productName eq 'Application Gateway WAF v2'"
    elif key == "publicip":
        query += " and productName eq 'IP Addresses' and skuName eq 'Standard'"
    elif key == "vm":
        query += " and armSkuName eq 'Standard_D2s_v3'"
    elif key == "disk":
        query += " and productName eq 'Standard HDD Managed Disks'"
    elif key == "embedding":
        query += " and contains(meterName, 'embedding')"
    elif key == "hosted":
        query += " and productName eq 'Foundry Agents' and skuName eq 'Hosted'"
    elif key == "dns":
        query = "serviceName eq 'Azure DNS' and priceType eq 'Consumption'"
    elif key == "nat":
        query = "serviceName eq 'NAT Gateway' and armRegionName eq 'Global' and priceType eq 'Consumption'"
    elif key == "private":
        query = "productName eq 'Virtual Network Private Link' and armRegionName eq 'Global' and priceType eq 'Consumption'"
    result = fetch(query)
    logging.info("%s/%s: %s source records", region, key, len(result["items"]))
    return region, key, result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=pathlib.Path, default=ROOT / "candidate-prices.json")
    args = parser.parse_args()
    logging.basicConfig(level=logging.INFO, format="%(levelname)s %(message)s")
    snapshot = {
        "retrievedAt": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "currency": "USD",
        "source": BASE,
        "deploymentVersion": "v5.5.3",
        "regions": REGIONS,
        "data": {region: {} for region in REGIONS},
    }
    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
        jobs = [
            pool.submit(collect, region, key, service)
            for region in REGIONS
            for key, service in SERVICES.items()
        ]
        for job in concurrent.futures.as_completed(jobs):
            region, key, result = job.result()
            snapshot["data"][region][key] = result
    snapshot["modelDiscovery"] = fetch("contains(meterName, 'nano') and priceType eq 'Consumption'")
    from published_prices import collect as collect_published
    snapshot["publishedPrices"] = collect_published()
    compact(snapshot)
    from validate_catalog import validate
    validate(snapshot)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(snapshot, separators=(",", ":"), allow_nan=False) + "\n", encoding="utf-8")
    logging.info("Candidate written to %s. Browser validation is required before publication.", args.output)


def compact(snapshot):
    allowed = {
        "search": {"Basic", "Standard S1", "Standard S2"},
        "registry": {"Premium", "S1"},
        "storage": {"Hot LRS", "Cool LRS"},
        "logs": {"Analytics Logs"},
        "compute": {"Dedicated", "Environment"},
        "appconfig": {"Standard", "Premium"},
        "firewall": {"Basic", "Standard", "Premium"},
        "appgateway": {"Standard"},
        "publicip": {"Standard"},
        "apim": {"Standard v2", "Premium v2"},
        "cosmos": {"RUs", "Backup", "AP1"},
        "private": {"Standard"},
        "vault": {"Standard"},
        "bastion": {"Standard"},
        "nat": {"Standard"},
        "vm": {"D2s v3"},
        "disk": {"S15 LRS"},
        "hosted": {"Hosted"},
    }
    for services in snapshot["data"].values():
        for key, entry in services.items():
            if key in allowed:
                entry["items"] = [item for item in entry["items"] if item["skuName"] in allowed[key]]
    snapshot["modelDiscovery"]["items"] = [item for item in snapshot["modelDiscovery"]["items"]
        if item["armRegionName"] in REGIONS and item["skuName"] in {
            "gpt 4.1 nano Inp glbl", "gpt 4.1 nano Outp glbl",
            "gpt-5-nano Inp glbl", "gpt-5-nano Outp glbl"}]


if __name__ == "__main__":
    main()
