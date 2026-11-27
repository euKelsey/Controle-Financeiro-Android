
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static const String nomeBanco = 'controle_financeiro.db';
  static const int versaoBanco = 1;

  static Database? _banco;

  // Abre o banco existente ou cria um novo.
  static Future<Database> obterBanco() async {
    if (_banco != null && _banco!.isOpen) {
      return _banco!;
    }

    final caminho = await obterCaminhoBanco();

    _banco = await openDatabase(
      caminho,
      version: versaoBanco,
      onConfigure: configurarConexao,
      onCreate: _criarBanco,
      onOpen: inicializarCategoriasPadrao,
    );

    return _banco!;
  }

  // Define o caminho do banco no Android.
  static Future<String> obterCaminhoBanco() async {
    final pastaBanco = await getDatabasesPath();
    return join(pastaBanco, nomeBanco);
  }

  // Habilita as chaves estrangeiras.
  static Future<void> configurarConexao(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON;');
  }

  // Executa o schema na primeira criação.
  static Future<void> _criarBanco(
    Database db,
    int versao,
  ) async {
    final schema = await rootBundle.loadString(
      'assets/sql/schema.sql',
    );

    // Divide o schema em comandos SQL.
    final comandos = schema.split(';');

    for (final comando in comandos) {
      final sql = comando.trim();

      if (sql.isNotEmpty) {
        await db.execute(sql);
      }
    }
  }

  // Também atende bancos V1 já existentes e ainda vazios de categorias.
  static Future<void> inicializarCategoriasPadrao(Database db) async {
    await db.transaction((txn) async {
      final existentes = await txn.query('categoria', columns: ['id'], limit: 1);
      if (existentes.isNotEmpty) return;
      const padrao = {
        'RECEITA': ['Salário', 'Renda extra', 'Outras receitas'],
        'DESPESA': ['Alimentação', 'Moradia', 'Transporte', 'Saúde',
          'Educação', 'Internet', 'Energia', 'Lazer', 'Outras despesas'],
      };
      for (final grupo in padrao.entries) {
        for (final nome in grupo.value) {
          await txn.insert('categoria', {
            'nome': nome, 'tipo': grupo.key, 'status': 'ATIVA',
          });
        }
      }
    });
  }

  // Fecha a conexão quando necessário.
  static Future<void> fecharBanco() async {
    if (_banco != null && _banco!.isOpen) {
      await _banco!.close();
    }

    _banco = null;
  }
}
