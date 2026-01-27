# Standalone External (App Gateway in front of internal Container Apps)

Use this scenario when you want the standalone (new VNet) topology, but still expose a Container App externally via Application Gateway v2.

**Sample parameter file**

[bicep/infra/sample.standalone-external.bicepparam](https://github.com/Azure/AI-Landing-Zones/blob/main/bicep/infra/sample.standalone-external.bicepparam)

**What this walkthrough validates**

| Capability | Notes |
|---|---|
| Internal Container Apps Environment | Deploys an internal CAE with `publicNetworkAccess: Disabled`. |
| External entrypoint | Deploys App Gateway v2 with a Public IP to provide inbound access. |
| VNet-reachable backend | Ensures the backend Container App is reachable from inside the VNet so App Gateway probes + forwarding work. |
| HTTPS for labs | Generates a self-signed PFX at deployment time (no Key Vault required). |

> If you already have a real certificate, use the Key Vault path (production) instead of auto-generating a self-signed cert.

**Key settings (from the sample)**

| Setting | Typical value | Notes |
|---|---|---|
| `deployToggles.applicationGateway` | `true` | Deploys Application Gateway. |
| `deployToggles.applicationGatewayPublicIp` | `true` | Creates a public frontend IP. |
| `appGatewayDefinition.enableHttps` | `true` | HTTPS listener (443) + HTTP redirect (80 → 443). |
| `appGatewayDefinition.createSelfSignedCertificate` | `true` | Lab-friendly certificate path using deployment scripts. |
| `containerAppsList[*].ingressExternal` | `true` for the backend app | Required for **VNet-reachable ingress** (even though the CAE is internal). |

**Prerequisites**

You need permissions to create resources in the target subscription, and you must be signed in with Azure CLI. This walkthrough uses Azure Developer CLI (`azd`), so run the commands from the repository root.

**Deployment**

Create a local working directory and run the commands from there.

```powershell
mkdir deploy
cd deploy
```

Initialize the environment.

```powershell
azd init -e ailz-standalone-external-RANDOM_SUFFIX
```

Set environment variables.

```powershell
$env:AZURE_LOCATION = "eastus2"
$env:AZURE_RESOURCE_GROUP = "rg-ailz-standalone-external-RANDOM_SUFFIX"
$env:AZURE_SUBSCRIPTION_ID = "00000000-1111-2222-3333-444444444444"

# Convenience variable used by the commands below
$rg = $env:AZURE_RESOURCE_GROUP
```

Copy the sample into the active parameter file used by `azd`.

```powershell
Copy-Item bicep/infra/sample.standalone-external.bicepparam bicep/infra/main.bicepparam -Force
```

Provision.

```powershell
azd provision
```

**Validation**

Confirm the backend Container App ingress is VNet-reachable.

```powershell
az containerapp show --resource-group $rg --name ca-aca-helloworld --query "properties.configuration.ingress" -o jsonc
```

Expected:
- `external` should be `true` (VNet-reachable)
- `targetPort` should be `80` (matches the hello-world container)

Optional (recommended): validate in-VNet connectivity from the Jump VM.

```powershell
$vm = (az vm list --resource-group $rg --query "[?contains(name, '-jmp')].name | [0]" -o tsv)
$fqdn = (az containerapp show --resource-group $rg --name ca-aca-helloworld --query "properties.configuration.ingress.fqdn" -o tsv)

az vm run-command invoke -g $rg -n $vm --command-id RunPowerShellScript \
	--scripts "Resolve-DnsName -Name '$fqdn' | Out-String" \
					 "try { (Invoke-WebRequest -UseBasicParsing -TimeoutSec 20 -Uri 'http://$fqdn/').StatusCode } catch { if ($_.Exception.Response) { [int]$_.Exception.Response.StatusCode } else { $_.Exception.Message } }" \
	--query "value[0].message" -o tsv
```

Expected:
- DNS output includes a `privatelink.*` CNAME and a private `IP4Address`
- Final line prints `200`

Check Application Gateway backend health.

```powershell
$agwName = (az network application-gateway list --resource-group $rg --query "[0].name" -o tsv)
az network application-gateway show-backend-health --resource-group $rg --name $agwName -o jsonc
```

Expected: backend members show `Healthy`.

Get the App Gateway public DNS name (cloudapp FQDN).

```powershell
$pipId = (az network application-gateway show --resource-group $rg --name $agwName --query "frontendIPConfigurations[?publicIPAddress.id!=null][0].publicIPAddress.id" -o tsv)
$pipName = $pipId.Split('/')[-1]
$appGwFqdn = (az network public-ip show --resource-group $rg --name $pipName --query "dnsSettings.fqdn" -o tsv)
$appGwFqdn
```

Test HTTPS end-to-end.

```powershell
curl.exe -k "https://$appGwFqdn/"
```

Expected: `200 OK` and the hello-world response body.

**Optional: use your own custom domain + trusted certificate**

This walkthrough validates the scenario using the Azure Public IP `cloudapp.azure.com` hostname and a self-signed certificate.
If you want to test (or later move to) a real custom domain like `app.example.com`, you only need to change the **frontend** (DNS + HTTPS listener/cert).

**1) Create a DNS record for your domain**

Point your DNS name to the App Gateway public frontend using one of these:

- **CNAME**: `app.example.com` → `<appgw-public-fqdn>.<region>.cloudapp.azure.com`
- **A record**: `app.example.com` → `<App Gateway Public IP address>`

You can retrieve the Public IP resource and its FQDN/IP using the validation commands above.

**2) Set the HTTPS hostname (SNI)**

In your `.bicepparam`, set:

- `appGatewayDefinition.httpsHostName = 'app.example.com'`

**3) Use a certificate that matches your domain**

For a real custom domain, use a publicly trusted certificate (CN/SAN includes `app.example.com`). Supported options:

- **Recommended (production): Key Vault**
	- Set `appGatewayDefinition.httpsKeyVaultSecretId` to the Key Vault secret ID (PFX).
	- Set `appGatewayDefinition.createSelfSignedCertificate = false`.

- **Direct PFX upload (no Key Vault)**
	- Set `appGatewayDefinition.sslCertificatePfxBase64` and `appGatewayDefinition.sslCertificatePassword`.
	- Set `appGatewayDefinition.createSelfSignedCertificate = false`.

- **Self-signed (lab only)**
	- Keep `appGatewayDefinition.createSelfSignedCertificate = true`.
	- Browsers will show warnings unless the cert is trusted on the client.

After changing DNS / hostname / certificate settings, re-run `azd provision` to apply.

**Troubleshooting notes**

- If backend health shows `Unhealthy` with `404`, the Container App ingress is usually not VNet-reachable.
- If you changed subnet address spaces, ensure `firewallPrivateIp` matches the actual Azure Firewall private IP.
- If `userDefinedRoutes=true` (forced tunneling), keep `appGatewayDefinition.appGatewayInternetRoutingException=true` (AppGW v2 requirement).
