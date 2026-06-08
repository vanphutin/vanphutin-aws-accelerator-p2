# Final Project: Deploy a Web App on AWS with Terraform

This Terraform project deploys:

- VPC with public and private subnets across two Availability Zones
- EC2 web server in a public subnet
- RDS MySQL database in private subnets
- S3 bucket for static assets
- Security groups with limited required traffic
- S3 backend with DynamoDB locking template

## Prerequisites

Create the Terraform backend resources before running this project:

- S3 bucket for Terraform state
- DynamoDB table for state locking with partition key `LockID` as a string

Then copy the backend template:

```bash
cp backend.tf.example backend.tf
```

Update `backend.tf` with your backend bucket, key, region, and DynamoDB table.

## Configure

Copy the variables example:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:

- Set `static_assets_bucket_name` to a globally unique bucket name.
- Set `db_password` to a strong password.
- Set `allowed_ssh_cidr_blocks` to your public IP, for example `["203.0.113.10/32"]`.
- Set `key_name` to an existing EC2 key pair name, or leave it `null`.

## Deploy

```bash
terraform init
terraform fmt -recursive
terraform validate
terraform plan
terraform apply
```

After apply, open the `web_url` output in a browser.

## Security Notes

- RDS is not public and only accepts MySQL traffic from the EC2 web security group.
- EC2 accepts HTTP from `web_ingress_cidr_blocks`.
- SSH is disabled by default because `allowed_ssh_cidr_blocks` is empty. Add your IP only if SSH is required.
- The static assets bucket blocks public ACLs and uses server-side encryption by default.
