import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:controle_financeiro_android/repositories/lancamento_repository.dart';
import 'package:controle_financeiro_android/repositories/categoria_repository.dart';
import 'package:controle_financeiro_android/repositories/movimentacao_repository.dart';
import 'package:controle_financeiro_android/services/lancamento_service.dart';
import 'package:controle_financeiro_android/services/movimentacao_service.dart';
import 'package:controle_financeiro_android/screens/lancamentos_screen.dart';
import 'package:controle_financeiro_android/theme/app_theme.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Registro direto, edição e cancelamento pela interface', (tester) async {
    final caminho = join(await getDatabasesPath(), 'teste_movimentacoes_ui.db');
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
      final lancamentos = LancamentoRepository(banco: db);
      final movimentacoes = MovimentacaoRepository(banco: db);
      final service = LancamentoService(
        lancamentos, categoriaRepository: CategoriaRepository(banco: db),
      );
      final movService = MovimentacaoService(
        movimentacoes, lancamentoRepository: lancamentos,
      );
      final hoje = DateTime.now();
      final data = hoje.toIso8601String().substring(0, 10);
      final despesaId = await db.insert('categoria', {
        'nome': 'Contas teste', 'tipo': 'DESPESA', 'status': 'ATIVA',
      });
      final receitaId = await db.insert('categoria', {
        'nome': 'Renda teste', 'tipo': 'RECEITA', 'status': 'ATIVA',
      });
      final despesa = await service.cadastrarLancamento(
        tipo: 'DESPESA', descricao: 'Conta teste pagamento',
        valorPrevisto: 12050, dataPrevista: data, categoriaId: despesaId, registroDireto: true,
      );
      final receita = await service.cadastrarLancamento(
        tipo: 'RECEITA', descricao: 'Salário teste recebimento',
        valorPrevisto: 100000, dataPrevista: data, categoriaId: receitaId, registroDireto: true,
      );

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.temaClaro,
        home: Scaffold(body: LancamentosScreen(
          service: service, movimentacaoService: movService,
        )),
      ));
      await tester.pumpAndSettle();
      expect((await lancamentos.buscarPorId(despesa.id!))!.status, 'EFETIVADO');
      expect((await lancamentos.buscarPorId(receita.id!))!.status, 'EFETIVADO');
      final menuDespesa = find.byTooltip('Ações de Conta teste pagamento');
      await tester.ensureVisible(menuDespesa);
      await tester.tap(menuDespesa);
      await tester.pumpAndSettle();
      expect(find.text('Registrar pagamento'), findsNothing);
      await tester.tap(find.text('Editar'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(1), '200,00');
      await tester.ensureVisible(find.text('Salvar lançamento'));
      await tester.tap(find.text('Salvar lançamento'));
      await tester.pumpAndSettle();
      expect((await lancamentos.buscarPorId(despesa.id!))!.valorPrevisto, 20000);
      expect((await movimentacoes.buscarPorLancamentoId(despesa.id!))!.valor, 20000);
      final menuReceita = find.byTooltip('Ações de Salário teste recebimento');
      await tester.ensureVisible(menuReceita);
      await tester.tap(menuReceita);
      await tester.pumpAndSettle();
      expect(find.text('Registrar recebimento'), findsNothing);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmar cancelamento'));
      await tester.pumpAndSettle();
      expect((await lancamentos.buscarPorId(receita.id!))!.status, 'CANCELADO');
      expect(await movimentacoes.buscarPorLancamentoId(receita.id!), isNotNull);
      final registros = await movimentacoes.listar();
      expect(registros.length, 1);
      expect(registros.single.valor, 20000);
      expect(registros.single.forma, 'OUTRO');
      final resumo = await lancamentos.obterResumoMensal(ano: hoje.year, mes: hoje.month);
      expect(resumo.receitas, 0);
      expect(resumo.despesas, 20000);
      await expectLater(
        movService.cadastrarMovimentacao(
          lancamentoId: despesa.id!, valor: 12050,
          dataMovimentacao: data, forma: 'PIX',
        ), throwsArgumentError,
      );
      expect((await db.query('movimentacao')).length, 2);
      expect((await db.query('lancamento')).length, 2);
      expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    } finally {
      await db.close();
      await deleteDatabase(caminho);
    }
  });
}
