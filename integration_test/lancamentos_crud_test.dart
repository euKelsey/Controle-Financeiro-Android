import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'package:controle_financeiro_android/repositories/categoria_repository.dart';
import 'package:controle_financeiro_android/repositories/lancamento_repository.dart';
import 'package:controle_financeiro_android/screens/lancamentos_screen.dart';
import 'package:controle_financeiro_android/services/lancamento_service.dart';
import 'package:controle_financeiro_android/theme/app_theme.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Cadastro, edicao e cancelamento preservam regras financeiras',
      (tester) async {
    final pasta = await getDatabasesPath();
    final caminho = join(pasta, 'teste_lancamentos_crud.db');
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
      final categoriaId = await db.insert('categoria', {
        'nome': 'Despesas de teste CRUD',
        'tipo': 'DESPESA',
        'status': 'ATIVA',
      });
      final receitaId = await db.insert('categoria', {
        'nome': 'Receitas de teste CRUD',
        'tipo': 'RECEITA',
        'status': 'ATIVA',
      });
      final repository = LancamentoRepository(banco: db);
      final categorias = CategoriaRepository(banco: db);
      final service = LancamentoService(
        repository,
        categoriaRepository: categorias,
      );
      final agora = DateTime.now();
      final iso = '${agora.year.toString().padLeft(4, '0')}-'
          '${agora.month.toString().padLeft(2, '0')}-'
          '${agora.day.toString().padLeft(2, '0')}';

      final cadastrada = await service.cadastrarLancamento(
        tipo: ' DESPESA ',
        descricao: ' Conta de água ',
        valorPrevisto: 9876,
        dataPrevista: iso,
        categoriaId: categoriaId,
      );
      expect(cadastrada.tipo, 'DESPESA');
      expect(cadastrada.descricao, 'Conta de água');
      expect(cadastrada.status, 'PENDENTE');

      await expectLater(
        service.cadastrarLancamento(
          tipo: 'DESPESA',
          descricao: 'Categoria inválida',
          valorPrevisto: 1200,
          dataPrevista: iso,
          categoriaId: receitaId,
        ),
        throwsArgumentError,
      );
      await expectLater(
        service.cadastrarLancamento(
          tipo: 'RECEITA',
          descricao: 'Data inválida',
          valorPrevisto: 1200,
          dataPrevista: '2026-02-30',
          categoriaId: receitaId,
        ),
        throwsArgumentError,
      );
      final editada = await service.atualizarLancamento(
        lancamentoId: cadastrada.id!,
        tipo: 'DESPESA',
        descricao: 'Água atualizada',
        valorPrevisto: 11990,
        dataPrevista: iso,
        categoriaId: categoriaId,
      );
      expect(editada.valorPrevisto, 11990);
      expect(editada.descricao, 'Água atualizada');

      // O formulario consulta categorias ativas do tipo correto.
      final disponiveis = await service.listarCategoriasFormulario(
        tipo: 'DESPESA',
      );
      expect(disponiveis.single.id, categoriaId);

      // O botao de cadastro cria um lancamento real no banco temporario.
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.temaClaro,
        home: Scaffold(body: LancamentosScreen(service: service)),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Novo lançamento'));
      await tester.pumpAndSettle();
      expect(find.text('Novo lançamento'), findsOneWidget);

      final campos = find.byType(TextFormField);
      await tester.enterText(campos.at(0), 'Internet teste');
      await tester.enterText(campos.at(1), '75,90');

      await tester.ensureVisible(campos.at(2));
      await tester.tap(campos.at(2));
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      // O formulario inicia com a data de hoje e tipo DESPESA.
      await tester.ensureVisible(find.byKey(const ValueKey('categoria-DESPESA')));
      await tester.tap(find.byKey(const ValueKey('categoria-DESPESA')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Despesas de teste CRUD').last);
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Salvar lançamento'));
      await tester.tap(find.text('Salvar lançamento'));
      await tester.pumpAndSettle();
      expect(find.text('Internet teste'), findsOneWidget);

      final lancamentos = await repository.listarPorPeriodo(
        ano: agora.year,
        mes: agora.month,
      );
      expect(lancamentos.length, 2);
      expect(
        lancamentos.where((l) =>
            l.descricao == 'Internet teste' && l.valorPrevisto == 7590).length,
        1,
      );

      final novo = lancamentos.singleWhere((l) => l.descricao == 'Internet teste');
      expect(novo.status, 'EFETIVADO');
      expect((await db.query('movimentacao', where: 'lancamento_id = ?', whereArgs: [novo.id])).single['valor'], 7590);

      // Cancelar nao exclui o registro, so altera sua situacao.
      final cancelado = await service.cancelarLancamento(cadastrada.id!);
      expect(cancelado.status, 'CANCELADO');
      await expectLater(
        service.atualizarLancamento(
          lancamentoId: cadastrada.id!,
          tipo: 'DESPESA',
          descricao: 'Tentativa indevida',
          valorPrevisto: 100,
          dataPrevista: iso,
          categoriaId: categoriaId,
        ),
        throwsArgumentError,
      );

      // Fatura: edicao e cancelamento manual sempre bloqueados.
      final cartaoId = await db.insert('cartao', {
        'nome': 'Cartão teste',
        'instituicao': 'Teste',
        'limite_total': 100000,
        'dia_fechamento': 5,
        'dia_vencimento': 15,
        'status': 'ATIVO',
      });
      final mesReferencia =
          '${agora.year}-${agora.month.toString().padLeft(2, '0')}';
      final faturaId = await db.insert('fatura', {
        'cartao_id': cartaoId,
        'mes_referencia': mesReferencia,
        'data_fechamento': iso,
        'data_vencimento': iso,
        'status': 'FECHADA',
      });
      final faturaLancamentoId = await db.insert('lancamento', {
        'tipo': 'DESPESA',
        'descricao': 'Fatura não editável',
        'valor_previsto': 1990,
        'data_prevista': iso,
        'fatura_id': faturaId,
        'status': 'PENDENTE',
        'origem': 'FATURA',
      });
      await expectLater(
        service.cancelarLancamento(faturaLancamentoId),
        throwsArgumentError,
      );
      await expectLater(
        service.atualizarLancamento(
          lancamentoId: faturaLancamentoId,
          tipo: 'DESPESA',
          descricao: 'Não pode',
          valorPrevisto: 1990,
          dataPrevista: iso,
          categoriaId: categoriaId,
        ),
        throwsArgumentError,
      );

      final registros = await db.query('lancamento');
      expect(registros.length, 3);
      expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    } finally {
      await db.close();
      await deleteDatabase(caminho);
    }
  });
}
