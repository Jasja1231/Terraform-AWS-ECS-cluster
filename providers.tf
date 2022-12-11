#=====================================================================
    #Providers
#=====================================================================
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }

    docker = {
      source  = "kreuzwerker/docker"
      version = "2.23.1"
    }
  }
}


#=====================================================================
    #Configure the AWS Provider
#=====================================================================
provider "aws" {
  region                   = "eu-central-1"
  shared_credentials_files = ["/home/yaryna/.aws/credentials"]
  profile                  = "vscode"
} 

#=====================================================================
    #Docker
#=====================================================================

provider "docker" {
  host = "unix:///var/run/docker.sock"
}
