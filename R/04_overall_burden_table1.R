# Overall burden as context: Table 1 (prevalence and DALYs, 1990 and 2021, with EAPC), the selected age-specific

source(file.path("R", "setup.R"))

data <- read_gbd("global_overall_burden")

check_records(data, c("measure", "sex", "age", "cause", "metric", "year"), 29760, "Global prevalence and DALYs (all records)")

stopifnot(identical(sort(unique(data$year)), 1990:2021), identical(unique(data$location), "Global"))

PREV <- "Prevalence"

DALY <- "DALYs (Disability-Adjusted Life Years)"

age_groups <- c(paste(AGE_GROUPS, "years"), "95+ years")

causes <- names(CAUSE_TO_CATEGORY)

half_up <- function(x, digits) {
    s <- 10^digits
    sign(x) * floor(abs(x) * s + 0.5)/s
}

fmt_int <- function(x) formatC(half_up(x, 0L), format = "f", digits = 0L)

fmt_fix <- function(x, digits) sprintf(paste0("%.", digits, "f"), x)

fmt_est <- function(val, lower, upper, digits) {
    f <- if (digits == 0L) 
        fmt_int
    else function(x) fmt_fix(x, digits)
    paste0(f(val), " (", f(lower), "-", f(upper), ")")
}

eapc <- function(year, value) {
    o <- order(year)
    x <- year[o] - min(year) + 1
    m <- lm(log(value[o]) ~ x)
    ct <- summary(m)$coefficients
    b <- ct[2, 1]
    se <- ct[2, 2]
    c(eapc = (exp(b) - 1) * 100, lower = (exp(b - 1.96 * se) - 1) * 100, upper = (exp(b + 1.96 * 
        se) - 1) * 100, p_value = ct[2, 4])
}

fmt_eapc <- function(r) paste0(fmt_fix(r[[1]], 1), " (", fmt_fix(r[[2]], 1), " to ", fmt_fix(r[[3]], 
    1), ")")

fmt_p <- function(p) if (p < 0.001) "<0.001" else fmt_fix(p, 3)

pick <- function(cause, measure, age, metric, sex, years = NULL) {
    k <- data$cause == cause & data$measure == measure & data$age == age & data$metric == metric & 
        data$sex == sex
    if (!is.null(years)) 
        k <- k & data$year %in% years
    r <- data[k, , drop = FALSE]
    r[order(r$year), , drop = FALSE]
}

block <- function(cause, measure, age, sex) {
    rate_age <- if (age == "All ages") 
        "Age-standardized"
    else age
    n <- pick(cause, measure, age, "Number", sex, c(1990, 2021))
    r <- pick(cause, measure, rate_age, "Rate", sex, c(1990, 2021))
    s <- pick(cause, measure, rate_age, "Rate", sex)
    stopifnot(identical(n$year, c(1990L, 2021L)), identical(r$year, c(1990L, 2021L)), identical(s$year, 
        1990:2021))
    e <- eapc(s$year, s$val)
    c(fmt_est(n$val[1], n$lower[1], n$upper[1], 0), fmt_est(r$val[1], r$lower[1], r$upper[1], 
        1), fmt_est(n$val[2], n$lower[2], n$upper[2], 0), fmt_est(r$val[2], r$lower[2], r$upper[2], 
        1), fmt_eapc(e), fmt_p(e[[4]]))
}

cols <- c("Category", "Prev cases, 1990", "Prev rate (per 100,000), 1990", "Prev cases, 2021", 
    "Prev rate (per 100,000), 2021", "Prev EAPC, 1990-2021", "Prev p value", "DALY cases, 1990", 
    "DALY rate (per 100,000), 1990", "DALY cases, 2021", "DALY rate (per 100,000), 2021", "DALY EAPC, 1990-2021", 
    "DALY p value")

make_table <- function(cause) {
    rows <- list(c("Global", block(cause, PREV, "All ages", "Both"), block(cause, DALY, "All ages", 
        "Both")), c("Sex", rep(NA, 12)))
    for (sex in c("Male", "Female")) rows[[length(rows) + 1]] <- c(paste0("  ", sex), block(cause, 
        PREV, "All ages", sex), block(cause, DALY, "All ages", sex))
    rows[[length(rows) + 1]] <- c("Age", rep(NA, 12))
    for (age in age_groups) rows[[length(rows) + 1]] <- c(paste0("  ", age_label(age)), block(cause, 
        PREV, age, "Both"), block(cause, DALY, age, "Both"))
    t <- as.data.frame(do.call(rbind, rows), stringsAsFactors = FALSE)
    names(t) <- cols
    stopifnot(nrow(t) == 19)
    t
}

tabs <- list()

for (cause in causes) {
    tabs[[CAUSE_TO_CATEGORY[[cause]]]] <- make_table(cause)
}

write.csv(tabs[["Overall"]], out_path("overall_burden", "table1_overall.csv"), row.names = FALSE)

table_rows <- list()

for (category in names(tabs)) {
    table_rows[[category]] <- data.frame(category = category, tabs[[category]], check.names = FALSE, 
        stringsAsFactors = FALSE)
}

all_cat <- do.call(rbind, table_rows)

write.csv(all_cat, out_path("overall_burden", "burden_eapc_all_categories.csv"), row.names = FALSE)

selected_rows <- list()

for (age in c("30-34 years", "50-54 years", "80-84 years")) {
    f <- pick("Osteoarthritis", DALY, age, "Rate", "Female", 2021)
    m <- pick("Osteoarthritis", DALY, age, "Rate", "Male", 2021)
    stopifnot(nrow(f) == 1, nrow(m) == 1)
    h <- function(x) fmt_fix(half_up(x, 1), 1)
    selected_rows[[age]] <- data.frame(age_group = age_label(age), female_daly_rate_2021 = paste0(h(f$val), 
        " (", h(f$lower), "-", h(f$upper), ")"), male_daly_rate_2021 = paste0(h(m$val), " (", 
        h(m$lower), "-", h(m$upper), ")"), female_minus_male_rate_difference = h(f$val - m$val), 
        stringsAsFactors = FALSE)
}

sel <- do.call(rbind, selected_rows)

write.csv(sel, out_path("overall_burden", "table1_selected_age_sex_contrasts.csv"), row.names = FALSE)

series <- function(measure, sex, metric, age, cause = "Osteoarthritis") {
    r <- pick(cause, measure, age, metric, sex)
    stopifnot(identical(r$year, 1990:2021))
    r
}

asr_eapc <- function(measure, sex) {
    s <- series(measure, sex, "Rate", "Age-standardized")
    eapc(s$year, s$val)[[1]]
}

sex_diff <- function(measure) {
    f <- series(measure, "Female", "Rate", "Age-standardized")
    m <- series(measure, "Male", "Rate", "Age-standardized")
    d <- f$val - m$val
    stopifnot(all(d > 0))
    list(eapc = eapc(f$year, d)[[1]], y2021 = d[f$year == 2021])
}

pd <- sex_diff(PREV)

dd <- sex_diff(DALY)

pc <- series(PREV, "Both", "Number", "All ages")

dc <- series(DALY, "Both", "Number", "All ages")

df <- series(DALY, "Female", "Number", "All ages")

dm <- series(DALY, "Male", "Number", "All ages")

site <- setNames(numeric(4), causes[-1])

for (cause in causes[-1]) {
    site[cause] <- series(DALY, "Both", "Number", "All ages", cause)$val[32]
}

share <- site/sum(site) * 100

summ <- data.frame(quantity = c("EAPC of age-standardized prevalence rate, both sexes (%)", 
    "EAPC of age-standardized DALY rate, both sexes (%)", "EAPC of age-standardized prevalence rate, female (%)", 
    "EAPC of age-standardized prevalence rate, male (%)", "EAPC of age-standardized DALY rate, female (%)", 
    "EAPC of age-standardized DALY rate, male (%)", "EAPC of the female-male difference in age-standardized prevalence rate (%)", 
    "EAPC of the female-male difference in age-standardized DALY rate (%)", "Female-male difference in age-standardized prevalence rate, 2021 (per 100,000)", 
    "Female-male difference in age-standardized DALY rate, 2021 (per 100,000)", "Increase in prevalent cases, 1990 to 2021 (%)", 
    "DALYs in 1990 (millions)", "DALYs in 2021 (millions)", "Female-to-male ratio of DALY counts, 2021", 
    "Share of DALYs in 2021: knee (%)", "Share of DALYs in 2021: hip (%)", "Share of DALYs in 2021: hand (%)", 
    "Share of DALYs in 2021: other sites (%)"), value = c(asr_eapc(PREV, "Both"), asr_eapc(DALY, 
    "Both"), asr_eapc(PREV, "Female"), asr_eapc(PREV, "Male"), asr_eapc(DALY, "Female"), asr_eapc(DALY, 
    "Male"), pd$eapc, dd$eapc, pd$y2021, dd$y2021, (pc$val[32]/pc$val[1] - 1) * 100, dc$val[1]/1e+06, 
    dc$val[32]/1e+06, df$val[32]/dm$val[32], share[["Osteoarthritis knee"]], share[["Osteoarthritis hip"]], 
    share[["Osteoarthritis hand"]], share[["Osteoarthritis other"]]))

write.csv(summ, out_path("overall_burden", "overall_burden_summary.csv"), row.names = FALSE)

print(format(summ, digits = 4), row.names = FALSE)

cat("\n")

print(sel, row.names = FALSE)

