
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

  // Fecha a conexão quando necessário.
  static Future<void> fecharBanco() async {
    if (_banco != null && _banco!.isOpen) {
      await _banco!.close();
    }

    _banco = null;
  }
}
