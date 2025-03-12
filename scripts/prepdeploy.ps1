# PowerShell script for Windows environments

# Stop on errors
$ErrorActionPreference = "Stop"

# Get resource information
$RESOURCE_GROUP = az config get --query "defaults.group" -o tsv
$ACR_NAME = az resource list --resource-group $RESOURCE_GROUP --resource-type Microsoft.ContainerRegistry/registries --query "[0].name" -o tsv

if ([string]::IsNullOrEmpty($ACR_NAME)) {
  Write-Error "No Azure Container Registry found in resource group $RESOURCE_GROUP"
  exit 1
}

Write-Host "Building and pushing Docker image to $ACR_NAME..."

# Login to ACR
az acr login --name $ACR_NAME

# Build Docker image
$IMAGE_NAME = "microblog-ai-remix"
$IMAGE_TAG = "latest"

Write-Host "Building Docker image ${IMAGE_NAME}:${IMAGE_TAG}..."
docker build -t "${IMAGE_NAME}:${IMAGE_TAG}" .

# Tag and push to ACR
$ACR_LOGINSERVER = az acr show --name $ACR_NAME --query "loginServer" -o tsv
docker tag "${IMAGE_NAME}:${IMAGE_TAG}" "${ACR_LOGINSERVER}/${IMAGE_NAME}:${IMAGE_TAG}"

Write-Host "Pushing image to ${ACR_LOGINSERVER}/${IMAGE_NAME}:${IMAGE_TAG}..."
docker push "${ACR_LOGINSERVER}/${IMAGE_NAME}:${IMAGE_TAG}"

Write-Host "Image pushed successfully to ACR"