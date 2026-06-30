# Public Ingress with Application Gateway

Network-isolated deployments keep Container Apps private by default. The Container Apps environment is internal-only and is normally reached from inside the virtual network, for example from the jumpbox.

Use **Public Ingress** when one Container App needs a controlled public entry point. The Bicep template provisions Azure Application Gateway WAF v2 in front of the private Container Apps environment, without making the environment itself public.

!!! warning "Cost and teardown"
    Application Gateway WAF v2 and Standard Public IP incur hourly charges while deployed. Turning `publicIngress.enabled` back to `false` does not delete resources that were already created by an incremental ARM deployment. Use `azd down` for full teardown, or manually delete the gateway, Public IP, WAF policy, NSG, and gateway identity.

## What gets created

When `publicIngress.enabled=true`, and the deployment also has `networkIsolation=true`, `deployContainerEnv=true`, `deployContainerApps=true`, and at least one app in `containerAppsList`, the template creates:

| Resource | Purpose |
|---|---|
| Application Gateway WAF v2 | Public HTTPS entry point for one Container App backend. |
| Standard Public IP | Public address for the gateway. |
| WAF policy | Managed WAF rules, using Prevention mode by default. |
| User-assigned identity | Lets Application Gateway read the TLS certificate from Key Vault. |
| NSG for `AppGatewaySubnet` | Keeps the gateway closed until source CIDRs are configured. |
| Diagnostic settings | Sends gateway logs and metrics to Log Analytics. |

The backend defaults to the first app in `containerAppsList`. Use `publicIngress.backendAppIndex` to point to a different app.

## Operating states

Public Ingress is intentionally a two-step workflow.

| State | Configuration | Behavior |
|---|---|---|
| Skeleton mode | `enabled=true`, but `frontendHostName` or `sslCertSecretId` is empty | The gateway resources exist, but Internet traffic is not opened through the NSG. |
| Live mode | `enabled=true`, `frontendHostName` and `sslCertSecretId` are set, and allowed source CIDRs are provided | HTTPS on 443 is enabled, HTTP redirects to HTTPS, and only configured CIDRs can reach the gateway. |

This keeps the post-provision configuration in source control instead of relying on portal edits that can be overwritten later.

## Step 1: enable the gateway skeleton

In `main.parameters.json`, enable Public Ingress:

```jsonc
"publicIngress": {
  "value": {
    "enabled": true
  }
}
```

Provision the landing zone:

```bash
azd provision
```

After provisioning, capture the `PUBLIC_INGRESS_PUBLIC_IP` output. You can get it from the `azd provision` output or from the resource group deployment outputs in the Azure portal.

## Step 2: prepare the hostname and certificate

Choose the public hostname, for example:

```text
app.contoso.com
```

From the jumpbox, use the ACME client installed by the bootstrap script:

```powershell
C:\tools\win-acme\wacs.exe
```

Use a DNS-01 flow with your DNS provider, then import the certificate into the landing-zone Key Vault. The jumpbox managed identity has the Key Vault certificate permissions needed for this workflow.

After import, copy the **versionless** Key Vault secret URI for the certificate:

```text
https://<key-vault-name>.vault.azure.net/secrets/<certificate-name>
```

Use the versionless URI, not a URI that includes a certificate version.

## Step 3: point DNS at Application Gateway

In your public DNS provider, create or update an A record:

| Record | Value |
|---|---|
| `app.contoso.com` | `PUBLIC_INGRESS_PUBLIC_IP` |

Wait for DNS propagation before validating the endpoint.

## Step 4: switch to live mode

Update `main.parameters.json` with the hostname, certificate secret URI, and source CIDRs that are allowed to reach the gateway:

```jsonc
"publicIngress": {
  "value": {
    "enabled": true,
    "frontendHostName": "app.contoso.com",
    "sslCertSecretId": "https://<key-vault-name>.vault.azure.net/secrets/<certificate-name>",
    "allowedSourceAddressPrefixes": ["203.0.113.0/24"]
  }
}
```

Provision again:

```bash
azd provision
```

The template now configures the HTTPS listener, attaches the Key Vault certificate, redirects HTTP to HTTPS, and opens the NSG only for the configured source CIDRs.

## Step 5: validate

From an allowed source:

```bash
curl -v https://app.contoso.com/
curl -v http://app.contoso.com/
```

Expected behavior:

| Test | Expected result |
|---|---|
| `https://app.contoso.com/` | Returns the Container App response. |
| `http://app.contoso.com/` | Redirects to HTTPS. |
| Source outside `allowedSourceAddressPrefixes` | Cannot reach the gateway on 443. |

## Parameter reference

```bicep
publicIngress: {
  enabled: bool
  backendAppIndex: int?
  frontendHostName: string?
  sslCertSecretId: string?
  allowedSourceAddressPrefixes: string[]?
  wafMode: ('Prevention' | 'Detection')?
  wafCustomRules: object[]?
  capacity: object?
  sslPolicy: object?
}
```

| Parameter | Default | Description |
|---|---|---|
| `enabled` | `false` | Master switch for Public Ingress. |
| `backendAppIndex` | `0` | Index into `containerAppsList` for the backend app. |
| `frontendHostName` | Empty | Public hostname used by the HTTPS listener. Required for live mode. |
| `sslCertSecretId` | Empty | Versionless Key Vault secret URI for the TLS certificate. Required for live mode. |
| `allowedSourceAddressPrefixes` | `[]` | CIDRs allowed to reach HTTPS on 443. Empty keeps the gateway closed. |
| `wafMode` | `Prevention` | WAF mode. |
| `wafCustomRules` | `[]` | Optional custom WAF rules. |
| `capacity` | `{ minCapacity: 0, maxCapacity: 2 }` | Application Gateway autoscale capacity. |
| `sslPolicy` | `{}` | Optional Application Gateway SSL policy block. |

## Useful outputs

| Output | Description |
|---|---|
| `PUBLIC_INGRESS_ENABLED` | Whether Public Ingress was deployed. |
| `PUBLIC_INGRESS_PUBLIC_IP` | Public IPv4 address for the gateway. |
| `PUBLIC_INGRESS_GATEWAY_RESOURCE_ID` | Application Gateway resource ID. |
| `PUBLIC_INGRESS_NSG_RESOURCE_ID` | NSG attached to `AppGatewaySubnet`. |
| `PUBLIC_INGRESS_WAF_POLICY_RESOURCE_ID` | WAF policy resource ID. |
| `PUBLIC_INGRESS_IDENTITY_PRINCIPAL_ID` | Gateway identity principal ID. Use this if an external Key Vault must grant certificate access. |
| `PUBLIC_INGRESS_LIVE` | `true` when live mode is active. |

## Teardown

For full teardown:

```bash
azd down
```

If the rest of the landing zone must remain, delete the Public Ingress resources manually: Application Gateway, Public IP, WAF policy, NSG, and gateway user-assigned identity.
