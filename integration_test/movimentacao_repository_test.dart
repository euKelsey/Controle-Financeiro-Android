
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'package:controle_financeiro_android/models/movimentacao_model.dart';
import 'package:controle_financeiro_android/repositories/movimentacao_repository.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Testa cadastro e consultas de movimentacoes',
      (tester) async {
    final pasta = await getDatabasesPath();
    final caminho = join(
      pasta,
      'teste_movimentacao_repository.db',
    );

    // Remove somente o banco temporário deste teste.
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
      final repository = MovimentacaoRepository(banco: db);

      // TESTE 1: Criar categoria válida.
      final categoriaId = await db.insert(
        'categoria',
        {
          'nome': 'Moradia',
          'tipo': 'DESPESA',
          'status': 'ATIVA',
        },
      );

      // TESTE 2: Criar primeiro lançamento.
      final primeiroLancamentoId = await db.insert(
        'lancamento',
        {
          'tipo': 'DESPESA',
          'descricao': 'Conta de energia',
          'valor_previsto': 18590,
          'data_prevista': '2026-11-10',
          'categoria_id': categoriaId,
          'status': 'PENDENTE',
          'origem': 'MANUAL',
        },
      );

      // TESTE 3: Inserir movimentação.
      final primeira = await repository.inserir(
        MovimentacaoModel(
          lancamentoId: primeiroLancamentoId,
          valor: 18590,
          dataMovimentacao: '2026-11-09',
          forma: 'PIX',
          observacao: 'Pagamento confirmado',
        ),
      );

      expect(primeira.id, isNotNull);
      expect(primeira.id, greaterThan(0));
      expect(primeira.lancamentoId, primeiroLancamentoId);
      expect(primeira.valor, 18590);
      expect(primeira.forma, 'PIX');

      // TESTE 4: Buscar movimentação pelo ID.
      final encontrada = await repository.buscarPorId(
        primeira.id!,
      );

      expect(encontrada, isNotNull);
      expect(encontrada!.valor, 18590);
      expect(encontrada.forma, 'PIX');
      expect(encontrada.dataMovimentacao, '2026-11-09');
      expect(encontrada.observacao, 'Pagamento confirmado');

      // TESTE 5: Criar segundo lançamento.
      final segundoLancamentoId = await db.insert(
        'lancamento',
        {
          'tipo': 'DESPESA',
          'descricao': 'Conta de internet',
          'valor_previsto': 12000,
          'data_prevista': '2026-11-20',
          'categoria_id': categoriaId,
          'status': 'PENDENTE',
          'origem': 'MANUAL',
        },
      );

      // TESTE 6: Inserir segunda movimentação.
      final segunda = await repository.inserir(
        MovimentacaoModel(
          lancamentoId: segundoLancamentoId,
          valor: 12000,
          dataMovimentacao: '2026-11-05',
          forma: 'BOLETO',
        ),
      );

      expect(segunda.id, isNotNull);

      // TESTE 7: Listagem ordenada pela data.
      final movimentacoes = await repository.listar();

      expect(movimentacoes.length, 2);

      expect(movimentacoes[0].forma, 'BOLETO');
      expect(movimentacoes[0].dataMovimentacao, '2026-11-05');

      expect(movimentacoes[1].forma, 'PIX');
      expect(movimentacoes[1].dataMovimentacao, '2026-11-09');

      // TESTE 8: Consultar movimentação inexistente.
      final inexistente = await repository.buscarPorId(999999);

      expect(inexistente, isNull);

      // TESTE 9: Impedir segunda movimentação
      // para o mesmo lançamento.
      await expectLater(
        repository.inserir(
          MovimentacaoModel(
            lancamentoId: primeiroLancamentoId,
            valor: 18590,
            dataMovimentacao: '2026-11-10',
            forma: 'DINHEIRO',
          ),
        ),
        throwsA(isA<DatabaseException>()),
      );

      // TESTE 10: Confirmar que somente duas
      // movimentações foram gravadas.
      final registros = await db.query('movimentacao');

      expect(registros.length, 2);

      // TESTE 11: Verificar integridade referencial.
      final integridade = await db.rawQuery(
        'PRAGMA foreign_key_check;',
      );

      expect(integridade, isEmpty);
    } finally {
      // Fecha e remove o banco temporário.
      await db.close();
      await deleteDatabase(caminho);
    }
  });

  
  testWidgets('Testa transacoes e rollback de movimentacoes',
      (tester) async {
    final pasta = await getDatabasesPath();

    final caminho = join(
      pasta,
      'teste_movimentacao_transacao.db',
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
      final repository = MovimentacaoRepository(banco: db);

      // Cria uma categoria de despesa.
      final categoriaId = await db.insert(
        'categoria',
        {
          'nome': 'Moradia',
          'tipo': 'DESPESA',
          'status': 'ATIVA',
        },
      );

      // Função auxiliar para criar lançamentos.
      Future<int> criarLancamento(
        String descricao,
        String status,
      ) async {
        return db.insert(
          'lancamento',
          {
            'tipo': 'DESPESA',
            'descricao': descricao,
            'valor_previsto': 18590,
            'data_prevista': '2026-11-10',
            'categoria_id': categoriaId,
            'status': status,
            'origem': 'MANUAL',
          },
        );
      }

      // Função auxiliar para consultar status.
      Future<String> consultarStatus(int id) async {
        final registros = await db.query(
          'lancamento',
          columns: ['status'],
          where: 'id = ?',
          whereArgs: [id],
          limit: 1,
        );

        return registros.first['status'] as String;
      }

      // TESTE 1: Criar lançamento pendente.
      final pendenteId = await criarLancamento(
        'Conta de energia',
        'PENDENTE',
      );

      // TESTE 2: Inserir e efetivar na mesma transação.
      final movimentacao = await repository.inserirEEfetivar(
        MovimentacaoModel(
          lancamentoId: pendenteId,
          valor: 18590,
          dataMovimentacao: '2026-11-09',
          forma: 'PIX',
        ),
      );

      expect(movimentacao.id, isNotNull);
      expect(movimentacao.lancamentoId, pendenteId);
      expect(movimentacao.valor, 18590);

      // Confirma os dois registros no SQLite.
      final salva = await repository.buscarPorLancamentoId(
        pendenteId,
      );

      expect(salva, isNotNull);
      expect(salva!.id, movimentacao.id);
      expect(await consultarStatus(pendenteId), 'EFETIVADO');

      // TESTE 3: Impedir pagamento duplicado.
      await expectLater(
        repository.inserirEEfetivar(
          MovimentacaoModel(
            lancamentoId: pendenteId,
            valor: 18590,
            dataMovimentacao: '2026-11-10',
            forma: 'DINHEIRO',
          ),
        ),
        throwsA(isA<DatabaseException>()),
      );

      expect(await consultarStatus(pendenteId), 'EFETIVADO');

      final aposDuplicidade =
          await repository.buscarPorLancamentoId(pendenteId);

      expect(aposDuplicidade!.id, movimentacao.id);

      // TESTE 4: Criar lançamento cancelado.
      final canceladoId = await criarLancamento(
        'Conta cancelada',
        'CANCELADO',
      );

      // TESTE 5: Tentar pagar lançamento cancelado.
      await expectLater(
        repository.inserirEEfetivar(
          MovimentacaoModel(
            lancamentoId: canceladoId,
            valor: 18590,
            dataMovimentacao: '2026-11-09',
            forma: 'PIX',
          ),
        ),
        throwsA(isA<StateError>()),
      );

      // A inserção deve ter sido desfeita.
      expect(
        await repository.buscarPorLancamentoId(canceladoId),
        isNull,
      );

      expect(await consultarStatus(canceladoId), 'CANCELADO');

      // TESTE 6: Criar lançamento já efetivado,
      // mas sem movimentação (somente simulação).
      final efetivadoId = await criarLancamento(
        'Conta já efetivada',
        'EFETIVADO',
      );

      // TESTE 7: Tentar pagar lançamento efetivado.
      await expectLater(
        repository.inserirEEfetivar(
          MovimentacaoModel(
            lancamentoId: efetivadoId,
            valor: 18590,
            dataMovimentacao: '2026-11-09',
            forma: 'PIX',
          ),
        ),
        throwsA(isA<StateError>()),
      );

      // Confirma que o rollback removeu a inserção.
      expect(
        await repository.buscarPorLancamentoId(efetivadoId),
        isNull,
      );

      expect(await consultarStatus(efetivadoId), 'EFETIVADO');

      // TESTE 8: Tentar movimentar lançamento inexistente.
      await expectLater(
        repository.inserirEEfetivar(
          MovimentacaoModel(
            lancamentoId: 999999,
            valor: 18590,
            dataMovimentacao: '2026-11-09',
            forma: 'PIX',
          ),
        ),
        throwsA(isA<DatabaseException>()),
      );

      // TESTE 9: Conferir quantidade final de movimentações.
      final registros = await db.query('movimentacao');

      expect(registros.length, 1);
      expect(registros.first['lancamento_id'], pendenteId);

      // TESTE 10: Verificar integridade referencial.
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
