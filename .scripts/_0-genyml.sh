#!/usr/bin/env bash

# by sappho.io

# job names
jobnames=(
    pull
    build
)

# scripts to execute for each job - adjust flags here
jobs=(
    "./.scripts/ci.sh pull -v"
    "./.scripts/ci.sh build"
)

# all servers tags
allservers=(
    virginiapub
    chicago3
    lapub
    eupub
    eu2pub
    auspub
    sgppub
    uspotato1
    eupotato1
    eupotato2
)

# staging servers tags
stagingservers=(
    eupub
    virginiapub
)

# use staging by default
tagstouse=("${stagingservers[@]}")
# don't use master and make sure these vars are actually defined
if [[ "${CI_COMMIT_BRANCH}" == "${CI_DEFAULT_BRANCH}" ]] && [ -n "${CI_COMMIT_BRANCH}" ] && [ -n "${CI_DEFAULT_BRANCH}" ]; then
    tagstouse=("${allservers[@]}")
fi

# stages
echo "---"
echo "stages:"

# job names
for jobname in "${jobnames[@]}"
do
    echo "  - ${jobname}"
done

echo ""

i=0
# for loop for our job names list
for jobname in "${jobnames[@]}"
do
    # for loop for all the servers
    for tag in "${tagstouse[@]}"
    do
        # Job definition
        # I rather use a Here Document, but I can't be arsed with the whitepaces in YAML
        echo "${jobname}_${tag}:"
        echo "  stage: ${jobname}"
        echo "  script: ${jobs[i]}"

        # Needs
        # only do the needs stuff if we're not on the first stage
        if (( i > 0 )); then
        # get the previous str of the jobnames array
        echo "  needs:"
        echo "    - job: ${jobnames[i-1]}_${tag}"
        fi
        # Tags
        echo "  tags:"
        echo "    - ${tag}"
    done
    echo ""
    ((i=i+1))
done
