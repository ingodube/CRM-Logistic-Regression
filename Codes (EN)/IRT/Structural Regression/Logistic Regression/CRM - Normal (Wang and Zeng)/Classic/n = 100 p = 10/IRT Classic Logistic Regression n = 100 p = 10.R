# Load required packages
library(rjags)
library(bayesplot)
library(psych)
library(R2jags)
library(loo)
library(coda)
library(Metrics)
library(simcausal)
library(truncnorm)
library(doParallel)
library(foreach)
library(ggplot2)
library(tidyr)
library(dplyr)
library(EstCRM)

# Determine directories
# Resolve the repository root from the program path
main.dir = normalizePath(file.path(dirname(if (sys.nframe() > 0 && !is.null(sys.frame(1)$ofile)) sys.frame(1)$ofile else sub("^--file=", "", grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)[1])), "../../../../../../.."), winslash = "/", mustWork = TRUE)
setwd(main.dir)
Parm.dir = file.path(main.dir, 'Parameters')
Seed.dir = file.path(main.dir, 'Seeds')

# Define the number of cores
#num_cores = detectCores() - 5  # Leave one core available for other tasks

# Create a cluster with the selected number of cores
#cl = makeCluster(num_cores)
#registerDoParallel(cl)

r = 1000 # Total number of replications
n_values = c(100, 250, 500 ,1000) # Number of individuals
p_values = c(10, 20) # Number of items
Data.Tri.dir = matrix(NA, length(n_values), length(p_values))
colnames(Data.Tri.dir) = c("p = 10", "p = 20")
rownames(Data.Tri.dir) = c("n = 100", "n = 250", "n = 500","n = 1000")

# Generate true latent traits
true_thetas = list()
for (i in 1:length(n_values)) {
  set.seed(228371 + n_values[i])
  theta = rnorm(n_values[i], mean = 0, sd = 1)
  true_thetas[[as.character(n_values[i])]] = theta
  #write.table(theta, file = file.path(Parm.dir, paste0("theta_", n[i], ".txt")),
  #row.names = FALSE, quote = FALSE, dec = ".", col.names = c("theta"))
}

# Generate true item parameters
true_item_parameters = list()
for (j in 1:length(p_values)) {
  set.seed(448291 + p_values[j])
  item.parameters = matrix(NA, p_values[j], 3)
  colnames(item.parameters) = c("a", "b", "alpha")
  row.names(item.parameters) = paste("Item ", seq(1, p_values[j]), sep = '')
  item.parameters[,1] = runif(n = p_values[j], min = 0.30, max = 2.50)
  item.parameters[,2] = rnorm(n = p_values[j],  mean = 0, sd = 1)
  item.parameters[,3] = runif(n = p_values[j], min = 0.30, max = 2.50)
  true_item_parameters[[as.character(p_values[j])]] = item.parameters
  #write.table(item.parameters, file = file.path(Parm.dir, paste0("IRT_parameters_", p[j], ".txt")),
  #row.names = FALSE, quote = FALSE, dec = ".", col.names = c("a", "b", "c"))
}

# Determine directories
n = n_values[1] # n = 100
p = p_values[1] # p = 10
k = 1  # Fix k

Data.dir.IRT = file.path(main.dir, 'Simulated Data', 'IRT', 'Measurement Model', 'CRM - Normal (Wang and Zeng)', 'General', paste0('n = ',
                      n,' p = ', p))
Data.dir.Reg = file.path(main.dir, 'Simulated Data', 'Regression', 'Logistic Regression', paste0('n = ',
                      n))
Results.dir = file.path(main.dir, 'Results (EN)', 'IRT', 'Structural Regression', 'Logistic Regression', 'CRM - Normal (Wang and Zeng)', 'Classic', paste0('n = ',
                    n,' p = ', p))

# Select parameters
theta = true_thetas[[as.character(n)]]
param = true_item_parameters[[as.character(p)]]
a = param[,1]      # discrimination
b = param[,2]      # difficulty
alpha = param[,3]  # scale

# Initialize matrices
Z = matrix(NA, n, p)
Y = matrix(NA, n, p)

# Run the 1000 replications and MCMC estimation.
for (m in 1:r) {

  set.seed(49989+ m) # Vary random seeds

  # Auxiliary matrices
  theta_mat = matrix(theta, n, p)
  b_mat = matrix(b, n, p, byrow = TRUE)
  a_mat = matrix(a, n, p, byrow = TRUE)
  alpha_mat = matrix(alpha, n, p, byrow = TRUE)

  # Mean and standard deviation
  mu = alpha_mat * (theta_mat - b_mat)
  sd = alpha_mat / a_mat

  # Generate Z
  Z = matrix(rnorm(n * p, mean = as.vector(mu), sd = as.vector(sd)), n, p)

  # Transformation
  Y = k * exp(Z) / (1 + exp(Z))
  responses = Y   # Observed test score

  # Save file
  #write.table(
  #responses,
  #file = file.path(Data.dir.IRT, paste0("IRTData_", m, ".txt")),
  #row.names = FALSE,
  #quote = FALSE,
  #dec = ".",
  #col.names = FALSE
  #)
  cat("Replication ", m, "done. \n")
}

# Generate logistic-regression data
beta_0 = 0.2
beta_1 = 1.5
logito = rep(0, n)
x = true_thetas[[1]]

q = rep(0, n)
for (i in 1:n) {
  logito[i] = beta_0 + beta_1*x[i]
  q[i] = (1/(1 + exp(-logito[i])))
}

w = rep(0, n)
logistic_data = list()
for (m in 1:r) {
  set.seed(44920 + m)
  for (i in 1:n) {
    w[i] = rbern(1, q[i])
  }
  logistic_data[[as.character(m)]] = w
  #write.table(w, file = file.path(Data.dir.Reg, paste0("LogisticRegressionData_", m, ".txt")),
  #row.names = FALSE, quote = FALSE, dec = ".", col.names = FALSE)
  cat("Replication ", m, "done. \n")
}

# Calibrate IRT parameters
theta_estimates_EM = matrix(0, n, r)
a_estimates_EM = matrix(0, p, r)
b_estimates_EM = matrix(0, p, r)
alpha_estimates_EM = matrix(0, p, r)
Counter = seq(1, 1000)

# Read intermean_valuete saved results
theta_estimates_EM = read.table(paste0(Results.dir, '/theta_estimates_EM.txt'))
a_estimates_EM = read.table(paste0(Results.dir, '/a_estimates_EM.txt'))
b_estimates_EM = read.table(paste0(Results.dir, '/b_estimates_EM.txt'))
alpha_estimates_EM = read.table(paste0(Results.dir, '/alpha_estimates_EM.txt'))

for (m in Counter) {

  set.seed(32998 + m)

  # Read data
  Y = as.data.frame(read.table(paste0(Data.dir.IRT, "/IRTData_", m, ".txt")))

  # IRT calibration using the EM algorithm
  fit_IRT = EstCRMitem(Y, max.item = rep(k, p),
                       min.item = rep(0, p), max.EMCycle = 1000, converge = 0.0001,
                       type="Shojima",BFGS=TRUE)

  # Extract IRT parameters
  a_hat = as.matrix(fit_IRT$param[ , 1])
  b_hat = as.matrix(fit_IRT$param[ , 2])
  alpha_hat = as.matrix(fit_IRT$param[ , 3])

  # Armazenamento
  a_estimates_EM[, m] = a_hat
  b_estimates_EM[, m] = b_hat
  alpha_estimates_EM[, m] = alpha_hat

  # Partial save
  write.table(a_estimates_EM,
              file = file.path(Results.dir, "a_estimates_EM.txt"),
              row.names = FALSE, col.names = FALSE)
  write.table(b_estimates_EM,
              file = file.path(Results.dir, "b_estimates_EM.txt"),
              row.names = FALSE, col.names = FALSE)
  write.table(alpha_estimates_EM,
              file = file.path(Results.dir, "alpha_estimates_EM.txt"),
              row.names = FALSE, col.names = FALSE)

  # Estimate posterior theta values
  theta_fit = EstCRMperson(Y, ipar = as.matrix(fit_IRT$param),
                           max.item = rep(k, p),
                           min.item = rep(0, p))
  theta_hat = as.matrix(theta_fit$thetas)
  theta_estimates_EM[, m] = theta_hat[, 2]
  write.table(theta_estimates_EM,
              file = file.path(Results.dir, "theta_estimates_EM.txt"),
              row.names = FALSE, col.names = FALSE)

  # Atualizando contador
  Counter = Counter[Counter > m]
  write.table(Counter,
              file = file.path(Results.dir, "Counter.txt"),
              row.names = FALSE, col.names = FALSE)

  cat("Replication", m, "completed.\n")
}

true_thetas[[1]]
true_item_parameters[[1]]

# Fit logistic regression
beta_0_estimates_EM = rep(0, r)
beta_1_estimates_EM = rep(0, r)

for (m in 1:r) {

  set.seed(55627 + m)

  # Response variable
  W = read.table(paste0(Data.dir.Reg , "/LogisticRegressionData_", m, ".txt"), quote="\"", comment.char="")
  W = W$V1

  # Covariate (estimated theta)
  theta_hat = theta_estimates_EM[ , m]

  # Fit the logistic model
  fit_logit = glm(W ~ theta_hat, family = binomial(link = "logit"))

  # Extraindo coeficientes
  beta_0_estimates_EM[m] = coef(fit_logit)[1]
  beta_1_estimates_EM[m] = coef(fit_logit)[2]

  # Incremental save
  write.table(beta_0_estimates_EM,
              file = file.path(Results.dir, "beta_0_estimates_EM.txt"),
              row.names = FALSE, col.names = FALSE)

  write.table(beta_1_estimates_EM,
              file = file.path(Results.dir, "beta_1_estimates_EM.txt"),
              row.names = FALSE, col.names = FALSE)

  cat("Logistic regression - replication", m, "completed.\n")
}

# Evaluate theta
mean_theta_estimate = rep(0, n)
Bias_theta = rep(0, n)
for (i in 1:n) {
  mean_theta_estimate[i] = mean(as.numeric((theta_estimates_EM[i, ])))
  Bias_theta[i] = mean_theta_estimate[i] - true_thetas[[1]][i]
}

Bias_theta_overall = mean(Bias_theta) # Compute the overall bias across theta values.

MSE_theta = matrix(0, r, n)
for (m in 1:r) {
  for (i in 1:n) {
    MSE_theta[m, i] = as.numeric((theta_estimates_EM[i, m]) - true_thetas[[1]][i])^2
  }
}

RMSE_theta = rep(0, n)
for (i in 1:n) {
  RMSE_theta[i] = sqrt(mean(MSE_theta[, i]))
}

# Evaluate IRT parameters
mean_a_estimate = rep(0, p)
mean_b_estimate = rep(0, p)
mean_alpha_estimate = rep(0, p)
Bias_a = rep(0, p)
Bias_b = rep(0, p)
Bias_alpha = rep(0, p)
for (j in 1:p) {
  mean_a_estimate[j] = mean(as.numeric(a_estimates_EM[j, ]))
  mean_b_estimate[j] = mean(as.numeric(b_estimates_EM[j, ]))
  mean_alpha_estimate[j] = mean(as.numeric(alpha_estimates_EM[j, ]))
  Bias_a[j] = mean_a_estimate[j] - true_item_parameters[[1]][j, 1]
  Bias_b[j] = mean_b_estimate[j] - true_item_parameters[[1]][j, 2]
  Bias_alpha[j] = mean_alpha_estimate[j] - true_item_parameters[[1]][j, 3]
}

Bias_IRT = cbind(Bias_a, Bias_b, Bias_alpha) # For each item-specific parameter
Bias_a_overall = mean(Bias_a)
Bias_b_overall = mean(Bias_b)
Bias_alpha_overall = mean(Bias_alpha)

MSE_a = matrix(0, r, p)
MSE_b = matrix(0, r, p)
MSE_alpha = matrix(0, r, p)
for (m in 1:r) {
  for (j in 1:p) {
    MSE_a[m, j] = (as.numeric(a_estimates_EM[j, m]) - true_item_parameters[[1]][j, 1])^2
    MSE_b[m, j] = (as.numeric(b_estimates_EM[j, m]) - true_item_parameters[[1]][j, 2])^2
    MSE_alpha[m, j] = (as.numeric(alpha_estimates_EM[j, m]) - true_item_parameters[[1]][j, 3])^2
  }
}

RMSE_a = rep(0, p)
RMSE_b = rep(0, p)
RMSE_alpha = rep(0, p)
for (j in 1:p) {
  RMSE_a[j] = sqrt(mean(MSE_a[, j]))
  RMSE_b[j] = sqrt(mean(MSE_b[, j]))
  RMSE_alpha[j] = sqrt(mean(MSE_alpha[, j]))
}

RMSE_IRT = cbind(RMSE_a, RMSE_b, RMSE_alpha)
