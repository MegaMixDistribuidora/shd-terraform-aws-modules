# shd-terraform-aws-modules

Módulos Terraform compartilhados da Mega Mix. Consumo **sempre por tag**:

`git::https://github.com/MegaMixDistribuidora/shd-terraform-aws-modules.git//modules/<nome>?ref=vX.Y.Z`

| Módulo | Faz | Desde |
| --- | --- | --- |
| [`github-oidc`](modules/github-oidc) | provider OIDC, roles `infra`/`app` e boundary compartilhada | v1.2.0 |
| [`apigw-http-api`](modules/apigw-http-api) | API HTTP compartilhada com JWT authorizers e domínio customizado | v1.1.0 |

Cada módulo tem `README.md`, exemplo em `examples/<nome>` e testes em `modules/<nome>/tests` (`terraform test` com provider mockado). O CI valida só os módulos alterados; todo commit na `main` gera tag e release (ADR-14).
