
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'package:controle_financeiro_android/repositories/lancamento_repository.dart';
import 'package:controle_financeiro_android/screens/dashboard_screen.dart';
import 'package:controle_financeiro_android/services/dashboard_service.dart';
import 'package:controle_financeiro_android/theme/app_theme.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Dashboard exibe e atualiza proximos vencimentos',
    (tester) async {
      // ETAPA 1: Preparar banco temporario.
      final pasta = await getDatabasesPath();

      final caminho = join(
        pasta,
        'teste_dashboard_vencimentos.db',
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
        final categoriaDespesa = await db.insert(
          'categoria',
          {
            'nome': 'Despesa - Teste Dashboard',
            'tipo': 'DESPESA',
            'status': 'ATIVA',
          },
        );

        final categoriaReceita = await db.insert(
          'categoria',
          {
            'nome': 'Receita - Teste Dashboard',
            'tipo': 'RECEITA',
            'status': 'ATIVA',
          },
        );

        // ETAPA 3: Preparar datas relativas a hoje.
        final hoje = DateTime.now();

        final referencia = DateTime(
          hoje.year,
          hoje.month,
          hoje.day,
        );

        final amanha = referencia.add(
          const Duration(days: 1),
        );

        final depois = referencia.add(
          const Duration(days: 2),
        );

        String formatarData(DateTime data) {
          return '${data.year.toString().padLeft(4, '0')}-'
              '${data.month.toString().padLeft(2, '0')}-'
              '${data.day.toString().padLeft(2, '0')}';
        }

        String formatarDataVisual(DateTime data) {
          return '${data.day.toString().padLeft(2, '0')}/'
              '${data.month.toString().padLeft(2, '0')}/'
              '${data.year.toString().padLeft(4, '0')}';
        }

        // Funcao auxiliar para inserir lancamentos.
        Future<void> cadastrar({
          required String descricao,
          required String tipo,
          required int valor,
          required DateTime data,
          required String status,
        }) async {
          await db.insert(
            'lancamento',
            {
              'descricao': descricao,
              'tipo': tipo,
              'valor_previsto': valor,
              'data_prevista': formatarData(data),
              'categoria_id': tipo == 'RECEITA'
                  ? categoriaReceita
                  : categoriaDespesa,
              'status': status,
              'origem': 'MANUAL',
            },
          );
        }

        // ETAPA 4: Criar lancamentos de teste.
        await cadastrar(
          descricao: 'Energia Teste UI',
          tipo: 'DESPESA',
          valor: 18500,
          data: referencia,
          status: 'PENDENTE',
        );

        await cadastrar(
          descricao: 'Recebimento Teste UI',
          tipo: 'RECEITA',
          valor: 95000,
          data: amanha,
          status: 'PENDENTE',
        );

        await cadastrar(
          descricao: 'Despesa Efetivada UI',
          tipo: 'DESPESA',
          valor: 30000,
          data: depois,
          status: 'EFETIVADO',
        );

        await cadastrar(
          descricao: 'Despesa Cancelada UI',
          tipo: 'DESPESA',
          valor: 40000,
          data: depois,
          status: 'CANCELADO',
        );

        // ETAPA 5: Injetar o banco de testes.
        final repository = LancamentoRepository(
          banco: db,
        );

        final service = DashboardService(repository);

        // ETAPA 6: Abrir o Dashboard.
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

        await tester.pumpAndSettle();

        // A secao fica abaixo dos cartoes do resumo.
        // Rolamos ate seu titulo.
        await tester.ensureVisible(
          find.text('Próximos vencimentos'),
        );

        await tester.pumpAndSettle();

        // TESTE 1: Conferir a despesa pendente.
        expect(
          find.text('Energia Teste UI'),
          findsOneWidget,
        );

        expect(
          find.text('R\$ 185,00'),
          findsOneWidget,
        );

        expect(
          find.text(
            'Vence em ${formatarDataVisual(referencia)}',
          ),
          findsOneWidget,
        );

        // TESTE 2: Conferir receita pendente.
        expect(
          find.text('Recebimento Teste UI'),
          findsOneWidget,
        );

        expect(
          find.text('R\$ 950,00'),
          findsNWidgets(2),
        );

        // TESTE 3: Lancamentos nao pendentes
        // nao devem ser exibidos na lista.
        expect(
          find.text('Despesa Efetivada UI'),
          findsNothing,
        );

        expect(
          find.text('Despesa Cancelada UI'),
          findsNothing,
        );

        // ETAPA 7: Inserir um novo vencimento.
        await cadastrar(
          descricao: 'Internet Nova UI',
          tipo: 'DESPESA',
          valor: 12000,
          data: depois,
          status: 'PENDENTE',
        );

        // TESTE 4: O novo registro ainda
        // nao aparece sem atualizar a tela.
        expect(
          find.text('Internet Nova UI'),
          findsNothing,
        );

        // ETAPA 8: Atualizar pelo botao.
        await tester.tap(
          find.byTooltip('Atualizar resumo financeiro'),
        );

        await tester.pumpAndSettle();

        // TESTE 5: Conferir o novo vencimento.
        expect(
          find.text('Internet Nova UI'),
          findsOneWidget,
        );

        expect(
          find.text('R\$ 120,00'),
          findsOneWidget,
        );

        // TESTE 6: Os registros devem
        // permanecer inalterados.
        final registros = await db.query(
          'lancamento',
        );

        expect(registros.length, 5);

        // TESTE 7: Integridade referencial.
        final integridade = await db.rawQuery(
          'PRAGMA foreign_key_check;',
        );

        expect(integridade, isEmpty);

        // Desmontar a interface.
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
