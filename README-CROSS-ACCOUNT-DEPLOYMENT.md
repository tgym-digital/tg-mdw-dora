# Cross-Account ECS Deployment

This repository contains a GitHub Actions workflow that builds Docker images in the Digital account (931900621347) and deploys them to ECS in the Utilities account (992382793490).

## Architecture

- **Digital Account (931900621347)**: ECR repository for storing Docker images
- **Utilities Account (992382793490)**: ECS cluster where the application runs
- **GitHub Actions**: Handles build and deployment across accounts

## Prerequisites

### 1. ECR Repository (Digital Account)
Ensure the ECR repository exists:
```bash
aws ecr create-repository \
  --repository-name mwcloud-utils/tg-mdw-dora \
  --region eu-west-1
```

### 2. ECS Cluster (Utilities Account)
Ensure the ECS cluster `mwcloud-tools` exists with:
- Fargate launch type
- Proper VPC and subnet configuration
- Security groups for ports 3333, 9696, 9697

### 3. IAM Roles

#### Digital Account (931900621347)
Role: `github-actions-services-role`
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:PutImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload"
      ],
      "Resource": "arn:aws:ecr:eu-west-1:931900621347:repository/mwcloud-utils/tg-mdw-dora"
    },
    {
      "Effect": "Allow",
      "Action": "ecr:GetAuthorizationToken",
      "Resource": "*"
    }
  ]
}
```

#### Utilities Account (992382793490)
Role: `github-actions-services-role`
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecs:DescribeServices",
        "ecs:DescribeTaskDefinition",
        "ecs:RegisterTaskDefinition",
        "ecs:UpdateService",
        "ecs:DescribeClusters"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "iam:PassRole"
      ],
      "Resource": [
        "arn:aws:iam::992382793490:role/ecsTaskExecutionRole",
        "arn:aws:iam::992382793490:role/ecsTaskRole"
      ]
    }
  ]
}
```

### 4. Trust Relationships
Both IAM roles must trust GitHub Actions:
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
          "token.actions.githubusercontent.com:sub": "repo:YOUR_GITHUB_ORG/YOUR_REPO:*"
        }
      }
    }
  ]
}
```

### 5. Required Secrets
Set these secrets in your GitHub repository:
- `EFS_FILE_SYSTEM_ID`: EFS file system ID for persistent storage

## How It Works

The workflow `.github/workflows/deploy-cross-account.yml` performs:

1. **Build and Push (Digital Account)**:
   - Builds Docker image using `Dockerfile.ecs`
   - Pushes to ECR repository `mwcloud-utils/tg-mdw-dora`
   - Tags with commit SHA and `latest`

2. **Deploy (Utilities Account)**:
   - Generates ECS task definition
   - Updates ECS service `tg-mdw-dora` in cluster `mwcloud-tools`

## Configuration

### Environment Variables
The application uses these environment variables:
- `ENVIRONMENT`: "prod"
- `DB_HOST`, `DB_NAME`, `DB_USER`, `DB_PORT`: Database config
- `REDIS_HOST`, `REDIS_PORT`: Redis config
- `PORT`, `ANALYTICS_SERVER_PORT`, `SYNC_SERVER_PORT`: Service ports
- `BUILD_DATE`, `MERGE_COMMIT_SHA`: Build metadata

### Secrets Management
Database password from AWS Secrets Manager:
```
arn:aws:secretsmanager:eu-west-1:992382793490:secret:tg-mdw-dora/db-password
```

### Logging
CloudWatch Logs:
- Log group: `/ecs/tg-mdw-dora`
- Region: `eu-west-1`
- Stream prefix: `ecs`

## Deployment

Simply push to the main branch:
```bash
git push origin main
```

Or manually trigger the workflow from GitHub Actions.

## Monitoring

### Check Status
```bash
# ECS service status
aws ecs describe-services \
  --cluster mwcloud-tools \
  --services tg-mdw-dora \
  --region eu-west-1

# View logs
aws logs tail /ecs/tg-mdw-dora \
  --region eu-west-1 \
  --follow
```

### Common Issues
1. **Image Pull Errors**: Check ECS task execution role permissions
2. **Cross-Account Access**: Verify trust relationships
3. **EFS Mount Issues**: Check EFS access points and security groups
4. **Network Issues**: Verify VPC and security group configuration

## Security

- Cross-account access uses IAM roles with minimal permissions
- EFS volumes use transit encryption
- Secrets stored in AWS Secrets Manager
- Application runs in private subnets with proper security groups 