import 'package:sqflite/sqflite.dart';

import '../database/database_helper.dart';
import '../models/movimentacao_model.dart';

class MovimentacaoRepository {
  final Database? _bancoTeste;

  // Permite utilizar o banco principal ou um banco de testes.
  MovimentacaoRepository({Database? banco}) : _bancoTeste = banco;

  Future<Database> _obterBanco() async {
    return _bancoTeste ?? await DatabaseHelper.obterBanco();
  }

  // Insere uma movimentação no SQLite.
  Future<MovimentacaoModel> inserir(MovimentacaoModel movimentacao) async {
    final db = await _obterBanco();

    final id = await db.insert('movimentacao', movimentacao.toMap());

    return MovimentacaoModel(
      id: id,
      lancamentoId: movimentacao.lancamentoId,
      valor: movimentacao.valor,
      dataMovimentacao: movimentacao.dataMovimentacao,
      forma: movimentacao.forma,
      observacao: movimentacao.observacao,
    );
  }

  // Lista todas as movimentações por data.
  Future<List<MovimentacaoModel>> listar() async {
    final db = await _obterBanco();

    final registros = await db.query(
      'movimentacao',
      orderBy: 'data_movimentacao ASC',
    );

    return registros
        .map((registro) => MovimentacaoModel.fromMap(registro))
        .toList();
  }

  // Busca uma movimentação pelo ID.
  Future<MovimentacaoModel?> buscarPorId(int id) async {
    final db = await _obterBanco();

    final registros = await db.query(
      'movimentacao',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (registros.isEmpty) {
      return null;
    }

    return MovimentacaoModel.fromMap(registros.first);
  }

  // Busca a movimentação associada a um lançamento.
  Future<MovimentacaoModel?> buscarPorLancamentoId(int lancamentoId) async {
    final db = await _obterBanco();

    final registros = await db.query(
      'movimentacao',
      where: 'lancamento_id = ?',
      whereArgs: [lancamentoId],
      limit: 1,
    );

    if (registros.isEmpty) {
      return null;
    }

    return MovimentacaoModel.fromMap(registros.first);
  }

  // Atualiza os dados de uma movimentação existente.
  Future<int> atualizar(MovimentacaoModel movimentacao) async {
    if (movimentacao.id == null) {
      throw ArgumentError(
        'O ID da movimentação é obrigatório para atualização.',
      );
    }

    final db = await _obterBanco();

    return db.update(
      'movimentacao',
      {
        'lancamento_id': movimentacao.lancamentoId,
        'valor': movimentacao.valor,
        'data_movimentacao': movimentacao.dataMovimentacao,
        'forma': movimentacao.forma,
        'observacao': movimentacao.observacao,
      },
      where: 'id = ?',
      whereArgs: [movimentacao.id],
    );
  }

  // Insere a movimentação e efetiva o lançamento
  // dentro de uma única transação SQLite.
  Future<MovimentacaoModel> inserirEEfetivar(
    MovimentacaoModel movimentacao,
  ) async {
    final db = await _obterBanco();

    return db.transaction((txn) async {
      // ETAPA 1: Inserir a movimentação.
      final id = await txn.insert('movimentacao', movimentacao.toMap());

      // ETAPA 2: Efetivar somente um lançamento pendente.
      final linhasAtualizadas = await txn.update(
        'lancamento',
        {'status': 'EFETIVADO'},
        where: 'id = ? AND status = ?',
        whereArgs: [movimentacao.lancamentoId, 'PENDENTE'],
      );

      // Se não atualizou exatamente um lançamento,
      // a transação deverá ser desfeita.
      if (linhasAtualizadas != 1) {
        throw StateError('O lançamento não está pendente.');
      }

      // Retorna o objeto com o ID gerado pelo SQLite.
      return MovimentacaoModel(
        id: id,
        lancamentoId: movimentacao.lancamentoId,
        valor: movimentacao.valor,
        dataMovimentacao: movimentacao.dataMovimentacao,
        forma: movimentacao.forma,
        observacao: movimentacao.observacao,
      );
    });
  }

  // Registra o pagamento integral de uma fatura.
  // Todas as verificacoes financeiras ocorrem
  // dentro da mesma transacao SQLite.
  Future<MovimentacaoModel> pagarFaturaAtomicamente({
    required int faturaId,
    required String dataPagamento,
    required String forma,
    String? observacao,
  }) async {
    final db = await _obterBanco();

    return db.transaction((txn) async {
      // REGRA 1: Localizar a fatura dentro da transacao.
      final faturas = await txn.query(
        'fatura',
        where: 'id = ?',
        whereArgs: [faturaId],
        limit: 1,
      );

      if (faturas.isEmpty) {
        throw ArgumentError('Fatura nao encontrada.');
      }

      if (faturas.first['status'] != 'FECHADA') {
        throw StateError('Somente faturas fechadas podem ser pagas.');
      }

      // REGRA 2: Localizar o lancamento da fatura.
      final lancamentos = await txn.query(
        'lancamento',
        where: 'fatura_id = ?',
        whereArgs: [faturaId],
        limit: 1,
      );

      if (lancamentos.isEmpty) {
        throw StateError('Esta fatura nao possui lancamento financeiro.');
      }

      final lancamento = lancamentos.first;
      final lancamentoId = lancamento['id'] as int;
      final valor = lancamento['valor_previsto'] as int;

      // REGRA 3: Validar origem e status.
      if (lancamento['origem'] != 'FATURA' || lancamento['tipo'] != 'DESPESA') {
        throw StateError('Lancamento financeiro invalido para esta fatura.');
      }

      if (lancamento['status'] != 'PENDENTE') {
        throw StateError('Esta fatura nao possui pagamento pendente.');
      }

      if (valor <= 0) {
        throw StateError('O valor da fatura deve ser maior que zero.');
      }

      // REGRA ADICIONAL: Conferir o total consolidado
      // antes de permitir o pagamento da fatura.
      final resultadoTotal = await txn.rawQuery(
        '''
        SELECT COALESCE(SUM(p.valor), 0) AS total
        FROM parcela_cartao AS p
        INNER JOIN compra_cartao AS c
          ON c.id = p.compra_cartao_id
        WHERE p.fatura_id = ?
          AND c.status = 'ATIVA'
        ''',
        [faturaId],
      );

      final totalCompras = resultadoTotal.first['total'] as int;

      // O lançamento precisa representar exatamente
      // o total das compras ativas da fatura.
      if (totalCompras != valor) {
        throw StateError(
          'O valor do lançamento não corresponde '
          'ao total consolidado da fatura.',
        );
      }

      // REGRA 4: Impedir pagamento duplicado.
      final existentes = await txn.query(
        'movimentacao',
        columns: ['id'],
        where: 'lancamento_id = ?',
        whereArgs: [lancamentoId],
        limit: 1,
      );

      if (existentes.isNotEmpty) {
        throw StateError('Esta fatura ja possui pagamento registrado.');
      }

      // REGRA 5: Registrar o pagamento integral.
      final movimentacao = MovimentacaoModel(
        lancamentoId: lancamentoId,
        valor: valor,
        dataMovimentacao: dataPagamento,
        forma: forma,
        observacao: observacao,
      );

      final movimentacaoId = await txn.insert(
        'movimentacao',
        movimentacao.toMap(),
      );

      // REGRA 6: Efetivar apenas o lancamento pendente.
      final linhas = await txn.update(
        'lancamento',
        {'status': 'EFETIVADO'},
        where: 'id = ? AND status = ? AND origem = ?',
        whereArgs: [lancamentoId, 'PENDENTE', 'FATURA'],
      );

      if (linhas != 1) {
        throw StateError('Nao foi possivel efetivar o pagamento.');
      }

      return MovimentacaoModel(
        id: movimentacaoId,
        lancamentoId: lancamentoId,
        valor: valor,
        dataMovimentacao: dataPagamento,
        forma: forma,
        observacao: observacao,
      );
    });
  }
}
