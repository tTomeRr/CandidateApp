#!/bin/bash

# Define basic application arguments
flask_replica_count=1
mongodb_replica_count=1
cluster_config_file="cluster-config"
cluster_name="dogsvscats-cluster"
app_chart_name="flask-mongodb-chart"
app_namespace="application-namespace"

time=$(date "+%d.%m.%y-%H:%M:%S")
errorfile="error_$time.log"

# Define colors for the output messages
RED='\033[0;31m'
GREEN='\033[0;32m'
ORANGE='\033[0;33m'
LIGHTBLUE='\033[1;34m'
NC='\033[0m' # No Color

# Create an error log file if it doesn't exist.
function error_logging(){
	if [ ! -d error ]; then
		mkdir error
	fi

	touch "error/$errorfile"
}

# Display help information for the script.
function display_help(){
	echo "DogsVsCats"
	echo "  $0 is a script allowing you to download a simple Flask application, that will run on Kubernetes with Nginx."
	echo ""

	echo "USAGE"
	echo "  -i        Install"
	echo "  -d        Uninstall"
	echo "  -f <arg>  Upgrading Flask replicas to have 1-5 replicas"
	echo "  -m <arg>  Upgrading Mongodb replicas to have 1-5 replicas"
	echo "  -h        Help"
	echo ""

	echo "PREREQUISITES"
	echo "  1.You must run the script in the DogsVsCats folder."
	echo "  2.You must run the script with root user."
	echo "  3.You must have Docker installed."
	echo "  4.You must have Kind installed."
	echo "  5.You must have Kubectl insatlled."
	echo "  6.You must have Helm insatlled."
	echo ""

	echo "EXAMPLE USAGES"
	echo "  Installing the application- '$0' -i"
	echo "  Deleting the application- '$0' -d"
	echo "  Upgrading Flask and Mongodb replicas to 3 and 3- '$0' -f 3 -m 3"
	exit 1
}

# Display usage information for the script.
function usage() {
	echo "Usage: $0 [-i] [-d] [-f <arg>] [-m <arg>] [-h]"
}

# Check if the script is run as the root user.
function root_prerequisites() {
    if [ $(id -u) -ne 0 ]; then
        echo -e "${RED}ERROR: Please run as root.${NC}"
        exit 1
    fi
}

# Check if Docker is installed.
function docker_prerequisites() {
    if [ ! -x "$(command -v docker)" ]; then
        echo -e "${RED}ERROR: Please download Docker.${NC}"
        exit 1
    fi
}

# Check if Kind is installed.
function kind_prerequisites() {
    if [ ! -x "$(command -v kind)" ]; then
        echo -e "${RED}ERROR: Please download Kind.${NC}"
        exit 1
    fi
}

# Check if Kubectl is installed.
function kubectl_prerequisites() {
    if [ ! -x "$(command -v kubectl)" ]; then
        echo -e "${RED}ERROR: Please download Kubectl.${NC}"
        exit 1
    fi
}

# Check if Helm is installed.
function helm_prerequisites() {
    if [ ! -x "$(command -v helm)" ]; then
        echo -e "${RED}ERROR: Please download Helm.${NC}"
        exit 1
    fi
}

# Check if the script is run from the DogsVsCats directory.
function folder_prerequisites() {
    if [[ $(basename $(pwd)) != "DogsVsCats" ]]; then
        echo -e "${RED}ERROR: Please run this script from the DogsVsCats directory.${NC}"
        exit 1
    fi
}



# Check all prerequisites for running the script.
function check_prerequisites() {
	echo "Checking prerequisites..."
	root_prerequisites
	docker_prerequisites
	kind_prerequisites
	kubectl_prerequisites
	helm_prerequisites
	folder_prerequisites
	echo -e "${GREEN}Finished checking prerequisites...${NC}"
}

# Check if the specified Helm chart directory exists.
function check_helm_chart_dir_exist() {
	if [ -d "$1" ]; then
		return 0 # == true
	else
		return 1 # == false
	fi
}

# Check if flask cluster exists.
function check_cluster_exists() {
	if [ -z "$(kind get clusters | grep $cluster_name)" ]; then
		return 1 # == false
	else
		return 0 # == true
	fi
}

# Check if the specified file exists.
function check_file_exists() {
	if [ -e "$1" ]; then
		return 0 # == true
	else
		return 1 # == false
	fi
}

# Prepare the Kubernetes cluster for deployment.
function prepare_cluster() {
	if ! check_cluster_exists; then
		if ! check_file_exists "$cluster_config_file.yaml"; then
			echo -e "${RED}ERROR: '$cluster_config_file.yaml' does not exist.${NC}"
			exit 1
		else
			echo "Creating Cluster..."
			kind create cluster --config="$cluster_config_file.yaml" 
			echo -e "${GREEN}Finished creating Cluster...${NC}"
		fi
	fi
}

# Prepare the Helm charts for deployment.
function prepare_helm_chart() {
	if ! check_helm_chart_dir_exist $app_chart_name; then
		echo -e "${RED}ERROR: $app_chart_name does not exist.${NC}"
		exit 1
	fi
}

# Check if the specified Helm release exists.
function check_helm_release_exists() {
	if helm list --short | grep -q "$1"; then
		return 0 # == true
	else
		return 1 # == false
	fi
}

# Prepare for execution by setting up the cluster and Helm charts.
function prepare_execution() {
	echo "Preparing execution...."
	prepare_cluster
	prepare_helm_chart
	echo -e "${GREEN}Finished preparing execution...${NC}"
}

# Wait for the metallb and mongodb pods to be ready.
function wait_for_pods_ready() {
	metallb_pods=$(kubectl get pods -n metallb-system --no-headers -o custom-columns=":metadata.name")
	mongodb_pods=$(kubectl get pods --no-headers -o custom-columns=":metadata.name")

	echo "Waiting for metallb pods to be ready..."
	for pod in $metallb_pods; do
		kubectl wait --for=condition=Ready pod/$pod -n metallb-system --timeout=1h
	done

	echo "Waiting for mongodb pods to be ready..."
	for pod in $mongodb_pods; do
		kubectl wait --for=condition=Ready pod/$pod --timeout=1h
	done
	echo -e "${GREEN}All pods are ready!${NC}"
}

# Apply necessary YAML files for the deployment.
function apply_yamls(){
	echo "Applying necessary YAML files..."
	kubectl apply -f https://raw.githubusercontent.com/nginxinc/kubernetes-ingress/v3.5.0/deploy/crds.yaml

	if [ -e metallb/ip-pool.yaml ]; then
		kubectl apply -f metallb/ip-pool.yaml
	else
		echo -e "${RED}Missing ip-pool.yaml file${NC}"
		exit 1
	fi

	if [ -e metallb/l2advertisement.yaml ]; then
		kubectl apply -f metallb/l2advertisement.yaml
	else
		echo -e "${RED}Missing l2advertisement.yaml file${NC}"
		exit 1
	fi
	echo -e "${GREEN}Finished applying necassary YAML files...${NC}"
}

# Output the URL for the deployed website.
function output_url(){

	ip_address=$(kubectl get svc nginx-ingress-controller -o=jsonpath='{.status.loadBalancer.ingress[0].ip}')
	url=$(cat ./$app_chart_name/templates/flask-deployment.yaml | grep host | awk '{print $NF}')

	if ! grep -q "$ip_address.*$url" /etc/hosts; then
		echo "$ip_address $url" >> /etc/hosts
	elif grep -q "$url" /etc/hosts; then
		sed -i "/$url/d" /etc/hosts
		echo "$ip_address $url" >> /etc/hosts
	fi

	echo -e "Your URL for the website is ${LIGHTBLUE}$url${NC}"
}

# Check if the website is ready to be accessed.
function check_site_ready() {
	url=$(awk '/host:/ {print $NF}' ./$app_chart_name/templates/flask-deployment.yaml)
	echo "Waiting for site to be ready..."
	timeout=30 # each timeout interval is 3 seconds, 30 in this value equals 90 seconds.

	while true; do
		http_status=$(curl --silent --head "$url" | awk '/^HTTP/{print $2}') # Return http status via curl command.
		if [ "$http_status" = "200" ]; then
			break
		elif [ $timeout -eq 0 ]; then
			echo -e "${RED}ERROR: could not access site. Status code: '$http_status'. Pod output will be in the error log file. ${NC}" | tee -a error/$errorfile  

			# Sending log messages of the mongodb and flask pods to the error file
			kubectl logs -n=$app_namespace $(kubectl get pods -n=$app_namespace -o jsonpath='{.items[0].metadata.name}') >> error/$errorfile
			kubectl logs $(kubectl get pods -o jsonpath='{.items[0].metadata.name}') >> error/$errorfile
			exit 1
		else
			sleep 3
			((timeout--))
		fi
	done

	echo -e "${GREEN}Site is now ready!${NC}"
}

# Install the Flask application and its dependencies on the Kind cluster
function install(){
	check_prerequisites
	prepare_execution

	echo "Installing $app_chart_name..."
	if ! check_helm_release_exists "$app_chart_name"; then
		helm install $app_chart_name ./$app_chart_name --set mongodbReplicaCount=$mongodb_replica_count --set flaskReplicaCount=$flask_replica_count
		echo -e "${GREEN}Finished installing $app_chart_name${NC}"
	else
		echo -e "${ORANGE}$app_chart_name is already installed. Skipping installation.${NC}"
	fi
	
	
	echo "Installing Metallb..."
	if [ -e metallb/metallb.yaml ]; then
		kubectl apply -f metallb/metallb.yaml
	else
		echo -e "${RED}Missing metallb.yaml file${NC}"
		exit 1
	fi

	# Waiting for pods to be ready and applying neccesary YAML files before installing the Nginx ingress Helm chart.
	wait_for_pods_ready
	apply_yamls

	echo "Installing Nginx ingress Helm Chart...."
	if ! check_helm_release_exists "nginx-ingress"; then
		helm install nginx-ingress oci://ghcr.io/nginxinc/charts/nginx-ingress --version 1.1.3
		echo -e "${GREEN}Finished installing Nginx ingress Helm Chart${NC}"
	else
		echo -e "${ORANGE}Nginx ingress Helm Chart is already installed. Skipping installation.${NC}"
	fi

	check_site_ready
	output_url
}

# Uninstall the Flask application and delete the Kubernetes cluster.
function uninstall(){
	check_prerequisites
	if ! check_cluster_exists; then
		echo -e "${RED}ERROR: $cluster_config_file does not exist, nothing to do.${NC}"
		exit 1
	else
		echo "Deleting Cluster..."
		kind delete clusters $cluster_name
		echo -e "${GREEN}Finished deleting Cluster...${NC}"
		exit 0
	fi
}

# Upgrade the number of Flask replicas.
function upgrade_flask() {
	flask_replica_count_update=$1

	current_flask_replicas=$(helm get values "$app_chart_name" --all | grep flaskReplicaCount: | awk '{print $NF}')

	echo "Upgrading Flask replicas..."

	if ! check_helm_release_exists "$app_chart_name"; then
		echo -e "${RED}ERROR: $app_chart_name has not been found.${NC}"
		exit 1
	elif [ "$current_flask_replicas" -eq "$flask_replica_count_update" ]; then
		echo -e "${ORANGE}Nothing to upgrade for Flask.${NC}"
	else
		echo "Upgrading Flask replicas..."
		helm upgrade "$app_chart_name" ./$app_chart_name --set flaskReplicaCount="$flask_replica_count_update" > /dev/null 2>> error/$errorfile
		echo -e "${GREEN}Finished upgrading Flask replicas${NC}"
	fi
}

# Upgrade the number of MongoDB replicas.
function upgrade_mongo() {
	mongodb_replica_count_update=$1

	current_mongodb_replicas=$(helm get values "$app_chart_name" --all | grep mongodbReplicaCount: | awk '{print $NF}')

	echo "Upgrading MongoDB replicas..."

	if ! check_helm_release_exists "$app_chart_name"; then
		echo -e "${RED}ERROR: $app_chart_name has not been found.${NC}"
		exit 1
	elif [ "$current_mongodb_replicas" -eq "$mongodb_replica_count_update" ]; then
		echo -e "${ORANGE}Nothing to upgrade for MongoDB.${NC}"
	else
		echo "Upgrading MongoDB replicas..."
		helm upgrade "$app_chart_name" ./$app_chart_name --set mongodbReplicaCount="$mongodb_replica_count_update" > /dev/null 2>> error/$errorfile
		echo -e "${GREEN}Finished upgrading MongoDB replicas${NC}"
	fi
}

# Create the error log file
error_logging


# If no arguments has been sent to the user then display usage and exit code.
if [ $# -eq 0 ]; then
	usage
	exit 1
fi

# Handle script flags
while getopts ":idf:m:h" opt; do
	case ${opt} in
		i)
			install
			;;
		d)
			uninstall
			;;
		f)
			if [ -z "${OPTARG}" ]; then
				echo "Error: -f requires an argument."
				usage
			elif [[ "${OPTARG}" =~ ^[1-5]$ ]]; then # Checks that the argument passed to the flag is between 1-5
				upgrade_flask ${OPTARG}
			else
				echo "Error: argument must be between 1-5"
				usage
			fi
			;;
		m)
			if [ -z "${OPTARG}" ]; then
				echo "Error: -m requires an argument."
				usage
			elif [[ "${OPTARG}" =~ ^[1-5]$ ]]; then # Checks that the argument passed to the flag is between 1-5
				upgrade_mongo ${OPTARG}
			else
				echo "Error: argument must be between 1-5"
				usage
			fi
			;;
		h)
			display_help
			;;
		\?)
			echo "Invalid option: -${OPTARG}"
			usage
			;;
	esac
done
shift $((OPTIND -1))

# If error log file is empty, delete him, else print a message to the user that an error occured.
if [ ! -s "error/$errorfile" ]; then
	rm "error/$errorfile"
else
	echo -e "${RED}An Error occured, check the log at the error directory.${NC}"
fi

