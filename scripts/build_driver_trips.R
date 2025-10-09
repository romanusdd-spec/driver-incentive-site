# scripts/build_driver_trips.R
suppressPackageStartupMessages({
  library(tidyverse)
  library(lubridate)
  library(readr)
  library(here)
})

# Ensure folders exist
dir.create(here("data"), showWarnings = FALSE)
dir.create(here("data","raw"), showWarnings = FALSE)

raw_dir <- here("data","raw")
files <- list.files(raw_dir, pattern = "\\.csv$", full.names = TRUE)

# --- PHASE 1: Get raw data ---
if (length(files) == 0) {
  # No raw files yet? Produce a tiny demo dataset for dodi/alice/bob (last 7 days)
  message("No raw files found; generating demo data…")
  set.seed(1)
  dates <- seq.Date(Sys.Date()-6, Sys.Date(), by = "day")
  mk <- function(driver) tibble(
    driver = driver,
    trip_id = paste0(driver, "_", seq_along(dates)),
    date = dates,
    km_driving = round(runif(length(dates), 10, 80), 1),
    dur_driving_s = as.integer(runif(length(dates), 1800, 4*3600)),
    dur_parking_s = as.integer(runif(length(dates), 300, 3600)),
    incentive_rp = as.integer(runif(length(dates), 20000, 150000) %/% 1000 * 1000),
    sj_balikan = sample(c(0L,1L), length(dates), replace = TRUE, prob = c(0.7,0.3))
  )
  df <- bind_rows(mk("dodi"), mk("alice"), mk("bob"))
} else {
  message("Reading raw CSVs from data/raw/ …")
  raw <- map_dfr(files, ~ read_csv(.x, show_col_types = FALSE))
  
  # Map to the schema your site expects
  # Adjust the coalesce() names to match real columns when you’re ready.
  df <- raw %>%
    transmute(
      driver         = tolower(trimws(coalesce(driver, Driver, DRV, ""))),
      trip_id        = coalesce(trip_id, TripID, Trip_Id),
      date           = as_date(coalesce(date, Date, Tanggal)),
      km_driving     = as.numeric(coalesce(km_driving, KM, KM_driving)),
      dur_driving_s  = as.numeric(coalesce(dur_driving_s, dur_driving_sec, dur_driving)),
      dur_parking_s  = as.numeric(coalesce(dur_parking_s, dur_parking_sec, dur_parkir)),
      incentive_rp   = as.numeric(coalesce(incentive_rp, Insentif, Insentif_Rp)),
      sj_balikan     = as.integer(coalesce(sj_balikan, SJ_balikan, SJ, 0))
    ) %>%
    mutate(
      date          = as_date(date),
      km_driving    = replace_na(km_driving, 0),
      dur_driving_s = replace_na(dur_driving_s, 0),
      dur_parking_s = replace_na(dur_parking_s, 0),
      incentive_rp  = replace_na(incentive_rp, 0),
      sj_balikan    = replace_na(sj_balikan, 0)
    ) %>%
    arrange(date, driver, trip_id)
}

# Validate columns
need <- c("driver","trip_id","date","km_driving","dur_driving_s","dur_parking_s","incentive_rp","sj_balikan")
stopifnot(all(need %in% names(df)))

# --- PHASE 2: Write only if changed ---
out_fp <- here("data","driver_trips.csv")
tmp_fp <- tempfile(fileext = ".csv")
write_csv(df, tmp_fp, na = "")

same <- FALSE
if (file.exists(out_fp)) {
  same <- identical(read_file(out_fp), read_file(tmp_fp))
}
if (!same) {
  file.copy(tmp_fp, out_fp, overwrite = TRUE)
  message("Updated: ", out_fp)
} else {
  message("No changes to ", out_fp)
}
