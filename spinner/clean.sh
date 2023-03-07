#!/bin/bash

function lcd {
	cd "${1}" || exit 3
}

docker_compose="docker compose"

if (command -v docker-compose &>/dev/null)
then
	docker_compose="docker-compose"
fi

base_dir=$(pwd)

if [[ $(find . -name "env-*" -type d | wc -l) -eq 0 ]]
then
	echo "There were no environments to clean."

	exit 2
fi

for environment in "$(pwd)"/env*
do
	echo "Cleaning up ${environment}."

	lcd "${environment}"
	${docker_compose} down --rmi local -v

	rm -fr "${environment}"
done