#################################
### Migrant prediction - ui.R ###
#################################

# Load shiny
library(shiny) 
library(plotly)
library(lattice)

# UI
shinyUI(pageWithSidebar( 
  # Header 
  headerPanel("Predicting number of migrants - Model comparison"), 
  # Sidebar
  sidebarPanel( 
    p("Select a model and the number of days to predict ahead."),
    # How many days predict ahead?
    sliderInput(inputId = "ndaysprediction",
                label = "Number of days to predict ahead",
                min = 1,
                max = 3,
                value = 1,
                step = 1),
    # List of models
    selectInput(inputId = "selectModel",
                label = "Select a model",
                choices=list("Lasso" = 1,
                             "Lasso with AIC feature selection" = 2,
                             "Boosted Lasso" = 3,
                             "Multivariate Adaptive Regression Splines (MARS)" = 4,
                             "Boosted Generalized Additive Model (GAM)" = 5,
                             "Boosted Smoothing Spline (BSM)" = 6,
                             "Least Angle Regression (LARS)" =7),
                selected = 1),
    actionButton("calculate", "Go!")
  ),
  # This is where the plots go
  mainPanel(
    tabsetPanel( 
      tabPanel("Model", 
               br(),
               #p("Here is a model explanation. It is super short right now because this text is simply a placeholder. "),
               #br(),
               plotlyOutput("actualpredicted"),
               br(),
               tableOutput("ErrorStatsTable")),
      tabPanel("Prediction error", 
               plotOutput("cumSumError"),
               br(),
               plotOutput("percIncreaseCumSumError")),
      tabPanel("Variable Importance",
               plotOutput("VarImp"),
               br(),
               plotOutput("modelStats")) 
    )
  )
))
