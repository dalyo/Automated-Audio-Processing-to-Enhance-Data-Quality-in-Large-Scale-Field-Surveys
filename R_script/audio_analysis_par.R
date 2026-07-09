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

for(folder in folders) {
  setwd(file.path(base_dir, data_dir, folder))
  print(folder)
  # Collect .wav files
  file_list <- list.files(getwd(), pattern = "\\.wav$", full.names = TRUE)
  if (length(file_list) == 0) stop("No .wav files found in the folder.")
  
  # Choose cores (leave 1 free; never exceed number of files)
  n_cores <- max(1, min(detectCores() - 1L, length(file_list)))
  message(sprintf("Using %d worker(s) out of %d logical cores.", n_cores, detectCores()))
  
  # Start cluster
  cl <- makeCluster(n_cores)
  
  # Parallel compute: one file per worker task
    results_list <- parLapply(cl, file_list, function(fil) {
      # Each worker runs this
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
  )
  
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
  
  # Modify filename for saving
  file_name <- paste0(folder, "_summary.csv")
  
  # Save
  setwd(base_dir)
  out_path <- file.path(output_dir, file_name)
  write.csv(final_results, out_path, row.names = FALSE)
  message(sprintf("Done. Wrote: %s", out_path))
  
}