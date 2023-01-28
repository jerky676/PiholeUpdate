#!/usr/bin/env bash

set -e

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
SERVERS="${SCRIPT_DIR}/servers.json"
DNS_ENTRIES="${SCRIPT_DIR}/dns.json"

CUSTOM_DNS_LIST="${SCRIPT_DIR}/dns.json"

RED='\033[0;31m'
ORANGE='\033[0;33'
NC='\033[0m' # No Color
GREEN='\033[0;32m'
LIGHT_BLUE='\033[1;34m'
LIGHT_GREEN='\033[1;32m'

source ${SCRIPT_DIR}/pihole-functions.sh