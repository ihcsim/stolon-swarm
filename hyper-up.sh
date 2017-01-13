#!/bin/bash

usage() {
  cat <<EOF
The following is the list of required variables:
  ETCD_VERSION                   Etcd Docker image version.
  ETCD_TOKEN                     Initial cluster token for the etcd cluster during bootstrap.
  HYPER_CONTAINER_SIZE           Hyper container sizes. Refer https://www.hyper.sh/pricing.html
  IMAGE_TAG_SENTINEL             Stolon Sentinel Docker image tag.
  IMAGE_TAG_KEEPER               Stolon Keeper Docker image tag.
  IMAGE_TAG_PROXY                Stolon Proxy Docker image tag.
  STOLON_PROXY_PORT              Port that Stolon Proxy listens on.
  STOLON_KEEPER_PG_SU_PASSWORD   Postgres user password used by Stolon Keeper to interact with Postgres.
  STOLON_KEEPER_PG_REPL_PASSWORD Postgres replication user password used by Stolon Keeper to perform replication operation.
EOF
}

if [ -z "$ETCD_VERSION" ]
then
  echo "Can't create etcd cluster. Missing required ETCD_VERSION."
  usage
  exit 1
fi

if [ -z "$ETCD_TOKEN" ]
then
  echo "Can't create etcd cluster. Missing required ETCD_TOKEN."
  usage
  exit 1
fi

if [ -z "$HYPER_CONTAINER_SIZE" ]
then
  echo "Can't create hyper containers. Missing required HYPER_CONTAINER_SIZE."
  usage
  exit 1
fi

if [ -z "$IMAGE_TAG_SENTINEL" ]
then
  echo "Can't create stolon cluster. Missing required IMAGE_TAG_SENTINEL."
  usage
  exit 1
fi

if [ -z "$IMAGE_TAG_KEEPER" ]
then
  echo "Can't create stolon cluster. Missing required IMAGE_TAG_KEEPER."
  usage
  exit 1
fi

if [ -z "$IMAGE_TAG_PROXY" ]
then
  echo "Can't create stolon cluster. Missing required IMAGE_TAG_PROXY."
  usage
  exit 1
fi

if [ -z "$STOLON_PROXY_PORT" ]
then
  echo "Can't create stolon cluster. Missing required STOLON_PROXY_PORT."
  usage
  exit 1
fi

if [ -z "$STOLON_KEEPER_PG_SU_PASSWORD" ]
then
  echo "Can't create stolon cluster. Missing required STOLON_KEEPER_PG_SU_PASSWORD."
  usage
  exit 1
fi

if [ -z "$STOLON_KEEPER_PG_REPL_PASSWORD" ]
then
  echo "Can't create stolon cluster. Missing required STOLON_KEEPER_PG_REPL_PASSWORD."
  usage
  exit 1
fi

declare -a etcd_nodes
etcd_nodes=(etcd-00 etcd-01 etcd-02)
for node in "${etcd_nodes[@]}"
do
  etcd_cluster=$etcd_cluster,$node=http://$node:2380
  etcd_endpoints=$etcd_endpoints,http://$node:2379
done

for node in "${etcd_nodes[@]}"
do
  hyper run --name $node --hostname $node --size $HYPER_CONTAINER_SIZE -d quay.io/coreos/etcd:$ETCD_VERSION \
    etcd \
    --name $node \
    --data-dir=data.etcd \
    --advertise-client-urls http://$node:2379 \
    --listen-client-urls http://0.0.0.0:2379 \
    --initial-advertise-peer-urls http://$node:2380 \
    --listen-peer-urls http://0.0.0.0:2380 \
    --initial-cluster $etcd_cluster \
    --initial-cluster-state new \
    --initial-cluster-token $ETCD_TOKEN
done

hyper service create --name sentinel \
  --size $HYPER_CONTAINER_SIZE \
  --replicas 1 \
  --service-port 5432 \
  --label role=sentinel \
  -e STSENTINEL_STORE_ENDPOINTS=$etcd_endpoints \
  $IMAGE_TAG_SENTINEL

hyper service create --name keeper \
  --size $HYPER_CONTAINER_SIZE \
  --replicas 3 \
  --service-port 5432 \
  --label role=keeper \
  -e STKEEPER_PG_SU_PASSWORD=$STOLON_KEEPER_PG_SU_PASSWORD \
  -e STKEEPER_PG_REPL_PASSWORD=$STOLON_KEEPER_PG_REPL_PASSWORD \
  -e STKEEPER_STORE_ENDPOINTS=$etcd_endpoints \
  $IMAGE_TAG_KEEPER

hyper service create --name proxy \
  --size $HYPER_CONTAINER_SIZE \
  --replicas 1 \
  --service-port $STOLON_PROXY_PORT \
  --label role=proxy \
  -e STPROXY_STORE_ENDPOINTS=$etcd_endpoints \
  $IMAGE_TAG_PROXY

if [ ! -z "$PROXY_FLOATING_IP" ]
then
  echo "Attaching floating IP $PROXY_FLOATING_IP to proxy service..."
  while [ `hyper service inspect -f {{.Status}} proxy` != 'active' ]
  do
    echo "Proxy service isn't ready yet...Sleeping for 3 seconds"
    sleep 3
  done

  hyper service attach-fip --fip $PROXY_FLOATING_IP proxy
  echo -e "\n\nCompleted!\nYou can access the Stolon cluster using:\n  psql -h $PROXY_FLOATING_IP -p $STOLON_PROXY_PORT -U postgres"
fi
