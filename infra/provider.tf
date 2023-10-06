# Указываем, что мы хотим разворачивать окружение в Yandex.cloud
terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
 required_version = ">= 0.13"
}


provider "yandex" {
  token = var.token
  cloud_id = var.cloud_id
  folder_id = var.folder_id
  zone = "ru-central1-a"
}

resource "yandex_iam_service_account" "sa" {
  folder_id   = var.folder_id
  description = "Service account for terraform"
  name        = "sa"
}

resource "yandex_resourcemanager_folder_iam_member" "sa-editor" {
  folder_id = var.folder_id
  role      = "storage.editor"
  member    = "serviceAccount:${yandex_iam_service_account.sa.id}"
}

resource "yandex_iam_service_account_static_access_key" "keys" {
  service_account_id = yandex_iam_service_account.sa.id
  description        = "Access keys for object storage"
}

resource "yandex_storage_bucket" "backups" {
  bucket     = "bucket345"
  access_key = yandex_iam_service_account_static_access_key.keys.access_key
  secret_key = yandex_iam_service_account_static_access_key.keys.secret_key

  lifecycle_rule {
    prefix  = "config/"
    enabled = true

    noncurrent_version_transition {
      days          = 30
      storage_class = "COLD"
    }

    noncurrent_version_expiration {
      days = 90
    }
  }
}

