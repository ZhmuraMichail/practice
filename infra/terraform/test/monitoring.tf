resource "yandex_compute_instance" "testprometh" {
  name = "prometh"
  resources {
    cores = 2
    memory = 2
  }
  boot_disk {
    initialize_params{
      image_id = "fd8k5kam36qhmnojj8je"
      size = 15
    }
  
  }
 
  network_interface {
        subnet_id = yandex_vpc_subnet.subnet-1.id
 	nat = true
 		
	}
  metadata = {
  ssh-keys = "ubuntu:${file("~/.ssh/101.pub")}"
  
}
 
 }
resource "yandex_compute_instance" "testgrafana" {
  name = "grafana"
  resources {
    cores = 2
    memory = 2
  }
  boot_disk {
    initialize_params{
      image_id = "fd8k5kam36qhmnojj8je"
      size = 15
    }
  
  }
 
  network_interface {
        subnet_id = yandex_vpc_subnet.subnet-1.id
 	nat = true
 		
	}
  metadata = {
  ssh-keys = "ubuntu:${file("~/.ssh/101.pub")}"
  
}
  
   
   }
resource "null_resource" "testmonit" {
  depends_on = [yandex_compute_instance.testprometh, yandex_compute_instance.testgrafana]
    
    provisioner "remote-exec"{
          inline = ["echo hello"]
          
          connection {
              type  = "ssh"
              user  = "ubuntu"
              host  = "${yandex_compute_instance.testgrafana.network_interface.0.nat_ip_address}"
              }
            } 
    provisioner "remote-exec"{
          inline = ["echo hello"]
          
          connection {
              type  = "ssh"
              user  = "ubuntu"
              host  = "${yandex_compute_instance.testprometh.network_interface.0.nat_ip_address}"
              }
            }   
    provisioner "local-exec"{ 
  	  command = "ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -u ubuntu -i '${yandex_compute_instance.testprometh.network_interface.0.nat_ip_address},' ../ansible/monitoring-playbook.yaml --extra-vars 'record_name=${yandex_dns_recordset.testprom.name}'   -b -vvv"	   
   }  
    provisioner "local-exec"{ 
  	  command = "ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -u ubuntu -i '${yandex_compute_instance.testgrafana.network_interface.0.nat_ip_address},'  ../ansible/grafana.yaml --extra-vars 'record_name=${yandex_dns_recordset.testgraf.name}'   -b -vvv"	   
   }   
    }
resource "yandex_dns_recordset" "testprom"{
	zone_id = yandex_dns_zone.zone1.id
	name = "www.${var.domain_name_2}"
	type = "A"
	ttl = 600
	data = ["${yandex_compute_instance.testprometh.network_interface.0.nat_ip_address}"]
}
resource "yandex_dns_recordset" "testgraf"{
	zone_id = yandex_dns_zone.zone1.id
	name = "www.${var.domain_name_3}"
	type = "A"
	ttl = 600
	data = ["${yandex_compute_instance.testgrafana.network_interface.0.nat_ip_address}"]
}





# Выведем IP адрес сервера

output "my_prom_site_ip" {
  description = "Elatic IP address assigned to our Git-runner Server"
  value       = yandex_compute_instance.testprometh.network_interface.0.nat_ip_address
}
output "my_graf_site_ip" {
  description = "Elatic IP address assigned to our Git-runner Server"
  value       = yandex_compute_instance.testgrafana.network_interface.0.nat_ip_address
}

