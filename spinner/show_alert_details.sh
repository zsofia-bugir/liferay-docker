#!/bin/bash

function check_usage {
	check_utils docker

	ALERT_ID=

	while [ "${1}" != "" ]
	do
		case ${1} in
			-a)
				shift

				ALERT_ID=${1}

				;;
			-h)
				print_help

				;;
			*)
				print_help

				;;
		esac

		shift
	done

	if [ ! -n "${ALERT_ID}" ]
	then
		echo "Please provide an alert ID"
	else
        find_container
    fi
}

function print_help {
	echo "Usage: ./show_alert_details -a [ALERT_UNIQUE_ID]"
}

function check_utils {
	for util in "${@}"
	do
		if (! command -v "${util}" &>/dev/null)
		then
			echo "The utility ${util} is not installed."

			exit 1
		fi
	done
}

function find_container {

    container_id=$(docker ps --format "{{.ID}} {{.Names}}" | grep "webserver" | awk '{print $1}')

    echo $container_id

    if [ ! -n "${container_id}" ]
	then
		echo "No running docker container found, please start spin up an environment"
        exit 1
	fi
    file_path="/var/log/modsec_audit.log"
    local_file=$(docker cp "${container_id}":$file_path .)

    show_file

}

function show_file {
    
    local_path="modsec_audit.log"

    if [ ! -n "${local_path}" ]
	then
		echo "Found no file!"
        exit 1
	fi

    details=$(cat "${local_path}" | grep "${ALERT_ID}" | jq .)

    echo "Alert details"
    echo "${details}"

}

function clean_up {
    rm "modsec_audit.log"
}

function main {
	check_usage "${@}"

    if [ -f "${local_path}" ]
	then
		clean_up
	fi
}

main "${@}"