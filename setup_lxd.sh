#!/usr/bin/env bash
set -euo pipefail

export NUM_MASTER=1
export NUM_WORKER=0

add_lxd_profile() {
  lxc profile copy default single_node
  lxc profile copy default multi_node_master
  lxc profile copy default multi_node_worker
}

setup_single_node() {
  lxc launch ubuntu:18.04 single-node --profile single_node
}

setup_multi_node() {
  for num_node in $(seq "$NUM_MASTER"); do
    lxc launch ubuntu:18.04 master-"$num_node" --profile multi_node_master
    # echo "master-$num_node"
  done
  for num_node in $(seq "$NUM_WORKER"); do
    lxc launch ubuntu:18.04 worker-"$num_node" --profile multi_node_worker
    # echo "worker-$num_node"
  done
}

analyze_command_options(){
  # shellcheck disable=SC2086
  set -- $opts
  for arg in "$@"; do
    case $arg in
      -m | --master) NUM_MASTER=$2; shift 2;;
      -w | --worker) NUM_WORKER=$2; shift 2;;
      --) shift; break;;
    esac
  done
}

check_num_nodes(){
  if [ "$NUM_WORKER" -eq 0 ]; then
    echo 'No option required if you want single node configuration.'
    echo 'Now starting setup for single node.'
    setup_single_node
  elif [ "$NUM_WORKER" -gt 0 ]; then
    if [ "$NUM_MASTER" -eq 1 ] || [[ "$NUM_MASTER" -ge 3 && "$NUM_WORKER" -ge 3 ]]; then
      setup_multi_node
    else
      echo 'At least 3 master and worker nodes are required to configure the highly available cluster. Aborted!'
      exit 1
    fi
  fi
}

opts=$(getopt --unquoted --options m:,w: --longoptions master:,worker: -- "$@")

if ! lxc profile list 2> /dev/null | grep -e single_node -e multi_node_master -e multi_node_worker; then
  add_lxd_profile
fi

analyze_command_options

check_num_nodes
