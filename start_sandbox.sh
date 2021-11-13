#!/bin/bash

# Show how this script can be used.
show_usage() {
    local SCRIPT_NAME=$0

    echo "Usage: $(basename "$SCRIPT_NAME") [flags]"
    echo "Flags:"
    echo "  -d,--debug                  Debug mode."
    echo "  -c,--coord name             Provide coordinator name."
    echo "  -h,--help                   Display this help text."
    echo ""
    exit 1
}

# Parse the command line.
parse_command_line() {
    DEBUG=false
    COORD=none

    while (( "$#" )); do
    case "$1" in
        -d|--debug)
            DEBUG=1
            shift
        ;;
        -c|--coord)
            shift
            COORD=$1
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

# Parse any command line values.
parse_command_line "$@"

if [ $DEBUG = true ]; then
    echo "Running in debug mode"
    godot --no-window --path ./SandboxVisual --export-debug "HTML5"
else
    godot --no-window --path ./SandboxVisual --export "HTML5"
fi
sed -i "16s/.*/\t\t\tbackground-color: #f4f6f8;/" static/visual/index.html # Change loading screen to white
sed -i "58s/.*/\t\t\tbackground-color: gray;/" static/visual/index.html # Change loading progress bar to gray
sed -i "195s/.*/\t\t\t\t\tstatusIndeterminate.children[i].style.borderTopColor = 'gray';/" static/visual/index.html # Change loading wheel to gray

python3 application.py "$COORD"
