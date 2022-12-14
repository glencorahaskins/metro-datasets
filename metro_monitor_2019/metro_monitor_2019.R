library(tidyverse)
library(skimr)
library(expss)
library(reshape2)
source("R/save_output.R")

# SET UP ====================================
source_dir <- "V:/Performance/Project files/Metro Monitor/2019v/Output/"
folder_name <- "metro_monitor_2019"
file_name <- "cbsa_metromonitor"

# metadata
dt_title <- "Metro monitor, 2007 - 2017"
dt_src <- "https://www.brookings.edu/research/metro-monitor-2019-inclusion-remains-elusive-amid-widespread-metro-growth-and-rising-prosperity/"
dt_contact <- "Isha Shah"
dt_notes <- "The 6 missing growth rank factors were due to LEHD and EMSI job data gaps for the following MSAs:
Wichita, KS, 
Worcester, MA
Springfield, MA
Providence-New Bedford-Fall River, RI-MA
Nashville-Davidson--Murfreesboro, TN 
Boston-Cambridge-Quincy, MA-NH (Metro Area)"


# TRANSFORM ============================================
# Metro Monitor ---------------------------------------------------
# change in values (ranking) - update to 2019 file paths and add janitor to clean var names
growth_rank <- read.csv(paste0(source_dir, "Growth Ranks 2019-03-09 .csv")) %>% janitor::clean_names()
prosperity_rank <- read.csv(paste0(source_dir, "Prosperity Ranks 2019-03-09 .csv")) %>% janitor::clean_names()
inclusion_rank <- read.csv(paste0(source_dir, "Inclusion/Inclusion Ranks (IS 2018.12.11).csv"))%>% janitor::clean_names()
racial_inclusion_rank <- read.csv(paste0(source_dir, "Inclusion/Racial Inclusion Ranks (IS 2019.03.06).csv"))%>% janitor::clean_names() #racial inclusion = new category in 2019

# absolute value in 2017 (instead of 2016) and clean names
growth_value <- read.csv(paste0(source_dir, "Growth Values 2019-03-09 .csv")) %>% 
  # filter(year == 2017) %>%
  reshape2::dcast(year + cbsa ~ indicator, var.value = "value") %>% 
  janitor::clean_names()

prosperity_value <- read.csv(paste0(source_dir, "Prosperity Values 2019-03-09 .csv")) %>% 
  # filter(year == 2017) %>%
  reshape2::dcast(year + cbsa_code ~ indicator, var.value = "value") %>% #repalce CBSA with cbsa_code 
  janitor::clean_names()

inclusion_value <- read.csv(paste0(source_dir, "Inclusion/Inclusion Values (IS 2018.12.11).csv")) %>% 
  # filter(year == 2017) %>%
  filter(race == "Total") %>%
  filter(eduatt == "Total") %>%
  reshape2::dcast(year + cbsa ~ indicator, var.value = "value") %>% 
  janitor::clean_names()

racial_inclusion_value <- read.csv(paste0(source_dir, "Inclusion/Racial Inclusion Values (IS 2019.03.06).csv")) %>% #racial inclusion = new category in 2019
  # filter(year == 2017) %>%
  reshape2::dcast(year + cbsa ~ indicator, var.value = "value") %>% 
  janitor::clean_names()

# join all three changes
cbsa_rank <- prosperity_rank %>%
  rename(cbsa = cbsa_code,
         prosperity_score = score,
         prosperity_rank = rank)%>%
  full_join(growth_rank, by = c("year", "cbsa", "cbsa_name")) %>%
  rename(growth_score = score,
         growth_rank = rank
         )%>%
  full_join(inclusion_rank, by = c("year", "cbsa")) %>%
  rename(inclusion_score = score,
         inclusion_rank = rank)%>%
  full_join(racial_inclusion_rank, by = c("year", "cbsa")) %>%
  rename(racial_inclusion_score = score,
        racial_inclusion_rank = rank)%>%
  select(-contains("name."), -count) 

# save(cbsa_rank, file = "metro_monitor_2019/metro_monitor_2019_rank_allyear.rda")

# join all three absolute values
cbsa_value <- prosperity_value %>%
  rename(cbsa = cbsa_code)%>%
  full_join(growth_value, by = c("year", "cbsa")) %>%
  full_join(inclusion_value, by = c("year", "cbsa")) %>%
  full_join(racial_inclusion_value, by = c("year", "cbsa")) 

# save(cbsa_value, file = "metro_monitor_2019/metro_monitor_2019_allyear.rda")

# join everything (recoded rank.?.? to the 4 rank categories using Akron as visual sample)
df <- cbsa_rank %>%
  filter(year == "2007-2017")%>%
  rename(rank_year_range = year)%>%
  full_join(cbsa_value %>%
              filter(year == 2017), by = c("cbsa" = "cbsa")) %>%
  rename(
    cbsa_code = cbsa,
    value_year = year
  ) %>%
  mutate_at(c("cbsa_code","value_year","rank_year_range"),as.character) 

# FUNCTION load

df <- df %>% apply_labels(
  relative_income_poverty = "share of people earning less than half of the local median wage"
)
df_labels <- create_labels(df)

# SAVE OUTPUT
df <- df %>%
  select(cbsa_code, everything()) # make sure unique identifier is the left most column
# datasets
save_datasets(df, folder = folder_name, file = file_name)

# meta file
save_meta(df,
          labels = df_labels, folder = folder_name, file = file_name,
          title = dt_title, contact = dt_contact, source = dt_src, note = dt_notes
)

