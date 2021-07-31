#!/usr/bin/env bash
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# by sappho.io

# webhook url
WEBHOOK_URL="***REPLACED PRIVATE URL***"

# webhook url
WEBHOOK_URL_STARTUP_PING="***REPLACED PRIVATE URL***"

# todo: use ci vars
PROJ_URL="https://gitlab.com/creators_tf/gameservers/servers"

# first arg is msg sent
# second is ${PWD}
#
hook()
{
    bash ${SCRIPT_DIR}/discord.sh \
    --webhook-url="$WEBHOOK_URL" \
    --username "Gitlab Server Repo CI/CD Messages" \
    --title "${1}" \
    --field "commit; [${CI_COMMIT_SHORT_SHA}](${PROJ_URL}/-/commit/${CI_COMMIT_SHORT_SHA}); false" \
    --field "job url; [${CI_JOB_URL}](${CI_JOB_URL}); false" \
    --field "branch; [${CI_COMMIT_REF_NAME}](${PROJ_URL}/-/tree/${CI_COMMIT_REF_NAME}); false" \
    --field "pwd; ${PWD}; false" \
    --field "hostname; $(hostname); false" \
    --timestamp
}

startPing()
{
    if [ -z "${SERVER_ID}" ]; then SERVER_ID="N/A"; fi
    bash ${SCRIPT_DIR}/discord.sh \
    --webhook-url="$WEBHOOK_URL_STARTUP_PING" \
    --username "TF2 Server Startup Ping" \
    --title "${1}" \
    --field "serverid; ${SERVER_ID}; false" \
    --field "pwd; ${PWD}; false" \
    --field "hostname; $(hostname); false" \
    --timestamp
}
