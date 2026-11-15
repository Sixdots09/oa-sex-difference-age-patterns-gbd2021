# Shared model fitting and classification rules.
suppressPackageStartupMessages(library(mgcv))
suppressPackageStartupMessages(library(splines))

default_opts <- function() {
  return(list(
    grid = seq(45, 80, by = 5),
    k_linear = 3, k_hinge = 5, k_ns = 4, k_cubic = 5,
    ns_knot = 62.5, gam_k = 5, gam_method = "ML",
    gam_count = "loglik", ic_thresh = 2,
    exact_drop = 3, within_drop = 1, exact_tol = 0,
    amb_dist = 5, block = 1
  ))
}

ic_from <- function(negative_twice_loglik, sample_size, parameter_count) {
  bic <- negative_twice_loglik + parameter_count * log(sample_size)
  aicc <- negative_twice_loglik + 2 * parameter_count +
    2 * parameter_count * (parameter_count + 1) /
    (sample_size - parameter_count - 1)
  return(c(bic = bic, aicc = aicc, k = parameter_count))
}

ic_rss <- function(rss, sample_size, parameter_count) {
  negative_twice_loglik <- sample_size *
    (log(2 * pi) + 1 + log(rss / sample_size))
  return(ic_from(negative_twice_loglik, sample_size, parameter_count))
}

mk <- function(age, y) {
  return(data.frame(age = age, ca = age - 62.5,
                    z = (age - 62.5) / 30, y = y))
}

fit_all <- function(data, options) {
  sample_size <- nrow(data)
  models <- list()

  fit <- lm(y ~ ca, data)
  criteria <- ic_rss(sum(resid(fit)^2), sample_size, options$k_linear)
  models$LINEAR <- list(fit = fit, ic = criteria)

  candidates <- list()
  candidate_bic <- numeric(length(options$grid))
  for (index in seq_along(options$grid)) {
    candidate_age <- options$grid[index]
    candidate_data <- data
    candidate_data$h <- pmax(0, data$age - candidate_age)
    fit <- lm(y ~ ca + h, candidate_data)
    criteria <- ic_rss(sum(resid(fit)^2), sample_size, options$k_hinge)
    candidates[[index]] <- list(b = candidate_age, fit = fit, ic = criteria)
    candidate_bic[index] <- criteria[["bic"]]
  }
  candidate_order <- order(candidate_bic, options$grid)
  candidates <- candidates[candidate_order]
  best_candidate <- candidates[[1]]
  models$HINGE <- list(fit = best_candidate$fit, ic = best_candidate$ic,
                      b = best_candidate$b, all = candidates)

  fit <- lm(y ~ ns(age, knots = options$ns_knot,
                   Boundary.knots = c(32.5, 92.5)), data)
  criteria <- ic_rss(sum(resid(fit)^2), sample_size, options$k_ns)
  models$NS <- list(fit = fit, ic = criteria)

  fit <- lm(y ~ z + I(z^2) + I(z^3), data)
  criteria <- ic_rss(sum(resid(fit)^2), sample_size, options$k_cubic)
  models$CUBIC <- list(fit = fit, ic = criteria)

  fit <- gam(y ~ s(age, bs = "tp", k = options$gam_k),
             data = data, method = options$gam_method)
  log_likelihood <- logLik(fit)
  if (options$gam_count == "loglik") {
    parameter_count <- as.numeric(attr(log_likelihood, "df"))
  } else if (options$gam_count == "edf") {
    parameter_count <- sum(fit$edf) + 1
  } else if (options$gam_count == "full") {
    parameter_count <- options$gam_k + 1
  } else {
    stop("Unknown GAM parameter-count rule.")
  }
  criteria <- ic_from(-2 * as.numeric(log_likelihood), sample_size, parameter_count)
  converged <- isTRUE(fit$converged) &&
    identical(fit$outer.info$conv, "full convergence")
  models$GAM <- list(fit = fit, ic = criteria, conv = converged)
  return(models)
}

pred1 <- function(models, model_name, age) {
  new_data <- data.frame(age = age, ca = age - 62.5, z = (age - 62.5) / 30)
  if (model_name == "HINGE") {
    new_data$h <- pmax(0, age - models$HINGE$b)
  }
  return(as.numeric(predict(models[[model_name]]$fit, newdata = new_data)))
}

ids <- c("LINEAR", "HINGE", "NS", "CUBIC", "GAM")
smooth_ids <- c("NS", "CUBIC", "GAM")

adjudicate <- function(age, y, o = default_opts()) {
  data <- mk(age, y)
  sample_size <- nrow(data)
  models <- fit_all(data, o)
  bic <- setNames(numeric(5), ids)
  aicc <- setNames(numeric(5), ids)
  parameter_counts <- setNames(numeric(5), ids)
  for (model_name in ids) {
    bic[model_name] <- models[[model_name]]$ic[["bic"]]
    aicc[model_name] <- models[[model_name]]$ic[["aicc"]]
    parameter_counts[model_name] <- models[[model_name]]$ic[["k"]]
  }

  # First require a uniquely supported changepoint versus a line.
  candidate_bic <- numeric(length(models$HINGE$all))
  candidate_age <- numeric(length(models$HINGE$all))
  for (index in seq_along(models$HINGE$all)) {
    candidate <- models$HINGE$all[[index]]
    candidate_bic[index] <- candidate$ic[["bic"]]
    candidate_age[index] <- candidate$b
  }
  linear_advantage <- bic[["LINEAR"]] - min(candidate_bic)
  competitive <- candidate_age[
    candidate_bic <= min(candidate_bic) + o$ic_thresh + 1e-12]
  ambiguous <- any(abs(competitive - models$HINGE$b) >= o$amb_dist)
  if (linear_advantage < o$ic_thresh) {
    original_rule <- "NO_BREAK"
  } else if (ambiguous) {
    original_rule <- "AMBIGUOUS"
  } else {
    original_rule <- "UNIQUE_BREAK"
  }

  # Each fold removes one age group, or an adjacent block.
  fold_count <- sample_size - o$block + 1
  errors <- NULL
  fold_age <- numeric(fold_count)
  fold_support <- logical(fold_count)
  gam_converged <- models$GAM$conv
  for (fold in seq_len(fold_count)) {
    removed <- fold:(fold + o$block - 1)
    training_models <- fit_all(data[-removed, ], o)
    gam_converged <- gam_converged && training_models$GAM$conv
    fold_errors <- matrix(NA_real_, nrow = length(removed), ncol = 5)
    for (index in seq_along(ids)) {
      predicted <- pred1(training_models, ids[index], data$age[removed])
      fold_errors[, index] <- data$y[removed] - predicted
    }
    errors <- rbind(errors, fold_errors)
    fold_age[fold] <- training_models$HINGE$b
    fold_support[fold] <- training_models$LINEAR$ic[["bic"]] -
      training_models$HINGE$ic[["bic"]] >= o$ic_thresh
  }
  colnames(errors) <- ids
  rmse <- sqrt(colMeans(errors^2))
  exact_count <- sum(fold_support &
    abs(fold_age - models$HINGE$b) <= o$exact_tol + 1e-9)
  within_five_count <- sum(fold_support & abs(fold_age - models$HINGE$b) <= 5)

  bic_advantage <- min(bic[smooth_ids]) - bic[["HINGE"]]
  aicc_advantage <- min(aicc[smooth_ids]) - aicc[["HINGE"]]
  cv_advantage <- min(rmse[smooth_ids]) - rmse[["HINGE"]]
  changepoint_preferred <- original_rule == "UNIQUE_BREAK" &&
    bic_advantage >= o$ic_thresh && aicc_advantage >= o$ic_thresh &&
    cv_advantage > 0 && exact_count >= fold_count - o$exact_drop &&
    within_five_count >= fold_count - o$within_drop

  other_models <- setdiff(ids, "HINGE")
  dominant_models <- other_models[
    bic[["HINGE"]] - bic[other_models] >= o$ic_thresh &
    aicc[["HINGE"]] - aicc[other_models] >= o$ic_thresh &
    rmse[other_models] < rmse[["HINGE"]]]
  if (changepoint_preferred) {
    status <- "CHANGEPOINT_PREFERRED"
  } else if (length(dominant_models) > 0) {
    status <- "NON_CHANGEPOINT_PREFERRED"
  } else {
    status <- "INCONCLUSIVE"
  }

  return(list(
    status = status, dominant = paste(dominant_models, collapse = ";"),
    boundary = models$HINGE$b, orig = original_rule,
    d_lin_hinge = linear_advantage, adv_bic = bic_advantage,
    adv_aicc = aicc_advantage, adv_cv = cv_advantage,
    exact = exact_count, within5 = within_five_count, nfolds = fold_count,
    bic = bic, aicc = aicc, rmse = rmse, k = parameter_counts,
    best = c(BIC = names(which.min(bic)), AICc = names(which.min(aicc)),
             CV = names(which.min(rmse))),
    gam_converged = gam_converged, err = errors, full = models, data = data
  ))
}

row_of <- function(label, cause, scale, result) {
  return(data.frame(
    analysis = label, cause = cause, scale = scale, status = result$status,
    dominant = result$dominant, boundary = result$boundary,
    orig_rule = result$orig, adv_bic = result$adv_bic,
    adv_aicc = result$adv_aicc, adv_cv = result$adv_cv,
    exact = result$exact, within5 = result$within5,
    best_bic = result$best[["BIC"]], best_aicc = result$best[["AICc"]],
    best_cv = result$best[["CV"]], gam_edf_k = result$k[["GAM"]],
    gam_converged = result$gam_converged, stringsAsFactors = FALSE
  ))
}

load_main_curves <- function(path = "outputs/main/age_curves_main.csv") {
  curves <- read.csv(path, stringsAsFactors = FALSE)
  curves <- curves[curves$used_in_models, ]
  columns <- c(ratio = "log_rate_ratio", diff = "rate_difference_per_100000")
  result <- list()
  for (category in c("Overall", "Hip", "Knee", "Hand", "Other")) {
    for (scale in names(columns)) {
      data <- curves[curves$category == category, ]
      data <- data[order(data$age_midpoint_years), ]
      stopifnot(nrow(data) == 13,
                identical(data$age_midpoint_years, seq(32.5, 92.5, 5)),
                all(is.finite(data[[columns[[scale]]]])))
      result[[paste(category, scale)]] <- list(
        cause = category, scale = scale,
        age = data$age_midpoint_years, y = data[[columns[[scale]]]])
    }
  }
  return(result)
}

ab <- c(CHANGEPOINT_PREFERRED = "C", NON_CHANGEPOINT_PREFERRED = "n", INCONCLUSIVE = "?")
