# Joint-RPCA mia vs Gemelli Pipeline

This note summarizes the full local pipeline used to compare the R `mia` Joint-RPCA output with the Python `Gemelli` Joint-RPCA output.

## 1. Project folder

Use one project folder for all scripts and outputs.

```text
D:/Mia Folder/
```

Expected structure:

```text
D:/Mia Folder/
├─ R/
├─ data/
├─ python/
├─ commands/
├─ results/
│  ├─ mia/
│  ├─ gemelli/
│  └─ comparison/
├─ joint_rpca_mia_gemelli_combined.R
└─ joint_rpca_mia_gemelli_report.qmd
```

## 2. R side: run mia Joint-RPCA

Open RStudio and set the project folder:

```r
setwd("D:/Mia Folder")
```

Then run the combined R script:

```r
source("joint_rpca_mia_gemelli_combined.R")
```

The R script does the following:

1. Loads the local `mia` package.
2. Loads the `ibdmdb` example data.
3. Applies `filterRPCAInput()` using Gemelli-style filtering thresholds.
4. Applies `rclr` transformation to the selected MGX and MTX assays.
5. Runs `getJointRPCA()` with:

```r
ncomponents = 3L
max.iterations = 10L
```

6. Exports mia results to:

```text
results/mia/
```

Expected mia outputs:

```text
results/mia/sample_scores.csv
results/mia/feature_loadings.csv
results/mia/proportion_explained.csv
results/mia/distance_matrix.csv
results/mia/reconstruct_error.csv
results/mia/cv_error.csv
```

The same R pipeline should also prepare the raw input files for Gemelli in:

```text
data/
```

Expected data files:

```text
data/mgx_raw.csv
data/mtx_raw.csv
data/train_test_split.csv
```

## 3. Python side: run Gemelli Joint-RPCA

The Python script should be run after the R side has created the `data/` files.

### Option A: WSL

Open WSL and run:

```bash
cd "/mnt/d/Mia Folder"
conda activate mia-gemelli
python python/check_gemelli_environment.py
python python/run_gemelli_joint_rpca.py --project-dir "/mnt/d/Mia Folder"
```

Or use the WSL runner:

```bash
cd "/mnt/d/Mia Folder"
bash commands/run_gemelli_wsl.sh
```

### Option B: PowerShell

Open PowerShell and run:

```powershell
cd "D:/Mia Folder"
conda activate mia-gemelli
python python/check_gemelli_environment.py
python python/run_gemelli_joint_rpca.py --project-dir "D:/Mia Folder"
```

Or use the PowerShell runner:

```powershell
cd "D:/Mia Folder"
./commands/run_gemelli_powershell.ps1
```

If PowerShell blocks the script, run:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
./commands/run_gemelli_powershell.ps1
```

### Option C: Command Prompt

Open Command Prompt and run:

```bat
cd /d "D:\Mia Folder"
conda activate mia-gemelli
python python\check_gemelli_environment.py
python python\run_gemelli_joint_rpca.py --project-dir "D:\Mia Folder"
```

Or use the CMD runner:

```bat
cd /d "D:\Mia Folder"
commands\run_gemelli_cmd.bat
```

Gemelli outputs are written to:

```text
results/gemelli/
```

Expected Gemelli outputs:

```text
results/gemelli/sample_scores.csv
results/gemelli/feature_loadings.csv
results/gemelli/proportion_explained.csv
results/gemelli/eigenvalues.csv
results/gemelli/distance_matrix.csv
results/gemelli/cv_error.csv
```

## 4. Run comparison

After both `results/mia/` and `results/gemelli/` exist, run the R comparison step.

If the comparison is inside the combined R script, rerun:

```r
source("joint_rpca_mia_gemelli_combined.R")
```

The comparison calculates:

| Comparison | Type | Meaning |
|---|---|---|
| Subject/sample loadings | mia vs Gemelli | PC coordinates of samples |
| Feature loadings | mia vs Gemelli | PC loadings of features |
| Proportion explained | mia vs Gemelli | Variance / eigenvalue structure |
| Distance matrix correlation | mia vs Gemelli | Pairwise sample geometry |

Primary comparison outputs are saved to:

```text
results/comparison/
```

Expected comparison outputs:

```text
results/comparison/subject_loading_correlations.csv
results/comparison/feature_loading_correlations.csv
results/comparison/proportion_explained_difference.csv
results/comparison/distance_matrix_pairwise_values.csv
results/comparison/computed_comparison_summary.csv
```

Figures are saved to:

```text
results/comparison/figures/
```

## 5. Render Quarto report

After running both the R and Python sides, render the report in RStudio:

```r
quarto::quarto_render("joint_rpca_mia_gemelli_report.qmd")
```

This creates an HTML report summarizing the mia vs Gemelli comparison.

## 6. Interpretation notes

Principal component signs can differ between implementations. A correlation of `-1` means the two components are identical up to sign orientation. Therefore, use the absolute correlation when judging agreement.

Recommended interpretation:

```text
PC-wise absolute correlations close to 1 indicate strong agreement between mia and Gemelli.
Small differences in proportion explained indicate similar variance structure.
A distance matrix correlation close to 1 indicates similar global sample geometry.
```

The mia `cv_error` and `reconstruct_error` outputs should be treated as secondary diagnostics unless their definitions are confirmed to match Gemelli's `cv_error` exactly.

## 7. Recommended run order

```text
1. Run R script to create mia outputs and Gemelli input data.
2. Run Python Gemelli script from WSL, PowerShell, or Command Prompt.
3. Run R comparison section or combined R script again.
4. Render the Quarto report.
5. Check files in results/comparison/ and results/comparison/figures/.
```
