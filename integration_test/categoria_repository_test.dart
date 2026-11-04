
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'package:controle_financeiro_android/models/categoria_model.dart';
import 'package:controle_financeiro_android/repositories/categoria_repository.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Testa os metodos do CategoriaRepository', (tester) async {
    // Cria um banco exclusivo para os testes.
    final pasta = await getDatabasesPath();
    final caminho = join(pasta, 'teste_categoria_repository.db');

    await deleteDatabase(caminho);

    final schema = await rootBundle.loadString(
      'assets/sql/schema.sql',
    );

    final db = await openDatabase(
      caminho,
      version: 1,

      onConfigure: (database) async {
        await database.execute('PRAGMA foreign_keys = ON');
      },

      onCreate: (database, version) async {
        for (final comando in schema.split(';')) {
          final sql = comando.trim();

          if (sql.isNotEmpty) {
            await database.execute(sql);
          }
        }
      },
    );

    try {
      // Repository conectado ao banco temporário.
      final repository = CategoriaRepository(banco: db);

      // TESTE 1: Inserir uma categoria.
      final categoria = CategoriaModel(
        nome: 'Categoria Teste Android',
        tipo: 'DESPESA',
        descricao: 'Teste de integração',
      );

      final cadastrada = await repository.inserir(categoria);

      expect(cadastrada.id, isNotNull);
      expect(cadastrada.id, greaterThan(0));
      expect(cadastrada.nome, 'Categoria Teste Android');
      expect(cadastrada.status, 'ATIVA');

      // TESTE 2: Buscar pelo ID.
      final encontrada = await repository.buscarPorId(cadastrada.id!);

      expect(encontrada, isNotNull);
      expect(encontrada!.id, cadastrada.id);
      expect(encontrada.nome, 'Categoria Teste Android');
      expect(encontrada.tipo, 'DESPESA');

      // TESTE 3: Listar todas as categorias.
      final categorias = await repository.listar();

      expect(categorias.length, 1);
      expect(categorias.first.id, cadastrada.id);
      expect(categorias.first.nome, 'Categoria Teste Android');

      // TESTE 4: Buscar uma categoria inexistente.
      final inexistente = await repository.buscarPorId(999999);

      expect(inexistente, isNull);

    } finally {
      // Fecha e exclui somente o banco temporário.
      await db.close();
      await deleteDatabase(caminho);
    }
  });
}
