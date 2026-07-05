library(data.table)
library(sf)
library(ggiraph)
library(ggplot2)
library(patchwork)

options(datatable.week = "sequential")

# data files
data <- fread("data/dengue_data.csv")
popu <- fread("data/district_population.csv")
map <- read_sf("~/Downloads/lka_admin_boundaries.geojson/lka_admin2.geojson")

# only these columns in the map data are needed
map_cols <- c("adm2_name", "area_sqkm", "center_lat", "center_lon", "geometry")
map[setdiff(names(map), map_cols)] <- NULL
names(map)[c(1, 2)] <- c("district", "area")


# kalmune is a city in ampara, and some district names in data dont match those in
# shape file
data[, let(
  district = fcase(
    district == "Hambanthota", "Hambantota",
    district == "NuwaraEliya", "Nuwara Eliya",
    district == "Kalmune", "Ampara",
    default = district
  )
)][, cases := sum(cases, na.rm = TRUE), by = .(district, start.date, end.date)]

# create new columns
data[, let(
  year = as.integer(year(end.date)),
  month = as.integer(month(end.date)),
  monthL = as.character(format(end.date, "%B")),
  epiweek = as.character(week(end.date))
)]

population <- setNames(popu[["pop_000"]], popu[["district"]])

# colors
pallets <- list(
  c(
    "#245668FF", "#0F7279FF", "#0D8F81FF", "#39AB7EFF",
    "#6EC574FF", "#A9DC67FF", "#EDEF5DFF"
  ),
  c(
    "#4D004DFF", "#660066FF", "#800080FF", "#BA3241FF",
    "#F46404FF", "#ED9A2DFF", "#E7D057FF", "#E8D879FF", "#E9E09CFF"
  )
)

# district wise dengue incident map - 2026
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
    aes(fill = incident, data_id = cases, tooltip = tooltip),
    color = "white", linewidth = 0.2
  )

  # theme
  this_theme <- theme_void() +
    theme(
      aspect.ratio = 12.5 / 7,
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
    breaks = seq(30, 300, 30), transform = "reverse",
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

# top 10 districts - 2026 (compared with last year)
fig_2 <- local({
  # calculate district totals for 2025, 2026 for months Jan:May
  df <- data[
    year %in% c(2025, 2026) & monthL %in% month.name[1:5],
    .(cases = sum(cases, na.rm = TRUE)),
    by = .(year, district)
  ]

  df[, tooltip := sprintf("reported cases: %i (%i)", cases, year)]
  setorder(df, -cases)

  this_geom <- geom_col_interactive(
    aes(reorder(district, cases), cases,
      fill = district,
      data_id = district, tooltip = tooltip
    )
  )
  this_theme <- theme_void() +
    theme(
      legend.position = "none",
      plot.title = element_text(hjust = 0.5)
    )

  fig1 <- ggplot(df[year == 2026, head(.SD, 10)]) +
    this_geom +
    geom_text(
      aes(district, cases,
        label = district,
        hjust = ifelse(cases / max(cases) > 0.7, -.2, 1.2)
      ), ,
      color = "darkblue", fontface = "bold"
    ) +
    scale_y_reverse() +
    coord_flip() +
    labs(
      title = "Top 10 Districts - 2026"
    ) +
    this_theme


  fig2 <- ggplot(df[year == 2025, head(.SD, 10)]) +
    this_geom +
    geom_text(
      aes(district, cases,
        label = district,
        hjust = ifelse(cases / max(cases) > 0.7, 1.2, -.2)
      ), ,
      color = "darkblue", fontface = "bold"
    ) +
    coord_flip() +
    labs(
      title = "Top 10 Districts - 2025"
    ) +
    this_theme

  fig1 + fig2
})
