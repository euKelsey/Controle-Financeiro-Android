import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:controle_financeiro_android/repositories/lancamento_repository.dart';
import 'package:controle_financeiro_android/repositories/recorrencia_repository.dart';
import 'package:controle_financeiro_android/repositories/fatura_repository.dart';
import 'package:controle_financeiro_android/services/dashboard_service.dart';
import 'package:controle_financeiro_android/screens/dashboard_screen.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Resumo anual com recorrências, faturas e navegação', (tester) async {
    final caminho = join(await getDatabasesPath(), 'teste_dashboard_anual.db');
    await deleteDatabase(caminho);
    final schema = await rootBundle.loadString('assets/sql/schema.sql');
    final db = await openDatabase(caminho, version: 1,
      onConfigure: (b) async { await b.execute('PRAGMA foreign_keys = ON'); },
      onCreate: (b, v) async {
        for (final sql in schema.split(';')) {
          if (sql.trim().isNotEmpty) await b.execute(sql.trim());
        }
      });
    try {
      final ano = DateTime.now().year;
      final catReceita = await db.insert('categoria', {
        'nome': 'Salário', 'tipo': 'RECEITA', 'status': 'ATIVA',
      });
      final catDespesa = await db.insert('categoria', {
        'nome': 'Moradia', 'tipo': 'DESPESA', 'status': 'ATIVA',
      });
      final rec = RecorrenciaRepository(banco: db);
      await rec.cadastrar(tipo: 'RECEITA', descricao: 'Salário anual',
        valor: 500000, categoriaId: catReceita, inicio: DateTime(ano, 1, 5));
      await rec.cadastrar(tipo: 'DESPESA', descricao: 'Aluguel anual',
        valor: 150000, categoriaId: catDespesa, inicio: DateTime(ano, 1, 10),
        quantidadeMeses: 12);
      await db.insert('lancamento', {
        'tipo': 'DESPESA', 'descricao': 'Cancelado',
        'valor_previsto': 99999, 'data_prevista': '$ano-12-10',
        'categoria_id': catDespesa, 'status': 'CANCELADO', 'origem': 'MANUAL',
      });
      final cartao = await db.insert('cartao', {
        'nome': 'Cartão anual', 'instituicao': 'Banco', 'limite_total': 500000,
        'dia_fechamento': 25, 'dia_vencimento': 5, 'status': 'ATIVO',
      });
      final fatura = await db.insert('fatura', {
        'cartao_id': cartao, 'mes_referencia': '$ano-12',
        'data_fechamento': '$ano-12-25', 'data_vencimento': '${ano+1}-01-05',
        'status': 'ABERTA',
      });
      final compra = await db.insert('compra_cartao', {
        'cartao_id': cartao, 'categoria_id': catDespesa, 'descricao': 'Compra anual',
        'data_compra': '$ano-12-01', 'valor_total': 40000,
        'quantidade_parcelas': 1, 'status': 'ATIVA',
      });
      await db.insert('parcela_cartao', {
        'compra_cartao_id': compra, 'fatura_id': fatura, 'numero_parcela': 1,
        'valor': 40000, 'data_prevista': '${ano+1}-01-05',
      });
      final service = DashboardService(LancamentoRepository(banco: db),
        recorrencias: rec, faturaRepository: FaturaRepository(banco: db));
      final meses = await service.obterResumoAnual(ano: ano);
      expect(meses.length, 12);
      expect(meses.fold<int>(0, (s,m) => s+m.receitas), 6000000);
      expect(meses.fold<int>(0, (s,m) => s+m.despesas), 1840000);
      expect(meses.last.saldoPrevisto, 310000);
      expect((await service.obterResumoAnual(ano: ano+1)).first.despesas, 0);
      expect((await service.obterResumoAnual(ano: ano+1)).first.receitas, 500000);
      await tester.pumpWidget(MaterialApp(home: Scaffold(
        body: DashboardScreen(service: service, iniciarAnual: true))));
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(find.byKey(const ValueKey('saldo-anual'))).data, 'R\$ 41.600,00');
      final dezembro = find.byKey(const ValueKey('mes-12'));
      await tester.ensureVisible(dezembro);
      await tester.tap(dezembro);
      await tester.pumpAndSettle();
      expect(find.text('Dezembro de $ano'), findsOneWidget);
      expect(find.descendant(of: find.byKey(const ValueKey('resumo-saldo')),
        matching: find.text('R\$ 3.100,00')), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byTooltip('Próximo ano'));
      await tester.tap(find.byTooltip('Próximo ano'));
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(find.byKey(const ValueKey('saldo-anual'))).data, 'R\$ 60.000,00');
      expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    } finally {
      await db.close();
      await deleteDatabase(caminho);
    }
  });
}
