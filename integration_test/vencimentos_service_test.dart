
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'package:controle_financeiro_android/repositories/lancamento_repository.dart';
import 'package:controle_financeiro_android/services/dashboard_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'DashboardService consulta proximos vencimentos',
    (tester) async {
      // ETAPA 1: Preparar o banco temporario.
      final pasta = await getDatabasesPath();

      final caminho = join(
        pasta,
        'teste_vencimentos_service.db',
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
        // ETAPA 2: Criar uma categoria.
        final categoriaId = await db.insert(
          'categoria',
          {
            'nome': 'Despesas - Teste Service',
            'tipo': 'DESPESA',
            'status': 'ATIVA',
          },
        );

        // Funcao auxiliar para cadastrar despesas.
        Future<void> cadastrar({
          required String descricao,
          required String data,
        }) async {
          await db.insert(
            'lancamento',
            {
              'descricao': descricao,
              'tipo': 'DESPESA',
              'valor_previsto': 10000,
              'data_prevista': data,
              'categoria_id': categoriaId,
              'status': 'PENDENTE',
              'origem': 'MANUAL',
            },
          );
        }

        // ETAPA 3: Cadastrar dados de teste.
        await cadastrar(
          descricao: 'Internet',
          data: '2026-11-10',
        );

        await cadastrar(
          descricao: 'Energia',
          data: '2026-11-15',
        );

        await cadastrar(
          descricao: 'Aluguel',
          data: '2026-11-20',
        );

        // ETAPA 4: Criar Repository e Service.
        final repository = LancamentoRepository(
          banco: db,
        );

        final service = DashboardService(repository);

        // TESTE 1: Consultar a partir de 12/11.
        final proximos =
            await service.listarProximosVencimentos(
          dataReferencia: DateTime(2026, 11, 12),
        );

        expect(proximos.length, 2);

        expect(
          proximos.map((item) => item.descricao).toList(),
          ['Energia', 'Aluguel'],
        );

        // TESTE 2: Aplicar limite de 1.
        final limitado =
            await service.listarProximosVencimentos(
          dataReferencia: DateTime(2026, 11, 1),
          limite: 1,
        );

        expect(limitado.length, 1);
        expect(limitado.first.descricao, 'Internet');

        // TESTE 3: Periodo sem vencimentos.
        final vazio =
            await service.listarProximosVencimentos(
          dataReferencia: DateTime(2027, 1, 1),
        );

        expect(vazio, isEmpty);

        // TESTE 4: Consulta sem data informada.
        // Utiliza o dia atual do aparelho.
        final hoje = DateTime.now();

        final resultadoAtual =
            await service.listarProximosVencimentos();

        // Todos os resultados devem ter vencimento
        // igual ou posterior a data atual.
        final dataAtual =
            '${hoje.year.toString().padLeft(4, '0')}-'
            '${hoje.month.toString().padLeft(2, '0')}-'
            '${hoje.day.toString().padLeft(2, '0')}';

        for (final item in resultadoAtual) {
          expect(
            item.dataPrevista.compareTo(dataAtual) >= 0,
            isTrue,
          );
        }

        // TESTE 5: O Service nao deve modificar
        // os registros financeiros.
        final registros = await db.query('lancamento');

        expect(registros.length, 3);

        // TESTE 6: Integridade referencial.
        final integridade = await db.rawQuery(
          'PRAGMA foreign_key_check;',
        );

        expect(integridade, isEmpty);
      } finally {
        await db.close();
        await deleteDatabase(caminho);
      }
    },
  );
}
