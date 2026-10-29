# ==========================================================
# OHOL play statistics from oholcurse.com
# Usage:
#   Rscript ohol_stats.R "<player name, URL or hash>" [file name] [--include-dt]
#   for example: Rscript ohol_stats.R "Firstname Lastname"
# or edit PLAYER below and click Source in RStudio.
# Run it from the R folder so it can find ohol_fetch.R.
# ==========================================================
library(ggplot2)
library(dplyr)
library(gridExtra)
library(cowplot)   # adds the big title
library(tidyr)
library(openxlsx)  # Excel export

source("ohol_fetch.R")

# ---- Settings ----
PLAYER <- "Your Leaderboard Name"   # or a curse name, character name, URL or hash
NAME   <- ""                 # used in file names. Empty = name from the website
my_tz  <- Sys.timezone()     # or for example "America/Toronto"
out_dir <- "output"
INCLUDE_DT <- FALSE           # TRUE = also count lives in Donkey Town
# ------------------

args <- commandArgs(trailingOnly = TRUE)
if ("--include-dt" %in% args) INCLUDE_DT <- TRUE
args <- args[!startsWith(args, "--")]
if (length(args) >= 1) PLAYER <- args[1]
if (length(args) >= 2) NAME <- args[2]

Data <- fetch_ohol_lives(PLAYER, tz = my_tz)
leaderboardName <- if (nzchar(NAME)) NAME else gsub("[^A-Za-z0-9]+", "", attr(Data, "player"))

dir.create(out_dir, showWarnings = FALSE)
out_file <- function(ext) {
  file.path(out_dir, paste0("OHOL_stats_", leaderboardName, "_", Sys.Date() - 1, ext))
}

# Save the data as csv and Excel. Times are written as local clock time.
write.csv(Data, file.path(out_dir, paste0("OHOL_lives_", leaderboardName, ".csv")), row.names = FALSE)
xl <- Data %>% mutate(across(c(Born, Died), ~ force_tz(.x, "UTC")))
write.xlsx(xl, file.path(out_dir, paste0("OHOL_lives_", leaderboardName, ".xlsx")),
           sheetName = "Record", firstRow = TRUE, colWidths = "auto")
# The files above keep every life. The charts leave out Donkey Town unless INCLUDE_DT is TRUE.
if (!INCLUDE_DT) {
  n_dt <- sum(Data$`Donkey Town`)
  if (n_dt > 0) message("Left out ", n_dt, " Donkey Town lives. Use --include-dt to count them.")
  Data <- Data %>% filter(!`Donkey Town`)
}
summary(Data)
color<-c("#000000", "#e5a11c", "#5cb6ea", "#2b9f78", "#f0e54b", "#0076b4", "#d6641e", "#cc7daa")
color_blind_friendly <- c("#000000", "#0072B2", "#D55E00", "#E69F00", "#56B4E9", "#009E73", "#F0E442", "#CC79A7")

# Hour of birth
Data$OnlineHour <- format(Data$Born, "%H")

# Count lives per hour
hour_data <- Data %>%
  group_by(OnlineHour) %>%
  summarise(count = n(), .groups = 'drop') %>%
  mutate(percentage = count / sum(count) * 100)

# Keep all 24 hours, including empty ones
hour_data_full <- data.frame(
  OnlineHour = sprintf("%02d", 0:23)
) %>%
  left_join(hour_data, by = "OnlineHour")

# Empty hours get 0
hour_data_full <- hour_data_full %>%
  mutate(
    count = ifelse(is.na(count), 0, count),
    percentage = ifelse(is.na(percentage), 0, percentage)
  )

# Bar chart of lives per hour
hour_plot <- ggplot(hour_data_full, aes(x = OnlineHour, y = count)) +
  geom_bar(stat = "identity", fill = "skyblue") +
  geom_text(aes(label = count), vjust = -0.5, color = "black") +
  labs(title = "Online Hours",
       x = "Hours",
       y = "Frequency") +
  scale_x_discrete(limits = sprintf("%02d", 0:23)) +
  theme_minimal()
print(hour_plot)

# Same chart with percentages
hour_percentage_plot <- ggplot(hour_data_full, aes(x = OnlineHour, y = count)) +
  geom_bar(stat = "identity", fill = "skyblue") +
  geom_text(aes(label = sprintf("%.1f%%", percentage)),
            vjust = -0.5, color = "black") +
  labs(title = "Online Hours",
       x = "Hours",
       y = "Frequency") +
  scale_x_discrete(limits = sprintf("%02d", 0:23)) +
  theme_minimal()
print(hour_percentage_plot)


# Day of the week
Data$OnlineDay <- Data$Day   # always English, whatever the computer language

# Count lives per weekday
week_data <- Data %>%
  group_by(OnlineDay) %>%
  summarise(count = n()) %>%
  mutate(percentage = count / sum(count) * 100)

# Order the weekdays Monday to Sunday
week_data$OnlineDay <- factor(week_data$OnlineDay, levels = c("Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"))

# Bar chart per weekday
week_plot <- ggplot(week_data, aes(x = OnlineDay, y = count)) +
  geom_bar(stat = "identity", fill = "skyblue") +
  geom_text(aes(label = count), vjust = -0.5, color = "black") +
  labs(title = "My Online Days of the Week",
       x = "Day of the Week",
       y = "Frequency") +
  theme_minimal()
print(week_plot)

# Same chart with percentages
week_percentage_plot <- ggplot(week_data, aes(x = OnlineDay, y = count)) +
  geom_bar(stat = "identity", fill = "skyblue") +
  geom_text(aes(label = sprintf("%.1f%%", percentage)), vjust = -0.5, color = "black") +
  labs(title = "My Online Days of the Week",
       x = "Day of the Week",
       y = "Frequency") +
  theme_minimal()
print(week_percentage_plot)

Data$Date <- as.Date(Data$Date)

# All months from the first life to now
full_months <- seq.Date(
  from = as.Date(format(min(Data$Date), "%Y-%m-01")),
  to = Sys.Date(),
  by = "month"
) %>%
  format("%Y-%m")

# Count lives per month
monthly_counts <- table(Data$Month)

# As a data frame
monthly_counts_df <- as.data.frame(monthly_counts)
colnames(monthly_counts_df) <- c("Month", "Frequency")

# Data frame with every month
full_months_df <- data.frame(Month = full_months)
full_months_df$Month <- as.character(full_months_df$Month)

# Months without lives get 0
merged_df <- full_months_df %>%
  left_join(monthly_counts_df, by = "Month") %>%
  mutate(Frequency = ifelse(is.na(Frequency), 0, Frequency))

# Line chart
Month_plot <- ggplot(merged_df, aes(x = Month, y = Frequency)) +
  geom_line(group = 1, color = "skyblue", linewidth = 1.2) +  # Thicker line
  geom_point(color = "orange", size = 3) +  # Larger points
  geom_text(aes(label = Frequency), vjust = -0.5, color = "black", size = 3) +  # Add text labels above the points
  labs(title = "Monthly Frequency", 
       x = "Month", 
       y = "Frequency") +
  theme_minimal() +  # Minimalist theme for better visual appeal
  theme(
    axis.text.x = element_text(angle = 45, hjust = 1, size = 12),  # Rotate and adjust X-axis label size
    axis.text.y = element_text(size = 12),  # Adjust Y-axis label size
    plot.title = element_text(hjust = 0.5, size = 16, face = "bold"),  # Center and bold title
    plot.margin = margin(10, 20, 10, 10)  # Add space around the plot
  ) +
  scale_x_discrete(breaks = merged_df$Month)  # Ensure all months are shown

# Count first names, without "EVE"
name_data <- Data %>%
  filter(!is.na(Name) & Name != "EVE") %>%
  group_by(Name) %>%
  summarise(count = n()) %>%
  arrange(desc(count))
# Print name counts
print(name_data)
# Top 10 names chart
name_plot <- ggplot(head(name_data, 10), aes(x = reorder(Name, count), y = count)) +
  geom_bar(stat = "identity", fill = "lightcoral") +
  geom_text(aes(label = count), hjust = -0.2, color = "black") +
  labs(title = "Top 10 Names (Excluding 'EVE')",
       x = "Name",
       y = "Frequency") +
  theme_minimal() +
  coord_flip()

# Show it
print(name_plot)

# Count surnames
surname_data <- Data %>%
  filter(!is.na(Surname)) %>%
  group_by(Surname) %>%
  summarise(count = n()) %>%
  arrange(desc(count))

# Top 10 surnames chart
surname_plot <- ggplot(head(surname_data, 10), aes(x = reorder(Surname, count), y = count)) +
  geom_bar(stat = "identity", fill = "skyblue") +
  geom_text(aes(label = count), hjust = -0.2, color = "black") +
  labs(title = "My Top 10 Surnames",
       x = "Surname",
       y = "Frequency") +
  theme_minimal() +
  coord_flip()
print(surname_plot)
print(surname_data)

# Count causes of death
Data <- Data %>%
  mutate(`Died to` = case_when(
    grepl("Boar", `Died to`, ignore.case = TRUE) ~ "Boar",
    TRUE ~ `Died to`
  )) # merge all boar types
died_to_data <- Data %>%
  filter(!is.na(`Died to`)) %>%
  group_by(`Died to`) %>%
  summarise(count = n()) %>%
  arrange(desc(count))
print(died_to_data)
# Top 10 causes of death chart
died_to_plot <- ggplot(head(died_to_data, 10), aes(x = reorder(`Died to`, count), y = count)) +
  geom_bar(stat = "identity", fill = "lightblue") +
  geom_text(aes(label = count), hjust = -0.2, color = "black") +
  labs(title = "My Top 10 Died to Reasons",
       x = "Died to",
       y = "Frequency") +
  theme_minimal() +
  coord_flip()
print(died_to_plot)

# Character sex
sex_data <- Data %>%
  group_by(Sex) %>%
  summarise(count = n()) %>%
  mutate(percentage = count / sum(count) * 100)

# Pie chart of sex
sex_plot <- ggplot(sex_data, aes(x = "", y = percentage, fill = Sex)) +
  geom_bar(stat = "identity", width = 1) +
  coord_polar("y", start = 0) +
  geom_text(aes(label = sprintf("%.1f%%", percentage)), position = position_stack(vjust = 0.5), color = "white") +
  labs(title = "My Characters Sex Distribution",
       x = "",
       y = "") +
  theme_minimal() +
  theme(axis.ticks = element_blank(), axis.text = element_blank())
print(sex_plot)

# Keep ages up to 60
filtered_data <- Data %>% filter(Age <= 60)

# Age density plot
age_density_plot_filtered <- ggplot(filtered_data, aes(x = Age)) +
  geom_density(fill = "#D3A9C9", color = "black") +
  labs(title = "Density Plot of Ages (Age <= 60)",
       x = "Age",
       y = "Density") +
  theme_minimal()


# Hours played per day
# Drop any future dates
Data_filtered <- Data %>%
  filter(as.Date(Born, tz = my_tz) <= Sys.Date())  # drop future dates

daily_playtime <- Data_filtered %>%
  mutate(
    TotalTime = as.numeric(difftime(Died, Born, units = "hours")),
    PlayDate = as.Date(Born, tz = my_tz)  # use birth date as play date
  ) %>%
  filter(!is.na(TotalTime) & TotalTime > 0) %>%
  group_by(PlayDate) %>%
  summarise(
    DailyHours = sum(TotalTime, na.rm = TRUE),
    GameCount = n(),
    .groups = 'drop'
  ) %>%
  arrange(PlayDate)

# Show the date range
cat("Date range in data: from", as.character(min(daily_playtime$PlayDate)), 
    "to", as.character(max(daily_playtime$PlayDate)), "\n")
cat("Today:", as.character(Sys.Date()), "\n")

# Every day from the first life, including days without play
date_range <- seq.Date(
  from = min(daily_playtime$PlayDate, na.rm = TRUE),
  to = min(max(daily_playtime$PlayDate, na.rm = TRUE), Sys.Date()),  # not after today
  by = "day"
)

# Data frame with every day
full_dates_df <- data.frame(PlayDate = date_range) %>%
  left_join(daily_playtime, by = "PlayDate") %>%
  mutate(
    DailyHours = ifelse(is.na(DailyHours), 0, DailyHours),
    GameCount = ifelse(is.na(GameCount), 0, GameCount)
  )

# Bar chart of daily hours
daily_playtime_plot <- ggplot(full_dates_df, aes(x = PlayDate, y = DailyHours)) +
  geom_col(fill = "steelblue", alpha = 0.8) +
  geom_point(data = full_dates_df[full_dates_df$DailyHours > 0, ], 
             aes(x = PlayDate, y = DailyHours), 
             color = "orange", size = 1.5) +  # dots on days with play
  labs(title = "Daily Playtime",
       x = "Date",
       y = "Hours per Day") +
  theme_minimal() +
  theme(
    axis.text.x = element_text(angle = 45, hjust = 1),
    plot.title = element_text(hjust = 0.5, face = "bold")
  ) +
  scale_x_date(date_breaks = "1 month", date_labels = "%Y-%m", 
               limits = c(min(full_dates_df$PlayDate), max(full_dates_df$PlayDate)))

print(daily_playtime_plot)

# Show the plot
print(age_density_plot_filtered)

combined_plot <- grid.arrange(
  hour_plot, week_plot, 
  Month_plot, age_density_plot_filtered,
  died_to_plot, sex_plot,
  name_plot, surname_plot,
  daily_playtime_plot,
  ncol = 2
)
print(combined_plot)

# Total hours played
Data$TotalTime <- difftime(Data$Died, Data$Born, units = "hours")
total_time <- sum(Data$TotalTime, na.rm = TRUE)

# Title text
title_text <- paste("Total Online Hours:", round(total_time, 2), "hours")


# Title
title_plot <- ggdraw() +
  draw_label(
    title_text,
    fontface = "bold",
    size = 16,
    hjust = 0.5
  )

# Put the title on top
combined_plot_with_title <- plot_grid(
  title_plot,
  combined_plot,
  ncol = 1,
  rel_heights = c(0.1, 1)
)

# Save the figure
file_pdf <- out_file(".pdf")
file_png <- out_file(".jpg")
#ggsave(file_pdf, plot = combined_plot_with_title, width = 14, height = 18)
ggsave(file_png, plot = combined_plot_with_title, width = 14, height = 18, dpi = 300, bg = "white")

