#! /usr/bin/bash
set -euo pipefail

# load utils
. ./utils.sh

VSCODE_CONFIGS="../rawConfigs/.vscode"
SETTINGS_FILE="$VSCODE_CONFIGS/settings.json"
EXTENSIONS_FILE="$VSCODE_CONFIGS/extensions.txt"

install_code_extensions(){
    # Check if the extensions file exists
  if [[ ! -f "$EXTENSIONS_FILE" ]]; then
    error "Extensions file '$EXTENSIONS_FILE' not found."
  fi

  grep -vE '^\s*#|^\s*$' "$EXTENSIONS_FILE" | while IFS= read -r ext_id || [[ -n "$ext_id" ]]; do
  

    # Trim leading/trailing whitespace from ext_id (though grep should mostly handle it)
    ext_id=$(echo "$ext_id" | xargs)

    if [[ -z "$ext_id" ]]; then
      # This case should ideally be caught by grep, but as an extra check
      warn "Skipping empty line (or line that became empty after trim) at line $line_number in '$EXTENSIONS_FILE'."
      continue
    fi

    # error out if code is not already installed
    code --install-extension "${ext_id}"
  done
}

update_code_settings(){
  if [[ ! -f "$SETTINGS_FILE" ]]; then
    error "Settings file '$SETTINGS_FILE' not found."
  fi
  if [[ "$current_os" == "Linux" ]]; then
    settings_dir="$HOME/.config/Code/User"
  else
    error "Unsupported operating system: $current_os"
  fi

  target_settings_file="${settings_dir}/settings.json"

  # TODO - maybe create backup of previous settings - probably not needed if we only
  # intend to make modifications via this script

  if cp "$SETTINGS_FILE" "$target_settings_file"; then
    log "Successfully wrote settings to '$target_settings_file'."
  fi
}

install_vscode() {

    if [[ "$current_os" == "Linux" ]]; then
    log "Starting VS Code installation..."

  log "Updating package list and installing prerequisites (wget, gpg, apt-transport-https)..."
  sudo apt update
  sudo apt install -y wget gpg apt-transport-https

  log "Downloading Microsoft GPG key..."
  wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg

  log "Installing Microsoft GPG key..."
  sudo install -D -o root -g root -m 644 packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg

  log "Adding VS Code repository..."
  echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" | sudo tee /etc/apt/sources.list.d/vscode.list > /dev/null

  log "Cleaning up downloaded GPG key..."
  rm -f packages.microsoft.gpg

  log "Updating package list again after adding new repository..."
  sudo apt update

  log "Installing VS Code (code)..."
  sudo apt install -y code

  log "VS Code installation completed successfully."
  else
    error "Unsupported operating system: $current_os"
  fi
}

main() {
  install_vscode
  install_code_extensions
  update_code_settings
}

main
