# Country-level direction of the female-male contrast and its correlation with the Socio-demographic Index (SDI),

source(file.path("R", "setup.R"))

set.seed(20261112)

yrs <- c(1990, 2000, 2010, 2021)

nm <- c(`Bolivarian Republic of Venezuela` = "Venezuela (Bolivarian Republic of)", `Commonwealth of the Bahamas` = "Bahamas", 
    `Czech Republic` = "Czechia", `Federated States of Micronesia` = "Micronesia (Federated States of)", 
    `Islamic Republic of Iran` = "Iran (Islamic Republic of)", `Kingdom of Eswatini` = "Eswatini", 
    `Plurinational State of Bolivia` = "Bolivia (Plurinational State of)", `Principality of Monaco` = "Monaco", 
    `Republic of Cabo Verde` = "Cabo Verde", `Republic of Côte d'Ivoire` = "Côte d'Ivoire", 
    `Republic of Nauru` = "Nauru", `Republic of Niue` = "Niue", `Republic of Palau` = "Palau", 
    `Republic of San Marino` = "San Marino", `Republic of the Gambia` = "Gambia", `Socialist Republic of Viet Nam` = "Viet Nam", 
    Turkey = "Türkiye", `United Kingdom of Great Britain and Northern Ireland` = "United Kingdom", 
    `Taiwan (Province of China)` = "Taiwan")

canon <- function(x) {
    x <- iconv(x, from = "UTF-8", to = "UTF-8", sub = "?")
    i <- match(x, names(nm))
    x[!is.na(i)] <- unname(nm[i[!is.na(i)]])
    x[grepl("te d'Ivoire$", x) & !grepl("^Republic", x)] <- "Côte d'Ivoire"
    x[grepl("rkiye$", x)] <- "Türkiye"
    x
}

ckeys <- c(Overall = "country_overall", Hip = "country_hip", Knee = "country_knee", Hand = "country_hand", 
    Other = "country_other")

country_tables <- list()

for (cs in names(ckeys)) {
    d <- read_gbd(ckeys[[cs]])
    d <- d[grepl("^DALY", d$measure) & d$age == "Age-standardized" & d$metric == "Rate" & d$year %in% 
        yrs & d$sex %in% c("Female", "Male"), ]
    check_records(d, c("location", "sex", "year"), 204 * 2 * 4, paste("Country age-standardized DALY rates:", 
        cs))
    f <- d[d$sex == "Female", c("location", "year", "val", "lower", "upper")]
    m <- d[d$sex == "Male", c("location", "year", "val", "lower", "upper")]
    names(f)[3:5] <- c("female_val", "female_lower", "female_upper")
    names(m)[3:5] <- c("male_val", "male_lower", "male_upper")
    x <- merge(f, m, by = c("location", "year"))
    x$cause_label <- cs
    country_tables[[cs]] <- x
}

cd <- do.call(rbind, country_tables)

cd$location_name <- canon(cd$location)

cd$location <- NULL

stopifnot(nrow(cd) == 204 * 4 * 5, length(unique(cd$location_name)) == 204, all(table(cd$location_name, 
    cd$cause_label) == 4))

sdi <- read.csv(raw_path("sdi"), check.names = FALSE, stringsAsFactors = FALSE)

stopifnot(all(c("location", "year", "SDI") %in% names(sdi)), nrow(sdi) == 23552, !anyNA(sdi[c("location", 
    "year", "SDI")]), all(is.finite(sdi$SDI)), all(sdi$SDI > 0 & sdi$SDI <= 1))

check_set(sdi$year, 1990:2021, "SDI year")

sdi$location <- canon(sdi$location)

sdi <- sdi[sdi$location %in% unique(cd$location_name) & sdi$year %in% yrs, ]

geo <- sdi[sdi$location == "Georgia", ]

georgia_rows <- list()

for (year in yrs) {
    group <- geo[geo$year == year, ]
    stopifnot(nrow(group) >= 1)
    georgia_rows[[as.character(year)]] <- group[which.min(group$SDI), ]
}

geo <- do.call(rbind, georgia_rows)

sdi <- rbind(sdi[sdi$location != "Georgia", ], geo)

names(sdi)[1] <- "location_name"

stopifnot(nrow(sdi) == 204 * 4, !anyDuplicated(sdi[c("location_name", "year")]))

pop <- read_gbd("country_both_sexes_overall")

pop$location_name <- canon(pop$location)

pop <- pop[pop$age == "All ages" & grepl("^DALY", pop$measure), ]

pn <- pop[pop$metric == "Number", c("location_name", "year", "val")]

pr <- pop[pop$metric == "Rate", c("location_name", "year", "val")]

pp <- merge(pn, pr, by = c("location_name", "year"))

pp$pop <- pp$val.x/pp$val.y * 1e+05

pp <- pp[c("location_name", "year", "pop")]

stopifnot(!anyDuplicated(pp[c("location_name", "year")]), nrow(pp) == 204 * 32, all(is.finite(pp$pop)), 
    all(pp$pop > 0))

add <- function(d) {
    d <- merge(d, pp, by = c("location_name", "year"), all.x = TRUE)
    stopifnot(!anyNA(d$pop))
    d$lrr <- log(d$female_val/d$male_val)
    d$rd <- d$female_val - d$male_val
    d$uiw <- (log(d$female_upper/d$female_lower) + log(d$male_upper/d$male_lower))/2
    d[order(d$cause_label, d$year, tolower(chartr("ôü", "ou", d$location_name)), method = "radix"), 
        ]
}

sd <- add(merge(cd, sdi, by = c("location_name", "year")))

cd <- add(cd)

stopifnot(nrow(sd) == 204 * 4 * 5)

cat(sprintf("World population implied, 2021: %.2f billion (204 locations)\n", sum(pp$pop[pp$year == 
    2021])/1e+09))

wrank <- function(x, w) {
    if (anyDuplicated(x)) 
        stop("Weighted ranks require untied values in this analysis.")
    o <- order(x)
    cw <- cumsum(w[o])
    r <- numeric(length(x))
    r[o] <- cw - w[o]/2
    r
}

wcor <- function(a, b, w) {
    w <- w/sum(w)
    ma <- sum(w * a)
    mb <- sum(w * b)
    sum(w * (a - ma) * (b - mb))/sqrt(sum(w * (a - ma)^2) * sum(w * (b - mb)^2))
}

wspear <- function(x, y, w) wcor(wrank(x, w), wrank(y, w), w)

spear <- function(x, y) cor(rank(x), rank(y))

wq <- function(x, w, p = 0.5) {
    o <- order(x)
    cw <- cumsum(w[o])/sum(w)
    x[o][which(cw >= p)[1]]
}

direction_rows <- list()

for (cs in CATEGORIES) {
    for (y in yrs) {
        g <- cd[cd$cause_label == cs & cd$year == y, ]
        direction_rows[[length(direction_rows) + 1]] <- data.frame(cause = cs, year = y, n = nrow(g), 
            prop_female_higher = mean(g$lrr > 0), pop_share_female_higher = sum(g$pop[g$lrr > 
                0])/sum(g$pop), median_rr = exp(median(g$lrr)), pop_weighted_median_rr = exp(wq(g$lrr, 
                g$pop)), prop_female_higher_narrow_ui_half = mean(g$lrr[g$uiw <= median(g$uiw)] > 
                0), ui_width_p05 = exp(quantile(g$uiw, 0.05)), ui_width_p95 = exp(quantile(g$uiw, 
                0.95)))
    }
}

dirs <- do.call(rbind, direction_rows)

rownames(dirs) <- NULL

write.csv(dirs, out_path("country", "country_direction_weighted.csv"), row.names = FALSE)

B <- 5000

rows <- list()

for (cs in CATEGORIES) for (y in yrs) for (sc in c("lrr", "rd")) {
    g204 <- sd[sd$cause_label == cs & sd$year == y, ]
    stopifnot(nrow(g204) == 204)
    g <- g204[g204$location_name != "Georgia", ]
    rho <- spear(g[[sc]], g$SDI)
    n <- nrow(g)
    bs <- numeric(B)
    for (replicate in seq_len(B)) {
        sampled_rows <- sample.int(n, replace = TRUE)
        bs[replicate] <- spear(g[[sc]][sampled_rows], g$SDI[sampled_rows])
    }
    nar <- g$uiw <= median(g$uiw)
    rows[[length(rows) + 1]] <- data.frame(cause = cs, year = y, scale = c(lrr = "ratio", rd = "diff")[[sc]], 
        n_countries = n, rho = rho, ci_low = quantile(bs, 0.025), ci_high = quantile(bs, 0.975), 
        rho_population_weighted = wspear(g[[sc]], g$SDI, g$pop), rho_interval_width_weighted = wspear(g[[sc]], 
            g$SDI, 1/g$uiw^2), rho_narrow_ui_half = spear(g[[sc]][nar], g$SDI[nar]))
}

res <- do.call(rbind, rows)

rownames(res) <- NULL

write.csv(res, out_path("country", "sdi_correlations_bootstrap_weighted.csv"), row.names = FALSE)

cat(sprintf("SDI correlations: %d of %d bootstrap intervals exclude 0; sign differs with population weighting in %d of %d\n", 
    sum(res$ci_low > 0 | res$ci_high < 0), nrow(res), sum(sign(res$rho) != sign(res$rho_population_weighted)), 
    nrow(res)))

