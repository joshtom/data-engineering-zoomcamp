terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "7.16.0"
    }
  }
}

provider "google" {
  credentials = "./keys/my-cred.json"
  project     = "terraform-484615-bucket-29389283"
  region      = "us-central1"
}

resource "google_storage_bucket" "demo-bucket" {
  name          = "auto-expiring-bucket"
  location      = "US"
  force_destroy = true


  lifecycle_rule {
    condition {
      age = 1
    }
    action {
      type = "AbortIncompleteMultipartUpload"
    }
  }
}
