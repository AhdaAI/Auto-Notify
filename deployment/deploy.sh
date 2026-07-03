#!/usr/bin/env bash
set -euo pipefail

echo "--- Checking for gcloud installation ---"
if ! command -v gcloud &>/dev/null; then
    echo "gcloud not found. See https://cloud.google.com/sdk/docs/install"
    exit 1
fi

echo "--- Loading environment ---"
ENV_FILE="${ENV_FILE:-.env}"
if [ -f "$ENV_FILE" ]; then
    set -a
    source "$ENV_FILE"
    set +a
fi

: "${GOOGLE_CLOUD_PROJECT:?Required}"
: "${GOOGLE_DATABASE:?Required}"
: "${AUTO_NOTIFY_COLLECTION:?Required}"
: "${GOOGLE_CLOUD_REGION:?Required}"
: "${CRON_SCHEDULE:?Required}"
: "${FUNCTION_NAME:?Required}"
: "${FUNCTION_SERVICE_ACCOUNT:?Required}"

echo "--- Enabling required services ---"
gcloud services enable \
    cloudfunctions.googleapis.com \
    cloudscheduler.googleapis.com \
    cloudbuild.googleapis.com \
    --project "$GOOGLE_CLOUD_PROJECT"

echo "--- Deploying Cloud Function ---"
gcloud functions deploy "$FUNCTION_NAME" \
    --gen2 \
    --runtime python313 \
    --region "$GOOGLE_CLOUD_REGION" \
    --source . \
    --entry-point cloud_function_entrypoint \
    --trigger-http \
    --allow-unauthenticated \
    --service-account "$FUNCTION_SERVICE_ACCOUNT" \
    --set-env-vars "GOOGLE_CLOUD_PROJECT=$GOOGLE_CLOUD_PROJECT,GOOGLE_DATABASE=$GOOGLE_DATABASE,AUTO_NOTIFY_COLLECTION=$AUTO_NOTIFY_COLLECTION" \
    --timeout 60 \
    --quiet

echo "--- Getting function URL ---"
FUNCTION_URI=$(gcloud functions describe "$FUNCTION_NAME" \
    --gen2 \
    --region "$GOOGLE_CLOUD_REGION" \
    --format="value(serviceConfig.uri)")

echo "--- Setting up Cloud Scheduler ---"
if gcloud scheduler jobs describe "$FUNCTION_NAME" --location "$GOOGLE_CLOUD_REGION" &>/dev/null; then
    gcloud scheduler jobs update http "$FUNCTION_NAME" \
        --schedule="$CRON_SCHEDULE" \
        --uri="$FUNCTION_URI" \
        --location "$GOOGLE_CLOUD_REGION" \
        --quiet
    echo "Scheduler updated."
else
    gcloud scheduler jobs create http "$FUNCTION_NAME" \
        --schedule="$CRON_SCHEDULE" \
        --uri="$FUNCTION_URI" \
        --http-method POST \
        --time-zone "Asia/Jakarta" \
        --location "$GOOGLE_CLOUD_REGION" \
        --oauth-service-account-email "$FUNCTION_SERVICE_ACCOUNT" \
        --oauth-token-scope "https://www.googleapis.com/auth/cloud-platform" \
        --quiet
    echo "Scheduler created."
fi

echo "--- Done ---"
