# Session Forking 

This repository contains a proof-of-concept implementation of a session forking attack that exploits legitimate OAuth2 authentication mechanisms. The attack leverages the localhost redirect URI during the authentication flow and "forks" the session to an attacker-controlled server. This allows an attacker to hijack the session and gain access to a victim's account.

This should not be confused with a MITM attack, which typically steals user authentication material and tokens. This attack, when executed in an OPSEC friendly way, uses the legitimate OAuth2 flow to authenticate and steal post-authenticated session. This session usually contains an "access type" of offline, which is a long-term session, typically that lasts for a year when unconfigured.

Due to how OAuth functions, this will only work for a single authenticated user. Even if multiple users respond with authentication responses, only one can be chosen and submitted. Choose carefully!


## Overview

The attack works as follows:

1. The attacker creates an OAuth2 request that redirects to `localhost`:`<port>` (e.g., `gcloud auth login`)
2. A phishing package is sent to victim, containing a localhost listener/redirector and launcher for the legitimate OAuth2 request URL
3. Upon successful authentication, the victim's browser sends OAuth2 response to localhost listener, which is redirected to attacker controlled server (e.g., cloudflare worker)
4. The attacker can then submit this response (a localhost URL) in their browser to finish the OAuth flow to xyz service

## How It Works

The package contains several components that are used to carry out the attack:

1. A WSH (Windows Script Host) script that runs the payload on the victim's machine.
2. A Powershell script that redirects localhost requests to cloudflare worker, encoded in Base64+1 for mild obfuscation (hah)

### OPSEC Warning

> The payload uses Shell.Application (.ShellExecute) to run the payload. Be aware that security solutions like Endpoint Detection and Response (EDR) may flag and block this behavior, especially if there's an IOA on Powershell load by wscript.exe.

## Packaging and Deployment

This repository contains a script that builds the package and prepares the necessary files for deployment. The final output is a zip file that includes the malicious WSH and powershell, which can then be served through a Cloudflare Worker.

## Script Breakdown

The builder script (`create-package.sh`) is responsible for creating the attack package. It performs:

- File Modifications: Replaces placeholders in the script files with the actual values (like redirect URLs, OAuth2 request URIs, etc.).
- Base64 Encoding: The Powershell script is Base64+1 encoded to obfuscate the contents.
- File Compression: The final malicious files are zipped into a package.
- Cloudflare Worker Creation: A Cloudflare worker script (worker.js) is created, deployed with the zip downloader, and acts as a listener to responses

## Required Tools

Make sure the following tools are installed on your system:

- zip
- sed
- base64
- npm & npx
- cloudflare wrangler

## Running the Script

To run the script, follow these steps:

```bash
git clone https://github.com/fitretech-security/session-forking-poc
cd session-forking-poc
npm install wrangler --save-dev
npx wrangler login
# Modify variables in create-package.sh to set all parameters before deployment
bash ./create-package.sh
```

This will create a zip file containing the attack payload (authenticator.zip) and a Cloudflare worker (worker.js) that you can deploy to serve the malicious payload.

You can then optionally use the script to deploy automatically, and listen to responses if you want to see live responses, or test the build.

## Build Folder Structure

After running the script, the following folder structure (with example names) will be created:

```
output/
├── phish.zip      # Final package containing malicious files
├── execute_me.exe.js   # WSH script that runs the payload
├── not_ps1.db           # Base64-encoded Powershell script
└── worker.js              # Cloudflare Worker JavaScript to serve the zip file (not in the zip itself)
```