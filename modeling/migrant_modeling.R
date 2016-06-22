rm(list=ls())
# Load data
d <- read.csv(paste0(getwd(),"/prepdata/australiainput.csv"), header=T, stringsAsFactors = F)
# Load caret
library(caret)
library(plyr)
library(dplyr)
library(foreach)
library(doParallel)
library(doMC)
#library(doMC)

# Train/test splits -----
train.x <- d[1:80,] ; train.dates <- train.x$Date ; train.x$Date <- NULL
test.x <- d[81:115,] ; test.dates <- test.x$Date ; test.x$Date <- NULL
# Training / test for two day prediction
train.2 <- train.x ; train.2$y <- lead(train.2$y, n=1) 
train.2 <- train.2[-nrow(train.2), ] 
test.2 <- test.x ; test.2$y <- lead(test.2$y, n=1) 
test.2 <- test.2[-nrow(test.2), ]
# Training / test for three day prediction
train.3 <- train.x ; train.3$y <- lead(train.3$y, n=2) 
train.3 <- train.3[-c((nrow(train.3)-1):nrow(train.3)), ] 
test.3 <- test.x ; test.3$y <- lead(test.3$y, n=2) 
test.3 <- test.3[-c((nrow(test.3)-1):nrow(test.3)), ]
# Bind into lists
train.list <- list(train.x,train.2,train.3)
test.list <- list(test.x,test.2,test.3)

# Model parameters. Use Leave-one-out cross validation for models
trnTuners <- trainControl(
  method = "loocv")

# HELPER FUNCTIONS -----

# Return stats and plot model
modelStats <- function(model.fit, test.data, outcome.name, ndays = 1) {
  if( ndays > 3 ) {
    stop("Cannot predict more than three days ahead.")
  }
  res <- list()
  # Predict on test data
  pred <- predict(model.fit, newdata=test.data)
  # Get actual data and bind in dataframe
  actual <- test.data[,outcome.name]
  # If ndays == 2
  if( ndays == 2 ) {
    test.dates <- na.omit(lead(test.dates, n=1))
  } else if( ndays == 3 ) {
    test.dates <- na.omit(lead(test.dates, n=2))
  }
  # Bind in df
  df <- data.frame("actual" = actual,
                   "prediction" = pred,
                   "date" = test.dates)
  res$outcomes <- df
  # calculate errors
  res$absolute_error <- sum(abs(actual-pred))
  res$RMSE <- sqrt(mean((actual-pred)^2))
  # Print
  print(paste0("Absolute error is ", res$absolute_error, " and RMSE is ", res$RMSE))
  # Plot
  library(plotly)
  p <- plot_ly(res$outcomes, x=date, y=actual, name="Actual") %>% 
    add_trace(x=date, y=prediction, name="Prediction") %>%
    plotly_build()
  print(p)
  # Add to results
  res$plot_prediction_actual <- p
  # Add other plots
  res <- cumErrorPlots(df, res)
  # Return
  return(res)
}

# Cumulative error over period
cumErrorPlots <- function(df, result.list) {
  # Cumulative ABS ERROR
  df$cumError <- cumsum(abs(df$actual-df$prediction))
  
  # Plot error per day name
  library(lubridate)
  df$date <- as.Date(ymd(df$date))
  #df$dayname <- wday(df$date, label = TRUE)
  
  # Linear line
  df$LL <- max(df$cumError) / nrow(df) ; df$LL <- cumsum(df$LL) #; df$LL[1] <- df$cumError[1]
  # Add dots for days where error rises above linear line
  df$aboveLin <- ifelse(df$LL < df$cumError, 1, 0)
  # Plot
  p <- ggplot(df, aes(x=date, y=cumError)) +
    geom_line() +
    geom_line(aes(x=df$date, y=df$LL), color="darkgreen") +
    theme_bw() +
    scale_x_date() + #breaks = seq.Date(df$date[1], df$date[25], 1), labels=df$dayname
    scale_y_continuous(name ="cumulative error") +
    theme(axis.text.x = element_text(angle=90, hjust=1)) +
    geom_point(data = df[df$aboveLin == 1,], aes(x=date, y = cumError), color="red") +
    geom_segment(data=df[df$aboveLin == 1,], aes(xend=date), 
                 yend=0, 
                 size = 1,
                 color = "darkgrey") +
    ggtitle("Cumulative error over test period")
  # Add to results
  result.list$error_plot <- p
  
  # Calculate percentage change
  delta <- NULL
  for(row in 1:nrow(df)) {
    if(row == 1) {
      delta <- c(delta, NA)
    }
    today <- df[row,]$cumError
    yesterday <- df[(row-1),]$cumError
    #perc change
    pchange <- ((today - yesterday) / yesterday) * 100
    # Add
    delta <- c(delta, pchange)
  }
  # percentage increase
  df$perc_increase <- delta
  # Plot
  p_increase <- ggplot(df, aes(x=date, y=perc_increase)) +
    geom_line() +
    theme_bw() +
    scale_y_continuous(name="Percentage increase previous day") +
    ggtitle("Increase cumulative absolute error\n compared to previous day")
  # Add to list
  result.list$perc_error_increase <- p_increase
  
  # Return
  return(result.list)
}

# Register cores for parallel model computation -----

# Register cores
cl <- makeCluster(2)
registerDoParallel(cl)
# Export
clusterExport(cl, c("cumErrorPlots", "modelStats", "test.dates", "trnTuners"))

# Lasso 1 ----

model <- foreach(train = train.list, 
                 test=test.list) %dopar% {
                   library(caret)
                   library(ggplot2)
                   library(dplyr)
                   # Model parameters. Use Leave-one-out cross validation for models
                   trnTuners <- trainControl(
                     method = "loocv")
                  # Fit model
                  fit <- train(y ~ ., data = train,
                                     method = "glmnet",
                                     trControl = trnTuners)
                  # Stats
                  if(nrow(train) == 80) {
                    ndays <- 1
                  } else if( nrow(train) == 79) {
                    ndays <- 2
                  } else {
                    ndays <- 3
                  }
                  MS <- modelStats(fit, test, "y", ndays=ndays)
                  MS$model_info <- list("varImp" = plot(varImp(fit)),
                                        "model_eval" = plot(fit),
                                        "model_res" = fit$results,
                                        "final_model" = plot(fit$finalModel))
                  return(MS)
                }
# Names
names(model) <- c("predict_1day", "predict_2days", "predict_3days")
# Save modelstats
save(model, 
     file="/users/jasper/temp/migrant_models/modelstats/lasso1.Rdata")

# Lasso 2 (stepwiseAIC) -----

model <- foreach(train = train.list, 
                 test=test.list) %dopar% {
                   library(caret)
                   library(ggplot2)
                   library(dplyr)
                   # Fit model
                   fit <- train(y ~ ., data = train,
                                method = "glmStepAIC",
                                trControl = trnTuners,
                                verbose=FALSE)
                   # Stats
                   if(nrow(train) == 80) {
                     ndays <- 1
                   } else if( nrow(train) == 79) {
                     ndays <- 2
                   } else {
                     ndays <- 3
                   }
                   MS <- modelStats(fit, test, "y", ndays=ndays)
                   MS$model_info <- list("varImp" = plot(varImp(fit)))
                   return(MS)
                 }
# Names
names(model) <- c("predict_1day", "predict_2days", "predict_3days")
# Save modelstats
save(model, file="/users/jasper/temp/migrant_models/modelstats/lasso2.Rdata")

# Lasso 3 (glmboost) ----

model <- foreach(train = train.list, 
                 test=test.list) %dopar% {
                   library(caret)
                   library(ggplot2)
                   library(dplyr)
                   # Model parameters. Use Leave-one-out cross validation for models
                   trnTuners <- trainControl(
                     method = "loocv")
                   # Fit model
                   fit <- train(y ~ ., data = train,
                                method = "glmboost",
                                trControl = trnTuners,
                                weights = c(rep(1.5, 14), rep(1,21), 
                                            rep(0.8,28),rep(0.5,17)))
                   # Stats
                   if(nrow(train) == 80) {
                     ndays <- 1
                   } else if( nrow(train) == 79) {
                     ndays <- 2
                   } else {
                     ndays <- 3
                   }
                   MS <- modelStats(fit, test, "y", ndays=ndays)
                   MS$model_info <- list("varImp" = plot(varImp(fit)),
                                         "model_eval" = plot(fit),
                                         "model_res" = fit$results,
                                         "final_model" = plot(fit$finalModel))
                   return(MS)
                 }
# Names
names(model) <- c("predict_1day", "predict_2days", "predict_3days")
# Save modelstats
save(model, 
     file="/users/jasper/temp/migrant_models/modelstats/lasso3.Rdata")

# BstSm ----

model <- foreach(train = train.list, 
                 test=test.list) %dopar% {
                   library(caret)
                   library(ggplot2)
                   library(dplyr)
                   # Fit model
                   fit <- train(y ~ ., data = train,
                                method = "bstSm",
                                trControl = trnTuners)
                   # Stats
                   if(nrow(train) == 80) {
                     ndays <- 1
                   } else if( nrow(train) == 79) {
                     ndays <- 2
                   } else {
                     ndays <- 3
                   }
                   MS <- modelStats(fit, test, "y", ndays=ndays)
                   MS$model_info <- list("varImp" = plot(varImp(fit)),
                                         "model_eval" = plot(fit))
                   return(MS)
                 }
# Names
names(model) <- c("predict_1day", "predict_2days", "predict_3days")
# Save modelstats
save(model, 
     file="/users/jasper/temp/migrant_models/modelstats/bsm.Rdata")

# MARS -----

model <- foreach(train = train.list, 
                 test=test.list) %dopar% {
                   library(caret)
                   library(ggplot2)
                   library(dplyr)
                   # Fit model
                   fit <- train(y ~ ., data = train,
                                method = "gcvEarth",
                                trControl = trnTuners,
                                weights = c(rep(1.5, 21), rep(1,28), 
                                            rep(0.8,31)))
                   # Stats
                   if(nrow(train) == 80) {
                     ndays <- 1
                   } else if( nrow(train) == 79) {
                     ndays <- 2
                   } else {
                     ndays <- 3
                   }
                   MS <- modelStats(fit, test, "y", ndays=ndays)
                   MS$model_info <- list("varImp" = plot(varImp(fit)))
                   return(MS)
                 }
# Names
names(model) <- c("predict_1day", "predict_2days", "predict_3days")
# Save modelstats
save(model, 
     file="/users/jasper/temp/migrant_models/modelstats/gvce.Rdata")

# Least Angle Regression (LARS) -----

model <- foreach(train = train.list, 
                 test=test.list) %dopar% {
                   library(caret)
                   library(ggplot2)
                   library(dplyr)
                   # Fit model
                   fit <- train(y ~ ., data = train,
                                method = "lars2",
                                trControl = trnTuners)
                   # Stats
                   if(nrow(train) == 80) {
                     ndays <- 1
                   } else if( nrow(train) == 79) {
                     ndays <- 2
                   } else {
                     ndays <- 3
                   }
                   MS <- modelStats(fit, test, "y", ndays=ndays)
                   MS$model_info <- list("varImp" = plot(varImp(fit)))
                   return(MS)
                 }

# Names
names(model) <- c("predict_1day", "predict_2days", "predict_3days")
# Save modelstats
save(model, 
     file="/users/jasper/temp/migrant_models/modelstats/LARS.Rdata")

# GAMBOOST ----

model <- foreach(train = train.list, 
                 test=test.list) %dopar% {
                   library(caret)
                   library(ggplot2)
                   library(dplyr)
                   # Fit model
                   fit <- train(y ~ ., data = train,
                                method = "gamboost",
                                trControl = trnTuners)
                   # Stats
                   if(nrow(train) == 80) {
                     ndays <- 1
                   } else if( nrow(train) == 79) {
                     ndays <- 2
                   } else {
                     ndays <- 3
                   }
                   MS <- modelStats(fit, test, "y", ndays=ndays)
                   MS$model_info <- list("varImp" = plot(varImp(fit)))
                   return(MS)
                 }
# Names
names(model) <- c("predict_1day", "predict_2days", "predict_3days")
# Save modelstats
save(model, 
     file="/users/jasper/temp/migrant_models/modelstats/gb.Rdata")
