# OIDC

## Custom policies
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ManageECSRoles",
      "Effect": "Allow",
      "Action": [
        "iam:CreateRole",
        "iam:DeleteRole",
        "iam:GetRole",
        "iam:TagRole",
        "iam:UntagRole",
        "iam:PutRolePolicy",
        "iam:DeleteRolePolicy",
        "iam:GetRolePolicy",
        "iam:AttachRolePolicy",
        "iam:DetachRolePolicy",
        "iam:ListRolePolicies",
        "iam:ListAttachedRolePolicies",
        "iam:ListInstanceProfilesForRole"
      ],
      "Resource": [
        "arn:aws:iam::ACCOUNT_ID:role/*ecsTaskExecutionRole*",
        "arn:aws:iam::ACCOUNT_ID:role/*ecsTaskRole*",
        "arn:aws:iam::ACCOUNT_ID:role/*rag-api*",
        "arn:aws:iam::ACCOUNT_ID:role/*redis*"
      ]
    },
    {
      "Sid": "PassRoleToECSOnly",
      "Effect": "Allow",
      "Action": "iam:PassRole",
      "Resource": "arn:aws:iam::ACCOUNT_ID:role/*",
      "Condition": {
        "StringEquals": {
          "iam:PassedToService": "ecs-tasks.amazonaws.com"
        }
      }
    },
    {
      "Sid": "ManagePrefixListRead",
      "Effect": "Allow",
      "Action": [
        "ec2:DescribeManagedPrefixLists",
        "ec2:GetManagedPrefixListEntries"
      ],
      "Resource": "*"
    }
  ]
}
```

## Policy needed for Terraform remote state S3 

Also for DynamoDB state locking IF needed in future

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "TFStateBucket",
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:PutObject", "s3:ListBucket"],
      "Resource": [
        "arn:aws:s3:::YOUR-TF-STATE-BUCKET",
        "arn:aws:s3:::YOUR-TF-STATE-BUCKET/*"
      ]
    },
    {
      "Sid": "TFStateLock",
      "Effect": "Allow",
      "Action": ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:DeleteItem"],
      "Resource": "arn:aws:dynamodb:REGION:ACCOUNT_ID:table/YOUR-TF-LOCK-TABLE"
    }
  ]
}
```
## Role needed for ECS task definitions. 
GA doesn't need it to read SSM but to create the policy for ECS

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["ssm:GetParameter", "ssm:GetParameters"],
      "Resource": "arn:aws:ssm:REGION:ACCOUNT_ID:parameter/your-app/*"
    }
  ]
}
```
