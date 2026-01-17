# Terraform Labs (AWS)

This repo contains my AWS + Terraform learning labs.

## Structure
- week2/day1-ec2-nginx: EC2 + Security Group + user_data (nginx)
- week2/state-bootstrap: S3 remote backend + DynamoDB state locking

## How to run a lab
1) Copy tfvars example:
   - cp terraform.tfvars.example terraform.tfvars
2) Edit terraform.tfvars values
3) Run:
   - terraform init
   - terraform apply
4) Cleanup:
   - terraform destroy
