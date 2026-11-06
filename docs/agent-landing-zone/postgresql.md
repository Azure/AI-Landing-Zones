# Optional application PostgreSQL

Provision one Entra-only PostgreSQL Flexible Server/application database for an
owner-supplied custom Container App. This is a default-off foundation extension,
not a Cosmos replacement, migration, NL2SQL integration or bundled runtime consumer.
Disabled deployments add no PostgreSQL resources or discovery settings.

## Expected outcome

Your custom Container App reaches its application database through the selected
network path. Basic restricts the public PostgreSQL endpoint to the dedicated NAT
IP and explicitly allowed operator ranges. Isolation uses Private Link and
private DNS, with public PostgreSQL access disabled. Both modes require Entra
authentication, SQL grants and verified TLS.

<div class="runbook-diagram" markdown="1">

<div class="runbook-diagram__summary" markdown="1">

**Choose the network mode before first provision.** Basic uses the application's
dedicated NAT/static IPv4. Isolation uses an application Private Endpoint and
private DNS instead. PostgreSQL serves your custom application; bundled runtime
connections and Cosmos remain unchanged.

</div>

[![Basic and isolated PostgreSQL connectivity for a custom Container App. Basic associates NAT and a static public IPv4 with the Container Apps Environment subnet. Isolation uses a private endpoint in a separate subnet and private DNS, with public PostgreSQL access disabled. Dashed lines show subnet associations. Both modes use Entra authentication and verified TLS.](../media/runbooks/postgresql.svg?v=6d07587f2ff6)](../media/runbooks/postgresql.svg?v=6d07587f2ff6){: .runbook-diagram__image aria-label="Open full-size PostgreSQL connectivity diagram"}

[Open full-size diagram](../media/runbooks/postgresql.svg?v=6d07587f2ff6){: .runbook-diagram__open}

</div>

## Network and fresh-only scope

| Mode | Application path | Operator path |
| --- | --- | --- |
| Basic (`NETWORK_ISOLATION=false`) | Fresh external workload-profiles ACA with VNet integration and dedicated Standard NAT/static public IPv4; restricted public PostgreSQL permits exactly the outbound NAT IP plus explicit operator ranges. | An explicitly allowed operator IPv4 source. ACA ingress IP is not egress IP. |
| Isolated (`NETWORK_ISOLATION=true`) | Application Private Endpoint subnet and `privatelink.postgres.database.azure.com`; public PostgreSQL access disabled. | Authorized VNet-connected host with DNS/routes and Entra access. |

Workload-profiles ACA requires a `Microsoft.App/environments` delegated subnet
of at least /27; retain the /24 seed unless capacity is reviewed. A Consumption
profile in that environment is not legacy Consumption-only ACA, which is
unsupported. Forced default routes through NVA/firewall invalidate NAT SNAT and
are rejected, not overwritten. Jumpbox NAT is separate and unchanged.
Isolation adds neither a PostgreSQL delegated-server subnet nor Basic ACA NAT.
BYO VNet/subnets and managed, existing or policy-managed DNS keep explicit
ownership; existing-zone and policy ownership must not compete. The common
service `allowedIpRanges` does not open isolated PostgreSQL.

Enable only before first provision. Existing-environment retrofit, mode/name/
provider/admin binding replacement and disable-after-creation are blocked.
Verified same-binding recovery is supported, not implicit recreation.

## Configure either provider

Use the product-root Bicep or Terraform lifecycle and select destinations first.
The explicit administrator must belong to the deployment tenant: User, Group or
ServicePrincipal, with directory object ID, exact principal name and actual type.
It is not inferred from the application identity. Deployment needs resource,
directory-read and server-scope lock permissions.

```sh
azd env set DEPLOY_POSTGRESQL true
azd env set NETWORK_ISOLATION false
azd env set POSTGRESQL_ADMINISTRATOR_OBJECT_ID <administrator-object-id>
azd env set POSTGRESQL_ADMINISTRATOR_PRINCIPAL_NAME <administrator-principal-name>
azd env set POSTGRESQL_ADMINISTRATOR_PRINCIPAL_TYPE Group
azd provision
```

Group is an example, not a default. Choose isolation before provision if required.
Boolean inputs accept only true/false; integers reject floats and Booleans.
Whole-value root placeholders resolve once; explicit environment inputs override
corresponding native values.

| Native input | Environment input | Default |
| --- | --- | --- |
| `deployPostgreSql` | `DEPLOY_POSTGRESQL` | false |
| `postgreSqlServerName` | `POSTGRESQL_SERVER_NAME` | Deterministic deployment-context name; explicit name supported |
| `postgreSqlDatabaseName` | `POSTGRESQL_DATABASE_NAME` | agentlz |
| `postgreSqlVersion` | `POSTGRESQL_VERSION` | 16 |
| `postgreSqlTier` | `POSTGRESQL_TIER` | Burstable |
| `postgreSqlSkuName` | `POSTGRESQL_SKU_NAME` | Standard_B1ms |
| `postgreSqlStorageSizeGb` | `POSTGRESQL_STORAGE_SIZE_GB` | 32 GiB |
| `postgreSqlBackupRetentionDays` | `POSTGRESQL_BACKUP_RETENTION_DAYS` | 7 days |
| `postgreSqlHighAvailability` | `POSTGRESQL_HIGH_AVAILABILITY` | Disabled |
| `postgreSqlGeoRedundantBackup` | `POSTGRESQL_GEO_REDUNDANT_BACKUP` | false |
| `postgreSqlStorageAutoGrow` | `POSTGRESQL_STORAGE_AUTO_GROW` | false |
| `postgreSqlAdministratorObjectId` | `POSTGRESQL_ADMINISTRATOR_OBJECT_ID` | Required enabled |
| `postgreSqlAdministratorPrincipalName` | `POSTGRESQL_ADMINISTRATOR_PRINCIPAL_NAME` | Required enabled |
| `postgreSqlAdministratorPrincipalType` | `POSTGRESQL_ADMINISTRATOR_PRINCIPAL_TYPE` | Required enabled |
| `postgreSqlAllowedIpRanges` | Typed root JSON, no string alias | Empty array |
| `existingPrivateDnsZonePostgreSqlResourceId` | Typed native input, no string alias | Empty |

For Basic operator access set, for example,
`"postgreSqlAllowedIpRanges": {"value": ["203.0.113.8", "198.51.100.0/24"]}`
in root `main.parameters.json`. These are documentation addresses, not real
operator IPs. IPv4/CIDRs are normalized to network ranges; IPv6, 0.0.0.0, /0 and Azure-services
exceptions are prohibited. Application NAT output is separate.
HA accepts Disabled/SameZone/ZoneRedundant; Burstable requires Disabled. Storage
is a power of two from 32..65536 GiB; backup retention 7..35 days. No silent
SKU/HA downgrade occurs. Validate region capacity and subscription policy;
the pinned Bicep AVM uses a preview server API, not an assumed policy exception.

## Discovery for custom applications

The shared post-provision lifecycle persists azd environment metadata
`POSTGRESQL_SERVER_RESOURCE_ID`, `POSTGRESQL_HOST`,
`POSTGRESQL_PORT`, `POSTGRESQL_DATABASE_NAME` and
`CONTAINER_APPS_POSTGRESQL_EGRESS_IP`. Fresh disabled deployments add no
metadata; isolated egress is empty. The Bicep root preserves its existing
64 outputs (the ARM limit); PostgreSQL metadata is derived from immutable
creation intent and verified Azure resource reads, not extra root outputs.
Terraform also exposes native outputs, which the common adapter checks
against the same live binding. Basic egress follows the actual ACA
subnet-to-dedicated-NAT-to-static-IPv4 association, never the ingress address.
Shared lifecycle verifies actual server/database, tenant, Entra-only
authentication, ownership and independent lock before persisting metadata
and publishing discovery. A failed verification or azd write fails the hook;
correct the cause and rerun post-provision with the same binding.

Read these flat keys only under App Configuration label `agent-lz`:

| Key | Value |
| --- | --- |
| `AGENTLZ_POSTGRESQL_HOST` | Canonical FQDN |
| `AGENTLZ_POSTGRESQL_PORT` | 5432 |
| `AGENTLZ_POSTGRESQL_DATABASE` | Application database |
| `AGENTLZ_POSTGRESQL_SSLMODE` | verify-full |
| `AGENTLZ_POSTGRESQL_AUTH_MODE` | entra |

Closed `AGENTLZ_PLATFORM_OUTPUTS` v1 and bundled runtimes stay unchanged.
No password/token/global SQL username is published. App owners implement driver,
OID-bound SQL role selection, TLS trust, Entra token renewal, pooling and migrations.
Azure RBAC alone does not grant SQL permissions.

## Manual bootstrap

From the reviewed platform source, use Python >=3.10 and
`python -m pip install -r util/requirements.txt`, including
`psycopg[binary]==3.3.6`. Authenticate with `az login` and arrange operator
network access. Configure libpq trust with `PGSSLROOTCERT` pointing to an
operator-reviewed Azure server CA bundle (or the reviewed libpq default root
certificate location). The utility never downloads trust material or disables
hostname/certificate verification. As the configured Entra administrator, initialize a dedicated
application schema owned by the actual future migration-object creator.
Never target a shared database/schema or reassign ownership. The managed
identity must already exist; use its service-principal **object ID**, not client
ID or display-name lookup.
For a Group administrator, the operator must also be authorized to read its
transitive Microsoft Graph membership (including hidden membership where
applicable). The utility checks every page and rejects an application identity
that inherits that administrative group. Missing permissions, invalid paging
or an incomplete bounded directory read fail before SQL bootstrap.

Run on either platform (one line avoids shell continuation differences):

```text
python -m util.postgresql_bootstrap --server-resource-id <server-arm-id> --host <server-name>.postgres.database.azure.com --database agentlz --administrator-role <configured-entra-admin-role> --application-object-id <managed-identity-object-id> --application-role <sql-role> --schema <app-schema> --ddl-owner-role <actual-object-creator-role>
```

No password/token argument exists. AzureCliCredential acquires
`https://ossrdbms-aad.database.windows.net/.default` in memory; connect parameters
require verify-full TLS and bounded connection/statement/lock timeouts.
In `postgres`, `pgaadauth_create_principal_with_oid(..., 'service', false, false)`
creates the nonadmin mapping. Exact tenant/OID/type/admin mapping is read back;
conflicts/unmapped roles are rejected, never remapped by a duplicate-role catch.

In the app DB the utility verifies schema/object ownership and rejects privileged
roles, memberships/SET ROLE, shared-schema and user SECURITY DEFINER
function/trigger bypasses. Schema objects must be base tables/sequences owned
by the declared DDL owner, not views, materialized views or foreign wrappers. Grants are CONNECT, schema USAGE, table SELECT/INSERT/UPDATE/DELETE,
sequence USAGE/SELECT and actual-DDL-owner future defaults. PUBLIC CREATE/TEMP
on this dedicated DB and PUBLIC CREATE on public/app schemas are removed.
Effective permissions and global/PUBLIC defaults are checked. No DDL/admin,
role management or ownership is granted. Identifiers are quoted and values bound.

Run twice and verify identical mapping/grants. Cross-database work is not atomic:
if principal creation commits but app grants fail, correct the cause and rerun
the same binding. Failures are nonzero, with no token diagnostics. Deployment
hooks never execute SQL bootstrap.

## Protection, recovery and deliberate removal

Preserve `.azure/<environment>/postgresql-binding.json` with private deployment
records. Nonsecret immutable creation intent is written before IaC. Corrupt or
missing records are not adoption/deletion permission; restore the original record
and reviewed context. Same-binding recovery preserves data.

Post-provision creates/readbacks server-scoped CanNotDelete lock
`agentlz-postgresql-data-protection` outside **both** foundation graphs and
Terraform state before ready discovery. Failed/missing protection blocks
publication; recover with the same context and corrected permissions. Never import
the independent lock into Terraform or remove it for a routine deployment.

Normal down, disable and replacement are blocked, including Terraform's
state-scoped path. Code rollback does not authorize removal. The pre-lock
partial-provision window and privileged lock removal remain risks; direct provider
execution bypasses some lifecycle checks. Locks are not atomic or universal
protection and do not replace backups.

Separately approved removal requires exact resource/state inventory, backup/PITR/
export/restore and retention review, consumer shutdown and data-owner approval.
Remove only approved server protection/resources and reconcile provider state,
retired discovery and binding metadata. Preserve shared DNS/VNets/RGs; erasing
records is not an automatic teardown escape hatch. No bypass Boolean or automated
cleanup command is provided.

## Cost and acceptance

Defaults are a development profile, not a production SLA. Budget compute/storage/
backup, Basic dedicated NAT hourly/data-processing/static IPv4 or isolated PE/DNS,
transfer, monitoring and custom app usage. HA/geo-backup/larger SKUs/retention can
increase cost. This optional extension is not priced by the sizing planner.
Offline compilation/mocks do not establish live parity. Before production, verify
each provider/mode's actual NAT source/private DNS, positive/negative SQL/network
access, owner future defaults, rerun/partial recovery and lock deletion denial.
Live/destructive acceptance is a separate authorized gate.
