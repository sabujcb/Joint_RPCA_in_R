#!/usr/bin/env python3
"""
Run Gemelli Joint-RPCA from the CSV files exported by the R workflow.

Expected input files:
  data/mgx_raw.csv
  data/mtx_raw.csv
  data/train_test_split.csv

Written output files:
  results/gemelli/sample_scores.csv
  results/gemelli/feature_loadings.csv
  results/gemelli/proportion_explained.csv
  results/gemelli/eigenvalues.csv
  results/gemelli/distance_matrix.csv
  results/gemelli/cv_error.csv
"""

from __future__ import annotations

import argparse
import os
import re
import sys
from pathlib import Path

import pandas as pd

try:
    import biom
except ImportError as exc:
    raise SystemExit(
        "Missing package: biom-format. Install it in the active environment, for example:\n"
        "  conda install -c conda-forge biom-format\n"
        "or\n"
        "  pip install biom-format"
    ) from exc

try:
    from gemelli.rpca import joint_rpca
except ImportError as exc:
    raise SystemExit(
        "Missing package: gemelli. Install it in the active environment, for example:\n"
        "  conda install -c conda-forge gemelli\n"
        "or\n"
        "  pip install gemelli"
    ) from exc


def normalise_path(value: str | Path) -> Path:
    """Accept Windows or WSL-style paths and return a usable Path."""
    text = str(value).strip().strip('"').strip("'")

    if os.name == "posix":
        match = re.match(r"^([A-Za-z]):[\\/](.*)$", text)
        if match:
            drive = match.group(1).lower()
            rest = match.group(2).replace("\\", "/")
            return Path(f"/mnt/{drive}/{rest}").expanduser().resolve()

    return Path(text).expanduser().resolve()


def read_count_table(path: Path) -> pd.DataFrame:
    if not path.exists():
        raise FileNotFoundError(f"Input table not found: {path}")

    table = pd.read_csv(path, index_col=0)

    if table.empty:
        raise ValueError(f"Input table is empty: {path}")

    if table.index.has_duplicates:
        duplicate_ids = table.index[table.index.duplicated()].unique().tolist()
        raise ValueError(
            f"Duplicate feature IDs in {path.name}: {duplicate_ids[:5]}"
        )

    if table.columns.has_duplicates:
        duplicate_ids = table.columns[table.columns.duplicated()].unique().tolist()
        raise ValueError(
            f"Duplicate sample IDs in {path.name}: {duplicate_ids[:5]}"
        )

    table = table.apply(pd.to_numeric, errors="raise")
    return table


def read_train_test_split(path: Path) -> pd.DataFrame:
    if not path.exists():
        raise FileNotFoundError(f"Train/test split file not found: {path}")

    split_df = pd.read_csv(path)
    required_columns = {"sample_id", "train_test"}

    if not required_columns.issubset(split_df.columns):
        raise ValueError(
            "train_test_split.csv must contain columns: sample_id, train_test"
        )

    if split_df["sample_id"].duplicated().any():
        duplicate_ids = split_df.loc[
            split_df["sample_id"].duplicated(), "sample_id"
        ].unique().tolist()
        raise ValueError(
            f"Duplicate sample IDs in train_test_split.csv: {duplicate_ids[:5]}"
        )

    split_df["sample_id"] = split_df["sample_id"].astype(str)
    split_df["train_test"] = split_df["train_test"].astype(str)

    valid_labels = {"train", "test"}
    labels = set(split_df["train_test"].unique())
    unknown_labels = labels - valid_labels

    if unknown_labels:
        raise ValueError(
            "train_test column must contain only 'train' and 'test'. "
            f"Found: {sorted(unknown_labels)}"
        )

    return split_df


def check_sample_order(table: pd.DataFrame, split_df: pd.DataFrame, table_name: str) -> None:
    sample_order = split_df["sample_id"].tolist()

    if list(table.columns) != sample_order:
        table_samples = set(table.columns)
        split_samples = set(sample_order)

        missing_in_table = sorted(split_samples - table_samples)
        missing_in_split = sorted(table_samples - split_samples)

        message = [
            f"{table_name} sample order does not match train_test_split.csv.",
            "The R export should write both tables using the same shared sample order.",
        ]

        if missing_in_table:
            message.append(
                f"Samples in split but not in {table_name}: {missing_in_table[:10]}"
            )
        if missing_in_split:
            message.append(
                f"Samples in {table_name} but not in split: {missing_in_split[:10]}"
            )

        raise ValueError("\n".join(message))


def to_biom_table(table: pd.DataFrame) -> biom.Table:
    return biom.Table(
        data=table.to_numpy(),
        observation_ids=table.index.astype(str).tolist(),
        sample_ids=table.columns.astype(str).tolist(),
    )


def write_outputs(ordination, distance_matrix, cv_error, results_dir: Path) -> None:
    results_dir.mkdir(parents=True, exist_ok=True)

    ordination.samples.to_csv(results_dir / "sample_scores.csv")
    ordination.features.to_csv(results_dir / "feature_loadings.csv")
    ordination.proportion_explained.to_csv(
        results_dir / "proportion_explained.csv"
    )
    ordination.eigvals.to_csv(results_dir / "eigenvalues.csv")

    pd.DataFrame(
        distance_matrix.data,
        index=distance_matrix.ids,
        columns=distance_matrix.ids,
    ).to_csv(results_dir / "distance_matrix.csv")

    cv_error.to_csv(results_dir / "cv_error.csv", index=False)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Run Gemelli Joint-RPCA on CSV files exported by the R workflow."
    )

    parser.add_argument(
        "--project-dir",
        default=".",
        help="Project folder containing data/ and results/. Example: '/mnt/d/Mia Folder' or 'D:/Mia Folder'.",
    )
    parser.add_argument(
        "--data-dir",
        default=None,
        help="Optional data folder. Defaults to <project-dir>/data.",
    )
    parser.add_argument(
        "--results-dir",
        default=None,
        help="Optional output folder. Defaults to <project-dir>/results/gemelli.",
    )
    parser.add_argument("--mgx-file", default="mgx_raw.csv")
    parser.add_argument("--mtx-file", default="mtx_raw.csv")
    parser.add_argument("--split-file", default="train_test_split.csv")
    parser.add_argument("--n-components", type=int, default=3)
    parser.add_argument("--max-iterations", type=int, default=10)
    parser.add_argument("--min-sample-count", type=float, default=0)
    parser.add_argument("--min-feature-count", type=float, default=0)
    parser.add_argument("--min-feature-frequency", type=float, default=0)
    parser.add_argument(
        "--skip-rclr-transform",
        action="store_true",
        help="Use this only if the input tables have already been RCLR-transformed.",
    )

    return parser.parse_args()


def main() -> int:
    args = parse_args()

    project_dir = normalise_path(args.project_dir)
    data_dir = normalise_path(args.data_dir) if args.data_dir else project_dir / "data"
    results_dir = (
        normalise_path(args.results_dir)
        if args.results_dir
        else project_dir / "results" / "gemelli"
    )

    mgx_path = data_dir / args.mgx_file
    mtx_path = data_dir / args.mtx_file
    split_path = data_dir / args.split_file

    print("Project directory:", project_dir)
    print("Input data directory:", data_dir)
    print("Gemelli results directory:", results_dir)
    print("Python executable:", sys.executable)

    mgx = read_count_table(mgx_path)
    mtx = read_count_table(mtx_path)
    split_df = read_train_test_split(split_path)

    check_sample_order(mgx, split_df, "MGX")
    check_sample_order(mtx, split_df, "MTX")

    metadata = split_df.set_index("sample_id")

    print("MGX shape:", mgx.shape)
    print("MTX shape:", mtx.shape)
    print("Train/test counts:")
    print(split_df["train_test"].value_counts().to_string())

    ordination, distance_matrix, cv_error = joint_rpca(
        [to_biom_table(mgx), to_biom_table(mtx)],
        sample_metadata=metadata,
        train_test_column="train_test",
        n_components=args.n_components,
        max_iterations=args.max_iterations,
        min_sample_count=args.min_sample_count,
        min_feature_count=args.min_feature_count,
        min_feature_frequency=args.min_feature_frequency,
        rclr_transform_tables=not args.skip_rclr_transform,
    )

    write_outputs(ordination, distance_matrix, cv_error, results_dir)

    print("Gemelli Joint-RPCA completed.")
    print("Sample score dimensions:", ordination.samples.shape)
    print("Feature loading dimensions:", ordination.features.shape)
    print("Written files:")
    for path in sorted(results_dir.glob("*.csv")):
        print(" -", path)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
