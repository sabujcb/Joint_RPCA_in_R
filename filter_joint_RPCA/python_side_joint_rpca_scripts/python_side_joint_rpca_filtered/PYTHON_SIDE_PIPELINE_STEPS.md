# Python-side Joint-RPCA pipeline

This note records the Python side of the local mia and Gemelli comparison pipeline.

The R workflow prepares the input CSV files and writes the local mia output. The Python workflow runs Gemelli on the same raw tables and writes the Gemelli output. The Quarto report then reads both result folders and compares the outputs.

## Folder layout

Use this layout inside the project folder:

```text
D:/Mia Folder/
├─ data/
│  ├─ mgx_raw.csv
│  ├─ mtx_raw.csv
│  └─ train_test_split.csv
├─ python/
│  ├─ check_gemelli_environment.py
│  └─ run_gemelli_joint_rpca.py
├─ results/
│  ├─ mia/
│  ├─ gemelli/
│  └─ comparison/
└─ commands/
   ├─ run_gemelli_wsl.sh
   ├─ run_gemelli_powershell.ps1
   └─ run_gemelli_cmd.bat
```

## Input files expected by Python

The Python script expects these files:

```text
data/mgx_raw.csv
data/mtx_raw.csv
data/train_test_split.csv
```

The first column of `mgx_raw.csv` and `mtx_raw.csv` must contain feature IDs. The remaining columns must be samples. The column order must match the `sample_id` order in `train_test_split.csv`.

`train_test_split.csv` must contain:

```text
sample_id,train_test
```

The `train_test` column should contain only:

```text
train
test
```

## RStudio step before Python

Run the R preparation step first. This should create the `data/` files and the local `results/mia/` files.

At minimum, the data export step should produce:

```r
setwd("D:/Mia Folder")

dir.create("data", recursive = TRUE, showWarnings = FALSE)

mgx_raw <- assay(mae[[1L]], "mgx")
mtx_raw <- assay(mae[[2L]], "mtx")

shared_samples <- intersect(colnames(mgx_raw), colnames(mtx_raw))
mgx_raw <- mgx_raw[, shared_samples, drop = FALSE]
mtx_raw <- mtx_raw[, shared_samples, drop = FALSE]

test_samples <- tail(shared_samples, 2L)

train_test_split <- data.frame(
  sample_id = shared_samples,
  train_test = ifelse(shared_samples %in% test_samples, "test", "train")
)

write.csv(as.data.frame(mgx_raw), "data/mgx_raw.csv")
write.csv(as.data.frame(mtx_raw), "data/mtx_raw.csv")
write.csv(train_test_split, "data/train_test_split.csv", row.names = FALSE)
```

## WSL commands

Use WSL paths in WSL:

```bash
cd "/mnt/d/Mia Folder"
conda activate mia-gemelli
python python/check_gemelli_environment.py
python python/run_gemelli_joint_rpca.py --project-dir "/mnt/d/Mia Folder"
```

Or use the runner:

```bash
cd "/mnt/d/Mia Folder"
bash commands/run_gemelli_wsl.sh
```

If the project folder is different:

```bash
bash commands/run_gemelli_wsl.sh "/mnt/d/Mia Folder" mia-gemelli
```

## PowerShell commands

Use Windows paths in PowerShell:

```powershell
cd "D:/Mia Folder"
conda activate mia-gemelli
python python/check_gemelli_environment.py
python python/run_gemelli_joint_rpca.py --project-dir "D:/Mia Folder"
```

Or use the runner:

```powershell
cd "D:/Mia Folder"
./commands/run_gemelli_powershell.ps1
```

If script execution is blocked, run it for the current session only:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
./commands/run_gemelli_powershell.ps1
```

## Command Prompt commands

Use Windows paths in Command Prompt:

```bat
cd /d "D:\Mia Folder"
conda activate mia-gemelli
python python\check_gemelli_environment.py
python python\run_gemelli_joint_rpca.py --project-dir "D:\Mia Folder"
```

Or use the runner:

```bat
cd /d "D:\Mia Folder"
commands\run_gemelli_cmd.bat
```

## Python output files

After a successful Gemelli run, this folder should contain:

```text
results/gemelli/sample_scores.csv
results/gemelli/feature_loadings.csv
results/gemelli/proportion_explained.csv
results/gemelli/eigenvalues.csv
results/gemelli/distance_matrix.csv
results/gemelli/cv_error.csv
```

Check from WSL:

```bash
ls results/gemelli
```

Check from RStudio:

```r
list.files("results/gemelli")
```

## Complete order of the local pipeline

1. Run the R data preparation and mia Joint-RPCA step in RStudio.
2. Confirm that `data/mgx_raw.csv`, `data/mtx_raw.csv`, and `data/train_test_split.csv` exist.
3. Activate the `mia-gemelli` Python environment.
4. Run `python/check_gemelli_environment.py`.
5. Run `python/run_gemelli_joint_rpca.py`.
6. Confirm that `results/gemelli/` contains the Gemelli output CSV files.
7. Run the R comparison script.
8. Render the Quarto report.

## Common path rules

Use this path style in each shell:

| Shell | Project path |
|---|---|
| RStudio on Windows | `D:/Mia Folder` |
| PowerShell | `D:/Mia Folder` or `D:\Mia Folder` |
| Command Prompt | `D:\Mia Folder` |
| WSL | `/mnt/d/Mia Folder` |

Avoid using `D:\Mia Folder` directly inside WSL. Use `/mnt/d/Mia Folder` there.
