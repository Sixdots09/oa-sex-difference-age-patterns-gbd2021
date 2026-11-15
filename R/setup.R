# Shared paths, input checks and figure devices.
if (!file.exists("R/setup.R")) {
  stop("Run scripts from the repository root.")
}
if (!isTRUE(l10n_info()[["UTF-8"]])) {
  stop("Use a UTF-8 locale, for example LC_ALL=en_US.UTF-8.")
}

RAW_DIR <- Sys.getenv("GBD_RAW_DIR", unset = "data/raw")
INPUTS <- read.csv("data/input_files.csv", stringsAsFactors = FALSE,
                   fileEncoding = "UTF-8")
CATEGORIES <- c("Overall", "Hip", "Knee", "Hand", "Other")
CAUSE_TO_CATEGORY <- c(
  "Osteoarthritis" = "Overall", "Osteoarthritis hip" = "Hip",
  "Osteoarthritis knee" = "Knee", "Osteoarthritis hand" = "Hand",
  "Osteoarthritis other" = "Other")
AGE_GROUPS <- paste0(seq(30, 90, 5), "-", seq(34, 94, 5))
DALY_MEASURE <- "DALYs (Disability-Adjusted Life Years)"

raw_path <- function(key) {
  filename <- INPUTS$file_name[INPUTS$key == key]
  if (length(filename) != 1) {
    stop("Unknown or duplicated input key: ", key)
  }
  path <- file.path(RAW_DIR, filename)
  if (!file.exists(path)) {
    stop("Input not found: ", path, ". See data/README.md.")
  }
  return(path)
}

check_set <- function(values, expected, label) {
  actual <- sort(unique(as.character(values)))
  expected <- sort(as.character(expected))
  if (anyNA(values) || !identical(actual, expected)) {
    stop("Unexpected values in ", label)
  }
}

check_records <- function(data, keys, n_expected, label, positive = TRUE) {
  required <- c(keys, "val", "lower", "upper")
  if (!all(required %in% names(data))) {
    stop("Missing columns in ", label)
  }
  values <- as.matrix(data[c("val", "lower", "upper")])
  valid <- nrow(data) == n_expected && !anyNA(data[required]) &&
    all(is.finite(values)) && !anyDuplicated(data[keys]) &&
    all(data$lower <= data$val & data$val <= data$upper)
  if (positive) {
    valid <- valid && all(values > 0)
  } else {
    valid <- valid && all(values >= 0)
  }
  if (!valid) {
    stop("Record check failed: ", label)
  }
  cat(label, ":", nrow(data), "records checked\n")
}

read_gbd <- function(key) {
  data <- read.csv(raw_path(key), stringsAsFactors = FALSE, check.names = FALSE)
  names(data) <- sub("_name$", "", names(data))
  data <- data[, !grepl("_id$", names(data)), drop = FALSE]
  keys <- c("measure", "location", "sex", "age", "cause", "metric", "year")
  expected_rows <- INPUTS$records[INPUTS$key == key]
  check_records(data, keys, expected_rows, key, positive = FALSE)
  check_set(data$year, 1990:2021, paste(key, "year"))
  check_set(data$metric, c("Number", "Rate"), paste(key, "metric"))

  if (key == "global_dalys_age_sex") {
    expected_measures <- DALY_MEASURE
    expected_sexes <- c("Female", "Male")
    expected_ages <- c(paste(AGE_GROUPS, "years"), "95+ years")
    expected_causes <- names(CAUSE_TO_CATEGORY)
  } else if (key == "global_overall_burden") {
    expected_measures <- c(DALY_MEASURE, "Prevalence")
    expected_sexes <- c("Female", "Male", "Both")
    expected_ages <- c(paste(AGE_GROUPS, "years"), "95+ years",
                       "All ages", "Age-standardized")
    expected_causes <- names(CAUSE_TO_CATEGORY)
  } else {
    expected_measures <- c(DALY_MEASURE, "Prevalence", "Incidence")
    category_keys <- c(overall = "Overall", hip = "Hip", knee = "Knee",
                       hand = "Hand", other = "Other")
    category_key <- sub(".*_", "", key)
    category <- category_keys[[category_key]]
    expected_causes <- names(CAUSE_TO_CATEGORY)[CAUSE_TO_CATEGORY == category]
    if (startsWith(key, "age_sex_")) {
      expected_sexes <- c("Female", "Male")
      expected_ages <- c("<5 years", paste0(seq(5, 90, 5), "-",
                                            seq(9, 94, 5), " years"), "95+ years")
    } else {
      expected_sexes <- c("Female", "Male", "Both")
      if (key == "country_both_sexes_overall") {
        expected_sexes <- "Both"
      }
      expected_ages <- c("All ages", "Age-standardized")
    }
  }
  check_set(data$measure, expected_measures, paste(key, "measure"))
  check_set(data$sex, expected_sexes, paste(key, "sex"))
  check_set(data$age, expected_ages, paste(key, "age"))
  check_set(data$cause, expected_causes, paste(key, "cause"))
  if (startsWith(key, "country_")) {
    if (length(unique(data$location)) != 204) {
      stop("Expected 204 country locations in ", key)
    }
  } else {
    check_set(data$location, "Global", paste(key, "location"))
  }
  return(data)
}

out_path <- function(...) {
  path <- file.path("outputs", ...)
  for (directory in unique(dirname(path))) {
    dir.create(directory, recursive = TRUE, showWarnings = FALSE)
  }
  return(path)
}

age_label <- function(age) {
  return(sub(" years$", "", age))
}

age_midpoint <- function(label) {
  return(as.numeric(substr(label, 1, 2)) + 2.5)
}

# Use a local font without changing figure values or layout.
FONT <- Sys.getenv("FIGURE_FONT", unset = "")
if (FONT == "") {
  if (Sys.info()[["sysname"]] == "Darwin") {
    FONT <- "Helvetica"
  } else if (Sys.info()[["sysname"]] == "Windows") {
    FONT <- "Arial"
  } else {
    FONT <- "Liberation Sans"
  }
}

cairo_available <- function() {
  if (!isTRUE(capabilities("cairo"))) {
    return(FALSE)
  }
  probe <- tempfile(fileext = ".pdf")
  previous_device <- dev.cur()
  success <- tryCatch({
    withCallingHandlers({
      grDevices::cairo_pdf(probe)
      plot.new()
      dev.off()
    }, warning = function(message) stop(conditionMessage(message)))
    file.exists(probe) && file.info(probe)$size > 0
  }, error = function(error) FALSE)
  if (dev.cur() != previous_device) {
    dev.off()
  }
  unlink(probe)
  return(success)
}

save_pdf_tiff <- function(draw, name, width_in, height_in, dpi) {
  use_cairo <- cairo_available()
  if (!use_cairo) {
    message("Cairo unavailable; using base PDF and the native TIFF device.")
  }
  for (format in c("pdf", "tif")) {
    destination <- out_path("figures", paste0(name, ".", format))
    temporary <- tempfile(tmpdir = dirname(destination), fileext = paste0(".", format))
    previous_device <- dev.cur()
    tryCatch({
      withCallingHandlers({
        if (format == "pdf") {
          if (use_cairo) {
            grDevices::cairo_pdf(temporary, width = width_in, height = height_in)
          } else {
            grDevices::pdf(temporary, width = width_in, height = height_in,
                           family = "Helvetica", useDingbats = FALSE)
          }
        } else {
          bitmap_type <- getOption("bitmapType")
          if (use_cairo) {
            bitmap_type <- "cairo"
          } else if (Sys.info()[["sysname"]] == "Darwin") {
            bitmap_type <- "quartz"
          }
          if (bitmap_type == "quartz") {
            grDevices::tiff(temporary, width = width_in, height = height_in,
                            units = "in", res = dpi, type = "quartz")
          } else {
            grDevices::tiff(temporary, width = width_in, height = height_in,
                            units = "in", res = dpi, compression = "lzw",
                            type = bitmap_type)
          }
        }
        if (dev.cur() == previous_device) {
          stop("The graphics device did not open.")
        }
        draw()
        dev.off()
      }, warning = function(message) stop(conditionMessage(message)))
      if (!file.exists(temporary) || file.info(temporary)$size == 0) {
        stop("The graphics device produced no file.")
      }
      if (!file.copy(temporary, destination, overwrite = TRUE)) {
        stop("Could not save ", destination)
      }
    }, error = function(error) {
      if (dev.cur() != previous_device) {
        dev.off()
      }
      stop("Figure export failed for ", destination, ": ", conditionMessage(error))
    }, finally = unlink(temporary))
    cat("Wrote", destination, "\n")
  }
}
