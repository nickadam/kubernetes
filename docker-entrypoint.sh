#!/bin/bash

SENTINEL_CONFIG="/data/${HOSTNAME}/sentinel.conf"
REDIS_CONFIG="/data/${HOSTNAME}/redis.conf"

create_sentinel_config(){
cat <<EOF > "${SENTINEL_CONFIG}"
sentinel monitor ${INSTANCE_NAME} ${REDIS_POD_NAME}-${1}.${REDIS_SERVICE_NAME} 6379 2
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

# If using bind mount on the same node or shared persistent volume, config files
# and database persistence will clober each other. To avoid issues with this
# each pod gets it's own subfolder.
mkdir "/data/${HOSTNAME}" 2>/dev/null

# we are starting a redis server
if [ "$1" == "redis-server" ]
then
  create_redis_config
  # this is -0
  if [[ "${HOSTNAME}" =~ -0$ ]]
  then
    # check if -1 is the primary
    if redis-cli -h "${REDIS_POD_NAME}"-1."${REDIS_SERVICE_NAME}" -a "${PASSWORD}" info 2>/dev/null | grep role:master >/dev/null
    then
      # start replica
      redis-server "${REDIS_CONFIG}" --replicaof "${REDIS_POD_NAME}"-1."${REDIS_SERVICE_NAME}" 6379
    else
      # start primary
      redis-server "${REDIS_CONFIG}"
    fi
  else
    # start replica
    redis-server "${REDIS_CONFIG}" --replicaof "${REDIS_POD_NAME}"-0."${REDIS_SERVICE_NAME}" 6379
  fi
fi

# we are starting a redis sentinel server
if [ "$1" == "redis-sentinel" ]
then
  # check if -1 is the primary and create a config to match
  if redis-cli -h "${REDIS_POD_NAME}"-1."${REDIS_SERVICE_NAME}" -a "${PASSWORD}" info 2>/dev/null | grep role:master >/dev/null
  then
    create_sentinel_config 1
  else
    create_sentinel_config 0
  fi
  # reset sentinel above me after waiting for at least a multiple of 30 seconds of this instance
  # this will clean up any dead sentinels that preceded me
  {
    NEXT_ORDINAL=$(($(echo "${HOSTNAME}" | egrep -o [0-9]+$) + 1))
    sleep $(($NEXT_ORDINAL * 30))
    redis-cli -h "${REDIS_SENTINEL_POD_NAME}"-"${NEXT_ORDINAL}"."${REDIS_SENTINEL_SERVICE_NAME}" -p 26379 sentinel reset \*
  } &
  redis-sentinel "${SENTINEL_CONFIG}"
fi
