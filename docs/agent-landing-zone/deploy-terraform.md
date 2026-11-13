---
search:
  exclude: true
---

<span id="deployment-guidance-has-moved"></span>

<span id="terraform-runbooks"></span>

# Terraform deployment guides

Choose the Agent Landing Zone guide by outcome:

- [Deploy infra only with Terraform](deploy-terraform-infra-only.md)
- [Deploy full stack with Terraform](deploy-terraform-full-stack.md)

[Terraform templates](terraform.md) explains the integrated composition and
shared azd lifecycle. The separate
[AI Landing Zone Terraform foundation reference](../terraform/index.md)
covers direct foundation composition with the shared AVM pattern.

Shared hooks read verified `DEPLOYMENT_METADATA` from the original native
Terraform backend, independently of runtime App Configuration delivery.
See [runtime configuration modes](configuration.md#runtime-configuration-mode)
and [metadata recovery](deployment-operations.md#verify-deployment-metadata).

[Optional PostgreSQL](postgresql.md) for fresh custom consumers uses this same
product-root lifecycle; direct foundation calls omit protection/bootstrap guards.
