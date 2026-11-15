# Opposite-limit bounds for the female-male contrast, from DALY rates and from prevalence rates,

source(file.path("R", "setup.R"))

keys <- c(Overall = "age_sex_overall", Hip = "age_sex_hip", Knee = "age_sex_knee", Hand = "age_sex_hand", 
    Other = "age_sex_other")

input_tables <- list()

for (category in names(keys)) {
    input <- read_gbd(keys[[category]])
    input$cause <- category
    input_tables[[category]] <- input
}

d <- do.call(rbind, input_tables)

d$age <- age_label(d$age)

d <- d[d$metric == "Rate" & d$measure != "Incidence" & d$age %in% AGE_GROUPS, ]

d$m <- ifelse(grepl("^DALY", d$measure), "D", "P")

check_records(d, c("cause", "m", "sex", "age", "year"), 8320, "DALY and prevalence rates, 13 age groups")

key <- c("cause", "age", "year")

g <- function(sex, m) {
    x <- d[d$sex == sex & d$m == m, c(key, "val", "lower", "upper")]
    x <- x[do.call(order, x[key]), ]
    rownames(x) <- NULL
    x
}

FD <- g("Female", "D")

MD <- g("Male", "D")

FP <- g("Female", "P")

MP <- g("Male", "P")

stopifnot(identical(FD[key], MD[key]), identical(FD[key], FP[key]), identical(FD[key], MP[key]), 
    nrow(FD) == 5 * 13 * 32)

x <- FD[key]

x$dpc_ratio <- (FD$val/FP$val)/(MD$val/MP$val)

x$D_lrr <- log(FD$val/MD$val)

x$D_lo <- log(FD$lower/MD$upper)

x$D_hi <- log(FD$upper/MD$lower)

x$D_rd <- FD$val - MD$val

x$D_rd_lo <- FD$lower - MD$upper

x$D_rd_hi <- FD$upper - MD$lower

x$P_lrr <- log(FP$val/MP$val)

x$P_lo <- log(FP$lower/MP$upper)

x$P_hi <- log(FP$upper/MP$lower)

x$D_width <- (FD$upper/FD$lower + MD$upper/MD$lower)/2

x$P_width <- (FP$upper/FP$lower + MP$upper/MP$lower)/2

a <- aggregate(cbind(dpc_ratio, D_lrr, D_lo, D_hi, D_rd, D_rd_lo, D_rd_hi, P_lrr, P_lo, P_hi, 
    D_width, P_width) ~ cause + age, x, mean)

a <- a[order(match(a$cause, names(keys)), a$age), ]

out <- data.frame(cause = a$cause, age = a$age, dalys_per_case_female_over_male = a$dpc_ratio, 
    daly_rate_ratio = exp(a$D_lrr), daly_bound_low = exp(a$D_lo), daly_bound_high = exp(a$D_hi), 
    daly_bound_excludes_1 = a$D_lo > 0 | a$D_hi < 0, daly_rate_difference = a$D_rd, daly_diff_bound_low = a$D_rd_lo, 
    daly_diff_bound_high = a$D_rd_hi, daly_diff_bound_excludes_0 = a$D_rd_lo > 0 | a$D_rd_hi < 
        0, prevalence_rate_ratio = exp(a$P_lrr), prev_bound_low = exp(a$P_lo), prev_bound_high = exp(a$P_hi), 
    prev_bound_excludes_1 = a$P_lo > 0 | a$P_hi < 0, daly_ui_upper_over_lower = a$D_width, 
    prev_ui_upper_over_lower = a$P_width)

write.csv(out, out_path("uncertainty", "bounds_daly_vs_prevalence.csv"), row.names = FALSE)

for (category in names(keys)) {
    group <- out[out$cause == category, ]
    cat(category, ": prevalence bounds excluding 1 =", sum(group$prev_bound_excludes_1), "of 13\n")
}

