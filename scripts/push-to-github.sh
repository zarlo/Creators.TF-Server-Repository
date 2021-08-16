#!/bin/bash
source scripts/helpers.sh

# written by sappho.io

# use tmpfs
tmp="/dev/shm"

bootstrap ()
{
    git clone git@gitlab.com:creators_tf/gameservers/servers.git -b master --single-branch ${tmp}/gameservers --bare --depth 50

    cd ${tmp}/gameservers || exit 255

    ok "-> fetching master"
    git fetch origin master:master -f
}

# used to use BFG for this
# but I didn't like the java dep and also
# git filter-repo is faster and updated more often
# -sapph
# https://github.com/newren/git-filter-repo

stripchunkyblobs ()
{
    ok "-> stripping big blobs"
    git filter-repo --strip-blobs-bigger-than 100M --force
}

stripfiles ()
{
    ok "-> stripping sensitive files"
    # clobber any existing file
    true > paths.txt

    # echo our regex && literal paths to it
    {
        echo 'regex:private.*';
        echo 'regex:databases.*';
        echo 'regex:economy.*';
        echo 'discord.cfg';
        echo 'discord_seed.sp';
    } >> paths.txt

    git filter-repo --invert-paths --paths-from-file paths.txt --force --use-base-name
}


stripsecrets ()
{
    # strip sensitive strings
    #
    ok "-> stripping sensitive strings"
    # clobber any existing file
    true > regex.txt

    # echo our regex to it
    {
// ***REPLACED SRC PASSWORD***
        echo 'regex:(?m)(***REPLACED C.TF API INFO***>***REPLACED C.TF API INFO***';
        echo 'regex:(?m)(\bhttp.*(@|/api/webhook).*\b)==>***REPLACED PRIVATE URL***';
    } >> regex.txt

    git filter-repo --replace-text regex.txt --force
}

push ()
{
    if ! git remote | grep origin-gh > /dev/null; then
        ok "-> adding gh remote"
        git remote add origin-gh git@github.com:CreatorsTF/gameservers.git
    fi

    # donezo
    ok "-> pushing to gh"
    git push origin-gh --progress --verbose --verbose --verbose
}

bootstrap
stripchunkyblobs
stripfiles
stripsecrets
push
