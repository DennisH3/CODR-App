# Author: Dennis Huynh
# Date Created: 02/22/2021
# Last Edited: 08/30/2021
# Use CANSIM APIs to search for a CODR table and then make a basic scatter plot.

# Look at IMDB data for dimensions/members/variables.

# Documentation for the APIs
# https://cran.r-project.org/web/packages/cansim/cansim.pdf
# https://github.com/mountainMath/cansim/blob/1e13f999fd6f4169f66d912683a79c41a2db9b9d/R/cansim_tables_list.R#L33
# https://cran.r-project.org/web/packages/CANSIM2R/CANSIM2R.pdf
# https://github.com/MarcoLugo/CANSIM2R/tree/master/R

#install.packages("https://cran.r-project.org/src/contrib/Archive/cansim/cansim_0.3.7.tar.gz", repos = NULL, type = "source")
#install.packages("Hmisc")
#install.packages("CANSIM2R")
#install.packages("plotly")

library(shiny)
library(shinyjs)
library(tidyverse)
library(data.table)
library(arrow)
library(cansim)
library(CANSIM2R)
library(Hmisc)
library(htmlwidgets)
library(plotly)
library(httr)
library(jsonlite)
library(curl) # Note: I had to conda install curl because there was an error with curl to fetch the url

# Run getMetaData.R
source("getMetaData.R")

# Run compileMetaData.R
# source("compileMetaData.R")

# allMD <- open_dataset("CODR_tables")
# 
# # Bind all files and select columns
# allMD <- allMD %>% 
#   select(productId, cansimId, cubeTitleEn, cubeTitleFr, cubeStartDate,
#          cubeEndDate, releaseTime, dimensionNameEn, dimensionNameFr,
#          memberNameEn, memberNameFr, memberUomEn, memberUomFr,
#          subjectEn, subjectFr, surveyEn, surveyFr, frequencyDescEn,
#          frequencyDescFr, footnotesEn, footnotesFr, archiveStatusEn, archiveStatusFr)

# Empty list to store each dataframe
mds = list()

# Get list of all CODR tables
files <- list.files("./CODR_tables")

# Read all CODR meta data
for (i in 1:length(files)){
  
  # Append the CODR table meta data to the end of the mds list
  mds <- append(mds, list(read_parquet(str_glue("./CODR_tables/{files[i]}"))))
}

# Bind mds into one data frame
allMD <- rbindlist(mds, use.names = TRUE, fill=TRUE)

# Select columns and remove duplicates
allMD <- allMD %>% 
  select(productId, cansimId, cubeTitleEn, cubeTitleFr, cubeStartDate,
         cubeEndDate, releaseTime, dimensionNameEn, dimensionNameFr,
         memberNameEn, memberNameFr, memberUomEn, memberUomFr,
         subjectEn, subjectFr, surveyEn, surveyFr, frequencyDescEn,
         frequencyDescFr, footnotesEn, footnotesFr, archiveStatusEn, archiveStatusFr) %>%
  distinct()

# Convert date columns to Date type
allMD$cubeStartDate <- as.Date(allMD$cubeStartDate)
allMD$cubeEndDate <- as.Date(allMD$cubeEndDate)
allMD$releaseTime <- as.Date(allMD$releaseTime)

# Define UI ----
ui <- fluidPage(

  useShinyjs(),

  # Title of page

  titlePanel("CANSIM Interactive Tool"),

  # Create the tab panel
  tabsetPanel(

    tabPanel("Search and Scatter Plot", fluid = TRUE,

             sidebarLayout(

               # Define the sidebar
               sidebarPanel(

                 # Link to StatCan Data Search Tool
                 helpText(tags$a(href="https://www150.statcan.gc.ca/n1/en/type/data", "Online Data Search Tool")),

                 # Provide instructions
                 helpText("Search for a table on StatCan and then input its table number to display the table.
                  I.e. Search for: Average usual hours. Table number: 14-10-0320"),

                 # Text input to search for tables
                 textInput("query", "Input a search query"),

                 # Submit button for the query
                 actionButton("q", "Search"),

                 # Text input to display a table
                 textInput("tableNum", "Input the Table Number of Interest"),

                 # Submit button for retrieving the data
                 actionButton("t", "Get Data"),

                 # Conditional Panel - wait for data to be retrieved
                 conditionalPanel(
                   condition = ("input.t != 0"),

                   h3("Scatterplot Graph"),

                   # Render selectInput buttons to control what variables to plot
                   uiOutput("vars")
                 )
               ),

               mainPanel(
                 dataTableOutput("searchResults"),
                 dataTableOutput("table"),  # The main datatable
                 plotlyOutput("dynSP")
               )
             )
    ),

    tabPanel("MetaData", fluid = TRUE,
             sidebarLayout(
               sidebarPanel(

                 # Render some textInput filters and action buttons
                 uiOutput("filters"),

                 # Download Button
                 downloadButton("downloadData", "Download"),

                 # Download button for unique product Tables
                 downloadButton("dlPID", "Download PIDs"),

                 # Reset Button
                 actionButton("reset", "Reset")
               ),

               mainPanel(
                 p(HTML(paste("Please refer to", a(href="https://www.statcan.gc.ca/eng/developers/wds/user-guide#a15", "https://www.statcan.gc.ca/eng/developers/wds/user-guide#a15"), "for legends on subjectCode, surveyCode, archived, and frequencyCode."))),
                 p("Please wait until the data frame is generated before you click the Download button. For each query, ensure that the Reset button is clicked. Otherwise, you will not be filtering the complete data frame."),
                 dataTableOutput("cubeData"),
                 verbatimTextOutput("totalTables"),
                 dataTableOutput("uqID")
               )
             )
    )
  )
)


server <- function(input, output) {

  # Search for data and wait until full query is completed
  query <- eventReactive(input$q, {
    if (input$query == "") {
      "Your search query is empty"
    } else {
      search_cansim_tables(input$query) %>%
        select(title, title_fr, cansim_table_number, date_published, url_en, url_fr)
    }
  })

  # Search for a CANSIM table
  output$searchResults <- renderDataTable({
    query()
  })

  # Retrieve the CANSIM table
  getData <- eventReactive(input$t, {

    # Wait until data table number is typed
    df <- getCANSIM(input$tableNum)

    # Rename the columns to their labels
    ogNames <- list()

    for (i in 1:ncol(df)){
      ogNames[[i]] <- label(df[[i]])
    }

    names(df) <- ogNames

    return(df)
  })

  # Display the table
  output$table <- renderDataTable(
    if (input$tableNum == ""){
      print("Your table number is empty")
    } else {
      getData()
    }
  )

  # Widgets to create the scatter plot
  widgets <- reactive({

    df <- getData()

    list(
      selectInput("x",
                  label = "X-variable",
                  choices = colnames(df),
                  selected = ""),

      selectInput("y",
                  label = "Y-variable",
                  choices = colnames(df),
                  selected = "")
    )

  })

  # Render the widgets on the first tab
  output$vars <- renderUI({widgets()})

  # Dynamic scatter plot
  output$dynSP <-renderPlotly({

    # Require filtered_sp()
    req(getData(), input$x, input$y)

    # Get data
    df <- getData()

    # Create scatter plot
    fig <- plot_ly(df, x = df[[input$x]], y = df[[input$y]], type = "scatter", mode = "markers")

    # Add title and axes titles
    fig <- fig %>%
      layout(title = paste(input$x, "by", input$y),
             xaxis = list(title = input$x),
             yaxis = list(title = input$y)
      )

    # Return fig
    return(fig)
  })



  # Create some text input filters
  tiFilters <- reactive({

    df <- allMD

    # Generate the text filters and action buttons
    list(

      # Filter by title in English
      textInput("titleEn", "Filter by Title in English"),
      actionButton("te", "Filter"),

      # Filter by title in French
      textInput("titleFr", "Filter by Title in French"),
      actionButton("tf", "Filter"),

      # Filter date range for Start Date
      dateRangeInput("sd", "Filter by Start Date"),
      actionButton("s", "Filter"),

      # Filter date range for End Date
      dateRangeInput("ed", "Filter by End Date"),
      actionButton("e", "Filter"),

      # Filter date range for Release Date
      dateRangeInput("rd", "Filter by Released Date"),
      actionButton("r", "Filter"),

      # Filter by dimension in English
      textInput("dimEn", "Filter by Dimension in English"),
      actionButton("de", "Filter"),

      # Filter by dimension in French
      textInput("dimFr", "Filter by Dimension in French"),
      actionButton("dFr", "Filter"),

      # Filter by member in English
      textInput("memEn", "Filter by Member in English"),
      actionButton("me", "Filter"),

      # Filter by member in French
      textInput("memFr", "Filter by Member in French"),
      actionButton("mFr", "Filter"),

      # Filter by footnote in English
      textInput("fnEn", "Filter by Footnote in English"),
      actionButton("fn", "Filter"),

      # Filter by footnote in French
      textInput("FnFr", "Filter by Footnote in French"),
      actionButton("fnFr", "Filter"),

      # Filter by Frequency (En)
      selectizeInput("freqEn", "Filter by Frequency (En)",
                     choices = unique(df$frequencyDescEn),
                     multiple = TRUE,
                     selected = NULL),
      actionButton("freq", "Filter"),

      # Filter by Frequency (Fr)
      selectizeInput("FreqFr", "Filter by Frequency (Fr)",
                     choices = unique(df$frequencyDescFr),
                     multiple = TRUE,
                     selected = NULL),
      actionButton("freqFr", "Filter"),

      # Filter by survey in English
      selectizeInput("svEn", "Filter by Survey in English",
                     choices = unique(df$surveyEn),
                     multiple = TRUE,
                     selected = NULL),
      actionButton("sv", "Filter"),

      # Filter by survey in French
      selectizeInput("SvFr", "Filter by Survey in French",
                     choices = unique(df$surveyFr),
                     multiple = TRUE,
                     selected = NULL),
      actionButton("svFr", "Filter"),

      # Filter by subject in English
      selectizeInput("subEn", "Filter by Subject in English",
                     choices = unique(df$subjectEn),
                     multiple = TRUE,
                     selected = NULL),
      actionButton("sub", "Filter"),

      # Filter by subject in French
      selectizeInput("SubFr", "Filter by Subject in French",
                     choices = unique(df$subjectFr),
                     multiple = TRUE,
                     selected = NULL),
      actionButton("subFr", "Filter")
    )

  })

  # Render the textInput filters
  output$filters <- renderUI({tiFilters()})


  # Reactive data frame stored as filtered data
  filt <- reactiveValues(df = allMD)

  # Check if action button was pressed
  observeEvent(input$te,{

    # If it was pressed, check if search isn't null
    if (input$titleEn != ""){

      # Filter title (Eng) for titles that contain the query
      filt$df <- filter(isolate(filt$df), grepl(input$titleEn, cubeTitleEn, ignore.case = TRUE))
    }
  })

  # Check if action button was pressed
  observeEvent(input$tf, {

    # If it was pressed, check if search isn't null
    if (input$titleFr != ""){

      # Filter title (Fr) for titles that contain the query
      filt$df <- filter(filt$df, grepl(input$titleFr, cubeTitleFr, ignore.case = TRUE))
    }
  })

  # Check if action button was pressed
  observeEvent(input$s, {

    # If the date ranges are not null
    if (!is.null(input$sd[1]) & !is.null(input$sd[2])){

      # Filter Start date between the dates
      filt$df <- filter(filt$df, cubeStartDate >= input$sd[1] & cubeStartDate <= input$sd[2])
    }
  })

  # Check if action button was pressed
  observeEvent(input$e, {

    # If the date ranges are not null
    if (!is.null(input$ed[1]) & !is.null(input$ed[2])){

      # Filter End date between the dates
      filt$df <- filter(filt$df, cubeEndDate >= input$ed[1] & cubeEndDate <= input$ed[2])
    }
  })

  # Check if action button was pressed
  observeEvent(input$r, {

    # If the date ranges are not null
    if (!is.null(input$rd[1]) & !is.null(input$rd[2])){

      # Filter release time between the dates
      filt$df <- filter(filt$df, releaseTime >= input$rd[1] & releaseTime <= input$rd[2])
    }
  })

  # Check if action button was pressed
  observeEvent(input$de, {

    # If the query is not null
    if (input$dimEn != ""){

      # Filter dimension (Eng) for dimensions that contain the query
      filt$df <- filter(filt$df, grepl(input$dimEn, dimensionNameEn, ignore.case = TRUE))
    }
  })

  # Check if action button was pressed
  observeEvent(input$dFr,{

    # If query is not null
    if (input$dimFr != ""){

      # Filter dimension (Fr) for dimensions that contain the query
      filt$df <- filter(filt$df, grepl(input$dimFr, dimensionNameFr, ignore.case = TRUE))
    }
  })

  # Check if action button was pressed
  observeEvent(input$me, {

    # If the query is not null
    if (input$memEn != ""){

      # Filter member (Eng) for Members that contain the query
      filt$df <- filter(filt$df, grepl(input$memEn, memberNameEn, ignore.case = TRUE))
    }
  })

  # Check if action button was pressed
  observeEvent(input$mFr, {

    # If query is not null
    if (input$memFr != ""){

      # Filter member (Fr) for dimensions that contain the query
      filt$df <- filter(filt$df, grepl(input$memFr, memberNameFr, ignore.case = TRUE))
    }
  })

  # Check if action button was pressed
  observeEvent(input$fn, {

    # If the query is not null
    if (input$fnEn != ""){

      # Filter footnotes (Eng) for Members that contain the query
      filt$df <- filter(filt$df, grepl(input$fnEn, footnotesEn, ignore.case = TRUE))
    }
  })

  # Check if action button was pressed
  observeEvent(input$fnFr, {

    # If query is not null
    if (input$FnFr != ""){

      # Filter footnotes (Fr) for dimensions that contain the query
      filt$df <- filter(filt$df, grepl(input$FnFr, footnotesFr, ignore.case = TRUE))
    }
  })

  # Check if action button was pressed
  observeEvent(input$freq, {

    # Filter frequency (Eng) for dimensions that contain the query
    filt$df <- filter(filt$df, frequencyDescEn %in% input$freqEn)
  })

  # Check if action button was pressed
  observeEvent(input$freqFr, {

    # Filter frequency (Fr) for dimensions that contain the query
    filt$df <- filter(filt$df, frequencyDescFr %in% input$FreqFr)
  })

  # Check if action button was pressed
  observeEvent(input$sv, {

    # If the query is not null
    if (input$svEn != ""){

      # Filter survey (Eng) for Members that contain the query
      filt$df <- filter(filt$df, surveyEn %in% input$svEn)
    }
  })

  # Check if action button was pressed
  observeEvent(input$svFr, {

    # If query is not null
    if (input$SvFr != ""){

      # Filter survey (Fr) for dimensions that contain the query
      filt$df <- filter(filt$df, surveyFr %in% input$SvFr)
    }
  })

  # Check if action button was pressed
  observeEvent(input$sub, {

    # If the query is not null
    if (input$subEn != ""){

      # Filter subject (Eng) for Members that contain the query
      filt$df <- filter(filt$df, subjectEn %in% input$subEn)
    }
  })

  # Check if action button was pressed
  observeEvent(input$subFr, {

    # If query is not null
    if (input$SubFr != ""){

      # Filter subject (Fr) for dimensions that contain the query
      filt$df <- filter(filt$df, subjectFr %in% input$SubFr)
    }
  })

  # Render cubeData
  output$cubeData <- renderDataTable({filt$df})

  # Render totalTables
  output$totalTables <- renderText({paste("Total number of unique tables:", length(unique(filt$df$productId)))})

  # uniqueTables
  uqt <- reactive({distinct(select(filt$df, c("productId", "cubeTitleEn", "cubeTitleFr")),
                            productId, .keep_all = TRUE)})

  # Render uqID
  output$uqID <- renderDataTable({uqt()})

  # Check if reset button was pressed
  observeEvent(input$reset, {
    # Return to original data frame
    filt$df <- allMD

    # Reset all inputs to original value
    reset("titleEn")
    reset("titleFr")
    reset("sd")
    reset("ed")
    reset("rd")
    reset("dimEn")
    reset("dimFr")
    reset("memEn")
    reset("memFr")
    reset("fnEn")
    reset("FnFr")
    reset("freqEn")
    reset("FreqFr")
    reset("svEn")
    reset("SvFr")
    reset("subEn")
    reset("SubFr")
  })

  # Download csv of selected cubeMetaData
  output$downloadData <- downloadHandler(
    filename = "cubeMetaData.csv",
    content = function(file) {
      fwrite(filt$df, file)
    }
  )

  # Download csv of pids
  output$dlPID <- downloadHandler(
    filename = "pids.csv",
    content = function(file) {
      fwrite(uqt(), file)
    }
  )
}

shinyApp(ui = ui, server = server)
