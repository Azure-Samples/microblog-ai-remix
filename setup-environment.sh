#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Microblog AI with Azure Container Apps Environment Setup ===${NC}"
echo -e "${YELLOW}This script will configure the environment and create resources in Azure${NC}"

# Check if azd is installed
if ! command -v azd &> /dev/null; then
    echo -e "${RED}'azd' command not found. Please install the Azure Developer CLI.${NC}"
    echo "You can install it using: npm install -g @azure/static-web-apps-cli"
    exit 1
fi

# Check if logged in to Azure
if ! az account show &> /dev/null; then
    echo -e "${YELLOW}You are not logged in to Azure. Starting login...${NC}"
    az login
fi

# Generate a unique suffix
TIMESTAMP=$(date +%Y%m%d%H%M%S)
RANDOM_CHARS=$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 4 | head -n 1)
UNIQUE_SUFFIX="${TIMESTAMP:(-6)}-${RANDOM_CHARS}"

# Set environment name
ENV_NAME="microblog-${UNIQUE_SUFFIX}"
echo -e "${GREEN}Creating environment '${ENV_NAME}'...${NC}"
# Create the environment and automatically respond "yes" to any prompts
echo "yes" | azd env new $ENV_NAME

# Prompt for Azure OpenAI information
echo -e "${YELLOW}Please provide your Azure OpenAI details:${NC}"
read -p "Azure OpenAI API Key: " OPENAI_KEY
read -p "Azure OpenAI Endpoint (e.g., https://your-resource.openai.azure.com/): " OPENAI_ENDPOINT
read -p "Azure OpenAI Deployment Name (e.g., gpt-4o): " OPENAI_DEPLOYMENT
OPENAI_API_VERSION="2024-08-01-preview"

# Configure variables in azd environment
echo -e "${GREEN}Configuring environment variables...${NC}"
azd env set AZURE_LOCATION "eastus"
azd env set AZURE_OPENAI_ENDPOINT "$OPENAI_ENDPOINT" 
azd env set AZURE_OPENAI_DEPLOYMENT_NAME "$OPENAI_DEPLOYMENT"
azd env set AZURE_OPENAI_API_VERSION "$OPENAI_API_VERSION"
azd env set CREATE_NEW_OPENAI_RESOURCE "false"
azd env set MANAGED_IDENTITY "false"

# Configure the secret variable
echo -e "${GREEN}Setting OpenAI API Key as a secret...${NC}"
azd env set-secret AZURE_OPENAI_API_KEY "$OPENAI_KEY" --no-prompt

# Modify Dockerfile to use npm install instead of npm ci
echo -e "${YELLOW}Modifying Dockerfile to use npm install...${NC}"
sed -i 's/npm ci/npm install/g' Dockerfile

# Generate .env file
echo -e "${GREEN}Generating .env file...${NC}"
cat > .env << EOF
# Azure OpenAI settings environment variables
AZURE_OPENAI_API_KEY=$OPENAI_KEY
AZURE_OPENAI_ENDPOINT=$OPENAI_ENDPOINT
AZURE_OPENAI_DEPLOYMENT_NAME=$OPENAI_DEPLOYMENT
AZURE_OPENAI_API_VERSION=$OPENAI_API_VERSION
