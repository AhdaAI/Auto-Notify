function Get-EnvValue {
    param (
        [string]$Key,
        [string]$EnvFilePath = ".env"
    )

    $value = [System.Environment]::GetEnvironmentVariable($Key)
    if (-not $value -and (Test-Path $EnvFilePath)) {
        $match = Select-String -Path $EnvFilePath -Pattern "^\s*$Key\s*=" | Select-Object -First 1
        if ($match) {
            $value = ($match.Line -split "=", 2)[1].Trim()
        }
    }

    if (-not $value) {
        Write-Warning "$key not found in environment or .env file."
    }

    return $value
}

function Set-GCloudConfig {
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [string]$ProjectId
    )

    if ($PSCmdlet.ShouldProcess("gcloud config", "Updated the configuration to desired state")) {
        $ConfirmPreference = 'None'
        $requiredServices = @("run.googleapis.com", "cloudbuild.googleapis.com", "cloudscheduler.googleapis.com")
        gcloud config set project $ProjectId
        Write-Host "• Updated project $ProjectId" -ForegroundColor Green
        foreach ($service in $requiredServices) {
            gcloud services enable $service
            Write-Host "• Updated service $service" -ForegroundColor Green
        }
    }
}


Write-Host "--- Checking for gcloud installation ---"
try {
    # $gcloudVersion = & gcloud --version 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "SUCCESS: 'gcloud' command found in PATH." -ForegroundColor Green
        # Write-Host "gcloud version output:"
        # $gcloudVersion | ForEach-Object { Write-Host "  $_" }
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

Write-Host "`n--- Preparing required environment ---"
$GOOGLE_APPLICATION_CREDENTIALS = Get-EnvValue "GOOGLE_APPLICATION_CREDENTIALS"
$GOOGLE_CLOUD_PROJECT = Get-EnvValue "GOOGLE_CLOUD_PROJECT"
$CLOUD_RUN_NAME = Get-EnvValue "CLOUD_RUN_NAME"
$GOOGLE_CLOUD_REGION = Get-EnvValue "GOOGLE_CLOUD_REGION"
$CRON_SCHEDULE = Get-EnvValue "CRON_SCHEDULE"
$SERVICE_ACCOUNT_EMAIL = (ConvertFrom-Json -InputObject (Get-Content -Path $GOOGLE_APPLICATION_CREDENTIALS -Raw)).client_email

Write-Host "`n--- Google Cloud Process ---"
Set-GCloudConfig -ProjectId $GOOGLE_CLOUD_PROJECT -Confirm
$deployCommands = @(
    "gcloud run jobs deploy $CLOUD_RUN_NAME",
    "--source .",
    "--region $($GOOGLE_CLOUD_REGION)",
    "--project $($GOOGLE_CLOUD_PROJECT)",
    "--service-account $($SERVICE_ACCOUNT_EMAIL)",
    "--tasks 1",
    "--max-retries 0",
    "--args=""--use-gcp""",
    "--set-env-vars GOOGLE_CLOUD_PROJECT=$($GOOGLE_CLOUD_PROJECT)"
)
$fullCommand = $deployCommands -join " "
Invoke-Expression $fullCommand
Write-Host "--- Executing cloud run jobs ---"
gcloud run jobs execute $CLOUD_RUN_NAME --region $GOOGLE_CLOUD_REGION

Write-Host "`n--- Scheduler ---"
$schedule = gcloud scheduler jobs list --location $($GOOGLE_CLOUD_REGION) --format "value(ID)" | Select-String $CLOUD_RUN_NAME
if ($schedule) {
    Write-Host "Schedule exist." -ForegroundColor Green
    exit 0
}

$cronJobUri = "https://$($GOOGLE_CLOUD_REGION)-run.googleapis.com/apis/run.googleapis.com/v1/namespaces/$($GOOGLE_CLOUD_PROJECT)/jobs/$($CLOUD_RUN_NAME):run"

Write-Host "Scheduler Name : $CLOUD_RUN_NAME"
Write-Host "Cron Schedule : $CRON_SCHEDULE"
Write-Host "Target : $cronJobUri"

$schedulerCommands = @(
    "gcloud scheduler jobs create http $CLOUD_RUN_NAME",
    "--schedule ""$CRON_SCHEDULE""", # Double-quotes inside the string must be escaped
    "--uri ""$cronJobUri""",         # Double-quotes inside the string must be escaped
    "--oauth-service-account-email ""$SERVICE_ACCOUNT_EMAIL""",
    "--oauth-token-scope ""https://www.googleapis.com/auth/cloud-platform""", # Required OAuth scope
    "--http-method POST",            # Cloud Run Jobs are triggered via HTTP POST
    "--time-zone ""Asia/Jakarta""",  # IMPORTANT: Set this to your desired timezone (e.g., "America/New_York", "Europe/London")
    "--project $($GOOGLE_CLOUD_PROJECT)",       # Explicitly specify the project
    "--location ""$($GOOGLE_CLOUD_REGION)"""
)

$fullSchedulerCommand = $schedulerCommands -join ' '
Invoke-Expression -Command $fullSchedulerCommand
