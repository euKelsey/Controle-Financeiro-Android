import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'package:controle_financeiro_android/repositories/fatura_repository.dart';
import 'package:controle_financeiro_android/repositories/lancamento_repository.dart';
import 'package:controle_financeiro_android/repositories/movimentacao_repository.dart';
import 'package:controle_financeiro_android/screens/dashboard_screen.dart';
import 'package:controle_financeiro_android/services/dashboard_service.dart';
import 'package:controle_financeiro_android/services/fatura_service.dart';
import 'package:controle_financeiro_android/theme/app_theme.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Dashboard lista faturas e atualiza pagamento', (tester) async {
    final pasta = await getDatabasesPath();
    final caminho = join(pasta, 'teste_dashboard_faturas_periodo.db');
    await deleteDatabase(caminho);

    final schema = await rootBundle.loadString('assets/sql/schema.sql');
    final db = await openDatabase(
      caminho,
      version: 1,
      onConfigure: (database) async {
        await database.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (database, version) async {
        for (final comando in schema.split(';')) {
          final sql = comando.trim();
          if (sql.isNotEmpty) await database.execute(sql);
        }
      },
    );

    try {
      final hoje = DateTime.now();
      final periodo = DateTime(hoje.year, hoje.month + 1, 1);

      String data(int dia) {
        return '${periodo.year.toString().padLeft(4, '0')}-'
            '${periodo.month.toString().padLeft(2, '0')}-'
            '${dia.toString().padLeft(2, '0')}';
      }

      final mesReferencia =
          '${periodo.year}-${periodo.month.toString().padLeft(2, '0')}';
      final categoriaId = await db.insert('categoria', {
        'nome': 'Categoria Teste Faturas UI',
        'tipo': 'DESPESA',
        'status': 'ATIVA',
      });

      Future<int> criarCartao(String nome) => db.insert('cartao', {
        'nome': nome,
        'instituicao': 'Banco Teste',
        'limite_total': 500000,
        'dia_fechamento': 10,
        'dia_vencimento': 20,
        'status': 'ATIVO',
      });

      final cartao1 = await criarCartao('Cartão Principal UI');
      final cartao2 = await criarCartao('Cartão Secundário UI');

      Future<int> criarFatura(int cartaoId, int diaVencimento) =>
          db.insert('fatura', {
            'cartao_id': cartaoId,
            'mes_referencia': mesReferencia,
            'data_fechamento': data(10),
            'data_vencimento': data(diaVencimento),
            'status': 'ABERTA',
          });

      final fatura1 = await criarFatura(cartao1, 20);
      final fatura2 = await criarFatura(cartao2, 25);

      Future<void> criarCompra({
        required int cartaoId,
        required int faturaId,
        required int valor,
        required String descricao,
        String status = 'ATIVA',
      }) async {
        final compraId = await db.insert('compra_cartao', {
          'cartao_id': cartaoId,
          'categoria_id': categoriaId,
          'descricao': descricao,
          'data_compra': data(5),
          'valor_total': valor,
          'quantidade_parcelas': 1,
          'status': status,
        });
        await db.insert('parcela_cartao', {
          'compra_cartao_id': compraId,
          'fatura_id': faturaId,
          'numero_parcela': 1,
          'valor': valor,
          'data_prevista': data(20),
        });
      }

      await criarCompra(
        cartaoId: cartao1,
        faturaId: fatura1,
        valor: 25990,
        descricao: 'Supermercado',
      );
      await criarCompra(
        cartaoId: cartao1,
        faturaId: fatura1,
        valor: 8500,
        descricao: 'Farmácia',
      );
      await criarCompra(
        cartaoId: cartao1,
        faturaId: fatura1,
        valor: 2000,
        descricao: 'Compra cancelada',
        status: 'CANCELADA',
      );
      await criarCompra(
        cartaoId: cartao2,
        faturaId: fatura2,
        valor: 5000,
        descricao: 'Compra segundo cartão',
      );

      final faturaRepo = FaturaRepository(banco: db);
      final lancamentoRepo = LancamentoRepository(banco: db);
      final movimentacaoRepo = MovimentacaoRepository(banco: db);
      final service = DashboardService(
        lancamentoRepo,
        faturaRepository: faturaRepo,
      );

      final antes = await service.listarFaturasDashboard(
        ano: periodo.year,
        mes: periodo.month,
      );
      expect(antes.length, 2);
      expect(antes.first.cartaoNome, 'Cartão Principal UI');
      expect(antes.first.valorTotal, 34490);
      expect(antes.first.situacaoPagamento, 'ABERTA');
      expect(antes.last.valorTotal, 5000);

      final limitadas = await service.listarFaturasDashboard(
        ano: periodo.year,
        mes: periodo.month,
        limite: 1,
      );
      expect(limitadas.length, 1);
      await expectLater(
        service.listarFaturasDashboard(
          ano: periodo.year,
          mes: periodo.month,
          limite: 0,
        ),
        throwsArgumentError,
      );

      final faturaService = FaturaService(
        faturaRepo,
        lancamentoRepository: lancamentoRepo,
        movimentacaoRepository: movimentacaoRepo,
      );
      final fechamento = await faturaService.atualizarFaturasAutomaticamente(
        dataReferencia: data(11),
      );
      expect(fechamento.faturasFechadas, 2);
      expect(fechamento.lancamentosGerados, 2);

      final fechadas = await service.listarFaturasDashboard(
        ano: periodo.year,
        mes: periodo.month,
      );
      expect(fechadas.first.statusFatura, 'FECHADA');
      expect(fechadas.first.situacaoPagamento, 'PENDENTE');

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.temaClaro,
        home: Scaffold(body: DashboardScreen(service: service)),
      ));
      await tester.pumpAndSettle();

      // O Dashboard inicia no mes atual; a fatura e do mes seguinte.
      expect(find.text('Cartão Principal UI'), findsNothing);
      await tester.tap(find.byTooltip('Próximo mês'));
      await tester.pumpAndSettle();

      expect(find.text('Cartão Principal UI'), findsOneWidget);
      expect(find.text('Cartão Secundário UI'), findsOneWidget);
      expect(find.text('R\$ 50,00'), findsOneWidget);

      await faturaService.pagarFatura(
        faturaId: fatura1,
        dataPagamento: data(12),
        forma: 'PIX',
      );
      await tester.tap(find.byTooltip('Atualizar resumo financeiro'));
      await tester.pumpAndSettle();

      // O cartão continua exibido e passa a constar como pago.
      final depois = await service.listarFaturasDashboard(
        ano: periodo.year,
        mes: periodo.month,
      );
      expect(depois.first.id, fatura1);
      expect(depois.first.situacaoPagamento, 'PAGA');
      expect(depois.last.situacaoPagamento, 'PENDENTE');
      expect(find.text('Paga'), findsOneWidget);
      expect(find.text('Cartão Principal UI'), findsOneWidget);
      expect(find.text('Cartão Secundário UI'), findsOneWidget);

      final lancamentos = await db.query('lancamento');
      expect(lancamentos.length, 2);
      final pagamentos = await db.query('movimentacao');
      expect(pagamentos.length, 1);
      expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);

      await tester.pumpWidget(const SizedBox.shrink());
    } finally {
      await db.close();
      await deleteDatabase(caminho);
    }
  });
}
