# WhaleTale
Cloud-based RAG that helps answer questions on marine biology, with a focus on cetaceans.

### Prerequisites

* An AWS account
* An S3 bucket for the terraform backend
* OpenAI API key

## Data Ingestion
Ingestion is handled by a companion repository: https://github.com/mmoinsiaam/RAG-ingestion-scripts

## Architecture

<img width="849" height="758" alt="architecture" src="https://github.com/user-attachments/assets/f0da53b2-625d-4887-866c-0185839a6f54" />

The frontend is hosted on Amazon S3 and distributed through CloudFront. Requests to the backend are routed through an Application Load Balancer and restricted using CloudFront's AWS-managed prefix list to ECS/Fargate tasks running the RAG API and Redis. Redis serves as the vector database used for document retrieval. On startup, an init container downloads the Redis `.rdb` database dump from public Cloudflare object storage, which Redis then loads to initialize the vector database.

The application runs within a VPC across multiple Availability Zones, with backend containers placed in private subnets and outbound internet access provided via NAT gateways. ECS tasks assume dedicated IAM roles rather than using static credentials, a task execution role for pulling images/writing logs, and a task role scoped to what the RAG API needs at runtime (e.g. reading secrets from Parameter Store). Configuration variables are stored in AWS Systems Manager Parameter Store, while application logs and metrics are sent to CloudWatch from ECS/Fargate.

Infrastructure is provisioned with Terraform, using an S3 backend for remote state.

## API
The backend exposes a small FastAPI service with two endpoints:

### `POST /query`
Answers a marine biology question using retrieval-augmented generation.

**Request body**
```json
{
  "query": "How deep do sperm whales dive?",
  "history": [
    { "query": "What do sperm whales eat?", "answer": "Primarily squid, including giant squid..." }
  ]
}
```
- `query` (string, required) — the user's question.
- `history` (array, optional) — prior turns in the conversation, each with a `query` and `answer`, used to resolve follow-up questions (e.g. pronouns like "it" or "their").

**Response body**
```json
{
  "answer": "Sperm whales can dive to depths of over 2,000 meters..."
}
```

**How it works**
1. If conversation history is present, the query is rewritten into a standalone question (via `gpt-4o-mini`) so follow-ups resolve implied context.
2. The standalone query is embedded using OpenAI's `text-embedding-3-small` model.
3. The embedding is used to run a vector similarity search (cosine distance, top 5) against a Redis index of marine biology document chunks.
4. Retrieved chunks are passed as context to `gpt-4o-mini`, which is scoped to a marine biology system prompt and declines off-topic questions.
5. Each request logs structured latency, token usage, and retrieval-distance metrics to CloudWatch in EMF format for monitoring.

### `GET /health`
Basic health check endpoint, returns:
```json
{ "status": "healthy" }
```

## Deployment

Because the ECS task definition references an image that must already exist in ECR, deployment is a two-step Terraform apply:

### 0. Configure your environment
Copy `.env.example` to `.env` and `terraform.tfvars.example` to `terraform.tfvars`, and fill in the values for your setup.

### 1. Create the ECR repository
```bash
terraform apply -target=aws_ecr_repository.rag_api
```
This provisions just the ECR repo so there's somewhere to push the image to.

### 2. Build and push the image
```bash
aws ecr get-login-password --region <region> | docker login --username AWS --password-stdin <account-id>.dkr.ecr.<region>.amazonaws.com

docker build -t rag-api .
docker tag rag-api:latest <account-id>.dkr.ecr.<region>.amazonaws.com/rag-api:latest
docker push <account-id>.dkr.ecr.<region>.amazonaws.com/rag-api:latest
```
(`<region>` and `<account-id>` here come from whatever you set in your `.env`/tfvars.)

### 3. Deploy the full infrastructure
```bash
terraform apply
```
This provisions the VPC, ECS cluster/service, ALB, CloudFront, IAM roles, and everything else, pointing the ECS task definition at the image just pushed.

> **Note:** Step 1 must always be followed by step 3, even if step 2 (the build/push) fails partway. Skipping the full apply after a partial `-target` run can leave Terraform state out of sync with actual infrastructure.

After the final apply is finished, Terraform will output the link for your application. Simply copy and paste it to the browser and enjoy the product !

## AWS OIDC Setup (GitHub Actions) - Optional

This project authenticates GitHub Actions to AWS via OIDC federation, no long-lived
access keys are stored in the repo.

### 1. Create the OIDC identity provider
In IAM, create an identity provider:
- Provider URL: `https://token.actions.githubusercontent.com`
- Audience: `sts.amazonaws.com`

Once created, use IAM's **"Create role"** flow for this provider. It walks you through scoping
the trust policy to a specific GitHub org/repo automatically. AWS generates a trust policy
equivalent to:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:YOUR_GH_ORG/YOUR_REPO:*"
        }
      }
    }
  ]
}
```

### 3. Attach permissions
Attach these AWS-managed policies to the role:
- `AmazonEC2ContainerRegistryFullAccess`
- `AmazonECS_FullAccess`
- `ElasticLoadBalancingFullAccess`
- `AmazonVPCFullAccess`
- `CloudFrontFullAccess`
- `AmazonS3FullAccess`
- `CloudWatchLogsFullAccess`
- `AmazonSSMFullAccess`
- `AmazonDynamoDBFullAccess` (if using DynamoDB for state locking)

Then attach the custom IAM permissions policy at [`github-actions-iam-policies.md`](./github-actions-iam-policies.md),
which scopes policy management to the ECS task roles this project creates — deliberately
avoiding `IAMFullAccess`, since that would let the role create new admin identities for itself.

### 4. Point the workflow at the role
In your GitHub Actions workflow, use `aws-actions/configure-aws-credentials@v4` with
`role-to-assume` set to the role's ARN.
