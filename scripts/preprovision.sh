#!/bin/bash
set -e

# Generate a unique suffix based on timestamp and random characters
TIMESTAMP=$(date +%Y%m%d%H%M%S)
RANDOM_CHARS=$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 4 | head -n 1)
UNIQUE_SUFFIX="${TIMESTAMP:(-6)}-${RANDOM_CHARS}"

# Get current environment name or use default
CURRENT_ENV_NAME=$(azd env get-name 2>/dev/null || echo "")
if [ -z "$CURRENT_ENV_NAME" ]; then
  # Set a default environment name with unique suffix
  DEFAULT_ENV_NAME="microblog-${UNIQUE_SUFFIX}"
  echo "Setting unique environment name: ${DEFAULT_ENV_NAME}"
  echo "yes" | azd env new $DEFAULT_ENV_NAME
fi

# Load variables from .env file if it exists
if [ -f .env ]; then
  echo "Loading environment variables from .env file..."
  
  # Read .env file line by line
  while IFS= read -r line || [[ -n "$line" ]]; do
    # Skip comments and empty lines
    [[ "$line" =~ ^#.*$ ]] && continue
    [[ -z "$line" ]] && continue
    
    # Extract variable name and value
    if [[ "$line" =~ ^([^=]+)=(.*)$ ]]; then
      VAR_NAME="${BASH_REMATCH[1]}"
      VAR_VALUE="${BASH_REMATCH[2]}"
      
      # Remove quotes if present
      VAR_VALUE="${VAR_VALUE%\"}"
      VAR_VALUE="${VAR_VALUE#\"}"
      VAR_VALUE="${VAR_VALUE%\'}"
      VAR_VALUE="${VAR_VALUE#\'}"
      
      # Set the variable in azd environment - SKIP secrets from .env
      # This is to avoid Key Vault interaction issues
      if [[ "$VAR_NAME" != *"KEY"* ]] && [[ "$VAR_NAME" != *"SECRET"* ]] && [[ "$VAR_NAME" != *"PASSWORD"* ]]; then
        echo "Setting $VAR_NAME from .env file"
        azd env set "$VAR_NAME" "$VAR_VALUE"
      else
        echo "Skipping sensitive variable $VAR_NAME (will be set during azd up prompt)"
      fi
    fi
  done < .env
  
  echo "Environment variables from .env file have been loaded successfully."
else
  echo "No .env file found in the project root."
fi

# Map environment variables to the expected Azure variables if they use different naming conventions
# This ensures that variables from .env are mapped to what Azure templates expect

# Map OpenAI variables if they exist in different format
if [ -n "$(azd env get OPENAI_ENDPOINT 2>/dev/null)" ] && [ -z "$(azd env get AZURE_OPENAI_ENDPOINT 2>/dev/null)" ]; then
  echo "Mapping OPENAI_ENDPOINT to AZURE_OPENAI_ENDPOINT"
  azd env set AZURE_OPENAI_ENDPOINT "$(azd env get OPENAI_ENDPOINT)"
fi

if [ -n "$(azd env get OPENAI_DEPLOYMENT_NAME 2>/dev/null)" ] && [ -z "$(azd env get AZURE_OPENAI_DEPLOYMENT_NAME 2>/dev/null)" ]; then
  echo "Mapping OPENAI_DEPLOYMENT_NAME to AZURE_OPENAI_DEPLOYMENT_NAME"
  azd env set AZURE_OPENAI_DEPLOYMENT_NAME "$(azd env get OPENAI_DEPLOYMENT_NAME)"
fi

# Set a default location if not already set
if [ -z "$(azd env get AZURE_LOCATION 2>/dev/null)" ]; then
  echo "Setting default AZURE_LOCATION to eastus"
  azd env set AZURE_LOCATION "eastus"
fi

# Apply settings from .env to Bicep parameters
if [ -n "$(azd env get MIN_REPLICAS 2>/dev/null)" ]; then
  echo "Setting minReplicas parameter"
  azd env set BICEP_MIN_REPLICAS "$(azd env get MIN_REPLICAS)"
fi

if [ -n "$(azd env get MAX_REPLICAS 2>/dev/null)" ]; then
  echo "Setting maxReplicas parameter"
  azd env set BICEP_MAX_REPLICAS "$(azd env get MAX_REPLICAS)"
fi

if [ -n "$(azd env get MANAGED_IDENTITY 2>/dev/null)" ]; then
  echo "Setting managedIdentity parameter"
  azd env set MANAGED_IDENTITY "$(azd env get MANAGED_IDENTITY)"
else
  echo "Setting default managedIdentity parameter to false"
  azd env set MANAGED_IDENTITY "false"
fi

# Set OpenAI resource creation flag if specified
if [ -n "$(azd env get CREATE_NEW_OPENAI_RESOURCE 2>/dev/null)" ]; then
  echo "Setting createNewOpenAIResource parameter"
  azd env set CREATE_NEW_OPENAI_RESOURCE "$(azd env get CREATE_NEW_OPENAI_RESOURCE)"
else
  echo "Setting default createNewOpenAIResource parameter to false"
  azd env set CREATE_NEW_OPENAI_RESOURCE "false"
fi

# Set API version if not already set
if [ -z "$(azd env get AZURE_OPENAI_API_VERSION 2>/dev/null)" ]; then
  echo "Setting default AZURE_OPENAI_API_VERSION to 2024-08-01-preview"
  azd env set AZURE_OPENAI_API_VERSION "2024-08-01-preview"
fi

echo "Pre-provisioning tasks completed successfully."