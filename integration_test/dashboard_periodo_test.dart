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

  testWidgets('Dashboard navega entre meses', (tester) async {
    // ETAPA 1: Preparar banco temporario.
    final pasta = await getDatabasesPath();
    final caminho = join(pasta, 'teste_dashboard_periodo.db');

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

          if (sql.isNotEmpty) {
            await database.execute(sql);
          }
        }
      },
    );

    try {
      // ETAPA 2: Criar categorias.
      final receitaId = await db.insert('categoria', {
        'nome': 'Receitas - Teste Periodo',
        'tipo': 'RECEITA',
        'status': 'ATIVA',
      });

      final despesaId = await db.insert('categoria', {
        'nome': 'Despesas - Teste Periodo',
        'tipo': 'DESPESA',
        'status': 'ATIVA',
      });

      // ETAPA 3: Definir tres meses consecutivos.
      final hoje = DateTime.now();

      final anterior = DateTime(hoje.year, hoje.month - 1, 15);
      final atual = DateTime(hoje.year, hoje.month, 15);
      final proximo = DateTime(hoje.year, hoje.month + 1, 15);

      String formatarData(DateTime data) {
        return '${data.year.toString().padLeft(4, '0')}-'
            '${data.month.toString().padLeft(2, '0')}-'
            '${data.day.toString().padLeft(2, '0')}';
      }

      // Funcao auxiliar para cadastrar lancamentos.
      Future<void> criarLancamento({
        required String tipo,
        required int valor,
        required DateTime data,
      }) async {
        await db.insert('lancamento', {
          'tipo': tipo,
          'descricao': 'Lancamento do teste de periodo',
          'valor_previsto': valor,
          'data_prevista': formatarData(data),
          'categoria_id': tipo == 'RECEITA' ? receitaId : despesaId,
          'status': 'PENDENTE',
          'origem': 'MANUAL',
        });
      }

      // ETAPA 4: Cadastrar valores distintos.
      await criarLancamento(tipo: 'RECEITA', valor: 300000, data: anterior);

      await criarLancamento(tipo: 'DESPESA', valor: 50000, data: anterior);

      await criarLancamento(tipo: 'RECEITA', valor: 500000, data: atual);

      await criarLancamento(tipo: 'DESPESA', valor: 150000, data: atual);

      await criarLancamento(tipo: 'RECEITA', valor: 400000, data: proximo);

      await criarLancamento(tipo: 'DESPESA', valor: 100000, data: proximo);

      // ETAPA 5: Criar Service de testes.
      final repository = LancamentoRepository(banco: db);
      final service = DashboardService(repository);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.temaClaro,
          home: Scaffold(body: DashboardScreen(service: service)),
        ),
      );

      await tester.pumpAndSettle();

      // TESTE 1: Exibir os valores do mes atual.
      expect(find.text('R\$ 5.000,00'), findsOneWidget);
      expect(find.text('R\$ 1.500,00'), findsOneWidget);
      expect(find.text('R\$ 3.500,00'), findsOneWidget);

      // TESTE 2: Navegar ao mes anterior.
      await tester.tap(find.byTooltip('Mês anterior'));
      await tester.pumpAndSettle();

      expect(find.text('R\$ 3.000,00'), findsOneWidget);
      expect(find.text('R\$ 500,00'), findsOneWidget);
      expect(find.text('R\$ 2.500,00'), findsOneWidget);

      // TESTE 3: Confirmar que o mes atual
      // nao continua exibido.
      expect(find.text('R\$ 5.000,00'), findsNothing);

      // TESTE 4: Voltar ao mes atual.
      await tester.tap(find.byTooltip('Próximo mês'));
      await tester.pumpAndSettle();

      expect(find.text('R\$ 3.500,00'), findsOneWidget);

      // TESTE 5: Navegar ao proximo mes.
      await tester.tap(find.byTooltip('Próximo mês'));
      await tester.pumpAndSettle();

      expect(find.text('R\$ 4.000,00'), findsOneWidget);
      expect(find.text('R\$ 1.000,00'), findsOneWidget);
      expect(find.text('R\$ 3.000,00'), findsOneWidget);

      // TESTE 6: Recarregar sem perder o periodo.
      await tester.tap(find.byTooltip('Atualizar resumo financeiro'));
      await tester.pumpAndSettle();

      expect(find.text('R\$ 4.000,00'), findsOneWidget);
      expect(find.text('R\$ 1.000,00'), findsOneWidget);

      // TESTE 7: O botao de retorno deve aparecer,
      // pois estamos consultando o proximo mes.
      final botaoMesAtual = find.text('Voltar ao mês atual');

      expect(botaoMesAtual, findsOneWidget);

      // TESTE 8: Retornar ao mes atual.
      await tester.tap(botaoMesAtual);
      await tester.pumpAndSettle();

      // O mes atual deve apresentar os valores
      // cadastrados anteriormente.
      expect(find.text('R\$ 5.000,00'), findsOneWidget);

      expect(find.text('R\$ 1.500,00'), findsOneWidget);

      expect(find.text('R\$ 3.500,00'), findsOneWidget);

      // TESTE 9: O botao deve desaparecer.
      expect(botaoMesAtual, findsNothing);

      // TESTE 10: Navegar novamente
      // para o proximo mes.
      await tester.tap(find.byTooltip('Próximo mês'));

      await tester.pumpAndSettle();

      expect(find.text('R\$ 4.000,00'), findsOneWidget);

      expect(find.text('R\$ 1.000,00'), findsOneWidget);

      // TESTE 11: Registrar nova despesa
      // no mes futuro, sem atualizar a tela.
      await criarLancamento(tipo: 'DESPESA', valor: 20000, data: proximo);

      // A tela ainda deve mostrar os
      // valores da consulta anterior.
      expect(find.text('R\$ 1.000,00'), findsOneWidget);

      // TESTE 12: Simular o gesto de
      // puxar a tela para baixo.
      await tester.drag(find.byType(ListView), const Offset(0, 400));

      await tester.pumpAndSettle();

      // TESTE 13: Conferir valores atualizados.
      expect(find.text('R\$ 4.000,00'), findsOneWidget);

      expect(find.text('R\$ 1.200,00'), findsOneWidget);

      expect(find.text('R\$ 2.800,00'), findsOneWidget);

      // TESTE 14: A atualizacao por gesto
      // nao deve alterar o mes selecionado.
      expect(botaoMesAtual, findsOneWidget);

      // TESTE 15: Retornar ao mes atual novamente.
      await tester.tap(botaoMesAtual);
      await tester.pumpAndSettle();

      expect(find.text('R\$ 3.500,00'), findsOneWidget);

      expect(botaoMesAtual, findsNothing);

      // TESTE 16: Conferir que os seis
      // lancamentos foram preservados.
      final lancamentos = await db.query('lancamento');

      expect(lancamentos.length, 7);

      // TESTE 17: Verificar integridade do SQLite.
      final integridade = await db.rawQuery('PRAGMA foreign_key_check;');

      expect(integridade, isEmpty);

      // Desmontar a tela antes de fechar o banco.
      await tester.pumpWidget(const SizedBox.shrink());
    } finally {
      await db.close();
      await deleteDatabase(caminho);
    }
  });
}
