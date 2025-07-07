########### Load, Clean, Explore, and Export BJA Dataset ########################

# Load required libraries
library(readxl)
library(dplyr)
library(janitor)
library(ggplot2)
library(lubridate)
library(plotly)
library(flextable)
library(officer)
library(tibble)

# Read the Excel file (first sheet)
bja_data <- read_excel("BJA_updated_fields_Full Data_data-882_Cleaned-up.2.25.xlsx", sheet = 1)

# Load the BJS dataset and its codebook
bjs_data <- read_excel("mciprison2016_20192025.xlsx", sheet = 1)
bjs_codebook <- read_excel("mcicodebookprison2025.xlsx", sheet = 1)

# Clean column names
bja_data <- bja_data %>% clean_names()
bjs_codebook <- bjs_codebook %>% clean_names()



# Keep only the most relevant variables for analysis and linkage
bja_data_core <- bja_data %>%
  select(
    state, city, zip_code, agency_name, facility_type, location_type,
    date_of_death, calendar_year_death, time_of_death,
    first_name, decedent_last_name, birth_year, age, gender, race, ethnicity,
    manner_of_death, pre_recode_type_of_death, recode
  )


# View structure and first few rows
glimpse(bja_data_core)
head(bja_data_core)

# Check missing values
colSums(is.na(bja_data_core))

bja_data_core <- bja_data_core %>%
  mutate(
    manner_of_death = tolower(trimws(manner_of_death)),
    pre_recode_type_of_death = tolower(trimws(pre_recode_type_of_death)),
    facility_type = tolower(trimws(facility_type))
  )

#Filter obvious errors/blanks
bja_data_core <- bja_data_core %>%
  filter(!is.na(date_of_death), !is.na(state))

#Check for Duplicates
bja_data_core %>%
  count(first_name, decedent_last_name, date_of_death, manner_of_death) %>%
  filter(n > 1)



# Summarize deaths by state
bja_data_core %>%
  count(state, sort = TRUE)

# Summarize deaths by year
bja_data_core %>%
  mutate(year = year(date_of_death)) %>%
  count(year, sort = TRUE)

# Plot deaths over time
bja_data_core %>%
  mutate(year = year(date_of_death)) %>%
  count(year) %>%
  ggplot(aes(x = year, y = n)) +
  geom_col(fill = "steelblue") +
  labs(title = "Deaths in Custody by Year",
       x = "Year",
       y = "Number of Deaths") +
  theme_minimal()


###########################################################################################

#####################State by State Map Example ################################

# Summarize deaths by state
state_stats <- bja_data_core %>%
  count(state, name = "death_count")

# Create interactive US map
fig <- plot_ly(state_stats,
               type = 'choropleth',
               locations = ~state,
               locationmode = 'USA-states',
               z = ~death_count,
               text = ~paste("State:", state, "<br>Deaths:", death_count),
               colorscale = 'Blues',
               colorbar = list(title = "Death Count"),
               marker = list(line = list(color = "white", width = 1)))

fig <- fig %>%
  layout(title = "Deaths in Custody by State",
         geo = list(scope = 'usa'))

# Display the interactive map
fig

################################################################################

################################################################################
# ----------------------------------------------
# Script: compare_bja_bjs_variables.R
# Purpose: Compare variable names across BJA and BJS datasets
#          to identify overlap and gaps for integration
# Author: Johnathan Ross
# Date: 6/5/2025
# ----------------------------------------------

# Combine BJS variables from both the dataset and the codebook (assumes first column of codebook has variable names)
bjs_vars <- colnames(bjs_data)
codebook_vars <- tolower(trimws(bjs_codebook[[1]]))
bjs_all_vars <- sort(unique(c(bjs_vars, codebook_vars)))

# BJA variable names (from cleaned dataset)
bja_vars <- colnames(bja_data_core)

# Create comparison table
comparison_table <- tibble(
  variable_name = sort(unique(c(bja_vars, bjs_all_vars))),
  status = case_when(
    variable_name %in% bja_vars & variable_name %in% bjs_all_vars ~ "Shared",
    variable_name %in% bja_vars ~ "BJA Only",
    variable_name %in% bjs_all_vars ~ "BJS Only"
  )
)

# Create a styled flextable
ft <- flextable(comparison_table) %>%
  set_header_labels(variable_name = "Variable Name", status = "Present In") %>%
  theme_booktabs() %>%
  autofit() %>%
  align(align = "left", part = "all")

# Export to Word
doc <- read_docx() %>%
  body_add_par("BJA vs BJS Variable Comparison", style = "heading 1") %>%
  body_add_flextable(ft)

print(doc, target = "bja_bjs_variable_comparison.docx")
################################################################################