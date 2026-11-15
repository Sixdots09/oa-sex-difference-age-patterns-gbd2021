# Record the R environment used for this run.
source("R/setup.R")
versions <- c(R.version.string, paste("Platform:", R.version$platform),
              paste("Running under:", sessionInfo()$running))
for (package in c("mgcv", "ggplot2", "patchwork", "scales", "digest")) {
  if (requireNamespace(package, quietly = TRUE)) {
    versions <- c(versions, paste(package, as.character(packageVersion(package))))
  }
}
writeLines(versions, out_path("session_info.txt"))
