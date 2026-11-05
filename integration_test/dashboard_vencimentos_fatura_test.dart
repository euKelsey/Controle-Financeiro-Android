
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'package:controle_financeiro_android/repositories/fatura_repository.dart';
import 'package:controle_financeiro_android/repositories/lancamento_repository.dart';
import 'package:controle_financeiro_android/screens/dashboard_screen.dart';
import 'package:controle_financeiro_android/services/dashboard_service.dart';
import 'package:controle_financeiro_android/services/fatura_service.dart';
import 'package:controle_financeiro_android/theme/app_theme.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Dashboard exibe fatura sem duplicar compras',
    (tester) async {
      // ETAPA 1: Preparar um banco temporario.
      final pasta = await getDatabasesPath();

      final caminho = join(
        pasta,
        'teste_dashboard_fatura.db',
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
        // ETAPA 2: Criar datas futuras.
        final hoje = DateTime.now();

        final mesFatura = DateTime(
          hoje.year,
          hoje.month + 1,
          1,
        );

        final fechamento = DateTime(
          mesFatura.year,
          mesFatura.month,
          10,
        );

        final vencimento = DateTime(
          mesFatura.year,
          mesFatura.month,
          20,
        );

        String formatarData(DateTime data) {
          return '${data.year.toString().padLeft(4, '0')}-'
              '${data.month.toString().padLeft(2, '0')}-'
              '${data.day.toString().padLeft(2, '0')}';
        }

        final mesReferencia =
            '${mesFatura.year}-'
            '${mesFatura.month.toString().padLeft(2, '0')}';

        // ETAPA 3: Cadastrar cartao e categoria.
        final cartaoId = await db.insert('cartao', {
          'nome': 'Cartao Teste Dashboard',
          'instituicao': 'Banco Teste',
          'limite_total': 500000,
          'dia_fechamento': 10,
          'dia_vencimento': 20,
          'status': 'ATIVO',
        });

        final categoriaId = await db.insert(
          'categoria',
          {
            'nome': 'Compras do teste Dashboard',
            'tipo': 'DESPESA',
            'status': 'ATIVA',
          },
        );

        // ETAPA 4: Criar fatura aberta.
        final faturaId = await db.insert('fatura', {
          'cartao_id': cartaoId,
          'mes_referencia': mesReferencia,
          'data_fechamento': formatarData(fechamento),
          'data_vencimento': formatarData(vencimento),
          'status': 'ABERTA',
        });

        // Funcao auxiliar para registrar compras 1x.
        Future<void> criarCompra({
          required String descricao,
          required int valor,
        }) async {
          final compraId = await db.insert(
            'compra_cartao',
            {
              'cartao_id': cartaoId,
              'categoria_id': categoriaId,
              'descricao': descricao,
              'data_compra': formatarData(mesFatura),
              'valor_total': valor,
              'quantidade_parcelas': 1,
              'status': 'ATIVA',
            },
          );

          await db.insert('parcela_cartao', {
            'compra_cartao_id': compraId,
            'fatura_id': faturaId,
            'numero_parcela': 1,
            'valor': valor,
            'data_prevista': formatarData(vencimento),
          });
        }

        // ETAPA 5: Criar duas compras.
        await criarCompra(
          descricao: 'Supermercado Teste',
          valor: 25990,
        );

        await criarCompra(
          descricao: 'Farmacia Teste',
          valor: 8500,
        );

        // ETAPA 6: Processar o fechamento.
        final faturaRepository = FaturaRepository(
          banco: db,
        );

        final faturaService = FaturaService(
          faturaRepository,
        );

        final resultado =
            await faturaService.atualizarFaturasAutomaticamente(
          dataReferencia: formatarData(
            fechamento.add(const Duration(days: 1)),
          ),
        );

        expect(resultado.faturasFechadas, 1);
        expect(resultado.lancamentosGerados, 1);

        // ETAPA 7: Verificar o lancamento gerado.
        final lancamentos = await db.query(
          'lancamento',
        );

        expect(lancamentos.length, 1);
        expect(lancamentos.first['origem'], 'FATURA');
        expect(lancamentos.first['tipo'], 'DESPESA');
        expect(lancamentos.first['status'], 'PENDENTE');
        expect(lancamentos.first['valor_previsto'], 34490);
        expect(lancamentos.first['fatura_id'], faturaId);

        // ETAPA 8: Verificar a consulta do Dashboard.
        final repository = LancamentoRepository(
          banco: db,
        );

        final service = DashboardService(repository);

        final proximos =
            await service.listarProximosVencimentos();

        expect(proximos.length, 1);
        expect(proximos.first.origem, 'FATURA');
        expect(proximos.first.valorPrevisto, 34490);

        // ETAPA 9: Abrir o Dashboard.
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.temaClaro,
            home: Scaffold(
              body: DashboardScreen(service: service),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Verificar a interface.
        expect(
          find.text(
            'Fatura do cartão - $mesReferencia',
          ),
          findsOneWidget,
        );

        expect(
          find.text('R\$ 344,90'),
          findsOneWidget,
        );

        // As compras nao aparecem individualmente.
        expect(
          find.text('Supermercado Teste'),
          findsNothing,
        );

        expect(
          find.text('Farmacia Teste'),
          findsNothing,
        );

        // ETAPA 10: Conferir os registros.
        final compras = await db.query('compra_cartao');

        expect(compras.length, 2);

        final lancamentosFinais = await db.query(
          'lancamento',
        );

        expect(lancamentosFinais.length, 1);

        // Integridade referencial.
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
