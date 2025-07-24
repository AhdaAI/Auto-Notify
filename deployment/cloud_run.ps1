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

$requiredParams = @('GCP_PROJECT_ID', 'GOOGLE_APPLICATION_CREDENTIALS', 'GCP_DATABASE_COLLECTION', 'GCP_DATABASE_NAME', 'GCP_ARTIFACT_REPO', 'GCP_IMAGE_NAME', 'CLOUD_RUN_NAME')
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

try {
  $jsonContent = Get-Content -Path $envVars['GOOGLE_APPLICATION_CREDENTIALS'] -Raw
  $serviceAccountObject = ConvertFrom-Json -InputObject $jsonContent
  $serviceAccountEmail = $serviceAccountObject.client_email

  if (-not [string]::IsNullOrEmpty($serviceAccountEmail)) {
    Write-Host "Service Account Email: $serviceAccountEmail"
  }
  else {
    Write-Host "Could not find 'client_email' in the JSON file. This might not be a standard service account key file."
  }
}
catch {
  Write-Error "Error reading or parsing the JSON file: $($_.Exception.Message)"
  Write-Error "Please ensure the path is correct and the file is a valid service account JSON key."
}

$activeProject = gcloud config get-value project
if (-not [string]::IsNullOrEmpty($activeProject) -or -not ($activeProject -eq $envVars["GCP_PROJECT_ID"])) {
  write-host "Setting active project to $($envVars["GCP_PROJECT_ID"])"
  gcloud config set project $envVars["GCP_PROJECT_ID"]
}
else {
  Write-Host "Active GCP project ID [ $activeProject ]"
}

$activeAccount = gcloud config list account --format="value(core.account)"
Write-Host "Currently active gcloud account: $activeAccount"
$requiredServices = @("run.googleapis.com", "cloudbuild.googleapis.com", "cloudscheduler.googleapis.com")
foreach ($param in $requiredServices) {
  Write-Host "[ $activeProject ] -- Enabling gcloud service $param"
  gcloud services enable $param
}

# --- Artifact Registry ---
Write-Host "[ $activeProject ] Checking repo existence..."
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
  Write-Warning "[ $activeProject ] Artifact Registry repository '$repoName' not found."
  Write-Host "[ $activeProject ] Creating Artifact Registry repository '$repoName'..."
  try {
    gcloud artifacts repositories create $repoName `
      --repository-format=docker `
      --location=$region `
      --project=$projId `
      --description="Docker repository for Cloud Run Job images"

    Write-Host "[ $activeProject ] Artifact Registry repository '$repoName' created successfully."
  }
  catch {
    Write-Error "[ $activeProject ] Failed to create Artifact Registry repository '$repoName': $($_.Exception.Message)"
    exit 1 # Exit script on failure
  }
}
else {
  Write-Host "[ $activeProject ] '$repoName' repository exists."
}


Write-Host "[ $activeProject ] Building docker image and pushing to artifact registry..."
gcloud builds submit . `
  --tag $region-docker.pkg.dev/$projId/$repoName/"$imageName":latest `
  --project $projId

if ($LASTEXITCODE -ne 0) {
  throw "[ $activeProject ] gcloud encounter an error (exit code: $LASTEXITCODE)."
  exit 1
}

# --- Cloud Run Jobs ---
$runName = $envVars['CLOUD_RUN_NAME']
Write-Host "[ $activeProject ] Deploying to cloud run jobs..."
$deployCommands = @(
  "gcloud run jobs deploy $runName",
  "--image $region-docker.pkg.dev/$projId/$repoName/$imageName",
  "--region $region",
  "--project $projId",
  "--service-account $serviceAccountEmail",
  "--tasks 1",
  "--max-retries 0"
)
$fullCommand = $deployCommands -join " "
write-host "[ $activeProject ] Executing: [ $fullCommand ]"
Invoke-Expression $fullCommand

if ($LASTEXITCODE -ne 0) {
  throw "[ $activeProject ] ERROR: Something went wrong when invoking $fullCommand"
  exit 1
}

# --- Scheduler ---
$cloudRunName = $envVars['CLOUD_RUN_NAME']
$cronJobName = "auto-notify"
$cronSchedule = "10 23 * * *"
$cronJobUri = "https://$region-run.googleapis.com/apis/run.googleapis.com/v1/projects/$projtId/locations/$region/jobs/$cloudRunName`:run"
if ([string]::IsNullOrEmpty($envVars['GCP_SCHEDULE_LOCATION'])) {
  $cloudSchedulerLocation = "asia-southeast2"
  Write-Host "CLOUD_SCHEDULER_LOCATION not set. Defaulting to '$cloudSchedulerLocation'."
}
else {
  $cloudSchedulerLocation = $envVars['GCP_SCHEDULE_LOCATION']
  Write-Host "Using CLOUD_SCHEDULER_LOCATION from environment: '$cloudSchedulerLocation'."
}

Write-Host "[ $activeProject ] Configuring Cloud Scheduler [ $cronJobName ]"
Write-Host "[ $activeProject ] Target URI: $cronJobUri"
Write-Host "[ $activeProject ] Schedule: $cronSchedule"

$schedulerCommands = @(
  "gcloud scheduler jobs create http $cronJobName",
  "--schedule ""$cronSchedule""", # Double-quotes inside the string must be escaped
  "--uri ""$cronJobUri""",         # Double-quotes inside the string must be escaped
  "--oauth-service-account-email ""$serviceAccountEmail""",
  "--oauth-token-scope ""https://www.googleapis.com/auth/cloud-platform""", # Required OAuth scope
  "--http-method POST",            # Cloud Run Jobs are triggered via HTTP POST
  "--time-zone ""Asia/Jakarta""",  # IMPORTANT: Set this to your desired timezone (e.g., "America/New_York", "Europe/London")
  "--project ""$projId""",       # Explicitly specify the project
  "--location ""$cloudSchedulerLocation"""
)

# Join the array elements into a single command string
$fullSchedulerCommand = $schedulerCommands -join ' '
Write-Host "Executing Cloud Scheduler command:`n$fullSchedulerCommand"

Invoke-Expression -Command $fullSchedulerCommand
if ($LASTEXITCODE -ne 0) {
  Write-Error "Failed to configure Cloud Scheduler Job '$cronJobName': $($_.Exception.Message)"
  Write-Error "Please ensure the service account '$serviceAccountEmail' has 'roles/run.invoker' permission on Cloud Run Job '$cloudRunJobName'."
  exit 1
}
Write-Host "Cloud Scheduler Job '$cronJobName' configured successfully!"
Write-Host "It will run according to schedule '$cronSchedule' in timezone 'Asia/Jakarta'."