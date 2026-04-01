terraform {
  backend "s3" {
    bucket         = "davy-terraform-state-storage" 
    key            = "dev/Conditionals-with-Terraform/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-locking"
    encrypt        = true
  }
}