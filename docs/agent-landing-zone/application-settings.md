# Application settings

Application settings control how the UI, orchestrator and ingestion service
behave after deployment. They normally live in Azure App Configuration under
the `agent-lz` label. Deployment inputs, such as resource selection and networking,
are covered separately in [Deployment settings](configuration.md).

## Change a setting

1. Select the App Configuration store for the intended environment.
2. Check [configuration ownership](configuration.md#configuration-ownership-and-declarations).
   Change provisioning-managed values through their declared inputs, not an
   independent edit that the next deployment could replace.
3. For an operator-managed value, update the exact key under `agent-lz`.
   Store credentials as Key Vault references, never literal strings.
4. Reload the affected process. Restart the UI or ingestion Container App.
   For hosted orchestrator settings, deploy a new agent version.
5. Check the effective nonsecret value and exercise the affected feature.
   An accepted write alone does not confirm that a running process loaded it.

Use the [runtime-setting procedure](deploy-full-stack.md#change-a-runtime-setting)
for commands and the [secret-rotation procedure](deploy-full-stack.md#rotate-a-secret)
for versioned and unversioned Key Vault references.

## Configuration access

Set `APP_CONFIG_ENDPOINT` in each process environment before startup. The
application uses managed identity in Azure and can use the Azure CLI credential
for local development. `AZURE_CLIENT_ID` selects a user-assigned managed identity.
The identity still needs App Configuration Data Reader, access to referenced
Key Vault secrets and network connectivity.

Use separate stores and identities for separate environments. The label is not
an environment-isolation boundary.

### Overrides and effective values

The components also read compatibility labels. Conflicting values under those
labels or without a label can replace the intended `agent-lz` value. Avoid
duplicate keys with different values rather than using label ordering as an
override mechanism.

The orchestrator's final selection reads unlabelled keys. UI and ingestion
endpoint loaders finish with an unfiltered selection, which can read keys from
other labels too. A successful write therefore needs an effective-value check.
The orchestrator dashboard writes to `agent-app-orchestrator`. Ingestion writes
to `agent-lz` unless its process variable `APP_CONFIG_LABEL` selects another label.

Direct environment overrides differ by component:

| Component | How overrides work |
| --- | --- |
| Orchestrator | `allow_environment_variables=true` enables runtime environment overrides. `1` and `yes` are also accepted. Leave it unset for normal remote configuration. |
| Ingestion | Any nonempty `allow_environment_variables` value enables overrides, including the text `false`. Leave it unset or empty to disable them. |
| UI | Overrides are supported by specific feature loaders, including embedding and continuity. There is no universal environment override for every key. |

Bootstrap inputs, such as `APP_CONFIG_ENDPOINT`, are process values regardless
of these switches. An unavailable store is not a supported offline mode.
UI returns a not-ready application when it cannot connect. Other components
have loader-specific fallback behavior, so a running process is not proof that
all required values are available.

## Find the settings for your task

| Task | Guide |
| --- | --- |
| Choose agent execution and prompts | [Strategies & prompts](agent-strategies.md) |
| Set up user login, consent and document access | [Sign-in & access](application-auth.md) |
| Configure conversation history and uploads | [Conversations & files](conversations.md) |
| Embed the chat in a portal | [Embed chat](embed-chat.md) |
| Connect a knowledge source | [Foundry IQ](foundry-iq.md), [Work IQ](work-iq.md), [Fabric IQ](fabric-iq.md), [SharePoint](sharepoint.md) |
| Schedule ingestion and maintenance | [Jobs & schedules](ingestion-jobs.md) |
| Enable administrative access | [Administration](operations.md) |
| Configure audit and content capture | [Monitoring & audit](application-monitoring.md) |

The runtime default of a component can differ from the value selected by the
platform. For example, the orchestrator's standalone retrieval default is
`ai_search`, while a fresh Agent Landing Zone deployment selects `foundry_iq`.
Use the selected deployment's effective configuration, not a local sample file.

## Orchestrator TLS compatibility

Use `APP_CONFIG_TLS_COMPATIBILITY=true` only when the orchestrator needs the
documented App Configuration transport workaround. It is a process-environment
input, default `false`, and cannot be enabled by an App Configuration key.
When enabled, also supply `KEY_VAULT_URI` in the process environment.
Both endpoints must be plain HTTPS origins without credentials, query strings,
fragments or additional paths.

The compatibility transport retains certificate and hostname verification,
custom certificate authorities and TLS 1.2 or later. It affects App Configuration
and references to that configured vault, not every outbound connection.
UI and ingestion do not implement this orchestrator switch.

Invalid input fails startup. A hosted change requires a new agent version.
Use [TLS troubleshooting](troubleshooting.md#hosted-configuration-tls-handshake-stalls)
instead of disabling certificate verification.
