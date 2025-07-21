terraform {
  required_version = ">=0.13"

  required_providers {
    google = {
      version = "6.42.0"
      source  = "hashicorp/google"
    }
  }
}