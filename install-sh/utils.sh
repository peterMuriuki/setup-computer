# utils.sh

# ANSI Color Codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

LOG_PREFIX="[SETUP]" # Be specific

log() {
  echo -e "${GREEN}$(date '+%T') ${LOG_PREFIX} INFO:${NC} $@"
}

warn() {
  echo -e "${YELLOW}$(date '+%T') ${LOG_PREFIX} WARN:${YELLOW} $@"
}

error() {
  echo -e "${RED}$(date '+%T') ${LOG_PREFIX} ERROR:${NC} $@" >&2
  exit 1
}


## magic constants
current_os="$(uname)"

check_command_exists() {
  if ! command -v "$1" &> /dev/null; then
    error "Command '$1' not found. Please install it."
  fi
}

# You can add other utility functions here as needed

