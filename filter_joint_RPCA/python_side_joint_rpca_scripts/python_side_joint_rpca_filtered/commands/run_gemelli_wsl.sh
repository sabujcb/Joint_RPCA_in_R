#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   bash commands/run_gemelli_wsl.sh
#   bash commands/run_gemelli_wsl.sh "/mnt/d/Mia Folder" mia-gemelli

PROJECT_DIR="${1:-/mnt/d/Mia Folder}"
CONDA_ENV_NAME="${2:-mia-gemelli}"

if ! command -v conda >/dev/null 2>&1; then
  echo "conda was not found in PATH. Start Anaconda/Miniconda first, or load conda in WSL."
  exit 1
fi

# Make conda activate available in non-interactive shells.
CONDA_BASE="$(conda info --base)"
# shellcheck disable=SC1091
source "$CONDA_BASE/etc/profile.d/conda.sh"
conda activate "$CONDA_ENV_NAME"

python "$PROJECT_DIR/python/check_gemelli_environment.py"
python "$PROJECT_DIR/python/run_gemelli_joint_rpca.py" --project-dir "$PROJECT_DIR"
