#!/bin/bash

set -euo pipefail

# Usage:
#   swarm-workshop.sh create
#   swarm-workshop.sh version
#   swarm-workshop.sh hello
#   swarm-workshop.sh clusterize
#   dockerswarm100.sh delete
# Requirements:
#   Environment Variables:
#     export RS_USERNAME={my-rackspace-username}
#     export RS_API_KEY={my-rackspace-api-key}
#   rack: The Rackspace command line interface for managing Rackspace services
#     https://developer.rackspace.com/docs/rack-cli/configuration/#installation-and-configuration
#   Keypair named swarm
#     ssh-keygen -q -b 4096 -t rsa -N "" -f ~/.ssh/id_rsa.swarm
#     for region in IAD; do
#       export RS_REGION_NAME=${region}
#       rack servers keypair upload --name swarm --file ~/.ssh/id_rsa.swarm.pub
#     done

main() {
  echo "$@"
  loop $@
}

loop() {
  for region in IAD; do
    export RS_REGION_NAME=${region}
    echo -e "Region\t\t${RS_REGION_NAME}"

    for u in $(seq -f "%02g" 1 1); do
      for n in $(seq 1 5); do
        USERNAME=user${u}
        SERVER_NAME=${USERNAME}-node${n}
        echo -e "Name\t\t${SERVER_NAME}"
        "$@"
      done
    done
  done
}

create() {
  rack servers instance create \
    --region ${RS_REGION_NAME} \
    --name ${SERVER_NAME} \
    --image-name "Ubuntu 16.04 LTS (Xenial Xerus) (PVHVM)" \
    --flavor-name "1 GB General Purpose v1" \
    --keypair swarm \
    --user-data swarm-workshop-dockerize.sh
}

clusterize() {
  IFS=$'\n'
  hosts=""
  nodes=$(rack servers instance list --name ${USERNAME} --fields name,publicipv4,privateipv4 --no-header)
  for node in ${nodes[@]}; do
    hostname=$(echo ${node} | awk '{print $1}' | awk -F'-' '{print $2}')

    # publicipv4=$(echo ${node} | awk '{print $2}')
    privateipv4=$(echo ${node} | awk '{print $3}')

    # hosts="${hosts}\\\n${publicipv4}\\\t${hostname}"
    hosts="${hosts}\\\n${privateipv4}\\\t${hostname}"
  done

  SERVER_IP=$(get_server_ip)
  scp -i ~/.ssh/id_rsa.swarm ~/.ssh/id_rsa.swarm docker@${SERVER_IP}:.ssh/id_rsa
  ssh -i ~/.ssh/id_rsa.swarm root@${SERVER_IP} "/bin/bash -c 'echo -e ${hosts} >> /etc/hosts'"
}

delete() {
  rack servers instance delete --name ${SERVER_NAME}
}

version() {
  SERVER_IP=$(get_server_ip)
  DOCKER_VERSION=$(ssh -i ~/.ssh/id_rsa.swarm root@${SERVER_IP} docker version | grep Version | tail -n 1 | awk '{print $2}')
  echo -e "Version\t\t${DOCKER_VERSION}"
}

hello() {
  SERVER_IP=$(get_server_ip)
  ssh -i ~/.ssh/id_rsa.swarm root@${SERVER_IP} docker run alpine echo "Hello World"
}

info() {
  SERVER_IP=$(get_server_ip)
  ssh -i ~/.ssh/id_rsa.swarm root@${SERVER_IP} docker info | awk '/Swarm/,/Runtimes/' | sed '$ d'
}

get_server_ip() {
  echo $(rack servers instance get --name ${SERVER_NAME} --fields publicipv4 | awk '{print $2}')
}

main $@
