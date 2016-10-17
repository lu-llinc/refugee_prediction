######################################
#### Migrant prediction - server.R ###
######################################

library(shiny)
library(ggplot2)
library(plotly)
library(reshape2)
library(lubridate)

# Prep -----
rm(list=ls())

# Path to models
#path <- "/users/jasper/temp/migrant_models/modelstats/"
path <- paste0(getwd(), "/modelstats/")
mods <- list.files(path)
# Add names
names(mods) <- c(6,5,4,7,1,2,3)

# Server
shinyServer(function(input, output) { 
  
  # When user clicks, show output.
  observeEvent(input$calculate, {
    
    # Choose model to load
    model.to.load <- mods[which(names(mods) == input$selectModel)]
    # Load
    load(file=paste0(path, model.to.load))
    
    # How many days to predict?
    if(input$ndaysprediction == 1) {
      mod.of.int <- model$predict_1day
    } else if(input$ndaysprediction == 2) {
      mod.of.int <- model$predict_2days
    } else {
      mod.of.int <- model$predict_3days
    }
    
    # Error stats
    output$ErrorStatsTable <- renderTable(
      data.frame(
        "Absolute_error" = mod.of.int$absolute_error,
        "RMSE" = mod.of.int$RMSE
      )
    )
    
    df <- mod.of.int$outcomes
    df$date <- as.Date(ymd(df$date))
    # Add plots
    output$actualpredicted <- renderPlotly({
      # Melt
      dfm <- reshape2::melt(df, "date")
      p <- ggplot(dfm, aes(x=date,y=value,color=variable)) +
        geom_line(size=1) + 
        theme_bw() +
        scale_color_manual(values=c("blue", "orange"))
      ggplotly(p)
    })
    output$cumSumError <- renderPlot({
      mod.of.int$error_plot
    })
    output$percIncreaseCumSumError <- renderPlot({
      mod.of.int$perc_error_increase
    })
    output$VarImp <- renderPlot({
      mod.of.int$model_info$varImp
    })
    
  }) # End observeevent
})
