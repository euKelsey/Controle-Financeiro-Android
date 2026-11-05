
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'package:controle_financeiro_android/repositories/lancamento_repository.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Valida resumo financeiro mensal', (tester) async {
    // ETAPA 1: Criar banco temporario.
    final pasta = await getDatabasesPath();

    final caminho = join(
      pasta,
      'teste_dashboard_resumo.db',
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
      // ETAPA 2: Preparar o Repository.
      final repository = LancamentoRepository(banco: db);

      // Criar categorias para manter as
      // regras de integridade do SQLite.
      final categoriaReceitaId = await db.insert(
        'categoria',
        {
          'nome': 'Receitas do Dashboard',
          'tipo': 'RECEITA',
          'status': 'ATIVA',
        },
      );

      final categoriaDespesaId = await db.insert(
        'categoria',
        {
          'nome': 'Despesas do Dashboard',
          'tipo': 'DESPESA',
          'status': 'ATIVA',
        },
      );

      // Funcao auxiliar para cadastrar
      // lancamentos financeiros de teste.
      Future<void> criarLancamento({
        required String tipo,
        required int valor,
        required String data,
        String status = 'PENDENTE',
      }) async {
        await db.insert(
          'lancamento',
          {
            'tipo': tipo,
            'descricao': 'Lancamento de teste',
            'valor_previsto': valor,
            'data_prevista': data,
            'categoria_id': tipo == 'RECEITA'
                ? categoriaReceitaId
                : categoriaDespesaId,
            'status': status,
            'origem': 'MANUAL',
          },
        );
      }

      // TESTE 1: Mes sem lancamentos.
      final vazio = await repository.obterResumoMensal(
        ano: 2026,
        mes: 11,
      );

      expect(vazio.receitas, 0);
      expect(vazio.despesas, 0);
      expect(vazio.saldoPrevisto, 0);

      // ETAPA 3: Cadastrar dados de novembro.
      await criarLancamento(
        tipo: 'RECEITA',
        valor: 500000,
        data: '2026-11-01',
      );

      await criarLancamento(
        tipo: 'DESPESA',
        valor: 150000,
        data: '2026-11-15',
      );

      await criarLancamento(
        tipo: 'DESPESA',
        valor: 35000,
        data: '2026-11-30',
        status: 'EFETIVADO',
      );

      // Este valor nao deve entrar no calculo.
      await criarLancamento(
        tipo: 'DESPESA',
        valor: 20000,
        data: '2026-11-20',
        status: 'CANCELADO',
      );

      // TESTE 2: Conferir o resumo de novembro.
      final novembro = await repository.obterResumoMensal(
        ano: 2026,
        mes: 11,
      );

      expect(novembro.receitas, 500000);
      expect(novembro.despesas, 185000);
      expect(novembro.saldoPrevisto, 315000);

      // ETAPA 4: Cadastrar dados de outros meses.
      await criarLancamento(
        tipo: 'RECEITA',
        valor: 300000,
        data: '2026-10-31',
      );

      await criarLancamento(
        tipo: 'DESPESA',
        valor: 80000,
        data: '2026-12-01',
      );

      // TESTE 3: Novembro nao pode mudar.
      final novembroNovamente =
          await repository.obterResumoMensal(
        ano: 2026,
        mes: 11,
      );

      expect(novembroNovamente.receitas, 500000);
      expect(novembroNovamente.despesas, 185000);
      expect(novembroNovamente.saldoPrevisto, 315000);

      // TESTE 4: Consultar outubro.
      final outubro = await repository.obterResumoMensal(
        ano: 2026,
        mes: 10,
      );

      expect(outubro.receitas, 300000);
      expect(outubro.despesas, 0);
      expect(outubro.saldoPrevisto, 300000);

      // TESTE 5: Consultar dezembro.
      final dezembro = await repository.obterResumoMensal(
        ano: 2026,
        mes: 12,
      );

      expect(dezembro.receitas, 0);
      expect(dezembro.despesas, 80000);
      expect(dezembro.saldoPrevisto, -80000);

      // TESTE 6: Validar meses invalidos.
      await expectLater(
        repository.obterResumoMensal(
          ano: 2026,
          mes: 0,
        ),
        throwsA(isA<ArgumentError>()),
      );

      await expectLater(
        repository.obterResumoMensal(
          ano: 2026,
          mes: 13,
        ),
        throwsA(isA<ArgumentError>()),
      );

      // TESTE 7: Validar ano invalido.
      await expectLater(
        repository.obterResumoMensal(
          ano: 0,
          mes: 11,
        ),
        throwsA(isA<ArgumentError>()),
      );

      // TESTE 8: O calculo nao pode
      // modificar os dados financeiros.
      final lancamentos = await db.query(
        'lancamento',
      );

      expect(lancamentos.length, 6);

      // TESTE 9: Conferir integridade do SQLite.
      final integridade = await db.rawQuery(
        'PRAGMA foreign_key_check;',
      );

      expect(integridade, isEmpty);
    } finally {
      // ETAPA 5: Limpar o banco de demonstracao.
      await db.close();
      await deleteDatabase(caminho);
    }
  });
}
