#!/usr/bin/env bash
set -e

GITHUB_API_URL="${API_URL:-https://api.github.com}"
GITHUB_SERVER_URL="${SERVER_URL:-https://github.com}"

validateArgs() {
  # Setup branch
  ref="main"

  # Necessary I/P Checks
  if [ -z "${INPUT_ORG}" ]
  then
    echo "Error: ORG is a required argument."
    exit 1
  fi

  if [ -z "${INPUT_REPOSITORY}" ]
  then
    echo "Error: Repository is a required argument."
    exit 1
  fi

  if [ -z "${INPUT_REPO_TOKEN}" ]
  then
    echo "Error: Repository token is required."
    exit 1
  fi

  if [ -z "${INPUT_WORKFLOW_FILE_NAME}" ]
  then
    echo "Error: Workflow File Name is required"
    exit 1
  fi

  if [ -z "${INPUT_CLIENT_PAYLOAD}" ]
  then
    echo "Error: Brandname is required"
    exit 1
  else 
    clientPayload=$(echo "${INPUT_CLIENT_PAYLOAD}" | jq -c)  
  fi
}

api() {
  path=$1; shift
  if response=$(curl --fail-with-body -sSL \
      "${GITHUB_API_URL}/repos/${INPUT_ORG}/${INPUT_REPOSITORY}/actions/$path" \
      -H "Authorization: Bearer ${INPUT_REPO_TOKEN}" \
      -H 'Accept: application/vnd.github.v3+json' \
      -H 'Content-Type: application/json' \
      "$@")
  then
    echo "$response"
  else
    echo >&2 "api failed:"
    echo >&2 "path: $path"
    echo >&2 "response: $response"
    if [[ "$response" == *'"Server Error"'* ]]; then 
      echo "Server error - trying again"
    else
      exit 1
    fi
  fi
}

getWorkflowData() {
  since=${1:?}
  query="event=workflow_dispatch&created=>=$since${INPUT_GITHUB_USER+&actor=}${INPUT_GITHUB_USER}&per_page=100"
  api "workflows/${INPUT_WORKFLOW_FILE_NAME}/runs?${query}" |
  jq -r '[.workflow_runs[].id][0]'
}


triggerWorkflowHandler() {
  echo >&2 "Triggering Workflow For Syncing Platform"

  sleep 5
  
  # Trigger the workflow
  api "workflows/${INPUT_WORKFLOW_FILE_NAME}/dispatches" \
    --data "{\"ref\":\"${ref}\",\"inputs\":${clientPayload}}"

  sleep 10
  
  START_TIME=$(date +%s)
  SINCE=$(date -u -Iseconds -d "@$((START_TIME - 15))")  

  NEW_RUNS=$(getWorkflowData "$SINCE")

  # Return new run ids
  echo "$NEW_RUNS"
}

workflowStallHandler() {
  echo($1)
  last_workflow_id=$1

  echo "id: ${last_workflow_id}"
  
  echo "Syncing the Platform Changes..."

  conclusion=null
  status=

  while [[ "${conclusion}" == "null" && "${status}" != "completed" ]]
  do 
    workflow=$(api "runs/$last_workflow_id")
    conclusion=$(echo "${workflow}" | jq -r '.conclusion')
    status=$(echo "${workflow}" | jq -r '.status')
  done

  if [[ "${conclusion}" == "success" && "${status}" == "completed" ]]
  then
    echo "Platform Synced Successfully..."
    echo "Fetching The PR Link..."

    if response=$(curl -sSL \
    -H "Accept: application/vnd.github+json" \
    -H "Authorization: Bearer ${INPUT_REPO_TOKEN}"\
    -H "X-GitHub-Api-Version: 2022-11-28" \
    ${GITHUB_API_URL}/repos/${INPUT_ORG}/${INPUT_REPOSITORY}/pulls?state=open | jq -r '[.[].html_url][0]')
    then
  
    if [[ ! -z "$response" ]] && [[ $response != "null" ]]
      then
        echo $response
      else
        echo "NO PR Found"  
    fi 
    else
    echo "PR Link Not Fetched Due To Some Error"
    fi
  else
    echo "Platform syncing failed due to some error"
      exit 1
  fi
}

entrypoint() {
  validateArgs

    jobId=$(triggerWorkflowHandler)
    echo "$jobId"
    workflowStallHandler "$jobId"
}

entrypoint
