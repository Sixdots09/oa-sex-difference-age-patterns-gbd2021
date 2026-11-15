# Fixed-seed simulations. Usage: Rscript R/07_simulation.R 2 [1,2,3,4|none]
source("R/setup.R")
source("R/engine.R")
suppressPackageStartupMessages(library(parallel))

arguments <- commandArgs(trailingOnly = TRUE)
cores <- 2L
run_batches <- 1:4
if (length(arguments) >= 1) {
  cores <- as.integer(arguments[1])
}
if (length(arguments) >= 2) {
  if (arguments[2] == "none") {
    run_batches <- integer(0)
  } else {
    run_batches <- as.integer(strsplit(arguments[2], ",")[[1]])
  }
}
stopifnot(!is.na(cores), cores >= 1, all(run_batches %in% 1:4))
if (.Platform$OS.type == "windows" && cores > 1) {
  stop("Use one core on Windows.")
}
BATCHES <- data.frame(batch = 1:4, reps = c(35L, 65L, 40L, 60L))
curves <- load_main_curves()
options <- default_opts()
age <- curves[[1]]$age
sample_size <- 13L
candidate_grid <- options$grid

linear_matrix <- function(age) {
  return(cbind(1, age - 62.5))
}
spline_matrix <- function(age) {
  return(cbind(1, ns(age, knots = 62.5, Boundary.knots = c(32.5, 92.5))))
}
cubic_matrix <- function(age) {
  centered_age <- (age - 62.5) / 30
  return(cbind(1, centered_age, centered_age^2, centered_age^3))
}
changepoint_matrix <- function(age, changepoint) {
  return(cbind(1, age - 62.5, pmax(0, age - changepoint)))
}
prepare_ols <- function(design, new_design) {
  coefficient_map <- solve(crossprod(design), t(design))
  residual_map <- diag(nrow(design)) - design %*% coefficient_map
  prediction_map <- NULL
  if (!is.null(new_design)) {
    prediction_map <- new_design %*% coefficient_map
  }
  return(list(residual_map = residual_map, prediction_map = prediction_map))
}

# Reuse age-only matrices across simulated response curves.
prepared_fits <- list()
for (removed in 0:sample_size) {
  training_rows <- setdiff(1:sample_size, removed)
  training_age <- age[training_rows]
  new_age <- NULL
  new_linear <- NULL
  new_spline <- NULL
  new_cubic <- NULL
  if (removed > 0) {
    new_age <- age[removed]
    new_linear <- linear_matrix(new_age)
    new_spline <- spline_matrix(new_age)
    new_cubic <- cubic_matrix(new_age)
  }
  gam_setup <- gam(y ~ s(age, bs = "tp", k = 5),
    data = data.frame(age = training_age, y = training_age / 100 + sin(training_age / 9)),
    method = "ML", fit = FALSE)
  gam_prediction_matrix <- NULL
  if (removed > 0) {
    temporary_gam <- gam(G = gam_setup, method = "ML")
    gam_prediction_matrix <- predict(temporary_gam,
      newdata = data.frame(age = new_age), type = "lpmatrix")
  }
  changepoints <- list()
  for (candidate_age in candidate_grid) {
    new_hinge <- NULL
    if (removed > 0) {
      new_hinge <- changepoint_matrix(new_age, candidate_age)
    }
    changepoints[[length(changepoints) + 1]] <- prepare_ols(
      changepoint_matrix(training_age, candidate_age), new_hinge)
  }
  prepared_fits[[removed + 1]] <- list(
    training_rows = training_rows,
    LINEAR = prepare_ols(linear_matrix(training_age), new_linear),
    NS = prepare_ols(spline_matrix(training_age), new_spline),
    CUBIC = prepare_ols(cubic_matrix(training_age), new_cubic),
    HINGE = changepoints, gam_setup = gam_setup,
    gam_prediction_matrix = gam_prediction_matrix)
}

fast_fit <- function(prepared, response) {
  training_response <- response[prepared$training_rows]
  training_size <- length(training_response)
  hinge_rss <- numeric(length(candidate_grid))
  for (index in seq_along(candidate_grid)) {
    residuals <- prepared$HINGE[[index]]$residual_map %*% training_response
    hinge_rss[index] <- sum(residuals^2)
  }
  best_hinge <- which.min(hinge_rss)
  gam_setup <- prepared$gam_setup
  gam_setup$y <- training_response
  gam_fit <- gam(G = gam_setup, method = "ML")
  if (!isTRUE(gam_fit$converged) ||
      !identical(gam_fit$outer.info$conv, "full convergence")) {
    stop("A simulation GAM did not converge.")
  }
  log_likelihood <- logLik(gam_fit)
  linear_rss <- sum((prepared$LINEAR$residual_map %*% training_response)^2)
  spline_rss <- sum((prepared$NS$residual_map %*% training_response)^2)
  cubic_rss <- sum((prepared$CUBIC$residual_map %*% training_response)^2)
  criteria <- rbind(
    LINEAR = ic_rss(linear_rss, training_size, 3),
    HINGE = ic_rss(hinge_rss[best_hinge], training_size, 5),
    NS = ic_rss(spline_rss, training_size, 4),
    CUBIC = ic_rss(cubic_rss, training_size, 5),
    GAM = ic_from(-2 * as.numeric(log_likelihood), training_size,
                  as.numeric(attr(log_likelihood, "df"))))
  hinge_bic <- numeric(length(candidate_grid))
  for (index in seq_along(candidate_grid)) {
    hinge_bic[index] <- ic_rss(hinge_rss[index], training_size, 5)[["bic"]]
  }
  predicted <- NULL
  if (!is.null(prepared$gam_prediction_matrix)) {
    predicted <- c(
      LINEAR = prepared$LINEAR$prediction_map %*% training_response,
      HINGE = prepared$HINGE[[best_hinge]]$prediction_map %*% training_response,
      NS = prepared$NS$prediction_map %*% training_response,
      CUBIC = prepared$CUBIC$prediction_map %*% training_response,
      GAM = prepared$gam_prediction_matrix %*% coef(gam_fit))
  }
  return(list(criteria = criteria, boundary = candidate_grid[best_hinge],
              hinge_bic = hinge_bic, predicted = predicted))
}

fast_classify <- function(response) {
  full <- fast_fit(prepared_fits[[1]], response)
  bic <- full$criteria[, "bic"]
  aicc <- full$criteria[, "aicc"]
  linear_advantage <- bic[["LINEAR"]] - min(full$hinge_bic)
  competitive <- candidate_grid[full$hinge_bic <= min(full$hinge_bic) + 2 + 1e-12]
  if (linear_advantage < 2) {
    original_rule <- "NO_BREAK"
  } else if (any(abs(competitive - full$boundary) >= 5)) {
    original_rule <- "AMBIGUOUS"
  } else {
    original_rule <- "UNIQUE_BREAK"
  }
  errors <- matrix(NA_real_, sample_size, 5, dimnames = list(NULL, ids))
  fold_age <- numeric(sample_size)
  fold_support <- logical(sample_size)
  for (fold in 1:sample_size) {
    fit <- fast_fit(prepared_fits[[fold + 1]], response)
    errors[fold, ] <- response[fold] - fit$predicted[ids]
    fold_age[fold] <- fit$boundary
    fold_support[fold] <- fit$criteria["LINEAR", "bic"] -
      fit$criteria["HINGE", "bic"] >= 2
  }
  rmse <- sqrt(colMeans(errors^2))
  exact_count <- sum(fold_support & fold_age == full$boundary)
  within_five_count <- sum(fold_support & abs(fold_age - full$boundary) <= 5)
  bic_advantage <- min(bic[smooth_ids]) - bic[["HINGE"]]
  aicc_advantage <- min(aicc[smooth_ids]) - aicc[["HINGE"]]
  cv_advantage <- min(rmse[smooth_ids]) - rmse[["HINGE"]]
  changepoint_preferred <- original_rule == "UNIQUE_BREAK" &&
    bic_advantage >= 2 && aicc_advantage >= 2 && cv_advantage > 0 &&
    exact_count >= 10 && within_five_count >= 12
  other_models <- setdiff(ids, "HINGE")
  dominant <- other_models[bic[["HINGE"]] - bic[other_models] >= 2 &
    aicc[["HINGE"]] - aicc[other_models] >= 2 & rmse[other_models] < rmse[["HINGE"]]]
  status <- "?"
  if (changepoint_preferred) {
    status <- "C"
  } else if (length(dominant) > 0) {
    status <- "n"
  }
  return(list(status = status, boundary = full$boundary, adv_bic = bic_advantage))
}

# Check the accelerated implementation before simulation.
set.seed(1)
for (curve_name in names(curves)) {
  response <- curves[[curve_name]]$y
  test_curves <- list(response,
    response + rnorm(sample_size, 0, sd(response) / 20),
    response + rnorm(sample_size, 0, sd(response) / 5))
  for (test_response in test_curves) {
    reference <- adjudicate(age, test_response, options)
    accelerated <- fast_classify(test_response)
    stopifnot(identical(unname(ab[reference$status]), accelerated$status),
      reference$boundary == accelerated$boundary,
      isTRUE(all.equal(reference$adv_bic, accelerated$adv_bic, tolerance = 1e-6)))
  }
}
cat("Accelerated and reference implementations agree on 30 curves.\n")

scenarios <- list()
for (curve_name in names(curves)) {
  comparison <- adjudicate(age, curves[[curve_name]]$y, options)
  smooth_model <- smooth_ids[which.min(comparison$bic[smooth_ids])]
  rss <- numeric(4)
  noise_models <- c("HINGE", smooth_ids)
  for (index in seq_along(noise_models)) {
    rss[index] <- sum(residuals(comparison$full[[noise_models[index]]]$fit)^2)
  }
  noise_sd <- sqrt(min(rss) / sample_size)
  for (truth in c("smooth", "changepoint")) {
    truth_model <- smooth_model
    if (truth == "changepoint") {
      truth_model <- "HINGE"
    }
    for (rho in c(0, 0.5, 0.8)) {
      for (multiplier in c(1, 2)) {
        scenarios[[length(scenarios) + 1]] <- list(
          curve = curve_name, truth = truth, rho = rho, multiplier = multiplier,
          sigma = noise_sd * multiplier, true_boundary = comparison$boundary,
          mean_response = as.numeric(fitted(comparison$full[[truth_model]]$fit)),
          smooth_model = smooth_model)
      }
    }
  }
}

run_scenario <- function(index, reps, batch) {
  scenario <- scenarios[[index]]
  set.seed(20261112 + index + 1000L * batch)
  statuses <- character(reps)
  boundaries <- numeric(reps)
  for (replicate in seq_len(reps)) {
    independent_noise <- rnorm(sample_size)
    noise <- independent_noise
    if (scenario$rho > 0) {
      for (point in 2:sample_size) {
        noise[point] <- scenario$rho * noise[point - 1] +
          sqrt(1 - scenario$rho^2) * independent_noise[point]
      }
    }
    response <- scenario$mean_response + scenario$sigma * noise
    result <- fast_classify(response)
    statuses[replicate] <- result$status
    boundaries[replicate] <- result$boundary
  }
  at_true_location <- boundaries == scenario$true_boundary
  return(data.frame(
    curve = scenario$curve, truth = scenario$truth, rho = scenario$rho,
    noise_mult = scenario$multiplier, sigma = scenario$sigma,
    true_changepoint = scenario$true_boundary, smooth_model = scenario$smooth_model,
    reps = reps, n_C = sum(statuses == "C"), n_n = sum(statuses == "n"),
    n_q = sum(statuses == "?"), n_loc = sum(at_true_location),
    n_C_loc = sum(statuses == "C" & at_true_location),
    p_changepoint_preferred = mean(statuses == "C"),
    p_non_changepoint_preferred = mean(statuses == "n"),
    p_inconclusive = mean(statuses == "?"), p_location_exact = mean(at_true_location),
    p_cp_preferred_at_true_location = mean(statuses == "C" & at_true_location)))
}

for (batch in run_batches) {
  start_time <- proc.time()[3]
  # mclapply distributes independent scenarios; each has its own seed.
  results <- mclapply(seq_along(scenarios), run_scenario,
    reps = BATCHES$reps[batch], batch = batch, mc.cores = cores,
    mc.preschedule = FALSE)
  for (result in results) {
    if (inherits(result, "try-error")) {
      stop("A simulation worker failed; no batch output was saved.")
    }
  }
  results <- do.call(rbind, results)
  stopifnot(nrow(results) == 120)
  write.csv(results, out_path("simulation", paste0("simulation_batch", batch, ".csv")),
            row.names = FALSE)
  cat("Batch", batch, "completed in", round(proc.time()[3] - start_time), "seconds.\n")
}

all_batches <- list()
for (batch in 1:4) {
  path <- out_path("simulation", paste0("simulation_batch", batch, ".csv"))
  if (!file.exists(path)) {
    stop("Missing simulation batch: ", path)
  }
  results <- read.csv(path)
  stopifnot(nrow(results) == 120, all(results$reps == BATCHES$reps[batch]),
            all(results$n_C + results$n_n + results$n_q == results$reps))
  for (index in seq_along(scenarios)) {
    scenario <- scenarios[[index]]
    stopifnot(results$curve[index] == scenario$curve,
      results$truth[index] == scenario$truth, results$rho[index] == scenario$rho,
      results$noise_mult[index] == scenario$multiplier,
      results$true_changepoint[index] == scenario$true_boundary,
      results$smooth_model[index] == scenario$smooth_model,
      isTRUE(all.equal(results$sigma[index], scenario$sigma, tolerance = 1e-10)))
  }
  all_batches[[batch]] <- results
}
results <- do.call(rbind, all_batches)
pooled <- aggregate(cbind(reps, n_C, n_n, n_q) ~ truth + noise_mult + rho, results, sum)
pooled <- data.frame(truth = pooled$truth, noise_multiplier = pooled$noise_mult,
  ar1_rho = pooled$rho, simulated_curves = pooled$reps,
  p_changepoint_preferred = pooled$n_C / pooled$reps,
  p_non_changepoint_preferred = pooled$n_n / pooled$reps,
  p_inconclusive = pooled$n_q / pooled$reps)
pooled <- pooled[order(match(pooled$truth, c("smooth", "changepoint")),
                        pooled$noise_multiplier, pooled$ar1_rho), ]
stopifnot(all(pooled$simulated_curves == 2000))
write.csv(pooled, out_path("simulation", "simulation_pooled_summary.csv"), row.names = FALSE)
print(pooled, digits = 3, row.names = FALSE)
