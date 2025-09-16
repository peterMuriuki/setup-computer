# Shell to use
SHELL := /bin/bash

# User-configurable shell configuration file
SHELL_CONFIG_FILE ?= $(HOME)/.bashrc
SHELL_CONFIG_BACKUP := $(SHELL_CONFIG_FILE).makefile.bak

# OS is assumed to be Linux
STOW_DIR := $(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))

# Variables
PYENV_ROOT_PATH := $(HOME)/.pyenv
PYENV_BIN := $(PYENV_ROOT_PATH)/bin/pyenv
PYTHON_VERSION := 3.13.3

NVM_DIR_PATH := $(HOME)/.nvm
NVM_SH := $(NVM_DIR_PATH)/nvm.sh

SDKMAN_DIR_PATH := $(HOME)/.sdkman
SDKMAN_INIT_SH := $(SDKMAN_DIR_PATH)/bin/sdkman-init.sh

KOPS_VERSION := $(shell curl -s https://api.github.com/repos/kubernetes/kops/releases/latest | grep tag_name | cut -d '"' -f 4)
NVM_VERSION := $(shell curl -s https://api.github.com/repos/nvm-sh/nvm/releases/latest | grep tag_name | cut -d '"' -f 4)

export XDG_CONFIG_HOME := $(HOME)/.config
export DOTFILES_DIR := $(STOW_DIR)/dotfiles
export ACCEPT_EULA := Y # For non-interactive installations

# Phony targets
.PHONY: all apt-sys-deps pyenv-install pyenv-python terraform-tools kops kubectl helm \
	nvm-install nvm-node sdkman-install sdkman-kotlin git apt-installs\
	tmux-htop-jre jetbrains-toolbox brave-browser minikube vagrant podman \
	update-shell-config help clean-downloads test stow-dotfiles link-dotfiles unlink-dotfiles

# Default target
all: apt-sys-deps pyenv-python terraform-tools kops kubectl helm nvm-node sdkman-kotlin \
	tmux-htop-jre jetbrains-toolbox brave-browser minikube vagrant podman git\
	link-dotfiles apt-installs\
	update-shell-config
	@echo "---------------------------------------------------------------------"
	@echo "All setup tasks attempted. Please review any messages above."
	@echo "If pyenv, nvm, or sdkman were installed/configured, your $(SHELL_CONFIG_FILE) might have been modified."
	@echo "To use them in your CURRENT shell, ensure it is sourced:"
	@echo "  source $(SHELL_CONFIG_FILE)"
	@echo "Or, simply open a new terminal window."
	@echo "---------------------------------------------------------------------"

help:
	@echo "Makefile for $(NAME) v$(VERSION)"
	@echo "Usage: make [target] [SHELL_CONFIG_FILE=~/.your_shell_rc]"
	@echo ""
	@echo "Core Targets:"
	@echo "  all                       - Install all tools, link dotfiles, and update shell config (default)"
	@echo "  apt-sys-deps              - Install base system packages (git, stow, build-essential, etc.)"
	@echo "  update-shell-config       - Check and update $(SHELL_CONFIG_FILE) for pyenv, nvm, sdkman"
	@echo ""
	@echo "Dotfile Management:"
	@echo "  stow-dotfiles             - Ensures stow is installed (dependency for link/unlink)"
	@echo "  link-dotfiles             - Stow dotfiles to their respective locations (backs up existing files)"
	@echo "  unlink-dotfiles           - Unstow dotfiles (restores backed up files)"
	@echo ""
	@echo "Tool Installation Targets (examples):"
	@echo "  pyenv-install             - Install pyenv tool"
	@echo "  pyenv-python              - Install Python $(PYTHON_VERSION) via pyenv"
	@echo "  nvm-install               - Install Node Version Manager (nvm)"
	@echo "  nvm-node                  - Install LTS Node.js via nvm"
	@echo "  sdkman-install            - Install SDKMAN!"
	@echo "  sdkman-kotlin             - Install Kotlin via SDKMAN"
	@echo "  terraform-tools           - Install Terraform, Vault, Packer"
	@echo "  kops                      - Install kops"
	@echo "  kubectl                   - Install kubectl"
	@echo "  helm                      - Install Helm"
	@echo "  tmux-htop-jre             - Install tmux, htop, default-jre"
	@echo "  jetbrains-toolbox         - Install JetBrains Toolbox"
	@echo "  brave-browser             - Install Brave Browser"
	@echo "  minikube                  - Install Minikube"
	@echo "  vagrant                   - Install Vagrant"
	@echo "  podman                    - Install Podman"
	@echo ""
	@echo "Other Targets:"
	@echo "  test                      - Run tests (requires bats)"
	@echo "  clean-downloads           - Remove temporary downloaded binaries (kops, kubectl, minikube)"
	@echo ""
	@echo "To specify a different shell config file (e.g., for zsh):"
	@echo "  make all SHELL_CONFIG_FILE=~/.zshrc"

# System dependencies
apt-sys-deps:
	@echo "Installing system dependencies..."
	sudo apt update
	sudo apt install -y \
		libssl-dev libbz2-dev libreadline-dev libsqlite3-dev \
		apt-transport-https curl ca-certificates gnupg lsb-release \
		wget stow build-essential make zlib1g-dev \
		libncursesw5-dev xz-utils tk-dev libxml2-dev libxmlsec1-dev libffi-dev liblzma-dev

apt-installs: apt-sys-deps
	sudo apt install vim

git:apt-sys-deps
	sudo apt update && sudo apt install curl -y; \
	curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg; \
	sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg; \
	echo "deb [arch=$(shell dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null; \
	sudo apt update; \
	sudo apt install git-all git-delta gh -y;

# Renamed stow-linux to stow-dotfiles for clarity, actual linking is 'link-dotfiles'
stow-dotfiles: apt-sys-deps
	@command -v stow >/dev/null 2>&1 || { echo "Stow not found. 'apt-sys-deps' might have failed or stow is not in PATH."; exit 1; }
	@echo "Stow is available."

# Renamed link to link-dotfiles for clarity
link-dotfiles: stow-dotfiles
	@echo "Linking dotfiles from $(STOW_DIR)..."
	for FILE in $$(\ls -A "$(DOTFILES_DIR)/runcom"); do if [ -f $(HOME)/$$FILE -a ! -h $(HOME)/$$FILE ]; then \
		mv -v $(HOME)/$$FILE{,.bak}; fi; done
	mkdir -p "$(XDG_CONFIG_HOME)"
	stow -d "$(DOTFILES_DIR)" -t "$(HOME)" runcom
	stow -d "$(DOTFILES_DIR)" -t "$(XDG_CONFIG_HOME)" config
	mkdir -p $(HOME)/.local/runtime
	chmod 700 $(HOME)/.local/runtime


# Renamed unlink to unlink-dotfiles for clarity
unlink-dotfiles: stow-dotfiles
	@echo "Unlinking dotfiles from $(STOW_DIR)..."
	@if [ -d "$(STOW_DIR)/runcom" ]; then \
		echo "Unstowing 'runcom' from $(HOME)..."; \
		stow -v -D -t "$(HOME)" -d "$(STOW_DIR)" runcom; \
		echo "Restoring backed up runcom files if any..."; \
		for FILE in $$(cd "$(STOW_DIR)/runcom" && find . -maxdepth 1 -type f -print | sed 's|^\./||'); do \
			if [ -f "$(HOME)/$$FILE.makefile.bak" ]; then \
				echo "Restoring $(HOME)/$$FILE.makefile.bak to $(HOME)/$$FILE"; \
				mv -v "$(HOME)/$$FILE.makefile.bak" "$(HOME)/$$FILE"; \
			fi; \
		done; \
	else \
		echo "Directory '$(STOW_DIR)/runcom' not found, skipping runcom unstowing."; \
	fi

	@if [ -d "$(STOW_DIR)/config" ]; then \
		echo "Unstowing 'config' from $(XDG_CONFIG_HOME)..."; \
		stow -v -D -t "$(XDG_CONFIG_HOME)" -d "$(STOW_DIR)" config; \
	else \
		echo "Directory '$(STOW_DIR)/config' not found, skipping config unstowing."; \
	fi
	@echo "Dotfile unlinking complete."

# Update shell configuration file (e.g., .bashrc, .zshrc)
update-shell-config:
	@echo "Checking and updating $(SHELL_CONFIG_FILE) if necessary..."
	@touch $(SHELL_CONFIG_FILE)
	@made_backup=false; \
	if ! grep -qF "# PYENV_BLOCK_START - Managed by Makefile" $(SHELL_CONFIG_FILE) || \
	   ! grep -qF "# NVM_BLOCK_START - Managed by Makefile" $(SHELL_CONFIG_FILE) || \
	   ! grep -qF "# SDKMAN_BLOCK_START - Managed by Makefile" $(SHELL_CONFIG_FILE); then \
		if [ ! -f "$(SHELL_CONFIG_BACKUP)" ]; then \
			echo "Backing up $(SHELL_CONFIG_FILE) to $(SHELL_CONFIG_BACKUP)"; \
			cp $(SHELL_CONFIG_FILE) $(SHELL_CONFIG_BACKUP); \
			made_backup=true; \
		fi; \
	fi

	@# Pyenv
	@if ! grep -qF "# PYENV_BLOCK_START - Managed by Makefile" $(SHELL_CONFIG_FILE); then \
		if [ -d "$(PYENV_ROOT_PATH)" ]; then \
			echo "Adding pyenv configuration to $(SHELL_CONFIG_FILE)..."; \
			printf "\n# PYENV_BLOCK_START - Managed by Makefile\nexport PYENV_ROOT=\"%s\"\n[[ -d \"\$PYENV_ROOT/bin\" ]] && export PATH=\"\$PYENV_ROOT/bin:\$PATH\"\neval \"\$\$(pyenv init --path)\"\neval \"\$\$(pyenv virtualenv-init -)\"\n# PYENV_BLOCK_END\n" '$(HOME)/.pyenv' >> $(SHELL_CONFIG_FILE); \
		else echo "Pyenv directory $(PYENV_ROOT_PATH) not found, skipping shell config update for pyenv."; fi; \
	else \
		echo "Pyenv Makefile-managed configuration already in $(SHELL_CONFIG_FILE)."; \
	fi

	@# NVM
	@if ! grep -qF "# NVM_BLOCK_START - Managed by Makefile" $(SHELL_CONFIG_FILE); then \
		if [ -d "$(NVM_DIR_PATH)" ]; then \
			echo "Adding NVM configuration to $(SHELL_CONFIG_FILE)..."; \
			printf "\n# NVM_BLOCK_START - Managed by Makefile\nexport NVM_DIR=\"%s\"\n[ -s \"\$NVM_DIR/nvm.sh\" ] && \\. \"\$NVM_DIR/nvm.sh\"\n[ -s \"\$NVM_DIR/bash_completion\" ] && \\. \"\$NVM_DIR/bash_completion\"\n# NVM_BLOCK_END\n" '$(HOME)/.nvm' >> $(SHELL_CONFIG_FILE); \
		else echo "NVM directory $(NVM_DIR_PATH) not found, skipping shell config update for NVM."; fi; \
	else \
		echo "NVM Makefile-managed configuration already in $(SHELL_CONFIG_FILE)."; \
	fi

	@# SDKMAN
	@if ! grep -qF "# SDKMAN_BLOCK_START - Managed by Makefile" $(SHELL_CONFIG_FILE); then \
		if [ -d "$(SDKMAN_DIR_PATH)" ]; then \
			echo "Adding SDKMAN configuration to $(SHELL_CONFIG_FILE)..."; \
			printf "\n# SDKMAN_BLOCK_START - Managed by Makefile\nexport SDKMAN_DIR=\"%s\"\n[[ -s \"\$SDKMAN_DIR/bin/sdkman-init.sh\" ]] && source \"\$SDKMAN_DIR/bin/sdkman-init.sh\"\n# SDKMAN_BLOCK_END\n" '$(HOME)/.sdkman' >> $(SHELL_CONFIG_FILE); \
		else echo "SDKMAN directory $(SDKMAN_DIR_PATH) not found, skipping shell config update for SDKMAN."; fi; \
	else \
		echo "SDKMAN Makefile-managed configuration already in $(SHELL_CONFIG_FILE)."; \
	fi

	@echo "---------------------------------------------------------------------"
	@echo "$(SHELL_CONFIG_FILE) check/update process complete."
	@if $$made_backup; then echo "Original $(SHELL_CONFIG_FILE) backed up to $(SHELL_CONFIG_BACKUP)"; fi
	@echo "For changes to take effect in your CURRENT shell, please run:"
	@echo "  source $(SHELL_CONFIG_FILE)"
	@echo "Or open a new terminal."
	@echo "---------------------------------------------------------------------"


# Pyenv
pyenv-install: $(PYENV_BIN)
$(PYENV_BIN): apt-sys-deps
	@echo "Installing pyenv..."
	@if [ -d "$(PYENV_ROOT_PATH)" ]; then \
		echo "Pyenv directory $(PYENV_ROOT_PATH) already exists. Skipping pyenv download."; \
	else \
		curl -L https://github.com/pyenv/pyenv-installer/raw/master/bin/pyenv-installer | bash; \
	fi
	@echo "Pyenv tool installed (or already present)."

pyenv-python: pyenv-install
	@echo "Installing Python $(PYTHON_VERSION) via pyenv..."
	@if ! bash -c 'export PATH="$(PYENV_ROOT_PATH)/bin:$$PATH"; eval "$$(pyenv init --path)"; pyenv versions --bare' | grep -q "^$(PYTHON_VERSION)$$"; then \
		bash -c 'export PATH="$(PYENV_ROOT_PATH)/bin:$$PATH"; eval "$$(pyenv init --path)"; pyenv install $(PYTHON_VERSION)'; \
	else \
		echo "Python $(PYTHON_VERSION) already installed via pyenv."; \
	fi
	bash -c 'export PATH="$(PYENV_ROOT_PATH)/bin:$$PATH"; eval "$$(pyenv init --path)"; pyenv global $(PYTHON_VERSION)'

# NVM
nvm-install: $(NVM_SH)
$(NVM_SH): apt-sys-deps
	@echo "Installing NVM v$(NVM_VERSION)..."
	@if [ -d "$(NVM_DIR_PATH)" ]; then \
		echo "NVM directory $(NVM_DIR_PATH) already exists. Skipping NVM download."; \
	else \
		curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/$(NVM_VERSION)/install.sh | bash; \
	fi
	@echo "NVM tool installed (or already present)."

nvm-node: nvm-install
	@echo "Installing LTS Node.js via NVM..."
	@if [ -f "$(NVM_SH)" ]; then \
		bash -c '. $(NVM_SH); nvm install --lts && nvm use default && nvm alias default lts'; \
	else \
		echo "NVM not found at $(NVM_SH). Cannot install Node.js."; exit 1; \
	fi

# SDKMAN
sdkman-install: $(SDKMAN_INIT_SH)
$(SDKMAN_INIT_SH): apt-sys-deps
	@echo "Installing SDKMAN!..."
	@if [ -d "$(SDKMAN_DIR_PATH)" ]; then \
		echo "SDKMAN! directory $(SDKMAN_DIR_PATH) already exists. Skipping SDKMAN download."; \
	else \
		curl -s "https://get.sdkman.io" | bash; \
	fi
	@echo "SDKMAN! tool installed (or already present)."

sdkman-kotlin: sdkman-install
	@echo "Installing Kotlin via SDKMAN!..."
	@if [ -f "$(SDKMAN_INIT_SH)" ]; then \
		bash -c '. $(SDKMAN_INIT_SH); sdkman install kotlin'; \
	else \
		echo "SDKMAN not found at $(SDKMAN_INIT_SH). Cannot install Kotlin."; exit 1; \
	fi

# Terraform, Vault, Packer (Hashicorp)
TERRAFORM_INSTALLED := $(shell command -v terraform 2>/dev/null)
VAULT_INSTALLED := $(shell command -v vault 2>/dev/null)
PACKER_INSTALLED := $(shell command -v packer 2>/dev/null)
HASHICORP_KEYRING := /usr/share/keyrings/hashicorp-archive-keyring.gpg
HASHICORP_SOURCE_LIST := /etc/apt/sources.list.d/hashicorp.list

terraform-tools: $(HASHICORP_SOURCE_LIST) apt-sys-deps
	@echo "Installing Terraform, Vault, Packer..."
	@if [ ! -f "$(HASHICORP_SOURCE_LIST)" ]; then echo "HashiCorp source list not found, cannot install tools."; exit 1; fi
	sudo apt-get update
	@if [ -z "$(TERRAFORM_INSTALLED)" ]; then sudo apt-get install -y terraform; else echo "Terraform already installed."; fi
	@if [ -z "$(VAULT_INSTALLED)" ]; then sudo apt-get install -y vault; else echo "Vault already installed."; fi
	@if [ -z "$(PACKER_INSTALLED)" ]; then sudo apt-get install -y packer; else echo "Packer already installed."; fi

$(HASHICORP_SOURCE_LIST):
	@echo "Adding HashiCorp APT repository..."
	@if [ ! -f $(HASHICORP_KEYRING) ]; then \
		curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o $(HASHICORP_KEYRING); \
	fi
	@if ! test -f $(HASHICORP_SOURCE_LIST) || ! grep -q "apt.releases.hashicorp.com" $(HASHICORP_SOURCE_LIST); then \
		echo "deb [signed-by=$(HASHICORP_KEYRING) arch=$(shell dpkg --print-architecture)] https://apt.releases.hashicorp.com $(shell lsb_release -cs) main" | sudo tee $(HASHICORP_SOURCE_LIST) > /dev/null; \
	else echo "HashiCorp source list already configured or contains entry."; fi


# Kops
KOPS_BIN := /usr/local/bin/kops
kops: apt-sys-deps
	@if command -v kops >/dev/null 2>&1 && [ "$$(kops version --short 2>/dev/null)" = "$(KOPS_VERSION)" ]; then \
		echo "kops v$(KOPS_VERSION) already installed."; \
	else \
		echo "Installing/Updating kops to v$(KOPS_VERSION)..."; \
		curl -Lo kops https://github.com/kubernetes/kops/releases/download/$(KOPS_VERSION)/kops-linux-amd64; \
		chmod +x kops; \
		sudo mv kops $(KOPS_BIN); \
	fi

# Kubectl
KUBECTL_BIN := /usr/local/bin/kubectl
KUBECTL_STABLE_VERSION := $(shell curl -L -s https://dl.k8s.io/release/stable.txt)
kubectl: apt-sys-deps
	@if command -v kubectl >/dev/null 2>&1 && [ "$$(kubectl version --client --short 2>/dev/null | cut -d' ' -f3)" = "$(KUBECTL_STABLE_VERSION)" ]; then \
		echo "kubectl $(KUBECTL_STABLE_VERSION) already installed."; \
	else \
		echo "Installing/Updating kubectl to $(KUBECTL_STABLE_VERSION)..."; \
		curl -Lo kubectl "https://dl.k8s.io/release/$(KUBECTL_STABLE_VERSION)/bin/linux/amd64/kubectl"; \
		chmod +x kubectl; \
		sudo mv kubectl $(KUBECTL_BIN); \
	fi

# Helm
HELM_INSTALLED := $(shell command -v helm 2>/dev/null)
HELM_KEYRING := /usr/share/keyrings/helm.gpg
HELM_SOURCE_LIST := /etc/apt/sources.list.d/helm-stable-debian.list

helm: $(HELM_SOURCE_LIST) apt-sys-deps
	@echo "Installing Helm..."
	@if [ ! -f "$(HELM_SOURCE_LIST)" ]; then echo "Helm source list not found, cannot install Helm."; exit 1; fi
	@if [ -z "$(HELM_INSTALLED)" ]; then \
		sudo apt-get update; \
		sudo apt-get install -y helm; \
	else \
		echo "Helm already installed."; \
	fi

$(HELM_SOURCE_LIST):
	@echo "Adding Helm APT repository..."
	@if [ ! -f $(HELM_KEYRING) ]; then \
		curl https://baltocdn.com/helm/signing.asc | sudo gpg --dearmor -o $(HELM_KEYRING); \
	fi
	@if ! test -f $(HELM_SOURCE_LIST) || ! grep -q "baltocdn.com/helm" $(HELM_SOURCE_LIST); then \
		echo "deb [signed-by=$(HELM_KEYRING) arch=$(shell dpkg --print-architecture)] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee $(HELM_SOURCE_LIST) > /dev/null; \
	else echo "Helm source list already configured or contains entry."; fi


# Tmux, htop, default-jre
TMUX_INSTALLED := $(shell command -v tmux 2>/dev/null)
HTOP_INSTALLED := $(shell command -v htop 2>/dev/null)
JRE_INSTALLED := $(shell dpkg-query -W -f='$${Status}' default-jre 2>/dev/null | grep -q "ok installed"; echo $$?)

tmux-htop-jre: apt-sys-deps
	@echo "Installing tmux, htop, default-jre..."
	@if [ -z "$(TMUX_INSTALLED)" ]; then sudo apt-get install -y tmux; else echo "tmux already installed."; fi
	@if [ -z "$(HTOP_INSTALLED)" ]; then sudo apt-get install -y htop; else echo "htop already installed."; fi
	@if [ "$(JRE_INSTALLED)" -ne "0" ]; then sudo apt-get install -y default-jre; else echo "default-jre already installed."; fi

# JetBrains Toolbox
JETBRAINS_TOOLBOX_DIR := $(HOME)/.local/share/JetBrains/Toolbox
JETBRAINS_TOOLBOX_INSTALL_SCRIPT_URL := https://gist.githubusercontent.com/greeflas/431bc50c23532eee8a7d6c1d603f3921/raw

jetbrains-toolbox: apt-sys-deps
	@echo "Checking JetBrains Toolbox..."
	@if [ ! -d "$(JETBRAINS_TOOLBOX_DIR)" ]; then \
		echo "Installing JetBrains Toolbox..."; \
		curl "$(JETBRAINS_TOOLBOX_INSTALL_SCRIPT_URL)" | bash; \
	else \
		echo "JetBrains Toolbox appears to be installed in $(JETBRAINS_TOOLBOX_DIR)."; \
	fi

# Brave Browser
BRAVE_INSTALLED := $(shell command -v brave-browser 2>/dev/null)
BRAVE_KEYRING := /usr/share/keyrings/brave-browser-archive-keyring.gpg
BRAVE_SOURCE_LIST := /etc/apt/sources.list.d/brave-browser-release.list

brave-browser: $(BRAVE_SOURCE_LIST) apt-sys-deps
	@echo "Installing Brave Browser..."
	@if [ ! -f "$(BRAVE_SOURCE_LIST)" ]; then echo "Brave source list not found, cannot install Brave."; exit 1; fi
	@if [ -z "$(BRAVE_INSTALLED)" ]; then \
		sudo apt update; \
		sudo apt install -y brave-browser; \
	else \
		echo "Brave Browser already installed."; \
	fi

$(BRAVE_SOURCE_LIST):
	@echo "Adding Brave Browser APT repository..."
	@if [ ! -f $(BRAVE_KEYRING) ]; then \
		sudo curl -fsSLo $(BRAVE_KEYRING) https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg; \
	fi
	@if ! test -f $(BRAVE_SOURCE_LIST) || ! grep -q "brave-browser-apt-release.s3.brave.com" $(BRAVE_SOURCE_LIST); then \
		echo "deb [signed-by=$(BRAVE_KEYRING) arch=amd64] https://brave-browser-apt-release.s3.brave.com/ stable main"|sudo tee $(BRAVE_SOURCE_LIST) > /dev/null; \
	else echo "Brave source list already configured or contains entry."; fi

# Minikube
MINIKUBE_BIN := /usr/local/bin/minikube
minikube: apt-sys-deps
	@if command -v minikube >/dev/null 2>/dev/null; then \
		echo "Minikube already installed. Checking for updates (manual for now)."; \
	else \
		echo "Installing Minikube..."; \
		curl -Lo minikube-linux-amd64 https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64; \
		sudo install minikube-linux-amd64 $(MINIKUBE_BIN); \
		rm minikube-linux-amd64; \
	fi

# Vagrant
VAGRANT_INSTALLED := $(shell command -v vagrant 2>/dev/null)
vagrant: $(HASHICORP_SOURCE_LIST) apt-sys-deps
	@echo "Installing Vagrant..."
	@if [ ! -f "$(HASHICORP_SOURCE_LIST)" ]; then echo "HashiCorp source list not found, cannot install Vagrant."; exit 1; fi
	@if [ -z "$(VAGRANT_INSTALLED)" ]; then \
		sudo apt-get update; \
		sudo apt-get install -y vagrant; \
	else \
		echo "Vagrant already installed."; \
	fi

# Podman
PODMAN_INSTALLED := $(shell command -v podman 2>/dev/null)
podman: apt-sys-deps
	@echo "Installing Podman..."
	@if [ -z "$(PODMAN_INSTALLED)" ]; then \
		sudo apt-get update; \
		sudo apt-get install -y podman; \
	else \
		echo "Podman already installed."; \
	fi

snap-installs: apt-sys-deps
	@echo "Installing snap packages"
	sudo snap install discord surfshark
	sudo snap install sublime-text --classic

# Clean up downloaded files (not a full uninstall)
clean-downloads:
	@echo "Cleaning downloaded temporary files..."
	rm -f kops kubectl minikube-linux-amd64
