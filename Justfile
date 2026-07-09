# Justfile for Automated Audio Analysis Pipeline
# Requires: https://github.com/casey/just
# Requires: Rscript on PATH

# Use PowerShell instead of sh for recipe bodies on Windows
set windows-shell := ["powershell.exe", "-NoLogo", "-NoProfile", "-Command"]

# List available recipes
default:
    just --list

# Restore the project's R package library from renv.lock
install:
    Rscript -e "renv::restore(prompt = FALSE)"

# Update renv.lock to match the currently installed packages
snapshot:
    Rscript -e "renv::snapshot(prompt = FALSE)"

# Run the parallelized audio analysis pipeline
run:
    Rscript R_script/audio_analysis_par.R

# Remove generated summary CSV files
clean:
    Get-ChildItem -Path outputs -Filter "*_summary.csv" -File -ErrorAction SilentlyContinue | Remove-Item
