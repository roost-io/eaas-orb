#!/bin/bash
ROOST_AUTH_TOKEN=$(eval "echo \"\$$ORB_ENV_AUTH_TOKEN\"")
ENT_SERVER=$(eval "echo \"\$$ORB_ENV_ENT_SERVER\"")

pre_checks() {
  if [ -z "$ROOST_AUTH_TOKEN" ]; then
    echo "ROOST_AUTH_TOKEN not found. Please add ROOST_AUTH_TOKEN as an environment variable in CicleCI before continuing."
    exit 1
  fi
}

trigger_eaas() {
  TRIGGER_IDS=$(curl --location --silent --request POST "https://$ENT_SERVER/api/application/triggerEaasFromCircleCI" \
  --header "Content-Type: application/json" \
  --data-raw "{
    \"app_user_id\": \"$ROOST_AUTH_TOKEN\",
    \"application_name\": \"$APPLICATION_NAME\",
    \"git_type\": \"$PIPELINE_PROJECT_TYPE\",
    \"repo_id\": \"\",
    \"full_repo_name\": \"$CIRCLE_PROJECT_USERNAME/$CIRCLE_PROJECT_REPONAME\",
    \"branch\": \"$CIRCLE_BRANCH\",
    \"circle_workflow_id\": \"$CIRCLE_WORKFLOW_ID\",
    \"user_name\": \"$CIRCLE_PROJECT_USERNAME\"
  }" | jq -r '.trigger_ids[0]')

  if [ "$TRIGGER_IDS" != "null" ]; then
    echo "Triggered Eaas Successfully."
    get_eaas_status "$TRIGGER_IDS"
  else
    echo "Failed to trigger Eaas. Please try again."
    exit 1
  fi
}

get_eaas_status() {

  TRIGGER_ID=$1
  STATUS=$(curl --location --silent --request POST "https://$ENT_SERVER/api/application/client/git/eaas/getStatus" \
  --header "Content-Type: application/json" \
  --data-raw "{
    \"app_user_id\" : \"${ROOST_AUTH_TOKEN}\",
    \"trigger_id\" : \"$TRIGGER_ID\"
  }" | jq -r '.current_status')

  case "$STATUS" in
    setup_in_progress)
      echo "Application setup is in progress."
      sleep 30
      get_eaas_status $TRIGGER_ID
      ;;
    cluster_creation_in_progress)
      echo "Cluster creation in proggress."
      sleep 30
      get_eaas_status $TRIGGER_ID
      ;;
    build_in_progress)
      echo "Application build is in progress."
      sleep 30
      get_eaas_status $TRIGGER_ID
      ;;
    deploy_completed)
      echo "Application deployed successfully."
      ;;
    deploy_failed)
      echo "Failed to deploy application. Please try again."
      exit 1
      ;;
    *)
      echo "Application setup is in progress."
      sleep 30
      get_eaas_status $TRIGGER_ID
      ;;
  esac

}


main() {
  pre_checks
  trigger_eaas
}

main $*