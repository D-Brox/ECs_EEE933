#!/usr/bin/env bash
set -u

cd "$(dirname "$0")"

n_inst=34   # número de instâncias; acompanha gerar_dados_grupoA.R (power.t.test)
nucl=${NUCLEOS:-$(( $(nproc) - 2 ))}   # limite de processos simultâneos

mkdir -p coleta_instancias
inicio=$(date +%s)

echo "Coletando $n_inst instâncias com até $nucl processos simultâneos..."

# Fila via xargs: no máximo `nucl` instâncias rodam ao mesmo tempo. Cada uma
# tem log próprio; o status individual é conferido pelos arquivos gravados.
printf '%s\n' $(seq 1 "$n_inst") | xargs -P "$nucl" -I{} sh -c '
  log=$(printf "coleta_instancias/inst_%02d.log" "$1")
  Rscript gerar_dados_grupoA.R --instancia "$1" > "$log" 2>&1
' _ {}

# Estado de cada instância (última linha do log).
for k in $(seq 1 "$n_inst"); do
  log=$(printf "coleta_instancias/inst_%02d.log" "$k")
  tail -n 1 "$log" | sed 's/^/  /'
done

# Falha = par de arquivos faltando ou vazio no final da fila.
falta=0
for k in $(seq 1 "$n_inst"); do
  b=$(printf "coleta_instancias/inst_%02d_bruto.csv" "$k")
  r=$(printf "coleta_instancias/inst_%02d_resumo.csv" "$k")
  if [ ! -s "$b" ] || [ ! -s "$r" ]; then
    echo "ERRO: instância $k não concluiu (ver coleta_instancias/inst_$(printf '%02d' $k).log)"
    falta=1
  fi
done
if [ "$falta" -ne 0 ]; then
  echo "Coleta encerrada por falhas; os CSV finais não foram atualizados."
  echo "Rode o script de novo: as instâncias concluídas serão dispensadas,"
  echo "e só o que falta será coletado."
  exit 1
fi

Rscript mesclar_dados_grupoA.R

fim=$(date +%s)
dur=$((fim - inicio))
echo "Tempo total da coleta: $((dur / 60)) min $((dur % 60)) s"
