terraform {
  backend "s3" {
    bucket       = "vanphutin-tf-state-bucket-p2"
    key          = "learn-terraform-aws-s3/terraform.tfstate"
    region       = "ap-southeast-1"
    encrypt      = true
    use_lockfile = true
  }
}
