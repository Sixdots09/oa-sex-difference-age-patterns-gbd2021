# Main age curves: equal-year means (1990-2021) of the annual female-male contrasts in DALY rates,

source(file.path("R", "setup.R"))

raw <- read_gbd("global_dalys_age_sex")

raw$category <- unname(CAUSE_TO_CATEGORY[raw$cause])

raw$age_group <- age_label(raw$age)

check_records(raw, c("category", "sex", "age_group", "year", "metric"), 8960, "Global DALYs by age and sex (all records)")

rate <- raw[raw$metric == "Rate", ]

check_records(rate, c("category", "sex", "age_group", "year"), 4480, "DALY rates")

check_records(rate[rate$age_group %in% AGE_GROUPS, ], c("category", "sex", "age_group", "year"), 
    4160, "DALY rates, 13 age groups used in the models")

key <- c("category", "age_group", "year")

pick <- function(sex) {
    x <- rate[rate$sex == sex, c(key, "val")]
    x <- x[do.call(order, x[key]), ]
    rownames(x) <- NULL
    x
}

f <- pick("Female")

m <- pick("Male")

stopifnot(identical(f[key], m[key]), nrow(f) == 5 * 14 * 32)

ann <- f[key]

ann$female_rate <- f$val

ann$male_rate <- m$val

ann$log_rate_ratio <- log(ann$female_rate/ann$male_rate)

ann$rate_difference <- ann$female_rate - ann$male_rate

groups <- split(ann, list(ann$category, ann$age_group), drop = TRUE)

curve_rows <- list()

for (group_name in names(groups)) {
    group <- groups[[group_name]]
    curve_rows[[group_name]] <- data.frame(category = group$category[1], age_group = group$age_group[1], 
        n_years = nrow(group), mean_female_daly_rate_per_100000 = mean(group$female_rate), 
        mean_male_daly_rate_per_100000 = mean(group$male_rate), log_rate_ratio = mean(group$log_rate_ratio), 
        rate_ratio = exp(mean(group$log_rate_ratio)), rate_difference_per_100000 = mean(group$rate_difference), 
        stringsAsFactors = FALSE)
}

curves <- do.call(rbind, curve_rows)

curves$used_in_models <- curves$age_group %in% AGE_GROUPS

curves$age_midpoint_years <- ifelse(curves$used_in_models, age_midpoint(curves$age_group), 
    NA)

curves <- curves[order(match(curves$category, CATEGORIES), match(curves$age_group, c(AGE_GROUPS, 
    "95+"))), c("category", "age_group", "age_midpoint_years", "used_in_models", "n_years", 
    "mean_female_daly_rate_per_100000", "mean_male_daly_rate_per_100000", "log_rate_ratio", 
    "rate_ratio", "rate_difference_per_100000")]

stopifnot(nrow(curves) == 70, all(curves$n_years == 32))

write.csv(curves, out_path("main", "age_curves_main.csv"), row.names = FALSE)

cat("Written:", out_path("main", "age_curves_main.csv"), "\n")

