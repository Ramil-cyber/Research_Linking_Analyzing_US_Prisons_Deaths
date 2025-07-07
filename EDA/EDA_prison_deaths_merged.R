########### Prison Mortality EDA Script ########################
# Script Name: eda_prison_deaths_merged.R
# Author: Johnathan Ross
# Purpose: Exploratory data analysis on merged BJA + BJS dataset
# Dataset: Merged_BJA_BJS_prison.csv
###############################################################

########### 1. Load Libraries #################################
library(dplyr)
library(ggplot2)
library(readr)
library(janitor)

########### 2. Load Dataset ###################################
# Load the merged dataset and standardize column names
data <- read_csv("Merged_BJA_BJS_prison.csv") %>%
  clean_names()

########### 3. Preview Dataset Structure ######################
# View the first few rows
head(data)

# View column names and types
glimpse(data)

# Summary statistics for numeric variables
summary(data)

# Check unique values in key categorical variables
sapply(data %>% select(gender, race, state_name, death_cause, source), unique)


########### 4. Check for Missing Data #########################
colSums(is.na(data))

########### 5. Basic Counts and Frequencies ###################
# Deaths by Year
table(data$reporting_death_year)

# Deaths by State
table(data$state_name)

# Deaths by Cause
table(data$death_cause)

# Deaths by Gender
table(data$gender, useNA = "ifany")

# Deaths by Race
table(data$race, useNA = "ifany")

########### 6. Visualization Examples #########################
# Deaths by Year
ggplot(data, aes(x = reporting_death_year)) +
  geom_bar(fill = "steelblue") +
  labs(title = "Number of Deaths by Year", x = "Year", y = "Count")

# Deaths by Cause
ggplot(data, aes(x = death_cause)) +
  geom_bar(fill = "tomato") +
  theme(axis.text.x = element_text(angle = 45, hjust = 1)) +
  labs(title = "Deaths by Cause", x = "Cause of Death", y = "Count")

# Deaths by Race
ggplot(data, aes(x = race)) +
  geom_bar(fill = "darkgreen") +
  theme(axis.text.x = element_text(angle = 45, hjust = 1)) +
  labs(title = "Deaths by Race", x = "Race", y = "Count")

########### 5. Plot: Deaths Over Time ###########################
data %>%
  count(reporting_death_year) %>%
  ggplot(aes(x = reporting_death_year, y = n)) +
  geom_line(color = "steelblue", size = 1.2) +
  geom_point() +
  labs(title = "Total Deaths Reported by Year",
       x = "Year", y = "Number of Deaths") +
  theme_minimal()

