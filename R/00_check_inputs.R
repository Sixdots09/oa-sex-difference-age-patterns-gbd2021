# Check input file identity; analysis scripts also validate their contents.
source("R/setup.R")

sha256 <- function(path) {
  if (exists("sha256sum", envir = asNamespace("tools"), inherits = FALSE)) {
    hash_function <- get("sha256sum", envir = asNamespace("tools"))
    return(unname(hash_function(path)))
  }
  if (!requireNamespace("digest", quietly = TRUE)) {
    stop("Install the digest package for SHA-256 checks on R before 4.5.")
  }
  return(digest::digest(path, algo = "sha256", file = TRUE))
}

checks <- list()
for (index in seq_len(nrow(INPUTS))) {
  path <- raw_path(INPUTS$key[index])
  records <- length(readLines(path, warn = FALSE)) - 1L
  checksum <- sha256(path)
  checks[[index]] <- data.frame(key = INPUTS$key[index], records = records,
    records_match = records == INPUTS$records[index],
    checksum_match = checksum == INPUTS$sha256[index])
}
checks <- do.call(rbind, checks)
print(checks, row.names = FALSE)
if (all(checks$records_match) && all(checks$checksum_match)) {
  cat("All 14 files match the analysed inputs.\n")
} else {
  warning("Inputs differ from the analysed files. Check the GBD release and estimates; formatting can also change a checksum.")
}
