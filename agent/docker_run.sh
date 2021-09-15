#!/bin/bash

#############################################
# Copyright (c) Gaia Platform LLC
# All rights reserved.
#############################################

# Simple function to start the process off.
start_process() {
    if [ "$VERBOSE_MODE" -ne 0 ]; then
        echo "Executing agent docker image..."
    fi

    if ! pushd . >"$TEMP_FILE" 2>&1;  then
        cat "$TEMP_FILE"
        complete_process 1 "Script cannot save the current directory before proceeding."
    fi
    DID_PUSHD=1

    if ! cd "$SCRIPTPATH" >"$TEMP_FILE" 2>&1; then
        cat "$TEMP_FILE"
        complete_process 1 "Script cannot change to script directory before proceeding."
    fi
}

# Simple function to stop the process, including any cleanup
complete_process() {
    local SCRIPT_RETURN_CODE=$1
    local COMPLETE_REASON=$2

    if [ "$SCRIPT_RETURN_CODE" -ne 0 ] && [ -f "$TEMP_FILE" ] ; then
        cat "$TEMP_FILE"
    fi

    if [ -n "$COMPLETE_REASON" ] ; then
        echo "$COMPLETE_REASON"
    fi

    if [ "$DID_PUSHD" -eq 1 ]; then
        popd > /dev/null 2>&1 || exit
    fi

    if [ "$SCRIPT_RETURN_CODE" -ne 0 ]; then
        echo "Executing agent docker image failed."
    else
        if [ "$VERBOSE_MODE" -ne 0 ]; then
            echo "Executing agent docker image succeeded."
        fi
    fi

    if [ -f "$TEMP_FILE" ]; then
        rm "$TEMP_FILE"
    fi

    exit "$SCRIPT_RETURN_CODE"
}

# Show how this script can be used.
show_usage() {
    local SCRIPT_NAME=$0

    echo "Usage: $(basename "$SCRIPT_NAME") [flags]"
    echo "Flags:"
    echo "  -n,--name                   Name of the agent to start with."
    echo "  -a,--auto-build             Auto-build the image before running it."
    echo "  -v,--verbose                Show lots of information while executing the project."
    echo "  -h,--help                   Display this help text."
    echo ""
    exit 1
}

# Parse the command line.
parse_command_line() {
    VERBOSE_MODE=0
    AUTO_BUILD=0
    AGENT_ID=
    PARAMS=()
    while (( "$#" )); do
    case "$1" in
        -a|--auto-build)
            AUTO_BUILD=1
            shift
        ;;
        -n|--name)
            # shellcheck disable=SC2086
            if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
                AGENT_ID=$2
                shift 2
            else
                echo "Error: Argument for $1 is missing." >&2; exit 1
            fi
        ;;
        -v|--verbose)
            VERBOSE_MODE=1
            shift
        ;;
        -h|--help)
            show_usage
        ;;
        -*) # unsupported flags
            echo "Error: Unsupported flag $1" >&2
            show_usage
        ;;
        *) # preserve positional arguments
            PARAMS+=("$1")
            shift
        ;;
    esac
    done
}


# Set up any global script variables.
# shellcheck disable=SC2164
SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

# Set up any project based local script variables.
TEMP_FILE=/tmp/agent-run.tmp
DID_PUSHD=0

IMAGE_NAME=agent

# Parse any command line values.
parse_command_line "$@"

if [[ -z $AGENT_ID ]] ; then
    complete_process 1 "Agent name must be specified with the --name flag."
fi

if [[ ! -f "gaia.deb" ]] ; then
    complete_process 1 "Gaia install debian file 'gaia.deb' must be in the current directory."
fi

# Clean entrance into the script.
start_process

if [[ $AUTO_BUILD -ne 0 ]] ; then
    if [[ $VERBOSE_MODE -ne 0 ]] ; then
        echo "Auto-building '$IMAGE_NAME' image."
    fi
    if ! ./docker_build.sh > "$TEMP_FILE" 2>&1 ; then
        complete_process 1 "Docker build of '$IMAGE_NAME' image failed."
    fi
fi

docker run --rm -e AGENT_ID=$AGENT_ID $IMAGE_NAME

# If we get here, we have a clean exit from the script.
complete_process 0

