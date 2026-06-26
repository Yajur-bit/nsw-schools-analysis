# NSW Government Schools Analysis
# Tool: R (ggplot2, dplyr, leaflet)
# Dataset: NSW Government School Locations and
#          Student Enrolment Numbers  Data.NSW
# ============================================================


# ============================================================
# SECTION 1: LOAD LIBRARIES
# ============================================================

# Before I do anything else I need to load all the packages
# that power my analysis. 



# tidyverse gives me ggplot2 for charts and dplyr for
# Data manipulation is the backbone of my whole script.
library(tidyverse)

# scales lets me format axis numbers with commas
# so 1000 displays as 1,000 on my charts
library(scales)

# leaflet builds my interactive map for Visualisation 2
library(leaflet)

# htmlwidgets lets me save the leaflet map as an
# HTML file that anyone can open in a browser
library(htmlwidgets)


# ============================================================
# SECTION 2: SET WORKING DIRECTORY AND LOAD RAW DATA
# ============================================================

# I am pointing R to my Assignment folder on my Desktop
# so every output file I create saves in the right place
setwd("~/Desktop/Assignment_2_data_visualisation")

# Quick confirmation that the path is correct
getwd()

# Now I am loading the raw CSV file from the same folder.
# The most important argument here is na.strings — I am
# telling R to treat blank cells, "np", "NA" and "N/A"
# as missing values the moment the file loads.
# "np" is the NSW Department of Education privacy
# suppression code used when Indigenous or LBOTE student
# counts are five or fewer. The dataset Readme confirms
# this so I must treat "np" as missing, never as zero.
df_raw <- read.csv(
  "NSW government school locations and student enrolment numbers.csv",
  stringsAsFactors = FALSE,
  na.strings       = c("", "np", "NA", "N/A")
)

# Confirming the dataset l
nrow(df_raw) 
ncol(df_raw) 


# ============================================================
# SECTION 3: VALIDATE RAW DATA INTEGRITY
# ============================================================

# Before I clean anything I want to verify what is actually
# in the raw data. Running checks here before my pipeline
# touches anything means I am testing the source file
# not my own cleaning code.

# I am checking there are no duplicate school codes.
# School_code should be a unique ID for every school.
# If this line runs silently there are zero duplicates.
# If it throws an error I have found a real data problem.
stopifnot(!any(duplicated(df_raw$School_code)))
cat("School_code uniqueness check: PASSED\n")

# I am checking for whitespace in key categorical columns
# on the RAW data before cleaning. This proves the source
# file was already clean which means I do not need
# str_trim() anywhere in my pipeline.
# Every result below should print 0.
cat("Whitespace check on raw data (all should be 0):\n")
cat("  Level_of_schooling:     ",
    sum(df_raw$Level_of_schooling !=
          trimws(df_raw$Level_of_schooling),
        na.rm = TRUE), "\n")
cat("  ASGS_remoteness:        ",
    sum(df_raw$ASGS_remoteness !=
          trimws(df_raw$ASGS_remoteness),
        na.rm = TRUE), "\n")
cat("  School_gender:          ",
    sum(df_raw$School_gender !=
          trimws(df_raw$School_gender),
        na.rm = TRUE), "\n")
cat("  Operational_directorate:",
    sum(df_raw$Operational_directorate !=
          trimws(df_raw$Operational_directorate),
        na.rm = TRUE), "\n")


# ============================================================
# SECTION 4: CLEAN THE DATA
# ============================================================

# During my exploratory analysis I identified four specific
# quality issues in this dataset. I am addressing each one
# below and explaining the reason for every decision I made.
# I only cleaned what I actually use in my visualisations
# because cleaning columns I never analyse would be wasted
# effort and could introduce new errors.

# ISSUE 1: Two columns that add no analytical value
# Support_classes is 100% empty across all 2210 rows.
# I checked this myself — not a single value exists.
# There is nothing to analyse so I am dropping it entirely.
# Fax has 135 missing values and is completely irrelevant
# to education data visualisation.

# ISSUE 2: Numeric columns stored as character type
# When R read the CSV it saw "np" mixed with numbers in
# columns like ICSEA_value and FOEI_Value. Since a column
# can only have one data type R called those columns text.
# Now that "np" is already NA from my na.strings argument
# I can safely convert these columns to proper numbers.
# I am also rounding Enrolment to 1 decimal place to fix
# floating point precision errors from the part-time FTE
# formula (0.1 x units studied). Cherrybrook Technology
# High School is a good example — its raw enrolment value
# is 2097.3999999999996 when it should simply be 2097.4.

# ISSUE 3: Inconsistent suburb capitalisation
# The Town_suburb column has a mix of ALL CAPS entries
# like ADAMINABY and Title Case entries like Abbotsford.
# The raw data has 1491 unique suburb strings but after
# standardising to Title Case using str_to_title() this
# reduces to 1327. That means 164 suburbs had duplicate
# spellings purely from inconsistent data entry.
# This is real deduplication work not just cosmetic.

# ISSUE 4: One school with no directorate assigned
# One school has Operational_directorate = "Unassigned".
# It has no meaningful administrative category so I am
# removing it to prevent a spurious group appearing in
# any directorate-level chart.

df <- df_raw %>%
  
  # Dropping the two useless columns (Issue 1)
  select(-Support_classes, -Fax) %>%
  
  # Converting to numeric and fixing floating point (Issue 2)
  mutate(
    Enrolment = round(as.numeric(latest_year_enrolment_FTE), 1),
    ICSEA     = as.numeric(ICSEA_value),
    FOEI      = as.numeric(FOEI_Value),
    Latitude  = as.numeric(Latitude),
    Longitude = as.numeric(Longitude)
  ) %>%
  
  # Now that I have created the clean Enrolment column I
  # do not need the original latest_year_enrolment_FTE
  select(-latest_year_enrolment_FTE) %>%
  
  # Removing the one Unassigned directorate record (Issue 4)
  filter(Operational_directorate != "Unassigned") %>%
  
  # Fixing suburb capitalisation and ordering remoteness
  # in one combined mutate to keep my code tidy
  mutate(
    
    # This reduces 1491 raw suburb strings to 1327 unique
    # values correcting 164 duplicate spellings (Issue 3)
    Town_suburb = str_to_title(Town_suburb),
    
    # I am converting remoteness to an ordered factor so
    # every chart displays it in the correct logical order
    # from urban to remote. Without this R would sort
    # alphabetically putting Inner Regional before
    # Major Cities which makes no analytical sense.
    ASGS_remoteness = factor(ASGS_remoteness,
                             levels = c(
                               "Major Cities of Australia",
                               "Inner Regional Australia",
                               "Outer Regional Australia",
                               "Remote Australia",
                               "Very Remote Australia"
                             ),
                             ordered = TRUE)
  )

# I want to note two geographic points before moving on.
# Lord Howe Island Central School sits at longitude 159.07
# degrees east — about 600km off the NSW mainland. This is
# correct. Lord Howe Island is an NSW territory so this is
# a legitimate NSW Government school. I kept it deliberately
# because removing it would misrepresent the true geographic
# scope of the NSW public school network.
# Jennings Public School has postcode 4383 which is a
# Queensland value. This is not an error — it is a border
# community where Queensland postcodes legitimately apply.


# ============================================================
# SECTION 5: CREATE TWO WORKING DATASETS
# ============================================================

# I need two separate datasets because different charts
# need different subsets of schools.

# df_all keeps all 2209 schools including the 41 with no
# enrolment figure. I use this for my map and any chart
# counting schools because every school exists geographically
# even without an enrolment number. Removing them from the
# map would make real schools disappear which is misleading.

# df_enrolment keeps only the 2168 schools with a valid
# positive enrolment. I use this for every chart that
# plots enrolment as a measured value. The 41 excluded
# schools are NSSC out-of-scope institutions mainly
# Environmental Education Centres. The dataset Readme
# confirms these schools have no enrolment by design
# not because of a data error.

df_all       <- df
df_enrolment <- df %>% filter(!is.na(Enrolment), Enrolment > 0)

# Confirming both datasets have the right row counts
nrow(df_all)        # expecting 2209
nrow(df_enrolment)  # expecting 2168


# ============================================================
# SECTION 6: SUMMARY STATISTICS
# ============================================================

# I am calculating all my key statistics before building
# any charts. Every number I quote in my report comes
# directly from this output — nothing is assumed and
# nothing is taken from external sources. This way every
# statistic in my report is verified from my own analysis.

cat("\n=== OVERALL ENROLMENT SUMMARY ===\n")
summary(df_enrolment$Enrolment)
cat("Standard deviation:", round(sd(df_enrolment$Enrolment), 1), "\n")
cat("IQR:", IQR(df_enrolment$Enrolment), "\n")
cat("Percentage of schools with 300 or fewer students:",
    round(sum(df_enrolment$Enrolment <= 300) /
            nrow(df_enrolment) * 100, 1), "%\n")

cat("\n=== SCHOOL TYPE BREAKDOWN ===\n")
df_enrolment %>%
  group_by(Level_of_schooling) %>%
  summarise(
    count        = n(),
    pct_schools  = round(n() / nrow(df_enrolment) * 100, 1),
    median_enrol = round(median(Enrolment), 1),
    mean_enrol   = round(mean(Enrolment), 1)
  ) %>%
  arrange(desc(count)) %>%
  print()

cat("\n=== REMOTENESS BREAKDOWN ===\n")
df_all %>%
  group_by(ASGS_remoteness) %>%
  summarise(
    school_count = n(),
    pct_schools  = round(n() / nrow(df_all) * 100, 1),
    total_enrol  = round(sum(Enrolment, na.rm = TRUE)),
    median_enrol = round(median(Enrolment, na.rm = TRUE), 1),
    median_ICSEA = round(median(ICSEA, na.rm = TRUE)),
    median_FOEI  = round(median(FOEI, na.rm = TRUE))
  ) %>%
  print()

cat("\n=== TOP 5 LARGEST SCHOOLS ===\n")
df_enrolment %>%
  arrange(desc(Enrolment)) %>%
  select(School_name, Enrolment,
         Level_of_schooling, ASGS_remoteness) %>%
  head(5) %>%
  print()

cat("\n=== BOTTOM 5 SMALLEST SCHOOLS ===\n")
df_enrolment %>%
  arrange(Enrolment) %>%
  select(School_name, Enrolment, ASGS_remoteness) %>%
  head(5) %>%
  print()


# ============================================================
# VISUALISATION 1: HISTOGRAM - ENROLMENT DISTRIBUTION
# ============================================================

# This addresses Requirement 1 — examine the distribution
# of student enrolments across NSW public schools.
#
# I chose a histogram because enrolment is a continuous
# numeric variable and a histogram is the most appropriate
# chart for showing distribution. It reveals the shape
# spread skewness and outliers all at once. A bar chart
# cannot do this — it only compares discrete categories.
#
# I am adding both a median and mean reference line because
# the gap between them is visual proof of right skew.
# When my mean of 356 is higher than my median of 276 it
# tells me a small number of very large metropolitan schools
# are pulling the average upward.

p1 <- ggplot(df_enrolment, aes(x = Enrolment)) +
  geom_histogram(
    binwidth = 50,
    fill     = "#2E86AB",
    colour   = "white",
    alpha    = 0.9
  ) +
  geom_vline(
    aes(xintercept = median(Enrolment)),
    colour    = "#E84855",
    linetype  = "dashed",
    linewidth = 1
  ) +
  geom_vline(
    aes(xintercept = mean(Enrolment)),
    colour    = "#F18F01",
    linetype  = "dashed",
    linewidth = 1
  ) +
  annotate("text",
           x      = median(df_enrolment$Enrolment) + 55,
           y      = 225,
           label  = paste0("Median = ",
                           round(median(df_enrolment$Enrolment))),
           colour = "#E84855",
           size   = 3.5,
           hjust  = 0
  ) +
  annotate("text",
           x      = mean(df_enrolment$Enrolment) + 55,
           y      = 205,
           label  = paste0("Mean = ",
                           round(mean(df_enrolment$Enrolment))),
           colour = "#F18F01",
           size   = 3.5,
           hjust  = 0
  ) +
  scale_x_continuous(
    labels = comma,
    breaks = seq(0, 2500, 250)
  ) +
  scale_y_continuous(labels = comma) +
  labs(
    title    = "Distribution of Student Enrolments Across NSW Public Schools",
    subtitle = paste0("n = ", comma(nrow(df_enrolment)),
                      " schools  |  Over 53% of schools enrol 300 or fewer students"),
    x        = "Full-Time Equivalent (FTE) Student Enrolment",
    y        = "Number of Schools",
    caption  = "Source: NSW Government School Locations and Student Enrolment Numbers (Data.NSW, 2026)"
  ) +
  theme_minimal(base_size = 12) +
  theme(
    plot.title       = element_text(face = "bold", size = 13),
    plot.subtitle    = element_text(colour = "grey40", size = 10),
    plot.caption     = element_text(colour = "grey50", size = 8),
    panel.grid.minor = element_blank()
  )

print(p1)
ggsave("plot1_enrolment_histogram.png", p1,
       width = 10, height = 6, dpi = 150)
cat("Plot 1 saved.\n")


# ============================================================
# VISUALISATION 2: INTERACTIVE MAP — GEOGRAPHIC DISTRIBUTION
# ============================================================

# This addresses Requirement 2 — create a map visualisation
# illustrating the geographic distribution of NSW public
# schools.
#
# I chose an interactive Leaflet map rather than a static
# ggplot map because geographic distribution is a spatial
# question that only a map can answer directly. Leaflet lets
# the reader zoom into Sydney's dense school network or pan
# across remote western NSW and click any school to see its
# individual details.
#
# I am encoding two dimensions of data in one chart.
# Circle colour shows remoteness category and circle size
# is proportional to enrolment so the reader can see both
# where schools are and how big they are at once.
#
# I am using df_all not df_enrolment because every school
# exists geographically even without an enrolment figure.
# The ifelse on radius ensures the 41 NSSC out-of-scope
# schools still appear at a fixed size instead of being
# silently dropped when Enrolment is NA.
#
# I am defining remoteness_colours here and reusing the
# same palette in Visualisation 5 so both charts use
# identical colours for the same remoteness categories.

remoteness_colours <- c(
  "Major Cities of Australia"  = "#08519C",
  "Inner Regional Australia"   = "#2171B5",
  "Outer Regional Australia"   = "#FFB347",
  "Remote Australia"           = "#FF6B6B",
  "Very Remote Australia"      = "#C9184A"
)

pal <- colorFactor(
  palette = unname(remoteness_colours),
  domain  = levels(df_all$ASGS_remoteness)
)

map2 <- leaflet(df_all) %>%
  addProviderTiles(providers$CartoDB.Positron) %>%
  addCircleMarkers(
    lng         = ~Longitude,
    lat         = ~Latitude,
    radius      = ~ifelse(
      is.na(Enrolment), 4,
      pmin(pmax(Enrolment / 150, 3), 12)
    ),
    color       = ~pal(ASGS_remoteness),
    stroke      = FALSE,
    fillOpacity = 0.7,
    popup       = ~paste0(
      "<b>", School_name, "</b><br>",
      "Level: ",      Level_of_schooling, "<br>",
      "Enrolment: ",  ifelse(
        is.na(Enrolment),
        "Not reported (NSSC out of scope)",
        paste0(round(Enrolment), " FTE")
      ), "<br>",
      "Remoteness: ", ASGS_remoteness, "<br>",
      "Suburb: ",     Town_suburb
    )
  ) %>%
  addLegend(
    pal      = pal,
    values   = ~ASGS_remoteness,
    title    = "Remoteness Category",
    position = "bottomright",
    opacity  = 0.9
  )

map2
saveWidget(map2, "plot2_school_map.html",
           selfcontained = TRUE)
cat("Plot 2 saved.\n")


# ============================================================
# VISUALISATION 3: BOXPLOT — ENROLMENT BY SCHOOL TYPE
# ============================================================

# This is the first of three charts for Requirement 3 —
# design visualisations comparing different school
# categories across NSW.
#
# I chose a boxplot rather than a bar chart because I want
# to show more than just average enrolment per school type.
# A boxplot shows the median spread IQR range and outliers
# all at once. Primary schools for example range from
# 1 FTE at Tulloona Public School to 2030 FTE at Riverbank
# Public School. A bar chart showing only averages would
# completely hide this variation.
#
# I am adding a white diamond marker to show the mean
# alongside the median. When the diamond sits to the right
# of the median line that group is right-skewed.
#
# I am excluding Environmental Education Centres and Other
# Schools because they have too few records for a
# meaningful boxplot — 22 and 2 schools respectively.

box_data <- df_enrolment %>%
  filter(!Level_of_schooling %in%
           c("Environmental Education Centre", "Other School"))

p3 <- ggplot(
  box_data,
  aes(
    x    = reorder(Level_of_schooling, Enrolment, median),
    y    = Enrolment,
    fill = Level_of_schooling
  )
) +
  geom_boxplot(
    outlier.alpha = 0.35,
    outlier.size  = 1.2,
    show.legend   = FALSE,
    width         = 0.6
  ) +
  stat_summary(
    fun    = mean,
    geom   = "point",
    shape  = 23,
    size   = 3,
    fill   = "white",
    colour = "black"
  ) +
  coord_flip() +
  scale_y_continuous(labels = comma) +
  scale_fill_manual(values = c(
    "Primary School"                = "#2E86AB",
    "Secondary School"              = "#A23B72",
    "Central/Community School"      = "#F18F01",
    "Schools for Specific Purposes" = "#C73E1D",
    "Infants School"                = "#44BBA4"
  )) +
  labs(
    title    = "Student Enrolment Distribution by School Type",
    subtitle = "Diamond = mean. Box spans IQR; whiskers extend to 1.5x IQR. Dots are outliers.",
    x        = NULL,
    y        = "Full-Time Equivalent (FTE) Student Enrolment",
    caption  = "Source: NSW Government School Locations and Student Enrolment Numbers (Data.NSW, 2026)"
  ) +
  theme_minimal(base_size = 12) +
  theme(
    plot.title         = element_text(face = "bold", size = 13),
    plot.subtitle      = element_text(colour = "grey40", size = 10),
    plot.caption       = element_text(colour = "grey50", size = 8),
    panel.grid.minor   = element_blank(),
    panel.grid.major.y = element_blank()
  )

print(p3)
ggsave("plot3_boxplot_schooltype.png", p3,
       width = 10, height = 6, dpi = 150)
cat("Plot 3 saved.\n")


# ============================================================
# VISUALISATION 4: HEATMAP — SCHOOL TYPE VS REMOTENESS
# ============================================================

# This is the second of three charts for Requirement 3.
#
# I chose a heatmap because I am asking a two-dimensional
# question — how does the mix of school types change as
# remoteness increases? One axis is remoteness and the
# other is school type. A heatmap shows both dimensions
# at once. No single-axis chart can answer this question
# as directly.
#
# I am colouring cells by row percentage rather than raw
# count so the structural shift is visible regardless of
# how many schools each remoteness category has. I am also
# showing zeros in empty cells so blank cells cannot be
# mistaken for missing data. Row totals in the y axis
# labels give immediate context for each group size.
#
# The key finding is that Central and Community Schools
# rise from 0.5% in Major Cities to 40% in Very Remote.
# Note: the 40% figure is based on only 15 schools so the
# proportion is volatile — I flag this in my report.

heat_data <- df_all %>%
  filter(!Level_of_schooling %in%
           c("Environmental Education Centre", "Other School")) %>%
  count(ASGS_remoteness, Level_of_schooling) %>%
  complete(ASGS_remoteness, Level_of_schooling,
           fill = list(n = 0)) %>%
  group_by(ASGS_remoteness) %>%
  mutate(
    pct       = round(n / sum(n) * 100, 1),
    row_total = sum(n)
  ) %>%
  ungroup() %>%
  mutate(text_colour = ifelse(pct > 35, "white", "grey20"))

p4 <- ggplot(
  heat_data,
  aes(
    x    = str_wrap(Level_of_schooling, 15),
    y    = ASGS_remoteness,
    fill = pct
  )
) +
  geom_tile(colour = "white", linewidth = 0.6) +
  geom_text(
    aes(label = paste0(n, "\n(", pct, "%)"),
        colour = text_colour),
    size = 2.9
  ) +
  scale_fill_gradient(
    low  = "#EFF7FB",
    high = "#08519C",
    name = "Row %"
  ) +
  scale_colour_identity() +
  scale_y_discrete(
    limits = rev(levels(heat_data$ASGS_remoteness)),
    labels = function(x) {
      totals <- heat_data %>%
        group_by(ASGS_remoteness) %>%
        summarise(row_total = first(row_total)) %>%
        deframe()
      paste0(x, "  (n=", totals[x], ")")
    }
  ) +
  labs(
    title    = "School Type Composition Across NSW Remoteness Categories",
    subtitle = "Central/Community Schools rise from 0.5% in Major Cities to 40% in Very Remote areas",
    x        = "School Type",
    y        = "Remoteness Category",
    caption  = "Source: NSW Government School Locations and Student Enrolment Numbers (Data.NSW, 2026)"
  ) +
  theme_minimal(base_size = 11) +
  theme(
    plot.title    = element_text(face = "bold", size = 13),
    plot.subtitle = element_text(colour = "grey40", size = 10),
    plot.caption  = element_text(colour = "grey50", size = 8),
    panel.grid    = element_blank(),
    axis.text.x   = element_text(angle = 20, hjust = 1),
    plot.margin   = margin(10, 20, 10, 10)
  )

print(p4)
ggsave("plot4_heatmap_type_remoteness.png", p4,
       width = 13, height = 6, dpi = 150)
cat("Plot 4 saved.\n")


# ============================================================
# VISUALISATION 5: SCATTER PLOT — FOEI VS ENROLMENT
# ============================================================

# This is the third and final chart for Requirement 3.
#
# I chose a scatter plot because I want to explore the
# relationship between educational disadvantage and school
# size. A scatter plot is the only chart type that shows
# the relationship between two continuous variables — FOEI
# and Enrolment — while encoding a third variable through
# colour which is remoteness here.
#
# FOEI is the Family Occupation and Education Index. The
# dataset Readme describes it as a school-level index of
# educational disadvantage. Higher FOEI means greater
# disadvantage. I chose FOEI because it is a more direct
# disadvantage measure than ICSEA.
#
# The dashed trend line confirms that as disadvantage
# increases enrolment tends to decrease. Remote and Very
# Remote schools cluster in the bottom right — high FOEI
# and low enrolment — which is the most important pattern
# in my entire analysis.
#
# This chart shows association not causation. The pattern
# reflects entangled geographic demographic and socio-
# economic factors not a simple causal relationship.
#
# I am reusing remoteness_colours from Visualisation 2
# so both charts use identical colours for remoteness.

scatter_data <- df_enrolment %>%
  filter(!is.na(FOEI))

p5 <- ggplot(
  scatter_data,
  aes(
    x      = FOEI,
    y      = Enrolment,
    colour = ASGS_remoteness
  )
) +
  geom_point(alpha = 0.5, size = 2.2) +
  geom_smooth(
    method    = "lm",
    se        = FALSE,
    colour    = "black",
    linewidth = 0.9,
    linetype  = "dashed"
  ) +
  scale_colour_manual(
    values = remoteness_colours,
    name   = "Remoteness"
  ) +
  scale_y_continuous(labels = comma) +
  labs(
    title    = "Educational Disadvantage vs Student Enrolment by Remoteness",
    subtitle = "Higher FOEI = greater disadvantage. Remote schools cluster: high FOEI, low enrolment.",
    x        = "FOEI Value (higher value = greater socio-educational disadvantage)",
    y        = "Full-Time Equivalent (FTE) Student Enrolment",
    caption  = "Source: NSW Government School Locations and Student Enrolment Numbers (Data.NSW, 2026)"
  ) +
  theme_minimal(base_size = 12) +
  theme(
    plot.title       = element_text(face = "bold", size = 13),
    plot.subtitle    = element_text(colour = "grey40", size = 10),
    plot.caption     = element_text(colour = "grey50", size = 8),
    panel.grid.minor = element_blank(),
    legend.position  = "right"
  )

print(p5)
ggsave("plot5_scatter_foei_enrolment.png", p5,
       width = 11, height = 6, dpi = 150)
cat("Plot 5 saved.\n")

