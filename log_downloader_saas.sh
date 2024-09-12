#!/bin/bash

PROJECT_ID="exta1234"  ##Liferay SaaS Project ID
ENVIRONMENT="extprd" ##environment instance id
SERVICES=("mycustomclientextension" "liferay")  ## SaaS services list 
DATE=$(date +%Y-%m-%d)  ## Yesterday logs for Mac platform. Use $(date -d "yesterday" +%Y-%m-%d) for Linux platforms
START_TIME="today at 00am"  ## Start date
END_TIME="today at 23:59:59pm" ## End date
LOG_DIR="./logs-$DATE"  ## Folder log
ZIP_FILE="logs-$DATE.zip"  ## Zip file
ERROR_LOG="error-log-$DATE.txt"  ## Error log file (if the execution of the script throws errors)
MAX_RETRIES=3  ## Max attemps
LCP_USER="user@email.com"  ## Local user (with Guest role!!!) in Liferay Cloud environment
LCP_PASSWORD="pwd"  ## Password here but you can set it using environment variable if you prefer.

START_DOWNLOAD=$(date +%s)

##### LCP Login
echo "Logging into Liferay Cloud"
echo "$LCP_USER" "$LCP_PASSWORD" | lcp login --no-browser;

##### Check if the login was successful
if [ $? -ne 0 ]; then
    echo "Failed to log in to Liferay Cloud."
    exit 1
fi

mkdir -p "$LOG_DIR"

## Function to download service logs between a date range
download_logs() {
    local service=$1
    local attempt=1

    while [ $attempt -le $MAX_RETRIES ]; do
        echo "Downloading $service Service logs since $START_TIME until $END_TIME (Attempt $attempt)"

        # lcp command to get logs
        lcp log --url "$service"-"$PROJECT_ID"-"$ENVIRONMENT".lfr.cloud  --since "$START_TIME" --until "$END_TIME" > "$LOG_DIR/$service-$DATE.log"
        
        # check if there are errors
        if [ $? -eq 0 ]; then
            echo "$service Service logs downloaded successfull."
            return 0
        else
            ## error log file is only created if there are errors
            echo "There were errors trying to download logs for service $service. Attempt $attempt failed." | tee -a "$ERROR_LOG"
            attempt=$((attempt + 1))
        fi
    done

    # All attemps were unsuccessful
    echo "Download of Service $service failed after $MAX_RETRIES attemps." | tee -a "$ERROR_LOG"

}


for service in "${SERVICES[@]}"; do
    download_logs "$service"
done

if [ -f "$ERROR_LOG" ]; then
    echo "There were errors trying to download logs. See $ERROR_LOG for more details."
else
    # No errors, then zip files
    echo "Zipping logs in $ZIP_FILE..."
    zip -r "$ZIP_FILE" "$LOG_DIR"
    
    if [ $? -eq 0 ]; then
        echo "Logs zipped successful in $ZIP_FILE."
    else
        echo "There were errors zipping logs." | tee -a "$ERROR_LOG"
    fi

    ## Removing temp folder
    rm -rf "$LOG_DIR"
fi

# Logout LCP CLI
echo "Logging out Liferay Cloud"
lcp logout

# End time
END_DOWNLOAD=$(date +%s)

ELAPSED_TIME=$((END_DOWNLOAD - START_DOWNLOAD))

echo "Elapsed time: $(printf '%d minutes and %d seconds' $((ELAPSED_TIME / 60)) $((ELAPSED_TIME % 60)))"


echo "Download logs process finished."
