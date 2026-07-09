# Automated Audio Analysis Pipeline

## Overview
This project provides a scalable pipeline for **audio data analysis** designed for large-scale survey datasets.
It automates the **preprocessing, feature extraction, and parallelized computation** of thousands of audio files, improving efficiency, data quality, and reproducibility in research workflows.

The project is developed in **R** using packages such as `soundgen`, `tuneR`, and `parallel`, and is tailored for applications in **survey monitoring, evaluation, and development research**. Package versions are pinned with [`renv`](https://rstudio.github.io/renv/) and common tasks are exposed through a [`Justfile`](https://github.com/casey/just) for reproducibility.

---

## Objectives

- Automate the processing of raw audio files collected during surveys.
- Extract acoustic features (duration, pitch, intensity, formants, etc.).
- Use **parallelization** to handle thousands of files efficiently.
- Provide reproducible scripts for large-scale monitoring and evaluation projects.
- Enable researchers and practitioners to transform **raw sound into actionable insights**.

---

## Project Structure

```text
.
├── R_script/
│   └── audio_analysis_par.R   # Main parallelized analysis script
├── data/                      # Input audio files, one subfolder per batch (gitignored)
│   ├── test1/
│   └── test2/
├── outputs/                   # Generated *_summary.csv files (gitignored)
├── renv/                      # renv-managed R package library
├── renv.lock                  # Pinned package versions
├── .Rprofile                  # Activates renv for the project
└── Justfile                   # Task runner (install / run / snapshot / clean)
```

`data/`, `outputs/`, and `logs/` are excluded from version control (see `.gitignore`); you provide your own audio files locally.

---

## Methodology

1. **Data Input** – Audio files (`.wav`) are organized into subfolders under `data/`, one subfolder per batch/test.
2. **Parallelized Processing** – For each subfolder, the script spins up an R cluster (`parallel::makeCluster`), using all logical cores minus one (capped at the number of files), and analyzes one file per worker task.
3. **Feature Extraction** – Each file is analyzed with `soundgen::analyze()` (16 kHz sampling rate) to extract acoustic features (duration, pitch, intensity, formants, etc.).
4. **Error Handling** – Failed files are captured individually (via `try()`) and recorded with an error message instead of aborting the whole batch.
5. **Output** – Results for each subfolder are combined into a single data frame and written to `outputs/<subfolder>_summary.csv`.

---

## Installation & Requirements

### Prerequisites

- [R](https://www.r-project.org/) (developed against R 4.5)
- [`just`](https://github.com/casey/just) command runner
- Windows users: recipes run under PowerShell (configured in the `Justfile`)

### 1. Clone the repository

```bash
git clone https://github.com/<your-username>/<repo-name>.git
cd <repo-name>
```

### 2. Restore the R package environment

This project uses `renv` to pin package versions from `renv.lock`.

```bash
just install
```

This runs `renv::restore(prompt = FALSE)` and installs all required packages (`soundgen`, `tuneR`, `parallel`, etc.) into an isolated project library.

### 3. Add your audio data

Place `.wav` files in `data/<batch_name>/` (e.g. `data/test1/`, `data/test2/`), one subfolder per batch you want summarized separately.

---

## Usage

List all available tasks:
```bash
just
```

Run the parallelized audio analysis pipeline:
```bash
just run
```

This executes `R_script/audio_analysis_par.R`, which processes every subfolder in `data/` and writes one summary CSV per subfolder to `outputs/`.

Update `renv.lock` after installing/upgrading packages:
```bash
just snapshot
```

Remove generated summary CSVs:
```bash
just clean
```

---

## Output

For each subfolder in `data/`, a corresponding `outputs/<subfolder>_summary.csv` is produced, containing the acoustic feature summary for every `.wav` file in that subfolder, plus `file`, `path`, and `error` columns (the latter populated only when analysis of a given file failed).
