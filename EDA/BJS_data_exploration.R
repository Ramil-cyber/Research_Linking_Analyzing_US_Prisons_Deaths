########### BJS DATA EXPLORATION SCRIPT ########################
# Author: Johnathan Ross
# Purpose: Initial exploration and summary of BJS prison mortality dataset
# Dataset: mciprison2016_20192025.xlsx and mcicodebookprison2025.xlsx
# --------------------------------------------------------------

# Load packages
library(readxl)
library(dplyr)
library(janitor)
library(ggplot2)
library(tidyr)
library(plotly)
# --------------------------------------------------------------
# 1. Load and Clean Data
# --------------------------------------------------------------
# Load BJS dataset
bjs_data <- read_excel("mciprison2016_20192025.xlsx", sheet = 1) %>%
  clean_names()

# Preview structure
glimpse(bjs_data)
summary(bjs_data)

# --------------------------------------------------------------
# 2. Check Missingness
# --------------------------------------------------------------
missing_summary <- bjs_data %>%
  summarise(across(everything(), ~ mean(is.na(.)) * 100)) %>%
  pivot_longer(everything(), names_to = "variable", values_to = "pct_missing") %>%
  arrange(desc(pct_missing))

# View top missing variables
print(missing_summary, n=57)

#Shows all variables w/ >75% missing
missing_summary %>%
  filter(pct_missing > 75)



missing_summary %>%
  filter(pct_missing > 10) %>%
  ggplot(aes(x = reorder(variable, pct_missing), y = pct_missing)) +
  geom_col(fill = "firebrick") +
  coord_flip() +
  labs(title = "Variables with >10% Missingness in BJS Dataset",
       x = "Variable", y = "Percent Missing") +
  theme_minimal()


########### Extract Unique Levels of 'year' #######
unique_years <- unique(bjs_data$year)

########### Display the Result ####################
print(unique_years)
# --------------------------------------------------------------
# 3. Summarize Key Variables
# --------------------------------------------------------------
# Deaths by Reporting year
bjs_data %>%
  count(year) %>%
  ggplot(aes(x = year, y = n)) +
  geom_col(fill = "steelblue") +
  labs(title = "BJS Death Records by Reporting Year",
       x = "Reporting Year", y = "Number of Records") +
  theme_minimal()


bjs_data %>%
  mutate(cause_label = recode(as.character(cause),
                              "1" = "Illness (non-AIDS)",
                              "2" = "AIDS-related",
                              "3" = "Drug/Alcohol Overdose",
                              "4" = "Accidental Injury (Self)",
                              "5" = "Accidental Injury (Other)",
                              "6" = "Suicide",
                              "7" = "Homicide (excl. 2011–12)",
                              "8" = "Other Causes",
                              "11" = "Homicide (2011–12 only)",
                              .default = "Missing/Unknown"
  )) %>%
  count(cause_label, sort = TRUE)



# --------------------------------------------------------------
# 4. Prepare for Linkage/Mapping
# --------------------------------------------------------------
state_lookup <- c(
  "1" = "Alabama", "2" = "Alaska", "3" = "Arizona", "4" = "Arkansas",
  "5" = "California", "6" = "Colorado", "7" = "Connecticut", "8" = "Delaware",
  "9" = "District of Columbia", "10" = "Florida", "11" = "Georgia", "12" = "Hawaii",
  "13" = "Idaho", "14" = "Illinois", "15" = "Indiana", "16" = "Iowa",
  "17" = "Kansas", "18" = "Kentucky", "19" = "Louisiana", "20" = "Maine",
  "21" = "Maryland", "22" = "Massachusetts", "23" = "Michigan", "24" = "Minnesota",
  "25" = "Mississippi", "26" = "Missouri", "27" = "Montana", "28" = "Nebraska",
  "29" = "Nevada", "30" = "New Hampshire", "31" = "New Jersey", "32" = "New Mexico",
  "33" = "New York", "34" = "North Carolina", "35" = "North Dakota", "36" = "Ohio",
  "37" = "Oklahoma", "38" = "Oregon", "39" = "Pennsylvania", "40" = "Rhode Island",
  "41" = "South Carolina", "42" = "South Dakota", "43" = "Tennessee", "44" = "Texas",
  "45" = "Utah", "46" = "Vermont", "47" = "Virginia", "48" = "Washington",
  "49" = "West Virginia", "50" = "Wisconsin", "51" = "Wyoming"
)

# Core subset for future matching or dashboard
bjs_core <- bjs_data %>%
  filter(!is.na(year) & !is.na(dobyear)) %>%
  mutate(
    year = as.numeric(year),
    dobyear = as.numeric(dobyear),
    age = year - dobyear,
    state_name = state_lookup[as.character(state)]
  ) %>%
  select(year, dobyear, state_name, age, gender, race, cause, fname, lname, facname) %>%
  rename(
    first_name = fname,
    last_name = lname,
    facility_name = facname,
    reporting_year = year
  )


# --------------------------------------------------------------
# 4b. Check for Duplicates in Core Dataset
# --------------------------------------------------------------
# We found 4 sets of potential duplicates based on matching
# first name, last name, reporting year, cause, and year of birth.
# These may represent actual duplicate entries and need review.
# 1. Count full duplicate rows
cat("Full duplicate rows in bjs_core: ", sum(duplicated(bjs_core)), "\n")

# 2. Check for potential duplicates using name + reporting_year + cause 
bjs_core %>%
  count(first_name, last_name, reporting_year, cause, dobyear) %>%
  filter(n > 1) %>%
  arrange(desc(n)) %>%
  print(n = 50)  # or more if you want to explore deeper




# --------------------------------------------------------------
# 5. Notes for Future Steps
# --------------------------------------------------------------
# - Standardize cause of death labels
# - Compare against BJA structure
# - Explore facility-level patterns (if variable exists)
# - Consider prep for interactive visualization or linking

################################################################


# --------------------------------------------------------------
# 6. Exploration & Mapping
# --------------------------------------------------------------
#Top 10 States by Death Count
bjs_core %>%
  count(state_name, sort = TRUE) %>%
  slice_max(n, n = 10)

#Mapping Deaths By State
# Create abbreviation lookup
state_abbrev_lookup <- setNames(state.abb, state.name)

# Recode full names to abbreviations
state_deaths <- bjs_core %>%
  count(state_name, name = "death_count") %>%
  mutate(
    state_abbrev = state_abbrev_lookup[state_name]
  ) %>%
  filter(!is.na(state_abbrev))  # remove unmatched rows

plot_ly(
  data = state_deaths,
  type = "choropleth",
  locations = ~state_abbrev,
  locationmode = "USA-states",
  z = ~death_count,
  text = ~paste0("<b>", state_name, "</b><br>Deaths: ", death_count),
  colorscale = "Reds",
  marker = list(line = list(color = "white", width = 1)),
  colorbar = list(title = "Number of Deaths", thickness = 15)
) %>%
  layout(
    title = "Prison Deaths by State (BJS Data)<br><sup>Reported counts by state</sup>",
    geo = list(scope = "usa")
  )



