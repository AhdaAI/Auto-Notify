# ==============================================================================
# PowerShell : Checking for required program and variable
# ==============================================================================
Import-Module -Name powershell-yaml

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

$requiredParams = @('GCP_PROJECT_ID', 'GOOGLE_APPLICATION_CREDENTIALS', 'GCP_DATABASE_COLLECTION', 'GCP_DATABASE_NAME', 'CLOUD_RUN_NAME')
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

$cacheFile = ".cache.yaml"
$cacheContent = "GCP:" | Out-String
$cachedStoredRaw = Get-Content $cacheFile -Raw 2>$null
if ($cachedStoredRaw) {
  $cachedStoredContent = ConvertFrom-Yaml $cachedStoredRaw
}

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
Write-Host "`n[ $activeProject ] ------- GCP Services -------"
$requiredServices = @("run.googleapis.com", "cloudbuild.googleapis.com", "cloudscheduler.googleapis.com")
$cacheContent += "  services:`n"
$services = $cachedStoredContent.GCP.services 2>$null
foreach ($service in $requiredServices) {
  if (-not $cachedStoredRaw) {
    Write-Host "[ $activeProject ] -- Enabling gcloud service $service"
    gcloud services enable $service
    $cacheContent += "    - $service`n"
    continue
  }

  if ((-not $services) -or (-not $service -in $services)) {
    Write-Host "[ $activeProject ] -- Enabling gcloud service $service"
    gcloud services enable $service
    $cacheContent += "    - $service`n"
    continue
  }
  
  Write-Host "[ $activeProject ] -- $service Enabled [CACHED]"
  $cacheContent += "    - $service`n"
}
Write-Host "[ $activeProject ] ----- Services Enabled -----`n"

$gitCommitSha = (git rev-parse --short HEAD).Trim()
$deployedImageUrl = (gcloud run jobs describe $envVars['CLOUD_RUN_NAME'] `
    --region $envVars['GCP_REGION'] `
    --format="value(image)").trim()
$deployedImageTag = ($deployedImageUrl -split ':')[-1]
Write-Host "[ $activeProject ] Currently deployed image tag: $deployedImageTag"

if ((-not $cachedStoredRaw) -or ([string]::IsNullOrEmpty($cachedStoredContent.GCP.ImageTag))) {
  $cachedTag = $deployedImageTag
}
else {
  $cachedTag = $cachedStoredContent.GCP.ImageTag
  Write-Host "[ $activeProject ] Cached deployed image tag: $cachedTag"
}

Write-Host "[ $activeProject ] Local Git commit SHA: $gitCommitSha"

if ($deployedImageTag -eq $cachedTag -or ([string]::IsNullOrEmpty($deployedImageTag))) {
  # --- Cloud Run Jobs ---
  $runName = $envVars['CLOUD_RUN_NAME']
  Write-Host "[ $activeProject ] Deploying to cloud run jobs..."
  $deployCommands = @(
    "gcloud run jobs deploy $runName",
    "--source .",
    "--region $($envVars['GCP_REGION'])",
    "--project $($envVars['GCP_PROJECT_ID'])",
    "--service-account $($serviceAccountEmail)",
    "--tasks 1",
    "--max-retries 0",
    "--args=""--use-gcp"""
  )
  $requiredEnvKeys = @("GCP_PROJECT_ID", "GCP_DATABASE_NAME", "GCP_DATABASE_COLLECTION")
  foreach ($key in $requiredEnvKeys) {
    $deployCommands += "--set-env-vars $($key)=$($envVars[$key])"
  }
  $fullCommand = $deployCommands -join " "
  write-host "[ $activeProject ] Executing: [ $fullCommand ]"
  Invoke-Expression $fullCommand

  if ($LASTEXITCODE -ne 0) {
    throw "[ $activeProject ] ERROR: Something went wrong when invoking $fullCommand"
    exit 1
  }

  $recentDeployedImageUrl = (gcloud run jobs describe $envVars['CLOUD_RUN_NAME'] `
      --region $envVars['GCP_REGION'] `
      --format="value(image)").trim()
  $recentDeployedImageTag = ($recentDeployedImageUrl -split ':')[-1]
  $cacheContent += "  ImageTag: $recentDeployedImageTag"
  $cacheContent | Set-Content $cacheFile -Encoding UTF8

  Write-Host "Executing cloud run jobs"
  gcloud run jobs execute $runName --region $envVars['GCP_REGION']
}
else {
  Write-Warning "[ $activeProject ] Deployed tag mismatch with cached tag."
  Write-Warning "[ $activeProject ] If this is correct, clear or delete '.cache.yaml' file."
}

# --- Scheduler ---
$cronJobName = "auto-notify"
$schedule = gcloud scheduler jobs list --location $($envVars["GCP_REGION"]) --format "value(ID)" | Select-String "auto-notify"
if ($schedule) {
  Write-Host "[ $activeProject ] Existing schedule name found! [ $cronJobName ]"
  Write-Host "[ $activeProject ] If this is not intended please delete the schedule and run the script again!"
  exit 0
}
$cloudRunName = $envVars['CLOUD_RUN_NAME']
$cronSchedule = "10 23 * * *"
$cronJobUri = "https://$($envVars["GCP_REGION"])-run.googleapis.com/apis/run.googleapis.com/v1/namespaces/$($envVars["GCP_PROJECT_ID"])/jobs/$($cloudRunName):run"

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
  "--project $($envVars['GCP_PROJECT_ID'])",       # Explicitly specify the project
  "--location ""$($envVars["GCP_REGION"])"""
)

# Join the array elements into a single command string
$fullSchedulerCommand = $schedulerCommands -join ' '
Write-Host "[ $activeProject ] Executing Cloud Scheduler command:`n$fullSchedulerCommand"

Invoke-Expression -Command $fullSchedulerCommand
if ($LASTEXITCODE -ne 0) {
  Write-Error "[ $activeProject ] Failed to configure Cloud Scheduler Job '$cronJobName': $($_.Exception.Message)"
  Write-Error "[ $activeProject ] Please ensure the service account '$serviceAccountEmail' has 'roles/run.invoker' permission on Cloud Run Job '$cloudRunJobName'."
  exit 1
}
Write-Host "[ $activeProject ] Cloud Scheduler Job '$cronJobName' configured successfully!"
Write-Host "[ $($activeProject) ] It will run according to schedule '$($cronSchedule)' in timezone 'Asia/Jakarta'."