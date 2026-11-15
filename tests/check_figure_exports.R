# Verify real output files and failure handling without changing repository figures.
source("R/setup.R")
test_directory <- tempfile("figure-export-")
dir.create(test_directory)
out_path <- function(...) {
  return(file.path(test_directory, basename(file.path(...))))
}
draw_valid <- function() {
  plot(1:3, main = "Device check")
}
save_pdf_tiff(draw_valid, "probe", 2, 2, 100)
pdf_path <- file.path(test_directory, "probe.pdf")
tiff_path <- file.path(test_directory, "probe.tif")
stopifnot(file.info(pdf_path)$size > 0, file.info(tiff_path)$size > 0)
previous_hash <- tools::md5sum(pdf_path)
draw_invalid <- function() {
  stop("Deliberate export failure")
}
failed <- tryCatch({
  save_pdf_tiff(draw_invalid, "probe", 2, 2, 100)
  FALSE
}, error = function(error) TRUE)
stopifnot(failed, identical(previous_hash, tools::md5sum(pdf_path)))
unlink(test_directory, recursive = TRUE)
cat("PASS: files were created; failed drawing raised an error and preserved the existing PDF.\n")
