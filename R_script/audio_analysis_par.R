# load library
library(soundgen)
library(parallel)

# list of folder names located inside the data folder
data_dir <- "data"
folders <- list.dirs(path = data_dir, full.names = FALSE, recursive = FALSE)

base_dir <- getwd()

# Output folder for summary CSVs
output_dir <- file.path(base_dir, "outputs")
dir.create(output_dir, showWarnings = FALSE)

# Logs folder + log file for this run
logs_dir <- file.path(base_dir, "logs")
dir.create(logs_dir, showWarnings = FALSE)
log_file <- file.path(logs_dir, sprintf("audio_analysis_%s.log", format(Sys.time(), "%Y%m%d_%H%M%S")))

log_msg <- function(...) {
  msg <- sprintf(...)
  line <- sprintf("[%s] %s", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), msg)
  message(line)
  cat(line, file = log_file, sep = "\n", append = TRUE)
}

# Function run by each worker to analyze a single file
analyze_file <- function(fil) {
  out <- try({
    res <- soundgen::analyze(
      fil,
      samplingRate = 16000,
      plot = FALSE
    )
    df <- as.data.frame(res$summary)
    df$file <- basename(fil)
    df$path <- fil
    df$error <- NA_character_
    df
  }, silent = TRUE)

  if (inherits(out, "try-error")) {
    # Return a minimal, consistent row on failure
    data.frame(
      file  = basename(fil),
      path  = fil,
      error = as.character(attr(out, "condition")$message),
      stringsAsFactors = FALSE
    )
  } else {
    out
  }
}

# Pre-scan all folders to get the grand total of .wav files for overall progress
folder_file_lists <- lapply(folders, function(folder) {
  list.files(file.path(base_dir, data_dir, folder), pattern = "\\.wav$", full.names = TRUE)
})
names(folder_file_lists) <- folders
total_files <- sum(vapply(folder_file_lists, length, integer(1)))
overall_processed <- 0

log_msg("Starting audio analysis run. Found %d folder(s) and %d file(s) total in '%s'.",
        length(folders), total_files, data_dir)

for(folder in folders) {
  setwd(file.path(base_dir, data_dir, folder))
  log_msg("Processing folder: %s", folder)
  # Collect .wav files
  file_list <- folder_file_lists[[folder]]
  if (length(file_list) == 0) {
    log_msg("No .wav files found in folder '%s'. Stopping.", folder)
    stop("No .wav files found in the folder.")
  }
  n_files <- length(file_list)
  log_msg("Found %d .wav file(s) in folder '%s'.", n_files, folder)

  # Choose cores (leave 1 free; never exceed number of files)
  n_cores <- max(1, min(detectCores() - 1L, n_files))
  log_msg("Using %d worker(s) out of %d logical cores.", n_cores, detectCores())

  # Start cluster
  cl <- makeCluster(n_cores)

  # Process files in batches of n_cores so we can report progress as each
  # batch completes (parLapply blocks until the whole vector is done)
  batches <- split(file_list, ceiling(seq_along(file_list) / n_cores))
  results_list <- list()
  folder_processed <- 0

  for (batch in batches) {
    batch_results <- parLapply(cl, batch, analyze_file)
    results_list <- c(results_list, batch_results)

    folder_processed <- folder_processed + length(batch)
    overall_processed <- overall_processed + length(batch)
    log_msg("Progress: %d/%d files in folder '%s' | %d/%d overall",
            folder_processed, n_files, folder, overall_processed, total_files)
  }

  # Stop cluster
  stopCluster(cl)
  
  # Bind rows (works even if some rows are error-only)
  # Fill missing cols gracefully
  all_cols <- unique(unlist(lapply(results_list, names)))
  results_list <- lapply(results_list, function(x) {
    missing <- setdiff(all_cols, names(x))
    if (length(missing)) x[missing] <- NA
    x[all_cols]
  })
  
  final_results <- do.call(rbind, results_list)

  # Log any per-file errors captured during analysis
  if ("error" %in% names(final_results)) {
    error_rows <- final_results[!is.na(final_results$error), ]
    if (nrow(error_rows) > 0) {
      for (i in seq_len(nrow(error_rows))) {
        log_msg("ERROR processing file '%s': %s", error_rows$file[i], error_rows$error[i])
      }
    }
  }

  # Modify filename for saving
  file_name <- paste0(folder, "_summary.csv")

  # Save
  setwd(base_dir)
  out_path <- file.path(output_dir, file_name)
  write.csv(final_results, out_path, row.names = FALSE)
  log_msg("Done with folder '%s'. Wrote: %s", folder, out_path)

}

log_msg("Audio analysis run complete. Log saved to: %s", log_file)