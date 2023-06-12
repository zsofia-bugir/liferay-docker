#!/bin/bash

source ../_liferay_common.sh

function build_service_antivirus {
	write "    antivirus:"

	write_deploy_section 1G

	write "        image: clamav/clamav:1.0.1-1"
	write "        ports:"
	write "            - \"3310:3310\""
}

function build_service_database {
	write "    database:"
	write "        command: mysqld --character-set-filesystem=utf8mb4 --character-set-server=utf8mb4 --collation-server=utf8mb4_general_ci --default-authentication-plugin=mysql_native_password --max_allowed_packet=256M --tls-version=''"

	write_deploy_section 1G

	write "        environment:"
	write "            - MYSQL_DATABASE=lportal"
	write "            - MYSQL_PASSWORD=password"
	write "            - MYSQL_ROOT_HOST=%"
	write "            - MYSQL_ROOT_PASSWORD=password"
	write "            - MYSQL_USER=dxpcloud"
	write "        image: mysql:8.0.32"
	write "        ports:"
	write "            - 127.0.0.1:${DATABASE_PORT}:3306"
	write "        volumes:"
	write "            - ./database_import:/docker-entrypoint-initdb.d"
	write "            - mysql-db:/var/lib/mysql"
}

function build_service_liferay {
	mkdir -p build/liferay/resources/opt/liferay

	cp ../../orca/templates/liferay/resources/opt/liferay/cluster-link-tcp.xml build/liferay/resources/opt/liferay

	mkdir -p build/liferay/resources/usr/local/bin

	cp ../../orca/templates/liferay/resources/usr/local/bin/remove_lock_on_startup.sh build/liferay/resources/usr/local/bin

	mkdir -p build/liferay/resources/usr/local/liferay/scripts/pre-startup

	cp ../../orca/templates/liferay/resources/usr/local/liferay/scripts/pre-startup/10_wait_for_dependencies.sh build/liferay/resources/usr/local/liferay/scripts/pre-startup

	(
		echo "FROM $(grep -e '^liferay.workspace.docker.image.liferay=' "${SPINNER_LIFERAY_LXC_REPOSITORY_DIR}/liferay/gradle.properties" | cut -d'=' -f2)"

		echo "COPY resources/opt/liferay /opt/liferay"
		echo "COPY resources/usr/local/bin /usr/local/bin"
		echo "COPY resources/usr/local/liferay/scripts /usr/local/liferay/scripts"

		cat "${SPINNER_LIFERAY_LXC_REPOSITORY_DIR}/liferay/Dockerfile.ext"
	) > build/liferay/Dockerfile

	mkdir -p liferay_mount/files/deploy

	cp -r ../dxp-activation-key/*.xml liferay_mount/files/deploy

	cp -r "${SPINNER_LIFERAY_LXC_REPOSITORY_DIR}"/liferay/configs/common/* liferay_mount/files
	cp -r "${SPINNER_LIFERAY_LXC_REPOSITORY_DIR}"/liferay/configs/"${LXC_ENVIRONMENT}"/* liferay_mount/files

	echo "Deleting the following files from DXP configuration to ensure it can run locally:"
	echo ""

	for file in \
		osgi/configs/com.liferay.portal.k8s.agent.configuration.PortalK8sAgentConfiguration.config \
		osgi/configs/com.liferay.portal.search.elasticsearch7.configuration.ElasticsearchConfiguration.config \
		osgi/configs/com.liferay.portal.security.sso.openid.connect.configuration.OpenIdConnectConfiguration.config \
		osgi/configs/com.liferay.portal.security.sso.openid.connect.internal.configuration.OpenIdConnectProviderConfiguration_liferayokta.config \
		tomcat/webapps/ROOT/WEB-INF/classes/META-INF/portal-log4j-ext.xml
	do
		rm -f ${file}

		echo "    ${file}"
	done

	echo ""

	mkdir -p liferay_mount/files/patching
	mkdir -p liferay_mount/files/scripts

	mv liferay_mount/files/patching liferay_mount
	mv liferay_mount/files/scripts liferay_mount

	(
		echo "active=B\"true\""
		echo "maxUsers=I\"0\""
		echo "mx=\"spinner-test.com\""
		echo "siteInitializerKey=\"\""
		echo "virtualHostname=\"spinner-test.com\""
	) >> "liferay_mount/files/osgi/configs/com.liferay.portal.instances.internal.configuration.PortalInstancesConfiguration~spinner-test.com.config"

	for index in {1..2}
	do
		local port_last_digit=$((index - 1))

		write "    liferay-${index}:"
		write "        build: ./build/liferay"

		write_deploy_section 6G

		write "        environment:"
		write "            - LCP_LIFERAY_UPGRADE_ENABLED=\${LCP_LIFERAY_UPGRADE_ENABLED:-}"
		write "            - LCP_SECRET_DATABASE_HOST=database"
		write "            - LCP_SECRET_DATABASE_PASSWORD=password"
		write "            - LCP_SECRET_DATABASE_USER=root"
		write "            - LIFERAY_CLUSTER_PERIOD_LINK_PERIOD_AUTODETECT_PERIOD_ADDRESS="
		write "            - LIFERAY_CLUSTER_PERIOD_LINK_PERIOD_CHANNEL_PERIOD_LOGIC_PERIOD_NAME_PERIOD_CONTROL=control-channel-liferay-${index}"
		write "            - LIFERAY_CLUSTER_PERIOD_LINK_PERIOD_CHANNEL_PERIOD_LOGIC_PERIOD_NAME_PERIOD_TRANSPORT_PERIOD_NUMBER0=transport-channel-logic-${index}"
		write "            - LIFERAY_CLUSTER_PERIOD_LINK_PERIOD_CHANNEL_PERIOD_PROPERTIES_PERIOD_CONTROL=/opt/liferay/cluster-link-tcp.xml"
		write "            - LIFERAY_CLUSTER_PERIOD_LINK_PERIOD_CHANNEL_PERIOD_PROPERTIES_PERIOD_TRANSPORT_PERIOD__NUMBER0_=/opt/liferay/cluster-link-tcp.xml"
		write "            - LIFERAY_CLUSTER_PERIOD_LINK_PERIOD_ENABLED=true"
		write "            - LIFERAY_CONFIGURATION_PERIOD_OVERRIDE_PERIOD_COM_PERIOD_LIFERAY_PERIOD_PORTAL_PERIOD_SEARCH_PERIOD_ELASTICSEARCH_NUMBER7__PERIOD_CONFIGURATION_PERIOD__UPPERCASEE_LASTICSEARCH_UPPERCASEC_ONFIGURATION_UNDERLINE_CLUSTER_UPPERCASEN_AME=\"liferay_cluster\""
		write "            - LIFERAY_CONFIGURATION_PERIOD_OVERRIDE_PERIOD_COM_PERIOD_LIFERAY_PERIOD_PORTAL_PERIOD_SEARCH_PERIOD_ELASTICSEARCH_NUMBER7__PERIOD_CONFIGURATION_PERIOD__UPPERCASEE_LASTICSEARCH_UPPERCASEC_ONFIGURATION_UNDERLINE_NETWORK_UPPERCASEH_OST_UPPERCASEA_DDRESSES=\"search:9200\""
		write "            - LIFERAY_CONFIGURATION_PERIOD_OVERRIDE_PERIOD_COM_PERIOD_LIFERAY_PERIOD_PORTAL_PERIOD_SEARCH_PERIOD_ELASTICSEARCH_NUMBER7__PERIOD_CONFIGURATION_PERIOD__UPPERCASEE_LASTICSEARCH_UPPERCASEC_ONFIGURATION_UNDERLINE_OPERATION_UPPERCASEM_ODE=\"REMOTE\""
		write "            - LIFERAY_CONFIGURATION_PERIOD_OVERRIDE_PERIOD_COM_PERIOD_LIFERAY_PERIOD_PORTAL_PERIOD_SEARCH_PERIOD_ELASTICSEARCH_NUMBER7__PERIOD_CONFIGURATION_PERIOD__UPPERCASEE_LASTICSEARCH_UPPERCASEC_ONFIGURATION_UNDERLINE_PRODUCTION_UPPERCASEM_ODE_UPPERCASEE_NABLED=B\"true\""
		write "            - LIFERAY_DISABLE_TRIAL_LICENSE=true"
		write "            - LIFERAY_JDBC_PERIOD_DEFAULT_PERIOD_DRIVER_UPPERCASEC_LASS_UPPERCASEN_AME=org.mariadb.jdbc.Driver"
		write "            - LIFERAY_JDBC_PERIOD_DEFAULT_PERIOD_PASSWORD=password"
		write "            - LIFERAY_JDBC_PERIOD_DEFAULT_PERIOD_URL=jdbc:mysql://database/lportal?characterEncoding=UTF-8&dontTrackOpenResources=true&holdResultsOpenOverStatementClose=true&serverTimezone=GMT&useFastDateParsing=false&useUnicode=true&useSSL=false"
		write "            - LIFERAY_JDBC_PERIOD_DEFAULT_PERIOD_USERNAME=root"
		write "            - LIFERAY_JPDA_ENABLED=true"
		write "            - LIFERAY_SETUP_PERIOD_DATABASE_PERIOD_JAR_PERIOD_SHA_NUMBER1__OPENBRACKET_COM_PERIOD_MYSQL_PERIOD_CJ_PERIOD_JDBC_PERIOD__UPPERCASED_RIVER_CLOSEBRACKET_=6d6ea84c870837afa63f5f55efde211a84cf2897"
		write "            - LIFERAY_SETUP_PERIOD_DATABASE_PERIOD_JAR_PERIOD_URL_OPENBRACKET_COM_PERIOD_MYSQL_PERIOD_CJ_PERIOD_JDBC_PERIOD__UPPERCASED_RIVER_CLOSEBRACKET_=https://repo1.maven.org/maven2/org/mariadb/jdbc/mariadb-java-client/2.7.4/mariadb-java-client-2.7.4.jar"
		write "            - LIFERAY_UPGRADE_ENABLED=false"
		write "            - LIFERAY_USERS_PERIOD_REMINDER_PERIOD_QUERIES_PERIOD_ENABLED=false"
		write "            - LIFERAY_WEB_PERIOD_SERVER_PERIOD_PROTOCOL=http"
		write "            - LIFERAY_WORKSPACE_ENVIRONMENT=${LXC_ENVIRONMENT}"
		write "            - LOCAL_STACK=true"
		write "            - ORCA_LIFERAY_SEARCH_ADDRESSES=search:9200"
		write "        hostname: liferay-${index}"
		write "        ports:"
		write "            - 127.0.0.1:1800${port_last_digit}:8000"
		write "            - 127.0.0.1:1808${port_last_digit}:8080"
		write "        volumes:"
		write "            - liferay-document-library:/opt/liferay/data"
		write "            - ./liferay_mount:/mnt/liferay"
	done
}

function build_service_search {
	mkdir -p build/search

	grep -v "^FROM" ../../orca/templates/search/Dockerfile | sed -e "s/#FROM/FROM/" > build/search/Dockerfile

	mkdir -p database_import

	mkdir -p build/webserver/resources/etc/nginx
	cp -a "${LIFERAY_LXC_REPOSITORY_DIR}"/webserver/configs/common/blocks.d/ build/webserver/resources/etc/nginx
	rm -f build/webserver/resources/etc/nginx/blocks.d/oauth2_proxy_pass.conf
	rm -f build/webserver/resources/etc/nginx/blocks.d/oauth2_proxy_protection.conf

	cp -a "${LIFERAY_LXC_REPOSITORY_DIR}"/webserver/configs/common/conf.d/ build/webserver/resources/etc/nginx
	cp -a "${LIFERAY_LXC_REPOSITORY_DIR}"/webserver/configs/common/public/ build/webserver/resources/etc/nginx

	export DOLLAR="$"
	envsubst < ../resources/webserver/etc/nginx/nginx.conf > build/webserver/resources/etc/nginx/nginx.conf
	if [ "${MODSEC}" = on ]
	then
		cp -r ../resources/webserver/modsec build/webserver/resources/etc/nginx/
	fi

	mkdir -p build/webserver/resources/usr/local/bin/

	if [ -e "${LIFERAY_LXC_REPOSITORY_DIR}"/webserver/configs/common/scripts/10-replace-environment-variables.sh ]
	then
		cp -a "${LIFERAY_LXC_REPOSITORY_DIR}"/webserver/configs/common/scripts/10-replace-environment-variables.sh build/webserver/resources/usr/local/bin/
		chmod +x build/webserver/resources/usr/local/bin/10-replace-environment-variables.sh
	fi

	mkdir -p build/webserver/resources/etc/usr
	cp -a ../resources/webserver/usr/ build/webserver/resources/

	create_liferay_dockerfile

	create_liferay_configuration

	create_webserver_dockerfile

	write "services:"
	write "    antivirus:"

	write_deploy 1G

	write "        image: clamav/clamav:1.0.1-1"
	write "        ports:"
	write "            - \"3310:3310\""
	write "    database:"
	write "        command: mysqld --character-set-server=utf8mb4 --collation-server=utf8mb4_general_ci --character-set-filesystem=utf8mb4 --default-authentication-plugin=mysql_native_password --max_allowed_packet=256M --tls-version=''"

	write_deploy 1G

	write "        environment:"
	write "            - MYSQL_DATABASE=lportal"
	write "            - MYSQL_PASSWORD=password"
	write "            - MYSQL_ROOT_HOST=%"
	write "            - MYSQL_ROOT_PASSWORD=password"
	write "            - MYSQL_USER=dxpcloud"
	write "        image: mysql:8.0.32"
	write "        ports:"
	write "            - 127.0.0.1:${DATABASE_PORT}:3306"
	write "        volumes:"
	write "            - ./database_import:/docker-entrypoint-initdb.d"
	write "            - mysql-db:/var/lib/mysql"

	write_liferay liferay-1 0
	write_liferay liferay-2 1

	write "    search:"
	write "        build: ./build/search"

	write_deploy_section 2G

	write "        environment:"
	write "            - discovery.type=single-node"
	write "            - xpack.ml.enabled=false"
	write "            - xpack.monitoring.enabled=false"
	write "            - xpack.security.enabled=false"
	write "            - xpack.sql.enabled=false"
	write "            - xpack.watcher.enabled=false"
}

function build_service_web_server {
	mkdir -p build/web-server/resources/etc/nginx

	local web_server_dir="${SPINNER_LIFERAY_LXC_REPOSITORY_DIR}"/webserver

	cp -a "${web_server_dir}"/configs/common/blocks.d build/web-server/resources/etc/nginx

	rm -f build/web-server/resources/etc/nginx/blocks.d/oauth2_proxy_pass.conf
	rm -f build/web-server/resources/etc/nginx/blocks.d/oauth2_proxy_protection.conf

	cp -a "${web_server_dir}"/configs/common/conf.d build/web-server/resources/etc/nginx
	cp -a "${web_server_dir}"/configs/common/public build/web-server/resources/etc/nginx

	cp ../resources/web-server/etc/nginx/nginx.conf build/web-server/resources/etc/nginx

	mkdir -p build/web-server/resources/usr/local/bin

	if [ -e "${web_server_dir}"/configs/common/scripts/10-replace-environment-variables.sh ]
	then
		cp -a "${web_server_dir}"/configs/common/scripts/10-replace-environment-variables.sh build/web-server/resources/usr/local/bin

		chmod +x build/web-server/resources/usr/local/bin/10-replace-environment-variables.sh
	fi

	mkdir -p build/web-server/resources/etc/usr

	cp -a ../resources/web-server/usr build/web-server/resources

	(
		head -n 1 "${web_server_dir}"/Dockerfile

		echo "COPY resources/etc/nginx /etc/nginx"
		echo "COPY resources/usr/local /usr/local"

	) > build/web-server/Dockerfile

	write "    web-server:"
	write "        build: ./build/web-server"

	write_deploy_section 1G

	write "        ports:"
	write "            - 127.0.0.1:80:80"
}

function build_services {
	lc_cd "${STACK_DIR}"

	write "services:"

	build_service_antivirus
	build_service_database
	build_service_liferay
	build_service_search
	build_service_web_server

	write "volumes:"
	write "    liferay-document-library:"
	write "    mysql-db:"
}

function check_usage {
	lc_check_utils docker

	DATABASE_IMPORT=
	DATABASE_PORT=13306
	LXC_ENVIRONMENT=

	while [ "${1}" != "" ]
	do
		case ${1} in
			-d)
				shift

				DATABASE_IMPORT=${1}

				;;
			-h)
				print_help

				;;
			-m)
				shift

				export MODSEC=on

				;;
			-o)
				shift

				STACK_NAME=env-${1}

				;;
			-r)
				DATABASE_PORT=$((RANDOM % 100 + 13300))

				echo "Database port: ${DATABASE_PORT}"

				;;
			-s)
				shift

				DATABASE_SKIP_TABLE=${1}

				;;
			*)
				LXC_ENVIRONMENT=${1}

				;;
		esac

		shift
	done

	if [ ! -n "${LXC_ENVIRONMENT}" ]
	then
		LXC_ENVIRONMENT=x1e4prd

		echo "Using LXC environment \"x1e4prd\" because the LXC environment was not set."
		echo ""
	fi

	lc_cd "$(dirname "$0")"

	if [ ! -n "${SPINNER_LIFERAY_LXC_REPOSITORY_DIR}" ]
	then
		SPINNER_LIFERAY_LXC_REPOSITORY_DIR=$(pwd)"/../../liferay-lxc"
	fi

	if [ ! -e "${SPINNER_LIFERAY_LXC_REPOSITORY_DIR}" ]
	then
		echo "The ${SPINNER_LIFERAY_LXC_REPOSITORY_DIR} directory does not exist. Clone the liferay-lxc repository to this directory or set the environment variable \"SPINNER_LIFERAY_LXC_REPOSITORY_DIR\" to point to an existing clone."

		exit "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi

	if [ ! -e "${SPINNER_LIFERAY_LXC_REPOSITORY_DIR}/liferay/configs/${LXC_ENVIRONMENT}" ]
	then
		echo "The directory ${SPINNER_LIFERAY_LXC_REPOSITORY_DIR}/liferay/configs/${LXC_ENVIRONMENT} does not exist."

		exit "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi

	if [[ $(find dxp-activation-key -name "*.xml" | wc -l ) -eq 0 ]]
	then
		echo ""
		echo "Copy a valid DXP license to the dxp-activation-key directory before running this script."

		exit "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi

	if [ ! -n "${STACK_NAME}" ]
	then
		STACK_NAME="env-${LXC_ENVIRONMENT}-"$(date +%s)
	fi

	STACK_DIR=$(pwd)/${STACK_NAME}

	if [ -e "${STACK_DIR}" ]
	then
		echo ""
		echo "Stack directory already exists."

		exit "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi

	mkdir -p "${STACK_DIR}"

	if [ ! -n "${MODSEC}" ]
	then
		export MODSEC=off

		echo "Modsecurity was not enabled, building without modsec module. Use -m to enable it."
	fi
}

function main {
	check_usage "${@}"

	(
		build_services

		prepare_database_import

		print_docker_compose_usage
	) | tee -a "${STACK_DIR}/README.txt"
}

function prepare_database_import {
	mkdir -p database_import

	if [ ! -n "${DATABASE_IMPORT}" ]
	then
		return
	fi

	echo ""
	echo "Preparing to import ${DATABASE_IMPORT}."

	lc_cd "${STACK_DIR}"/database_import

	cp "${DATABASE_IMPORT}" .

	if [ $(find . -type f -name "*.gz" | wc -l) -gt 0 ]
	then
		echo ""
		echo "Extracting the database import file."

		gzip -d $(find . -type f -name "*.gz") 
	fi

	mv $(find . -type f) 01_database.sql

	if [ -n "${DATABASE_SKIP_TABLE}" ]
	then
		echo ""
		echo "Removing ${DATABASE_SKIP_TABLE} from the database import."

		grep -v "^INSERT INTO .${DATABASE_SKIP_TABLE}. VALUES (" < 01_database.sql > 01_database_removed.sql

		rm 01_database.sql

		mv 01_database_removed.sql 01_database.sql
	fi

	echo ""
	echo "Adding 10_after_import.sql to make changes to the database. Review them before starting the container."

	echo "update VirtualHost SET hostname=concat(hostname, \".local\");" > 10_after_import.sql
}

function print_docker_compose_usage {
	echo "The stack configuration is ready to use. It is available in the ${STACK_NAME} directory. Use the following commands to start all services:"
	echo ""
	echo "    cd ${STACK_NAME}"
	echo ""
	echo "    $(lc_docker_compose) up -d antivirus database search web-server"
	echo ""
	echo "    $(lc_docker_compose) up liferay-1"
	echo ""
	echo "Use the following command to start the second Liferay node to test clustering:"
	echo ""
	echo "    $(lc_docker_compose) up liferay-2"
	echo ""
	echo "See https://liferay.atlassian.net/l/cp/SD571mFA for more information on how to debug."
}

function print_help {
	echo "Usage: ${0} <lxc-environment> -d <database-import>"
	echo ""
	echo "The script can be configured with the following arguments:"
	echo ""
	echo "    -d (optional): Set the database import file (raw or with a .gz suffix). Virtual hosts will be suffixed with .local (e.g. abc.liferay.com becomes abc.liferay.com.local)."
	echo "    -m (optional): Enable Modsecurity"
	echo "    -o (optional): Set directory name where the stack configuration will be created. It will be prefixed with \"env-\"."
	echo "    -r (optional): Randomize the MySQL port opened on localhost to enable multiple database servers at the same time"
	echo "    -s (optional): Skip the specified table name in the database import"
	echo ""
	echo "The default LXC environment is \"x1e4prd\"."
	echo ""
	echo "Example: ${0} x1e4prd -d sql.gz -o test"

	exit "${LIFERAY_COMMON_EXIT_CODE_HELP}"
}

function write {
	echo "${1}" >> docker-compose.yml
}

function write_deploy_section {
	write "        deploy:"
	write "            resources:"
	write "                limits:"
	write "                    memory: ${1}"
	write "                reservations:"
	write "                    memory: ${1}"
}

main "${@}"