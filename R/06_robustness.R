# Robustness of the five-model comparison: 18 alternative specifications, removal of each age group in turn,

source(file.path("R", "setup.R"))

source(file.path("R", "engine.R"))

cv <- load_main_curves()

o0 <- default_opts()

set_o <- function(...) modifyList(o0, list(...))

settings <- list(`Main analysis` = list(o = o0), `Grid: 2.5-year steps, 45-80` = list(o = set_o(grid = seq(45, 
    80, 2.5))), `Grid: age-group midpoints, 42.5-82.5` = list(o = set_o(grid = seq(42.5, 82.5, 
    5))), `Grid: wider range, 40-85` = list(o = set_o(grid = seq(40, 85, 5))), `Grid: quasi-continuous, 45-80 by 0.5` = list(o = set_o(grid = seq(45, 
    80, 0.5), exact_tol = 2.5)), `Count: changepoint K=4 (no search penalty)` = list(o = set_o(k_hinge = 4)), 
    `Count: GAM = sum(edf)+1` = list(o = set_o(gam_count = "edf")), `Count: GAM = full basis k+1` = list(o = set_o(gam_count = "full")), 
    `GAM: REML instead of ML` = list(o = set_o(gam_method = "REML")), `GAM: basis k=4` = list(o = set_o(gam_k = 4)), 
    `GAM: basis k=6` = list(o = set_o(gam_k = 6)), `Spline knot at 52.5` = list(o = set_o(ns_knot = 52.5)), 
    `Spline knot at 72.5` = list(o = set_o(ns_knot = 72.5)), `Threshold: any advantage (0)` = list(o = set_o(ic_thresh = 0)), 
    `Threshold: strong advantage (6)` = list(o = set_o(ic_thresh = 6)), `CV: leave two adjacent ages out` = list(o = set_o(block = 2)), 
    `Drop youngest age group (30-34)` = list(o = o0, drop = 1), `Drop oldest age group (90-94)` = list(o = o0, 
        drop = 13), `Drop both end groups` = list(o = o0, drop = c(1, 13)))

res <- list()

for (s in names(settings)) for (nm in names(cv)) {
    c0 <- cv[[nm]]
    keep <- setdiff(seq_along(c0$age), settings[[s]]$drop)
    r <- adjudicate(c0$age[keep], c0$y[keep], settings[[s]]$o)
    res[[length(res) + 1]] <- row_of(s, c0$cause, c0$scale, r)
}

res <- do.call(rbind, res)

write.csv(res, out_path("robustness", "model_comparison_sensitivity_settings.csv"), row.names = FALSE)

stopifnot(all(res$gam_converged))

print(table(res$analysis, res$status))

inf <- list()

for (nm in names(cv)) for (i in 1:13) {
    c0 <- cv[[nm]]
    r <- adjudicate(c0$age[-i], c0$y[-i], o0)
    inf[[length(inf) + 1]] <- row_of(paste0("Drop age ", c0$age[i]), c0$cause, c0$scale, r)
}

inf <- do.call(rbind, inf)

stopifnot(all(inf$gam_converged))

write.csv(inf, out_path("robustness", "model_comparison_drop_one_age_group.csv"), row.names = FALSE)

it <- matrix(ab[inf$status], nrow = 13, dimnames = list(paste0(seq(30, 90, 5), "-", seq(34, 
    94, 5)), names(cv)))

cat("\nDROP-ONE influence: status when each age group is removed (rows = removed group)\n")

print(t(it), quote = FALSE)

ib <- matrix(inf$boundary, nrow = 13, dimnames = dimnames(it))

cat("\nSelected changepoint age when each age group is removed\n")

print(t(ib))

maximum_ages <- function(values, ages) {
    tolerance <- 1e-12 * max(1, abs(max(values)))
    tied <- abs(values - max(values)) <= tolerance
    return(paste(ages[tied], collapse = ";"))
}

dg <- list()

rs_all <- list()

for (sc in c("ratio", "diff")) for (cs in CATEGORIES) {
    c0 <- cv[[paste(cs, sc)]]
    r <- adjudicate(c0$age, c0$y, o0)
    for (id in ids) {
        f <- r$full[[id]]$fit
        e <- residuals(f)
        h <- if (id == "GAM") 
            f$hat
        else hatvalues(f)
        p <- if (id == "GAM") 
            sum(f$edf)
        else length(coef(f))
        s2 <- sum(e^2)/(13 - p)
        cook <- e^2/(p * s2) * h/(1 - h)^2
        rs_all[[length(rs_all) + 1]] <- data.frame(cause = cs, scale = sc, model = id, age_midpoint_years = c0$age, 
            residual = as.numeric(e))
        dg[[length(dg) + 1]] <- data.frame(cause = cs, scale = sc, model = id, resid_sd = sqrt(sum(e^2)/13), 
            max_abs_std_resid = max(abs(e/sqrt(s2 * (1 - h)))), age_max_resid = c0$age[which.max(abs(e))], 
            max_leverage = max(h), age_max_leverage = maximum_ages(h, c0$age), max_cooks_d = max(cook), 
            age_max_cooks_d = c0$age[which.max(cook)])
    }
}

dg <- do.call(rbind, dg)

write.csv(dg, out_path("robustness", "fit_diagnostics.csv"), row.names = FALSE)

write.csv(do.call(rbind, rs_all), out_path("robustness", "residuals_main.csv"), row.names = FALSE)

cat("\nDIAGNOSTICS: age group with the largest Cook's distance, by model, over the 10 curves\n")

print(table(model = dg$model, age = dg$age_max_cooks_d))

