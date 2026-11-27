import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:controle_financeiro_android/database/database_helper.dart';
import 'package:controle_financeiro_android/repositories/categoria_repository.dart';
import 'package:controle_financeiro_android/services/categoria_service.dart';
import 'package:controle_financeiro_android/screens/categorias_screen.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Categorias iniciais e gerenciamento preservam histórico', (tester) async {
    final caminho = join(await getDatabasesPath(), 'teste_categorias_ui.db');
    await deleteDatabase(caminho);
    final schema = await rootBundle.loadString('assets/sql/schema.sql');
    final db = await openDatabase(caminho, version: 1,
      onConfigure: DatabaseHelper.configurarConexao,
      onCreate: (banco, versao) async {
        for (final comando in schema.split(';')) {
          if (comando.trim().isNotEmpty) await banco.execute(comando.trim());
        }
      },
    );
    try {
      final repo = CategoriaRepository(banco: db);
      final service = CategoriaService(repo);
      await DatabaseHelper.inicializarCategoriasPadrao(db);
      expect((await repo.listar()).length, 12);
      await DatabaseHelper.inicializarCategoriasPadrao(db);
      expect((await repo.listar()).length, 12);
      final salario = await repo.buscarPorNomeTipo('Salário', 'RECEITA');
      expect(salario, isNotNull);
      await service.inativarCategoria(salario!.id!);
      await DatabaseHelper.inicializarCategoriasPadrao(db);
      expect((await repo.buscarPorId(salario.id!))!.status, 'INATIVA');

      await tester.pumpWidget(MaterialApp(home: CategoriasScreen(service: service)));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Nova categoria'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, 'Teste UI categoria');
      await tester.ensureVisible(find.text('Salvar categoria'));
      await tester.tap(find.text('Salvar categoria'));
      await tester.pumpAndSettle();
      final criada = await repo.buscarPorNomeTipo('Teste UI categoria', 'DESPESA');
      expect(criada, isNotNull);
      final data = DateTime.now().toIso8601String().substring(0, 10);
      await db.insert('lancamento', {
        'tipo': 'DESPESA', 'descricao': 'Histórico teste',
        'valor_previsto': 1000, 'data_prevista': data,
        'categoria_id': criada!.id, 'status': 'PENDENTE', 'origem': 'MANUAL',
      });
      final menu = find.byTooltip('Ações de Teste UI categoria');
      await tester.scrollUntilVisible(menu, 200);
      await tester.tap(menu);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Inativar categoria'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();
      expect((await repo.buscarPorId(criada.id!))!.status, 'INATIVA');
      expect((await repo.listarAtivas()).any((c) => c.id == criada.id), isFalse);
      expect((await db.query('lancamento')).single['categoria_id'], criada.id);
      await DatabaseHelper.inicializarCategoriasPadrao(db);
      expect((await repo.listar()).length, 13);
      expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    } finally {
      await db.close();
      await deleteDatabase(caminho);
    }
  });
}
