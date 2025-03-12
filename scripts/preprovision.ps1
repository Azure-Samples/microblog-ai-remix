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

# Load variables from .env if it exists
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

# Set a default location if not already set
$Location = azd env get AZURE_LOCATION 2>$null
if ([string]::IsNullOrEmpty($Location)) {
    Write-Host "Setting default AZURE_LOCATION to eastus"
    azd env set AZURE_LOCATION "eastus"
}

# Set OpenAI creation flag if specified
$CreateNewOpenAI = azd env get CREATE_NEW_OPENAI_RESOURCE 2>$null
if ([string]::IsNullOrEmpty($CreateNewOpenAI)) {
    Write-Host "Setting default createNewOpenAIResource parameter to false"
    azd env set CREATE_NEW_OPENAI_RESOURCE "false"
}

# Set managed identity flag if specified
$ManagedIdentity = azd env get MANAGED_IDENTITY 2>$null
if ([string]::IsNullOrEmpty($ManagedIdentity)) {
    Write-Host "Setting default managedIdentity parameter to false"
    azd env set MANAGED_IDENTITY "false"
}

Write-Host "Pre-provisioning tasks completed successfully."