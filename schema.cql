-- Modelagem "query-first": cada tabela existe para responder a UMA consulta.
-- SimpleStrategy/RF=1 só para desenvolvimento (1 nó).
-- Em produção: NetworkTopologyStrategy com RF=3 por datacenter.
CREATE KEYSPACE IF NOT EXISTS rastreio
WITH replication = {'class': 'NetworkTopologyStrategy', 'datacenter1': 1};

USE rastreio;

-- Q1: buscar um entregador pelo id
CREATE TABLE IF NOT EXISTS entregadores (
    entregador_id uuid PRIMARY KEY,
    nome          text,
    veiculo       text,
    placa         text
);

-- Q2: buscar uma entrega pelo id
CREATE TABLE IF NOT EXISTS entregas (
    entrega_id      uuid PRIMARY KEY,
    codigo_rastreio text,
    cliente         text,
    destino         text,
    entregador_id   uuid,
    status          text,        -- CRIADA | EM_ROTA | ENTREGUE | CANCELADA
    criado_em       timestamp,
    atualizado_em   timestamp
);

-- Q3: listar as entregas de um entregador (mais recentes primeiro)
-- Tabela desnormalizada: o mesmo dado de "entregas", organizado por outra chave.
CREATE TABLE IF NOT EXISTS entregas_por_entregador (
    entregador_id uuid,
    criado_em     timestamp,
    entrega_id    uuid,
    codigo_rastreio text,
    cliente       text,
    PRIMARY KEY ((entregador_id), criado_em, entrega_id)
) WITH CLUSTERING ORDER BY (criado_em DESC, entrega_id ASC);

-- Q4: histórico de posições de uma entrega (série temporal)
-- Partition key composta (entrega_id, dia): "bucket" diário evita partições
-- que crescem para sempre. Clustering por horário, do mais novo ao mais antigo.
-- TTL de 90 dias e TWCS (compactação própria para séries temporais).
CREATE TABLE IF NOT EXISTS posicoes_por_entrega (
    entrega_id    uuid,
    dia           date,
    registrado_em timestamp,
    latitude      double,
    longitude     double,
    velocidade_kmh double,
    PRIMARY KEY ((entrega_id, dia), registrado_em)
) WITH CLUSTERING ORDER BY (registrado_em DESC)
  AND default_time_to_live = 7776000
  AND compaction = {
      'class': 'TimeWindowCompactionStrategy',
      'compaction_window_unit': 'DAYS',
      'compaction_window_size': 1
  };

-- Q5: última posição conhecida (o "onde está meu pedido?" do cliente)
-- Cada INSERT sobrescreve a linha anterior (upsert).
CREATE TABLE IF NOT EXISTS ultima_posicao (
    entrega_id    uuid PRIMARY KEY,
    registrado_em timestamp,
    latitude      double,
    longitude     double,
    velocidade_kmh double
);
