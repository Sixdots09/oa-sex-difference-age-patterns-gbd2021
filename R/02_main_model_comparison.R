# Main analysis: five-model comparison for the ten category-by-measure curves (Table 2; Figure 3C-D).

source(file.path("R", "setup.R"))

source(file.path("R", "engine.R"))

cv <- load_main_curves()

o <- default_opts()

dec <- list()

fits <- list()

cand <- list()

for (nm in names(cv)) {
    c0 <- cv[[nm]]
    r <- adjudicate(c0$age, c0$y, o)
    x <- row_of("Main analysis", c0$cause, c0$scale, r)
    x$linear_minus_changepoint_bic <- r$d_lin_hinge
    x$n_folds <- r$nfolds
    dec[[nm]] <- x
    fits[[nm]] <- data.frame(cause = c0$cause, scale = c0$scale, model = ids, parameter_count = unname(r$k[ids]), 
        bic = unname(r$bic[ids]), aicc = unname(r$aicc[ids]), loocv_rmse = unname(r$rmse[ids]), 
        stringsAsFactors = FALSE)
    candidate_ages <- numeric(length(r$full$HINGE$all))
    candidate_bic <- numeric(length(r$full$HINGE$all))
    for (index in seq_along(r$full$HINGE$all)) {
        candidate_ages[index] <- r$full$HINGE$all[[index]]$b
        candidate_bic[index] <- r$full$HINGE$all[[index]]$ic[["bic"]]
    }
    cand[[nm]] <- data.frame(cause = c0$cause, scale = c0$scale, candidate_changepoint_age = candidate_ages, 
        bic = candidate_bic, stringsAsFactors = FALSE)
    cand[[nm]] <- cand[[nm]][order(cand[[nm]]$candidate_changepoint_age), ]
}

dec <- do.call(rbind, dec)

fits <- do.call(rbind, fits)

cand <- do.call(rbind, cand)

stopifnot(all(dec$gam_converged), nrow(dec) == 10, nrow(fits) == 50)

write.csv(dec, out_path("main", "model_comparison_main.csv"), row.names = FALSE)

write.csv(fits, out_path("main", "model_fits_main.csv"), row.names = FALSE)

write.csv(cand, out_path("main", "changepoint_candidates_main.csv"), row.names = FALSE)

print(dec[c("cause", "scale", "status", "boundary", "adv_bic", "adv_aicc", "adv_cv", "exact", 
    "within5")], row.names = FALSE, digits = 4)

cat("\nClassification counts:\n")

print(table(dec$status))

