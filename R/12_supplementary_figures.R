# Supplementary figures (Additional file 1).

source(file.path("R", "setup.R"))

panel_layout <- function() {
    layout(rbind(matrix(1:10, 2, 5, byrow = TRUE), rep(11, 5)), heights = c(1, 1, 0.14))
    par(mar = c(3.6, 4, 2.2, 0.7), mgp = c(2.3, 0.7, 0), cex = 0.72, las = 1)
}

bottom_legend <- function(labels, ...) {
    par(mar = c(0, 0, 0, 0))
    plot.new()
    legend("center", labels, ..., horiz = TRUE, bty = "n", cex = 1.05, text.width = max(strwidth(labels, 
        cex = 1.05)) * 1.15)
}

res <- read.csv(out_path("robustness", "residuals_main.csv"), stringsAsFactors = FALSE)

shown <- c("HINGE", "NS", "CUBIC", "GAM")

cols <- c(HINGE = "#D55E00", NS = "#009E73", CUBIC = "#0072B2", GAM = "#CC79A7")

pchs <- c(HINGE = 16, NS = 17, CUBIC = 15, GAM = 18)

pdf(out_path("figures", "Figure_S1_residuals.pdf"), width = 11, height = 5.6)

panel_layout()

for (sc in c("ratio", "diff")) for (cs in CATEGORIES) {
    r <- res[res$cause == cs & res$scale == sc & res$model %in% shown, ]
    r <- r[order(r$age_midpoint_years), ]
    stopifnot(nrow(r) == 4 * 13)
    plot(NA, xlim = c(30, 95), ylim = range(r$residual), xlab = "Age (years)", main = paste0(cs, 
        if (sc == "ratio") 
            ": rate ratio"
        else ": rate difference"), ylab = if (sc == "ratio") 
        "Residual, log rate ratio"
    else "Residual, DALYs per 100,000", las = 0)
    abline(h = 0, lty = 2, col = "grey50")
    for (id in shown) lines(r$age_midpoint_years[r$model == id], r$residual[r$model == id], 
        type = "o", pch = pchs[[id]], cex = 0.7, col = cols[[id]], lwd = 1.2)
}

bottom_legend(c("Changepoint", "Natural spline", "Cubic polynomial", "GAM"), col = cols[shown], 
    pch = pchs[shown], lwd = 1.2)

invisible(dev.off())

cur <- read.csv(out_path("calendar_time", "age_curves_by_weighting_and_period.csv"), stringsAsFactors = FALSE)

periods <- c("1990-1999", "2000-2009", "2010-2021")

cur <- cur[cur$analysis %in% paste("Period", periods), ]

cur$age <- age_midpoint(cur$age_lab)

stopifnot(nrow(cur) == 3 * 5 * 13)

pc <- c("#56B4E9", "#0072B2", "#000000")

pp <- c(17, 15, 16)

pdf(out_path("figures", "Figure_S2_age_curves_by_period.pdf"), width = 11, height = 5.6)

panel_layout()

for (sc in c("ratio", "diff")) for (cs in CATEGORIES) {
    d <- cur[cur$cause == cs, ]
    d <- d[order(d$age), ]
    y <- if (sc == "ratio") 
        d$rate_ratio
    else d$rate_difference_per_100000
    ref <- if (sc == "ratio") 
        1
    else 0
    plot(NA, xlim = c(30, 95), ylim = range(c(y, ref)), xlab = "Age (years)", log = if (sc == 
        "ratio") 
        "y"
    else "", main = paste0(cs, if (sc == "ratio") 
        ": rate ratio"
    else ": rate difference"), ylab = if (sc == "ratio") 
        "Female-to-male DALY rate ratio"
    else "Female minus male, DALYs per 100,000", las = 0)
    abline(h = ref, lty = 2, col = "grey50")
    for (i in 1:3) {
        s <- d$analysis == paste("Period", periods[i])
        lines(d$age[s], y[s], type = "o", pch = pp[i], cex = 0.7, col = pc[i], lwd = 1.3)
    }
}

bottom_legend(periods, col = pc, pch = pp, lwd = 1.3)

invisible(dev.off())

cat("Wrote outputs/figures/Figure_S1_residuals.pdf and Figure_S2_age_curves_by_period.pdf\n")

