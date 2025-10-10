
# scripts/build_driver_trips.R
suppressPackageStartupMessages({
  library(tidyverse)
  library(lubridate)
})

# Where we will write the final file
out_fp <- file.path("data", "driver_trips.csv")
dir.create("data", showWarnings = FALSE)

raw_dir <- file.path("data","raw")
dir.create(raw_dir, showWarnings = FALSE)

# ---- Helper to generate demo data ----
gen_demo <- function() {
  message("No raw files found; generating DEMO data for last 7 days…")

  today <- Sys.Date()
  days <- seq(today - 6, today, by = "1 day")

  # date-based seed so numbers change each day but are stable per run
  set.seed(as.integer(format(today, "%Y%m%d")))

  drivers <- c("dodi","alice","bob")

  df <- crossing(
    date = days,
    driver = drivers,
    trips = sample(2:6, length(days)*length(drivers), replace = TRUE)
  ) |>
    rowwise() |>
    mutate(
      # one row per trip
      data = list({
        tibble(
          trip_idx = seq_len(trips),
          trip_id = paste0(format(date, "%Y%m%d"), "-", driver, "-", trip_idx),
          km_driving = round(runif(trips, 5, 40), 1),
          dur_driving_s = round(runif(trips, 15*60, 120*60)),   # 15–120 min
          dur_parking_s = round(runif(trips, 5*60, 60*60)),     # 5–60 min
          incentive_rp = round(runif(trips, 10000, 90000), -2), # Rp 10k–90k
          sj_balikan = rbinom(trips, 1, 0.25)
        )
      })
    ) |>
    unnest(data) |>
    arrange(driver, date, trip_id) |>
    ungroup() |>
    select(driver, trip_id, date, km_driving, dur_driving_s,
           dur_parking_s, incentive_rp, sj_balikan)

  df
}

# ---- If you have real raw files, put your logic here ----
# For example, later you could read all CSVs in data/raw/ and transform to the
# required columns above. For now we detect if folder is empty and use demo.

raw_files <- list.files(raw_dir, pattern = "\.csv$", full.names = TRUE)

if (length(raw_files) == 0) {
  df <- gen_demo()
} else {
  message("Found raw files: ", paste(basename(raw_files), collapse = ", "))
  # Example scaffold (replace with your actual schema):
  # df <- map_dfr(raw_files, ~ read_csv(.x, show_col_types = FALSE)) |>
  #   transmute(
  #     driver = tolower(driver),
  #     trip_id = as.character(trip_id),
  #     date = as.Date(date),
  #     km_driving = as.double(km_driving),
  #     dur_driving_s = as.double(dur_driving_s),
  #     dur_parking_s = as.double(dur_parking_s),
  #     incentive_rp = as.double(incentive_rp),
  #     sj_balikan = as.integer(sj_balikan)
  #   )
  # For now, still fallback to demo until you wire real inputs:
  df <- gen_demo()
}

# Basic validation
req <- c("driver","trip_id","date","km_driving","dur_driving_s",
         "dur_parking_s","incentive_rp","sj_balikan")
missing <- setdiff(req, names(df))
if (length(missing)) stop("Missing columns in build: ", paste(missing, collapse = ", "))

# Normalize types
df <- df |>
  mutate(
    driver = tolower(as.character(driver)),
    trip_id = as.character(trip_id),
    date = as.Date(date),
    km_driving = as.double(km_driving),
    dur_driving_s = as.double(dur_driving_s),
    dur_parking_s = as.double(dur_parking_s),
    incentive_rp = as.double(incentive_rp),
    sj_balikan = as.integer(sj_balikan)
  ) |>
  arrange(date, driver, trip_id)

# Write
readr::write_csv(df, out_fp)
message("Updated: ", normalizePath(out_fp))
