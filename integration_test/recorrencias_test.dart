import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:controle_financeiro_android/repositories/recorrencia_repository.dart';
import 'package:controle_financeiro_android/repositories/lancamento_repository.dart';
import 'package:controle_financeiro_android/repositories/categoria_repository.dart';
import 'package:controle_financeiro_android/services/lancamento_service.dart';
import 'package:controle_financeiro_android/services/dashboard_service.dart';
import 'package:controle_financeiro_android/screens/lancamentos_screen.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Recorrência mensal: duração, reajuste, cancelamento e virada de ano', (tester) async {
    final caminho = join(await getDatabasesPath(), 'teste_recorrencias.db');
    await deleteDatabase(caminho);
    final schema = await rootBundle.loadString('assets/sql/schema.sql');
    final db = await openDatabase(caminho, version: 1,
      onConfigure: (b) async { await b.execute('PRAGMA foreign_keys = ON'); },
      onCreate: (b, v) async {
        for (final parte in schema.split(';')) {
          if (parte.trim().isNotEmpty) await b.execute(parte.trim());
        }
      });
    try {
      final categoria = await db.insert('categoria', {
        'nome': 'Moradia teste', 'tipo': 'DESPESA', 'status': 'ATIVA',
      });
      final rec = RecorrenciaRepository(banco: db);
      final lanc = LancamentoRepository(banco: db);
      final service = LancamentoService(lanc,
        categoriaRepository: CategoriaRepository(banco: db), recorrencias: rec);
      final dashboard = DashboardService(lanc, recorrencias: rec);
      final ano = DateTime.now().year + 1;
      final id = await rec.cadastrar(tipo: 'DESPESA', descricao: 'Aluguel teste',
        valor: 150000, categoriaId: categoria, inicio: DateTime(ano, 12, 31),
        quantidadeMeses: 4);
      await rec.gerarAte(DateTime(ano + 1, 12, 31));
      Future<List<Map<String,Object?>>> ocorrencias() => db.query('lancamento',
        where: 'recorrencia_id = ?', whereArgs: [id], orderBy: 'data_prevista');
      final lista = await ocorrencias();
      expect(lista.length, 4);
      expect(lista.map((l) => l['data_prevista']), [
        '$ano-12-31', '${ano+1}-01-31',
        RecorrenciaRepository.iso(DateTime(ano+1,3,0)), '${ano+1}-03-31',
      ]);
      expect(await rec.gerarAte(DateTime(ano + 1, 12, 31)), 0);
      expect(await db.query('movimentacao'), isEmpty);
      await rec.editarOcorrencia(id: lista[1]['id'] as int, tipo: 'DESPESA',
        descricao: 'Aluguel teste', valor: 160000, categoriaId: categoria,
        data: DateTime(ano+1,1,30), futuros: false);
      expect((await ocorrencias())[2]['valor_previsto'], 150000);
      await expectLater(rec.editarOcorrencia(id: lista[1]['id'] as int,
        tipo: 'DESPESA', descricao: 'Inválido', valor: 1, categoriaId: categoria,
        data: DateTime(ano+1,2,1), futuros: false), throwsArgumentError);
      await rec.editarOcorrencia(id: lista[2]['id'] as int, tipo: 'DESPESA',
        descricao: 'Aluguel reajustado', valor: 170000, categoriaId: categoria,
        data: DateTime(ano+1,3,0), futuros: true);
      expect((await ocorrencias()).map((l) => l['valor_previsto']),
        [150000,160000,170000,170000]);
      await service.cancelarLancamento(lista[1]['id'] as int, registroDireto: true);
      expect(await rec.gerarAte(DateTime(ano+1,12,31)), 0);
      expect((await dashboard.obterResumoMensal(ano: ano+1, mes: 1)).despesas, 0);
      expect((await dashboard.obterResumoMensal(ano: ano+1, mes: 2)).despesas, 170000);
      await rec.encerrarDesde(lista[3]['id'] as int);
      expect((await dashboard.obterResumoMensal(ano: ano+1, mes: 3)).despesas, 0);
      expect((await ocorrencias()).length, 4);
      expect((await ocorrencias()).first['status'], 'PENDENTE');

      // Cadastro real pela interface, com duração limitada.
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: LancamentosScreen(service: service))));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Novo lançamento'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), 'Faculdade teste');
      await tester.enterText(find.byType(TextFormField).at(1), '650,00');
      await tester.ensureVisible(find.byKey(const ValueKey('categoria-DESPESA')));
      await tester.tap(find.byKey(const ValueKey('categoria-DESPESA')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Moradia teste').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Repetir mensalmente'));
      await tester.tap(find.text('Repetir mensalmente'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Definir quantidade de meses'));
      await tester.tap(find.text('Definir quantidade de meses'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.widgetWithText(TextFormField, 'Quantidade de meses'));
      await tester.enterText(find.widgetWithText(TextFormField, 'Quantidade de meses'), '3');
      await tester.ensureVisible(find.text('Salvar lançamento'));
      await tester.tap(find.text('Salvar lançamento'));
      await tester.pumpAndSettle();
      expect(find.text('Faculdade teste'), findsOneWidget);
      final hoje = DateTime.now();
      await rec.gerarAte(DateTime(hoje.year, hoje.month+4, 1));
      expect(await db.query('lancamento', where: 'descricao = ?', whereArgs: ['Faculdade teste']), hasLength(3));
      expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    } finally {
      await db.close();
      await deleteDatabase(caminho);
    }
  });
}
