# Troubleshooting

## Common problems

| Symptom | Cause | Fix |
| --- | --- | --- |
| `azd deploy` fails with a message that the platform foundation is missing | Applications were deployed before the platform was provisioned, or in an environment where provisioning failed | Run `azd provision` first and check that it completes. See [Deploy infrastructure only](deploy-infra-only.md). |
| Preflight fails with a quota error | The subscription does not have enough model or vCPU quota in the selected region | Request more quota, lower the model capacity parameters, or choose another region. See [Configuration](configuration.md#deployment-parameters). |
| Hosted validation fails during `preprovision` | The parameter combination is not valid for the selected `DEPLOYMENT_TOPOLOGY` (for example, continuity enabled without a hosted topology) | Read the error message; it names the invalid parameter. See [Hosted agents](hosted-agents.md). |
| The hosted agent returns HTTP 422 from the Responses API | The request body does not match what the agent expects, or the model deployment name is wrong | Check the request format in [Calling the agent](hosted-agents.md) and the model deployment parameters. |
| Continuity endpoints return HTTP 503 | Conversation continuity is not enabled, or the conversation store is not reachable | Set `HOSTED_CONTINUITY_ENABLED=true` with a hosted topology, then run `azd provision`. See [Conversation continuity and panel](hosted-agents.md#conversation-continuity-and-panel). |
| With network isolation, calls fail with name resolution or timeout errors | Private DNS zones are not linked to the virtual network you are using, or you are running from outside the network | Run the steps from the jumpbox and do the checks in [Network isolation](network-isolation.md#check-connectivity). |
| `azd deploy` cannot build images with network isolation on | The ACR Tasks agent pool is not available | Check that the agent pool exists in the container registry. Use a local build on the jumpbox only as a fallback. |

## Collecting information

When you open an issue, include:

1. The release tag you deployed.
2. The values of your environment, **without secrets**:

    ```bash
    azd env get-values
    ```

    Remove keys, passwords and connection strings before you share the output.

3. Container App logs for the failing component:

    ```bash
    az containerapp logs show -g <resource-group> -n <container-app> --tail 200
    ```

4. The full error output from `azd`.

Open issues at [Azure/agent-landing-zone](https://github.com/Azure/agent-landing-zone/issues).
