##############################################
# calculate_state_prison_mortality_rates.R
# Author: [Your Name]
# Date: [Today's Date]
# Description: Summarize individual-level BJS prison death records,
# merge with state-level incarceration trends data, and calculate
# annual state-level mortality rates per 100,000 prisoners.
##############################################

########## 1. Load Required Libraries #########################
library(readxl)
library(readr)
library(dplyr)
library(janitor)
library(ggplot2)
library(knitr)
library(kableExtra)
library(stringr)
library(tidyr)

########## 2. Load BJS Individual-Level Death Records #########
# File: mciprison2016_20192025.xlsx
bjs_data <- read_excel("mciprison2016_20192025.xlsx") %>%
  clean_names()


########## Recode State Numbers to Match Population Dataset ##########

# Named vector for mapping state numeric codes to state names
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

# Recode to create a new 'state_name' variable for merging
bjs_data <- bjs_data %>%
  mutate(state_name = recode(as.character(state), !!!state_lookup))

########## Recode Cause of Death ###############################

########## Recode Cause of Death (Combined Homicide) ##########

bjs_data <- bjs_data %>%
  mutate(
    cause_of_death = recode(
      as.character(cause),
      "1"  = "Illness (non-AIDS)",
      "2"  = "AIDS-related",
      "3"  = "Drug/Alcohol Overdose",
      "4"  = "Accidental Injury (Self)",
      "5"  = "Accidental Injury (Other)",
      "6"  = "Suicide",
      "7"  = "Homicide",
      "11" = "Homicide",
      "8"  = "Other Causes",
      .default = "Missing/Unknown"
    )
  )


########## Handle Explicit NAs in cause_of_death #############

bjs_data <- bjs_data %>%
  mutate(
    cause_of_death = ifelse(is.na(cause_of_death), "Missing/Unknown", cause_of_death)
  )

# --------------------------------------------------------------
# 2.5 Check Missingness
# --------------------------------------------------------------
missing_summary <- bjs_data %>%
  summarise(across(everything(), ~ mean(is.na(.)) * 100)) %>%
  pivot_longer(everything(), names_to = "variable", values_to = "pct_missing") %>%
  arrange(desc(pct_missing))

# View top missing variables
print(missing_summary, n=59)



########## 3. Summarize Deaths by State and Year ##############
deaths_summary <- bjs_data %>%
  group_by(state_name, year) %>%
  summarize(deaths = n(), .groups = "drop")

# Group by year, state, and cause to prepare cause-specific mortality rates
deaths_by_cause <- bjs_data %>%
  group_by(year, state_name, cause_of_death) %>%
  summarize(deaths = n(), .groups = "drop")

########## 4. Load Incarceration Trends Dataset ###############
# File: incarceration_trends_state(1).csv
incarceration_data <- read_csv("incarceration_trends_state(1).csv") %>%
  clean_names()


########## 5. Select and Clean Population Data ################
# Check column names to confirm population field
# You may need to inspect with: names(incarceration_data)

names(incarceration_data)

###Filter so YEAR matches BJS
pop_data <- incarceration_data %>%
  filter(year >= 2015 & year <= 2019) %>%   # Match years in BJS dataset
  select(state_name, year, total_prison_pop)


########## 6. Merge Death Counts and Population Data ##########
########## Ensure 'year' is numeric in deaths_summary ##########

deaths_summary <- deaths_summary %>%
  mutate(year = as.numeric(year))

merged_data <- left_join(deaths_summary, pop_data, by = c("state_name", "year"))

########## 7. Calculate Mortality Rate per 100,000 ###########
mortality_rates <- merged_data %>%
  mutate(mortality_rate = (deaths / total_prison_pop) * 100000)


########## Check for Unmatched Rows After Merge ###############

unmatched_rows <- merged_data %>%
  filter(is.na(total_prison_pop))

# Print how many rows didn't match
cat("Number of unmatched rows:", nrow(unmatched_rows), "\n")

# View the actual rows (if needed)
print(unmatched_rows)


##############################################################

########## Merge Cause-Specific Deaths with Population ########

# Ensure year is numeric in cause-specific summary
deaths_by_cause <- deaths_by_cause %>%
  mutate(year = as.numeric(year))

# Merge
cause_specific_data <- left_join(deaths_by_cause, pop_data, by = c("state_name", "year"))

# Calculate cause-specific mortality rate
cause_specific_rates <- cause_specific_data %>%
  mutate(mortality_rate = (deaths / total_prison_pop) * 100000)

########## Check for Unmatched Rows in Cause-Specific Merge ####

cause_na <- cause_specific_rates %>%
  filter(is.na(total_prison_pop))

cat("Unmatched cause-specific rows:", nrow(cause_na), "\n")

###############################################################

########## 8. Save Merged Datasets for Reporting ###############
write_csv(mortality_rates, "overall_mortality_rates.csv")
########## Save Cause-Specific Mortality Rates to CSV ##########
write_csv(cause_specific_rates, "cause_specific_mortality_rates.csv")

########## 9. Example Plot: Mortality Trends for Texas ########
mortality_rates %>%
  filter(state_name == "Texas") %>%
  ggplot(aes(x = year, y = mortality_rate)) +
  geom_line(color = "steelblue") +
  geom_point(color = "black") +
  labs(title = "Texas Prison Mortality Rate by Year",
       y = "Mortality Rate (per 100,000)",
       x = "Year") +
  theme_minimal()


# Overall national rate 2019
nat_rate_2019 <- mortality_rates %>%
  filter(year == 2019) %>%
  summarize(national = mean(mortality_rate, na.rm = TRUE))

# Top state for overall rate
top_state <- mortality_rates %>%
  filter(year == 2019) %>%
  arrange(desc(mortality_rate)) %>%
  slice(1)

# Cause-specific values for that state in 2019
top_cause_rates <- cause_specific_rates %>%
  filter(year == 2019, state_name == top_state$state_name) %>%
  arrange(desc(mortality_rate))

# Rates for illness, suicide, homicide in 2019 (all states aggregated):
agg_2019 <- cause_specific_rates %>%
  filter(year == 2019, cause_of_death %in% c("Illness (non-AIDS)", "Suicide", "Homicide")) %>%
  group_by(cause_of_death) %>%
  summarize(avg_rate = mean(mortality_rate))




########## Extract Top 5 Suicide States (2019) ################

top_suicide_states_2019 <- cause_specific_rates %>%
  filter(year == 2019, cause_of_death == "Suicide") %>%
  arrange(desc(mortality_rate)) %>%
  slice(1:5)

print(top_suicide_states_2019)


########## 1. Extract Top 5 States by Overdose Rate in 2019 ##########

top5_overdose_2019 <- cause_specific_rates %>%
  filter(year == 2019, cause_of_death == "Drug/Alcohol Overdose") %>%
  arrange(desc(mortality_rate)) %>%
  slice(1:5)

top_states <- top5_overdose_2019$state_name

########## 2. Filter for Overdose Trends in Top 5 States ##########

top_overdose_trends <- cause_specific_rates %>%
  filter(cause_of_death == "Drug/Alcohol Overdose", state_name %in% top_states)

########## 3. Compute National Average Overdose Rates ##########

national_avg_overdose <- cause_specific_rates %>%
  filter(cause_of_death == "Drug/Alcohol Overdose") %>%
  group_by(year) %>%
  summarize(national_avg = mean(mortality_rate, na.rm = TRUE))

########## 4. Plot Trends + National Average Line ##########

library(ggrepel)

ggplot(top_overdose_trends, aes(x = year, y = mortality_rate, group = state_name)) +
  # Gray lines for all states
  geom_line(color = "gray40", size = 1.2) +
  
  # Add points
  geom_point(color = "gray40", size = 1.5) +
  
  # Label only 2019 values
  geom_text_repel(
    data = top_overdose_trends %>% filter(year == 2019),
    aes(label = state_name),
    size = 3,
    nudge_x = 0.3,
    direction = "y",
    hjust = 0,
    segment.color = "gray70",
    show.legend = FALSE
  ) +
  
  # Add national average line in red
  geom_line(data = national_avg_overdose,
            aes(x = year, y = national_avg),
            color = "red", size = 1.2,
            inherit.aes = FALSE) +
  geom_point(data = national_avg_overdose,
             aes(x = year, y = national_avg),
             color = "red", size = 2,
             inherit.aes = FALSE) +
  
  labs(
    title = "Drug/Alcohol Overdose Mortality Rates in State Prisons (Top 5 States)",
    subtitle = "Gray lines: states | Red line: National Average",
    x = "Year",
    y = "Overdose Mortality Rate (per 100,000)"
  ) +
  theme_minimal(base_size = 13) +
  theme(legend.position = "none")



######Plot of unnatural causes of death count
########## 1. Filter and Group Unnatural Causes ##########

########## 1. Group Unnatural Causes ##########

unnatural_deaths <- cause_specific_rates %>%
  filter(cause_of_death %in% c(
    "Suicide", "Drug/Alcohol Overdose",
    "Homicide", "Accidental Injury (Self)", "Accidental Injury (Other)")
  ) %>%
  mutate(cause_group = case_when(
    str_detect(cause_of_death, "Homicide") ~ "Homicide",
    str_detect(cause_of_death, "Accidental Injury") ~ "Accident",
    TRUE ~ cause_of_death
  )) %>%
  group_by(year, cause_group) %>%
  summarize(total_deaths = sum(deaths, na.rm = TRUE), .groups = "drop")

########## 2. Plot Line Chart ##########

# Get data for 2019 to use as label positions
label_data <- unnatural_deaths %>% 
  filter(year == 2019)

ggplot(unnatural_deaths, aes(x = year, y = total_deaths, color = cause_group)) +
  geom_line(size = 1.4) +
  geom_point(size = 2) +
  geom_text_repel(
    data = label_data,
    aes(label = cause_group),
    nudge_x = 0.5,
    direction = "y",
    hjust = 0,
    segment.color = NA,
    size = 4.2,
    show.legend = FALSE
  ) +
  scale_color_manual(
    values = c(
      "Suicide" = "#1f77b4",              # Blue
      "Drug/Alcohol Overdose" = "#7f7f7f", # Gray
      "Homicide" = "#d62728",             # Red
      "Accident" = "#2ca02c"              # Green
    )
  ) +
  scale_x_continuous(breaks = 2015:2019, expand = expansion(mult = c(0.01, 0.15))) +
  labs(
    title = "Trends in Unnatural Deaths in State Prisons (2015–2019)",
    subtitle = "Labeled by Cause of Death",
    x = "Year",
    y = "Number of Deaths",
    caption = "Data: BJS & Incarceration Trends Project"
  ) +
  theme_minimal(base_size = 13) +
  theme(
    plot.title = element_text(face = "bold", size = 16),
    plot.subtitle = element_text(size = 13, margin = margin(b = 10)),
    plot.caption = element_text(size = 10, hjust = 1),
    legend.position = "none",
    axis.title = element_text(size = 12),
    axis.text = element_text(size = 11),
    panel.grid.minor = element_blank()
  )





########## National Mortality Rate Trend (State Prisons Only) ##########

# Calculate national mortality rate per year (weighted average by population)
national_mortality_trend <- mortality_rates %>%
  group_by(year) %>%
  summarize(
    deaths = sum(deaths, na.rm = TRUE),
    total_prison_pop = sum(total_prison_pop, na.rm = TRUE),
    mortality_rate = 100000 * deaths / total_prison_pop
  )

# Plot it

ggplot(national_mortality_trend, aes(x = year, y = mortality_rate)) +
  geom_line(color = "steelblue", size = 1.3) +
  geom_point(color = "steelblue", size = 2) +
  labs(
    title = "Mortality Rate per 100,000 State Prisoners (2015–2019)",
    x = "Year",
    y = "Mortality Rate (per 100,000)"
  ) +
  theme_minimal(base_size = 14)


############Tables
# Filter for 2019, sort, and show top 10 states by overall mortality rate
mortality_rates %>%
  filter(year == 2019) %>%
  arrange(desc(mortality_rate)) %>%
  slice(1:10) %>%
  select(state_name, mortality_rate) %>%
  rename(`State` = state_name, `Mortality Rate (per 100,000)` = mortality_rate) %>%
  kable(digits = 1, align = 'l', caption = "Top 10 States by Overall Mortality Rate in State Prisons (2019)") %>%
  kable_styling(full_width = FALSE, bootstrap_options = c("striped", "hover"))

cause_specific_rates %>%
  group_by(year, cause_of_death) %>%
  summarize(avg_rate = round(mean(mortality_rate, na.rm = TRUE), 1), .groups = "drop") %>%
  pivot_wider(names_from = year, values_from = avg_rate) %>%
  rename(`Cause of Death` = cause_of_death) %>%
  kable(align = 'l', caption = "National Average Cause-Specific Mortality Rates in Prisons (per 100,000)") %>%
  kable_styling(full_width = FALSE, bootstrap_options = c("striped", "hover"))


########## Updated Table 1: Cleaner Format and Pooled Mortality Rate ##########

# Compute total population over all years
total_population <- cause_specific_rates %>%
  summarise(total_pop = sum(total_prison_pop, na.rm = TRUE)) %>%
  pull(total_pop)

# Build Table 1 with better formatting
table1_clean <- cause_specific_rates %>%
  group_by(cause_of_death) %>%
  summarise(
    Total_Deaths = sum(deaths, na.rm = TRUE),
    Total_Population = sum(total_prison_pop, na.rm = TRUE)
  ) %>%
  mutate(
    Mortality_Rate = round((Total_Deaths / total_population) * 100000, 1),
    Percent_of_Deaths = round((Total_Deaths / sum(Total_Deaths)) * 100, 1)
  ) %>%
  select(`Cause of Death` = cause_of_death,
         `Number of Deaths` = Total_Deaths,
         `Mortality Rate (per 100,000)` = Mortality_Rate,
         `Percent of Deaths` = Percent_of_Deaths) %>%
  arrange(desc(`Number of Deaths`))

# Display table
kable(table1_clean, caption = "Table 1: Deaths of State Prisoners by Cause (2015–2019)") %>%
  kable_styling(bootstrap_options = c("striped", "hover", "condensed"))



########## Table 4: Mortality Rates by Year and Cause (Wide Format) ##########

# Pivot to wide format: causes as rows, years as columns
table4 <- cause_specific_rates %>%
  select(year, cause_of_death, mortality_rate) %>%
  group_by(cause_of_death, year) %>%
  summarise(mortality_rate = round(mean(mortality_rate, na.rm = TRUE), 1), .groups = "drop") %>%
  tidyr::pivot_wider(names_from = year, values_from = mortality_rate) %>%
  arrange(desc(`2019`))  # Optional: sort by most recent year

# Display the wide table
kable(table4, caption = "Table 4: Mortality Rate per 100,000 by Cause of Death and Year (2015–2019)") %>%
  kable_styling(bootstrap_options = c("striped", "hover", "condensed"))



