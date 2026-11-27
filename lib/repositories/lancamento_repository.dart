
import 'package:sqflite/sqflite.dart';

import '../database/database_helper.dart';
import '../models/lancamento_model.dart';

class LancamentoRepository {
  final Database? _bancoTeste;

  // Permite usar o banco principal ou um banco de testes.
  LancamentoRepository({Database? banco}) : _bancoTeste = banco;

  Future<Database> _obterBanco() async {
    return _bancoTeste ?? await DatabaseHelper.obterBanco();
  }

  // Cadastra um novo lançamento financeiro.
  Future<LancamentoModel> inserir(
    LancamentoModel lancamento,
  ) async {
    final db = await _obterBanco();

    final id = await db.insert(
      'lancamento',
      lancamento.toMap(),
    );

    return LancamentoModel(
      id: id,
      tipo: lancamento.tipo,
      descricao: lancamento.descricao,
      valorPrevisto: lancamento.valorPrevisto,
      dataPrevista: lancamento.dataPrevista,
      categoriaId: lancamento.categoriaId,
      recorrenciaId: lancamento.recorrenciaId,
      faturaId: lancamento.faturaId,
      status: lancamento.status,
      observacao: lancamento.observacao,
      origem: lancamento.origem,
    );
  }

  // Lista todos os lançamentos por data prevista.
  Future<List<LancamentoModel>> listar() async {
    final db = await _obterBanco();

    final registros = await db.query(
      'lancamento',
      orderBy: 'data_prevista ASC',
    );

    return registros
        .map((registro) => LancamentoModel.fromMap(registro))
        .toList();
  }

  // Busca um lançamento pelo identificador.
  Future<LancamentoModel?> buscarPorId(int id) async {
    final db = await _obterBanco();

    final registros = await db.query(
      'lancamento',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (registros.isEmpty) {
      return null;
    }

    return LancamentoModel.fromMap(registros.first);
  }

  
  // Atualiza um lançamento existente.
  Future<int> atualizar(LancamentoModel lancamento) async {
    if (lancamento.id == null) {
      throw ArgumentError(
        'O ID do lançamento é obrigatório para atualização.',
      );
    }

    final db = await _obterBanco();

    return db.update(
      'lancamento',
      {
        'tipo': lancamento.tipo,
        'descricao': lancamento.descricao,
        'valor_previsto': lancamento.valorPrevisto,
        'data_prevista': lancamento.dataPrevista,
        'categoria_id': lancamento.categoriaId,
        'recorrencia_id': lancamento.recorrenciaId,
        'fatura_id': lancamento.faturaId,
        'status': lancamento.status,
        'observacao': lancamento.observacao,
        'origem': lancamento.origem,
      },
      where: 'id = ?',
      whereArgs: [lancamento.id],
    );
  }

  // Busca o lançamento relacionado a uma fatura.
  Future<LancamentoModel?> buscarPorFaturaId(
    int faturaId,
  ) async {
    final db = await _obterBanco();

    final registros = await db.query(
      'lancamento',
      where: 'fatura_id = ?',
      whereArgs: [faturaId],
      limit: 1,
    );

    if (registros.isEmpty) {
      return null;
    }

    return LancamentoModel.fromMap(registros.first);
  }

  // Cancela um lançamento sem excluir seu histórico.
  Future<int> cancelar(int id) async {
    final db = await _obterBanco();

    return db.update(
      'lancamento',
      {'status': 'CANCELADO'},
      where: 'id = ?',
      whereArgs: [id],
    );
  }


  // Calcula receitas, despesas e saldo previsto
  // de um determinado mês.
  Future<({
    int receitas,
    int despesas,
    int saldoPrevisto,
  })> obterResumoMensal({
    required int ano,
    required int mes,
  }) async {
    // REGRA 1: Validar o período informado.
    if (ano < 1 || ano > 9999) {
      throw ArgumentError('Ano inválido.');
    }

    if (mes < 1 || mes > 12) {
      throw ArgumentError('Mês inválido.');
    }

    final db = await _obterBanco();

    // REGRA 2: Definir o intervalo do mês.
    final inicio =
        '${ano.toString().padLeft(4, '0')}-'
        '${mes.toString().padLeft(2, '0')}-01';

    final proximoMes = DateTime.utc(ano, mes + 1);

    final fim =
        '${proximoMes.year.toString().padLeft(4, '0')}-'
        '${proximoMes.month.toString().padLeft(2, '0')}-01';

    // Lancamentos comuns seguem a data prevista. Faturas seguem a
    // competencia, inclusive quando vencem no mes seguinte.
    final competencia = inicio.substring(0, 7);
    final resultado = await db.rawQuery(
      '''
      WITH itens AS (
        SELECT tipo, valor_previsto AS valor
        FROM lancamento
        WHERE data_prevista >= ? AND data_prevista < ?
          AND origem <> 'FATURA'
          AND status IN ('PENDENTE', 'EFETIVADO')

        UNION ALL

        SELECT 'DESPESA', l.valor_previsto
        FROM lancamento l
        JOIN fatura f ON f.id = l.fatura_id
        WHERE f.mes_referencia = ?
          AND l.origem = 'FATURA'
          AND l.status IN ('PENDENTE', 'EFETIVADO')

        UNION ALL

        SELECT 'DESPESA', p.valor
        FROM fatura f
        JOIN parcela_cartao p ON p.fatura_id = f.id
        JOIN compra_cartao c ON c.id = p.compra_cartao_id
        WHERE f.mes_referencia = ?
          AND c.status = 'ATIVA'
          AND NOT EXISTS (
            SELECT 1 FROM lancamento l WHERE l.fatura_id = f.id
          )
      )
      SELECT
        COALESCE(SUM(CASE WHEN tipo = 'RECEITA' THEN valor ELSE 0 END), 0) AS receitas,
        COALESCE(SUM(CASE WHEN tipo = 'DESPESA' THEN valor ELSE 0 END), 0) AS despesas
      FROM itens
      ''',
      [inicio, fim, competencia, competencia],
    );

    // REGRA 4: Converter os resultados.
    final receitas = resultado.first['receitas'] as int;
    final despesas = resultado.first['despesas'] as int;

    // REGRA 5: Calcular o saldo previsto.
    final saldoPrevisto = receitas - despesas;

    return (
      receitas: receitas,
      despesas: despesas,
      saldoPrevisto: saldoPrevisto,
    );
  }


  // Consulta os proximos lancamentos pendentes,
  // ordenados pela data de vencimento.
  Future<List<LancamentoModel>> listarProximosVencimentos({
    required String dataReferencia,
    int limite = 5,
  }) async {
    // REGRA 1: Validar a data de referencia.
    final formato = RegExp(r'^\d{4}-\d{2}-\d{2}$');

    if (!formato.hasMatch(dataReferencia)) {
      throw ArgumentError(
        'A data deve estar no formato AAAA-MM-DD.',
      );
    }

    final data = DateTime.tryParse(dataReferencia);

    if (data == null ||
        data.year.toString().padLeft(4, '0') !=
            dataReferencia.substring(0, 4) ||
        data.month.toString().padLeft(2, '0') !=
            dataReferencia.substring(5, 7) ||
        data.day.toString().padLeft(2, '0') !=
            dataReferencia.substring(8, 10)) {
      throw ArgumentError(
        'Data de referencia invalida.',
      );
    }

    // REGRA 2: Validar a quantidade solicitada.
    if (limite < 1 || limite > 50) {
      throw ArgumentError(
        'O limite deve estar entre 1 e 50.',
      );
    }

    final db = await _obterBanco();

    // REGRA 3: Consultar apenas lancamentos
    // pendentes a partir da data informada.
    final registros = await db.query(
      'lancamento',
      where: 'status = ? AND data_prevista >= ?',
      whereArgs: [
        'PENDENTE',
        dataReferencia,
      ],
      orderBy: 'data_prevista ASC, id ASC',
      limit: limite,
    );

    // REGRA 4: Converter os registros
    // do SQLite para objetos Dart.
    return registros
        .map((registro) => LancamentoModel.fromMap(registro))
        .toList();
  }

  // Lista os lancamentos por competencia de vencimento, sem incluir
  // compras individuais do cartao (apenas o lancamento da fatura).
  Future<List<LancamentoModel>> listarPorPeriodo({
    required int ano,
    required int mes,
    String? tipo,
    String? status,
    int limite = 100,
    int deslocamento = 0,
  }) async {
    if (ano < 1 || ano > 9999 || mes < 1 || mes > 12) {
      throw ArgumentError('Periodo invalido.');
    }
    if (tipo != null && tipo != 'RECEITA' && tipo != 'DESPESA') {
      throw ArgumentError('Tipo invalido.');
    }
    if (status != null &&
        status != 'PENDENTE' &&
        status != 'EFETIVADO' &&
        status != 'CANCELADO') {
      throw ArgumentError('Status invalido.');
    }
    if (limite < 1 || limite > 500 || deslocamento < 0) {
      throw ArgumentError('Paginacao invalida.');
    }
    final inicio =
        '${ano.toString().padLeft(4, '0')}-${mes.toString().padLeft(2, '0')}-01';
    // Evita DateTime(9999, 13), que excede o ano maximo aceito.
    final fim = mes == 12
        ? '${(ano + 1).toString().padLeft(4, '0')}-01-01'
        : '${ano.toString().padLeft(4, '0')}-${(mes + 1).toString().padLeft(2, '0')}-01';
    final condicoes = <String>[
      'data_prevista >= ?',
      'data_prevista < ?',
    ];
    final argumentos = <Object>[inicio, fim];
    if (tipo != null) {
      condicoes.add('tipo = ?');
      argumentos.add(tipo);
    }
    if (status != null) {
      condicoes.add('status = ?');
      argumentos.add(status);
    }
    final db = await _obterBanco();
    final registros = await db.query(
      'lancamento',
      where: condicoes.join(' AND '),
      whereArgs: argumentos,
      orderBy: 'data_prevista DESC, id DESC',
      limit: limite,
      offset: deslocamento,
    );
    return registros.map(LancamentoModel.fromMap).toList();
  }


  // Registro simplificado: lançamento e movimentação na mesma transação.
  Future<LancamentoModel> inserirEfetivado(LancamentoModel lancamento) async {
    final db = await _obterBanco();
    return db.transaction((txn) async {
      final mapa = lancamento.toMap()..['status'] = 'EFETIVADO';
      final id = await txn.insert('lancamento', mapa);
      await txn.insert('movimentacao', {
        'lancamento_id': id, 'valor': lancamento.valorPrevisto,
        'data_movimentacao': lancamento.dataPrevista, 'forma': 'OUTRO',
      });
      return LancamentoModel.fromMap(mapa..['id'] = id);
    });
  }

  Future<int> atualizarRegistrado(LancamentoModel lancamento) async {
    final db = await _obterBanco();
    return db.transaction((txn) async {
      final registros = await txn.query('lancamento',
        where: 'id = ? AND origem = ? AND status IN (?, ?)',
        whereArgs: [lancamento.id, 'MANUAL', 'PENDENTE', 'EFETIVADO']);
      if (registros.length != 1) throw StateError('Lançamento indisponível para edição.');
      final anterior = registros.single;
      final movimentos = await txn.query('movimentacao',
        where: 'lancamento_id = ?', whereArgs: [lancamento.id]);
      if (anterior['status'] == 'EFETIVADO' && movimentos.length != 1) {
        throw StateError('Movimentação do lançamento inconsistente.');
      }
      final mapa = lancamento.toMap()..remove('id');
      // Não efetiva retroativamente um lançamento pendente legado.
      mapa['status'] = anterior['status'];
      final linhas = await txn.update('lancamento', mapa,
        where: 'id = ?', whereArgs: [lancamento.id]);
      if (movimentos.isNotEmpty) {
        final movimento = movimentos.single;
        await txn.update('movimentacao', {
          'valor': lancamento.valorPrevisto,
          if (lancamento.dataPrevista != anterior['data_prevista'])
            'data_movimentacao': lancamento.dataPrevista,
        }, where: 'id = ?', whereArgs: [movimento['id']]);
      }
      return linhas;
    });
  }

  Future<int> cancelarRegistrado(int id) async {
    final db = await _obterBanco();
    // Preserva a movimentação histórica; consultas de movimentos ativos
    // excluem lançamentos cancelados.
    return db.update('lancamento', {'status': 'CANCELADO'},
      where: 'id = ? AND origem = ? AND status IN (?, ?)',
      whereArgs: [id, 'MANUAL', 'PENDENTE', 'EFETIVADO']);
  }

}
