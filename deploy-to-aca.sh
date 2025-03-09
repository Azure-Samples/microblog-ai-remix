#!/bin/bash
set -e

# Load environment variables from .env file
if [ -f .env]; then
  echo "Loading environment variables from .env file..."
  export $(grep -v '^#' .env | xargs)
else
  echo ".env file not found. Please create a .env file with the required variables."
  exit 1
fi

# Check if required environment variables are set
for var in AZURE_OPENAI_API_KEY AZURE_OPENAI_ENDPOINT AZURE_OPENAI_DEPLOYMENT_NAME AZURE_OPENAI_API_VERSION; do
  if [ -z "${!var}" ]; then
    echo "Error: $var is not set in the .env file."
    exit 1
  fi
done

# Configuration Variables
RESOURCE_GROUP="microblog-ai-remix-rg"
LOCATION="eastus2"
ACR_NAME="microblogairemixacr"
CONTAINER_APP_ENV="microblog-ai-remix-env"
CONTAINER_APP_NAME="microblog-ai-remix-app"
IMAGE_NAME="microblog-ai-remix"
IMAGE_TAG="latest"

# Step 1: Build the Docker image locally
echo "Building Docker image..."
docker build -t $IMAGE_NAME:$IMAGE_TAG .

# Step 2: Login to Azure if not already logged in
echo "Logging in to Azure..."
az account show &> /dev/null || az login

# Step 3: Create a Resource Group if it doesn't exist
echo "Creating Resource Group if it doesn't exist..."
az group create --name $RESOURCE_GROUP --location $LOCATION

# Step 4: Create an Azure Container Registry if it doesn't exist
echo "Creating Azure Container Registry if it doesn't exist..."
az acr create --resource-group $RESOURCE_GROUP --name $ACR_NAME --sku Basic || true
az acr update --name $ACR_NAME --admin-enabled true

# Step 5: Login to Azure Container Registry
echo "Logging into ACR..."
az acr login --name $ACR_NAME

# Step 6: Tag and push the Docker image to ACR
echo "Tagging and pushing image to ACR..."
docker tag $IMAGE_NAME:$IMAGE_TAG $ACR_NAME.azurecr.io/$IMAGE_NAME:$IMAGE_TAG
docker push $ACR_NAME.azurecr.io/$IMAGE_NAME:$IMAGE_TAG

# Step 7: Create a Container App Environment if it doesn't exist
echo "Creating Container App Environment if it doesn't exist..."
az containerapp env create \
  --name $CONTAINER_APP_ENV \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION || true

# Step 8: Get ACR credentials
echo "Getting ACR credentials..."
ACR_USERNAME=$ACR_NAME
ACR_PASSWORD=$(az acr credential show --name $ACR_NAME --query "passwords[0].value" -o tsv)

# Step 9: Create or update the Container App
echo "Checking if Container App exists..."
CONTAINER_APP_EXISTS=$(az containerapp show --name $CONTAINER_APP_NAME --resource-group $RESOURCE_GROUP --query name 2>/dev/null || echo "false")

if [ "$CONTAINER_APP_EXISTS" == "false" ]; then
  echo "Creating new Container App..."
  az containerapp create \
    --name $CONTAINER_APP_NAME \
    --resource-group $RESOURCE_GROUP \
    --environment $CONTAINER_APP_ENV \
    --image $ACR_NAME.azurecr.io/$IMAGE_NAME:$IMAGE_TAG \
    --registry-server $ACR_NAME.azurecr.io \
    --registry-username $ACR_USERNAME \
    --registry-password $ACR_PASSWORD \
    --target-port 80 \
    --ingress external \
    --env-vars AZURE_OPENAI_API_KEY=$AZURE_OPENAI_API_KEY \
            AZURE_OPENAI_ENDPOINT=$AZURE_OPENAI_ENDPOINT \
            AZURE_OPENAI_DEPLOYMENT_NAME=$AZURE_OPENAI_DEPLOYMENT_NAME \
            AZURE_OPENAI_API_VERSION=$AZURE_OPENAI_API_VERSION
else
  echo "Updating existing Container App..."
  az containerapp update \
    --name $CONTAINER_APP_NAME \
    --resource-group $RESOURCE_GROUP \
    --image $ACR_NAME.azurecr.io/$IMAGE_NAME:$IMAGE_TAG
fi

# Step 10: Configure autoscaling if needed
echo "Configuring autoscaling..."
az containerapp scale rule add \
  --name $CONTAINER_APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --type http \
  --http-concurrency 20 \
  --min-replicas 1 \
  --max-replicas 10

# Step 11: Get the application URL
echo "Getting the application URL..."
CONTAINER_APP_URL=$(az containerapp show \
  --name $CONTAINER_APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --query properties.configuration.ingress.fqdn -o tsv)

echo "Deployment completed successfully!"
echo "Your application is available at: https://$CONTAINER_APP_URL"
