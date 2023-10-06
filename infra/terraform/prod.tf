# Создаём Launch Configuration - это сущность, которая определяет конфигурацию запускаемых серверов.
resource "yandex_compute_image" "web" {
  # какой будет использоваться образ
  source_family = "lemp"
  lifecycle {
    create_before_destroy = true
  }
}
# Запускаем инстанс
resource "yandex_compute_instance" "serv" {
  name = "reactjs1"
  resources {
    cores = 2
    memory = 2
  }
  boot_disk {
    initialize_params{
      image_id = "fd8k5kam36qhmnojj8je"
      size = 60
    }
  
  }
  network_interface {
    subnet_id = yandex_vpc_subnet.subnet-1.id
    nat = true
  } 
  metadata = {
    ssh-keys = "root:${file("~/.ssh/101.pub")}"
  }
  	
}
resource "null_resource" "serv" {
  depends_on = [yandex_compute_instance.serv]
    
  provisioner "local-exec"{ 
  	  command = "ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -u ubuntu -i '${(yandex_compute_instance.serv.network_interface.0.nat_ip_address)},' ../ansible/gitlab-playbook.yaml -e 'runner_tags=prod' -b -vvv"
  	  }
  provisioner "local-exec"{ 
  	  command = "ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -u ubuntu -i '${(yandex_compute_instance.serv.network_interface.0.nat_ip_address)},' ../../service/service-playbook.yaml -b -vvv"
  	  }       
  }
# для указания, сколько нам понадобится инстансов 
resource "yandex_compute_instance_group" "web" {
  service_account_id = var.service_account_id
  instance_template {
  
  	platform_id = "standard-v3"
    	
    	resources {
		memory = 2
		cores = 2
		core_fraction = 100
		}  
    	boot_disk {
    		mode = "READ_WRITE"
    		initialize_params {
        	image_id = "${yandex_compute_image.web.id}"
        	size     = 30
      }
    		}
    	
	network_interface {
	network_id = "${yandex_vpc_network.network-1.id}"
        subnet_ids = ["${yandex_vpc_subnet.subnet-1.id}"]
 	nat = true
 		
	}
	metadata = {
    		ssh-keys = "ubuntu:${file("~/.ssh/101.pub")}"	
}	
	}
 	allocation_policy {
  	zones = ["ru-central1-a"]
  		}
  	deploy_policy {
  		max_unavailable = 0
  		max_expansion = 100 
  		}
  
  	scale_policy {
  		auto_scale {
  			initial_size = 2
  			max_size = 2
  			min_zone_size = 2
  			measurement_duration = 120
  			warmup_duration = 30
  			cpu_utilization_target = 75
  }
  }
  	load_balancer {
  		target_group_name = "nlb-1"
  		}
  	provisioner "remote-exec"{
          inline = ["echo hello"]
          
          connection {
              type  = "ssh"
              user  = "ubuntu"
              host  = "${yandex_compute_instance.serv.network_interface.0.nat_ip_address}"
              }
            }
  	provisioner "local-exec"{ 
  	  command = "ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -u ubuntu -i '${join(",",yandex_compute_instance_group.web.instances[*].network_interface.0.nat_ip_address)}' ../ansible/nginx.yaml -e 'tf_host_ip_address=${yandex_compute_instance.serv.network_interface.0.nat_ip_address}' -b -vvv"
  	  }
}

# Elastic Load Balancer проксирует трафик на наши сервера 
resource "yandex_lb_network_load_balancer" "web" {
  name               = "nlb-1"
  listener {
  	name = "listen"
  	port = 80
  	target_port = 80
  	}
  listener {
  	name = "listen-1"
  	port = 8080
  	target_port = 8080
  	external_address_spec {
  	
  	}
  	}
  attached_target_group {
  	target_group_id = "${yandex_compute_instance_group.web.load_balancer.0.target_group_id}"
  	healthcheck {
  		name = "health-check-1"
  		unhealthy_threshold = 5
  		healthy_threshold = 5
  		http_options {
  			port = 80
  			}
  		}
  	}
  
 }
resource "yandex_dns_recordset" "rs1"{
	zone_id = yandex_dns_zone.zone1.id
	name = "www.${var.domain_name}"
	type = "A"
	ttl = 600
	data = ["${[for s in yandex_lb_network_load_balancer.web.listener: s.external_address_spec.*.address].0[0]}"]
}
# Выведем IP адрес сервера
output "instance_group_ip"{
  description = "ip instane group"
  value       = yandex_compute_instance_group.web.instances[*].network_interface.0.nat_ip_address
  }
output "my_web_site_ip" {
  description = "Elatic IP address assigned to our ReactJS Server"
  value       = yandex_compute_instance.serv.network_interface.0.nat_ip_address
}
