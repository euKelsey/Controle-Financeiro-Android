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

  testWidgets('Cartões: cadastrar, editar, inativar e reativar com histórico',
      (tester) async {
    final pasta = await getDatabasesPath();
    final caminho = join(pasta, 'teste_gerenciamento_cartoes.db');
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
          if (comando.trim().isNotEmpty) {
            await banco.execute(comando.trim());
          }
        }
      },
    );

    try {
      final cartoesRepo = CartaoRepository(banco: db);
      final faturasRepo = FaturaRepository(banco: db);
      final cartoesService = CartaoService(cartoesRepo);
      final faturasService = FaturaService(
        faturasRepo,
        lancamentoRepository: LancamentoRepository(banco: db),
        movimentacaoRepository: MovimentacaoRepository(banco: db),
      );

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.temaClaro,
        home: Scaffold(
          body: CartoesScreen(
            cartaoService: cartoesService,
            faturaRepository: faturasRepo,
            faturaService: faturasService,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Nenhum cartão cadastrado.'), findsOneWidget);
      await tester.tap(find.byTooltip('Novo cartão'));
      await tester.pumpAndSettle();

      final campos = find.byType(TextFormField);
      await tester.enterText(campos.at(0), 'Cartão CRUD');
      await tester.enterText(campos.at(1), 'Banco Teste');
      await tester.enterText(campos.at(2), '3500,90');
      await tester.enterText(campos.at(3), '10');
      await tester.enterText(campos.at(4), '20');
      await tester.ensureVisible(find.text('Salvar cartão'));
      await tester.tap(find.text('Salvar cartão'));
      await tester.pumpAndSettle();

      final cadastrados = await cartoesService.listarCartoes();
      expect(cadastrados.length, 1);
      final id = cadastrados.single.id!;
      expect(cadastrados.single.limiteTotal, 350090);
      expect(cadastrados.single.status, 'ATIVO');
      expect(find.text('Cartão CRUD'), findsOneWidget);

      // Registra uma fatura de teste para conferir preservacao historica.
      await db.insert('fatura', {
        'cartao_id': id,
        'mes_referencia': '2026-11',
        'data_fechamento': '2026-11-10',
        'data_vencimento': '2026-11-20',
        'status': 'FECHADA',
      });

      await tester.tap(find.byTooltip('Ações do cartão Cartão CRUD'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Editar cartão'));
      await tester.pumpAndSettle();
      expect(find.text('Editar cartão'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).at(0), 'Cartão Editado');
      await tester.ensureVisible(find.text('Salvar cartão'));
      await tester.tap(find.text('Salvar cartão'));
      await tester.pumpAndSettle();

      final editado = await cartoesService.buscarCartaoPorId(id);
      expect(editado.nome, 'Cartão Editado');
      expect(editado.limiteTotal, 350090);

      await tester.tap(find.byTooltip('Ações do cartão Cartão Editado'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Inativar cartão'));
      await tester.pumpAndSettle();
      expect(find.text('Inativar cartão?'), findsOneWidget);
      await tester.tap(find.text('Confirmar inativação'));
      await tester.pumpAndSettle();

      expect((await cartoesService.buscarCartaoPorId(id)).status, 'INATIVO');
      expect((await db.query('fatura')).length, 1);

      await tester.tap(find.byTooltip('Ações do cartão Cartão Editado'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reativar cartão'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmar reativação'));
      await tester.pumpAndSettle();

      expect((await cartoesService.buscarCartaoPorId(id)).status, 'ATIVO');
      expect((await db.query('fatura')).length, 1);

      await expectLater(
        cartoesService.cadastrarCartao(
          nome: '',
          instituicao: 'Banco',
          limiteTotal: 100,
          diaFechamento: 5,
          diaVencimento: 10,
        ),
        throwsArgumentError,
      );
      await expectLater(
        cartoesService.cadastrarCartao(
          nome: 'Inválido',
          instituicao: 'Banco',
          limiteTotal: -1,
          diaFechamento: 5,
          diaVencimento: 10,
        ),
        throwsArgumentError,
      );
      await expectLater(
        cartoesService.cadastrarCartao(
          nome: 'Inválido',
          instituicao: 'Banco',
          limiteTotal: 0,
          diaFechamento: 32,
          diaVencimento: 10,
        ),
        throwsArgumentError,
      );
      expect((await db.query('cartao')).length, 1);
      expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    } finally {
      await db.close();
      await deleteDatabase(caminho);
    }
  });
}
