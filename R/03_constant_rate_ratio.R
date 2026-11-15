# Constant-rate-ratio sensitivity analysis: what the absolute female-male difference looks like when the

source(file.path("R", "setup.R"))

source(file.path("R", "engine.R"))

cur <- read.csv(out_path("main", "age_curves_main.csv"), stringsAsFactors = FALSE)

cur <- cur[cur$used_in_models, ]

o <- default_opts()

line_vs_changepoint <- function(age, y) {
    full <- fit_all(mk(age, y), o)
    hb <- numeric(length(full$HINGE$all))
    b <- numeric(length(full$HINGE$all))
    for (index in seq_along(full$HINGE$all)) {
        hb[index] <- full$HINGE$all[[index]]$ic[["bic"]]
        b[index] <- full$HINGE$all[[index]]$b
    }
    delta <- full$LINEAR$ic[["bic"]] - min(hb)
    comp <- sort(b[hb <= min(hb) + o$ic_thresh + 1e-12])
    list(status = if (delta < o$ic_thresh) "NO_BREAK" else if (length(comp) > 1) "AMBIGUOUS" else "UNIQUE_BREAK", 
        delta_bic = delta, best_age = full$HINGE$b, competitive = paste(comp, collapse = ";"))
}

constructions <- c("GEOMETRIC_MEAN_SYMMETRIC", "ARITHMETIC_MEAN_SYMMETRIC", "MALE_ANCHORED", 
    "FEMALE_ANCHORED")

build <- function(female, male, rho, spec) {
    if (spec == "GEOMETRIC_MEAN_SYMMETRIC") {
        baseline <- sqrt(female * male)
        return(list(f = baseline * sqrt(rho), m = baseline/sqrt(rho)))
    }
    else if (spec == "ARITHMETIC_MEAN_SYMMETRIC") {
        baseline <- (female + male)/2
        new_male <- 2 * baseline/(1 + rho)
        return(list(f = rho * new_male, m = new_male))
    }
    else if (spec == "MALE_ANCHORED") {
        return(list(f = rho * male, m = male))
    }
    else if (spec == "FEMALE_ANCHORED") {
        return(list(f = female, m = female/rho))
    }
    stop("Unknown constant-ratio construction.")
}

summ <- list()

curves <- list()

for (cs in CATEGORIES) {
    d <- cur[cur$category == cs, ]
    d <- d[order(d$age_midpoint_years), ]
    stopifnot(nrow(d) == 13)
    female <- d$mean_female_daly_rate_per_100000
    male <- d$mean_male_daly_rate_per_100000
    rho <- exp(mean(d$log_rate_ratio))
    obs <- line_vs_changepoint(d$age_midpoint_years, d$rate_difference_per_100000)
    for (spec in constructions) {
        n <- build(female, male, rho, spec)
        stopifnot(all(n$f > 0), all(n$m > 0), max(abs(n$f/n$m - rho)) < 1e-12)
        fit <- line_vs_changepoint(d$age_midpoint_years, n$f - n$m)
        summ[[length(summ) + 1]] <- data.frame(category = cs, construction = spec, constant_rate_ratio = rho, 
            observed_status = obs$status, observed_delta_bic = obs$delta_bic, observed_competitive_ages = obs$competitive, 
            constant_ratio_status = fit$status, constant_ratio_delta_bic = fit$delta_bic, constant_ratio_best_age = fit$best_age, 
            constant_ratio_competitive_ages = fit$competitive, stringsAsFactors = FALSE)
        curves[[length(curves) + 1]] <- data.frame(category = cs, construction = spec, age_group = d$age_group, 
            age_midpoint_years = d$age_midpoint_years, observed_rate_difference_per_100000 = d$rate_difference_per_100000, 
            constant_rate_ratio = rho, constructed_female_rate_per_100000 = n$f, constructed_male_rate_per_100000 = n$m, 
            constructed_rate_difference_per_100000 = n$f - n$m)
    }
}

summ <- do.call(rbind, summ)

curves <- do.call(rbind, curves)

write.csv(summ, out_path("main", "constant_rate_ratio_summary.csv"), row.names = FALSE)

write.csv(curves, out_path("main", "constant_rate_ratio_curves.csv"), row.names = FALSE)

print(summ[summ$construction == constructions[1], c("category", "constant_rate_ratio", "observed_status", 
    "constant_ratio_status", "constant_ratio_delta_bic", "constant_ratio_competitive_ages")], 
    row.names = FALSE, digits = 4)

