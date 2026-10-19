#!/usr/bin/env bash
set -u

cd "$(dirname "$0")"

n_inst=10   # número de instâncias; acompanha dims <- seq(5, 140, by = 15)

mkdir -p coleta_instancias
inicio=$(date +%s)

echo "Coletando $n_inst instâncias em paralelo (um log por instância em coleta_instancias/)..."

pids=()
for k in $(seq 1 "$n_inst"); do
  log=$(printf "coleta_instancias/inst_%02d.log" "$k")
  Rscript gerar_dados_grupoA.R --instancia "$k" > "$log" 2>&1 &
  pids+=("$!")
done

# Espera cada instância terminar, com verificação individual dos códigos de
# saída para saber exatamente qual falhou (e onde olhar).
falha=0
for i in "${!pids[@]}"; do
  k=$((i + 1))
  log=$(printf "coleta_instancias/inst_%02d.log" "$k")
  if wait "${pids[$i]}"; then
    tail -n 1 "$log"
  else
    echo "ERRO: instância $k falhou; ver $log:"
    tail -n 3 "$log" | sed 's/^/    /'
    falha=1
  fi
done

if [ "$falha" -ne 0 ]; then
  echo "Coleta encerrada por falhas; os CSV finais não foram atualizados."
  echo "Resolva a falha e rode o script de novo: as instâncias concluídas"
  echo "serão dispensadas e só o que falta será coletado."
  exit 1
fi

Rscript mesclar_dados_grupoA.R

fim=$(date +%s)
dur=$((fim - inicio))
echo "Tempo total da coleta: $((dur / 60)) min $((dur % 60)) s"
