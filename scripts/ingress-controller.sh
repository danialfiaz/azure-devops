#!/bin/bash
INGRESS_NAME=$1
ACR_LOGIN_SERVER=$2
NAMESPACE=$3


#acr_registry=<yourregistryname>
# CONTROLLER_REGISTRY=k8s.gcr.io
# CONTROLLER_IMAGE=ingress-nginx
# CONTROLLER_TAG=v0.48.1
# PATCH_REGISTRY=docker.io
# PATCH_IMAGE=jettech/kube-webhook-certgen
# PATCH_TAG=v1.5.1
# DEFAULTBACKEND_REGISTRY=k8s.gcr.io
# DEFAULTBACKEND_IMAGE=defaultbackend-amd64
# DEFAULTBACKEND_TAG=1.5

SOURCE_REGISTRY=registry.k8s.io
CONTROLLER_IMAGE=ingress-nginx/controller
CONTROLLER_TAG=v1.8.1
PATCH_IMAGE=ingress-nginx/kube-webhook-certgen
PATCH_TAG=v20230407
DEFAULTBACKEND_IMAGE=defaultbackend-amd64
DEFAULTBACKEND_TAG=1.5
RESOURCE_GROUP=terraform-rg
CLUSTER_NAME=aks-cluster

# get kubernetes credentials

az aks get-credentials --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME

# create namespace if doesn't exists
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

 # Authenticate with ACR with --expose-token
export HELM_EXPERIMENTAL_OCI=1
TOKEN=$(az acr login --name $ACR_LOGIN_SERVER --expose-token --output tsv --query accessToken)
echo $TOKEN | helm registry login $ACR_LOGIN_SERVER --username 00000000-0000-0000-0000-000000000000 --password-stdin

# Pull Helm Chart from Azure Container Registry & extract files
helm pull oci://$ACR_URL/<pathofregistry> --version 4.7.1 --untar

# Add the ingress-nginx repository
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

# Set variable for ACR location to use for pulling images
ACR_LOGIN_SERVER=$ACR_LOGIN_SERVER

# Use Helm to deploy an NGINX ingress controller
helm install ingress-nginx ingress-nginx/ingress-nginx \
    --version 4.7.1 \
    --namespace $NAMESPACE \
    --set controller.replicaCount=2 \
    --set controller.nodeSelector."kubernetes\.io/os"=linux \
    --set controller.admissionWebhooks.patch.nodeSelector."kubernetes\.io/os"=linux \
    --set controller.service.annotations."service\.beta\.kubernetes\.io/azure-load-balancer-internal"=true \
    --set controller.service.annotations."service\.beta\.kubernetes\.io/azure-load-balancer-health-probe-request-path"=/healthz
