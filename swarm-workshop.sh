#!/bin/bash

set -euo pipefail

# Usage:
#   1. Create a keypair
#      swarm-workshop.sh keypair
#   2. Create the servers
#      swarm-workshop.sh create [from_user] [to_user] [from_node] [to_node]
#      e.g. swarm-workshop.sh create 1 20 1 5
#   3. You'll know the servers are ready when version returns the proper Docker version
#      swarm-workshop.sh version [from_user] [to_user] [from_node] [to_node]
#   4. Clusterize the servers
#      swarm-workshop.sh clusterize [from_user] [to_user] [from_node] [to_node]
#   5. (Optional) Test the servers with the hello-world image
#      swarm-workshop.sh hello [from_user] [to_user] [from_node] [to_node]
#   6. Delete the servers
#      dockerswarm100.sh delete [from_user] [to_user] [from_node] [to_node]
# Requirements:
#   Environment Variables:
#     export RS_USERNAME={my-rackspace-username}
#     export RS_API_KEY={my-rackspace-api-key}
#   rack: The Rackspace command line interface for managing Rackspace services
#     https://developer.rackspace.com/docs/rack-cli/configuration/#installation-and-configuration

main() {
  SUB_COMMAND=${1}
  FROM_USER=${2:-0}
  TO_USER=${3:-0}
  FROM_NODE=${4:-0}
  TO_NODE=${5:-0}

  ${SUB_COMMAND}
}

loop() {
  DO_FUNCTION=$1

  for region in IAD; do
    RS_REGION_NAME=${region}
    echo -e "Region\t\t${RS_REGION_NAME}"

    for u in $(seq -f "%02g" ${FROM_USER} ${TO_USER}); do
      for n in $(seq ${FROM_NODE} ${TO_NODE}); do
        USERNAME=user${u}
        SERVER_NAME=${USERNAME}-node${n}
        echo -e "Name\t\t${SERVER_NAME}"
        ${DO_FUNCTION}
      done
    done
  done
}

keypair() {
  ssh-keygen -q -b 4096 -t rsa -N "" -f ~/.ssh/id_rsa.swarm

  for region in IAD; do
    RS_REGION_NAME=${region}
    rack servers keypair upload --name swarm --file ~/.ssh/id_rsa.swarm.pub
  done

}

create() {
  loop do_create
}

do_create() {
  rack servers instance create \
    --region ${RS_REGION_NAME} \
    --name ${SERVER_NAME} \
    --image-name "Ubuntu 16.04 LTS (Xenial Xerus) (PVHVM)" \
    --flavor-name "1 GB General Purpose v1" \
    --keypair swarm \
    --user-data swarm-workshop-dockerize.sh
}

clusterize() {
  loop do_clusterize
}

do_clusterize() {
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
  loop do_delete
}

do_delete() {
  rack servers instance delete --name ${SERVER_NAME}
}

version() {
  loop do_version
}

do_version() {
  SERVER_IP=$(get_server_ip)
  DOCKER_VERSION=$(ssh -i ~/.ssh/id_rsa.swarm root@${SERVER_IP} docker version | grep Version | tail -n 1 | awk '{print $2}')
  echo -e "Version\t\t${DOCKER_VERSION}"
}

hello() {
  loop do_hello
}

do_hello() {
  SERVER_IP=$(get_server_ip)
  ssh -i ~/.ssh/id_rsa.swarm root@${SERVER_IP} docker run alpine echo "Hello World"
}

info() {
  loop do_info
}

do_info() {
  SERVER_IP=$(get_server_ip)
  ssh -i ~/.ssh/id_rsa.swarm root@${SERVER_IP} docker info | awk '/Swarm/,/Runtimes/' | sed '$ d'
}

get_server_ip() {
  echo $(rack servers instance get --name ${SERVER_NAME} --fields publicipv4 | awk '{print $2}')
}

main $@
