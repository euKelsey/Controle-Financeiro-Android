PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS categoria (
    id INTEGER PRIMARY KEY,
    nome TEXT NOT NULL,
    tipo TEXT NOT NULL,
    descricao TEXT,
    status TEXT NOT NULL DEFAULT 'ATIVA',

    CHECK (tipo IN ('RECEITA', 'DESPESA')),
    CHECK (status IN ('ATIVA', 'INATIVA')),

    UNIQUE (nome, tipo)
);

CREATE TABLE IF NOT EXISTS cartao (
    id INTEGER PRIMARY KEY,
    nome TEXT NOT NULL,
    instituicao TEXT NOT NULL,
    limite_total INTEGER NOT NULL,
    dia_fechamento INTEGER NOT NULL,
    dia_vencimento INTEGER NOT NULL,
    status TEXT NOT NULL DEFAULT 'ATIVO',
    observacao TEXT,

    CHECK (limite_total >= 0),
    CHECK (dia_fechamento BETWEEN 1 AND 31),
    CHECK (dia_vencimento BETWEEN 1 AND 31),
    CHECK (status IN ('ATIVO', 'INATIVO'))
);

CREATE TABLE IF NOT EXISTS recorrencia (
    id INTEGER PRIMARY KEY,
    tipo_lancamento TEXT NOT NULL,
    descricao TEXT NOT NULL,
    valor INTEGER NOT NULL,
    categoria_id INTEGER NOT NULL,
    periodicidade TEXT NOT NULL,
    data_inicio TEXT NOT NULL,
    data_fim TEXT,
    dia_referencia INTEGER,
    destino_geracao TEXT NOT NULL DEFAULT 'LANCAMENTO',
    cartao_id INTEGER,
    status TEXT NOT NULL DEFAULT 'ATIVA',
    observacao TEXT,

    CHECK (tipo_lancamento IN ('RECEITA', 'DESPESA')),
    CHECK (valor > 0),
    CHECK (periodicidade IN ('MENSAL', 'SEMANAL', 'QUINZENAL', 'ANUAL')),
    CHECK (dia_referencia IS NULL OR dia_referencia BETWEEN 1 AND 31),
    CHECK (destino_geracao IN ('LANCAMENTO', 'COMPRA_CARTAO')),
    CHECK (status IN ('ATIVA', 'PAUSADA', 'ENCERRADA')),
    CHECK (data_fim IS NULL OR data_fim >= data_inicio),

    CHECK (
        (destino_geracao = 'LANCAMENTO' AND cartao_id IS NULL)
        OR
        (
            destino_geracao = 'COMPRA_CARTAO'
            AND tipo_lancamento = 'DESPESA'
            AND cartao_id IS NOT NULL
        )
    ),

    FOREIGN KEY (categoria_id)
        REFERENCES categoria(id)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,

    FOREIGN KEY (cartao_id)
        REFERENCES cartao(id)
        ON DELETE RESTRICT
        ON UPDATE CASCADE
);

CREATE TABLE IF NOT EXISTS fatura (
    id INTEGER PRIMARY KEY,
    cartao_id INTEGER NOT NULL,
    mes_referencia TEXT NOT NULL,
    data_fechamento TEXT NOT NULL,
    data_vencimento TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'ABERTA',

    CHECK (status IN ('ABERTA', 'FECHADA')),

    UNIQUE (cartao_id, mes_referencia),

    FOREIGN KEY (cartao_id)
        REFERENCES cartao(id)
        ON DELETE RESTRICT
        ON UPDATE CASCADE
);

CREATE TABLE IF NOT EXISTS lancamento (
    id INTEGER PRIMARY KEY,
    tipo TEXT NOT NULL,
    descricao TEXT NOT NULL,
    valor_previsto INTEGER NOT NULL,
    data_prevista TEXT NOT NULL,
    categoria_id INTEGER,
    recorrencia_id INTEGER,
    fatura_id INTEGER,
    status TEXT NOT NULL DEFAULT 'PENDENTE',
    observacao TEXT,
    origem TEXT NOT NULL DEFAULT 'MANUAL',

    CHECK (tipo IN ('RECEITA', 'DESPESA')),
    CHECK (valor_previsto > 0),
    CHECK (status IN ('PENDENTE', 'EFETIVADO', 'CANCELADO')),
    CHECK (origem IN ('MANUAL', 'RECORRENCIA', 'FATURA')),

    CHECK (
        origem = 'FATURA'
        OR categoria_id IS NOT NULL
    ),

    CHECK (
        (origem = 'MANUAL'
            AND recorrencia_id IS NULL
            AND fatura_id IS NULL)
        OR
        (origem = 'RECORRENCIA'
            AND recorrencia_id IS NOT NULL
            AND fatura_id IS NULL)
        OR
        (origem = 'FATURA'
            AND fatura_id IS NOT NULL
            AND recorrencia_id IS NULL)
    ),

    CHECK (
        origem != 'FATURA'
        OR tipo = 'DESPESA'
    ),

    FOREIGN KEY (categoria_id)
        REFERENCES categoria(id)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,

    FOREIGN KEY (recorrencia_id)
        REFERENCES recorrencia(id)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,

    FOREIGN KEY (fatura_id)
        REFERENCES fatura(id)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,

    UNIQUE (fatura_id)
);

CREATE TABLE IF NOT EXISTS movimentacao (
    id INTEGER PRIMARY KEY,
    lancamento_id INTEGER NOT NULL,
    valor INTEGER NOT NULL,
    data_movimentacao TEXT NOT NULL,
    forma TEXT NOT NULL,
    observacao TEXT,

    CHECK (valor > 0),

    CHECK (
        forma IN (
            'PIX',
            'DINHEIRO',
            'DEBITO',
            'TRANSFERENCIA',
            'BOLETO',
            'OUTRO'
        )
    ),

    UNIQUE (lancamento_id),

    FOREIGN KEY (lancamento_id)
        REFERENCES lancamento(id)
        ON DELETE RESTRICT
        ON UPDATE CASCADE
);

CREATE TABLE IF NOT EXISTS compra_cartao (
    id INTEGER PRIMARY KEY,
    cartao_id INTEGER NOT NULL,
    categoria_id INTEGER NOT NULL,
    recorrencia_id INTEGER,
    descricao TEXT NOT NULL,
    data_compra TEXT NOT NULL,
    valor_total INTEGER NOT NULL,
    quantidade_parcelas INTEGER NOT NULL,
    primeira_parcela_controlada INTEGER NOT NULL DEFAULT 0,
    data_primeira_parcela_controlada TEXT,
    status TEXT NOT NULL DEFAULT 'ATIVA',
    observacao TEXT,

    CHECK (valor_total > 0),
    CHECK (quantidade_parcelas > 0),
    CHECK (primeira_parcela_controlada IN (0, 1)),
    CHECK (status IN ('ATIVA', 'CANCELADA')),

    CHECK (
        primeira_parcela_controlada = 0
        OR data_primeira_parcela_controlada IS NOT NULL
    ),

    FOREIGN KEY (cartao_id)
        REFERENCES cartao(id)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,

    FOREIGN KEY (categoria_id)
        REFERENCES categoria(id)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,

    FOREIGN KEY (recorrencia_id)
        REFERENCES recorrencia(id)
        ON DELETE RESTRICT
        ON UPDATE CASCADE
);

CREATE TABLE IF NOT EXISTS parcela_cartao (
    id INTEGER PRIMARY KEY,
    compra_cartao_id INTEGER NOT NULL,
    fatura_id INTEGER,
    numero_parcela INTEGER NOT NULL,
    valor INTEGER NOT NULL,
    data_prevista TEXT NOT NULL,

    CHECK (numero_parcela > 0),
    CHECK (valor > 0),

    UNIQUE (compra_cartao_id, numero_parcela),

    FOREIGN KEY (compra_cartao_id)
        REFERENCES compra_cartao(id)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,

    FOREIGN KEY (fatura_id)
        REFERENCES fatura(id)
        ON DELETE SET NULL
        ON UPDATE CASCADE
);

CREATE TABLE IF NOT EXISTS meta_reserva (
    id INTEGER PRIMARY KEY,
    tipo TEXT NOT NULL,
    valor INTEGER,
    percentual INTEGER,
    data_inicio TEXT NOT NULL,
    data_fim TEXT,
    status TEXT NOT NULL DEFAULT 'ATIVA',
    observacao TEXT,

    CHECK (tipo IN ('VALOR_FIXO', 'PERCENTUAL')),

    CHECK (
        (tipo = 'VALOR_FIXO'
            AND valor IS NOT NULL
            AND valor > 0
            AND percentual IS NULL)
        OR
        (tipo = 'PERCENTUAL'
            AND percentual IS NOT NULL
            AND percentual > 0
            AND percentual <= 10000
            AND valor IS NULL)
    ),

    CHECK (data_fim IS NULL OR data_fim >= data_inicio),

    CHECK (status IN ('ATIVA', 'ENCERRADA'))
);

CREATE TABLE IF NOT EXISTS reserva_movimentacao (
    id INTEGER PRIMARY KEY,
    valor INTEGER NOT NULL,
    data_movimentacao TEXT NOT NULL,
    observacao TEXT,

    CHECK (valor > 0)
);

CREATE TABLE IF NOT EXISTS configuracao (
    id INTEGER PRIMARY KEY,
    chave TEXT NOT NULL UNIQUE,
    valor TEXT NOT NULL
);
