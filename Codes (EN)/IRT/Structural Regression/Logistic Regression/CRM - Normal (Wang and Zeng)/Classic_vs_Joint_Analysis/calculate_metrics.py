import csv
import json
import math
import os
import re
import subprocess
from pathlib import Path

import numpy as np


ROOT = Path(
    __file__
).resolve().parent.parent
OUT = ROOT / "Classic_vs_Joint_Analysis"
R_SCRIPT = "Rscript"
SCENARIOS = [(100, 10), (250, 10), (500, 10), (1000, 10)]
REPS = 1000

METHOD_FILES = {
    "Classic": {
        "a": "a_estimates_EM.txt",
        "b": "b_estimates_EM.txt",
        "alpha": "alpha_estimates_EM.txt",
        "theta": "theta_estimates_EM.txt",
    },
    "Joint": {
        "a": "a_estimates_mean.txt",
        "b": "b_estimates_mean.txt",
        "alpha": "alpha_estimates_mean.txt",
        "theta": "theta_estimates_mean.txt",
    },
}


def r_numbers(expression: str) -> np.ndarray:
    cmd = [R_SCRIPT, "-e", f"cat({expression}, sep='\\n')"]
    proc = subprocess.run(cmd, check=True, capture_output=True, text=True)
    return np.array([float(x) for x in proc.stdout.split()], dtype=float)


def true_theta(n: int) -> np.ndarray:
    return r_numbers(f"{{set.seed(228371 + {n}); rnorm({n}, mean = 0, sd = 1)}}")


def true_items(p: int) -> dict[str, np.ndarray]:
    expr = (
        "{"
        f"set.seed(448291 + {p}); "
        f"a <- runif(n = {p}, min = 0.30, max = 2.50); "
        f"b <- rnorm(n = {p}, mean = 0, sd = 1); "
        f"alpha <- runif(n = {p}, min = 0.30, max = 2.50); "
        "cat(c(a, b, alpha), sep='\\n')"
        "}"
    )
    values = r_numbers(expr)
    return {
        "a": values[0:p],
        "b": values[p : 2 * p],
        "alpha": values[2 * p : 3 * p],
    }


def read_matrix(path: Path) -> np.ndarray:
    rows: list[list[float]] = []
    with path.open("r", encoding="utf-8", errors="ignore") as handle:
        for line in handle:
            parts = line.split()
            if parts:
                rows.append([float(x) for x in parts])
    if not rows:
        return np.empty((0, 0), dtype=float)
    width = max(len(row) for row in rows)
    if any(len(row) != width for row in rows):
        raise ValueErrorr(f"ragged matrix: {path}")
    return np.array(rows, dtype=float)


def valid_numeric(matrix: np.ndarray) -> bool:
    return matrix.size > 0 and np.isfinite(matrix).all()


def metric_row(
    n: int,
    p: int,
    method: str,
    estimates: dict[str, np.ndarray],
    theta_real: np.ndarray,
    item_real: dict[str, np.ndarray],
) -> dict[str, object]:
    row: dict[str, object] = {"n": n, "p": p, "method": method}
    for param in ["theta", "a", "b", "alpha"]:
        estimate = estimates[param]
        real = theta_real if param == "theta" else item_real[param]
        expected_rows = n if param == "theta" else p
        is_valid = estimate.shape == (expected_rows, REPS) and valid_numeric(estimate)
        if is_valid:
            mean_est = np.mean(estimate, axis=1)
            bias_by_entity = mean_est - real
            sq_error = (estimate - real[:, None]) ** 2
            rmse_by_entity = np.sqrt(np.mean(sq_error, axis=1))
            row[f"bias_{param}"] = float(np.mean(bias_by_entity))
            row[f"rmse_{param}"] = float(np.mean(rmse_by_entity))
        else:
            row[f"bias_{param}"] = None
            row[f"rmse_{param}"] = None
    return row


def theta_stats_row(n: int, p: int, method: str, theta_est: np.ndarray) -> dict[str, object]:
    is_valid = theta_est.shape == (n, REPS) and valid_numeric(theta_est)
    row: dict[str, object] = {"n": n, "p": p, "method": method}
    if is_valid:
        values = theta_est.reshape(-1)
        row.update(
            {
                "mean": float(np.mean(values)),
                "sd": float(np.std(values, ddof=1)),
                "min": float(np.min(values)),
                "max": float(np.max(values)),
                "range": float(np.max(values) - np.min(values)),
            }
        )
    else:
        row.update({"mean": None, "sd": None, "min": None, "max": None, "range": None})
    return row


def quality_rows() -> list[dict[str, object]]:
    rows: list[dict[str, object]] = []
    for method, files in METHOD_FILES.items():
        base = ROOT / method
        for scenario_dir in sorted(base.glob("n = * p = *")):
            match = re.fullmatch(r"n = (\d+) p = (\d+)", scenario_dir.name)
            if not match:
                continue
            n, p = int(match.group(1)), int(match.group(2))
            for param, filename in files.items():
                path = scenario_dir / filename
                if not path.exists():
                    rows.append(
                        {
                            "n": n,
                            "p": p,
                            "method": method,
                            "param": param,
                            "file": filename,
                            "rows": None,
                            "cols": None,
                            "expected_rows": n if param == "theta" else p,
                            "expected_cols": REPS,
                            "status": "missing",
                            "note": "Missing file.",
                        }
                    )
                    continue
                matrix = read_matrix(path)
                expected_rows = n if param == "theta" else p
                status = "ok" if matrix.shape == (expected_rows, REPS) and valid_numeric(matrix) else "invalid"
                note = ""
                if status == "invalid":
                    note = "Invalid dimensions or values; metric reported as NA."
                rows.append(
                    {
                        "n": n,
                        "p": p,
                        "method": method,
                        "param": param,
                        "file": filename,
                        "rows": int(matrix.shape[0]),
                        "cols": int(matrix.shape[1]) if matrix.ndim == 2 else None,
                        "expected_rows": expected_rows,
                        "expected_cols": REPS,
                        "status": status,
                        "note": note,
                    }
                )
    rows.append(
        {
            "n": None,
            "p": None,
            "method": "Classic",
            "param": "theta",
            "file": "IRT Classic Reg. Log. *.R",
            "rows": None,
            "cols": None,
            "expected_rows": None,
            "expected_cols": None,
            "status": "warning",
            "note": "The inspected Classic programs write alpha_estimates_EM to theta_estimates_EM.txt; therefore, theta scenarios outside n x 1000 are reported as NA.",
        }
    )
    return rows


def write_csv(path: Path, rows: list[dict[str, object]], fieldnames: list[str]) -> None:
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        for row in rows:
            writer.writerow(row)


def fmt(value: object) -> str:
    if value is None:
        return "NA"
    return f"{float(value):.4f}"


def make_markdown(summary: list[dict[str, object]], theta_rows: list[dict[str, object]]) -> str:
    lines = [
        "# Comparison Classic vs Joint - CRM",
        "",
        "## IRT Summary",
        "",
        "| n | p | Method | RMSE theta | RMSE a | RMSE b | RMSE alpha | Bias theta | Bias a | Bias b | Bias alpha |",
        "|---:|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|",
    ]
    for row in summary:
        lines.append(
            "| {n} | {p} | {method} | {rmse_theta} | {rmse_a} | {rmse_b} | {rmse_alpha} | {bias_theta} | {bias_a} | {bias_b} | {bias_alpha} |".format(
                n=row["n"],
                p=row["p"],
                method=row["method"],
                rmse_theta=fmt(row["rmse_theta"]),
                rmse_a=fmt(row["rmse_a"]),
                rmse_b=fmt(row["rmse_b"]),
                rmse_alpha=fmt(row["rmse_alpha"]),
                bias_theta=fmt(row["bias_theta"]),
                bias_a=fmt(row["bias_a"]),
                bias_b=fmt(row["bias_b"]),
                bias_alpha=fmt(row["bias_alpha"]),
            )
        )
    lines.extend(
        [
            "",
            "## Estimated Theta Statistics",
            "",
            "| n | p | Method | Mean | DP | Min | Max | Range |",
            "|---:|---:|---|---:|---:|---:|---:|---:|",
        ]
    )
    for row in theta_rows:
        lines.append(
            "| {n} | {p} | {method} | {mean} | {sd} | {min} | {max} | {range} |".format(
                n=row["n"],
                p=row["p"],
                method=row["method"],
                mean=fmt(row["mean"]),
                sd=fmt(row["sd"]),
                min=fmt(row["min"]),
                max=fmt(row["max"]),
                range=fmt(row["range"]),
            )
        )
    return "\n".join(lines) + "\n"


def main() -> None:
    OUT.mkdir(exist_ok=True)
    summary: list[dict[str, object]] = []
    theta_rows: list[dict[str, object]] = []
    manual_checks: list[dict[str, object]] = []

    for n, p in SCENARIOS:
        theta_real = true_theta(n)
        item_real = true_items(p)
        for method, files in METHOD_FILES.items():
            scenario_dir = ROOT / method / f"n = {n} p = {p}"
            estimates = {param: read_matrix(scenario_dir / filename) for param, filename in files.items()}
            summary.append(metric_row(n, p, method, estimates, theta_real, item_real))
            theta_rows.append(theta_stats_row(n, p, method, estimates["theta"]))

            # Independent spot check for orientation and formula.
            if n == 250 and p == 10 and method == "Joint":
                a_est = estimates["a"]
                bias = float(np.mean(a_est[0, :]) - item_real["a"][0])
                rmse = float(np.sqrt(np.mean((a_est[0, :] - item_real["a"][0]) ** 2)))
                manual_checks.append(
                    {
                        "scenario": "n = 250 p = 10",
                        "method": "Joint",
                        "param": "a",
                        "entity": "Item 1",
                        "bias": bias,
                        "rmse": rmse,
                        "note": "Independent orientation check: row = item, column = replication.",
                    }
                )

    quality = quality_rows()

    write_csv(
        OUT / "resumo_tri.csv",
        summary,
        ["n", "p", "method"]
        + [f"{metric}_{param}" for metric in ["rmse", "bias"] for param in ["theta", "a", "b", "alpha"]],
    )
    write_csv(OUT / "thetas.csv", theta_rows, ["n", "p", "method", "mean", "sd", "min", "max", "range"])
    write_csv(
        OUT / "quality.csv",
        quality,
        ["n", "p", "method", "param", "file", "rows", "cols", "expected_rows", "expected_cols", "status", "note"],
    )
    write_csv(OUT / "checks.csv", manual_checks, ["scenario", "method", "param", "entity", "bias", "rmse", "note"])

    with (OUT / "metrics.json").open("w", encoding="utf-8") as handle:
        json.dump(
            {"summary": summary, "theta_stats": theta_rows, "quality": quality, "manual_checks": manual_checks},
            handle,
            ensure_ascii=False,
            indent=2,
        )

    (OUT / "comparacao_classic_joint.md").write_text(make_markdown(summary, theta_rows), encoding="utf-8")


if __name__ == "__main__":
    main()
