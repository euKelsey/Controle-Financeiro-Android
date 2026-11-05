
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

}
