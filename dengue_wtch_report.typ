#set page(margin: 2.5cm)
#set text(font: "New Computer Modern", size: 11pt)
#set par(justify: true, leading: 0.65em)
#set heading(numbering: "1.1")
#show link: set text(fill: blue)

#align(center)[
#text(size: 20pt, weight: "bold")[Dengue Watch: Analysis of Dengue Incidence in Sri Lanka, 2026]

#v(0.3cm)
#text(size: 12pt)[A Data Analysis Report]

#v(0.3cm)
#text(size: 12pt)[Index - AS2022560]

#v(0.4cm)
#text(size: 11pt, style: "italic")[Prepared as part of STA 492 Data Visualisation project]

#v(0.2cm)
#text(size: 12pt)[Project Source: #link("https://github.com/1hansamal/dengue-watch.git", )]

#v(0.1cm)
#text(size: 12pt)[Dashboard Link: #link("https://1hansamal.github.io/dengue-watch/dengue_watch.html")]


]

#v(1cm)

= Introduction

This project examines how dengue cases have been distributed across Sri Lanka during 2026,
with the aim of identifying seasonal and geographic patterns in disease transmission.
Dengue remains a major public health concern in Sri Lanka, with outbreaks occurring in recurring waves.
Combining spatial analysis (identifying the districts most affected) with time series analysis
(examining when cases occur) provides a more comprehensive understanding of the outbreak.

= Data

Three data sources were used for this analysis:

+ *Weekly reported dengue cases by district (2007–2025)* — obtained from the `denguedatahub` R package (Talagala, 2026), a tidy-format collection of dengue surveillance datasets by country. See references.
+ *Weekly reported dengue cases by district (2026)* — extracted from the Weekly Epidemiological Report published by the Epidemiology Unit, Ministry of Health, Sri Lanka. See references.
+ *District population data* — mid-year population estimates for 2025, obtained from
  the Department of Census and Statistics, Sri Lanka.
+ *Administrative boundary shapefile* — district-level boundaries of Sri Lanka.

The two case-data sources (historical and 2026) were combined into a single dataset with a
consistent structure — district, reporting date, and weekly case count — prior to analysis.

Several district names in the case data did not match those in the administrative boundary data
(for example, "Hambanthota" instead of "Hambantota", and "NuwaraEliya" instead of "Nuwara Eliya"),
so these were corrected using a lookup table.

It was also identified that "Kalmune", which is a city within the Ampara district,
had been treated as a separate district. These records were merged into Ampara,
after which the data were aggregated so that each district-date combination appeared only once.

Additional date-based variables (year, month, and epidemiological week) were created from the reporting
dates to support subsequent grouping and time series analyses.

= Methods

== Tools

The analysis was conducted in R using the following packages:

- `data.table` for fast data wrangling and aggregation
- `sf` for handling spatial (shapefile) data
- `ggplot2` for creating the plots
- `patchwork` for combining multiple plots into a single figure
- `ggiraph` for adding interactive features such as tooltips and hover effects within the dashboard
- `forecast` for time series forecasting

== Geospatial Visualization

To examine the geographic distribution of dengue, district case counts were combined with
district population data to calculate an *incident rate per 100,000 people*.
Districts were shaded according to their incident rates, with interactive tooltips.
The map focuses on data from January to May 2026 to represent the current outbreak period.

Bar charts were also produced to display the districts with the highest case counts
and to compare the top ten districts during the same period in 2026 and 2025.

== Heatmap of Cases

To visualise daily changes in reported cases across all districts,
a heatmap was created with day of the month on the x-axis, district on the y-axis.
This made it easier to identify districts experiencing sudden increases in reported cases.

== Time Series Decomposition (STL)

For long-term trend analysis, weekly dengue cases from all districts were aggregated into
a national time series covering the period from 2007 onward. As some weeks were missing,
a complete weekly calendar was first created and missing values were filled using linear interpolation.

An *Seasonal-Trend decomposition using Loess* was then applied to separate the series into components.

A robust STL approach was used to reduce the influence of unusually large outbreak years
on the estimated seasonal and trend components.

== Seasonal Index

To provide a simpler summary of seasonal variation, a *seasonal index* was calculated by month.

== Autocorrelation

The *autocorrelation function (ACF)* of monthly case totals was calculated up to a lag of 24 months,
together with the 95% confidence interval bands. This analysis was used to determine
whether dengue cases in a given month were statistically associated with previous months
and to assess the presence of an annual seasonal cycle.

== Outbreak Detection

To flag weeks of unusually high transmission in 2026, a historical epidemic threshold was
calculated for each epidemiological week using data from 2016–2025. Following standard
surveillance practice, the threshold was defined as the historical mean plus two standard
deviations for that week, with the expected range shown as mean $plus.minus$ 2 standard
deviations. Weekly case counts in 2026 were then compared against this threshold to
identify weeks where transmission exceeded the historically expected range.

== Population-Adjusted Incidence Ranking

District case totals for 2026 were converted to an incidence rate per 100,000 population
using the 2025 mid-year population estimates, and ranked against the national average
incidence rate. This addresses a limitation of ranking districts by raw case counts alone,
which tends to favour more populous districts regardless of their underlying transmission
intensity.

== Short-Term Forecasting

An *Exponential Smoothing State Space model (ETS)*, selected automatically based on
model fit, was applied to the national weekly case series to produce an eight-week-ahead
forecast, together with 80% and 95% prediction intervals. As with the STL decomposition,
missing weeks in the series were first filled using linear interpolation before fitting
the model.

= Results

== Overview of 2026

Between January and May 2026, more than 56,000 dengue cases were reported nationwide.
*Colombo*, *Galle*, and *Gampaha* recorded the highest incident rates,
consistent with the higher dengue burden typically observed in the more urbanised
south-western region of the country. The heatmap also revealed several distinct
single-day spikes in specific districts, standing out against the otherwise
relatively steady background level of reported cases.

== Seasonal and Trend Patterns

The STL decomposition revealed a clear annual seasonal cycle together with a long-term upward trend
in dengue incidence. A particularly large epidemic peak occurred around 2017,
substantially exceeding the level expected from the normal seasonal pattern. This indicates that,
although seasonal transmission is relatively predictable, major outbreak years are
influenced by additional factors such as weather variability or changes in population immunity,
highlighting the importance of continuous surveillance.

The seasonal index supported these findings by showing that *July* had the highest seasonal index,
indicating that dengue activity is typically well above the annual average during this month.
January, June, November, and December also exhibited above-average activity, whereas
March, April, September, and October consistently recorded lower-than-average case numbers.
Overall, the results indicate a pronounced mid-year peak followed by a smaller increase toward
the end of the year, providing useful information for planning dengue prevention
and control activities.

== Outbreak Status and Short-Term Outlook

Comparing 2026 weekly case counts against the 2016–2025 historical baseline showed several
weeks where reported cases exceeded the epidemic threshold, indicating periods of
higher-than-expected transmission relative to the historical pattern for that time of year.
The eight-week forecast, generated from the ETS model, provides an indication of expected
case volumes in the near term and can support planning for resource allocation, while the
widening prediction intervals over the forecast horizon reflect the greater uncertainty
associated with longer-range projections.

= References

#set par(justify: false)

Talagala, T. (2026). *denguedatahub: A Tidy Format Dataset of Dengue by Country*. R package
version 4.1.1. #link("https://thiyangt.github.io/denguedatahubweb/")

Epidemiology Unit, Ministry of Health, Sri Lanka (2026). *Weekly Epidemiological Report*.
#link("https://www.epid.gov.lk/")

Department of Census and Statistics, Sri Lanka (2025). *Mid-year Population Estimates
by District*. #link("http://www.statistics.gov.lk/")