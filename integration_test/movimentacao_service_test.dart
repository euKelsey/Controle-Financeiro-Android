
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'package:controle_financeiro_android/repositories/lancamento_repository.dart';
import 'package:controle_financeiro_android/repositories/movimentacao_repository.dart';
import 'package:controle_financeiro_android/services/movimentacao_service.dart';
import 'package:controle_financeiro_android/models/movimentacao_model.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Valida pagamentos e recebimentos no MovimentacaoService',
      (tester) async {
    final pasta = await getDatabasesPath();

    final caminho = join(
      pasta,
      'teste_movimentacao_service.db',
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

      final lancamentoRepository = LancamentoRepository(
        banco: db,
      );

      final service = MovimentacaoService(
        repository,
        lancamentoRepository: lancamentoRepository,
      );

      // TESTE 1: Criar categorias.
      final categoriaDespesaId = await db.insert(
        'categoria',
        {
          'nome': 'Moradia',
          'tipo': 'DESPESA',
          'status': 'ATIVA',
        },
      );

      final categoriaReceitaId = await db.insert(
        'categoria',
        {
          'nome': 'Trabalho',
          'tipo': 'RECEITA',
          'status': 'ATIVA',
        },
      );

      // Função auxiliar para criar lançamentos.
      Future<int> criarLancamento({
        required String tipo,
        required String descricao,
        required int valor,
        required int categoriaId,
        String status = 'PENDENTE',
      }) {
        return db.insert(
          'lancamento',
          {
            'tipo': tipo,
            'descricao': descricao,
            'valor_previsto': valor,
            'data_prevista': '2026-11-10',
            'categoria_id': categoriaId,
            'status': status,
            'origem': 'MANUAL',
          },
        );
      }

      // TESTE 2: Criar despesa pendente.
      final despesaId = await criarLancamento(
        tipo: 'DESPESA',
        descricao: 'Conta de energia',
        valor: 18590,
        categoriaId: categoriaDespesaId,
      );

      // TESTE 3: Registrar pagamento válido.
      final pagamento = await service.cadastrarMovimentacao(
        lancamentoId: despesaId,
        valor: 18590,
        dataMovimentacao: '2026-11-09',
        forma: ' pix ',
      );

      expect(pagamento.id, isNotNull);
      expect(pagamento.valor, 18590);
      expect(pagamento.forma, 'PIX');

      // Confirma mudança de status no SQLite.
      final despesaEfetivada =
          await lancamentoRepository.buscarPorId(despesaId);

      expect(despesaEfetivada!.status, 'EFETIVADO');

      // TESTE 4: Criar receita pendente.
      final receitaId = await criarLancamento(
        tipo: 'RECEITA',
        descricao: 'Salário',
        valor: 350000,
        categoriaId: categoriaReceitaId,
      );

      // TESTE 5: Registrar recebimento válido.
      final recebimento = await service.cadastrarMovimentacao(
        lancamentoId: receitaId,
        valor: 350000,
        dataMovimentacao: '2026-11-05',
        forma: 'TRANSFERENCIA',
      );

      expect(recebimento.id, isNotNull);
      expect(recebimento.valor, 350000);

      final receitaEfetivada =
          await lancamentoRepository.buscarPorId(receitaId);

      expect(receitaEfetivada!.status, 'EFETIVADO');

      // TESTE 6: Criar outra despesa para validações.
      final validacaoId = await criarLancamento(
        tipo: 'DESPESA',
        descricao: 'Conta de internet',
        valor: 12000,
        categoriaId: categoriaDespesaId,
      );

      // TESTE 7: Rejeitar valor diferente do previsto.
      await expectLater(
        service.cadastrarMovimentacao(
          lancamentoId: validacaoId,
          valor: 10000,
          dataMovimentacao: '2026-11-10',
          forma: 'PIX',
        ),
        throwsA(isA<ArgumentError>()),
      );

      // TESTE 8: Rejeitar valor zero.
      await expectLater(
        service.cadastrarMovimentacao(
          lancamentoId: validacaoId,
          valor: 0,
          dataMovimentacao: '2026-11-10',
          forma: 'PIX',
        ),
        throwsA(isA<ArgumentError>()),
      );

      // TESTE 9: Rejeitar valor negativo.
      await expectLater(
        service.cadastrarMovimentacao(
          lancamentoId: validacaoId,
          valor: -100,
          dataMovimentacao: '2026-11-10',
          forma: 'PIX',
        ),
        throwsA(isA<ArgumentError>()),
      );

      // TESTE 10: Rejeitar forma inválida.
      await expectLater(
        service.cadastrarMovimentacao(
          lancamentoId: validacaoId,
          valor: 12000,
          dataMovimentacao: '2026-11-10',
          forma: 'CARTAO_CREDITO',
        ),
        throwsA(isA<ArgumentError>()),
      );

      // TESTE 11: Rejeitar data inválida.
      await expectLater(
        service.cadastrarMovimentacao(
          lancamentoId: validacaoId,
          valor: 12000,
          dataMovimentacao: '2026-02-30',
          forma: 'PIX',
        ),
        throwsA(isA<ArgumentError>()),
      );

      // TESTE 12: Rejeitar lançamento inexistente.
      await expectLater(
        service.cadastrarMovimentacao(
          lancamentoId: 999999,
          valor: 12000,
          dataMovimentacao: '2026-11-10',
          forma: 'PIX',
        ),
        throwsA(isA<ArgumentError>()),
      );

      // TESTE 13: Criar lançamento cancelado.
      final canceladoId = await criarLancamento(
        tipo: 'DESPESA',
        descricao: 'Despesa cancelada',
        valor: 12000,
        categoriaId: categoriaDespesaId,
        status: 'CANCELADO',
      );

      // TESTE 14: Impedir movimentação de cancelado.
      await expectLater(
        service.cadastrarMovimentacao(
          lancamentoId: canceladoId,
          valor: 12000,
          dataMovimentacao: '2026-11-10',
          forma: 'PIX',
        ),
        throwsA(isA<ArgumentError>()),
      );

      // TESTE 15: Impedir segunda movimentação.
      await expectLater(
        service.cadastrarMovimentacao(
          lancamentoId: despesaId,
          valor: 18590,
          dataMovimentacao: '2026-11-10',
          forma: 'DINHEIRO',
        ),
        throwsA(isA<ArgumentError>()),
      );

      // TESTE 16: Criar cartão.
      final cartaoId = await db.insert(
        'cartao',
        {
          'nome': 'Cartão Teste',
          'instituicao': 'Banco Teste',
          'limite_total': 500000,
          'dia_fechamento': 2,
          'dia_vencimento': 10,
        },
      );

      // TESTE 17: Criar fatura fechada.
      final faturaId = await db.insert(
        'fatura',
        {
          'cartao_id': cartaoId,
          'mes_referencia': '2026-11',
          'data_fechamento': '2026-11-02',
          'data_vencimento': '2026-11-10',
          'status': 'FECHADA',
        },
      );

      // TESTE 18: Criar lançamento de fatura.
      final lancamentoFaturaId = await db.insert(
        'lancamento',
        {
          'tipo': 'DESPESA',
          'descricao': 'Fatura Cartão Teste',
          'valor_previsto': 85000,
          'data_prevista': '2026-11-10',
          'categoria_id': null,
          'fatura_id': faturaId,
          'status': 'PENDENTE',
          'origem': 'FATURA',
        },
      );

      // TESTE 19: Impedir pagamento pelo fluxo comum.
      await expectLater(
        service.cadastrarMovimentacao(
          lancamentoId: lancamentoFaturaId,
          valor: 85000,
          dataMovimentacao: '2026-11-10',
          forma: 'PIX',
        ),
        throwsA(isA<ArgumentError>()),
      );

      // TESTE 20: Confirmar somente duas movimentações.
      final movimentacoes = await repository.listar();

      expect(movimentacoes.length, 2);

      // TESTE 21: Lançamento com erro continua pendente.
      final naoEfetivado =
          await lancamentoRepository.buscarPorId(validacaoId);

      expect(naoEfetivado!.status, 'PENDENTE');

      // TESTE 22: Confirmar integridade referencial.
      final integridade = await db.rawQuery(
        'PRAGMA foreign_key_check;',
      );

      expect(integridade, isEmpty);
    } finally {
      await db.close();
      await deleteDatabase(caminho);
    }
  });

  
  testWidgets('Valida atualizacao de movimentacoes', (tester) async {
    final pasta = await getDatabasesPath();

    final caminho = join(
      pasta,
      'teste_movimentacao_service_edicao.db',
    );

    // Banco temporário exclusivo deste teste.
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
      final lancamentoRepository = LancamentoRepository(
        banco: db,
      );

      final service = MovimentacaoService(
        repository,
        lancamentoRepository: lancamentoRepository,
      );

      // TESTE 1: Criar categoria.
      final categoriaId = await db.insert(
        'categoria',
        {
          'nome': 'Moradia',
          'tipo': 'DESPESA',
          'status': 'ATIVA',
        },
      );

      // TESTE 2: Criar lançamento pendente.
      final lancamentoId = await db.insert(
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

      // TESTE 3: Registrar pagamento.
      final pagamento = await service.cadastrarMovimentacao(
        lancamentoId: lancamentoId,
        valor: 18590,
        dataMovimentacao: '2026-11-09',
        forma: 'PIX',
        observacao: 'Pagamento inicial',
      );

      final movimentacaoId = pagamento.id!;

      // TESTE 4: Buscar por ID.
      final encontrado = await service.buscarMovimentacaoPorId(
        movimentacaoId,
      );

      expect(encontrado.lancamentoId, lancamentoId);
      expect(encontrado.valor, 18590);
      expect(encontrado.forma, 'PIX');

      // TESTE 5: Atualizar data, forma e observação.
      final atualizado = await service.atualizarMovimentacao(
        movimentacaoId: movimentacaoId,
        valor: 18590,
        dataMovimentacao: '2026-11-10',
        forma: ' boleto ',
        observacao: 'Data corrigida',
      );

      expect(atualizado.id, movimentacaoId);
      expect(atualizado.lancamentoId, lancamentoId);
      expect(atualizado.valor, 18590);
      expect(atualizado.dataMovimentacao, '2026-11-10');
      expect(atualizado.forma, 'BOLETO');
      expect(atualizado.observacao, 'Data corrigida');

      // TESTE 6: Confirmar persistência no SQLite.
      final salvo = await service.buscarMovimentacaoPorId(
        movimentacaoId,
      );

      expect(salvo.forma, 'BOLETO');
      expect(salvo.dataMovimentacao, '2026-11-10');
      expect(salvo.observacao, 'Data corrigida');

      // TESTE 7: Rejeitar valor diferente do previsto.
      await expectLater(
        service.atualizarMovimentacao(
          movimentacaoId: movimentacaoId,
          valor: 10000,
          dataMovimentacao: '2026-11-10',
          forma: 'PIX',
        ),
        throwsA(isA<ArgumentError>()),
      );

      // TESTE 8: Rejeitar valor zero ou negativo.
      for (final valorInvalido in [0, -100]) {
        await expectLater(
          service.atualizarMovimentacao(
            movimentacaoId: movimentacaoId,
            valor: valorInvalido,
            dataMovimentacao: '2026-11-10',
            forma: 'PIX',
          ),
          throwsA(isA<ArgumentError>()),
        );
      }

      // TESTE 9: Rejeitar forma inválida.
      await expectLater(
        service.atualizarMovimentacao(
          movimentacaoId: movimentacaoId,
          valor: 18590,
          dataMovimentacao: '2026-11-10',
          forma: 'CREDITO',
        ),
        throwsA(isA<ArgumentError>()),
      );

      // TESTE 10: Rejeitar data inválida.
      await expectLater(
        service.atualizarMovimentacao(
          movimentacaoId: movimentacaoId,
          valor: 18590,
          dataMovimentacao: '2026-02-30',
          forma: 'PIX',
        ),
        throwsA(isA<ArgumentError>()),
      );

      // TESTE 11: Rejeitar movimentação inexistente.
      await expectLater(
        service.buscarMovimentacaoPorId(999999),
        throwsA(isA<ArgumentError>()),
      );

      await expectLater(
        service.atualizarMovimentacao(
          movimentacaoId: 999999,
          valor: 18590,
          dataMovimentacao: '2026-11-10',
          forma: 'PIX',
        ),
        throwsA(isA<ArgumentError>()),
      );

      // TESTE 12: Confirmar status do lançamento.
      final lancamento = await lancamentoRepository.buscarPorId(
        lancamentoId,
      );

      expect(lancamento!.status, 'EFETIVADO');

      // TESTE 13: Criar cartão e fatura de demonstração.
      final cartaoId = await db.insert(
        'cartao',
        {
          'nome': 'Cartão Teste',
          'instituicao': 'Banco Teste',
          'limite_total': 500000,
          'dia_fechamento': 2,
          'dia_vencimento': 10,
        },
      );

      final faturaId = await db.insert(
        'fatura',
        {
          'cartao_id': cartaoId,
          'mes_referencia': '2026-11',
          'data_fechamento': '2026-11-02',
          'data_vencimento': '2026-11-10',
          'status': 'FECHADA',
        },
      );

      final lancamentoFaturaId = await db.insert(
        'lancamento',
        {
          'tipo': 'DESPESA',
          'descricao': 'Fatura Cartão Teste',
          'valor_previsto': 85000,
          'data_prevista': '2026-11-10',
          'categoria_id': null,
          'fatura_id': faturaId,
          'status': 'PENDENTE',
          'origem': 'FATURA',
        },
      );

      // TESTE 14: Criar movimentação de fatura diretamente
      // pelo Repository, somente para preparar o teste.
      final pagamentoFatura = await repository.inserirEEfetivar(
        MovimentacaoModel(
          lancamentoId: lancamentoFaturaId,
          valor: 85000,
          dataMovimentacao: '2026-11-10',
          forma: 'PIX',
        ),
      );

      // TESTE 15: Bloquear edição de pagamento de fatura.
      await expectLater(
        service.atualizarMovimentacao(
          movimentacaoId: pagamentoFatura.id!,
          valor: 85000,
          dataMovimentacao: '2026-11-11',
          forma: 'BOLETO',
        ),
        throwsA(isA<ArgumentError>()),
      );

      // TESTE 16: Confirmar preservação dos dados.
      final preservado = await service.buscarMovimentacaoPorId(
        movimentacaoId,
      );

      expect(preservado.valor, 18590);
      expect(preservado.forma, 'BOLETO');
      expect(preservado.dataMovimentacao, '2026-11-10');
      expect(preservado.lancamentoId, lancamentoId);

      final faturaPreservada =
          await service.buscarMovimentacaoPorId(
        pagamentoFatura.id!,
      );

      expect(faturaPreservada.valor, 85000);
      expect(faturaPreservada.forma, 'PIX');
      expect(faturaPreservada.dataMovimentacao, '2026-11-10');

      // TESTE 17: Listar movimentações.
      final movimentacoes = await service.listarMovimentacoes();

      expect(movimentacoes.length, 2);

      // TESTE 18: Verificar integridade referencial.
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
