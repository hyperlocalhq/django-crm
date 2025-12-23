#!/usr/bin/env bash

# Initialize variables
COMMAND=""
ARGS=""
PROJECT=""
ENVIRONMENT=""
ROTATION_DAYS=60  # Default to 60 days if not provided

# Function to print usage
print_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  -c, --command=COMMAND       Specify the Django command to run"
    echo "  -a, --args=ARGS             Specify additional arguments for the Django command"
    echo "  -p, --project=PROJECT       Specify the project name"
    echo "  -e, --environment=ENV       Specify the environment"
    echo "  -d, --rotation-days=DAYS    Specify the log rotation days (default: 60)"
    echo "  -h, --help                  Print this help message"
    echo ""
    echo "Example:"
    echo "  $0 -c=my_command -a=\"--noinput\" -p=museumsportal -e=production -d=7"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -c=*|--command=*)
            COMMAND="${1#*=}"
            ;;
        -a=*|--args=*)
            ARGS="${1#*=}"
            ;;
        -p=*|--project=*)
            PROJECT="${1#*=}"
            ;;
        -e=*|--environment=*)
            ENVIRONMENT="${1#*=}"
            ;;
        -d=*|--rotation-days=*)
            ROTATION_DAYS="${1#*=}"
            ;;
        -h|--help)
            print_usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            print_usage
            exit 1
            ;;
    esac
    shift
done

# Validate required arguments
if [[ -z "${PROJECT}" || -z "${ENVIRONMENT}" ]]; then
    echo "Error: Missing required arguments" >&2
    print_usage
    exit 1
fi

# Validate ROTATION_DAYS
if ! [[ "${ROTATION_DAYS}" =~ ^[0-9]+$ ]] || [ "${ROTATION_DAYS}" -lt 1 ]; then
    echo "Error: rotation days must be a positive integer" >&2
    exit 1
fi

PROJECT_PATH="/var/webapps/${PROJECT}"
DATE_FORMAT=$(date +'%Y%m%d%H%M%S')
