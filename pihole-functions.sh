#!/usr/bin/env bash

# SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
# SERVER_LIST_FILE="${SCRIPT_DIR}/server.json"


API_ADMIN_SUFFIX="/admin/api.php?"
API_ACTION_SUFFIX="&action="
AUTH_SUFFIX="&auth="

CNAME_ACTION="customcname"
DNS_ACTION="customdns"


function update_servers(){
    jq -c '.servers[]' ${SERVERS} | while read i; do
        url=$(echo "${i}" | jq -r '.url')
        api=$(echo "${i}" | jq -r '.api')

        update_server ${url} ${api}
    done
}

function update_server(){
    url="${1}"
    api="${2}"

    update_type ${url} ${api} "dns"
    update_type ${url} ${api} "cname"
}

function update_type(){
    url="${1}"
    api="${2}"
    type="${3}"

    remote_dns_list=$(get_type ${url} ${api} ${type})
    remote_dns_names=$(echo "${remote_dns_list}" | jq -r '[ .[] | .name ]')

    if [ "${type}" == "dns" ]
    then
        list_type="customDns"
    elif [ "${type}" == "cname" ]
    then
        list_type="customCname"
    else 
        echo "bad type"
        exit 1
    fi

    local_dns_names=$(jq -r "[ .${list_type}[] | .name ]" ${CUSTOM_DNS_LIST})

    echo "Checking for deletes on server ${url}"

    delete_list=$(echo -n "{\"remote\":${remote_dns_names}, \"local\":${local_dns_names}}" | jq '.remote-.local')

    echo "${delete_list}" | jq -cr '.[]'  | while read delete; do
        address=$(echo "${remote_dns_list}" | jq -r ".[] | select(.name == \"${delete}\") | .address" )
        echo -e "${RED}Entry ${type} ${LIGHT_BLUE}${delete}:${address}${RED} exist in remote server and needs to be deleted on server ${url}${NC}"
        delete_type ${url} ${api} ${delete} ${address} ${type}
    done

    echo "Checking for updates to records on server ${url}"

    # upsert
    jq -c ".${list_type}[]" ${CUSTOM_DNS_LIST} | while read dns; do
        name=$(echo "${dns}" | jq -r '.name')
        address=$(echo "${dns}" | jq -r '.address')
        
        entry=$(echo "${remote_dns_list}" | jq ".[] | select(.name == \"${name}\")")       
        
        if [ -z "${entry}" ]
        then
            echo -e "${LIGHT_GREEN}Adding ${type} entry ${LIGHT_BLUE}${name}:${address}${LIGHT_GREEN} to server ${url}${NC}"
            add_type ${url} ${api} ${name} ${address} ${type}
        else
            old_address=$(echo "${entry}" | jq -r '.address')
            if [ "${address}" != "${old_address}" ]
            then
                echo -e "${ORANGE}Entry ${type} ${LIGHT_BLUE}${name}:${address}${ORANGE} does not match need to be updated on server ${url}${NC}"
                delete_type ${url} ${api} ${name} ${old_address} ${type}
                sleep 1
                add_type ${url} ${api} ${name} ${address} ${type}
            else
                echo -e "${GREEN}Entry ${type} ${LIGHT_BLUE}${name}:${address}${GREEN} is up to date on server ${url}${NC}"
            fi
        fi
    done

}

function add_type(){
    url="${1}"
    api="${2}"
    name="${3}"
    address="${4}"
    type="${5}"

    if [ "${type}" == "dns" ]
    then
        cmd="${DNS_ACTION}"
        payload="&domain=${name}&ip=${address}"
    elif [ "${type}" == "cname" ]
    then
        cmd="${CNAME_ACTION}"
        payload="&domain=${name}&target=${address}"
    else 
        echo "bad type"
        exit 1
    fi

    auth="${AUTH_SUFFIX}${api}"
    action="${API_ACTION_SUFFIX}add"

    # echo "curl -s \"${url}/${API_ADMIN_SUFFIX}${cmd}${auth}${action}${payload}\"" 
    echo $(curl -s -k "${url}/${API_ADMIN_SUFFIX}${cmd}${auth}${action}${payload}")
}

function delete_type(){
    url="${1}"
    api="${2}"
    name="${3}"
    address="${4}"
    type="${5}"

    if [ "${type}" == "dns" ]
    then
        cmd="${DNS_ACTION}"
        payload="&domain=${name}&ip=${address}"
    elif [ "${type}" == "cname" ]
    then
        cmd="${CNAME_ACTION}"
        payload="&domain=${name}&target=${address}"
    else 
        echo "bad type"
        exit 1
    fi

    auth="${AUTH_SUFFIX}${api}"
    action="${API_ACTION_SUFFIX}delete"

    # echo "curl \"${url}/${API_ADMIN_SUFFIX}${cmd}${auth}${action}${payload}\""
    echo $(curl -s -k "${url}/${API_ADMIN_SUFFIX}${cmd}${auth}${action}${payload}")
}

function get_type(){
    url="${1}"
    api="${2}"
    type="${3}"

    if [ "${type}" == "dns" ]; then
        cmd="${DNS_ACTION}"
    elif [ "${type}" == "cname" ]; then
        cmd="${CNAME_ACTION}"
    else 
        echo "bad type"
        exit 1
    fi

    auth="${AUTH_SUFFIX}${api}"
    action="${API_ACTION_SUFFIX}get"
    data=$(curl -s -k "${url}/${API_ADMIN_SUFFIX}${cmd}${auth}${action}")
   
    echo $(echo "${data}" | jq '[ .data[] | { "name": .[0], "address":.[1] } ]')
}
