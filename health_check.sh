#!/bin/bash

REMOTE_USER="cloud-user"
REMOTE_HOST="10.144.167.246"
PEM_KEY="../practiceserver.pem"

remote_exec() {
    ssh -i "$PEM_KEY" "${REMOTE_USER}@${REMOTE_HOST}" "$@"
}

get_health_status() {
    local deployment_name=$1
    local namespace=$2

    echo "Retrieving health status for deployment: $deployment_name in namespace: $namespace"

    # Get the deployment status
    echo "Checking deployment status..."
    remote_exec "kubectl get deployment $deployment_name -n $namespace -o wide"

    # Get pod status
    echo "Checking pod status..."
    remote_exec "kubectl get pods -n $namespace -l app=$deployment_name"

    # Get pod metrics (CPU and memory usage)
    echo "Retrieving CPU and memory metrics..."
    remote_exec "kubectl top pod -n $namespace -l app=$deployment_name"

    # Check for any issues or failures
    echo "Checking for any issues or failures in the deployment..."
    remote_exec "kubectl describe deployment $deployment_name -n $namespace"
    remote_exec "kubectl describe pods -n $namespace -l app=$deployment_name"

    echo "Health status retrieval complete."
}

main(){
	read -rp "Enter the deployment name: " DEPLOYMENT_NAME
   	read -rp "Enter the namespace (default): " NAMESPACE
    	NAMESPACE=${NAMESPACE:-default}
	read -rp "Do you want to check the health status of the deployment? (yes/no): " check_health
    	if [[ "$check_health" == "yes" ]]; then
        	get_health_status "$DEPLOYMENT_NAME" "$NAMESPACE"
    	fi
}

main
