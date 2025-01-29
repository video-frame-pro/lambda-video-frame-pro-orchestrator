<p align="center">
  <img src="https://i.ibb.co/zs1zcs3/Video-Frame.png" width="30%" />
</p>

---

# Video Frame Pro - Orchestrator

Este repositório contém a implementação da **Lambda Orchestrator** do sistema **Video Frame Pro**.  
A função orquestra a execução do processamento de vídeos, validando usuários no Cognito, iniciando o processamento no Step Functions e armazenando informações no DynamoDB.

---

## 📌 Objetivo

A função Lambda executa as seguintes tarefas:

1. **Valida a requisição recebida** verificando os campos obrigatórios.
2. **Decodifica o token Cognito** para obter o usuário autenticado.
3. **Inicia a execução do Step Functions** com os dados do vídeo.
4. **Armazena os detalhes da requisição** no DynamoDB.
5. **Retorna uma resposta com os dados do processamento**.

---

## 📂 Estrutura do Repositório

```
/src
├── orchestrator
│   ├── orchestrator.py            # Lógica principal da Lambda
│   ├── requirements.txt           # Dependências da Lambda
│   ├── __init__.py                # Inicialização do módulo
/tests
├── orchestrator
│   ├── orchestrator_test.py       # Testes unitários
│   ├── __init__.py                # Inicialização do módulo de testes
/infra
├── main.tf                        # Infraestrutura AWS (Lambda, S3, IAM, etc.)
├── outputs.tf                     # Definição dos outputs Terraform
├── variables.tf                    # Variáveis de configuração Terraform
├── terraform.tfvars                # Arquivo com valores das variáveis Terraform
```

---

## 🔹 Campos da Requisição

A Lambda espera um **JSON** com os seguintes campos obrigatórios:

| Campo       | Tipo   | Descrição |
|-------------|--------|-----------|
| `video_url` | String | URL do vídeo a ser processado |
| `email`     | String | E-mail do usuário solicitante |

Além disso, a requisição deve conter um cabeçalho `Authorization` com o token JWT do usuário autenticado.

### 📥 Exemplo de Entrada

```json
{
   "headers": {
        "Authorization": "Bearer token_do_usuario"
   },
   "body": {
        "video_url": "https://example.com/video.mp4",
        "email": "usuario@email.com"
   }
}
```

### 📤 Exemplo de Resposta - Sucesso

```json
{
   "statusCode": 200,
   "body": {
      "user_name": "usuario123",
      "email": "usuario@email.com",
      "video_id": "b19a74b0-4d6d-4f82-8f02-acee6d65f7a1",
      "video_url": "https://example.com/video.mp4",
      "stepFunctionId": "arn:aws:states:us-east-1:123456789012:execution:StepFunction:12345"
   }
}
```

### ❌ Exemplo de Resposta - Erro

```json
{
   "statusCode": 400,
   "body": {
      "message": "Missing required fields: video_url, email"
   }
}
```

---

## 🚀 Configuração e Deploy

### 1️⃣ Pré-requisitos

1. **AWS CLI** configurado (`aws configure`)
2. **Terraform** instalado (`terraform -v`)
3. Permissões para criar **Lambda Functions**, **DynamoDB**, **Step Functions** e **IAM Roles**.

### 2️⃣ Deploy da Infraestrutura

1. Navegue até o diretório `infra` e inicialize o Terraform:

```sh
cd infra
terraform init
terraform apply -auto-approve
```

### 3️⃣ Executando Testes Unitários

Execute os testes e gere o relatório de cobertura:

```sh
find tests -name 'requirements.txt' -exec pip install -r {} +
pip install coverage coverage-badge
coverage run -m unittest discover -s tests -p '*_test.py'
coverage report -m
coverage html  
```

---

## 🛠 Tecnologias Utilizadas

<p>
  <img src="https://img.shields.io/badge/AWS-232F3E?logo=amazonaws&logoColor=white" alt="AWS" />
  <img src="https://img.shields.io/badge/AWS_Lambda-4B5A2F?logo=aws-lambda&logoColor=white" alt="AWS Lambda" />
  <img src="https://img.shields.io/badge/AWS_Cognito-00A1C9?logo=amazonaws&logoColor=white" alt="AWS Cognito" />
  <img src="https://img.shields.io/badge/AWS_DynamoDB-4053D6?logo=amazonaws&logoColor=white" alt="AWS DynamoDB" />
  <img src="https://img.shields.io/badge/Python-3776AB?logo=python&logoColor=white" alt="Python" />
  <img src="https://img.shields.io/badge/GitHub_Actions-2088FF?logo=github-actions&logoColor=white" alt="GitHub Actions" />
</p>

---

## 📜 Licença

Este projeto está licenciado sob a **MIT License**. Consulte o arquivo LICENSE para mais detalhes.

---

Desenvolvido com ❤️ pela equipe **Video Frame Pro**.
