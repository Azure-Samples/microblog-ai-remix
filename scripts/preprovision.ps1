# PowerShell script for Windows environments
$ErrorActionPreference = "Stop"

# Generate a unique suffix based on timestamp and random characters
$Timestamp = Get-Date -Format "yyyyMMddHHmmss"
$RandomChars = -join ((65..90) + (97..122) | Get-Random -Count 4 | ForEach-Object { [char]$_ })
$UniqueSuffix = "$Timestamp-$RandomChars"

# Get current environment name or use default
try {
    $CurrentEnvName = azd env get-name
}
catch {
    $CurrentEnvName = ""
}

if ([string]::IsNullOrEmpty($CurrentEnvName)) {
    # Set a default environment name with unique suffix
    $DefaultEnvName = "microblog-$UniqueSuffix"
    Write-Host "Setting unique environment name: $DefaultEnvName"
    azd env new $DefaultEnvName -y
}

# Load variables from .env file if it exists
if (Test-Path -Path ".env") {
    Write-Host "Loading environment variables from .env file..."
    
    # Read .env file line by line
    $envContent = Get-Content -Path ".env"
    foreach ($line in $envContent) {
        # Skip comments and empty lines
        if ($line.StartsWith('#') -or [string]::IsNullOrWhiteSpace($line)) {
            continue
        }
        
        # Extract variable name and value
        if ($line -match '([^=]+)=(.*)') {
            $VarName = $matches[1].Trim()
            $VarValue = $matches[2].Trim()
            
            # Remove quotes if present
            $VarValue = $VarValue -replace '^["'']|["'']$', ''
            
            # Set the variable in azd environment
            Write-Host "Setting $VarName from .env file"
            
            # Check if it's a sensitive variable that might contain a key/password
            if ($VarName -match 'KEY|SECRET|PASSWORD') {
                azd env set-secret $VarName $VarValue
            }
            else {
                azd env set $VarName $VarValue
            }
        }
    }
    
    Write-Host "Environment variables from .env file have been loaded successfully."
}
else {
    Write-Host "No .env file found in the project root."
}

# Map environment variables to the expected Azure variables if they use different naming conventions
# This ensures that variables from .env are mapped to what Azure templates expect

# Map OpenAI variables if they exist in different format
$OpenAIApiKey = azd env get OPENAI_API_KEY 2>$null
$AzureOpenAIApiKey = azd env get AZURE_OPENAI_API_KEY 2>$null

if (-not [string]::IsNullOrEmpty($OpenAIApiKey) -and [string]::IsNullOrEmpty($AzureOpenAIApiKey)) {
    Write-Host "Mapping OPENAI_API_KEY to AZURE_OPENAI_API_KEY"
    azd env set-secret AZURE_OPENAI_API_KEY (azd env get-secret OPENAI_API_KEY)
}

$OpenAIEndpoint = azd env get OPENAI_ENDPOINT 2>$null
$AzureOpenAIEndpoint = azd env get AZURE_OPENAI_ENDPOINT 2>$null

if (-not [string]::IsNullOrEmpty($OpenAIEndpoint) -and [string]::IsNullOrEmpty($AzureOpenAIEndpoint)) {
    Write-Host "Mapping OPENAI_ENDPOINT to AZURE_OPENAI_ENDPOINT"
    azd env set AZURE_OPENAI_ENDPOINT (azd env get OPENAI_ENDPOINT)
}

$OpenAIDeploymentName = azd env get OPENAI_DEPLOYMENT_NAME 2>$null
$AzureOpenAIDeploymentName = azd env get AZURE_OPENAI_DEPLOYMENT_NAME 2>$null

if (-not [string]::IsNullOrEmpty($OpenAIDeploymentName) -and [string]::IsNullOrEmpty($AzureOpenAIDeploymentName)) {
    Write-Host "Mapping OPENAI_DEPLOYMENT_NAME to AZURE_OPENAI_DEPLOYMENT_NAME"
    azd env set AZURE_OPENAI_DEPLOYMENT_NAME (azd env get OPENAI_DEPLOYMENT_NAME)
}

# Set a default location if not already set
$Location = azd env get AZURE_LOCATION 2>$null
if ([string]::IsNullOrEmpty($Location)) {
    Write-Host "Setting default AZURE_LOCATION to eastus"
    azd env set AZURE_LOCATION "eastus"
}

# Apply settings from .env to Bicep parameters
$MinReplicas = azd env get MIN_REPLICAS 2>$null
if (-not [string]::IsNullOrEmpty($MinReplicas)) {
    Write-Host "Setting minReplicas parameter"
    azd env set BICEP_MIN_REPLICAS $MinReplicas
}

$MaxReplicas = azd env get MAX_REPLICAS 2>$null
if (-not [string]::IsNullOrEmpty($MaxReplicas)) {
    Write-Host "Setting maxReplicas parameter"
    azd env set BICEP_MAX_REPLICAS $MaxReplicas
}

$ManagedIdentity = azd env get MANAGED_IDENTITY 2>$null
if (-not [string]::IsNullOrEmpty($ManagedIdentity)) {
    Write-Host "Setting managedIdentity parameter"
    azd env set MANAGED_IDENTITY $ManagedIdentity
}
else {
    Write-Host "Setting default managedIdentity parameter to false"
    azd env set MANAGED_IDENTITY "false"
}

# Set OpenAI resource creation flag if specified
$CreateNewOpenAI = azd env get CREATE_NEW_OPENAI_RESOURCE 2>$null
if (-not [string]::IsNullOrEmpty($CreateNewOpenAI)) {
    Write-Host "Setting createNewOpenAIResource parameter"
    azd env set CREATE_NEW_OPENAI_RESOURCE $CreateNewOpenAI
}
else {
    Write-Host "Setting default createNewOpenAIResource parameter to false"
    azd env set CREATE_NEW_OPENAI_RESOURCE "false"
}

Write-Host "Pre-provisioning tasks completed successfully."