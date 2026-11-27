import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:controle_financeiro_android/repositories/cartao_repository.dart';
import 'package:controle_financeiro_android/repositories/categoria_repository.dart';
import 'package:controle_financeiro_android/repositories/compra_cartao_repository.dart';
import 'package:controle_financeiro_android/repositories/fatura_repository.dart';
import 'package:controle_financeiro_android/repositories/lancamento_repository.dart';
import 'package:controle_financeiro_android/repositories/movimentacao_repository.dart';
import 'package:controle_financeiro_android/screens/cartoes_screen.dart';
import 'package:controle_financeiro_android/services/cartao_service.dart';
import 'package:controle_financeiro_android/services/compra_cartao_service.dart';
import 'package:controle_financeiro_android/services/fatura_service.dart';
import 'package:controle_financeiro_android/theme/app_theme.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Compra em 1x, fatura compartilhada e bloqueio de fatura fechada',
      (tester) async {
    final caminho = join(await getDatabasesPath(), 'teste_compras_ui.db');
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
      final cartoesRepo = CartaoRepository(banco: db);
      final categoriasRepo = CategoriaRepository(banco: db);
      final comprasRepo = CompraCartaoRepository(banco: db);
      final faturasRepo = FaturaRepository(banco: db);
      final cartoesService = CartaoService(cartoesRepo);
      final comprasService = CompraCartaoService(
        comprasRepo,
        cartaoRepository: cartoesRepo,
        categoriaRepository: categoriasRepo,
      );
      final faturasService = FaturaService(
        faturasRepo,
        lancamentoRepository: LancamentoRepository(banco: db),
        movimentacaoRepository: MovimentacaoRepository(banco: db),
      );
      final cartao = await cartoesService.cadastrarCartao(
        nome: 'Cartão compras UI',
        instituicao: 'Banco Teste',
        limiteTotal: 500000,
        diaFechamento: 15,
        diaVencimento: 25,
      );
      final categoriaId = await db.insert('categoria', {
        'nome': 'Mercado UI',
        'tipo': 'DESPESA',
        'status': 'ATIVA',
      });
      await db.insert('categoria', {
        'nome': 'Receita não selecionável',
        'tipo': 'RECEITA',
        'status': 'ATIVA',
      });
      final hoje = DateTime.now();
      final periodo = DateTime(hoje.year, hoje.month + 1, 2);
      final ano = periodo.year.toString().padLeft(4, '0');
      final mes = periodo.month.toString().padLeft(2, '0');
      final iso = '$ano-$mes-02';

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.temaClaro,
        home: Scaffold(body: CartoesScreen(
          cartaoService: cartoesService,
          faturaRepository: faturasRepo,
          faturaService: faturasService,
          compraService: comprasService,
        )),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nova compra'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('compra-cartao')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cartão compras UI').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('compra-categoria')));
      await tester.pumpAndSettle();
      expect(find.text('Receita não selecionável'), findsNothing);
      await tester.tap(find.text('Mercado UI').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('compra-descricao')), 'Compra UI teste');
      await tester.enterText(find.byKey(const ValueKey('compra-valor')), '125,90');
      await tester.enterText(find.byKey(const ValueKey('compra-data')), '02/$mes/$ano');
      await tester.ensureVisible(find.text('Salvar compra'));
      await tester.tap(find.text('Salvar compra'));
      await tester.pumpAndSettle();

      final compras = await comprasService.listarCompras();
      expect(compras.length, 1);
      expect(compras.single.valorTotal, 12590);
      expect(compras.single.quantidadeParcelas, 1);
      expect(compras.single.cartaoId, cartao.id);
      final faturas = await db.query('fatura');
      expect(faturas.length, 1);
      expect(faturas.single['mes_referencia'], '$ano-$mes');

      await comprasService.cadastrarCompra(
        cartaoId: cartao.id!,
        categoriaId: categoriaId,
        descricao: 'Segunda compra teste',
        dataCompra: iso,
        valorTotal: 1000,
      );
      expect((await db.query('fatura')).length, 1);
      final parcelas = await db.query('parcela_cartao');
      expect(parcelas.length, 2);
      expect(parcelas.map((p) => p['fatura_id']).toSet().length, 1);
      expect((await db.query('lancamento')).isEmpty, isTrue);

      await tester.tap(find.text('Ver compras'));
      await tester.pumpAndSettle();
      expect(find.text('Compra UI teste'), findsOneWidget);
      expect(find.text('Segunda compra teste'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();

      final fechamento = await faturasService.atualizarFaturasAutomaticamente(
        dataReferencia: '$ano-$mes-15',
      );
      expect(fechamento.faturasFechadas, 1);
      expect(fechamento.lancamentosGerados, 1);
      await expectLater(comprasService.cadastrarCompra(
        cartaoId: cartao.id!,
        categoriaId: categoriaId,
        descricao: 'Compra bloqueada',
        dataCompra: iso,
        valorTotal: 100,
      ), throwsStateError);
      final lancamentos = await db.query('lancamento');
      expect(lancamentos.length, 1);
      expect(lancamentos.single['valor_previsto'], 13590);
      expect((await db.query('compra_cartao')).length, 2);
      expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    } finally {
      await db.close();
      await deleteDatabase(caminho);
    }
  });
}
