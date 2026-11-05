
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'package:controle_financeiro_android/repositories/lancamento_repository.dart';
import 'package:controle_financeiro_android/services/dashboard_service.dart';
import 'package:controle_financeiro_android/screens/dashboard_screen.dart';
import 'package:controle_financeiro_android/theme/app_theme.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Dashboard exibe e atualiza os valores financeiros',
    (tester) async {
      // ETAPA 1: Preparar o banco de testes.
      final pasta = await getDatabasesPath();

      final caminho = join(
        pasta,
        'teste_dashboard_screen.db',
      );

      await deleteDatabase(caminho);

      final schema = await rootBundle.loadString(
        'assets/sql/schema.sql',
      );

      final db = await openDatabase(
        caminho,
        version: 1,
        onConfigure: (database) async {
          await database.execute(
            'PRAGMA foreign_keys = ON',
          );
        },
        onCreate: (database, version) async {
          for (final comando in schema.split(';')) {
            final sql = comando.trim();

            if (sql.isNotEmpty) {
              await database.execute(sql);
            }
          }
        },
      );

      try {
        // ETAPA 2: Criar categorias.
        final categoriaReceitaId = await db.insert(
          'categoria',
          {
            'nome': 'Receitas Dashboard UI',
            'tipo': 'RECEITA',
            'status': 'ATIVA',
          },
        );

        final categoriaDespesaId = await db.insert(
          'categoria',
          {
            'nome': 'Despesas Dashboard UI',
            'tipo': 'DESPESA',
            'status': 'ATIVA',
          },
        );

        // ETAPA 3: Utilizar o mes atual.
        final hoje = DateTime.now();

        final dataAtual =
            '${hoje.year.toString().padLeft(4, '0')}-'
            '${hoje.month.toString().padLeft(2, '0')}-'
            '${hoje.day.toString().padLeft(2, '0')}';

        // Funcao auxiliar para inserir lancamentos.
        Future<void> criarLancamento({
          required String tipo,
          required int valor,
        }) async {
          await db.insert(
            'lancamento',
            {
              'tipo': tipo,
              'descricao': 'Lancamento do teste visual',
              'valor_previsto': valor,
              'data_prevista': dataAtual,
              'categoria_id': tipo == 'RECEITA'
                  ? categoriaReceitaId
                  : categoriaDespesaId,
              'status': 'PENDENTE',
              'origem': 'MANUAL',
            },
          );
        }

        // ETAPA 4: Preparar os valores iniciais.
        await criarLancamento(
          tipo: 'RECEITA',
          valor: 500000,
        );

        await criarLancamento(
          tipo: 'DESPESA',
          valor: 150000,
        );

        // ETAPA 5: Injetar o banco temporario.
        final repository = LancamentoRepository(
          banco: db,
        );

        final service = DashboardService(repository);

        // ETAPA 6: Abrir o Dashboard no Flutter.
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.temaClaro,
            home: Scaffold(
              body: DashboardScreen(
                service: service,
              ),
            ),
          ),
        );

        // Aguarda a consulta e os widgets.
        await tester.pumpAndSettle();

        // TESTE 1: Conferir os valores iniciais.
        expect(
          find.text('R\$ 5.000,00'),
          findsOneWidget,
        );

        expect(
          find.text('R\$ 1.500,00'),
          findsOneWidget,
        );

        expect(
          find.text('R\$ 3.500,00'),
          findsOneWidget,
        );

        // TESTE 2: Verificar os titulos.
        expect(
          find.text('Resumo do mês'),
          findsOneWidget,
        );

        expect(
          find.text('Receitas'),
          findsOneWidget,
        );

        expect(
          find.text('Despesas'),
          findsOneWidget,
        );

        // ETAPA 7: Criar uma nova despesa
        // depois que a tela ja foi carregada.
        await criarLancamento(
          tipo: 'DESPESA',
          valor: 50000,
        );

        // TESTE 3: Os valores anteriores
        // permanecem ate a atualizacao.
        expect(
          find.text('R\$ 1.500,00'),
          findsOneWidget,
        );

        // ETAPA 8: Simular o toque no botao.
        final botaoAtualizar = find.byTooltip(
          'Atualizar resumo financeiro',
        );

        expect(botaoAtualizar, findsOneWidget);

        await tester.tap(botaoAtualizar);

        await tester.pumpAndSettle();

        // TESTE 4: Conferir os valores atualizados.
        expect(
          find.text('R\$ 5.000,00'),
          findsOneWidget,
        );

        expect(
          find.text('R\$ 2.000,00'),
          findsOneWidget,
        );

        expect(
          find.text('R\$ 3.000,00'),
          findsOneWidget,
        );

        // TESTE 5: O valor antigo nao
        // deve continuar na interface.
        expect(
          find.text('R\$ 1.500,00'),
          findsNothing,
        );

        // TESTE 6: Conferir os registros.
        final lancamentos = await db.query(
          'lancamento',
        );

        expect(lancamentos.length, 3);

        // TESTE 7: Conferir integridade SQLite.
        final integridade = await db.rawQuery(
          'PRAGMA foreign_key_check;',
        );

        expect(integridade, isEmpty);

        // Desmonta a tela antes de fechar o banco.
        await tester.pumpWidget(
          const SizedBox.shrink(),
        );
      } finally {
        await db.close();
        await deleteDatabase(caminho);
      }
    },
  );
}
