
import 'package:sqflite/sqflite.dart';

import '../database/database_helper.dart';
import '../models/cartao_model.dart';

class CartaoRepository {
  final Database? _bancoTeste;

  // Permite utilizar o banco principal ou um banco de testes.
  CartaoRepository({Database? banco}) : _bancoTeste = banco;

  Future<Database> _obterBanco() async {
    return _bancoTeste ?? await DatabaseHelper.obterBanco();
  }

  // Cadastra um novo cartão.
  Future<CartaoModel> inserir(CartaoModel cartao) async {
    final db = await _obterBanco();

    final id = await db.insert(
      'cartao',
      cartao.toMap(),
    );

    return CartaoModel(
      id: id,
      nome: cartao.nome,
      instituicao: cartao.instituicao,
      limiteTotal: cartao.limiteTotal,
      diaFechamento: cartao.diaFechamento,
      diaVencimento: cartao.diaVencimento,
      status: cartao.status,
      observacao: cartao.observacao,
    );
  }

  // Lista todos os cartões, inclusive os inativos.
  Future<List<CartaoModel>> listar() async {
    final db = await _obterBanco();

    final registros = await db.query(
      'cartao',
      orderBy: 'nome ASC',
    );

    return registros
        .map((registro) => CartaoModel.fromMap(registro))
        .toList();
  }

  // Busca um cartão pelo identificador.
  Future<CartaoModel?> buscarPorId(int id) async {
    final db = await _obterBanco();

    final registros = await db.query(
      'cartao',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (registros.isEmpty) {
      return null;
    }

    return CartaoModel.fromMap(registros.first);
  }

  
  // Atualiza os dados de um cartão existente.
  Future<int> atualizar(CartaoModel cartao) async {
    if (cartao.id == null) {
      throw ArgumentError(
        'O ID do cartão é obrigatório para atualização.',
      );
    }

    final db = await _obterBanco();

    return db.update(
      'cartao',
      {
        'nome': cartao.nome,
        'instituicao': cartao.instituicao,
        'limite_total': cartao.limiteTotal,
        'dia_fechamento': cartao.diaFechamento,
        'dia_vencimento': cartao.diaVencimento,
        'status': cartao.status,
        'observacao': cartao.observacao,
      },
      where: 'id = ?',
      whereArgs: [cartao.id],
    );
  }

  // Inativa um cartão sem excluir seus dados.
  Future<int> inativar(int id) async {
    final db = await _obterBanco();

    return db.update(
      'cartao',
      {'status': 'INATIVO'},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Reativa um cartão anteriormente inativado.
  Future<int> reativar(int id) async {
    final db = await _obterBanco();

    return db.update(
      'cartao',
      {'status': 'ATIVO'},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

}
