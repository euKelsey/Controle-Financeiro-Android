
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

    // REGRA 3: Somar os lançamentos do período.
    final resultado = await db.rawQuery(
      '''
      SELECT
        COALESCE(
          SUM(
            CASE
              WHEN tipo = 'RECEITA'
              THEN valor_previsto
              ELSE 0
            END
          ),
          0
        ) AS receitas,

        COALESCE(
          SUM(
            CASE
              WHEN tipo = 'DESPESA'
              THEN valor_previsto
              ELSE 0
            END
          ),
          0
        ) AS despesas

      FROM lancamento

      WHERE data_prevista >= ?
        AND data_prevista < ?
        AND status IN ('PENDENTE', 'EFETIVADO')
      ''',
      [inicio, fim],
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

}
