#!/usr/bin/env bash

# colors
source scripts/helpers.sh

# a2s shennanigans
# https://steamcommunity.com/discussions/forum/14/2974028351344359625/
export STEAM_GAMESERVER_RATE_LIMIT_200MS=10
export STEAM_GAMESERVER_PACKET_HANDLER_NO_IPC=1
# Not yet.
#export STEAM_GAMESERVER_A2S_INFO_REQUIRE_CHALLENGE=1

# update server if it needs it
./steamcmd/steamcmd.sh +login anonymous +force_install_dir ${PWD} +app_update 232250 +exit

# generate our server config
python3 ./gencfg.py

# wait a second
sleep 1

# here's the args from our python script, for picking the map
export py_args="$(cat ./py_args)"

# spew em
important "PY ARGS = ${py_args}"

# delete that temp file
rm ./py_args

# print out our full cmd
echo "./srcds_run $* ${py_args}"

# we're good!
ok "Starting server..."

startPing "Server starting!"

./srcds_run $* ${py_args}

