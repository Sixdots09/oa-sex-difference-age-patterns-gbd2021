# Figure 1: global burden of osteoarthritis, 1990-2021 (eight descriptive panels, A-H).

source(file.path("R", "setup.R"))

suppressPackageStartupMessages({
    library(ggplot2)
    library(scales)
    library(grid)
})

d <- read_gbd("global_overall_burden")

d <- d[d$location == "Global", ]

PREV <- "Prevalence"

DALY <- "DALYs (Disability-Adjusted Life Years)"

measure_short <- c(Prevalence = "Prevalence", `DALYs (Disability-Adjusted Life Years)` = "DALYs")

site_of <- c(`Osteoarthritis knee` = "Knee", `Osteoarthritis hip` = "Hip", `Osteoarthritis hand` = "Hand", 
    `Osteoarthritis other` = "Other")

site_levels <- c("Knee", "Hip", "Hand", "Other")

site_colors <- c(Knee = "#4A90E2", Hip = "#E88FD8", Hand = "#6FD88F", Other = "#F4E676")

sex_colors <- c(Female = "#E88388", Male = "#6BA3D0")

age_levels <- paste0(c(paste0(seq(30, 90, 5), "-", seq(34, 94, 5)), "95+"), " years")

theme_fig1 <- function(base_size = 9) {
    theme_classic(base_family = FONT, base_size = base_size) + theme(text = element_text(colour = "#202020"), 
        plot.title = element_text(size = base_size + 1.5, hjust = 0.5, margin = margin(b = 2.5)), 
        plot.subtitle = element_text(size = base_size - 0.2, hjust = 0.5, colour = "#4A4A4A", 
            margin = margin(b = 2.5)), axis.title = element_text(size = base_size), axis.text = element_text(size = base_size - 
            0.5, colour = "#202020"), axis.line = element_line(linewidth = 0.45, colour = "#202020"), 
        axis.ticks = element_line(linewidth = 0.35, colour = "#202020"), legend.position = "top", 
        legend.justification = "center", legend.title = element_blank(), legend.text = element_text(size = base_size - 
            0.5), legend.key.width = unit(3.4, "mm"), legend.key.height = unit(2.8, "mm"), 
        legend.spacing.x = unit(1, "mm"), plot.margin = margin(3, 7, 3, 4))
}

site_numbers <- function(measure) {
    x <- d[d$measure == measure & d$metric == "Number" & d$age == "All ages" & d$sex == "Both" & 
        d$cause %in% names(site_of), ]
    check_records(x, c("cause", "year"), 128, paste("Figure 1: numbers by site,", measure_short[[measure]]))
    x$site <- factor(unname(site_of[x$cause]), levels = site_levels)
    x[order(x$year, x$site), ]
}

panel_time_number <- function(measure) {
    number <- site_numbers(measure)
    number$millions <- number$val/1e+06
    rate <- d[d$measure == measure & d$metric == "Rate" & d$age == "Age-standardized" & d$sex == 
        "Both" & d$cause == "Osteoarthritis", ]
    check_records(rate, "year", 32, paste("Figure 1: age-standardized rate,", measure_short[[measure]]))
    rate <- rate[order(rate$year), ]
    annual_totals <- numeric(32)
    for (index in 1:32) {
        year <- 1989 + index
        annual_totals[index] <- sum(number$val[number$year == year])
    }
    k <- max(annual_totals)/max(rate$val)/1e+06
    rate$display_millions <- rate$val * k
    ggplot() + geom_col(data = number, aes(x = year, y = millions, fill = site), position = "stack", 
        width = 0.88, linewidth = 0) + geom_line(data = rate, aes(x = year, y = display_millions), 
        colour = "#222222", linewidth = 0.65) + scale_fill_manual(values = site_colors, breaks = site_levels, 
        drop = FALSE) + scale_x_continuous(breaks = c(1990, 2000, 2010, 2021), expand = expansion(mult = c(0.01, 
        0.015))) + scale_y_continuous(name = paste0(measure_short[[measure]], " (millions)"), 
        labels = label_number(accuracy = 1), expand = expansion(mult = c(0, 0.08)), sec.axis = sec_axis(~./k, 
            name = "Rate per 100,000")) + labs(title = paste0("Global ", measure_short[[measure]], 
        ", 1990-2021"), subtitle = "Both sexes; number (bars); age-standardized rate (line)", 
        x = NULL) + theme_fig1()
}

panel_time_proportion <- function(measure) {
    x <- site_numbers(measure)
    x$proportion <- x$val/ave(x$val, x$year, FUN = sum)
    ggplot(x, aes(x = year, y = proportion, fill = site)) + geom_col(width = 0.9, linewidth = 0) + 
        scale_fill_manual(values = site_colors, breaks = site_levels, drop = FALSE) + scale_x_continuous(breaks = c(1990, 
        2000, 2010, 2021), expand = expansion(mult = c(0.01, 0.015))) + scale_y_continuous(labels = percent_format(accuracy = 1), 
        expand = c(0, 0)) + coord_cartesian(ylim = c(0, 1)) + labs(title = paste0(measure_short[[measure]], 
        " composition"), subtitle = "Both sexes; four displayed-category shares", x = NULL, 
        y = "Share") + theme_fig1()
}

panel_sex_rate <- function(measure) {
    x <- d[d$measure == measure & d$metric == "Rate" & d$age == "Age-standardized" & d$cause == 
        "Osteoarthritis" & d$sex %in% c("Female", "Male"), ]
    check_records(x, c("sex", "year"), 64, paste("Figure 1: age-standardized rate by sex,", 
        measure_short[[measure]]))
    x$sex <- factor(x$sex, levels = c("Female", "Male"))
    ggplot(x, aes(x = year, y = val, colour = sex, fill = sex)) + geom_ribbon(aes(ymin = lower, 
        ymax = upper), alpha = 0.1, colour = NA) + geom_line(linewidth = 0.75) + geom_point(data = x[x$year %in% 
        c(1990, 2000, 2010, 2021), ], size = 1.5) + scale_colour_manual(values = sex_colors) + 
        scale_fill_manual(values = sex_colors) + scale_x_continuous(breaks = c(1990, 2000, 
        2010, 2021), expand = expansion(mult = c(0.03, 0.07))) + labs(title = paste0(measure_short[[measure]], 
        " rate by sex"), subtitle = "Age-standardized rate (95% UI)", x = NULL, y = "Rate per 100,000") + 
        theme_fig1()
}

panel_age_pyramid <- function(measure) {
    x <- d[d$year == 2021 & d$measure == measure & d$metric == "Number" & d$age %in% age_levels & 
        d$cause %in% names(site_of) & d$sex %in% c("Female", "Male"), ]
    check_records(x, c("cause", "sex", "age"), 112, paste("Figure 1: numbers by age and sex in 2021,", 
        measure_short[[measure]]))
    x$site <- factor(unname(site_of[x$cause]), levels = site_levels)
    x$age <- factor(x$age, levels = age_levels)
    x$display_millions <- ifelse(x$sex == "Female", -x$val, x$val)/1e+06
    ggplot(x, aes(x = age, y = display_millions, fill = site)) + geom_col(width = 0.82, colour = "white", 
        linewidth = 0.15) + coord_flip() + geom_hline(yintercept = 0, linewidth = 0.45, colour = "#303030") + 
        scale_fill_manual(values = site_colors, breaks = site_levels, drop = FALSE) + scale_y_continuous(labels = abs, 
        expand = expansion(mult = c(0.04, 0.04))) + labs(title = paste0(measure_short[[measure]], 
        " by age and sex, 2021"), subtitle = "Number; female left, male right", x = "Age group", 
        y = paste0(measure_short[[measure]], " number (millions)")) + theme_fig1()
}

cat("Record checks\n")

panels <- list(A = panel_time_number(PREV), B = panel_time_number(DALY), C = panel_time_proportion(PREV), 
    D = panel_time_proportion(DALY), E = panel_sex_rate(PREV), F = panel_sex_rate(DALY), G = panel_age_pyramid(PREV), 
    H = panel_age_pyramid(DALY))

PT <- 72/25.4

page_w <- 173.5 * PT

margin <- 7

col_gap <- 6

row_gap <- 4

label_strip <- 12

col_w <- (page_w - 2 * margin - col_gap)/2

row_h <- c(45.2, 45.2, 45.2, 70) * PT

page_h <- 2 * margin + 4 * label_strip + sum(row_h) + 3 * row_gap

draw_figure1 <- function() {
    grid.newpage()
    grid.rect(gp = gpar(fill = "white", col = NA))
    row_top <- page_h - margin
    for (r in 1:4) {
        panel_top <- row_top - label_strip
        for (k in 1:2) {
            id <- LETTERS[2 * (r - 1) + k]
            x <- c(margin, margin + col_w + col_gap)[k]
            print(panels[[id]], vp = viewport(x = unit(x, "bigpts"), y = unit(panel_top - row_h[r], 
                "bigpts"), width = unit(col_w, "bigpts"), height = unit(row_h[r], "bigpts"), 
                just = c("left", "bottom")))
            grid.text(id, x = unit(x, "bigpts"), y = unit(panel_top + 1, "bigpts"), just = c("left", 
                "bottom"), gp = gpar(fontfamily = FONT, fontsize = 10))
        }
        row_top <- panel_top - row_h[r] - row_gap
    }
}

save_pdf_tiff(draw_figure1, "Figure_1", width_in = page_w/72, height_in = page_h/72, dpi = 1200)

