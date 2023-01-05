#!/bin/bash
set -x

ROOST_AUTH_TOKEN=$(eval "echo \"\$$ORB_ENV_AUTH_TOKEN\"")
ENT_SERVER=$(eval "echo \"\$$ORB_ENV_ENT_SERVER\"")
echo $ROOST_AUTH_TOKEN
echo $ENT_SERVER

pre_checks() {
  if [ -z "$ROOST_AUTH_TOKEN" ]; then
    echo "The ROOST_AUTH_TOKEN is not found. Please add the ROOST_AUTH_TOKEN as an environment variable in CicleCI before continuing."
    exit 1
  fi

  ROOT_DISK_SIZE="${DISK_SIZE}GB"
  if [ -z "${ALIAS}" ]; then
    ALIAS=$(date +%s)
  fi
}

create_cluster() {
  echo "https://${ENT_SERVER}/api/application/client/launchCluster"
  echo $ROOST_AUTH_TOKEN
  echo $ALIAS
  echo $NAMESPACE
  echo $EMAIL
  echo $K8S_VERSION
  echo $NUM_WORKERS
  echo $PREEMPTIBLE
  echo $CLUSTER_EXPIRY
  echo $REGION
  echo $ROOT_DISK_SIZE
  echo $INSTANCE_TYPE
  echo $AMI
  RESPONSE_CODE=$(curl --location --silent --request POST "https://${ENT_SERVER}/api/application/client/launchCluster" \
  --header "Content-Type: application/json" \
  --data-raw "{
    \"ROOST_AUTH_TOKEN\": \"$ROOST_AUTH_TOKEN\",
    \"alias\": \"${ALIAS}\",
    \"namespace\": \"${NAMESPACE}\",
    \"customer_email\": \"${EMAIL}\",
    \"k8s_version\": \"${K8S_VERSION}\",
    \"num_workers\": ${NUM_WORKERS},
    \"preemptible\": ${PREEMPTIBLE},
    \"cluster_expires_in_hours\": ${CLUSTER_EXPIRY},
    \"region\": \"${REGION}\",
    \"disk_size\": \"${ROOT_DISK_SIZE}\",
    \"instance_type\": \"$INSTANCE_TYPE\",
    \"ami\": \"${AMI}\"
  }" | jq -r '.ResponseCode')
  if [ "${RESPONSE_CODE}" -eq 0 ]; then
    get_kubeconfig
  else
    echo "Failed to launch cluster. please try again"
    exit 1
  fi
}

get_kubeconfig() {
  sleep 5m
  for i in {1..10}
  do
    KUBECONFIG=$(curl --location --silent --request POST "https://${ENT_SERVER}/api/application/cluster/getKubeConfig" \
    --header "Content-Type: application/json" \
    --data-raw "{
      \"app_user_id\" : \"${ROOST_AUTH_TOKEN}\",
      \"cluster_alias\" : \"${ALIAS}\"
    }" | jq -r '.kubeconfig')

    if [ "${KUBECONFIG}" == "null" ]; then
      echo "$i sleeping now for 30s"
      sleep 30
    else
      echo "Cluster created successfully."
      break
    fi
  done
}

main() {
  pre_checks
  create_cluster
}

main $*