#!/bin/bash

#############################################
# Copyright (c) Gaia Platform LLC
# All rights reserved.
#############################################

# Simple function to start the process off.
start_process() {
    if [ "$VERBOSE_MODE" -ne 0 ]; then
        echo "Building agent docker image..."
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
        echo "Building agent docker image failed."
    else
        if [ "$VERBOSE_MODE" -ne 0 ]; then
            echo "Building agent docker image succeeded."
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
    echo "  -f,--force                  Force a build of the docker container."
    echo "  -v,--verbose                Show lots of information while executing the project."
    echo "  -h,--help                   Display this help text."
    echo ""
    exit 1
}

# Parse the command line.
parse_command_line() {
    FORCE_BUILD=0
    VERBOSE_MODE=0
    PARAMS=()
    while (( "$#" )); do
    case "$1" in
        -f|--force)
            FORCE_BUILD=1
            shift
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
TEMP_FILE=/tmp/agent-build.tmp
DID_PUSHD=0

IMAGE_NAME=agent

# Parse any command line values.
parse_command_line "$@"

# Clean entrance into the script.
start_process

if [[ $FORCE_BUILD -ne 0 ]] ; then

    DID_FOUND=0
    docker images | grep -o '^[^ ]\+' > $TEMP_FILE
    IFS=$'\r\n' GLOBIGNORE='*' command eval  'TEST_NAMES=($(cat $TEMP_FILE))'
    for NEXT_TEST_NAME in "${TEST_NAMES[@]}"; do
        if [[ $IMAGE_NAME == "$NEXT_TEST_NAME" ]] ; then
            DID_FOUND=1
        fi
    done

    if [[ $DID_FOUND -ne 0 ]]; then
        if [[ $VERBOSE_MODE -ne 0 ]] ; then
            echo "Removing previously built '$IMAGE_NAME' image."
        fi
        if ! docker rmi $IMAGE_NAME > "$TEMP_FILE" 2>&1 ; then
            complete_process 1 "Previously build '$IMAGE_NAME' image could not be removed."
        fi
    fi
fi

rm -rf $SCRIPTPATH/build
rm -rf $SCRIPTPATH/repo
mkdir $SCRIPTPATH/repo
git clone https://github.com/gaia-platform/amr_swarm_template $SCRIPTPATH/repo
#pushd $SCRIPTPATH/repo
#./build.sh -v -f
#popd
#rm -rf $SCRIPTPATH/repo/build
git clone --recurse-submodules https://github.com/aws/aws-iot-device-sdk-cpp-v2.git $SCRIPTPATH/repo/aws-iot-device-sdk-cpp-v2

#complete_process 1

if [[ $VERBOSE_MODE -ne 0 ]] ; then
    echo "Building '$IMAGE_NAME' image."
fi
if ! docker build --force-rm --tag $IMAGE_NAME . ; then # > "$TEMP_FILE" 2>&1 ; then
    complete_process 1 "Build of image '$IMAGE_NAME' was not completed."
fi

# If we get here, we have a clean exit from the script.
complete_process 0

