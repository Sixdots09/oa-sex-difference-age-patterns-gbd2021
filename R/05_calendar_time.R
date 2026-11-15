# Equal-year, population-weighted, period and single-year curves.
source("R/setup.R")
source("R/engine.R")

raw <- read_gbd("global_dalys_age_sex")
raw$cause <- unname(CAUSE_TO_CATEGORY[raw$cause])
raw$age_lab <- age_label(raw$age)
raw <- raw[raw$age_lab %in% AGE_GROUPS, ]
raw$age <- age_midpoint(raw$age_lab)
keys <- c("cause", "age", "age_lab", "year")

select_series <- function(sex, metric) {
  selected <- raw[raw$sex == sex & raw$metric == metric, c(keys, "val")]
  selected <- selected[do.call(order, selected[keys]), ]
  rownames(selected) <- NULL
  return(selected)
}
female_rates <- select_series("Female", "Rate")
male_rates <- select_series("Male", "Rate")
female_numbers <- select_series("Female", "Number")
male_numbers <- select_series("Male", "Number")
stopifnot(identical(female_rates[keys], male_rates[keys]),
          identical(female_rates[keys], female_numbers[keys]),
          identical(female_rates[keys], male_numbers[keys]),
          nrow(female_rates) == 5 * 13 * 32,
          all(female_rates$val > 0), all(male_rates$val > 0))
annual <- female_rates[keys]
annual$pop <- female_numbers$val / female_rates$val * 1e5 +
  male_numbers$val / male_rates$val * 1e5
annual$lrr <- log(female_rates$val / male_rates$val)
annual$rd <- female_rates$val - male_rates$val
annual$period <- cut(annual$year, c(1989, 1999, 2009, 2021),
                    labels = c("1990-1999", "2000-2009", "2010-2021"))
stopifnot(all(is.finite(annual$pop)), all(annual$pop > 0))

average_years <- function(data, weighted = FALSE) {
  groups <- split(data, list(data$cause, data$age), drop = TRUE)
  rows <- list()
  for (group_name in names(groups)) {
    group <- groups[[group_name]]
    weights <- rep(1 / nrow(group), nrow(group))
    if (weighted) {
      weights <- group$pop / sum(group$pop)
    }
    rows[[group_name]] <- data.frame(cause = group$cause[1], age = group$age[1],
      age_lab = group$age_lab[1], lrr = sum(weights * group$lrr),
      rd = sum(weights * group$rd))
  }
  return(do.call(rbind, rows))
}

compare_curves <- function(data, label) {
  rows <- list()
  scale_names <- c(lrr = "ratio", rd = "diff")
  for (category in CATEGORIES) {
    for (measure in names(scale_names)) {
      group <- data[data$cause == category, ]
      group <- group[order(group$age), ]
      result <- adjudicate(group$age, group[[measure]])
      rows[[length(rows) + 1]] <- row_of(label, category, scale_names[[measure]], result)
    }
  }
  result <- do.call(rbind, rows)
  stopifnot(all(result$gam_converged))
  return(result)
}

curves <- list(
  "Main (equal year weights, 1990-2021)" = average_years(annual),
  "Population-weighted years" = average_years(annual, TRUE))
for (period in levels(annual$period)) {
  curves[[paste("Period", period)]] <- average_years(annual[annual$period == period, ])
}
additional_periods <- list(
  "Period 1990-2005" = average_years(annual[annual$year <= 2005, ]),
  "Period 2006-2021" = average_years(annual[annual$year >= 2006, ]))
all_curves <- c(curves, additional_periods)
comparison_rows <- list()
for (label in names(all_curves)) {
  comparison_rows[[label]] <- compare_curves(all_curves[[label]], label)
}
comparisons <- do.call(rbind, comparison_rows)
write.csv(comparisons, out_path("calendar_time", "model_comparison_by_weighting_and_period.csv"), row.names = FALSE)

curve_rows <- list()
for (label in names(curves)) {
  curve_rows[[label]] <- cbind(analysis = label, curves[[label]])
}
curve_table <- do.call(rbind, curve_rows)
curve_table$rate_ratio <- exp(curve_table$lrr)
names(curve_table)[names(curve_table) == "rd"] <- "rate_difference_per_100000"
row_order <- order(match(curve_table$analysis, names(curves)),
                   match(curve_table$cause, CATEGORIES), curve_table$age)
columns <- c("analysis", "cause", "age_lab", "rate_ratio", "rate_difference_per_100000")
write.csv(curve_table[row_order, columns],
          out_path("calendar_time", "age_curves_by_weighting_and_period.csv"), row.names = FALSE)

annual_rows <- list()
for (year in 1990:2021) {
  yearly_curves <- average_years(annual[annual$year == year, ])
  annual_rows[[as.character(year)]] <- compare_curves(yearly_curves, as.character(year))
}
annual_comparisons <- do.call(rbind, annual_rows)
write.csv(annual_comparisons, out_path("calendar_time", "model_comparison_single_years.csv"), row.names = FALSE)
print(table(comparisons$analysis, comparisons$status))
