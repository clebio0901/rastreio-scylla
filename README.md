
```bash
docker compose up -d
docker compose ps            # aguarde ficar "healthy" (1 a 2 min)
docker exec -i scylla cqlsh < schema.cql
```
Conferir: `docker exec -it scylla nodetool status` (deve mostrar `UN` = Up/Normal).

## 2. Instalar dependências
```bash
python -m venv .venv && source .venv/bin/activate   # Windows: .venv\Scripts\activate
pip install -r requirements.txt
```

## 3. Roteiro da demo (CRUD)
```bash
# CREATE
python cli.py criar-entregador "Joao Silva" "Moto" "ABC1D23"        # anote o entregador_id
python cli.py criar-entrega "Maria" "Rua das Flores, 100" <entregador_id>   # anote o entrega_id

# READ
python cli.py ver-entrega <entrega_id>
python cli.py listar-entregas <entregador_id>

# UPDATE
python cli.py status <entrega_id> EM_ROTA
python cli.py destino <entrega_id> "Av. Principal, 500"

# Tempo real (em outro terminal, acompanhe com onde-esta / historico)
python simulador.py <entrega_id> --passos 30 --intervalo 1
python cli.py onde-esta <entrega_id>
python cli.py historico <entrega_id> --limite 10

# DELETE
python cli.py excluir-entrega <entrega_id>
```

## 4. Conceitos para explicar na apresentação
- **Query-first**: em Cassandra/Scylla modela-se a partir das consultas, não das entidades.
- **Desnormalização**: `entregas` e `entregas_por_entregador` guardam dados repetidos de propósito.
- **Partition key vs clustering key**: `((entrega_id, dia), registrado_em)`.
- **Bucket por dia**: evita partições gigantes (wide partitions).
- **Upsert**: `ultima_posicao` sobrescreve a linha a cada INSERT.
- **TTL** (`default_time_to_live`) e **TWCS**: expiração e compactação para séries temporais.
- **Batch logged**: atomicidade entre tabelas desnormalizadas (não é para performance).
- **Sem JOIN, sem transações ACID completas, sem consultas ad hoc**: o lado "contra".

## 5. Tópicos exigidos / extras (para completar depois)
| Tópico | Como demonstrar |
|---|---|
| Redundância | Cluster com 3 nós, RF=3, derrubar um nó e continuar lendo/escrevendo |
| Níveis de consistência | `CONSISTENCY QUORUM;` no cqlsh e no driver (`ConsistencyLevel`) |
| Backup/snapshot | `docker exec scylla nodetool snapshot rastreio` |
| Dump de dados | `docker exec scylla cqlsh -e "COPY rastreio.entregas TO '/tmp/entregas.csv' WITH HEADER=true"` |
| Tuning | `--smp`, `--memory`, estratégia de compactação, TTL, tamanho de partição |
| Inspecionar | `nodetool tablestats rastreio.posicoes_por_entrega` |

## 6. Próximos passos sugeridos
1. Gerar carga maior (ex.: 50 entregadores simultâneos) e medir latência.
2. Subir cluster de 3 nós no docker-compose e testar queda de nó.
3. Criar uma interface simples (Flask/FastAPI + mapa Leaflet) lendo `ultima_posicao`.
4. Medir antes/depois de mudar compactação ou consistência.
