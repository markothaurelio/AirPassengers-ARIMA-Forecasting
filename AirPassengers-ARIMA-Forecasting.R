# Load necessary libraries
library(forecast)
library(tseries)
library(ggplot2)


# This generates neighboring models +- 1 of intial for p,q and adds an extra specified one
generate_models <- function(ts_data, p, d, q) {
  models <- list()
  visited_keys <- character()
  
  try_add_model <- function(p_try, q_try) {
    if (p_try < 0 || q_try < 0) return()
    key <- sprintf("ARIMA(%d,%d,%d)", p_try, d, q_try)
    if (!(key %in% visited_keys)) {
      models[[key]] <<- Arima(ts_data, order = c(p_try, d, q_try), method="ML")
      visited_keys <<- c(visited_keys, key)
    }
  }
  
  # Adds initial model
  try_add_model(p, q)
  
  # Adds neighbor models
  for (dp in -1:1) {
    for (dq in -1:1) {
      if (dp != 0 || dq != 0) {
        try_add_model(p + dp, q + dq)
      }
    }
  }

  try_add_model(20,12)
  
  return(models)
}


# Load data
data("AirPassengers")

# Raw plot
autoplot(AirPassengers) + ggtitle("Monthly Air Passengers") +
  xlab("Year") + ylab("Passengers (1000s)")

# Data decomposition
decomp <- decompose(AirPassengers, type = "multiplicative")
autoplot(decomp)

# Seasonally adjusted series
AP_adj <- seasadj(decomp)

# Stationarity check (ADF test)
adf.test(AP_adj)  # likely non-stationary, so difference

# First difference to remove trend
AP_diff <- diff(AP_adj)

# Stationarity check on diff (ADF test)
adf.test(AP_diff)  # likely non-stationary, so difference

plot(AP_diff, main = "First Differenced Series")

# ACF PACF

par(mfrow = c(1,2))

acf(as.numeric(AP_diff), lag.max = 20, main = "ACF (lags 1 to 20)", xaxt = "n")
axis(1, at = 0:20)

pacf(as.numeric(AP_diff), lag.max = 20, main = "PACF (lags 1 to 20)", xaxt = "n")
axis(1, at = 0:20)

# ACF & PACF data
acf_result <- acf(AP_diff, plot = FALSE)
data.frame(Lag = acf_result$lag,
           ACF = acf_result$acf)
pacf_result <- pacf(AP_diff, plot = FALSE)
data.frame(Lag = pacf_result$lag,
           PACF = pacf_result$acf)

# Gen the models
models <- generate_models(AP_adj, p = 4, d = 1, q = 4)

# Compare AICs
model_aics <- sapply(models, AIC)
print(model_aics)

# Compare BICs
model_bics <- sapply(models, BIC)
print(model_bics)

best_model <- Arima(AP_adj, order = c(5, 1, 4))

# Drift term was statistically significant so this is used
best_model_with_drift <- Arima(AP_adj, order = c(5, 1, 4), include.drift = TRUE)

# Residual diagnostics
checkresiduals(best_model)
summary(best_model)
summary(best_model_with_drift)


# Forecast for next 3 years (36 months)
forecast_AP <- forecast(best_model_with_drift, h = 36)

# Print forecast raw data
forecast_AP

# Plot fitted values and forecast
autoplot(forecast_AP) +
  autolayer(forecast_AP$mean, series = "Forecast") +  
  autolayer(fitted(best_model_with_drift), series = "Fitted") +
  xlab("Year") + ylab("Passengers") +
  ggtitle("AirPassengers Forecast for Next 3 Years") +
  guides(colour = guide_legend(title = "Series"))

