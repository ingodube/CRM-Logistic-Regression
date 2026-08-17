# Carregando pacotes necessários
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

# Determinando os diretórios
# Mudar o diretório em caso de mudar de máquina
main.dir = normalizePath(file.path(dirname(if (sys.nframe() > 0 && !is.null(sys.frame(1)$ofile)) sys.frame(1)$ofile else sub("^--file=", "", grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)[1])), "../../../../../../.."), winslash = "/", mustWork = TRUE)
setwd(main.dir)
Parm.dir = file.path(main.dir, 'Parâmetros')
Seed.dir = file.path(main.dir, 'Sementes')

# Definindo o número de núcleos
#num_cores = detectCores() - 5  # Deixe um núcleo livre para outras tarefas

# Criando um cluster com o número de núcleos
#cl = makeCluster(num_cores)
#registerDoParallel(cl)

r = 1000 # Número de replicações totais
n_values = c(100, 250, 500 ,1000) # Número de indivíduos
p_values = c(10, 20) # Número de itens
Dados.Tri.dir = matrix(NA, length(n_values), length(p_values))
colnames(Dados.Tri.dir) = c("p = 10", "p = 20")
rownames(Dados.Tri.dir) = c("n = 100", "n = 250", "n = 500","n = 1000")

# Gerando as habilidades reais
thetas_reais = list()
for (i in 1:length(n_values)) {
  set.seed(228371 + n_values[i])
  theta = rnorm(n_values[i], mean = 0, sd = 1)
  thetas_reais[[as.character(n_values[i])]] = theta
  #write.table(theta, file = file.path(Parm.dir, paste0("theta_", n[i], ".txt")),
  #row.names = FALSE, quote = FALSE, dec = ".", col.names = c("theta"))
}

# Gerando parâmetros dos itens reais
param_itens_reais = list()
for (j in 1:length(p_values)) {
  set.seed(448291 + p_values[j])
  param.itens = matrix(NA, p_values[j], 3)
  colnames(param.itens) = c("a", "b", "alpha")
  row.names(param.itens) = paste("Item ", seq(1, p_values[j]), sep = '')
  param.itens[,1] = runif(n = p_values[j], min = 0.30, max = 2.50)
  param.itens[,2] = rnorm(n = p_values[j],  mean = 0, sd = 1)
  param.itens[,3] = runif(n = p_values[j], min = 0.30, max = 2.50)
  param_itens_reais[[as.character(p_values[j])]] = param.itens
  #write.table(param.itens, file = file.path(Parm.dir, paste0("parâmetrosTRI_", p[j], ".txt")),
  #row.names = FALSE, quote = FALSE, dec = ".", col.names = c("a", "b", "c"))
}

# Determinando os diretórios
n = n_values[4] # n = 1000
p = p_values[1] # p = 10
k = 1  # Fixando k

Dados.dir.TRI = file.path(main.dir, 'Simulated Data', 'IRT', 'Measurement Model', 'CRM - Normal (Wang and Zeng)', 'General', paste0('n = ',
                      n,' p = ', p))
Dados.dir.Reg = file.path(main.dir, 'Simulated Data', 'Regression', 'Logistic Regression', paste0('n = ',
                      n))
Results.dir = file.path(main.dir, 'Results (PT-BR)', 'TRI', 'Regressão Estrutural', 'Regressão Logística', 'CRM - Normal (Wang e Zeng)', 'Classic', paste0('n = ',
                    n,' p = ', p))

# Pegando parâmetros
theta = thetas_reais[[as.character(n)]]
param = param_itens_reais[[as.character(p)]]
a = param[,1]      # discriminação
b = param[,2]      # dificuldade
alpha = param[,3]  # escala

# Inicializando matrizes
Z = matrix(NA, n, p)
Y = matrix(NA, n, p)

# Realizando as 1000 replicatas e implementar o MCMC.
for (m in 1:r) {

  set.seed(229182 + m) # Variando as seeds

  # Matrizes auxiliares
  theta_mat = matrix(theta, n, p)
  b_mat = matrix(b, n, p, byrow = TRUE)
  a_mat = matrix(a, n, p, byrow = TRUE)
  alpha_mat = matrix(alpha, n, p, byrow = TRUE)

  # Média e desvio padrão
  mu = alpha_mat * (theta_mat - b_mat)
  sd = alpha_mat / a_mat

  # Gerando Z
  Z = matrix(rnorm(n * p, mean = as.vector(mu), sd = as.vector(sd)), n, p)

  # Transformação
  Y = k * exp(Z) / (1 + exp(Z))
  resultados = Y   # Escore observado no teste

  # Salvando arquivo
  #write.table(
  #resultados,
  #file = file.path(Dados.dir.TRI, paste0("IRTData_", m, ".txt")),
  #row.names = FALSE,
  #quote = FALSE,
  #dec = ".",
  #col.names = FALSE
  #)
  cat("Replicação ", m, "done. \n")
}

# Gerando os dados da regressão logística
beta_0 = 0.2
beta_1 = 1.5
logito = rep(0, n)
x = thetas_reais[[4]]

q = rep(0, n)
for (i in 1:n) {
  logito[i] = beta_0 + beta_1*x[i]
  q[i] = (1/(1 + exp(-logito[i])))
}

w = rep(0, n)
data.logistico = list()
for (m in 1:r) {
  set.seed(22913 + m)
  for (i in 1:n) {
    w[i] = rbern(1, q[i])
  }
  data.logistico[[as.character(m)]] = w
  write.table(w, file = file.path(Dados.dir.Reg, paste0("LogisticRegressionData_", m, ".txt")),
  row.names = FALSE, quote = FALSE, dec = ".", col.names = FALSE)
  cat("Replicação ", m, "done. \n")
}

# Calibrando os parâmetros da TRI
theta_estimados_EM = matrix(0, n, r)
a_estimados_EM = matrix(0, p, r)
b_estimados_EM = matrix(0, p, r)
alpha_estimados_EM = matrix(0, p, r)
Contador = seq(1, 1000)

# Lendo os salvamentos intermediários
theta_estimados_EM = read.table(paste0(Results.dir, '/theta_estimados_EM.txt'))
a_estimados_EM = read.table(paste0(Results.dir, '/a_estimados_EM.txt'))
b_estimados_EM = read.table(paste0(Results.dir, '/b_estimados_EM.txt'))
alpha_estimados_EM = read.table(paste0(Results.dir, '/alpha_estimados_EM.txt'))

for (m in Contador) {

  set.seed(32998 + m)

  # Lendo os dados
  Y = as.data.frame(read.table(paste0(Dados.dir.TRI, "/IRTData_", m, ".txt")))

  # Calibração da TRI via algoritmo EM
  fit_TRI = EstCRMitem(Y, max.item = rep(k, p),
                       min.item = rep(0, p), max.EMCycle = 1000, converge = 0.0001,
                       type="Shojima",BFGS=TRUE)

  # Extração dos parâmetros da TRI
  a_hat = as.matrix(fit_TRI$param[ , 1])
  b_hat = as.matrix(fit_TRI$param[ , 2])
  alpha_hat = as.matrix(fit_TRI$param[ , 3])

  # Armazenamento
  a_estimados_EM[, m] = a_hat
  b_estimados_EM[, m] = b_hat
  alpha_estimados_EM[, m] = alpha_hat

  # Salvamento parcial
  write.table(a_estimados_EM,
              file = file.path(Results.dir, "a_estimados_EM.txt"),
              row.names = FALSE, col.names = FALSE)
  write.table(b_estimados_EM,
              file = file.path(Results.dir, "b_estimados_EM.txt"),
              row.names = FALSE, col.names = FALSE)
  write.table(alpha_estimados_EM,
              file = file.path(Results.dir, "alpha_estimados_EM.txt"),
              row.names = FALSE, col.names = FALSE)

  # Estimando os thetas à posteriori
  fit_theta = EstCRMperson(Y, ipar = as.matrix(fit_TRI$param),
                           max.item = rep(k, p),
                           min.item = rep(0, p))
  theta_hat = as.matrix(fit_theta$thetas)
  theta_estimados_EM[, m] = theta_hat[, 2]
  write.table(theta_estimados_EM,
              file = file.path(Results.dir, "theta_estimados_EM.txt"),
              row.names = FALSE, col.names = FALSE)

  # Atualizando contador
  Contador = Contador[Contador > m]
  write.table(Contador,
              file = file.path(Results.dir, "Contador.txt"),
              row.names = FALSE, col.names = FALSE)

  cat("Replicação", m, "concluída.\n")
}

thetas_reais[[4]]
param_itens_reais[[1]]

# Implementando a regressão logística
beta_0_estimados_EM = rep(0, r)
beta_1_estimados_EM = rep(0, r)

for (m in 1:r) {

  set.seed(791201 + m)

  # Variável resposta
  W = read.table(paste0(Dados.dir.Reg , "/LogisticRegressionData_", m, ".txt"), quote="\"", comment.char="")
  W = W$V1

  # Covariável (theta estimado)
  theta_hat = theta_estimados_EM[ , m]

  # Ajuste do modelo logístico
  fit_logit = glm(W ~ theta_hat, family = binomial(link = "logit"))

  # Extraindo coeficientes
  beta_0_estimados_EM[m] = coef(fit_logit)[1]
  beta_1_estimados_EM[m] = coef(fit_logit)[2]

  # Salvamento incremental
  write.table(beta_0_estimados_EM,
              file = file.path(Results.dir, "beta_0_estimados_EM.txt"),
              row.names = FALSE, col.names = FALSE)

  write.table(beta_1_estimados_EM,
              file = file.path(Results.dir, "beta_1_estimados_EM.txt"),
              row.names = FALSE, col.names = FALSE)

  cat("Regressão logística - replicação", m, "concluída.\n")
}

# Avaliando theta
theta.est.médio = rep(0, n)
Vício_theta = rep(0, n)
for (i in 1:n) {
  theta.est.médio[i] = mean(as.numeric((theta_estimados_EM[i, ])))
  Vício_theta[i] = theta.est.médio[i] - thetas_reais[[4]][i]
}

round(Vício_theta, 6)
Vício_theta_geral = mean(Vício_theta) # Para encontrar o vício "geral" de todos os thetas.

EQM_theta = matrix(0, r, n)
for (m in 1:r) {
  for (i in 1:n) {
    EQM_theta[m, i] = as.numeric((theta_estimados_EM[i, m]) - thetas_reais[[4]][i])^2
  }
}

RMSE_theta = rep(0, n)
for (i in 1:n) {
  RMSE_theta[i] = sqrt(mean(EQM_theta[, i]))
}

# Avaliando os parâmetros da TRI
a.est.médio = rep(0, p)
b.est.médio = rep(0, p)
alpha.est.médio = rep(0, p)
Vício_a = rep(0, p)
Vício_b = rep(0, p)
Vício_alpha = rep(0, p)
for (j in 1:p) {
  a.est.médio[j] = mean(as.numeric(a_estimados_EM[j, ]))
  b.est.médio[j] = mean(as.numeric(b_estimados_EM[j, ]))
  alpha.est.médio[j] = mean(as.numeric(alpha_estimados_EM[j, ]))
  Vício_a[j] = a.est.médio[j] - param_itens_reais[[1]][j, 1]
  Vício_b[j] = b.est.médio[j] - param_itens_reais[[1]][j, 2]
  Vício_alpha[j] = alpha.est.médio[j] - param_itens_reais[[1]][j, 3]
}

Vício_TRI = cbind(Vício_a, Vício_b, Vício_alpha) # Para cada parâmetro individualizado
Vício_a_geral = mean(Vício_a)
Vício_b_geral = mean(Vício_b)
Vício_alpha_geral = mean(Vício_alpha)

EQM_a = matrix(0, r, p)
EQM_b = matrix(0, r, p)
EQM_alpha = matrix(0, r, p)
for (m in 1:r) {
  for (j in 1:p) {
    EQM_a[m, j] = (as.numeric(a_estimados_EM[j, m]) - param_itens_reais[[1]][j, 1])^2
    EQM_b[m, j] = (as.numeric(b_estimados_EM[j, m]) - param_itens_reais[[1]][j, 2])^2
    EQM_alpha[m, j] = (as.numeric(alpha_estimados_EM[j, m]) - param_itens_reais[[1]][j, 3])^2
  }
}

RMSE_a = rep(0, p)
RMSE_b = rep(0, p)
RMSE_alpha = rep(0, p)
for (j in 1:p) {
  RMSE_a[j] = sqrt(mean(EQM_a[, j]))
  RMSE_b[j] = sqrt(mean(EQM_b[, j]))
  RMSE_alpha[j] = sqrt(mean(EQM_alpha[, j]))
}

RMSE_TRI = cbind(RMSE_a, RMSE_b, RMSE_alpha)
