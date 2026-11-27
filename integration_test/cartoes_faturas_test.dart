import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'package:controle_financeiro_android/repositories/cartao_repository.dart';
import 'package:controle_financeiro_android/repositories/fatura_repository.dart';
import 'package:controle_financeiro_android/repositories/lancamento_repository.dart';
import 'package:controle_financeiro_android/repositories/movimentacao_repository.dart';
import 'package:controle_financeiro_android/screens/cartoes_screen.dart';
import 'package:controle_financeiro_android/services/cartao_service.dart';
import 'package:controle_financeiro_android/services/fatura_service.dart';
import 'package:controle_financeiro_android/theme/app_theme.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Cartoes exibem faturas e pagam apenas uma vez', (tester) async {
    final pasta = await getDatabasesPath();
    final caminho = join(pasta, 'teste_cartoes_faturas_ui.db');
    await deleteDatabase(caminho);
    final schema = await rootBundle.loadString('assets/sql/schema.sql');
    final db = await openDatabase(
      caminho,
      version: 1,
      onConfigure: (banco) async {
        await banco.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (banco, version) async {
        for (final comando in schema.split(';')) {
          if (comando.trim().isNotEmpty) await banco.execute(comando.trim());
        }
      },
    );

    try {
      final hoje = DateTime.now();
      final periodo = DateTime(hoje.year, hoje.month + 1, 1);
      String data(int dia) =>
          '${periodo.year.toString().padLeft(4, '0')}-'
          '${periodo.month.toString().padLeft(2, '0')}-'
          '${dia.toString().padLeft(2, '0')}';
      final mesRef =
          '${periodo.year}-${periodo.month.toString().padLeft(2, '0')}';

      final cartaoRepository = CartaoRepository(banco: db);
      final cartaoService = CartaoService(cartaoRepository);
      final cartao = await cartaoService.cadastrarCartao(
        nome: 'Cartão de testes UI',
        instituicao: 'Banco dos Testes',
        limiteTotal: 500000,
        diaFechamento: 10,
        diaVencimento: 20,
      );
      final cartaoId = cartao.id!;
      final categoriaId = await db.insert('categoria', {
        'nome': 'Compras de teste',
        'tipo': 'DESPESA',
        'status': 'ATIVA',
      });
      final faturaId = await db.insert('fatura', {
        'cartao_id': cartaoId,
        'mes_referencia': mesRef,
        'data_fechamento': data(10),
        'data_vencimento': data(20),
        'status': 'ABERTA',
      });
      final compraId = await db.insert('compra_cartao', {
        'cartao_id': cartaoId,
        'categoria_id': categoriaId,
        'descricao': 'Compra de teste 1x',
        'data_compra': data(5),
        'valor_total': 12990,
        'quantidade_parcelas': 1,
        'status': 'ATIVA',
      });
      await db.insert('parcela_cartao', {
        'compra_cartao_id': compraId,
        'fatura_id': faturaId,
        'numero_parcela': 1,
        'valor': 12990,
        'data_prevista': data(20),
      });

      final faturasRepository = FaturaRepository(banco: db);
      final lancamentosRepository = LancamentoRepository(banco: db);
      final movimentacoesRepository = MovimentacaoRepository(banco: db);
      final faturaService = FaturaService(
        faturasRepository,
        lancamentoRepository: lancamentosRepository,
        movimentacaoRepository: movimentacoesRepository,
      );

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.temaClaro,
        home: Scaffold(
          body: CartoesScreen(
            cartaoService: cartaoService,
            faturaService: faturaService,
            faturaRepository: faturasRepository,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Cartão de testes UI'), findsOneWidget);
      expect(find.text('Nenhuma fatura neste período.'), findsOneWidget);
      await tester.tap(find.byTooltip('Próximo mês'));
      await tester.pumpAndSettle();

      expect(find.text('Cartão de testes UI'), findsNWidgets(2));
      expect(find.text('Pagar fatura'), findsNothing);
      final abertas = await faturasRepository.listarResumoDashboard(
        ano: periodo.year, mes: periodo.month,
      );
      expect(abertas.single.situacaoPagamento, 'ABERTA');

      final resultado = await faturaService.atualizarFaturasAutomaticamente(
        dataReferencia: data(11),
      );
      expect(resultado.faturasFechadas, 1);
      expect(resultado.lancamentosGerados, 1);
      await tester.tap(find.byTooltip('Atualizar cartões e faturas'));
      await tester.pumpAndSettle();

      final botaoPagar = find.text('Pagar fatura');
      expect(botaoPagar, findsOneWidget);
      await tester.ensureVisible(botaoPagar);
      await tester.tap(botaoPagar);
      await tester.pumpAndSettle();
      // O texto aparece no titulo do dialogo e no botao de confirmacao.
      expect(find.text('Confirmar pagamento'), findsNWidgets(2));

      // Nao confirma o pagamento no emulador com data futura simulada.
      // Confirma apenas que a acao exige confirmacao; a integridade e
      // idempotencia do pagamento sao testadas pelo service com data valida.
      await tester.tap(find.text('Voltar'));
      await tester.pumpAndSettle();

      final pago = await faturaService.pagarFatura(
        faturaId: faturaId,
        dataPagamento: data(12),
        forma: 'PIX',
      );
      expect(pago.valor, 12990);
      await tester.tap(find.byTooltip('Atualizar cartões e faturas'));
      await tester.pumpAndSettle();
      expect(find.text('Pagar fatura'), findsNothing);
      expect(find.textContaining('Paga'), findsOneWidget);

      await expectLater(
        faturaService.pagarFatura(
          faturaId: faturaId,
          dataPagamento: data(13),
          forma: 'PIX',
        ),
        throwsArgumentError,
      );
      expect((await db.query('movimentacao')).length, 1);
      expect((await db.query('lancamento')).length, 1);
      expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    } finally {
      await db.close();
      await deleteDatabase(caminho);
    }
  });
}
