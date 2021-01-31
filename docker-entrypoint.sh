#!/bin/bash

SENTINEL_CONFIG="/data/${HOSTNAME}/sentinel.conf"
REDIS_CONFIG="/data/${HOSTNAME}/redis.conf"

create_sentinel_config(){
cat <<EOF > "${SENTINEL_CONFIG}"
sentinel monitor ${INSTANCE_NAME} ${REDIS_POD_NAME}-0.${REDIS_SERVICE_NAME} 6379 2
sentinel down-after-milliseconds ${INSTANCE_NAME} 5000
sentinel failover-timeout ${INSTANCE_NAME} 60000
sentinel parallel-syncs ${INSTANCE_NAME} 1
sentinel auth-pass ${INSTANCE_NAME} ${PASSWORD}
EOF
}
create_redis_config(){
cat <<EOF > "${REDIS_CONFIG}"
dir /data/${HOSTNAME}
appendonly yes
masterauth ${PASSWORD}
user default on +@all ~* >${PASSWORD}
EOF
}

# sentinel
# if config isn't there create it
# if it is there start and reset config


# asks if sentinel is there and who's the primary
# if there is a primary connect to it
# if no sentinel or no primary and "-0" I'm the primary
# if no sentinel or no primary and not "-0", "-0" is the primary

# if sentinel-0 comes back it has to ask the other sentinels if there is a primary


# If using bind mount on the same node or shared persistent volume, config files
# and database persistence will clober each other. To avoid issues with this
# each pod gets it's own subfolder.
mkdir "/data/${HOSTNAME}" 2>/dev/null

if [[ "${HOSTNAME}" =~ redis ]]
then
  rm -rf "/data/${HOSTNAME}/*" 2>/dev/null
fi

# we are starting a redis server
if [ "$1" == "redis-server" ]
then
  # On first start generate config file and connect replicas to "-0" primary
  # redis wont change the config file, we are just using it to indicate this is
  # the first time we are running redis
  if [ ! -f "${REDIS_CONFIG}" ]
  then
    create_redis_config
    if [[ "${HOSTNAME}" =~ -0$ ]]
    then
      # start primary
      redis-server "${REDIS_CONFIG}"
    else
      # start replica
      redis-server "${REDIS_CONFIG}" --replicaof "${REDIS_POD_NAME}"-0."${REDIS_SERVICE_NAME}" 6379
    fi
  else
    # just start redis, sentinel will reconnect known replicas
    redis-server "${REDIS_CONFIG}"
  fi
fi

# we are starting a redis sentinel server
if [ "$1" == "redis-sentinel" ]
then
  # on first start generate config file, sentinel will mofify contents as needed
  # persisting through runs and restarts
  if [ ! -f "${SENTINEL_CONFIG}" ]
  then
    create_sentinel_config
  fi
  redis-sentinel "${SENTINEL_CONFIG}"
fi
