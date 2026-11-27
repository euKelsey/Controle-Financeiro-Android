
import 'package:sqflite/sqflite.dart';

import '../database/database_helper.dart';
import '../models/categoria_model.dart';

class CategoriaRepository {
  final Database? _bancoTeste;

  // Sem argumento, utiliza o banco principal.
  // Nos testes, podemos informar outro banco.
  CategoriaRepository({Database? banco}) : _bancoTeste = banco;

  Future<Database> _obterBanco() async {
    return _bancoTeste ?? await DatabaseHelper.obterBanco();
  }

  // Cadastra uma categoria.
  Future<CategoriaModel> inserir(CategoriaModel categoria) async {
    final db = await _obterBanco();

    final id = await db.insert(
      'categoria',
      categoria.toMap(),
    );

    return CategoriaModel(
      id: id,
      nome: categoria.nome,
      tipo: categoria.tipo,
      descricao: categoria.descricao,
      status: categoria.status,
    );
  }

  // Lista todas as categorias em ordem alfabética.
  Future<List<CategoriaModel>> listar() async {
    final db = await _obterBanco();

    final registros = await db.query(
      'categoria',
      orderBy: 'nome ASC',
    );

    return registros
        .map((registro) => CategoriaModel.fromMap(registro))
        .toList();
  }

  // Busca uma categoria pelo ID.
  Future<CategoriaModel?> buscarPorId(int id) async {
    final db = await _obterBanco();

    final registros = await db.query(
      'categoria',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (registros.isEmpty) {
      return null;
    }

    return CategoriaModel.fromMap(registros.first);
  }

  
  // Lista somente as categorias ativas.
  Future<List<CategoriaModel>> listarAtivas() async {
    final db = await _obterBanco();

    final registros = await db.query(
      'categoria',
      where: 'status = ?',
      whereArgs: ['ATIVA'],
      orderBy: 'nome ASC',
    );

    return registros
        .map((registro) => CategoriaModel.fromMap(registro))
        .toList();
  }

  // Busca categoria pelo nome e tipo.
  Future<CategoriaModel?> buscarPorNomeTipo(
    String nome,
    String tipo,
  ) async {
    final db = await _obterBanco();

    final registros = await db.query(
      'categoria',
      where: 'nome = ? AND tipo = ?',
      whereArgs: [nome, tipo],
      limit: 1,
    );

    if (registros.isEmpty) {
      return null;
    }

    return CategoriaModel.fromMap(registros.first);
  }

  // Atualiza os dados de uma categoria existente.
  Future<int> atualizar(CategoriaModel categoria) async {
    if (categoria.id == null) {
      throw ArgumentError(
        'O ID da categoria é obrigatório para atualização.',
      );
    }

    final db = await _obterBanco();

    return db.update(
      'categoria',
      {
        'nome': categoria.nome,
        'tipo': categoria.tipo,
        'descricao': categoria.descricao,
        'status': categoria.status,
      },
      where: 'id = ?',
      whereArgs: [categoria.id],
    );
  }

  // Inativa uma categoria sem excluí-la.
  Future<int> inativar(int id) async {
    final db = await _obterBanco();

    return db.update(
      'categoria',
      {'status': 'INATIVA'},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

}
