.PHONY: build secrets local-up local-clean

include .env

export ETCD_VERSION ETCD_TOKEN IMAGE_TAG_SENTINEL IMAGE_TAG_KEEPER IMAGE_TAG_PROXY STOLON_PROXY_PORT STOLON_KEEPER_PG_SU_PASSWORDFILE STOLON_KEEPER_PG_REPL_PASSWORDFILE SWARM_MANAGER SWARM_WORKER_00 SWARM_WORKER_01 SWARM_WORKER_02 DO_REGION DO_SIZE COMPOSE_PROJECT_NAME HYPER_CONTAINER_SIZE

VCS_REF = `git rev-parse --short HEAD`

build: secrets sentinel keeper proxy

sentinel:
	docker build --rm -t ${IMAGE_TAG_SENTINEL} \
		--label org.label-schema.vcs-ref=${VCS_REF} \
		--label org.label-schema.vcs-url="https://github.com/ihcsim/stolon-swarm"	\
		-f Dockerfile-Sentinel .

keeper:
	docker build --rm -t ${IMAGE_TAG_KEEPER} \
		--label org.label-schema.vcs-ref=${VCS_REF} \
		--label org.label-schema.vcs-url="https://github.com/ihcsim/stolon-swarm"	\
		-f Dockerfile-Keeper .

proxy:
	docker build --rm -t ${IMAGE_TAG_PROXY} \
		--label org.label-schema.vcs-ref=${VCS_REF} \
		--label org.label-schema.vcs-url="https://github.com/ihcsim/stolon-swarm"	\
		-f Dockerfile-Proxy .

secrets:
	rm -rf etc/secrets
	mkdir -p etc/secrets
	cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1 >> etc/secrets/pgsql
	cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1 >> etc/secrets/pgsql-repl

local-up:
	@test -n "${ETCD_TOKEN}" # Please provide a value for $${ETCD_TOKEN}
	./local-up.sh

local-clean:
	./local-clean.sh

local-purge:
	PURGE_VOLUMES=true ./local-clean.sh

compose-up:
	@test -n "${ETCD_TOKEN}" # Please provide a value for $${ETCD_TOKEN}
	docker-compose up -d --remove-orphans

compose-down:
	docker-compose down --remove-orphans

compose-purge:
	docker-compose down -v --remove-orphans

swarm-local:
	swarm/local.sh

swarm-droplets:
	@test -n "${DO_ACCESS_TOKEN}" # Please provide a value for $${DO_ACCESS_TOKEN}
	@test -n "${DO_SSH_KEY_FINGERPRINT}" # Please provide a value for $${DO_SSH_KEY_FINGERPRINT}
	swarm/droplet.sh

swarm-init:
	swarm/init.sh

swarm-build: secrets
	swarm/build.sh

swarm-stolon:
	@test -n "${ETCD_TOKEN}" # Please provide a value for $${ETCD_TOKEN}
	swarm/stolon.sh

swarm-clean:
	swarm/clean.sh

swarm-destroy:
	DESTROY_MACHINES=true swarm/clean.sh

hyper-up: secrets
	@test -n "${ETCD_TOKEN}" # Please provide a value for $${ETCD_TOKEN}
	$(eval export STOLON_KEEPER_PG_SU_PASSWORD = $(shell cat etc/secrets/pgsql))
	$(eval export STOLON_KEEPER_PG_REPL_PASSWORD = $(shell cat etc/secrets/pgsql-repl))
	./hyper-up.sh

hyper-clean:
	./hyper-clean.sh

hyper-purge:
	PURGE_VOLUMES=true ./hyper-clean.sh
