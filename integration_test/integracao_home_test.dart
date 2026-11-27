import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'package:controle_financeiro_android/repositories/cartao_repository.dart';
import 'package:controle_financeiro_android/repositories/categoria_repository.dart';
import 'package:controle_financeiro_android/repositories/fatura_repository.dart';
import 'package:controle_financeiro_android/repositories/lancamento_repository.dart';
import 'package:controle_financeiro_android/screens/cartoes_screen.dart';
import 'package:controle_financeiro_android/screens/dashboard_screen.dart';
import 'package:controle_financeiro_android/screens/home_screen.dart';
import 'package:controle_financeiro_android/screens/lancamentos_screen.dart';
import 'package:controle_financeiro_android/services/cartao_service.dart';
import 'package:controle_financeiro_android/services/dashboard_service.dart';
import 'package:controle_financeiro_android/services/fatura_service.dart';
import 'package:controle_financeiro_android/services/lancamento_service.dart';
import 'package:controle_financeiro_android/theme/app_theme.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Home processa faturas vencidas e atualiza abas ao navegar',
      (tester) async {
    final caminho = join(await getDatabasesPath(), 'teste_integracao_home.db');
    await deleteDatabase(caminho);
    final schema = await rootBundle.loadString('assets/sql/schema.sql');
    final db = await openDatabase(
      caminho,
      version: 1,
      onConfigure: (banco) async {
        await banco.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (banco, versao) async {
        for (final comando in schema.split(';')) {
          if (comando.trim().isNotEmpty) await banco.execute(comando.trim());
        }
      },
    );
    try {
      final hoje = DateTime.now();
      final mesRef = '${hoje.year.toString().padLeft(4, '0')}-'
          '${hoje.month.toString().padLeft(2, '0')}';
      final iso = '$mesRef-${hoje.day.toString().padLeft(2, '0')}';
      final categoriaId = await db.insert('categoria', {
        'nome': 'Despesa integração', 'tipo': 'DESPESA', 'status': 'ATIVA',
      });
      final cartaoRepo = CartaoRepository(banco: db);
      final cartaoService = CartaoService(cartaoRepo);
      final cartao = await cartaoService.cadastrarCartao(
        nome: 'Cartão integração',
        instituicao: 'Banco teste',
        limiteTotal: 500000,
        diaFechamento: 1,
        diaVencimento: 25,
      );
      final faturaId = await db.insert('fatura', {
        'cartao_id': cartao.id,
        'mes_referencia': mesRef,
        'data_fechamento': '$mesRef-01',
        'data_vencimento': '$mesRef-25',
        'status': 'ABERTA',
      });
      final compraId = await db.insert('compra_cartao', {
        'cartao_id': cartao.id,
        'categoria_id': categoriaId,
        'descricao': 'Compra integração',
        'data_compra': '$mesRef-01',
        'valor_total': 12340,
        'quantidade_parcelas': 1,
        'status': 'ATIVA',
      });
      await db.insert('parcela_cartao', {
        'compra_cartao_id': compraId,
        'fatura_id': faturaId,
        'numero_parcela': 1,
        'valor': 12340,
        'data_prevista': '$mesRef-25',
      });
      final faturas = FaturaRepository(banco: db);
      final lancamentos = LancamentoRepository(banco: db);
      final service = LancamentoService(
        lancamentos, categoriaRepository: CategoriaRepository(banco: db),
      );
      final dashboard = DashboardService(lancamentos, faturaRepository: faturas);
      final fechamento = FaturaService(faturas);
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.temaClaro,
        home: HomeScreen(
          temaAtual: ThemeMode.light,
          onTemaAlterado: (_) {},
          faturaService: fechamento,
          dashboardBuilder: (r) => DashboardScreen(service: dashboard, revisaoDados: r),
          lancamentosBuilder: (r) => LancamentosScreen(service: service, revisaoDados: r),
          cartoesBuilder: (r) => CartoesScreen(
            cartaoService: cartaoService, faturaService: fechamento,
            faturaRepository: faturas, revisaoDados: r,
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect((await db.query('fatura')).single['status'], 'FECHADA');
      expect((await db.query('lancamento')).length, 1);

      await service.cadastrarLancamento(
        tipo: 'DESPESA',
        descricao: 'Despesa entre abas',
        valorPrevisto: 2500,
        dataPrevista: iso,
        categoriaId: categoriaId,
      );
      await tester.tap(find.widgetWithText(NavigationDestination, 'Lançamentos'));
      await tester.pumpAndSettle();
      expect(find.text('Despesa entre abas'), findsOneWidget);

      await tester.tap(find.widgetWithText(NavigationDestination, 'Início'));
      await tester.pumpAndSettle();
      final resumo = await dashboard.obterResumoMensal(ano: hoje.year, mes: hoje.month);
      expect(resumo.despesas, 14840);
      expect((await db.query('lancamento')).length, 2);
      expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    } finally {
      await db.close();
      await deleteDatabase(caminho);
    }
  });
}
