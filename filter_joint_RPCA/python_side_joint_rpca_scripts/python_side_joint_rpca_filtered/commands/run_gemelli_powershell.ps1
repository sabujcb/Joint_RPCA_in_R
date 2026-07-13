param(
    [string]$ProjectDir = "D:/Mia Folder",
    [string]$CondaEnvName = "mia-gemelli"
)

$ErrorActionPreference = "Stop"

Write-Host "Project directory: $ProjectDir"
Write-Host "Conda environment: $CondaEnvName"

conda activate $CondaEnvName

python "$ProjectDir/python/check_gemelli_environment.py"
python "$ProjectDir/python/run_gemelli_joint_rpca.py" --project-dir "$ProjectDir"
