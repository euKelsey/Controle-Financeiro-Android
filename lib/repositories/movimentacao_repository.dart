
import 'package:sqflite/sqflite.dart';

import '../database/database_helper.dart';
import '../models/movimentacao_model.dart';

class MovimentacaoRepository {
  final Database? _bancoTeste;

  // Permite utilizar o banco principal ou um banco de testes.
  MovimentacaoRepository({Database? banco})
      : _bancoTeste = banco;

  Future<Database> _obterBanco() async {
    return _bancoTeste ?? await DatabaseHelper.obterBanco();
  }

  // Insere uma movimentação no SQLite.
  Future<MovimentacaoModel> inserir(
    MovimentacaoModel movimentacao,
  ) async {
    final db = await _obterBanco();

    final id = await db.insert(
      'movimentacao',
      movimentacao.toMap(),
    );

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
  Future<MovimentacaoModel?> buscarPorLancamentoId(
    int lancamentoId,
  ) async {
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
  Future<int> atualizar(
    MovimentacaoModel movimentacao,
  ) async {
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
      final id = await txn.insert(
        'movimentacao',
        movimentacao.toMap(),
      );

      // ETAPA 2: Efetivar somente um lançamento pendente.
      final linhasAtualizadas = await txn.update(
        'lancamento',
        {'status': 'EFETIVADO'},
        where: 'id = ? AND status = ?',
        whereArgs: [
          movimentacao.lancamentoId,
          'PENDENTE',
        ],
      );

      // Se não atualizou exatamente um lançamento,
      // a transação deverá ser desfeita.
      if (linhasAtualizadas != 1) {
        throw StateError(
          'O lançamento não está pendente.',
        );
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

}
