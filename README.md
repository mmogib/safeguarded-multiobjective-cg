# Safeguarded multiobjective conjugate-gradient methods

This repository contains the MATLAB implementation and numerical experiments
for safeguarded three-term conjugate-gradient methods in unconstrained
multiobjective optimization. It is self-contained and may be cloned into a
folder with any name. In MATLAB, set **Current Folder** to that folder before
running the commands below.

No completed result data are included. The first use therefore requires a full
experimental run. Later, the tables and figures can be regenerated from the
locally stored results without solving the optimization problems again.

## Requirements

- MATLAB R2025b;
- Optimization Toolbox, for `quadprog`;
- Parallel Computing Toolbox for parallel reruns (optional);
- a LaTeX installation with `pdflatex` only if the profile figures are needed.

## Setup

Run this once after opening MATLAB:

```matlab
codeRoot = pwd;
addpath(codeRoot, ...
    fullfile(codeRoot, 'problems'), ...
    fullfile(codeRoot, 'core'), ...
    fullfile(codeRoot, 'config'), ...
    fullfile(codeRoot, 'bench'));
```

## Run the experiments

The full run takes many hours and needs about 4 GB of free disk space. It
computes the main campaign, the additional HS+ and LS+ runs, and the final
seven-method report:

```matlab
rerun_all_experiments();
```

Without the Parallel Computing Toolbox, use
`rerun_all_experiments(1)` instead.

If MATLAB is interrupted, run the same command again without deleting the
output folders. Completed blocks are checked and skipped, so computation
continues from the unfinished part. Generated experiment data are stored under
`data/results/`; reports are written to `reproduced_results/reports/`.

## Recreate the final tables

After the experiments have completed, rebuild the tables without rerunning the
solvers with:

```matlab
report = reproduce_results();
```

The main files are:

- `outcomes.csv`: convergence and failure counts;
- `paired_work.csv`: paired iteration and evaluation ratios;
- `descent.csv`: sufficient-descent checks;
- `front_coverage_mean_matrix.csv`: directed coverage values;
- `front_quality_per_problem.csv`: purity and spread measures;
- `analytic_front_distance.csv`: distance to the known fronts;
- `profile_values.csv` and `profile_curves.csv`: performance-profile data;
- `results_report.mat`: all results in one MATLAB file.

The expected convergence counts are:

| Method | Converged out of 6,600 |
|---|---:|
| SVPRP+ | 6,567 |
| SVHS+  | 6,567 |
| SVLS+  | 6,566 |
| VPRP+  | 5,393 |
| VHS+   | 5,537 |
| VLS+   | 5,401 |
| VSD    | 6,563 |

Wall-clock times can vary between computers. They are not used to rank the
methods. Iteration counts, evaluation counts, statuses, and mathematical
diagnostics should reproduce exactly.

## Recreate the performance-profile figures

This step is optional and requires `pdflatex`:

```matlab
figures = reproduce_figures();
```

The generated PDF files are saved in `reproduced_results/figures/`.

## Common problems

- **`quadprog` is not found:** install or enable the Optimization Toolbox.
- **MATLAB cannot find a function:** set Current Folder to this folder and run
  the setup commands again.
- **A parallel-pool error occurs:** rerun with `rerun_all_experiments(1)`.
- **A rerun was interrupted:** repeat the full-rerun commands with the same
  output folders.
- **No completed experiment data were found:** run `rerun_all_experiments`
  before `reproduce_results` or `reproduce_figures`.
- **A profile figure is not generated:** check that `pdflatex` is installed;
  the CSV profile data do not require LaTeX.
