# Infraestrutura — MotivaFit

Este diretório contém toda a configuração de infraestrutura, deploy e CI/CD do MotivaFit.

## Estrutura

```
infra/
├── nginx/
│   ├── nginx.prod.conf          # Nginx reverse proxy unificado (produção)
│   └── ssl/                     # Certificados TLS (coloque aqui os certificados)
├── ecs/
│   ├── task-definition-frontend.json  # Task Definition ECS — Frontend
│   └── task-definition-backend.json   # Task Definition ECS — Backend
└── terraform/
    ├── main.tf                  # Composição principal dos módulos
    ├── variables.tf             # Variáveis do Terraform
    ├── terraform.tfvars.example # Exemplo de valores (copie para terraform.tfvars)
    ├── .gitignore
    └── modules/
        ├── vpc/                 # VPC com subnets públicas e privadas
        ├── rds/                 # Amazon RDS PostgreSQL (Multi-AZ)
        ├── ecs/                 # ECS Cluster + Fargate Services
        ├── alb/                 # Application Load Balancer
        └── ecr/                 # ECR Repositories
```

## Arquivos no raiz do projeto

| Arquivo | Descrição |
|---------|-----------|
| `docker-compose.dev.yml` | Ambiente de desenvolvimento local (DB + Backend + Frontend) |
| `docker-compose.prod.yml` | Ambiente de produção local/staging (Nginx + Frontend + Backend + DB) |
| `.env.example` | Modelo de variáveis de ambiente |
| `.github/workflows/ci-cd.yml` | Pipeline CI/CD do GitHub Actions |

---

## Desenvolvimento Local

### Pré-requisitos

- Docker e Docker Compose
- Node.js 22+ (para desenvolvimento sem Docker)
- JDK 25 + Maven (para desenvolvimento sem Docker)

### Iniciar ambiente completo

```bash
# 1. Copie as variáveis de ambiente
cp .env.example .env

# 2. Suba todos os serviços
docker compose -f docker-compose.dev.yml up -d

# 3. Acesse
# Frontend: http://localhost:3000
# Backend API: http://localhost:8080/api
# Swagger UI: http://localhost:8080/swagger-ui.html
```

### Parar ambiente

```bash
docker compose -f docker-compose.dev.yml down
```

---

## Deploy para AWS

### 1. Configurar infraestrutura com Terraform

```bash
cd infra/terraform

# 1. Copie e edite as variáveis
cp terraform.tfvars.example terraform.tfvars
# Edite terraform.tfvars com seus valores

# 2. Inicialize o Terraform
terraform init

# 3. Revise o plano
terraform plan

# 4. Aplique a infraestrutura
terraform apply
```

### 2. Configurar GitHub Secrets

No repositório do GitHub, vá em **Settings → Secrets and variables → Actions** e adicione:

| Secret | Descrição |
|--------|-----------|
| `AWS_ACCESS_KEY_ID` | Chave de acesso AWS com permissão para ECR, ECS, SSM |
| `AWS_SECRET_ACCESS_KEY` | Chave secreta AWS |
| `JWT_SECRET` | Chave secreta para assinatura JWT (use `openssl rand -base64 64`) |
| `JWT_ISSUER` | Issuer do JWT (ex: `motivafit`) |
| `DB_URL` | URL JDBC do RDS (ex: `jdbc:postgresql://<endpoint>:5432/motivafit`) |
| `DB_USER` | Usuário do banco de dados |
| `DB_PASSWORD` | Senha do banco de dados |
| `CORS_ALLOWED_ORIGIN` | Origem CORS (ex: `https://motivafit.com`) |

### 3. Pipeline CI/CD

A pipeline `.github/workflows/ci-cd.yml` executa automaticamente:

1. **Pull Request**: Lint + Testes (Frontend + Backend)
2. **Push para `develop`**: Validação + Build + Push ECR
3. **Merge na `main`**: Validação + Build + Push ECR + Deploy ECS

### 4. Configurar SSM Parameters

O pipeline CI/CD configura automaticamente os parâmetros SSM no deploy. Alternativamente, configure manualmente:

```bash
aws ssm put-parameter --name "/motivafit/prod/JWT_SECRET" --value "<chave>" --type SecureString
aws ssm put-parameter --name "/motivafit/prod/DB_URL" --value "jdbc:postgresql://<endpoint>:5432/motivafit" --type SecureString
aws ssm put-parameter --name "/motivafit/prod/DB_USER" --value "<usuario>" --type SecureString
aws ssm put-parameter --name "/motivafit/prod/DB_PASSWORD" --value "<senha>" --type SecureString
aws ssm put-parameter --name "/motivafit/prod/CORS_ALLOWED_ORIGIN" --value "https://motivafit.com" --type SecureString
```

---

## Arquitetura

```
                          ┌─────────────┐
                          │   CloudFront │ (opcional)
                          └──────┬──────┘
                                 │
                    ┌────────────▼────────────┐
                    │   Application Load Balancer │
                    │   (HTTP/HTTPS)            │
                    └──┬───────────────┬───────┘
                       │               │
              ┌────────▼──────┐  ┌─────▼──────────┐
              │  Target Group │  │  Target Group  │
              │   Frontend    │  │    Backend     │
              └───────┬───────┘  └──────┬─────────┘
                      │                 │
           ┌──────────▼──────────┐  ┌───▼──────────────┐
           │  ECS Fargate        │  │  ECS Fargate     │
           │  Frontend (Nginx)   │  │  Backend (Spring)│
           │  Porta: 80          │  │  Porta: 8080     │
           └─────────────────────┘  └──┬───────────────┘
                                       │
                              ┌────────▼────────┐
                              │  RDS PostgreSQL  │
                              │  (Multi-AZ)      │
                              │  Porta: 5432     │
                              └─────────────────┘
```

### Componentes AWS

| Recurso | Descrição |
|---------|-----------|
| **VPC** | Rede isolada com subnets públicas e privadas |
| **RDS PostgreSQL** | Banco de dados gerenciado com Multi-AZ, backups automáticos e criptografia |
| **ECS Fargate** | Containers serverless sem gerenciamento de servidores |
| **ECR** | Registry de imagens Docker com scan de vulnerabilidades |
| **ALB** | Load balancer com roteamento baseado em caminho |
| **SSM Parameter Store** | Armazenamento seguro de secrets |
| **CloudWatch** | Logs e métricas dos containers |
| **IAM** | Roles com permissões mínimas necessárias |

---

## Segurança

- **Secrets**: Armazenados no AWS SSM Parameter Store (SecureString)
- **RDS**: Não acessível publicamente; apenas dentro da VPC
- **ECS Tasks**: Rodam em subnets privadas sem IP público
- **IAM**: Princípio do menor privilégio com roles dedicadas
- **RDS**: Criptografia em repouso com gp3
- **ECR**: Scan de vulnerabilidades ativado no push
- **Cookies**: `Secure` e `SameSite=Lax` em produção
- **Nginx**: Headers de segurança (X-Frame-Options, X-Content-Type-Options, etc.)

---

## Deploy Gratuito — Render.com

Para testes e demonstrações, o MotivaFit pode ser deployado gratuitamente no [Render.com](https://render.com).
Esta opção **não requer configuração de infraestrutura** — basta conectar o repositório GitHub.

### Arquivos de configuração

| Arquivo | Descrição |
|---------|-----------|
| `render.yaml` | Blueprint do Render com 3 serviços: DB, Backend, Frontend |
| `.renderignore` | Arquivos ignorados durante o build |
| `backend/MotivaFIt/src/main/resources/application-render.yaml` | Perfil Spring Boot para Render |

### Instruções passo a passo

1. **Crie uma conta** em [https://render.com](https://render.com) (use GitHub para login)
2. **Vá para Blueprints** → clique em **"Connect a GitHub Repo"**
3. **Selecione** o repositório do MotivaFit
4. **Clique em "Apply"** — o Render vai criar automaticamente:
   - **PostgreSQL** (Free, 512 MB)
   - **Backend** (Docker Web Service, porta 8080)
   - **Frontend** (Static Site, arquivos do Vite dist)

### URLs após o deploy

Após o deploy, o Render gera URLs automáticas:

| Serviço | URL |
|---------|-----|
| Frontend | `https://motivafit-front.onrender.com` |
| Backend API | `https://motivafit-api.onrender.com` |
| Swagger UI | `https://motivafit-api.onrender.com/swagger-ui.html` |

### Limites do plano gratuito

| Recurso | Limite |
|---------|--------|
| **PostgreSQL** | 512 MB, adormece após 15 min de inatividade |
| **Web Service (Backend)** | 512 MB RAM, adormece após 15 min |
| **Static Site (Frontend)** | Sem limite de inatividade |
| **Builds** | 900 min/mês |

> ⚠️ **Primeira requisição após inatividade**: O banco e o backend "acordam" em ~30 segundos.
> O frontend estático não adormece.

### Credenciais de teste

O backend cria automaticamente um superusuário no primeiro deploy:

| Campo | Valor |
|-------|-------|
| Email | `admin@motivafit.com` |
| Senha | `SenhaBootstrap123!` |

> 🔒 **Importante**: Altere estas credenciais no painel do Render antes de usar em produção.

### Atualizando o deploy

Cada **push na branch `main`** dispara um novo deploy automático. Para atualizar:

```bash
git push origin main
```

O Render vai:
1. Rebuildar o backend Docker
2. Rebuildar o frontend Vite
3. Deployar as novas versões automaticamente

### Variáveis de ambiente

As variáveis sensíveis são gerenciadas pelo Render:

| Variável | Origem |
|----------|--------|
| `DATABASE_URL` | Conectada automaticamente ao banco do Render |
| `JWT_SECRET` | Gerada automaticamente pelo Render |
| `CORS_ALLOWED_ORIGIN` | Definida no `render.yaml` |

Para alterar, vá em **Dashboard → Serviço → Environment**.

---

## Limpar infraestrutura

### AWS Terraform

```bash
cd infra/terraform
terraform destroy
```

### Render.com

No painel do Render, vá em **Blueprint → Delete** para remover todos os serviços.
