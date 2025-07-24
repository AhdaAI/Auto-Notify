# ==============================================================================
# PowerShell : Checking for required program and variable
# ==============================================================================

Write-Host "--- Checking for gcloud installation ---"
Write-Host "`nAttempting to run 'gcloud --version'..."
try {
  $gcloudVersion = & gcloud --version 2>&1
  if ($LASTEXITCODE -eq 0) {
    Write-Host "SUCCESS: 'gcloud' command found in PATH."
    Write-Host "gcloud version output:"
    $gcloudVersion | ForEach-Object { Write-Host "  $_" }
    $gcloudInstalled = $true
  }
  else {
    Write-Host "INFO: 'gcloud' command not found in PATH or returned an error. (Exit Code: $LASTEXITCODE)"
    $gcloudInstalled = $false
  }
}
catch {
  Write-Host "ERROR: Could not execute 'gcloud --version'. $($_.Exception.Message)"
  $gcloudInstalled = $false
}

if (-not $gcloudInstalled) {
  Write-Host "Please check [ https://cloud.google.com/sdk/docs/install ]"
}

Write-Host "`n--- gcloud Check Complete ---"
Write-Host "`n--- Checking Env Variable ---`n"

$envVars = @{}
$envFilePath = ".\.env.deploy"
if (Test-Path $envFilePath) {
  Get-Content $envFilePath | ForEach-Object {
    # Skip empty lines and comments
    if ($_ -and -not $_.StartsWith("#")) {
      # Split the line into key and value
      $parts = $_ -split '=', 2
      if ($parts.Count -eq 2) {
        $key = $parts[0].Trim()
        $value = $parts[1].Trim()
        $envVars[$key] = $value
      }
    }
  }
}
else {
  Write-Warning "The .env file was not found at path: $envFilePath"
}

$requiredParams = @('GCP_PROJECT_ID', 'GOOGLE_APPLICATION_CREDENTIALS', 'GCP_DATABASE_COLLECTION', 'GCP_DATABASE_NAME', 'GCP_ARTIFACT_REPO', 'GCP_IMAGE_NAME')
foreach ($param in $requiredParams) {
  if (-not $envVars.ContainsKey($param) -or [string]::IsNullOrWhiteSpace($envVars[$param])) {
    $inputValue = Read-Host "Enter value for $param"
    if ([string]::IsNullOrWhiteSpace($inputValue)) {
      Write-Error "$param is required. Exiting script."
      exit 1
    }
    $envVars[$param] = $inputValue
  }
  Write-Host "-- $param ✔️"
}

if (-not $envVars.ContainsKey("GCP_REGION") -or [string]::IsNullOrWhiteSpace($envVars["GCP_REGION"])) {
  write-host "No GCP_REGION provided, defaulting to asia-southeast2"
  $envVars["GCP_REGION"] = "asia-southeast2"
}

Write-Host "`n--- Env Variable Check Complete ---`n"

# ==============================================================================
# PowerShell : Running gcloud command to deploy and build
# Artifact Registry : GCP equivalent to docker hub
# Cloud run : Container base deployment (I only use Cloud run jobs)
# ==============================================================================

write-host "Setting active project to $($envVars["GCP_PROJECT_ID"])"
gcloud config set project $envVars["GCP_PROJECT_ID"]
$activeProject = gcloud config get-value project

if (-not [string]::IsNullOrEmpty($activeProject)) {
  Write-Host "Active GCP project ID [ $activeProject ]"
}
else {
  Write-Host "No active GCP project is set in your gcloud configuration."
  Write-Host "You might need to run 'gcloud init' or 'gcloud config set project YOUR_PROJECT_ID'."
}

$requiredServices = @("run.googleapis.com", "cloudbuild.googleapis.com")
foreach ($param in $requiredServices) {
  Write-Host "-- Enabling gcloud service $param"
  gcloud services enable $param
}

# --- Artifact Registry ---
Write-Host "Checking repo existence..."
$repoName = $envVars['GCP_ARTIFACT_REPO']
$imageName = $envVars['GCP_IMAGE_NAME']
$region = $envVars['GCP_REGION']
$projId = $envVars['GCP_PROJECT_ID']

# Attempt to describe the repository. If it doesn't exist, this command will fail.
gcloud artifacts repositories describe $repoName `
  --location=$region `
  --project=$projId `
  --format="value(name)"

if ($LASTEXITCODE -ne 0) {
  # If the describe command fails, it means the repository does not exist
  Write-Warning "Artifact Registry repository '$repoName' not found."
  Write-Host "Creating Artifact Registry repository '$repoName'..."
  try {
    gcloud artifacts repositories create $repoName `
      --repository-format=docker `
      --location=$region `
      --project=$projId `
      --description="Docker repository for Cloud Run Job images"

    Write-Host "Artifact Registry repository '$repoName' created successfully."
  }
  catch {
    Write-Error "Failed to create Artifact Registry repository '$repoName': $($_.Exception.Message)"
    exit 1 # Exit script on failure
  }
}
else {
  Write-Host "'$repoName' repository exists."
}


Write-Host "Building docker image and pushing to artifact registry..."
gcloud builds submit ./deployment `
  --tag $region-docker.pkg.dev/$projId/$repoName/$imageName:latest `
  --project $projId

if ($LASTEXITCODE -ne 0) {
  throw "gcloud encounter an error (exit code: $LASTEXITCODE)."
  exit 1
}

# --- Cloud Run Jobs ---
$runName = $envVars['CLOUD_RUN_NAME']
Write-Host "Deploying to cloud run jobs..."
$deployCommands = @(
  "gcloud run jobs deploy $runName",
  "--image $region-docker.pkg.dev/$projId/$repoName/$imageName",
  "--region $region",
  "--project $projId",
  "--tasks 1",
  "--max-retries 0"
)
$fullCommand = $deployCommands -join " "
write-host "Executing: [ $fullCommand ]"
Invoke-Expression $fullCommand

# --- Scheduler ---