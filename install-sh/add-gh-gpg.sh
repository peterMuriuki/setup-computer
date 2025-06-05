#!/usr/bin/env bash


set -uo pipefail # Exit on error, undefined variable, pipe failure

# --- Constants ---
GPG_CMD="gpg"
GH_CMD="gh"

# Determine the directory of this script
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
UTILS_FILE="${SCRIPT_DIR}/utils.sh"

# Source the utility script
if [ -f "$UTILS_FILE" ]; then
    # shellcheck source=utils.sh
    source "$UTILS_FILE"
else
    printf "ERROR: Utility script not found at %s\n" "$UTILS_FILE" >&2
    exit 1
fi

get_confirmation() {
    local prompt_msg="$1"
    local response
    while true; do
        read -rp "$prompt_msg (yes/no): " response
        case "${response,,}" in # Lowercase response
            yes|y) return 0 ;;
            no|n) return 1 ;;
            *) warn "Invalid input. Please enter 'yes' or 'no'." ;;
        esac
    done
}

# --- Main Script ---
main() {
    log "Starting GPG key to GitHub automation script."

    # 1. Dependency Checks
    check_command_exists "$GPG_CMD"
    check_command_exists "$GH_CMD"

    # 2. Check GitHub CLI Authentication
    log "Checking GitHub CLI authentication status..."
    if ! "$GH_CMD" auth status >/dev/null 2>&1; then
        # Attempt to capture specific error from gh auth status for better user feedback
        local auth_status_err
        auth_status_err=$("$GH_CMD" auth status 2>&1) || true # Capture error, proceed if command fails
        error "GitHub CLI (gh) is not authenticated. Please run \`gh auth login\` and try again. Details: ${auth_status_err:-No specific error message from gh.}"
    fi
    log "GitHub CLI is authenticated."

    # 3. GPG Key Selection or Generation
    local selected_key_id=""
    local email_address_for_key="" # Store email if generating a new key

    echo
    echo "How would you like to proceed?"
    echo "  1. Use an existing GPG key"
    echo "  2. Generate a new GPG key"
    echo "  3. Cancel"
    
    local choice
    read -rp "Enter your choice (1-3): " choice

    case "$choice" in
        1) # Use existing key
            log "Listing available GPG secret keys..."
            local key_list
            key_list=$("$GPG_CMD" --list-secret-keys --keyid-format LONG)
            
            if [ -z "$key_list" ]; then
                warn "No GPG secret keys found on your system."
                if get_confirmation "Would you like to generate a new GPG key instead?"; then
                    choice="2" # Re-route to generation
                else
                    log "Operation cancelled. No existing key selected and not generating a new one."
                    exit 0
                fi
            else
                echo "-----------------------------------------------------"
                echo "$key_list"
                echo "-----------------------------------------------------"
                while [ -z "$selected_key_id" ]; do
                    read -rp "Enter the GPG Key ID (long format, e.g., 3AA5C34371567BD2 from the list above): " input_key_id
                    # Validate if input_key_id exists by trying to export its public key (silently)
                    if "$GPG_CMD" --export "$input_key_id" >/dev/null 2>&1; then
                        selected_key_id="$input_key_id"
                        log "Selected GPG Key ID: $selected_key_id"
                    else
                        warn "Invalid Key ID or Key ID not found/accessible. Please try again."
                    fi
                done
            fi
            ;;
        2) # Generate new key (placeholder, actual logic follows if choice is 2)
            : 
            ;;
        3) # Cancel
            log "Operation cancelled by user."
            exit 0
            ;;
        *)
            error "Invalid choice. Exiting."
            ;;
    esac

    if [ "$choice" = "2" ]; then # Generate new key (handles direct choice "2" or reroute)
        log "Starting GPG key generation process..."
        read -rp "Enter your Real Name (e.g., John Doe): " real_name
        read -rp "Enter your Email Address (MUST be a verified email on your GitHub account): " email_address_for_key

        if [ -z "$real_name" ] || [ -z "$email_address_for_key" ]; then
            error "Real name and email address cannot be empty for GPG key generation."
        fi

        warn "IMPORTANT: Ensure '$email_address_for_key' is a VERIFIED email address on your GitHub account."
        log "You will now be guided by GPG to generate your key and set a passphrase."
        log "Please choose a strong passphrase and remember it!"
        echo

        # GPG will prompt interactively. This is preferred for security.
        if ! "$GPG_CMD" --full-generate-key; then
             error "GPG key generation failed or was cancelled by the user during the GPG process."
        fi
        log "GPG key generation process seems to have completed."
        echo

        log "Attempting to identify the newly generated key ID for email: $email_address_for_key"
        # Extract the key ID of the last 'sec' entry for the given email.
        # This assumes the newest key for that email is the one just generated.
        selected_key_id=$("$GPG_CMD" --list-secret-keys --with-colons --keyid-format LONG "$email_address_for_key" 2>/dev/null | awk -F: '/^sec:/ {key_id=$5} END {print key_id}')

        if [ -z "$selected_key_id" ]; then
            error "Could not automatically identify the new GPG key ID for '$email_address_for_key'.
This might happen if the email provided does not exactly match the one used during GPG generation,
or if GPG had an issue.
Please list your keys with \`gpg --list-secret-keys --keyid-format LONG\` and re-run this script to select it manually (Option 1)."
        else
            log "Successfully identified newly generated GPG Key ID: $selected_key_id"
        fi
    fi

    if [ -z "$selected_key_id" ]; then
        error "No GPG key ID was selected or generated. Exiting."
    fi

    # 4. Export the Public GPG Key
    log "Exporting public GPG key for ID: $selected_key_id"
    local public_gpg_key_block
    public_gpg_key_block=$("$GPG_CMD" --armor --export "$selected_key_id")
    if [ -z "$public_gpg_key_block" ]; then
        error "Failed to export public GPG key for ID: $selected_key_id. Check if the key ID is correct and accessible."
    fi
    log "Public GPG key exported successfully."
    echo

    # 5. Add the GPG Key to GitHub
    if ! get_confirmation "Proceed to add this GPG key to your GitHub account?"; then
        log "Operation cancelled by user before adding to GitHub."
        exit 0
    fi

    log "Attempting to add GPG key to GitHub account..."
    local temp_key_file
    temp_key_file=$(mktemp)
    # Ensure temp file is cleaned up on exit, error, or interrupt
    trap 'rm -f "$temp_key_file"' EXIT HUP INT QUIT TERM

    echo "$public_gpg_key_block" > "$temp_key_file"

    # Provide a title for the key on GitHub (optional, but good practice)
    local key_title
    read -rp "Enter an optional title for this GPG key on GitHub (e.g., 'Work Laptop', press Enter for default): " key_title

    local gh_add_cmd_args=("$GH_CMD" "gpg-key" "add" "$temp_key_file")
    if [ -n "$key_title" ]; then
        gh_add_cmd_args+=("--title" "$key_title")
    fi
    
    if "${gh_add_cmd_args[@]}"; then
        log "GPG key successfully added to your GitHub account!"
        echo
        log "To use this GPG key for signing commits in your Git repositories:"
        log "  1. Configure Git with the GPG key ID:"
        log "     git config --global user.signingkey $selected_key_id"
        log "  2. (Optional) Tell Git to sign all commits by default:"
        log "     git config --global commit.gpgsign true"
        log "  Alternatively, sign individual commits with \`git commit -S -m \"Your message\"\`"
    else
        # 'gh' usually provides a descriptive error message to stderr, which will be visible.
        error "Failed to add GPG key to GitHub. Please check the output from 'gh' above.
Common reasons include the key already existing on GitHub, or the email address
associated with the GPG key not being verified on your GitHub account."
    fi

    rm -f "$temp_key_file" # Explicitly remove; trap is a fallback
    trap - EXIT HUP INT QUIT TERM # Clear trap

    log "Script finished successfully."
}

# --- Run main ---
# Ensures that the script only runs main logic if sourced, e.g. for testing functions.
# However, for a standalone script, this is not strictly necessary and direct call is fine.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi