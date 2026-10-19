# =============================================================================
# EEE933 - Estudo de Caso 03
# Mesclagem dos dados da Equipe A
#
# Lê os 20 arquivos por instância produzidos pelo gerar_dados_grupoA.R (dois
# por instância, em coleta_instancias/), verifica a integridade do resumo
# contra o bruto e consolida tudo nos dois CSV usados pela análise:
#
#   DadosDEGrupoA_bruto.csv  - colunas dimensao, instancia, repeticao,
#                              configuracao, Fbest
#   DadosDEGrupoA_resumo.csv - colunas dimensao, instancia, configuracao,
#                              n_repeticoes, media, variancia
#
# Uso: Rscript mesclar_dados_grupoA.R
#      (o coletar_dados_grupoA.sh o chama automaticamente ao final; pode ser
#      rodado à mão sempre que quiser reconsolidar os arquivos por instância)
# =============================================================================

dir_ckpt <- "coleta_instancias"

f_bruto <- sort(list.files(dir_ckpt, pattern = "inst_[0-9]+_bruto\\.csv$",
                           full.names = TRUE))
f_resumo <- sort(list.files(dir_ckpt, pattern = "inst_[0-9]+_resumo\\.csv$",
                            full.names = TRUE))

stem <- function(x) sub("_(bruto|resumo)$", "", tools::file_path_sans_ext(x))
if (length(f_bruto) == 0L || length(f_bruto) != length(f_resumo) ||
    !identical(stem(f_bruto), stem(f_resumo))) {
  stop("coleta_instancias/ está inconsistente: cada instância precisa ter o ",
       "par (bruto, resumo). Faltam instâncias.\nBruto: ",
       paste(basename(f_bruto), collapse = ", "),
       "\nResumo: ", paste(basename(f_resumo), collapse = ", "))
}

dados_bruto  <- do.call(rbind, lapply(f_bruto, read.csv))
dados_resumo <- do.call(rbind, lapply(f_resumo, read.csv))

n_inst <- length(unique(dados_resumo$instancia))

for (k in sort(unique(dados_resumo$instancia))) {
  bk <- dados_bruto[dados_bruto$instancia == k, ]
  rk <- dados_resumo[dados_resumo$instancia == k, ]
  for (j in seq_len(nrow(rk))) {
    z <- bk$Fbest[bk$configuracao == rk$configuracao[j]]
    if (length(z) != rk$n_repeticoes[j] ||
        !isTRUE(all.equal(mean(z), rk$media[j])) ||
        !isTRUE(all.equal(var(z), rk$variancia[j]))) {
      stop("Resumo incompatível com o bruto na instância ", k,
           ", configuração ", rk$configuracao[j], ".")
    }
  }
}

arquivo_bruto  <- "DadosDEGrupoA_bruto.csv"
arquivo_resumo <- "DadosDEGrupoA_resumo.csv"

write.csv(dados_bruto, file = arquivo_bruto, row.names = FALSE)
write.csv(dados_resumo, file = arquivo_resumo, row.names = FALSE)

cat("\n")
cat(sprintf("Instâncias: %d | repetições por instância: %d | execuções: %d\n",
            n_inst, max(dados_resumo$n_repeticoes), nrow(dados_bruto)))
cat(sprintf("Dimensões: %s\n",
            paste(sort(unique(dados_bruto$dimensao)), collapse = ", ")))
cat(sprintf("Arquivos gravados: %s (%d linhas) e %s (%d linhas)\n\n",
            arquivo_bruto, nrow(dados_bruto),
            arquivo_resumo, nrow(dados_resumo)))

cat("Desempenho por configuração (sobre os valores brutos):\n")
print(aggregate(Fbest ~ configuracao, data = dados_bruto, FUN = function(z) {
  c(mediana = median(z), media = mean(z), desvio = sd(z))
}))

cat("\nMédias por instância, base do teste pareado:\n")
inst <- reshape(dados_resumo[, c("instancia", "dimensao", "configuracao", "media")],
                idvar = c("instancia", "dimensao"), timevar = "configuracao",
                direction = "wide")
print(inst)
