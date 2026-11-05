import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'package:controle_financeiro_android/models/fatura_model.dart';
import 'package:controle_financeiro_android/repositories/fatura_repository.dart';
import 'package:controle_financeiro_android/services/fatura_service.dart';
import 'package:controle_financeiro_android/repositories/lancamento_repository.dart';
import 'package:controle_financeiro_android/repositories/movimentacao_repository.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Valida consultas e processamento no FaturaService', (
    tester,
  ) async {
    final pasta = await getDatabasesPath();

    final caminho = join(pasta, 'teste_fatura_service.db');

    // Banco temporário exclusivo deste teste.
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
      final repository = FaturaRepository(banco: db);
      final service = FaturaService(repository);

      // TESTE 1: Criar cartão.
      final cartaoId = await db.insert('cartao', {
        'nome': 'Cartão Principal',
        'instituicao': 'Banco Teste',
        'limite_total': 500000,
        'dia_fechamento': 10,
        'dia_vencimento': 20,
        'status': 'ATIVO',
      });

      // TESTE 2: Criar categoria de despesa.
      final categoriaId = await db.insert('categoria', {
        'nome': 'Compras',
        'tipo': 'DESPESA',
        'status': 'ATIVA',
      });

      // Função auxiliar para criar faturas.
      Future<int> criarFatura({
        required String mes,
        required String fechamento,
        required String vencimento,
        String status = 'ABERTA',
      }) async {
        final fatura = await repository.inserir(
          FaturaModel(
            cartaoId: cartaoId,
            mesReferencia: mes,
            dataFechamento: fechamento,
            dataVencimento: vencimento,
            status: status,
          ),
        );

        return fatura.id!;
      }

      // Função auxiliar para cadastrar compras de teste.
      Future<void> adicionarCompra({
        required int faturaId,
        required String descricao,
        required int valor,
        String status = 'ATIVA',
      }) async {
        final compraId = await db.insert('compra_cartao', {
          'cartao_id': cartaoId,
          'categoria_id': categoriaId,
          'descricao': descricao,
          'data_compra': '2027-01-05',
          'valor_total': valor,
          'quantidade_parcelas': 1,
          'status': status,
        });

        await db.insert('parcela_cartao', {
          'compra_cartao_id': compraId,
          'fatura_id': faturaId,
          'numero_parcela': 1,
          'valor': valor,
          'data_prevista': '2027-01-20',
        });
      }

      // TESTE 3: Criar fatura principal.
      final principalId = await criarFatura(
        mes: '2027-01',
        fechamento: '2027-01-10',
        vencimento: '2027-01-20',
      );

      // TESTE 4: Adicionar compras à fatura.
      await adicionarCompra(
        faturaId: principalId,
        descricao: 'Supermercado',
        valor: 25990,
      );

      await adicionarCompra(
        faturaId: principalId,
        descricao: 'Farmácia',
        valor: 8500,
      );

      // Compra cancelada não entra no total.
      await adicionarCompra(
        faturaId: principalId,
        descricao: 'Restaurante',
        valor: 12050,
        status: 'CANCELADA',
      );

      // TESTE 5: Criar fatura futura.
      final futuraId = await criarFatura(
        mes: '2027-02',
        fechamento: '2027-02-10',
        vencimento: '2027-02-20',
      );

      // TESTE 6: Criar fatura zerada.
      final zeradaId = await criarFatura(
        mes: '2026-12',
        fechamento: '2026-12-10',
        vencimento: '2026-12-20',
      );

      // TESTE 7: Listar faturas.
      final faturas = await service.listarFaturas();

      expect(faturas.length, 3);
      expect(faturas[0].id, zeradaId);
      expect(faturas[1].id, principalId);
      expect(faturas[2].id, futuraId);

      // TESTE 8: Buscar fatura por ID.
      final encontrada = await service.buscarFaturaPorId(principalId);

      expect(encontrada.cartaoId, cartaoId);
      expect(encontrada.mesReferencia, '2027-01');
      expect(encontrada.status, 'ABERTA');

      // TESTE 9: Rejeitar ID inexistente.
      await expectLater(
        service.buscarFaturaPorId(999999),
        throwsA(isA<ArgumentError>()),
      );

      // TESTE 10: Rejeitar ID inválido.
      await expectLater(
        service.buscarFaturaPorId(0),
        throwsA(isA<ArgumentError>()),
      );

      await expectLater(
        service.buscarFaturaPorId(-1),
        throwsA(isA<ArgumentError>()),
      );

      // TESTE 11: Calcular total da fatura.
      final total = await service.obterTotalFatura(principalId);

      expect(total, 34490);

      // TESTE 12: Fatura sem compras retorna zero.
      final totalZerada = await service.obterTotalFatura(zeradaId);

      expect(totalZerada, 0);

      // TESTE 13: Impedir total de fatura inexistente.
      await expectLater(
        service.obterTotalFatura(999999),
        throwsA(isA<ArgumentError>()),
      );

      // TESTE 14: Processar fechamento.
      final resultado = await service.atualizarFaturasAutomaticamente(
        dataReferencia: '2027-01-15',
      );

      expect(resultado.faturasFechadas, 2);
      expect(resultado.lancamentosGerados, 1);

      // TESTE 15: Confirmar fatura principal fechada.
      final principalFechada = await service.buscarFaturaPorId(principalId);

      expect(principalFechada.status, 'FECHADA');

      // TESTE 16: Confirmar fatura zerada fechada.
      final zeradaFechada = await service.buscarFaturaPorId(zeradaId);

      expect(zeradaFechada.status, 'FECHADA');

      // TESTE 17: Fatura futura continua aberta.
      final futura = await service.buscarFaturaPorId(futuraId);

      expect(futura.status, 'ABERTA');

      // TESTE 18: Conferir lançamento financeiro.
      final lancamentos = await db.query(
        'lancamento',
        where: 'fatura_id = ?',
        whereArgs: [principalId],
      );

      expect(lancamentos.length, 1);

      final lancamento = lancamentos.first;

      expect(lancamento['tipo'], 'DESPESA');
      expect(lancamento['origem'], 'FATURA');
      expect(lancamento['status'], 'PENDENTE');
      expect(lancamento['valor_previsto'], 34490);
      expect(lancamento['data_prevista'], '2027-01-20');
      expect(lancamento['categoria_id'], isNull);

      // TESTE 19: Fatura zerada não gera lançamento.
      final lancamentosZerada = await db.query(
        'lancamento',
        where: 'fatura_id = ?',
        whereArgs: [zeradaId],
      );

      expect(lancamentosZerada, isEmpty);

      // TESTE 20: Reprocessar sem duplicar lançamentos.
      final segundaExecucao = await service.atualizarFaturasAutomaticamente(
        dataReferencia: '2027-01-15',
      );

      expect(segundaExecucao.faturasFechadas, 0);
      expect(segundaExecucao.lancamentosGerados, 0);

      final lancamentosFinais = await db.query('lancamento');

      expect(lancamentosFinais.length, 1);

      // TESTE 21: Rejeitar data de referência inválida.
      await expectLater(
        service.atualizarFaturasAutomaticamente(dataReferencia: '2027-02-30'),
        throwsA(isA<ArgumentError>()),
      );

      await expectLater(
        service.atualizarFaturasAutomaticamente(dataReferencia: '15/01/2027'),
        throwsA(isA<ArgumentError>()),
      );

      // TESTE 22: Conferir integridade referencial.
      final integridade = await db.rawQuery('PRAGMA foreign_key_check;');

      expect(integridade, isEmpty);
    } finally {
      await db.close();
      await deleteDatabase(caminho);
    }
  });

  testWidgets('Valida pagamento integral de faturas', (tester) async {
    final pasta = await getDatabasesPath();

    final caminho = join(pasta, 'teste_fatura_pagamento.db');

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
      // TESTE 1: Configurar os Repositories.
      final faturaRepository = FaturaRepository(banco: db);

      final lancamentoRepository = LancamentoRepository(banco: db);

      final movimentacaoRepository = MovimentacaoRepository(banco: db);

      final service = FaturaService(
        faturaRepository,
        lancamentoRepository: lancamentoRepository,
        movimentacaoRepository: movimentacaoRepository,
      );

      // TESTE 2: Criar cartão de demonstração.
      final cartaoId = await db.insert('cartao', {
        'nome': 'Cartão Principal',
        'instituicao': 'Banco Teste',
        'limite_total': 500000,
        'dia_fechamento': 10,
        'dia_vencimento': 20,
        'status': 'ATIVO',
      });

      final categoriaId = await db.insert('categoria', {
        'nome': 'Compras do teste de pagamento',
        'tipo': 'DESPESA',
        'status': 'ATIVA',
      });

      // Função auxiliar para criar faturas.
      Future<int> criarFatura({
        required String mes,
        required String fechamento,
        required String vencimento,
        required String status,
      }) async {
        final fatura = await faturaRepository.inserir(
          FaturaModel(
            cartaoId: cartaoId,
            mesReferencia: mes,
            dataFechamento: fechamento,
            dataVencimento: vencimento,
            status: status,
          ),
        );

        return fatura.id!;
      }

      // Função auxiliar para criar o lançamento
      // financeiro de uma fatura.
      Future<int> criarLancamentoFatura({
        required int faturaId,
        required int valor,
        required String vencimento,
      }) async {
        return db.insert('lancamento', {
          'tipo': 'DESPESA',
          'descricao': 'Fatura de teste',
          'valor_previsto': valor,
          'data_prevista': vencimento,
          'categoria_id': null,
          'fatura_id': faturaId,
          'status': 'PENDENTE',
          'origem': 'FATURA',
        });
      }

      // Cria uma compra 1x e sua parcela vinculada
      // à fatura utilizada no teste.
      Future<void> criarCompraDaFatura({
        required int faturaId,
        required int valor,
        required String descricao,
        required String dataPrevista,
      }) async {
        final compraId = await db.insert('compra_cartao', {
          'cartao_id': cartaoId,
          'categoria_id': categoriaId,
          'descricao': descricao,
          'data_compra': '2027-01-05',
          'valor_total': valor,
          'quantidade_parcelas': 1,
          'status': 'ATIVA',
        });

        await db.insert('parcela_cartao', {
          'compra_cartao_id': compraId,
          'fatura_id': faturaId,
          'numero_parcela': 1,
          'valor': valor,
          'data_prevista': dataPrevista,
        });
      }

      // TESTE 3: Criar fatura fechada.
      final faturaId = await criarFatura(
        mes: '2027-01',
        fechamento: '2027-01-10',
        vencimento: '2027-01-20',
        status: 'FECHADA',
      );

      // TESTE 4: Criar lançamento pendente.
      final lancamentoId = await criarLancamentoFatura(
        faturaId: faturaId,
        valor: 34490,
        vencimento: '2027-01-20',
      );

      await criarCompraDaFatura(
        faturaId: faturaId,
        valor: 34490,
        descricao: 'Compra de teste - janeiro',
        dataPrevista: '2027-01-20',
      );

      // TESTE 5: Registrar pagamento integral.
      final pagamento = await service.pagarFatura(
        faturaId: faturaId,
        dataPagamento: '2027-01-18',
        forma: ' pix ',
        observacao: 'Pagamento integral da fatura',
      );

      expect(pagamento.id, isNotNull);
      expect(pagamento.lancamentoId, lancamentoId);
      expect(pagamento.valor, 34490);
      expect(pagamento.forma, 'PIX');
      expect(pagamento.dataMovimentacao, '2027-01-18');
      expect(pagamento.observacao, 'Pagamento integral da fatura');

      // TESTE 6: Confirmar movimentação no SQLite.
      final movimentacoes = await db.query(
        'movimentacao',
        where: 'lancamento_id = ?',
        whereArgs: [lancamentoId],
      );

      expect(movimentacoes.length, 1);
      expect(movimentacoes.first['valor'], 34490);
      expect(movimentacoes.first['forma'], 'PIX');

      // TESTE 7: Confirmar lançamento efetivado.
      final lancamentoPago = await lancamentoRepository.buscarPorId(
        lancamentoId,
      );

      expect(lancamentoPago!.status, 'EFETIVADO');

      // TESTE 8: Fatura continua fechada.
      final faturaPaga = await service.buscarFaturaPorId(faturaId);

      expect(faturaPaga.status, 'FECHADA');

      // TESTE 9: Bloquear pagamento duplicado.
      await expectLater(
        service.pagarFatura(
          faturaId: faturaId,
          dataPagamento: '2027-01-19',
          forma: 'BOLETO',
        ),
        throwsA(isA<ArgumentError>()),
      );

      // TESTE 10: Criar fatura aberta.
      final faturaAbertaId = await criarFatura(
        mes: '2027-02',
        fechamento: '2027-02-10',
        vencimento: '2027-02-20',
        status: 'ABERTA',
      );

      // Cria um lançamento apenas para testar
      // a proteção de pagamento de fatura aberta.
      await criarLancamentoFatura(
        faturaId: faturaAbertaId,
        valor: 20000,
        vencimento: '2027-02-20',
      );

      // TESTE 11: Bloquear pagamento de fatura aberta.
      await expectLater(
        service.pagarFatura(
          faturaId: faturaAbertaId,
          dataPagamento: '2027-02-15',
          forma: 'PIX',
        ),
        throwsA(isA<ArgumentError>()),
      );

      // TESTE 12: Bloquear fatura inexistente.
      await expectLater(
        service.pagarFatura(
          faturaId: 999999,
          dataPagamento: '2027-01-18',
          forma: 'PIX',
        ),
        throwsA(isA<ArgumentError>()),
      );

      // TESTE 13: Bloquear ID inválido.
      await expectLater(
        service.pagarFatura(
          faturaId: 0,
          dataPagamento: '2027-01-18',
          forma: 'PIX',
        ),
        throwsA(isA<ArgumentError>()),
      );

      // TESTE 14: Criar fatura fechada sem lançamento.
      final semLancamentoId = await criarFatura(
        mes: '2027-03',
        fechamento: '2027-03-10',
        vencimento: '2027-03-20',
        status: 'FECHADA',
      );

      // TESTE 15: Bloquear pagamento sem lançamento.
      await expectLater(
        service.pagarFatura(
          faturaId: semLancamentoId,
          dataPagamento: '2027-03-15',
          forma: 'PIX',
        ),
        throwsA(isA<ArgumentError>()),
      );

      // TESTE 16: Preparar fatura para validações.
      final faturaValidacaoId = await criarFatura(
        mes: '2027-04',
        fechamento: '2027-04-10',
        vencimento: '2027-04-20',
        status: 'FECHADA',
      );

      final lancamentoValidacaoId = await criarLancamentoFatura(
        faturaId: faturaValidacaoId,
        valor: 18590,
        vencimento: '2027-04-20',
      );

      await criarCompraDaFatura(
        faturaId: faturaValidacaoId,
        valor: 18590,
        descricao: 'Compra de teste - abril',
        dataPrevista: '2027-04-20',
      );

      // TESTE 17: Rejeitar data em formato incorreto.
      await expectLater(
        service.pagarFatura(
          faturaId: faturaValidacaoId,
          dataPagamento: '15/04/2027',
          forma: 'PIX',
        ),
        throwsA(isA<ArgumentError>()),
      );

      // TESTE 18: Rejeitar data inexistente.
      await expectLater(
        service.pagarFatura(
          faturaId: faturaValidacaoId,
          dataPagamento: '2027-02-30',
          forma: 'PIX',
        ),
        throwsA(isA<ArgumentError>()),
      );

      // TESTE 19: Rejeitar forma inválida.
      await expectLater(
        service.pagarFatura(
          faturaId: faturaValidacaoId,
          dataPagamento: '2027-04-15',
          forma: 'CREDITO',
        ),
        throwsA(isA<ArgumentError>()),
      );

      // TESTE 20: Confirmar que erros não geraram
      // movimentação nem efetivaram o lançamento.
      final movimentacaoValidacao = await movimentacaoRepository
          .buscarPorLancamentoId(lancamentoValidacaoId);

      expect(movimentacaoValidacao, isNull);

      final lancamentoValidacao = await lancamentoRepository.buscarPorId(
        lancamentoValidacaoId,
      );

      expect(lancamentoValidacao!.status, 'PENDENTE');

      // TESTE 21: Simular falha na efetivação.
      // O trigger impede a atualização do lançamento.
      await db.execute('''
        CREATE TRIGGER bloquear_pagamento_fatura_teste
        BEFORE UPDATE OF status ON lancamento
        WHEN OLD.id = $lancamentoValidacaoId
          AND NEW.status = 'EFETIVADO'
        BEGIN
          SELECT RAISE(
            ABORT,
            'Falha simulada na efetivação'
          );
        END;
      ''');

      await expectLater(
        service.pagarFatura(
          faturaId: faturaValidacaoId,
          dataPagamento: '2027-04-15',
          forma: 'PIX',
        ),
        throwsA(isA<DatabaseException>()),
      );

      // TESTE 22: Confirmar rollback.
      final aposFalha = await movimentacaoRepository.buscarPorLancamentoId(
        lancamentoValidacaoId,
      );

      expect(aposFalha, isNull);

      final pendenteAposFalha = await lancamentoRepository.buscarPorId(
        lancamentoValidacaoId,
      );

      expect(pendenteAposFalha!.status, 'PENDENTE');

      // TESTE 23: Remover falha simulada.
      await db.execute('DROP TRIGGER bloquear_pagamento_fatura_teste');

      // TESTE 24: Registrar pagamento após a correção.
      final pagamentoRecuperado = await service.pagarFatura(
        faturaId: faturaValidacaoId,
        dataPagamento: '2027-04-15',
        forma: 'TRANSFERENCIA',
      );

      expect(pagamentoRecuperado.id, isNotNull);
      expect(pagamentoRecuperado.valor, 18590);
      expect(pagamentoRecuperado.forma, 'TRANSFERENCIA');

      final efetivado = await lancamentoRepository.buscarPorId(
        lancamentoValidacaoId,
      );

      expect(efetivado!.status, 'EFETIVADO');

      // TESTE 25: Conferir quantidade de pagamentos.
      final pagamentosFinais = await db.query('movimentacao');

      expect(pagamentosFinais.length, 2);

      // TESTE 26: Conferir integridade referencial.
      final integridade = await db.rawQuery('PRAGMA foreign_key_check;');

      expect(integridade, isEmpty);
    } finally {
      await db.close();
      await deleteDatabase(caminho);
    }
  });

  testWidgets('Valida seguranca do pagamento atomico', (tester) async {
    final pasta = await getDatabasesPath();

    final caminho = join(pasta, 'teste_pagamento_atomico.db');

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
      final repository = MovimentacaoRepository(banco: db);

      // TESTE 1: Criar cartão.
      final cartaoId = await db.insert('cartao', {
        'nome': 'Cartão Segurança',
        'instituicao': 'Banco Teste',
        'limite_total': 500000,
        'dia_fechamento': 10,
        'dia_vencimento': 20,
        'status': 'ATIVO',
      });

      final categoriaId = await db.insert('categoria', {
        'nome': 'Compras - Pagamento Atomico',
        'tipo': 'DESPESA',
        'status': 'ATIVA',
      });

      // Auxiliar para criar faturas de teste.
      Future<int> criarFatura(String mes, {String status = 'FECHADA'}) {
        return db.insert('fatura', {
          'cartao_id': cartaoId,
          'mes_referencia': mes,
          'data_fechamento': '$mes-10',
          'data_vencimento': '$mes-20',
          'status': status,
        });
      }

      // Auxiliar para criar lançamentos de fatura.
      Future<int> criarLancamento(
        int faturaId, {
        int valor = 18590,
        String status = 'PENDENTE',
      }) {
        return db.insert('lancamento', {
          'tipo': 'DESPESA',
          'descricao': 'Fatura de teste',
          'valor_previsto': valor,
          'data_prevista': '2027-01-20',
          'categoria_id': null,
          'fatura_id': faturaId,
          'status': status,
          'origem': 'FATURA',
        });
      }

      // Cria uma compra ativa com parcela unica,
      // vinculada a uma fatura de teste.
      Future<int> criarCompra({
        required int faturaId,
        required int valor,
        required String descricao,
      }) async {
        // ETAPA 1: Cadastrar a compra no cartao.
        final compraId = await db.insert('compra_cartao', {
          'cartao_id': cartaoId,
          'categoria_id': categoriaId,
          'descricao': descricao,
          'data_compra': '2027-01-05',
          'valor_total': valor,
          'quantidade_parcelas': 1,
          'status': 'ATIVA',
        });

        // ETAPA 2: Vincular a parcela a fatura.
        await db.insert('parcela_cartao', {
          'compra_cartao_id': compraId,
          'fatura_id': faturaId,
          'numero_parcela': 1,
          'valor': valor,
          'data_prevista': '2027-01-20',
        });

        return compraId;
      }

      // TESTE 2: Preparar fatura fechada.
      final faturaPagaId = await criarFatura('2027-01');

      final lancamentoPagoId = await criarLancamento(
        faturaPagaId,
        valor: 34490,
      );

      await criarCompra(
        faturaId: faturaPagaId,
        valor: 34490,
        descricao: 'Compra principal - janeiro',
      );

      // TESTE 3: Efetuar pagamento diretamente
      // pelo método transacional do Repository.
      final pagamento = await repository.pagarFaturaAtomicamente(
        faturaId: faturaPagaId,
        dataPagamento: '2027-01-18',
        forma: 'PIX',
      );

      expect(pagamento.id, isNotNull);
      expect(pagamento.lancamentoId, lancamentoPagoId);
      expect(pagamento.valor, 34490);

      final lancamentoPago = await db.query(
        'lancamento',
        where: 'id = ?',
        whereArgs: [lancamentoPagoId],
      );

      expect(lancamentoPago.first['status'], 'EFETIVADO');

      // TESTE 4: Impedir pagamento duplicado.
      await expectLater(
        repository.pagarFaturaAtomicamente(
          faturaId: faturaPagaId,
          dataPagamento: '2027-01-19',
          forma: 'PIX',
        ),
        throwsA(isA<StateError>()),
      );

      // TESTE 5: Preparar fatura aberta.
      final faturaAbertaId = await criarFatura('2027-02', status: 'ABERTA');

      await criarLancamento(faturaAbertaId);

      // TESTE 6: Bloquear pagamento de fatura aberta.
      await expectLater(
        repository.pagarFaturaAtomicamente(
          faturaId: faturaAbertaId,
          dataPagamento: '2027-02-15',
          forma: 'PIX',
        ),
        throwsA(isA<StateError>()),
      );

      // TESTE 7: Fatura fechada sem lançamento.
      final semLancamentoId = await criarFatura('2027-03');

      await expectLater(
        repository.pagarFaturaAtomicamente(
          faturaId: semLancamentoId,
          dataPagamento: '2027-03-15',
          forma: 'PIX',
        ),
        throwsA(isA<StateError>()),
      );

      // TESTE 8: Lançamento cancelado.
      final canceladaId = await criarFatura('2027-04');

      await criarLancamento(canceladaId, status: 'CANCELADO');

      await expectLater(
        repository.pagarFaturaAtomicamente(
          faturaId: canceladaId,
          dataPagamento: '2027-04-15',
          forma: 'PIX',
        ),
        throwsA(isA<StateError>()),
      );

      // TESTE 9: Preparar fatura para rollback.
      final rollbackId = await criarFatura('2027-05');

      final lancamentoRollbackId = await criarLancamento(
        rollbackId,
        valor: 25000,
      );

      await criarCompra(
        faturaId: rollbackId,
        valor: 25000,
        descricao: 'Compra para teste de rollback',
      );

      // Simula falha durante a efetivação.
      await db.execute('''
        CREATE TRIGGER falha_pagamento_atomico_teste
        BEFORE UPDATE OF status ON lancamento
        WHEN OLD.id = $lancamentoRollbackId
          AND NEW.status = 'EFETIVADO'
        BEGIN
          SELECT RAISE(
            ABORT,
            'Falha simulada no pagamento'
          );
        END;
      ''');

      // TESTE 10: Confirmar erro na transação.
      await expectLater(
        repository.pagarFaturaAtomicamente(
          faturaId: rollbackId,
          dataPagamento: '2027-05-15',
          forma: 'TRANSFERENCIA',
        ),
        throwsA(isA<DatabaseException>()),
      );

      // TESTE 11: Movimentação deve ser desfeita.
      final movimentacaoRollback = await db.query(
        'movimentacao',
        where: 'lancamento_id = ?',
        whereArgs: [lancamentoRollbackId],
      );

      expect(movimentacaoRollback, isEmpty);

      // TESTE 12: Lançamento permanece pendente.
      final lancamentoAposFalha = await db.query(
        'lancamento',
        where: 'id = ?',
        whereArgs: [lancamentoRollbackId],
      );

      expect(lancamentoAposFalha.first['status'], 'PENDENTE');

      // TESTE 13: Remover falha simulada.
      await db.execute('DROP TRIGGER falha_pagamento_atomico_teste');

      // TESTE 14: Repetir pagamento com sucesso.
      final recuperado = await repository.pagarFaturaAtomicamente(
        faturaId: rollbackId,
        dataPagamento: '2027-05-15',
        forma: 'TRANSFERENCIA',
      );

      expect(recuperado.id, isNotNull);
      expect(recuperado.valor, 25000);

      final lancamentoRecuperado = await db.query(
        'lancamento',
        where: 'id = ?',
        whereArgs: [lancamentoRollbackId],
      );

      expect(lancamentoRecuperado.first['status'], 'EFETIVADO');

      // TESTE ADICIONAL: Bloquear pagamento
      // com divergencia no total da fatura.
      final faturaDivergenteId = await criarFatura('2027-06');

      final lancamentoDivergenteId = await criarLancamento(
        faturaDivergenteId,
        valor: 30000,
      );

      // A compra possui valor diferente
      // do lancamento financeiro.
      final compraDivergenteId = await criarCompra(
        faturaId: faturaDivergenteId,
        valor: 20000,
        descricao: 'Compra com valor divergente',
      );

      // O pagamento deve ser bloqueado.
      await expectLater(
        repository.pagarFaturaAtomicamente(
          faturaId: faturaDivergenteId,
          dataPagamento: '2027-06-15',
          forma: 'PIX',
        ),
        throwsA(isA<StateError>()),
      );

      // Nenhuma movimentacao pode ter sido criada.
      final movimentacaoDivergente = await db.query(
        'movimentacao',
        where: 'lancamento_id = ?',
        whereArgs: [lancamentoDivergenteId],
      );

      expect(movimentacaoDivergente, isEmpty);

      // O lancamento deve permanecer pendente.
      final lancamentoDivergente = await db.query(
        'lancamento',
        where: 'id = ?',
        whereArgs: [lancamentoDivergenteId],
      );

      expect(lancamentoDivergente.first['status'], 'PENDENTE');

      // Cancela a compra de teste.
      await db.update(
        'compra_cartao',
        {'status': 'CANCELADA'},
        where: 'id = ?',
        whereArgs: [compraDivergenteId],
      );

      // Mesmo com total zerado, o pagamento
      // de R$ 300,00 deve continuar bloqueado.
      await expectLater(
        repository.pagarFaturaAtomicamente(
          faturaId: faturaDivergenteId,
          dataPagamento: '2027-06-15',
          forma: 'PIX',
        ),
        throwsA(isA<StateError>()),
      );

      // Restaura a compra e corrige o valor
      // apenas para simular recuperacao dos dados.
      await db.update(
        'compra_cartao',
        {'status': 'ATIVA', 'valor_total': 30000},
        where: 'id = ?',
        whereArgs: [compraDivergenteId],
      );

      await db.update(
        'parcela_cartao',
        {'valor': 30000},
        where: 'compra_cartao_id = ?',
        whereArgs: [compraDivergenteId],
      );

      // Agora os valores sao iguais.
      final pagamentoCorrigido = await repository.pagarFaturaAtomicamente(
        faturaId: faturaDivergenteId,
        dataPagamento: '2027-06-15',
        forma: 'PIX',
      );

      expect(pagamentoCorrigido.valor, 30000);

      final lancamentoCorrigido = await db.query(
        'lancamento',
        where: 'id = ?',
        whereArgs: [lancamentoDivergenteId],
      );

      expect(lancamentoCorrigido.first['status'], 'EFETIVADO');

      // TESTE 15: Somente tres pagamentos validos.
      final pagamentos = await db.query('movimentacao');

      expect(pagamentos.length, 3);

      // TESTE 16: Verificar integridade referencial.
      final integridade = await db.rawQuery('PRAGMA foreign_key_check;');

      expect(integridade, isEmpty);
    } finally {
      await db.close();
      await deleteDatabase(caminho);
    }
  });
}
