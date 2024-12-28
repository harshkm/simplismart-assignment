#!/bin/bash

set -euo pipefail

REMOTE_HOST="10.144.167.246"  # Replace with the remote server address
REMOTE_USER="cloud-user"      # Replace with the SSH username
KUBE_DIR="/tmp/"              # Directory on the remote server for YAML files
TEMPLATE_DIR="./kubernetes-files"
PEM_KEY="../practiceserver.pem"

HELM_URL="https://get.helm.sh/helm-v3.16.4-linux-amd64.tar.gz"
KEDA_HELM_REPO="https://kedacore.github.io/charts"
KEDA_HELM_CHART="kedacore/keda"
KEDA_NAMESPACE="keda"

remote_exec() {
    ssh -i "$PEM_KEY" "${REMOTE_USER}@${REMOTE_HOST}" "$@"
}

remote_copy() {
    scp -i "$PEM_KEY" "$1" "${REMOTE_USER}@${REMOTE_HOST}:$2"
}

install_helm() {
    if remote_exec 'helm version > /dev/null 2>&1'; then
        echo "Helm is already installed."
    else
        echo "Helm is not installed. Installing Helm..."

        if ! wget "$HELM_URL" -O helm-v3.16.4-linux-amd64.tar.gz; then
            echo "Error: Failed to download Helm"
            exit 1
        fi

        tar -xzvf helm-v3.16.4-linux-amd64.tar.gz
        chmod +x linux-amd64/helm

        remote_copy "./linux-amd64/helm" "/tmp/helm"
        remote_exec 'sudo mv /tmp/helm /usr/local/bin/ && sudo chmod +x /usr/local/bin/helm'

        if remote_exec 'helm version > /dev/null 2>&1'; then
            echo "Helm installed successfully."
        else
            echo "Error: Helm installation failed"
            exit 1
        fi
    fi
}


check_dependencies() {
    echo "Checking local dependencies..."
    for tool in ssh scp sed wget tar; do
        if ! command -v "$tool" &>/dev/null; then
            echo "Error: $tool is not installed. Please install it and try again."
            exit 1
        fi
    done
    echo "Checking K8s dependencies..."
    install_helm
    echo "All local dependencies are installed."
}

install_keda() {
    echo "Adding KEDA Helm repository..."
    remote_exec "helm repo add keda $KEDA_HELM_REPO && helm repo update"

    echo "Installing KEDA using Helm..."
    remote_exec "helm install keda $KEDA_HELM_CHART --namespace $KEDA_NAMESPACE --create-namespace"
    remote_exec "kubectl get pods -n $KEDA_NAMESPACE"
    echo "KEDA installed successfully."
}

replace_variables() {
    local template=$1
    local output=$2

    if [ -z "${DEPLOYMENT_NAME:-}" ]; then
        echo "Error: DEPLOYMENT_NAME is required."
        exit 1
    fi
    if [ -z "${IMAGE:-}" ]; then
        echo "Error: IMAGE is required."
        exit 1
    fi

    sed -e "s|{{DEPLOYMENT_NAME}}|$DEPLOYMENT_NAME|g" \
        -e "s|{{NAMESPACE}}|$NAMESPACE|g" \
        -e "s|{{IMAGE}}|$IMAGE|g" \
        -e "s|{{IMAGE_TAG}}|$IMAGE_TAG|g" \
        -e "s|{{CPU_REQUEST}}|$CPU_REQUEST|g" \
        -e "s|{{MEMORY_REQUEST}}|$MEMORY_REQUEST|g" \
        -e "s|{{CPU_LIMIT}}|$CPU_LIMIT|g" \
        -e "s|{{MEMORY_LIMIT}}|$MEMORY_LIMIT|g" \
        -e "s|{{CONTAINER_PORT}}|$CONTAINER_PORT|g" \
        -e "s|{{SERVICE_TYPE}}|$SERVICE_TYPE|g" \
        -e "s|{{SERVICE_PORT}}|$SERVICE_PORT|g" \
        -e "s|{{MIN_REPLICAS}}|$MIN_REPLICAS|g" \
        -e "s|{{MAX_REPLICAS}}|$MAX_REPLICAS|g" \
        -e "s|{{CPU_UTILIZATION}}|$CPU_UTILIZATION|g" \
        "$template" > "$output"
}

setup_kubernetes_files() {
    echo "Setting up Kubernetes files on remote server..."
    remote_exec "mkdir -p $KUBE_DIR || true"  # Ensure the directory exists, ignore failure if it exists
    remote_copy "$DEPLOYMENT_FILE" "$KUBE_DIR/deployment.yaml"
    remote_copy "$SERVICE_FILE" "$KUBE_DIR/service.yaml"
    remote_copy "$HPA_FILE" "$KUBE_DIR/hpa.yaml"
    echo "Kubernetes files transferred successfully."
}

deploy_resources() {
    echo "Deploying Kubernetes resources..."
    remote_exec "kubectl apply -f $KUBE_DIR/deployment.yaml"
    remote_exec "kubectl apply -f $KUBE_DIR/service.yaml"
    remote_exec "kubectl apply -f $KUBE_DIR/hpa.yaml"
    echo "Resources deployed successfully."
}

main() {
    check_dependencies

    read -rp "Enter the deployment name: " DEPLOYMENT_NAME
    read -rp "Enter the namespace (default): " NAMESPACE
    NAMESPACE=${NAMESPACE:-default}
    read -rp "Enter the Docker image name (e.g., nginx): " IMAGE
    read -rp "Enter the Docker image tag (e.g., latest): " IMAGE_TAG
    IMAGE_TAG=${IMAGE_TAG:-latest}
    read -rp "Enter the container port to expose: " CONTAINER_PORT
    read -rp "Enter CPU requests (e.g., 500m): " CPU_REQUEST
    read -rp "Enter memory requests (e.g., 512Mi): " MEMORY_REQUEST
    read -rp "Enter CPU limits (e.g., 1): " CPU_LIMIT
    read -rp "Enter memory limits (e.g., 1Gi): " MEMORY_LIMIT
    read -rp "Enter the service type (ClusterIP/NodePort/LoadBalancer): " SERVICE_TYPE
    read -rp "Enter the service port: " SERVICE_PORT
    read -rp "Enter the minimum number of replicas: " MIN_REPLICAS
    read -rp "Enter the maximum number of replicas: " MAX_REPLICAS
    read -rp "Enter the target CPU utilization (e.g., 50): " CPU_UTILIZATION

    DEPLOYMENT_FILE="/tmp/deployment.yaml"
    SERVICE_FILE="/tmp/service.yaml"
    HPA_FILE="/tmp/hpa.yaml"
    replace_variables "$TEMPLATE_DIR/deployment.yaml" "$DEPLOYMENT_FILE"
    replace_variables "$TEMPLATE_DIR/service.yaml" "$SERVICE_FILE"
    replace_variables "$TEMPLATE_DIR/hpa.yaml" "$HPA_FILE"

    setup_kubernetes_files
    deploy_resources
    install_keda
}

main

##!/bin/bash
#
#set -euo pipefail
#
#REMOTE_HOST="10.144.167.246"  # Replace with the remote server address
#REMOTE_USER="cloud-user"           # Replace with the SSH username
#KUBE_DIR="/tmp/"       # Directory on the remote server for YAML files
#TEMPLATE_DIR="./kubernetes-files"
#PEM_KEY="../practiceserver.pem"
#
#HELM_URL="https://get.helm.sh/helm-v3.16.4-linux-amd64.tar.gz"
#KEDA_HELM_REPO="https://kedacore.github.io/charts"
#KEDA_HELM_CHART="kedacore/keda"
#KEDA_NAMESPACE="keda"
#
#remote_exec() {
#    ssh -i $PEM_KEY "${REMOTE_USER}@${REMOTE_HOST}" "$@"
#}
#
#remote_copy() {
#    scp -i $PEM_KEY "$1" "${REMOTE_USER}@${REMOTE_HOST}:$2"
#}
#
#install_helm() {
#    remote_exec 'helm version > /dev/null 2>&1'
#    if [ $? -eq 0 ]; then
#        echo "Helm is already installed."
#    else
#        echo "Helm is not installed. Installing Helm..."
#        wget $HELM_URL
#        tar -xzvf helm-v3.16.4-linux-amd64.tar.gz
#        chmod +x linux-amd64/helm
#        remote_copy "./linux-amd64/helm" "/tmp/"
#        remote_exec 'sudo mv /tmp/helm /usr/local/bin/ && sudo chmod +x /usr/local/bin/helm'
#        remote_exec 'helm version > /dev/null 2>&1'
#        if [ $? -eq 0 ]; then
#            echo "Helm installed successfully."
#        else
#            error "Helm installation failed"
#        fi
#    fi
#}
#
#check_dependencies() {
#    echo "Checking local dependencies..."
#    for tool in ssh scp sed wget tar; do
#        if ! command -v $tool &>/dev/null; then
#            echo "Error: $tool is not installed. Please install it and try again."
#            exit 1
#        fi
#    done
#    echo "Checking local dependencies..."
#    install_helm
#    echo "All dependencies are installed."
#}
#
#install_keda() {
#    echo "Adding KEDA Helm repository..."
#    remote_exec "helm repo add keda $KEDA_HELM_REPO && helm repo update"
#
#    echo "Installing KEDA using Helm..."
#    remote_exec "helm install keda $KEDA_HELM_CHART --namespace $KEDA_NAMESPACE --create-namespace"
#    remote_exec "kubectl get pods -n $KEDA_NAMESPACE"
#    echo "KEDA installed successfully."
#}
#
#replace_variables() {
#    local template=$1
#    local output=$2
#
#    sed -e "s|{{DEPLOYMENT_NAME}}|$DEPLOYMENT_NAME|g" \
#        -e "s|{{NAMESPACE}}|$NAMESPACE|g" \
#        -e "s|{{IMAGE}}|$IMAGE|g" \
#        -e "s|{{IMAGE_TAG}}|$IMAGE_TAG|g" \
#        -e "s|{{CPU_REQUEST}}|$CPU_REQUEST|g" \
#        -e "s|{{MEMORY_REQUEST}}|$MEMORY_REQUEST|g" \
#        -e "s|{{CPU_LIMIT}}|$CPU_LIMIT|g" \
#        -e "s|{{MEMORY_LIMIT}}|$MEMORY_LIMIT|g" \
#        -e "s|{{CONTAINER_PORT}}|$CONTAINER_PORT|g" \
#        -e "s|{{SERVICE_TYPE}}|$SERVICE_TYPE|g" \
#        -e "s|{{SERVICE_PORT}}|$SERVICE_PORT|g" \
#        -e "s|{{MIN_REPLICAS}}|$MIN_REPLICAS|g" \
#        -e "s|{{MAX_REPLICAS}}|$MAX_REPLICAS|g" \
#        -e "s|{{CPU_UTILIZATION}}|$CPU_UTILIZATION|g" \
#        "$template" > "$output"
#}
#
#setup_kubernetes_files() {
#    echo "Setting up Kubernetes files on remote server..."
#    remote_exec "mkdir -p $KUBE_DIR"
#    remote_copy "$DEPLOYMENT_FILE" "$KUBE_DIR/deployment.yaml"
#    remote_copy "$SERVICE_FILE" "$KUBE_DIR/service.yaml"
#    remote_copy "$HPA_FILE" "$KUBE_DIR/hpa.yaml"
#    echo "Kubernetes files transferred successfully."
#}
#
#deploy_resources() {
#    echo "Deploying Kubernetes resources..."
#    remote_exec "kubectl apply -f $KUBE_DIR/deployment.yaml"
#    remote_exec "kubectl apply -f $KUBE_DIR/service.yaml"
#    remote_exec "kubectl apply -f $KUBE_DIR/hpa.yaml"
#    echo "Resources deployed successfully."
#}
#
#main() {
#    check_dependencies
#
#    read -rp "Enter the deployment name: " DEPLOYMENT_NAME
#    read -rp "Enter the namespace (default): " NAMESPACE
#    NAMESPACE=${NAMESPACE:-default}
#    read -rp "Enter the Docker image name (e.g., nginx): " IMAGE
#    read -rp "Enter the Docker image tag (e.g., latest): " IMAGE_TAG
#    IMAGE_TAG=${IMAGE_TAG:-latest}
#    read -rp "Enter the container port to expose: " CONTAINER_PORT
#    read -rp "Enter CPU requests (e.g., 500m): " CPU_REQUEST
#    read -rp "Enter memory requests (e.g., 512Mi): " MEMORY_REQUEST
#    read -rp "Enter CPU limits (e.g., 1): " CPU_LIMIT
#    read -rp "Enter memory limits (e.g., 1Gi): " MEMORY_LIMIT
#    read -rp "Enter the service type (ClusterIP/NodePort/LoadBalancer): " SERVICE_TYPE
#    read -rp "Enter the service port: " SERVICE_PORT
#    read -rp "Enter the minimum number of replicas: " MIN_REPLICAS
#    read -rp "Enter the maximum number of replicas: " MAX_REPLICAS
#    read -rp "Enter the target CPU utilization (e.g., 50): " CPU_UTILIZATION
#
#    DEPLOYMENT_FILE="/tmp/deployment.yaml"
#    SERVICE_FILE="/tmp/service.yaml"
#    HPA_FILE="/tmp/hpa.yaml"
#    replace_variables "$TEMPLATE_DIR/deployment.yaml" "$DEPLOYMENT_FILE"
#    replace_variables "$TEMPLATE_DIR/service.yaml" "$SERVICE_FILE"
#    replace_variables "$TEMPLATE_DIR/hpa.yaml" "$HPA_FILE"
#
#    setup_kubernetes_files
#    deploy_resources
#    install_keda
#}
#
#main
