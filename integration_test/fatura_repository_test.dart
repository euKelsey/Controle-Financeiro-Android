
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'package:controle_financeiro_android/models/fatura_model.dart';
import 'package:controle_financeiro_android/repositories/fatura_repository.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Testa cadastro e consultas de faturas',
      (tester) async {
    final pasta = await getDatabasesPath();

    final caminho = join(
      pasta,
      'teste_fatura_repository.db',
    );

    // Remove somente o banco temporário.
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
      final repository = FaturaRepository(banco: db);

      // TESTE 1: Criar primeiro cartão.
      final cartao1Id = await db.insert(
        'cartao',
        {
          'nome': 'Nubank Principal',
          'instituicao': 'Nubank',
          'limite_total': 500000,
          'dia_fechamento': 10,
          'dia_vencimento': 20,
          'status': 'ATIVO',
        },
      );

      // TESTE 2: Criar segundo cartão.
      final cartao2Id = await db.insert(
        'cartao',
        {
          'nome': 'Cartão Secundário',
          'instituicao': 'Banco Teste',
          'limite_total': 300000,
          'dia_fechamento': 15,
          'dia_vencimento': 25,
          'status': 'ATIVO',
        },
      );

      // TESTE 3: Inserir primeira fatura.
      final primeira = await repository.inserir(
        FaturaModel(
          cartaoId: cartao1Id,
          mesReferencia: '2027-01',
          dataFechamento: '2027-01-10',
          dataVencimento: '2027-01-20',
        ),
      );

      expect(primeira.id, isNotNull);
      expect(primeira.id, greaterThan(0));
      expect(primeira.cartaoId, cartao1Id);
      expect(primeira.mesReferencia, '2027-01');
      expect(primeira.status, 'ABERTA');

      // TESTE 4: Buscar primeira fatura por ID.
      final encontrada = await repository.buscarPorId(
        primeira.id!,
      );

      expect(encontrada, isNotNull);
      expect(encontrada!.cartaoId, cartao1Id);
      expect(encontrada.mesReferencia, '2027-01');
      expect(encontrada.dataFechamento, '2027-01-10');
      expect(encontrada.dataVencimento, '2027-01-20');
      expect(encontrada.status, 'ABERTA');

      // TESTE 5: Inserir fatura de fevereiro.
      final segunda = await repository.inserir(
        FaturaModel(
          cartaoId: cartao1Id,
          mesReferencia: '2027-02',
          dataFechamento: '2027-02-10',
          dataVencimento: '2027-02-20',
        ),
      );

      expect(segunda.id, isNotNull);

      // TESTE 6: Criar fatura de outro cartão
      // na mesma competência de janeiro.
      final terceira = await repository.inserir(
        FaturaModel(
          cartaoId: cartao2Id,
          mesReferencia: '2027-01',
          dataFechamento: '2027-01-15',
          dataVencimento: '2027-01-25',
          status: 'FECHADA',
        ),
      );

      expect(terceira.id, isNotNull);
      expect(terceira.status, 'FECHADA');

      // TESTE 7: Listar todas as faturas.
      final faturas = await repository.listar();

      expect(faturas.length, 3);

      // Janeiro aparece antes de fevereiro.
      // Em janeiro, o menor ID aparece primeiro.
      expect(faturas[0].id, primeira.id);
      expect(faturas[1].id, terceira.id);
      expect(faturas[2].id, segunda.id);

      // TESTE 8: Buscar fatura por cartão e mês.
      final faturaCartao1 =
          await repository.buscarPorCartaoMes(
        cartaoId: cartao1Id,
        mesReferencia: '2027-01',
      );

      expect(faturaCartao1, isNotNull);
      expect(faturaCartao1!.id, primeira.id);

      // TESTE 9: Mesma competência, outro cartão.
      final faturaCartao2 =
          await repository.buscarPorCartaoMes(
        cartaoId: cartao2Id,
        mesReferencia: '2027-01',
      );

      expect(faturaCartao2, isNotNull);
      expect(faturaCartao2!.id, terceira.id);
      expect(faturaCartao2.status, 'FECHADA');

      // TESTE 10: Buscar ID inexistente.
      final inexistente = await repository.buscarPorId(
        999999,
      );

      expect(inexistente, isNull);

      // TESTE 11: Buscar competência inexistente.
      final mesInexistente =
          await repository.buscarPorCartaoMes(
        cartaoId: cartao1Id,
        mesReferencia: '2028-12',
      );

      expect(mesInexistente, isNull);

      // TESTE 12: Bloquear fatura duplicada.
      await expectLater(
        repository.inserir(
          FaturaModel(
            cartaoId: cartao1Id,
            mesReferencia: '2027-01',
            dataFechamento: '2027-01-10',
            dataVencimento: '2027-01-20',
          ),
        ),
        throwsA(isA<DatabaseException>()),
      );

      // TESTE 13: Bloquear cartão inexistente.
      await expectLater(
        repository.inserir(
          FaturaModel(
            cartaoId: 999999,
            mesReferencia: '2027-03',
            dataFechamento: '2027-03-10',
            dataVencimento: '2027-03-20',
          ),
        ),
        throwsA(isA<DatabaseException>()),
      );

      // TESTE 14: Bloquear status inválido.
      await expectLater(
        repository.inserir(
          FaturaModel(
            cartaoId: cartao1Id,
            mesReferencia: '2027-04',
            dataFechamento: '2027-04-10',
            dataVencimento: '2027-04-20',
            status: 'PAGA',
          ),
        ),
        throwsA(isA<DatabaseException>()),
      );

      // TESTE 15: Conferir que tentativas inválidas
      // não adicionaram novas faturas.
      final registros = await db.query('fatura');

      expect(registros.length, 3);

      // TESTE 16: Conferir integridade referencial.
      final integridade = await db.rawQuery(
        'PRAGMA foreign_key_check;',
      );

      expect(integridade, isEmpty);
    } finally {
      // Fecha e exclui apenas o banco deste teste.
      await db.close();
      await deleteDatabase(caminho);
    }
  });

  
  testWidgets('Testa calculo do total das faturas',
      (tester) async {
    final pasta = await getDatabasesPath();

    final caminho = join(
      pasta,
      'teste_fatura_total.db',
    );

    // Banco temporario exclusivo deste teste.
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
      final repository = FaturaRepository(banco: db);

      // TESTE 1: Criar cartao.
      final cartaoId = await db.insert(
        'cartao',
        {
          'nome': 'Cartao Principal',
          'instituicao': 'Banco Teste',
          'limite_total': 500000,
          'dia_fechamento': 10,
          'dia_vencimento': 20,
          'status': 'ATIVO',
        },
      );

      // TESTE 2: Criar categoria de despesa.
      final categoriaId = await db.insert(
        'categoria',
        {
          'nome': 'Compras',
          'tipo': 'DESPESA',
          'status': 'ATIVA',
        },
      );

      // TESTE 3: Criar fatura principal.
      final fatura = await repository.inserir(
        FaturaModel(
          cartaoId: cartaoId,
          mesReferencia: '2027-01',
          dataFechamento: '2027-01-10',
          dataVencimento: '2027-01-20',
        ),
      );

      final faturaId = fatura.id!;

      // TESTE 4: Fatura sem compras retorna zero.
      final totalInicial =
          await repository.calcularTotalFatura(faturaId);

      expect(totalInicial, 0);

      // Funcao auxiliar para cadastrar uma compra
      // e sua parcela unica.
      Future<int> adicionarCompra({
        required int faturaDestinoId,
        required String descricao,
        required int valor,
        String status = 'ATIVA',
      }) async {
        final compraId = await db.insert(
          'compra_cartao',
          {
            'cartao_id': cartaoId,
            'categoria_id': categoriaId,
            'descricao': descricao,
            'data_compra': '2027-01-05',
            'valor_total': valor,
            'quantidade_parcelas': 1,
            'status': status,
          },
        );

        await db.insert(
          'parcela_cartao',
          {
            'compra_cartao_id': compraId,
            'fatura_id': faturaDestinoId,
            'numero_parcela': 1,
            'valor': valor,
            'data_prevista': '2027-01-20',
          },
        );

        return compraId;
      }

      // TESTE 5: Adicionar supermercado.
      final supermercadoId = await adicionarCompra(
        faturaDestinoId: faturaId,
        descricao: 'Supermercado',
        valor: 25990,
      );

      expect(supermercadoId, greaterThan(0));

      final totalUmaCompra =
          await repository.calcularTotalFatura(faturaId);

      expect(totalUmaCompra, 25990);

      // TESTE 6: Adicionar farmacia.
      final farmaciaId = await adicionarCompra(
        faturaDestinoId: faturaId,
        descricao: 'Farmacia',
        valor: 8500,
      );

      expect(farmaciaId, greaterThan(0));

      final totalDuasCompras =
          await repository.calcularTotalFatura(faturaId);

      expect(totalDuasCompras, 34490);

      // TESTE 7: Adicionar compra cancelada.
      final canceladaId = await adicionarCompra(
        faturaDestinoId: faturaId,
        descricao: 'Restaurante',
        valor: 12050,
        status: 'CANCELADA',
      );

      expect(canceladaId, greaterThan(0));

      final totalComCancelada =
          await repository.calcularTotalFatura(faturaId);

      // A compra cancelada nao participa da soma.
      expect(totalComCancelada, 34490);

      // TESTE 8: Criar segunda fatura.
      final outraFatura = await repository.inserir(
        FaturaModel(
          cartaoId: cartaoId,
          mesReferencia: '2027-02',
          dataFechamento: '2027-02-10',
          dataVencimento: '2027-02-20',
        ),
      );

      final outraFaturaId = outraFatura.id!;

      // TESTE 9: Adicionar compra em outra fatura.
      await adicionarCompra(
        faturaDestinoId: outraFaturaId,
        descricao: 'Compra de fevereiro',
        valor: 50000,
      );

      final totalPrincipal =
          await repository.calcularTotalFatura(faturaId);

      final totalOutraFatura =
          await repository.calcularTotalFatura(outraFaturaId);

      expect(totalPrincipal, 34490);
      expect(totalOutraFatura, 50000);

      // TESTE 10: Cancelar a compra do supermercado.
      await db.update(
        'compra_cartao',
        {'status': 'CANCELADA'},
        where: 'id = ?',
        whereArgs: [supermercadoId],
      );

      final totalAposCancelamento =
          await repository.calcularTotalFatura(faturaId);

      // Somente a farmacia continua ativa.
      expect(totalAposCancelamento, 8500);

      // TESTE 11: Cancelar a ultima compra ativa.
      await db.update(
        'compra_cartao',
        {'status': 'CANCELADA'},
        where: 'id = ?',
        whereArgs: [farmaciaId],
      );

      final totalTodasCanceladas =
          await repository.calcularTotalFatura(faturaId);

      expect(totalTodasCanceladas, 0);

      // TESTE 12: A outra fatura permanece inalterada.
      final totalOutraFaturaFinal =
          await repository.calcularTotalFatura(outraFaturaId);

      expect(totalOutraFaturaFinal, 50000);

      // TESTE 13: Conferir os registros armazenados.
      final compras = await db.query('compra_cartao');
      final parcelas = await db.query('parcela_cartao');
      final faturas = await db.query('fatura');

      expect(compras.length, 4);
      expect(parcelas.length, 4);
      expect(faturas.length, 2);

      // TESTE 14: Verificar integridade referencial.
      final integridade = await db.rawQuery(
        'PRAGMA foreign_key_check;',
      );

      expect(integridade, isEmpty);
    } finally {
      await db.close();
      await deleteDatabase(caminho);
    }
  });


  testWidgets('Testa fechamento automatico e rollback de faturas',
      (tester) async {
    final pasta = await getDatabasesPath();

    final caminho = join(
      pasta,
      'teste_fatura_fechamento.db',
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
      final repository = FaturaRepository(banco: db);

      // TESTE 1: Criar cartão.
      final cartaoId = await db.insert(
        'cartao',
        {
          'nome': 'Cartão Principal',
          'instituicao': 'Banco Teste',
          'limite_total': 500000,
          'dia_fechamento': 10,
          'dia_vencimento': 20,
          'status': 'ATIVO',
        },
      );

      // TESTE 2: Criar categoria de despesa.
      final categoriaId = await db.insert(
        'categoria',
        {
          'nome': 'Compras',
          'tipo': 'DESPESA',
          'status': 'ATIVA',
        },
      );

      // Função auxiliar para criar faturas de teste.
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

      // Função auxiliar para associar uma compra à fatura.
      Future<void> adicionarCompra({
        required int faturaId,
        required String descricao,
        required int valor,
      }) async {
        final compraId = await db.insert(
          'compra_cartao',
          {
            'cartao_id': cartaoId,
            'categoria_id': categoriaId,
            'descricao': descricao,
            'data_compra': '2027-01-05',
            'valor_total': valor,
            'quantidade_parcelas': 1,
            'status': 'ATIVA',
          },
        );

        await db.insert(
          'parcela_cartao',
          {
            'compra_cartao_id': compraId,
            'fatura_id': faturaId,
            'numero_parcela': 1,
            'valor': valor,
            'data_prevista': '2027-01-20',
          },
        );
      }

      // TESTE 3: Criar fatura aberta com fechamento atingido.
      final faturaPrincipalId = await criarFatura(
        mes: '2027-01',
        fechamento: '2027-01-10',
        vencimento: '2027-01-20',
      );

      await adicionarCompra(
        faturaId: faturaPrincipalId,
        descricao: 'Supermercado',
        valor: 25990,
      );

      await adicionarCompra(
        faturaId: faturaPrincipalId,
        descricao: 'Farmácia',
        valor: 8500,
      );

      // TESTE 4: Criar fatura zerada.
      final faturaZeradaId = await criarFatura(
        mes: '2026-12',
        fechamento: '2026-12-10',
        vencimento: '2026-12-20',
      );

      // TESTE 5: Criar fatura com fechamento futuro.
      final faturaFuturaId = await criarFatura(
        mes: '2027-02',
        fechamento: '2027-02-10',
        vencimento: '2027-02-20',
      );

      // TESTE 6: Criar fatura já fechada,
      // mas ainda sem lançamento.
      final faturaRecuperacaoId = await criarFatura(
        mes: '2026-11',
        fechamento: '2026-11-10',
        vencimento: '2026-11-20',
        status: 'FECHADA',
      );

      await adicionarCompra(
        faturaId: faturaRecuperacaoId,
        descricao: 'Compra histórica',
        valor: 12000,
      );

      // TESTE 7: Executar processamento.
      final resultado =
          await repository.processarFaturasAutomaticamente(
        dataReferencia: '2027-01-15',
      );

      expect(resultado.faturasFechadas, 2);
      expect(resultado.lancamentosGerados, 2);

      // TESTE 8: Confirmar fechamento da fatura principal.
      final principal = await repository.buscarPorId(
        faturaPrincipalId,
      );

      expect(principal!.status, 'FECHADA');

      // TESTE 9: Confirmar fechamento da fatura zerada.
      final zerada = await repository.buscarPorId(
        faturaZeradaId,
      );

      expect(zerada!.status, 'FECHADA');

      // TESTE 10: Confirmar que a fatura futura
      // continua aberta.
      final futura = await repository.buscarPorId(
        faturaFuturaId,
      );

      expect(futura!.status, 'ABERTA');

      // TESTE 11: Conferir o lançamento principal.
      final lancamentosPrincipal = await db.query(
        'lancamento',
        where: 'fatura_id = ?',
        whereArgs: [faturaPrincipalId],
      );

      expect(lancamentosPrincipal.length, 1);

      final lancamento = lancamentosPrincipal.first;

      expect(lancamento['tipo'], 'DESPESA');
      expect(lancamento['origem'], 'FATURA');
      expect(lancamento['status'], 'PENDENTE');
      expect(lancamento['valor_previsto'], 34490);
      expect(lancamento['data_prevista'], '2027-01-20');
      expect(lancamento['categoria_id'], isNull);

      // TESTE 12: Fatura zerada não gera lançamento.
      final lancamentosZerada = await db.query(
        'lancamento',
        where: 'fatura_id = ?',
        whereArgs: [faturaZeradaId],
      );

      expect(lancamentosZerada, isEmpty);

      // TESTE 13: Fatura futura não gera lançamento.
      final lancamentosFutura = await db.query(
        'lancamento',
        where: 'fatura_id = ?',
        whereArgs: [faturaFuturaId],
      );

      expect(lancamentosFutura, isEmpty);

      // TESTE 14: Recuperar lançamento de fatura
      // que já estava fechada.
      final lancamentosRecuperacao = await db.query(
        'lancamento',
        where: 'fatura_id = ?',
        whereArgs: [faturaRecuperacaoId],
      );

      expect(lancamentosRecuperacao.length, 1);
      expect(
        lancamentosRecuperacao.first['valor_previsto'],
        12000,
      );

      // TESTE 15: Executar o processamento novamente.
      final segundaExecucao =
          await repository.processarFaturasAutomaticamente(
        dataReferencia: '2027-01-15',
      );

      expect(segundaExecucao.faturasFechadas, 0);
      expect(segundaExecucao.lancamentosGerados, 0);

      // TESTE 16: Confirmar que não houve duplicidade.
      final lancamentosAposSegunda = await db.query(
        'lancamento',
      );

      expect(lancamentosAposSegunda.length, 2);

      // TESTE 17: Rejeitar data de referência inválida.
      await expectLater(
        repository.processarFaturasAutomaticamente(
          dataReferencia: '2027-02-30',
        ),
        throwsA(isA<ArgumentError>()),
      );

      await expectLater(
        repository.processarFaturasAutomaticamente(
          dataReferencia: '15/01/2027',
        ),
        throwsA(isA<ArgumentError>()),
      );

      // TESTE 18: Preparar fatura para simular falha.
      final faturaRollbackId = await criarFatura(
        mes: '2027-03',
        fechamento: '2027-01-12',
        vencimento: '2027-03-20',
      );

      await adicionarCompra(
        faturaId: faturaRollbackId,
        descricao: 'Compra para rollback',
        valor: 18000,
      );

      // Trigger usado exclusivamente no banco de testes.
      // Ele impede a criação de um lançamento de fatura.
      await db.execute('''
        CREATE TRIGGER bloquear_lancamento_fatura_teste
        BEFORE INSERT ON lancamento
        WHEN NEW.fatura_id = $faturaRollbackId
        BEGIN
          SELECT RAISE(
            ABORT,
            'Falha simulada no lançamento da fatura'
          );
        END;
      ''');

      // TESTE 19: O processamento deve falhar.
      await expectLater(
        repository.processarFaturasAutomaticamente(
          dataReferencia: '2027-01-15',
        ),
        throwsA(isA<DatabaseException>()),
      );

      // TESTE 20: A fatura não pode ficar fechada
      // se a geração do lançamento falhou.
      final aposFalha = await repository.buscarPorId(
        faturaRollbackId,
      );

      expect(aposFalha!.status, 'ABERTA');

      final lancamentosRollback = await db.query(
        'lancamento',
        where: 'fatura_id = ?',
        whereArgs: [faturaRollbackId],
      );

      expect(lancamentosRollback, isEmpty);

      // TESTE 21: Confirmar que os lançamentos
      // anteriores foram preservados.
      final lancamentosFinais = await db.query(
        'lancamento',
      );

      expect(lancamentosFinais.length, 2);

      // Remove o trigger de demonstração.
      await db.execute(
        'DROP TRIGGER bloquear_lancamento_fatura_teste',
      );

      // TESTE 22: Reprocessar depois de remover a falha.
      final recuperado =
          await repository.processarFaturasAutomaticamente(
        dataReferencia: '2027-01-15',
      );

      expect(recuperado.faturasFechadas, 1);
      expect(recuperado.lancamentosGerados, 1);

      final faturaRecuperada = await repository.buscarPorId(
        faturaRollbackId,
      );

      expect(faturaRecuperada!.status, 'FECHADA');

      // TESTE 23: Verificar integridade referencial.
      final integridade = await db.rawQuery(
        'PRAGMA foreign_key_check;',
      );

      expect(integridade, isEmpty);
    } finally {
      await db.close();
      await deleteDatabase(caminho);
    }
  });


  testWidgets('Testa consistencia dos valores das faturas',
      (tester) async {
    final pasta = await getDatabasesPath();

    final caminho = join(
      pasta,
      'teste_fatura_consistencia.db',
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
      final repository = FaturaRepository(banco: db);

      // TESTE 1: Criar cartao.
      final cartaoId = await db.insert(
        'cartao',
        {
          'nome': 'Cartao Consistencia',
          'instituicao': 'Banco Teste',
          'limite_total': 500000,
          'dia_fechamento': 10,
          'dia_vencimento': 20,
          'status': 'ATIVO',
        },
      );

      // TESTE 2: Criar categoria.
      final categoriaId = await db.insert(
        'categoria',
        {
          'nome': 'Compras',
          'tipo': 'DESPESA',
          'status': 'ATIVA',
        },
      );

      // Funcao auxiliar para criar faturas.
      Future<int> criarFatura(String mes) async {
        final fatura = await repository.inserir(
          FaturaModel(
            cartaoId: cartaoId,
            mesReferencia: mes,
            dataFechamento: '$mes-10',
            dataVencimento: '$mes-20',
            status: 'FECHADA',
          ),
        );

        return fatura.id!;
      }

      // Funcao auxiliar para cadastrar compras e parcelas.
      Future<int> adicionarCompra({
        required int faturaId,
        required String descricao,
        required int valor,
      }) async {
        final compraId = await db.insert(
          'compra_cartao',
          {
            'cartao_id': cartaoId,
            'categoria_id': categoriaId,
            'descricao': descricao,
            'data_compra': '2027-01-05',
            'valor_total': valor,
            'quantidade_parcelas': 1,
            'status': 'ATIVA',
          },
        );

        await db.insert(
          'parcela_cartao',
          {
            'compra_cartao_id': compraId,
            'fatura_id': faturaId,
            'numero_parcela': 1,
            'valor': valor,
            'data_prevista': '2027-01-20',
          },
        );

        return compraId;
      }

      // TESTE 3: Criar fatura principal.
      final faturaPrincipalId = await criarFatura(
        '2027-01',
      );

      // TESTE 4: Inserir duas compras ativas.
      final supermercadoId = await adicionarCompra(
        faturaId: faturaPrincipalId,
        descricao: 'Supermercado',
        valor: 25990,
      );

      final farmaciaId = await adicionarCompra(
        faturaId: faturaPrincipalId,
        descricao: 'Farmacia',
        valor: 8500,
      );

      // TESTE 5: Criar lancamento consolidado.
      final lancamentoId = await db.insert(
        'lancamento',
        {
          'tipo': 'DESPESA',
          'descricao': 'Fatura do cartao - 2027-01',
          'valor_previsto': 34490,
          'data_prevista': '2027-01-20',
          'categoria_id': null,
          'fatura_id': faturaPrincipalId,
          'status': 'PENDENTE',
          'origem': 'FATURA',
        },
      );

      expect(lancamentoId, greaterThan(0));

      // TESTE 6: Total e lancamento iguais.
      final conferenciaInicial =
          await repository.conferirValorLancamento(
        faturaPrincipalId,
      );

      expect(conferenciaInicial.totalCompras, 34490);
      expect(conferenciaInicial.valorLancamento, 34490);
      expect(conferenciaInicial.consistente, isTrue);

      // TESTE 7: Simular cancelamento apos fechamento.
      // Alteracao direta apenas para preparar o teste.
      await db.update(
        'compra_cartao',
        {'status': 'CANCELADA'},
        where: 'id = ?',
        whereArgs: [farmaciaId],
      );

      final aposCancelamento =
          await repository.conferirValorLancamento(
        faturaPrincipalId,
      );

      expect(aposCancelamento.totalCompras, 25990);
      expect(aposCancelamento.valorLancamento, 34490);
      expect(aposCancelamento.consistente, isFalse);

      // TESTE 8: Cancelar todas as compras.
      await db.update(
        'compra_cartao',
        {'status': 'CANCELADA'},
        where: 'id = ?',
        whereArgs: [supermercadoId],
      );

      final todasCanceladas =
          await repository.conferirValorLancamento(
        faturaPrincipalId,
      );

      expect(todasCanceladas.totalCompras, 0);
      expect(todasCanceladas.valorLancamento, 34490);
      expect(todasCanceladas.consistente, isFalse);

      // TESTE 9: Restaurar os dados de demonstracao.
      await db.update(
        'compra_cartao',
        {'status': 'ATIVA'},
        where: 'id IN (?, ?)',
        whereArgs: [supermercadoId, farmaciaId],
      );

      final restaurada =
          await repository.conferirValorLancamento(
        faturaPrincipalId,
      );

      expect(restaurada.consistente, isTrue);

      // TESTE 10: Fatura zerada sem lancamento.
      final faturaZeradaId = await criarFatura(
        '2027-02',
      );

      final conferenciaZerada =
          await repository.conferirValorLancamento(
        faturaZeradaId,
      );

      expect(conferenciaZerada.totalCompras, 0);
      expect(conferenciaZerada.valorLancamento, isNull);
      expect(conferenciaZerada.consistente, isTrue);

      // TESTE 11: Fatura com compra, sem lancamento.
      final semLancamentoId = await criarFatura(
        '2027-03',
      );

      await adicionarCompra(
        faturaId: semLancamentoId,
        descricao: 'Compra sem lancamento',
        valor: 15000,
      );

      final conferenciaSemLancamento =
          await repository.conferirValorLancamento(
        semLancamentoId,
      );

      expect(
        conferenciaSemLancamento.totalCompras,
        15000,
      );
      expect(
        conferenciaSemLancamento.valorLancamento,
        isNull,
      );
      expect(
        conferenciaSemLancamento.consistente,
        isFalse,
      );

      // TESTE 12: Conferir fatura inexistente.
      await expectLater(
        repository.conferirValorLancamento(999999),
        throwsA(isA<ArgumentError>()),
      );

      // TESTE 13: Confirmar que a conferencia
      // nao altera os registros financeiros.
      final lancamentos = await db.query('lancamento');
      final movimentacoes = await db.query('movimentacao');

      expect(lancamentos.length, 1);
      expect(movimentacoes, isEmpty);

      final lancamentoPreservado = await db.query(
        'lancamento',
        where: 'id = ?',
        whereArgs: [lancamentoId],
      );

      expect(
        lancamentoPreservado.first['valor_previsto'],
        34490,
      );
      expect(
        lancamentoPreservado.first['status'],
        'PENDENTE',
      );

      // TESTE 14: Conferir integridade referencial.
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
