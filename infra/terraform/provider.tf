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
resource "yandex_vpc_security_group" "my_webserver" {
  network_id = yandex_vpc_network.network-1.id
  name        = "Dynamic Security Group"
 

  dynamic "ingress" {
    for_each = ["80", "22", "81"]
    content{
      from_port = ingress.value
      to_port = ingress.value
      protocol       = "TCP"
      v4_cidr_blocks = ["0.0.0.0/0"]
    }
  }

  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 0
    to_port        = 0
  }
}
resource "yandex_vpc_network" "network-1" { 
  name = "network1"
}
#Создаем  DNS зону и ресурсную запись для балансировщика
resource "yandex_dns_zone" "zone1" {
	name = "test-zone"
	description = "desk"
	zone = "zhmura.online."
	public = true
}
resource "yandex_vpc_subnet" "subnet-1" {
  name           = "subnet1"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.network-1.id
  v4_cidr_blocks = ["192.168.10.0/24"]
}

