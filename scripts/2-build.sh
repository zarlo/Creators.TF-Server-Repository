#!/usr/bin/env bash

# by invaderctf

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
# Helper functions
source ${SCRIPT_DIR}/helpers.sh

# Variable initialisation
WORKING_DIR="tf/addons/sourcemod"
SPCOMP_PATH="scripting/spcomp64"
SCRIPTS_DIR="scripting"
COMPILED_DIR="plugins"
# Exclusion lists, use /dir/ for directories and /file_ for file_*.sp
EXCLUDE_COMPILE="/stac/ /include/ /disabled/ /external/ /economy/ /discord/"
EXCLUDE_COMPILE="grep -v -e ${EXCLUDE_COMPILE// / -e }"
EXCLUDE_CLEANUP="/external/ /disabled/"
EXCLUDE_CLEANUP="grep -v -e ${EXCLUDE_CLEANUP// / -e }"

# Temporary files
UNCOMPILED_LIST=$(mktemp)
UPDATED_LIST=$(mktemp)

# TODO: I am pretty sure this needs to be single quoted with double quotes around the vars
trap "rm -f ${UNCOMPILED_LIST} ${UPDATED_LIST}; popd >/dev/null" EXIT

usage()
{
    echo "This script looks for all uncompiled .sp files"
    echo "and if a reference is given, those that were updated"
    echo "Then it compiles everything"
    echo "Usage: ./2-build.sh <reference>"
    exit 1
}

# Just checking the git refernece is valid
reference_validation()
{
    GIT_REF="${1}"
    if git rev-parse --verify --quiet "${GIT_REF}" > /dev/null; then
        debug "Comparing against ${GIT_REF}"
    else
        error "Reference ${GIT_REF} does not exist"
        exit 2
    fi
}

# Find all changed *.sp files inside ${WORKING_DIR}
# Write the full list to a file
# Remove all the *.smx counterparts that exist
list_updated()
{
    UPDATED=$(git diff --name-only "${GIT_REF}" HEAD . | grep "\.sp$" | ${EXCLUDE_COMPILE})
    # skip compile if there's nothing *to* compile
    if [[ -z $UPDATED ]]; then
        ok "No updated files in diff"
        return 1
    fi
    debug "Generating list of updated plugins"
    while IFS= read -r line; do
        # git diff reports the full path, we need it relative to ${WORKING_DIR}
        echo "${line/${WORKING_DIR}\//}" >> "${UPDATED_LIST}"
        rm -f "${COMPILED_DIR}/$(basename "${line/.sp/.smx}")"
    done <<< "${UPDATED}"
    return 0
}

# Find all *.sp files inside ${WORKING_DIR}
# Select those that do not have a *.smx counterpart
# And write resulting list to a file
list_uncompiled()
{
    # this may need to be quoted
    UNCOMPILED=$(find "${SCRIPTS_DIR}" -iname "*.sp" | ${EXCLUDE_COMPILE})
    debug "Generating list of uncompiled plugins"
    # while loop, read from our uncompiled list we just got
    while IFS= read -r line; do
        # if file doesnt exist at compiled dir
        if [[ ! -f "${COMPILED_DIR}/$(basename "${line/.sp/.smx}")" ]]; then
            # then tack it on to the end of the temp file we made
            echo "${line}" >> "${UNCOMPILED_LIST}"
        fi;
    done <<< "${UNCOMPILED}"

    # skip compile if there's nothing *to* compile
    if [[  $(wc -l < "$UNCOMPILED_LIST") == 0 ]]; then
        ok "No uncompiled .sp files"
        return 1
    fi

    return 0
}

# Iterate over a list files and compile all the *.sp files
# Output will be ${COMPILED_DIR}/plugin_name.smx
# If an error is found the function dies and report the failing file

# Iterate over a list files and compile all the *.sp files
# Output will be ${COMPILED_DIR}/plugin_name.smx
# If an error is found the function prints the warnings to stdout and kills the
# job after it compiled every plugin
compile()
{
    failed=0
    info "Compiling $(wc -l < "${1}") files"
    while read -r plugin; do
        info "Compiling ${plugin}"
        # compiler path  plugin name    output dir       output file replacing sp with smx
        ./${SPCOMP_PATH} "${plugin}" -o "${COMPILED_DIR}/$(basename "${plugin/.sp/.smx}")" \
            -v=2 -z=9 -O=2 -\;=+ -E
        # verbose, max compressed, max optimized, require semicolons, treat errors as warnings

        # if something has gone wrong then stop everything and yell about it
        if [[ $? -ne 0 ]]; then
            error "spcomp error while compiling ${plugin}"
            failed=1
        fi
    done < "${1}"
    if [[ failed -ne 0 ]]; then
        exit 1
    fi
    return 0
}

# Auxiliary function to catch errors on spcomp64
compile_error()
{
    error "spcomp64 error while compiling ${1}"
    exit 255
}

# Find all *.smx files inside ${COMPILED_DIR}
# Select those that do not have a *.sp counterpart
# And remove them
cleanup_plugins()
{
    debug "Generating list of compiled plugins"
    COMPILED=$(find "${COMPILED_DIR}" -iname "*.smx" | ${EXCLUDE_CLEANUP})
    # while loop, read from our compiled list we just got
    while IFS= read -r line; do
        debug "Looking for $(basename "${line/.smx/.sp}")"
        # Look for a *.sp counterpart
        SP_FILE=$(find "${SCRIPTS_DIR}" -iname "$(basename "${line/.smx/.sp}")")
        SP_FILE_COUNT=$(wc -l <<< ${SP_FILE})
        if [[ -z ${SP_FILE} ]]; then
            # If no *.sp countrerpart is found, then delete the *.smx file
            important "Deleting orphan ${line} file"
            rm -fv ${line}
        elif [ ${SP_FILE_COUNT} -eq 1 ]; then
            # If only one *.sp counterpart was found then all is good
            debug "${line} -> ${SP_FILE}"
            # If the ${SP_FILE} lives on the exclusion list, then delete the compiled plugin
            if [[ ${SP_FILE} == */disabled/* ]] || [[ ${SP_FILE} == */external/* ]]; then
                important "Plugin is disabled or external, deleting the compiled file"
                rm -fv ${line}
            fi
        else
            # If more than one *.sp counterpart was found, then print a warning (for cleanup)
            warn "${line} -> ${SP_FILE//$'\n'/ - }"
        fi

    done <<< "${COMPILED}"

    return 0
}

###
# Script begins here ↓
pushd ${WORKING_DIR} >/dev/null || exit
[[ ! -x ${SPCOMP_PATH} ]] && chmod u+x ${SPCOMP_PATH}

# Compile all scripts that have been updated
if [[ -n ${1} ]]; then
    reference_validation "${1}"
    debug "Looking for all .sp files that have been updated"
    list_updated
    # only compile if we found something to compile
    if [[ $? -eq 0 ]]; then
        debug "Compiling updated plugins"
        compile "${UPDATED_LIST}"
    fi
fi

# Compile all scripts that have not been compiled
debug "Looking for all .sp files in ${WORKING_DIR}/${SCRIPTS_DIR}"
list_uncompiled
# only compile if we found something to compile
if [[ $? -eq 0 ]]; then
    debug "Compiling uncompiled plugins"
    compile "${UNCOMPILED_LIST}"
fi

ok "All plugins compiled successfully !"

cleanup_plugins
ok "Obsolete plugins deleted !"

exit 0
