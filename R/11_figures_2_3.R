# Figure 2 (joint-specific female-male age curves) and Figure 3 (age curves and five-model comparison, main analysis).

source(file.path("R", "setup.R"))

suppressPackageStartupMessages({
    library(ggplot2)
    library(patchwork)
})

ggplot2::update_geom_defaults("text", list(family = FONT))

cur <- read.csv(out_path("main", "age_curves_main.csv"), stringsAsFactors = FALSE)

cur <- cur[cur$used_in_models, ]

plot_data <- data.frame(cause_label = cur$category, age_midpoint_years = cur$age_midpoint_years, 
    equal_weight_mean_annual_geometric_mean_rate_ratio_female_over_male = cur$rate_ratio, equal_weight_mean_annual_absolute_rate_difference_female_minus_male_per_100000 = cur$rate_difference_per_100000, 
    stringsAsFactors = FALSE)

decisions <- read.csv(out_path("main", "model_comparison_main.csv"), stringsAsFactors = FALSE)

stopifnot(nrow(plot_data) == 65, nrow(decisions) == 10)

cause_levels <- CATEGORIES

joint_levels <- c("Knee", "Hand", "Hip", "Other")

status_short <- c(NON_CHANGEPOINT_PREFERRED = "Non-changepoint", INCONCLUSIVE = "Inconclusive", 
    CHANGEPOINT_PREFERRED = "Changepoint")

cause_colors <- c(Overall = "#222222", Hip = "#6C78A8", Knee = "#0072B2", Hand = "#D55E00", 
    Other = "#009E73")

model_colors <- c(Linear = "#E3E3E3", Changepoint = "#E8C5D8", `Natural spline` = "#C7E3F1", 
    Cubic = "#F4D48D", GAM = "#A8DCC9", `Non-changepoint` = "#A9CBE1", Inconclusive = "#F2B27D")

model_short <- c(LINEAR = "Linear", HINGE = "Changepoint", NS = "Natural spline", CUBIC = "Cubic", 
    GAM = "GAM")

theme_fig <- function() {
    theme_bw(base_size = 9, base_family = FONT) + theme(panel.grid.minor = element_blank(), 
        panel.grid.major = element_line(linewidth = 0.25, colour = "#E8E8E8"), axis.title = element_text(size = 9), 
        axis.text = element_text(size = 8, colour = "#222222"), strip.text = element_text(size = 9, 
            face = "bold"), strip.background = element_rect(fill = "#F2F2F2", colour = "#C8C8C8"), 
        plot.title = element_text(size = 10, face = "bold"), plot.subtitle = element_text(size = 8.2, 
            colour = "#444444"), plot.caption = element_text(size = 8, colour = "#444444", 
            hjust = 0), legend.text = element_text(size = 8), legend.title = element_text(size = 8, 
            face = "bold"), plot.margin = margin(5, 7, 5, 5))
}

long_plot <- rbind(data.frame(cause_label = plot_data$cause_label, age = plot_data$age_midpoint_years, 
    scale = "Relative: female/male rate ratio", value = plot_data$equal_weight_mean_annual_geometric_mean_rate_ratio_female_over_male, 
    stringsAsFactors = FALSE), data.frame(cause_label = plot_data$cause_label, age = plot_data$age_midpoint_years, 
    scale = "Absolute: female-minus-male rate difference", value = plot_data$equal_weight_mean_annual_absolute_rate_difference_female_minus_male_per_100000, 
    stringsAsFactors = FALSE))

long_plot$cause_label <- factor(long_plot$cause_label, levels = cause_levels)

make_joint_column <- function(scale_key, display_title, reference, y_label) {
    d <- long_plot[long_plot$cause_label %in% joint_levels & long_plot$scale == scale_key, 
        ]
    d$cause_label <- factor(as.character(d$cause_label), levels = joint_levels)
    endpoint <- d[d$age == max(d$age), ]
    ggplot(d, aes(age, value, group = cause_label, colour = cause_label)) + geom_hline(yintercept = reference, 
        linetype = 2, linewidth = 0.4, colour = "#6F6F6F") + geom_line(linewidth = 0.75) + 
        geom_point(size = 1.8, shape = 21, fill = "white", stroke = 0.65) + geom_text(data = endpoint, 
        aes(x = 94.5, label = cause_label), hjust = 0, size = 2.85, fontface = "bold", show.legend = FALSE) + 
        facet_grid(cause_label ~ ., scales = "fixed") + scale_colour_manual(values = cause_colors, 
        guide = "none") + scale_x_continuous(breaks = c(35, 55, 75, 95), limits = c(32.5, 102), 
        expand = expansion(mult = c(0.01, 0.01))) + labs(title = display_title, x = "Age-group midpoint (years)", 
        y = y_label) + theme_fig() + theme(panel.spacing.y = grid::unit(3, "mm"), strip.placement = "outside")
}

p2_rel <- make_joint_column("Relative: female/male rate ratio", "Relative disparity: F/M rate ratio", 
    1, "Female/male DALY-rate ratio")

p2_abs <- make_joint_column("Absolute: female-minus-male rate difference", "Absolute disparity: F-M rate difference", 
    0, "DALY-rate difference per 100,000")

figure2 <- (p2_rel | p2_abs) + plot_annotation(title = "Joint-specific female-male osteoarthritis burden across age", 
    subtitle = "Equal-year means of annual GBD estimates, 1990-2021; points are the 13 five-year age groups", 
    caption = "Horizontal dashed lines mark equality (ratio 1; difference 0). No transition age or preferred change point is shown.", 
    theme = theme(plot.title = element_text(family = FONT, size = 11, face = "bold"), plot.subtitle = element_text(family = FONT, 
        size = 8.5), plot.caption = element_text(family = FONT, size = 8, hjust = 0)))

make_overview <- function(scale_label, reference, y_label, title) {
    d <- long_plot[long_plot$scale == scale_label, ]
    endpoint <- d[d$age == max(d$age), ]
    ggplot(d, aes(age, value, colour = cause_label)) + geom_hline(yintercept = reference, linetype = 2, 
        linewidth = 0.4, colour = "#6F6F6F") + geom_line(linewidth = 0.78) + geom_point(size = 1.35) + 
        scale_colour_manual(values = cause_colors, breaks = cause_levels, drop = FALSE) + scale_x_continuous(breaks = c(35, 
        55, 75, 95), limits = c(32.5, 92.5)) + labs(title = title, x = "Age-group midpoint (years)", 
        y = y_label, colour = NULL) + theme_fig() + theme(legend.position = "top", legend.direction = "horizontal")
}

p3a <- make_overview("Relative: female/male rate ratio", 1, "Female/male DALY-rate ratio", 
    "Relative trajectories")

p3b <- make_overview("Absolute: female-minus-male rate difference", 0, "DALY-rate difference per 100,000", 
    "Absolute trajectories")

matrix_parts <- list()

for (i in seq_len(nrow(decisions))) {
    d <- decisions[i, ]
    estimand <- if (d$scale == "ratio") 
        "F/M"
    else "F-M"
    matrix_parts[[i]] <- data.frame(curve = paste(d$cause, estimand, sep = " · "), criterion = c("BIC", 
        "AICc", "LOOCV", "Disposition"), label = c(unname(model_short[d$best_bic]), unname(model_short[d$best_aicc]), 
        unname(model_short[d$best_cv]), status_short[[d$status]]), stringsAsFactors = FALSE)
}

matrix_rows <- do.call(rbind, matrix_parts)

curve_order <- character(0)

for (category in cause_levels) {
    curve_order <- c(curve_order, paste(category, c("F/M", "F-M"), sep = " · "))
}

matrix_rows$curve <- factor(matrix_rows$curve, levels = rev(curve_order))

matrix_rows$criterion <- factor(matrix_rows$criterion, levels = c("BIC", "AICc", "LOOCV", "Disposition"))

matrix_rows$fill <- factor(matrix_rows$label, levels = names(model_colors))

classification_labels <- c("Non-changepoint", "Changepoint", "Inconclusive")

classification_rows <- matrix_rows[matrix_rows$label %in% classification_labels, ]

model_rows <- matrix_rows[!matrix_rows$label %in% classification_labels, ]

p3c <- ggplot(matrix_rows, aes(criterion, curve, fill = fill)) + geom_tile(colour = "white", 
    linewidth = 0.9) + geom_text(aes(label = c(`Non-changepoint` = "Non-\nchange-\npoint", 
    Changepoint = "Change-\npoint", Inconclusive = "Incon-\nclusive")[label]), data = classification_rows, 
    size = 2.6, colour = "#171717", lineheight = 0.78, nudge_y = 0.02) + geom_text(aes(label = label), 
    data = model_rows, size = 2.95, colour = "#171717", lineheight = 0.88) + annotate("rect", 
    xmin = 0.51, xmax = 4.49, ymin = 3.51, ymax = 4.49, fill = NA, colour = "#7A3E78", linewidth = 0.65) + 
    scale_fill_manual(values = model_colors, drop = FALSE, name = NULL) + scale_x_discrete(labels = c(BIC = "BIC", 
    AICc = "AICc", LOOCV = "LOOCV\nRMSE", Disposition = "Classifi-\ncation")) + labs(title = "Best model and classification", 
    subtitle = "F/M, relative; F-M, absolute. Lower values indicate better fit.", x = NULL, 
    y = NULL) + theme_fig() + theme(panel.grid = element_blank(), axis.text.x = element_text(angle = 0, 
    hjust = 0.5, lineheight = 0.9), axis.text.y = element_text(size = 8.2), legend.position = "none", 
    plot.margin = margin(5, 12, 5, 7))

hand <- decisions[decisions$cause == "Hand" & decisions$scale == "ratio", ]

stopifnot(nrow(hand) == 1)

hand_adv <- c(hand$adv_bic, hand$adv_aicc, hand$adv_cv)

hand_metrics <- data.frame(metric = c("BIC", "AICc", "LOOCV RMSE"), y = c(3, 2, 1), direction = ifelse(hand_adv > 
    0, 0.72, -0.72), label = c(sprintf("%+.4f", hand$adv_bic), sprintf("%+.4f", hand$adv_aicc), 
    sprintf("%+.6f", hand$adv_cv)), preference = ifelse(hand_adv > 0, "Changepoint", "Non-changepoint"), 
    stringsAsFactors = FALSE)

p3d <- ggplot(hand_metrics, aes(direction, y, colour = preference)) + annotate("rect", xmin = -1, 
    xmax = 0, ymin = 0.68, ymax = 3.68, fill = "#F2F7FA", colour = NA) + annotate("rect", xmin = 0, 
    xmax = 1, ymin = 0.68, ymax = 3.68, fill = "#FBF3F7", colour = NA) + geom_hline(yintercept = c(1, 
    2, 3), colour = "#E1E1E1", linewidth = 0.3) + geom_vline(xintercept = 0, colour = "#666666", 
    linewidth = 0.5) + geom_segment(aes(x = 0, xend = direction, yend = y), linewidth = 0.82) + 
    geom_point(size = 3.2) + geom_text(aes(label = label), vjust = -1, size = 2.95, fontface = "bold", 
    show.legend = FALSE) + annotate("text", x = -0.55, y = 3.48, label = "Non-changepoint", 
    fontface = "bold", size = 2.95) + annotate("text", x = 0.55, y = 3.48, label = "Changepoint", 
    fontface = "bold", size = 2.95) + annotate("rect", xmin = -0.93, xmax = 0.93, ymin = -0.38, 
    ymax = 0.48, fill = "#FFF7EC", colour = "#B56A23", linewidth = 0.38) + annotate("text", 
    x = 0, y = 0.28, label = "Location reproduced in folds", fontface = "bold", size = 2.85) + 
    annotate("text", x = 0, y = 0.06, label = sprintf("%d/%d exact · %d/%d within 5 years", 
        hand$exact, hand$n_folds, hand$within5, hand$n_folds), size = 2.85) + annotate("text", 
    x = 0, y = -0.22, label = paste("Classification:", tolower(status_short[[hand$status]])), 
    fontface = "bold", size = 2.95) + scale_colour_manual(values = c(`Non-changepoint` = "#2C7FB8", 
    Changepoint = "#CC79A7"), guide = "none") + scale_x_continuous(limits = c(-1, 1), breaks = NULL, 
    expand = expansion(mult = 0)) + scale_y_continuous(breaks = c(3, 2, 1), labels = c("BIC", 
    "AICc", "LOOCV RMSE")) + coord_cartesian(ylim = c(-0.42, 3.7), clip = "off") + labs(title = "Hand F/M: criteria disagree", 
    subtitle = "Position shows direction;\nlabels show criterion differences.", x = NULL, y = NULL) + 
    theme_fig() + theme(panel.grid = element_blank(), axis.ticks = element_blank(), axis.text.x = element_blank(), 
    axis.text.y = element_text(size = 8.2), panel.border = element_rect(colour = "#8A8A8A", 
        linewidth = 0.45), plot.margin = margin(5, 7, 5, 9))

p3a <- p3a + theme(legend.position = "top")

p3b <- p3b + theme(legend.position = "none")

p3c <- p3c + theme(legend.position = "none")

p3d <- p3d + theme(legend.position = "none")

figure3 <- ((p3a | p3b)/(p3c | p3d)) + plot_layout(heights = c(0.9, 1.15), widths = c(1.16, 
    0.84)) + plot_annotation(title = "Age trajectories of GBD estimates and five-model comparison (main analysis)", 
    caption = paste0("The matrix reports relative preference among prespecified candidate models.\n", 
        "It does not identify the data-generating mechanism or establish any model as biologically correct."), 
    tag_levels = "A", theme = theme(plot.title = element_text(family = FONT, size = 11, face = "bold"), 
        plot.caption = element_text(family = FONT, size = 8, hjust = 0), plot.tag = element_text(family = FONT, 
            size = 11, face = "bold")))

draw_figure2 <- function() {
    print(figure2)
}

draw_figure3 <- function() {
    print(figure3)
}

save_pdf_tiff(draw_figure2, "Figure_2", 17.35/2.54, 22.8/2.54, 800)

save_pdf_tiff(draw_figure3, "Figure_3", 17.35/2.54, 22.8/2.54, 800)

