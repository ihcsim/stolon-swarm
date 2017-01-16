#!/bin/bash

sleep ${WAIT_FOR_CLUSTER}
echo 'Bootstrapping cluster....Waiting for cluster to be ready...'
stolonctl status --cluster-name ${CLUSTER_NAME} --store-backend etcd --store-endpoints http://etcd:2379
