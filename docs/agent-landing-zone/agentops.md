# AgentOps: evaluate, ship and operate

Use the **AgentOps Accelerator** to evaluate, ship and operate your agent
workload on Agent Landing Zone. It brings evaluation, safety checks, release
decisions and operational evidence into a repeatable workflow.

Agent Landing Zone provides the application and its Azure foundation.
AgentOps complements it with practices and tooling for the workload lifecycle.
Configure the accelerator for your workload using its own getting-started guide.

## How to add AgentOps to your workload

1. Deploy and verify the Agent Application capability you intend to evaluate.
   Record its component versions, configuration and execution host as the
   baseline. Use a separate validation environment for evaluation work.
2. Follow the [AgentOps installation and workspace setup](https://azure.github.io/agentops/)
   in your workload's development workspace. This is separate from the
   Agent Landing Zone infrastructure deployment.
3. Follow [Evaluation](https://azure.github.io/agentops/evaluation/) to configure
   the workload connection, test data, expected outcomes and acceptance
   thresholds. Use the intended caller's identity and approved test content.
4. Run the evaluation and review both quality and safety outcomes.
   Include denied access, tool failures and human-review decisions when those
   capabilities are part of your application.
5. Follow [Ship](https://azure.github.io/agentops/ship/) to connect the release
   gate to your CI/CD process, and [Operate](https://azure.github.io/agentops/operate/)
   to assess readiness and retain the evidence pack.

Configure evaluation and release policies in the AgentOps workspace using its
documentation. Configure application features in
[Application settings](application-settings.md).
Keep production promotion subject to the workload's human approval policy.
