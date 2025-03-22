#!/bin/bash
set -e

# Generate a unique suffix for environment names
TIMESTAMP=$(date +%Y%m%d%H%M%S)
RANDOM_CHARS=$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 4 | head -n 1)
UNIQUE_SUFFIX="${TIMESTAMP:(-6)}-${RANDOM_CHARS}"

# Get current env name or create default
CURRENT_ENV_NAME=$(azd env get-name 2>/dev/null || echo "")
if [ -z "$CURRENT_ENV_NAME" ]; then
  DEFAULT_ENV_NAME="microblog-${UNIQUE_SUFFIX}"
  echo "Setting unique environment name: ${DEFAULT_ENV_NAME}"
  echo "yes" | azd env new $DEFAULT_ENV_NAME
fi

# Load variables from .env if it exists
if [ -f .env ]; then
  echo "Loading environment variables from .env file..."
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" =~ ^# ]] && continue
    [[ -z "$line" ]] && continue
    if [[ "$line" =~ ^([^=]+)=(.*)$ ]]; then
      VAR_NAME="${BASH_REMATCH[1]}"
      VAR_VALUE="${BASH_REMATCH[2]}"
      VAR_VALUE="${VAR_VALUE%\"}"
      VAR_VALUE="${VAR_VALUE#\"}"
      VAR_VALUE="${VAR_VALUE%\'}"
      VAR_VALUE="${VAR_VALUE#\'}"
      
      if [[ "$VAR_NAME" != *"KEY"* ]] && [[ "$VAR_NAME" != *"SECRET"* ]] && [[ "$VAR_NAME" != *"PASSWORD"* ]]; then
        echo "Setting $VAR_NAME from .env file"
        azd env set "$VAR_NAME" "$VAR_VALUE"
      else
        echo "Setting secret $VAR_NAME from .env file"
        azd env set-secret "$VAR_NAME" "$VAR_VALUE"
      fi
    fi
  done < .env
  echo "Environment variables from .env file have been loaded successfully."
else
  echo "No .env file found in the project root."
fi

# Set a default location if not already set
if [ -z "$(azd env get AZURE_LOCATION 2>/dev/null)" ]; then
  echo "Setting default AZURE_LOCATION to eastus"
  azd env set AZURE_LOCATION "eastus"
fi

# Set OpenAI creation flag if specified
if [ -z "$(azd env get CREATE_NEW_OPENAI_RESOURCE 2>/dev/null)" ]; then
  echo "Setting default createNewOpenAIResource parameter to false"
  azd env set CREATE_NEW_OPENAI_RESOURCE "false"
fi

# Set managed identity flag if specified
if [ -z "$(azd env get MANAGED_IDENTITY 2>/dev/null)" ]; then
  echo "Setting default managedIdentity parameter to false"
  azd env set MANAGED_IDENTITY "false"
fi

echo "Pre-provisioning tasks completed successfully."