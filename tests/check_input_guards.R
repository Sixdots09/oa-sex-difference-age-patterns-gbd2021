# Check that wrong years, labels, rows and intervals are rejected.
# Uses the global age-sex input through GBD_RAW_DIR; never changes that file.
source("R/setup.R")
original <- read_gbd("global_dalys_age_sex")
test_directory <- tempfile("input-guard-")
dir.create(test_directory)
original_raw_directory <- RAW_DIR
RAW_DIR <- test_directory
test_path <- file.path(test_directory,
                      INPUTS$file_name[INPUTS$key == "global_dalys_age_sex"])

expect_rejection <- function(data, label) {
  write.csv(data, test_path, row.names = FALSE)
  rejected <- tryCatch({
    read_gbd("global_dalys_age_sex")
    FALSE
  }, error = function(error) TRUE)
  if (!rejected) {
    stop("Invalid input was accepted: ", label)
  }
  cat("PASS:", label, "rejected\n")
}

changed <- original
changed$year <- changed$year + 1L
expect_rejection(changed, "1991-2022 instead of 1990-2021")
changed <- original
changed$location <- "Wrong location"
expect_rejection(changed, "wrong location")
changed <- original
changed$measure <- "Prevalence"
expect_rejection(changed, "wrong measure")
changed <- original
changed$upper[1] <- changed$lower[1] / 2
expect_rejection(changed, "inverted interval")
changed <- original
changed[2, ] <- changed[1, ]
expect_rejection(changed, "duplicated record")
changed <- original
changed$val[1] <- NA
expect_rejection(changed, "missing estimate")
changed <- original
changed$val[1] <- Inf
expect_rejection(changed, "non-finite estimate")
changed <- original
changed$lower <- NULL
expect_rejection(changed, "missing required column")
unlink(test_directory, recursive = TRUE)
RAW_DIR <- original_raw_directory
