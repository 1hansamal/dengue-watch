library(data.table)
library(sf)
library(ggplot2)
library(patchwork)


options(datatable.week = "sequential")

# data files
data <- fread("data/dengue_data.csv")
popu <- fread("data/district_population.csv")
map <- read_sf("data/lka_admin2.geojson")

# only these columns in the map data are needed
map_cols <- c("adm2_name", "area_sqkm", "center_lat", "center_lon", "geometry")
map[setdiff(names(map), map_cols)] <- NULL
names(map)[c(1, 2)] <- c("district", "area")


# kalmune is a city in ampara, and some district names in data dont match those in
# shape file
data[, let(
  district = fcase(
    district == "Hambanthota" , "Hambantota"   ,
    district == "NuwaraEliya" , "Nuwara Eliya" ,
    district == "Kalmune"     , "Ampara"       ,
    default = district
  )
)][, cases := sum(cases, na.rm = TRUE), by = .(district, start.date, end.date)]

# create new columns
data[, let(
  start.date = as.POSIXct(start.date),
  end.date = as.POSIXct(end.date),
  year = year(start.date),
  month = month(start.date),
  epiweek = isoweek(start.date)
)]

population <- setNames(popu[["pop_000"]], popu[["district"]])

# colors
pallets <- list(
  c(
    "#245668FF",
    "#0F7279FF",
    "#0D8F81FF",
    "#39AB7EFF",
    "#6EC574FF",
    "#A9DC67FF",
    "#EDEF5DFF"
  ),
  c(
    "#4D004DFF",
    "#660066FF",
    "#800080FF",
    "#BA3241FF",
    "#F46404FF",
    "#ED9A2DFF",
    "#E7D057FF",
    "#E8D879FF",
    "#E9E09CFF"
  )
)

# district wise dengue incident map - 2026 =====================================
fig_1 <- local({
  # calculate district wise cases & tooltip text
  df <- data[year == 2026, .(cases = sum(cases, na.rm = TRUE)), by = district]

  df[, let(
    incident = (cases / population[district]) * 100,
    tooltip = sprintf("%s, total cases: %i", district, cases)
  )]

  map <- merge(map, df, by = "district")

  # geom
  this_geom <- geom_sf_interactive(
    aes(fill = incident, data_id = district, tooltip = tooltip),
    color = "white",
    linewidth = 0.2
  )

  # theme
  this_theme <- theme_void() +
    theme(
      aspect.ratio = 12.5 / 7,
      base_size = 12,
      legend.position = c(0.65, 0.95),
      legend.text = element_text(size = 10),
      panel.background = element_blank(),
      plot.caption = element_text(size = 10),
      plot.caption.position = "panel",
      margins = margin(0, 0, 0, 0)
    )

  # color legend
  this_colorbar <- scale_fill_continuous(
    palette = pallets[[1]],
    breaks = seq(30, 300, 30),
    transform = "reverse",
    guide = guide_legend(
      title = "Incident rate (per 100,000)",
      keyheight = unit(5, units = "pt"),
      keywidth = unit(10, units = "pt"),
      label.position = "bottom",
      title.position = "top",
      nrow = 1
    )
  )

  # plot
  ggplot(map) + this_geom + this_colorbar + this_theme
})

fig_12 <- local({
  monthly_totals <- data[year == 2026, .(total_cases = sum(cases)), by = month]
  setorder(monthly_totals, month)

  ggplot(monthly_totals, aes(x = factor(month), y = total_cases)) +
    geom_col(fill = "steelblue") +
    geom_text(aes(label = total_cases), vjust = -0.5) +
    labs(title = "Monthly Total Dengue Cases - 2026", x = "Month", y = "Total Cases")
})

fig_cumulative <- local({
  df <- data[
    year %in% c(2025, 2026) & month %in% 1:5,
    .(cases = sum(cases, na.rm = TRUE)),
    by = .(year, epiweek)
  ]
  setorder(df, year, epiweek)
  df[, cum_cases := cumsum(cases), by = year]
  df[, tooltip := sprintf("week %i (%i): %i cumulative cases", epiweek, year, cum_cases)]

  ggplot(df, aes(x = epiweek, y = cum_cases, color = factor(year), group = year)) +
    geom_line(
      aes(data_id = interaction(year, epiweek), tooltip = tooltip),
      linewidth = 1
    ) +
    scale_color_manual(
      values = c("2025" = "steelblue", "2026" = "darkred"),
      name = "Year"
    ) +
    labs(
      title = "Cumulative Dengue Cases (Jan–May)",
      x = "Epidemiological Week",
      y = "Cumulative Cases"
    ) +
    theme_minimal()
})

fig_boxplot <- local({
  df <- data[year == 2026]

  ggplot(df, aes(x = reorder(district, cases, median), y = cases)) +
    geom_boxplot(fill = "steelblue", outlier.color = "darkred", outlier.alpha = 0.6) +
    coord_flip() +
    labs(
      title = "Distribution of Weekly Cases by District - 2026",
      x = "District",
      y = "Weekly Cases"
    ) +
    theme_minimal()
})

fig_small_multiples <- local({
  df <- data[, .(cases = sum(cases, na.rm = TRUE)), by = .(year, epiweek)]

  ggplot(df, aes(x = epiweek, y = cases)) +
    geom_line(color = "darkred", linewidth = 0.4) +
    facet_wrap(~year, ncol = 6) +
    labs(title = "Weekly Case Curve by Year", x = "Epidemiological Week", y = "Cases") +
    theme_minimal(base_size = 8) +
    theme(strip.text = element_text(face = "bold"))
})

fig_growth_rate <- local({
  df <- data[year == 2026, .(cases = sum(cases, na.rm = TRUE)), by = epiweek]
  setorder(df, epiweek)
  df[, growth := (cases / shift(cases) - 1) * 100]
  df[, tooltip := sprintf("week %i: %.1f%% change", epiweek, growth)]

  ggplot(df[!is.na(growth)], aes(x = epiweek, y = growth, fill = growth > 0)) +
    geom_col(aes(data_id = epiweek, tooltip = tooltip)) +
    scale_fill_manual(
      values = c("TRUE" = "darkred", "FALSE" = "steelblue"),
      guide = "none"
    ) +
    geom_hline(yintercept = 0, color = "black", linewidth = 0.3) +
    labs(
      title = "Week-over-Week Growth Rate - 2026",
      x = "Epidemiological Week",
      y = "% Change"
    ) +
    theme_minimal()
})

fig_district_corr <- local({
  df <- dcast(
    data[year > 2015],
    start.date ~ district,
    value.var = "cases",
    fun = sum,
    fill = 0
  )
  mat <- cor(df[, -"start.date"], use = "pairwise.complete.obs")

  corr_dt <- as.data.table(as.table(mat))
  setnames(corr_dt, c("district_x", "district_y", "correlation"))

  ggplot(corr_dt, aes(x = district_x, y = district_y, fill = correlation)) +
    geom_tile() +
    scale_fill_viridis_c(option = "magma") +
    labs(
      title = "Correlation of Weekly Cases Between Districts",
      x = NULL,
      y = NULL,
      fill = "Corr."
    ) +
    theme_minimal() +
    theme(
      axis.text.x = element_text(angle = 90, hjust = 1, size = 7),
      axis.text.y = element_text(size = 7)
    )
})

fig_13 <- local({
  district_totals <- data[year == 2026, .(total_cases = sum(cases)), by = district]

  setorder(district_totals, -total_cases)

  # plot
  ggplot(district_totals, aes(x = reorder(district, -total_cases), y = total_cases)) +
    geom_col(fill = "steelblue") +
    geom_text(aes(label = total_cases), vjust = -0.5, size = 3) +
    labs(title = "District-wise Dengue Cases - 2026", x = "District", y = "Total Cases") +
    theme_minimal() +
    theme(axis.text.x = element_text(angle = 45, hjust = 1))
})

# top 10 districts - 2026 (compared with last year) ============================
fig_2 <- local({
  # calculate district totals for 2025, 2026 for months Jan:May
  df <- data[
    year %in% c(2025, 2026) & month %in% 1:5,
    .(cases = sum(cases, na.rm = TRUE)),
    by = .(year, district)
  ]

  df[, tooltip := sprintf("reported cases: %i (%i)", cases, year)]
  setorder(df, -cases)

  this_geom <- geom_col_interactive(aes(
    reorder(district, cases),
    cases,
    fill = district,
    data_id = district,
    tooltip = tooltip
  ))
  this_theme <- theme_void() +
    theme(legend.position = "none", plot.title = element_text(hjust = 0.5))

  fig1 <- ggplot(df[year == 2026, head(.SD, 10)]) +
    this_geom +
    geom_text(
      aes(
        district,
        cases,
        label = district,
        hjust = ifelse(cases / max(cases) > 0.7, -.2, 1.2)
      ),
      color = "darkblue",
      fontface = "bold"
    ) +
    scale_y_reverse() +
    coord_flip() +
    labs(title = "Top 10 Districts - 2026") +
    this_theme

  fig2 <- ggplot(df[year == 2025, head(.SD, 10)]) +
    this_geom +
    geom_text(
      aes(
        district,
        cases,
        label = district,
        hjust = ifelse(cases / max(cases) > 0.7, 1.2, -.2)
      ),
      color = "darkblue",
      fontface = "bold"
    ) +
    coord_flip() +
    labs(title = "Top 10 Districts - 2025") +
    this_theme

  fig1 + fig2
})

# weekly time series - 2026 ====================================================
fig_3 <- local({
  df <- data[year %in% 2025:2026 & month %in% 1:5]

  df_wide <- dcast(df, epiweek ~ year, value.var = "cases", fun = sum, fill = 0)
  df_wide[, let(
    tooltip_25 = sprintf("epi. week - %i: cases %i (2025)", epiweek, `2025`),
    tooltip_26 = sprintf("epi. week - %i: cases %i (2026)", epiweek, `2026`)
  )]

  epiweek_labs <- df_wide[, sprintf("week-%i", epiweek)]

  this_theme <- theme(
    aspect.ratio = 0.1,
    plot.background = element_blank(),
    panel.background = element_blank(),
    line = element_line(linewidth = 1)
  )

  fig <- ggplot(df_wide, aes(x = epiweek, group = 1)) +
    geom_line_interactive(
      aes(y = `2026`, data_id = `2026`, tooltip = tooltip_26),
      color = "magenta"
    ) +
    geom_line_interactive(
      aes(y = `2025`, data_id = `2025`, tooltip = tooltip_25),
      color = "blue"
    ) +
    ggh4x::stat_difference(aes(ymin = `2025`, ymax = `2026`), alpha = 0.3) +
    scale_x_continuous(
      breaks = 1:22,
      labels = epiweek_labs,
      guide = guide_axis(
        title = "Epidemiological week",
        check.overlap = TRUE,
        n.dodge = 3
      )
    ) +
    this_theme

  girafe(fig)
})

# heat map of 2026 =============================================================
fig_4 <- local({
  data_2026 <- data[year == 2026]
  data_2026[, day := as.integer(format(start.date, "%d"))]

  ggplot(data_2026, aes(x = epiweek, y = district, fill = cases)) +
    geom_tile(color = "white") +
    scale_fill_viridis_c(option = "inferno", direction = -1) +
    scale_x_continuous(breaks = seq(1, 31, by = 5)) +
    labs(
      title = "Dengue Cases by District - 2026",
      x = "Day of Month",
      y = "District",
      fill = "Cases"
    ) +
    theme(
      axis.text.x = element_text(angle = 90, vjust = 0.5, hjust = 1),
      strip.text = element_text(face = "bold")
    )
})

# stl decomposition ============================================================
fig_55 <- local({
  df <- data[year > 2006, .(cases = sum(cases, na.rm = TRUE)), by = .(year, start.date)]

  # unbroken weekly skeleton
  all_weeks <- seq(
    from = min(df[["start.date"]]),
    to = max(df[["start.date"]]),
    by = "1 week"
  )
  calendar_skel <- data.table(start.date = all_weeks)

  # Right-Join to expose the gaps (all missing weeks will show as NA)
  df_complete <- df[calendar_skel, on = .(start.date)]

  # fill gaps using linear interpolation
  df_complete[, cases_filled := approx(start.date, cases, xout = start.date)[["y"]]]

  decomp <- stl(
    ts(df_complete[["cases_filled"]], frequency = 52),
    s.window = 21,
    t.window = 121,
    robust = TRUE
  )

  decomp_values <- decomp[["time.series"]]

  df_complete[, `:=`(
    seasonal = decomp_values[, "seasonal"],
    trend = decomp_values[, "trend"],
    random = decomp_values[, "remainder"]
  )]

  # 1. Observed / actual cases
  p_cases <- ggplot(df_complete, aes(x = start.date, y = cases_filled)) +
    geom_line(color = "black", linewidth = 0.4) +
    labs(title = "Observed", x = NULL, y = "Cases") +
    theme_minimal(base_size = 11)

  # 2. Seasonal component
  p_seasonal <- ggplot(df_complete, aes(x = start.date, y = seasonal)) +
    geom_line(color = "#1b9e77", linewidth = 0.4) +
    labs(title = "Seasonal", x = NULL, y = "Seasonal") +
    theme_minimal(base_size = 11)

  # 3. Trend component
  p_trend <- ggplot(df_complete, aes(x = start.date, y = trend)) +
    geom_line(color = "#d95f02", linewidth = 0.4) +
    labs(title = "Trend", x = NULL, y = "Trend") +
    theme_minimal(base_size = 11)

  # 4. Random / remainder component
  p_random <- ggplot(df_complete, aes(x = start.date, y = random)) +
    geom_line(color = "#7570b3", linewidth = 0.4) +
    labs(title = "Random", x = "Date", y = "Random") +
    theme_minimal(base_size = 11)

  # Combine in rows (stacked vertically), one plot per row
  combined_plot <- p_cases /
    p_seasonal /
    p_trend /
    p_random +
    plot_annotation(title = "STL Decomposition of Weekly Cases")

  combined_plot
})

# seasonal indexes =============================================================
fig_5 <- local({
  seasonal <- data[, .(total_cases = sum(cases)), by = .(year, month)]

  seasonal_index <- seasonal[, .(avg_cases = mean(total_cases)), by = month]
  seasonal_index[, index := avg_cases / mean(avg_cases)]

  setorder(seasonal_index, month)

  ggplot(seasonal_index, aes(x = month, y = index)) +
    geom_col(fill = "steelblue") +
    geom_hline(yintercept = 1, linetype = "dashed", color = "red") +
    scale_x_continuous(breaks = 1:12) +
    labs(
      title = "Seasonal Index of Dengue Cases by Month",
      x = "Calendar Month",
      y = "Seasonal Index (Mean = 1)"
    )
})

# monthly dengue cases; auto-correlation =======================================
fig_6 <- local({
  df <- data[, .(cases = sum(cases, na.rm = TRUE)), by = .(year, month)]
  setorder(df, year, month)

  ts_cases <- ts(df$cases, start = c(df$year[1], df$month[1]), frequency = 12)
  acf_vals <- acf(ts_cases, plot = FALSE, lag.max = 24)
  acf_dt <- data.table(lag = acf_vals$lag[, 1, 1], acf = acf_vals$acf[, 1, 1])
  ci <- qnorm((1 + 0.95) / 2) / sqrt(acf_vals$n.used)
  acf_dt$tooltip <- with(acf_dt, sprintf("lag %f:\nacf %.2f", lag, acf))

  girafe({
    ggplot(acf_dt, aes(lag, acf)) +
      geom_col_interactive(
        aes(data_id = acf, tooltip = tooltip),
        fill = "darkred",
        width = 0.05
      ) +
      geom_hline(yintercept = c(-ci, ci), linetype = "dashed", color = "steelblue") +
      labs(
        title = "Autocorrelation of Monthly Dengue Cases",
        x = "Lag (months)",
        y = "ACF"
      ) +
      theme_minimal()
  })
})


leflet_map <- local({
  df <- data[, .(cases = sum(cases, na.rm = TRUE)), by = .(year, district)]
})
