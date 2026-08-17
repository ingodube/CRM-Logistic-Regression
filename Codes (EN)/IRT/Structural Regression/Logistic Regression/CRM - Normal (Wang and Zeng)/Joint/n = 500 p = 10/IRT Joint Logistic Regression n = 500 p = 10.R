# Load required packages
library(rjags)
library(bayesplot)
library(psych)
library(R2jags)
library(loo)
library(coda)
library(Metrics)
library(mcmcplots)
library(simcausal)
library(truncnorm)
library(doParallel)
library(foreach)
library(ggplot2)
library(tidyr)
library(dplyr)

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
n = n_values[3] # n = 500
p = p_values[1] # p = 10
k = 1  # Fix k

Data.dir.IRT = file.path(main.dir, 'Simulated Data', 'IRT', 'Measurement Model', 'CRM - Normal (Wang and Zeng)', 'General', paste0('n = ',
                      n,' p = ', p))
Data.dir.Reg = file.path(main.dir, 'Simulated Data', 'Regression', 'Logistic Regression', paste0('n = ',
                      n))
Results.dir = file.path(main.dir, 'Results (EN)', 'IRT', 'Structural Regression', 'Logistic Regression', 'CRM - Normal (Wang and Zeng)', 'Joint', paste0('n = ',
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

  set.seed(121182 + m) # Vary random seeds

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
x = true_thetas[[3]]

q = rep(0, n)
for (i in 1:n) {
  logito[i] = beta_0 + beta_1*x[i]
  q[i] = (1/(1 + exp(-logito[i])))
}

w = rep(0, n)
logistic_data = list()
for (m in 1:r) {
  set.seed(322281 + m)
  for (i in 1:n) {
    w[i] = rbern(1, q[i])
  }
  logistic_data[[as.character(m)]] = w
  #write.table(w, file = file.path(Data.dir.Reg, paste0("LogisticRegressionData_", m, ".txt")),
  #row.names = FALSE, quote = FALSE, dec = ".", col.names = FALSE)
  cat("Replication ", m, "done. \n")
}

# Write the model (weakly informative priors)
model_specification = "
model {
  for (i in 1:n) {
    for (j in 1:p) {
      Z[i, j] ~ dnorm(alpha[j]*(theta[i] - b[j]), tau[i, j])
      tau[i, j] <- pow(alpha[j]/a[j], -2)
    }
    W[i] ~ dbin((ilogit(beta_0 + beta_1*theta[i])), 1)
    theta[i] ~ dnorm(0.0, 1.0)
  }

  for (j in 1:p) {
    a[j] ~ dnorm(1.0, 0.001) T(0, )
    b[j] ~ dnorm (0.0, 0.001)
    alpha[j] ~ dnorm (1.0, 0.001) T(0, )
  }
  beta_0 ~ dnorm(0.0, 1.0E-06)
  beta_1 ~ dnorm(0.0, 1.0E-06)
}
"

writeLines(model_specification, con='modelsimCRMreglognormal.txt')
jags.inits = function(chain) {
  list("a" = rep(1, p),
       "b" = rep(0, p),
       "alpha" = rep(1, p),
       "theta" = rep(0, n),
       "beta_0" = 0,
       "beta_1" = 0)
}
params.jags = c("a", "b", "alpha", "theta", "beta_0", "beta_1")
theta_estimates_mean = matrix(0, n, r)
a_estimates_mean = matrix(0, p, r)
b_estimates_mean = matrix(0, p, r)
alpha_estimates_mean = matrix(0, p, r)
beta_0_estimates_mean = rep(0, r)
beta_1_estimates_mean = rep(0, r)
rm(Z) # Remove Z before replication-level estimation

# Set the number of Markov chains
nchains = 3
Counter = seq(1, 1000) # Restrict to the first replications when requested

# Read saved data
theta_estimates_mean = read.table(paste0(Results.dir, '/theta_estimates_mean.txt'), quote="\"", comment.char="")
a_estimates_mean = read.table(paste0(Results.dir, '/a_estimates_mean.txt'), quote="\"", comment.char="")
b_estimates_mean = read.table(paste0(Results.dir, '/b_estimates_mean.txt'), quote="\"", comment.char="")
alpha_estimates_mean = read.table(paste0(Results.dir, '/alpha_estimates_mean.txt'), quote="\"", comment.char="")
beta_0_estimates_mean = read.table(paste0(Results.dir, '/beta_0_estimates_mean.txt'), quote="\"", comment.char="")
beta_1_estimates_mean = read.table(paste0(Results.dir, '/beta_1_estimates_mean.txt'), quote="\"", comment.char="")
beta_0_estimates_mean = as.numeric(beta_0_estimates_mean$V1)
beta_1_estimates_mean = as.numeric(beta_1_estimates_mean$V1)

# Read the replication counter
Counter = read.table(paste0(Results.dir, '/Counter.txt'), quote="\"", comment.char="")
Counter = Counter$V1

for (m in Counter){
  set.seed(29111 + m)
  Y = read.table(paste0(Data.dir.IRT, "/IRTData_", m, ".txt"), quote="\"", comment.char="")
  Z = log(Y/(k - Y))
  W = read.table(paste0(Data.dir.Reg , "/LogisticRegressionData_", m, ".txt"), quote="\"", comment.char="")
  W = W$V1
  data_list = list("Z" = Z, "W" = W, "n" = n, "p" = p)

  # Load the model in JAGS
  model_specification_jags = jags.model(file = "modelsimCRMreglognormal.txt",
                           data = data_list,
                           inits = function() jags.inits(chain = 1:nchains),
                           n.chains = nchains, n.adapt = 2000)

  # Burn-in period
  update(model_specification_jags, n.iter = 2000)

  # Posterior sampling
  samples = coda.samples(model = model_specification_jags, variable.names = params.jags,
                          n.iter = 4000, thin = 1)

  # Convert to a simulation list
  sims_list = as.matrix(samples)

  # Thetas
  thetas_novos = sims_list[, grep("^theta", colnames(sims_list))]
  theta.int = apply(thetas_novos, 2, mean)
  theta_estimates_mean[, m] = theta.int
  write.table(theta_estimates_mean, file = file.path(Results.dir, paste0("theta_estimates_mean.txt")),
              row.names = FALSE, quote = FALSE, dec = ".", col.names = FALSE)

  # IRT parameters

  # Parameter a
  a_novos = sims_list[, grep("^a\\[", colnames(sims_list))]
  a.int = apply(a_novos, 2, mean)
  a_estimates_mean[, m] = a.int
  write.table(a_estimates_mean, file = file.path(Results.dir, paste0("a_estimates_mean.txt")),
              row.names = FALSE, quote = FALSE, dec = ".", col.names = FALSE)

  # Parameter b
  b_novos = sims_list[, grep("^b\\[", colnames(sims_list))]
  b.int = apply(b_novos, 2, mean)
  b_estimates_mean[, m] = b.int
  write.table(b_estimates_mean, file = file.path(Results.dir, paste0("b_estimates_mean.txt")),
              row.names = FALSE, quote = FALSE, dec = ".", col.names = FALSE)

  # Parameter c
  alpha_novos = sims_list[, grep("^alpha\\[", colnames(sims_list))]
  alpha.int = apply(alpha_novos, 2, mean)
  alpha_estimates_mean[, m] = alpha.int
  write.table(alpha_estimates_mean, file = file.path(Results.dir, paste0("alpha_estimates_mean.txt")),
              row.names = FALSE, quote = FALSE, dec = ".", col.names = FALSE)

  # Betas
  beta_0_novos = sims_list[, grep("beta_0", colnames(sims_list))]
  beta_1_novos = sims_list[, grep("beta_1", colnames(sims_list))]
  beta_0.int = mean(beta_0_novos)
  beta_1.int = mean(beta_1_novos)
  beta_0_estimates_mean[m] = beta_0.int
  beta_1_estimates_mean[m] = beta_1.int
  write.table(beta_0_estimates_mean, file = file.path(Results.dir, paste0("beta_0_estimates_mean.txt")),
              row.names = FALSE, quote = FALSE, dec = ".", col.names = FALSE)
  write.table(beta_1_estimates_mean, file = file.path(Results.dir, paste0("beta_1_estimates_mean.txt")),
              row.names = FALSE, quote = FALSE, dec = ".", col.names = FALSE)

  # Save the replication counter
  Counter = Counter[Counter > m]
  write.table(Counter, file = file.path(Results.dir, paste0("Counter.txt")),
              row.names = FALSE, quote = FALSE, dec = ".", col.names = FALSE)

  # Display progress
  cat("Replication ", m, " completed.\n")
}

# Chain diagnostics for the last processed replication
jags_samples = as.mcmc.list(samples)
traceplot(samples[, "beta_1"])
mcmc_dens(jags_samples, pars = "theta[57]")

beta_1_estimates_mean
mean(beta_1_estimates_mean)

true_thetas[[3]]
true_item_parameters[[1]]

# Evaluate theta
mean_theta_estimate = rep(0, n)
Bias_theta = rep(0, n)
for (i in 1:n) {
  mean_theta_estimate[i] = mean(as.numeric((theta_estimates_mean[i, ])))
  Bias_theta[i] = mean_theta_estimate[i] - true_thetas[[3]][i]
}

round(Bias_theta, 6)
Bias_theta_overall = mean(Bias_theta) # Compute the overall bias across theta values.

MSE_theta = matrix(0, r, n)
for (m in 1:r) {
  for (i in 1:n) {
    MSE_theta[m, i] = as.numeric((theta_estimates_mean[i, m]) - true_thetas[[3]][i])^2
  }
}

RMSEA_theta = rep(0, n)
for (i in 1:n) {
  RMSEA_theta[i] = sqrt(mean(MSE_theta[, i]))
}

# Evaluate IRT parameters
mean_a_estimate = rep(0, p)
mean_b_estimate = rep(0, p)
mean_alpha_estimate = rep(0, p)
Bias_a = rep(0, p)
Bias_b = rep(0, p)
Bias_alpha = rep(0, p)
for (j in 1:p) {
  mean_a_estimate[j] = mean(as.numeric(a_estimates_mean[j, ]))
  mean_b_estimate[j] = mean(as.numeric(b_estimates_mean[j, ]))
  mean_alpha_estimate[j] = mean(as.numeric(alpha_estimates_mean[j, ]))
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
    MSE_a[m, j] = (as.numeric(a_estimates_mean[j, m]) - true_item_parameters[[1]][j, 1])^2
    MSE_b[m, j] = (as.numeric(b_estimates_mean[j, m]) - true_item_parameters[[1]][j, 2])^2
    MSE_alpha[m, j] = (as.numeric(alpha_estimates_mean[j, m]) - true_item_parameters[[1]][j, 3])^2
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
