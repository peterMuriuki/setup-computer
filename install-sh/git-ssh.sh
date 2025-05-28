#!/bin/bash

# --- Configuration ---
# Your email address associated with your GitHub account
GITHUB_EMAIL="pmuriuki98@gmail.com"
# The title for the SSH key on GitHub (e.g., "My Laptop Key")
KEY_TITLE="Automated SSH Key $(hostname)"
# Path to your GitHub Personal Access Token (PAT) file
# Create this file and paste your PAT into it. Ensure it's readable only by you (chmod 600).
# Alternatively, you can set GITHUB_TOKEN environment variable before running the script.
PAT_FILE="$HOME/.github_pat"

# --- Script Logic ---

# Function to print messages
log() {
    echo "[INFO] $1"
}

error() {
    echo "[ERROR] $1" >&2
    exit 1
}

# 0. Check for gh CLI
if ! command -v gh &> /dev/null; then
    error "GitHub CLI 'gh' could not be found. Please install it first. See https://github.com/cli/cli#installation"
fi

# 1. Check/Generate SSH Key
SSH_DIR="$HOME/.ssh"
KEY_PATH="$SSH_DIR/id_ed25519"
PUB_KEY_PATH="$KEY_PATH.pub"

mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"

if [ ! -f "$KEY_PATH" ]; then
    log "SSH key not found. Generating a new ED25519 key..."
    # Generate a new key without a passphrase for full automation.
    # For security, you might prefer a passphrase, but that breaks non-interactive automation.
    ssh-keygen -t ed25519 -C "$GITHUB_EMAIL" -f "$KEY_PATH" -N "" # -N "" means no passphrase
    if [ $? -ne 0 ]; then
        error "SSH key generation failed."
    fi
    log "SSH key generated at $KEY_PATH"
else
    log "SSH key already exists at $KEY_PATH"
fi
chmod 600 "$KEY_PATH"
chmod 644 "$PUB_KEY_PATH"


# 2. Ensure SSH Agent is running and add the key
log "Ensuring ssh-agent is running and adding the key..."
# Start ssh-agent if not already running for this session
if [ -z "$SSH_AGENT_PID" ]; then
    eval "$(ssh-agent -s)" > /dev/null
fi

# Add the key. ssh-add might prompt for a passphrase if the key has one.
# Our key was generated without one.
# Check if already added to avoid errors/multiple additions
if ! ssh-add -l | grep -q "$(ssh-keygen -lf "$KEY_PATH" | awk '{print $2}')"; then
    ssh-add "$KEY_PATH"
    if [ $? -ne 0 ]; then
        error "Failed to add SSH key to agent. If key has a passphrase, this script cannot automate that part."
    fi
    log "SSH key added to agent."
else
    log "SSH key already added to agent."
fi


# 3. Authenticate with GitHub CLI and add public key
log "Authenticating with GitHub CLI and adding public key..."

# Check for GITHUB_TOKEN environment variable first
if [ -z "$GITHUB_TOKEN" ]; then
    if [ -f "$PAT_FILE" ]; then
        export GITHUB_TOKEN=$(cat "$PAT_FILE")
        if [ -z "$GITHUB_TOKEN" ]; then
            error "PAT file $PAT_FILE is empty. Please provide a GitHub Personal Access Token."
        fi
        log "Using GitHub PAT from $PAT_FILE."
    else
        error "GitHub Personal Access Token not found. Please set GITHUB_TOKEN environment variable or create $PAT_FILE with your token."
    fi
else
    log "Using GitHub PAT from GITHUB_TOKEN environment variable."
fi

# Check if the key is already on GitHub
# `gh ssh-key list` output format: TITLE   ID  KEY_FINGERPRINT
# We need the fingerprint from the local key to compare.
LOCAL_FINGERPRINT=$(ssh-keygen -lf "$PUB_KEY_PATH" | awk '{print $2}')

if gh ssh-key list | grep -q "$LOCAL_FINGERPRINT"; then
    log "SSH key with fingerprint $LOCAL_FINGERPRINT is already on GitHub."
else
    log "Adding public key to GitHub account..."
    gh ssh-key add "$PUB_KEY_PATH" --title "$KEY_TITLE"
    if [ $? -ne 0 ]; then
        error "Failed to add SSH key to GitHub. Check your PAT permissions (needs 'write:public_key') and ensure the key is not a duplicate with a different title."
    fi
    log "Public key successfully added to GitHub with title: $KEY_TITLE"
fi

# Clean up GITHUB_TOKEN from environment if we set it from file
if [ -f "$PAT_FILE" ]; then
    unset GITHUB_TOKEN
fi

# 4. Test SSH connection to GitHub
log "Testing SSH connection to GitHub..."
# The output of "ssh -T git@github.com" goes to stderr
# It will print a success message like: "Hi username! You've successfully authenticated..."
# Or an error. We capture stderr to check.
SSH_TEST_OUTPUT=$(ssh -o StrictHostKeyChecking=accept-new -T git@github.com 2>&1)

if [[ "$SSH_TEST_OUTPUT" == *"successfully authenticated"* ]]; then
    log "Successfully authenticated with GitHub via SSH!"
    echo "$SSH_TEST_OUTPUT" # Print the success message
else
    error "Failed to authenticate with GitHub via SSH. Output:\n$SSH_TEST_OUTPUT"
fi

log "GitHub SSH key configuration automated successfully."