#!/bin/bash

if [ "$PURGE_VOLUMES" ]
then
  purge_volumes="-v"
fi

hyper service detach-fip proxy
hyper service rm sentinel proxy keeper
hyper rm -f $purge_volumes etcd-00 etcd-01 etcd-02
