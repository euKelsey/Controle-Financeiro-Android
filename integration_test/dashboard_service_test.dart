
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'package:controle_financeiro_android/repositories/lancamento_repository.dart';
import 'package:controle_financeiro_android/services/dashboard_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Valida consultas do DashboardService', (tester) async {
    // ETAPA 1: Preparar o banco temporario.
    final pasta = await getDatabasesPath();

    final caminho = join(
      pasta,
      'teste_dashboard_service.db',
    );

    await deleteDatabase(caminho);

    final schema = await rootBundle.loadString(
      'assets/sql/schema.sql',
    );

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
      // ETAPA 2: Configurar Repository e Service.
      final repository = LancamentoRepository(banco: db);
      final service = DashboardService(repository);

      // Criar categorias para os lancamentos.
      final categoriaReceitaId = await db.insert(
        'categoria',
        {
          'nome': 'Receitas Dashboard Service',
          'tipo': 'RECEITA',
          'status': 'ATIVA',
        },
      );

      final categoriaDespesaId = await db.insert(
        'categoria',
        {
          'nome': 'Despesas Dashboard Service',
          'tipo': 'DESPESA',
          'status': 'ATIVA',
        },
      );

      // Funcao auxiliar para criar lancamentos.
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
            'descricao': 'Lancamento Dashboard Service',
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

      // TESTE 1: Consultar um mes sem lancamentos.
      final vazio = await service.obterResumoMensal(
        ano: 2026,
        mes: 11,
      );

      expect(vazio.receitas, 0);
      expect(vazio.despesas, 0);
      expect(vazio.saldoPrevisto, 0);

      // ETAPA 3: Cadastrar dados de novembro/2026.
      await criarLancamento(
        tipo: 'RECEITA',
        valor: 500000,
        data: '2026-11-05',
      );

      await criarLancamento(
        tipo: 'DESPESA',
        valor: 120000,
        data: '2026-11-10',
      );

      await criarLancamento(
        tipo: 'DESPESA',
        valor: 30000,
        data: '2026-11-20',
        status: 'EFETIVADO',
      );

      // Lancamento cancelado nao entra no resumo.
      await criarLancamento(
        tipo: 'DESPESA',
        valor: 15000,
        data: '2026-11-25',
        status: 'CANCELADO',
      );

      // TESTE 2: Conferir o resumo de novembro.
      final novembro = await service.obterResumoMensal(
        ano: 2026,
        mes: 11,
      );

      expect(novembro.receitas, 500000);
      expect(novembro.despesas, 150000);
      expect(novembro.saldoPrevisto, 350000);

      // TESTE 3: Consultar outro mes sem registros.
      final outubro = await service.obterResumoMensal(
        ano: 2026,
        mes: 10,
      );

      expect(outubro.receitas, 0);
      expect(outubro.despesas, 0);
      expect(outubro.saldoPrevisto, 0);

      // ETAPA 4: Preparar consulta do mes atual.
      final hoje = DateTime.now();

      final dataAtual =
          '${hoje.year.toString().padLeft(4, '0')}-'
          '${hoje.month.toString().padLeft(2, '0')}-'
          '${hoje.day.toString().padLeft(2, '0')}';

      // Criamos um registro no mes atual do aparelho.
      await criarLancamento(
        tipo: 'RECEITA',
        valor: 75000,
        data: dataAtual,
      );

      // TESTE 4: Comparar consulta automatica
      // com consulta explicita do mesmo mes.
      final resumoAtual = await service.obterResumoAtual();

      final resumoEsperado = await service.obterResumoMensal(
        ano: hoje.year,
        mes: hoje.month,
      );

      expect(
        resumoAtual.receitas,
        resumoEsperado.receitas,
      );

      expect(
        resumoAtual.despesas,
        resumoEsperado.despesas,
      );

      expect(
        resumoAtual.saldoPrevisto,
        resumoEsperado.saldoPrevisto,
      );

      // Confirma que a receita inserida esta no resumo.
      expect(
        resumoAtual.receitas,
        greaterThanOrEqualTo(75000),
      );

      // TESTE 5: Bloquear mes invalido.
      await expectLater(
        service.obterResumoMensal(
          ano: 2026,
          mes: 0,
        ),
        throwsA(isA<ArgumentError>()),
      );

      await expectLater(
        service.obterResumoMensal(
          ano: 2026,
          mes: 13,
        ),
        throwsA(isA<ArgumentError>()),
      );

      // TESTE 6: Bloquear ano invalido.
      await expectLater(
        service.obterResumoMensal(
          ano: 0,
          mes: 11,
        ),
        throwsA(isA<ArgumentError>()),
      );

      // TESTE 7: Conferir integridade referencial.
      final integridade = await db.rawQuery(
        'PRAGMA foreign_key_check;',
      );

      expect(integridade, isEmpty);
    } finally {
      await db.close();
      await deleteDatabase(caminho);
    }
  });
}
