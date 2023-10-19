#!/bin/bash

########################
###   COMMON BLOCK   ###
########################
common() {
              mkdir -p /home/ubuntu/boundary
              chown ubuntu /home/ubuntu/boundary
              chgrp ubuntu /home/ubuntu/boundary
              echo "${priv_key}" >> /home/ubuntu/.ssh/id_rsa
              chown ubuntu /home/ubuntu/.ssh/id_rsa
              chgrp ubuntu /home/ubuntu/.ssh/id_rsa
              chmod 600 /home/ubuntu/.ssh/id_rsa
              apt-get update -y
              apt-get install ansible boundary-enterprise -y 
}

########################
###    Worker BLOCK   ###
########################
worker_config() {

tee /home/ubuntu/boundary/pki-worker.hcl > /dev/null <<EOF

disable_mlock = true

hcp_boundary_cluster_id = "` echo ${boundary_cluster_addr} | cut -c 9- | cut -d . -f 1`"

listener "tcp" {
 address = "0.0.0.0:9202"
 purpose = "proxy"
}

worker {
 public_addr = "$(public_ip)"
 auth_storage_path = "/home/ubuntu/boundary/worker1"
 tags {
  type = ["worker1", "upstream"]
 }
 recording_storage_path = "/home/ubuntu/boundary/sessionrecordingstorage"
 controller_generated_activation_token = "${worker_token}"

}

EOF

chown ubuntu /home/ubuntu/boundary/pki-worker.hcl
chgrp ubuntu /home/ubuntu/boundary/pki-worker.hcl


}

worker_start() {
  boundary server -config /home/ubuntu/boundary/pki-worker.hcl
}

####################
#####   MAIN   #####
####################

common
worker_config
worker_start
