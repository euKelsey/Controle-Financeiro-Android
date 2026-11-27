import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'package:controle_financeiro_android/repositories/lancamento_repository.dart';
import 'package:controle_financeiro_android/screens/lancamentos_screen.dart';
import 'package:controle_financeiro_android/services/lancamento_service.dart';
import 'package:controle_financeiro_android/theme/app_theme.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Lançamentos exibem período, tipo e status do SQLite', (tester) async {
    final pasta = await getDatabasesPath();
    final caminho = join(pasta, 'teste_listagem_lancamentos.db');
    await deleteDatabase(caminho);
    final schema = await rootBundle.loadString('assets/sql/schema.sql');
    final db = await openDatabase(
      caminho,
      version: 1,
      onConfigure: (banco) async {
        await banco.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (banco, version) async {
        for (final parte in schema.split(';')) {
          final sql = parte.trim();
          if (sql.isNotEmpty) await banco.execute(sql);
        }
      },
    );

    try {
      final agora = DateTime.now();
      final outroMes = DateTime(agora.year, agora.month + 1, 1);
      String data(DateTime d) =>
          '${d.year.toString().padLeft(4, '0')}-'
          '${d.month.toString().padLeft(2, '0')}-'
          '${d.day.toString().padLeft(2, '0')}';

      final categoriaReceita = await db.insert('categoria', {
        'nome': 'Receitas Listagem',
        'tipo': 'RECEITA',
        'status': 'ATIVA',
      });
      final categoriaDespesa = await db.insert('categoria', {
        'nome': 'Despesas Listagem',
        'tipo': 'DESPESA',
        'status': 'ATIVA',
      });

      Future<void> inserir({
        required String descricao,
        required String tipo,
        required int valor,
        required DateTime dataPrevista,
        String status = 'PENDENTE',
      }) async {
        await db.insert('lancamento', {
          'tipo': tipo,
          'descricao': descricao,
          'valor_previsto': valor,
          'data_prevista': data(dataPrevista),
          'categoria_id': tipo == 'RECEITA'
              ? categoriaReceita
              : categoriaDespesa,
          'status': status,
          'origem': 'MANUAL',
        });
      }

      await inserir(
        descricao: 'Salário teste',
        tipo: 'RECEITA',
        valor: 350000,
        dataPrevista: DateTime(agora.year, agora.month, 2),
        status: 'EFETIVADO',
      );
      await inserir(
        descricao: 'Conta de luz teste',
        tipo: 'DESPESA',
        valor: 15990,
        dataPrevista: DateTime(agora.year, agora.month, 10),
      );
      await inserir(
        descricao: 'Despesa cancelada teste',
        tipo: 'DESPESA',
        valor: 1000,
        dataPrevista: DateTime(agora.year, agora.month, 12),
        status: 'CANCELADO',
      );
      await inserir(
        descricao: 'Receita próximo mês',
        tipo: 'RECEITA',
        valor: 2000,
        dataPrevista: outroMes,
      );

      final repo = LancamentoRepository(banco: db);
      final service = LancamentoService(repo);
      final atuais = await service.listarPorPeriodo(
        ano: agora.year, mes: agora.month,
      );
      expect(atuais.length, 3);
      expect(atuais.first.descricao, 'Despesa cancelada teste');
      final pendentes = await service.listarPorPeriodo(
        ano: agora.year, mes: agora.month,
        status: 'PENDENTE',
      );
      expect(pendentes.length, 1);
      expect(pendentes.single.descricao, 'Conta de luz teste');
      final receitas = await service.listarPorPeriodo(
        ano: agora.year, mes: agora.month,
        tipo: 'RECEITA',
      );
      expect(receitas.length, 1);
      final segundaPagina = await service.listarPorPeriodo(
        ano: agora.year, mes: agora.month,
        limite: 1,
        deslocamento: 1,
      );
      expect(segundaPagina.length, 1);
      await expectLater(
        service.listarPorPeriodo(ano: agora.year, mes: 13),
        throwsArgumentError,
      );

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.temaClaro,
        home: Scaffold(body: LancamentosScreen(service: service)),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Salário teste'), findsOneWidget);
      expect(find.text('Conta de luz teste'), findsOneWidget);
      expect(find.text('Despesa cancelada teste'), findsOneWidget);
      expect(find.text('Receita próximo mês'), findsNothing);

      await tester.tap(find.byTooltip('Próximo mês'));
      await tester.pumpAndSettle();
      expect(find.text('Receita próximo mês'), findsOneWidget);
      expect(find.text('Salário teste'), findsNothing);

      await tester.tap(find.byTooltip('Mês anterior'));
      await tester.pumpAndSettle();

      // A mudança dos filtros também é validada diretamente pelo serviço.
      // A consulta na interface permanece somente leitura nesta etapa.
      expect(find.text('Conta de luz teste'), findsOneWidget);
      final total = await db.query('lancamento');
      expect(total.length, 4);
      expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);

      await tester.pumpWidget(const SizedBox.shrink());
    } finally {
      await db.close();
      await deleteDatabase(caminho);
    }
  });
}
