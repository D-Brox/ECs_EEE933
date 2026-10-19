# -----------------------------------------------------------------------------
# Pacotes
# -----------------------------------------------------------------------------
pkgs <- c("ExpDE", "smoof")
faltando <- pkgs[!pkgs %in% rownames(installed.packages())]
if (length(faltando) > 0) {
  stop("Instale os pacotes ausentes antes de executar: ",
       paste(faltando, collapse = ", "),
       '\ninstall.packages(c("ExpDE", "smoof"))')
}
suppressWarnings(suppressPackageStartupMessages({
  library(ExpDE)
  library(smoof)
}))


# -----------------------------------------------------------------------------
# Parâmetros do estudo
# -----------------------------------------------------------------------------
d_star   <- 0.5       # mínima diferença de importância prática padronizada
alfa     <- 0.05      # significância desejada
potencia <- 0.80      # potência mínima desejada para d = d_star
semente  <- 20261011  # semente base: garante a reprodutibilidade da coleta

n_reps <- 50
dims <- seq(5, 140, by = 15)
n_inst <- length(dims)

# -----------------------------------------------------------------------------
# Função objetivo
# -----------------------------------------------------------------------------
make_fn <- function(d) {
  f <- smoof::makeRosenbrockFunction(dimensions = d)
  function(X) {
    if (!is.matrix(X)) X <- matrix(X, nrow = 1)
    apply(X, MARGIN = 1, FUN = f)
  }
}


# -----------------------------------------------------------------------------
# Configurações comparadas
# -----------------------------------------------------------------------------
recpars <- list(Config1 = list(name = "recombination_arith"),
                Config2 = list(name = "recombination_bin", cr = 0.7))

mutpars <- list(Config1 = list(name = "mutation_rand", f = 4),
                Config2 = list(name = "mutation_best", f = 3))

configs <- names(mutpars)


# -----------------------------------------------------------------------------
# Coleta da k-ésima instância (--instancia <k>)
# -----------------------------------------------------------------------------
args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 2L || args[[1]] != "--instancia") {
  stop("Uso: Rscript gerar_dados_grupoA.R --instancia <k>, com k entre 1 e ",
       n_inst,
       "\nPara coletar as 10 instâncias em paralelo e mesclar os resultados,",
       "\nuse ./coletar_dados_grupoA.sh.")
}
k <- as.integer(args[[2]])
if (is.na(k) || k < 1L || k > n_inst) {
  stop("O índice da instância deve estar entre 1 e ", n_inst,
       " (recebido: '", args[[2]], "').")
}

dir_ckpt <- "coleta_instancias"
dir.create(dir_ckpt, showWarnings = FALSE, recursive = TRUE)

f_bruto  <- file.path(dir_ckpt, sprintf("inst_%02d_bruto.csv",  k))
f_resumo <- file.path(dir_ckpt, sprintf("inst_%02d_resumo.csv", k))

# Retomada: se os dois arquivos da instância já existem, a coleta é
# dispensada. As dimensões e as sementes são fixas, de modo que re-coletar
# redegaria exatamente os mesmos valores.
if (file.exists(f_bruto) && file.exists(f_resumo)) {
  cat(sprintf(
    "Instância %2d/%d (dim = %3d): arquivos já gravados, coleta dispensada.\n",
    k, n_inst, dims[k]))
  flush(stdout())
  quit(save = "no", status = 0)
}

d      <- dims[k]
inicio <- Sys.time()

# A função objetivo precisa ser encontrada pelo ExpDE pelo nome informado em
# probpars, e por isso é atribuída no ambiente global.
fn <- make_fn(d)

selpars  <- list(name = "selection_standard")
# Atenção: o nome do campo é "names" (no plural), como no enunciado.
stopcrit <- list(names = "stop_maxeval", maxevals = 5000 * d, maxiter = 100 * d)
probpars <- list(name = "fn", xmin = rep(-5, d), xmax = rep(10, d))
popsize  <- 5 * d
showpars <- list(show.iters = "none")

obs <- matrix(NA_real_, nrow = n_reps, ncol = length(configs),
              dimnames = list(NULL, configs))

for (r in seq_len(n_reps)) {
  for (cfg in seq_along(configs)) {
    set.seed(semente + 100000L * k + 100L * r + cfg)
    out <- ExpDE(mutpars  = mutpars[[cfg]],
                 recpars  = recpars[[cfg]],
                 popsize  = popsize,
                 selpars  = selpars,
                 stopcrit = stopcrit,
                 probpars = probpars,
                 showpars = showpars)
    obs[r, cfg] <- out$Fbest
  }
}

if (anyNA(obs) || any(!is.finite(obs))) {
  stop("Houve execução sem valor de retorno na instância ", k,
       " (dimensão ", d, ").")
}

# Arquivo bruto: uma linha por repetição.
write.csv(
  data.frame(
    dimensao     = d,
    instancia    = k,
    repeticao    = rep(seq_len(n_reps), times = length(configs)),
    configuracao = rep(configs, each = n_reps),
    Fbest        = as.vector(obs)
  ),
  file = f_bruto, row.names = FALSE
)

# Arquivo de resumo: média e variância das repetições da instância. A
# variância é a amostral sem viés (denominador n_reps - 1), a mesma usada
# pelo teste t.
write.csv(
  data.frame(
    dimensao     = d,
    instancia    = k,
    configuracao = configs,
    n_repeticoes = n_reps,
    media        = c(mean(obs[, 1]), mean(obs[, 2])),
    variancia    = c(var(obs[, 1]), var(obs[, 2]))
  ),
  file = f_resumo, row.names = FALSE
)

fim <- Sys.time()
cat(sprintf(
  "Instância %2d/%d (dim = %3d) concluída em %.1f min | médias: %s\n",
  k, n_inst, d, as.numeric(difftime(fim, inicio, units = "mins")),
  paste(sprintf("%s = %.4g", configs, c(mean(obs[, 1]), mean(obs[, 2]))),
        collapse = ", ")))
flush(stdout())
