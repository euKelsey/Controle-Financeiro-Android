
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'package:controle_financeiro_android/repositories/cartao_repository.dart';
import 'package:controle_financeiro_android/services/cartao_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Valida cadastro no CartaoService', (tester) async {
    // Banco exclusivo deste teste.
    final pasta = await getDatabasesPath();
    final caminho = join(pasta, 'teste_cartao_service.db');

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
      final repository = CartaoRepository(banco: db);
      final service = CartaoService(repository);

      // TESTE 1: Cadastro válido com padronização.
      final cartao = await service.cadastrarCartao(
        nome: ' Nubank Principal ',
        instituicao: ' Nubank ',
        limiteTotal: 500000,
        diaFechamento: 2,
        diaVencimento: 10,
        observacao: 'Cartão de teste',
      );

      expect(cartao.id, isNotNull);
      expect(cartao.nome, 'Nubank Principal');
      expect(cartao.instituicao, 'Nubank');
      expect(cartao.limiteTotal, 500000);
      expect(cartao.diaFechamento, 2);
      expect(cartao.diaVencimento, 10);
      expect(cartao.status, 'ATIVO');

      // TESTE 2: Nome vazio.
      await expectLater(
        service.cadastrarCartao(
          nome: '   ',
          instituicao: 'Nubank',
          limiteTotal: 500000,
          diaFechamento: 2,
          diaVencimento: 10,
        ),
        throwsA(isA<ArgumentError>()),
      );

      // TESTE 3: Instituição vazia.
      await expectLater(
        service.cadastrarCartao(
          nome: 'Cartão Teste',
          instituicao: '   ',
          limiteTotal: 500000,
          diaFechamento: 2,
          diaVencimento: 10,
        ),
        throwsA(isA<ArgumentError>()),
      );

      // TESTE 4: Limite negativo.
      await expectLater(
        service.cadastrarCartao(
          nome: 'Cartão Teste',
          instituicao: 'Banco Teste',
          limiteTotal: -100,
          diaFechamento: 2,
          diaVencimento: 10,
        ),
        throwsA(isA<ArgumentError>()),
      );

      // TESTE 5: Dia de fechamento menor que 1.
      await expectLater(
        service.cadastrarCartao(
          nome: 'Cartão Teste',
          instituicao: 'Banco Teste',
          limiteTotal: 100000,
          diaFechamento: 0,
          diaVencimento: 10,
        ),
        throwsA(isA<ArgumentError>()),
      );

      // TESTE 6: Dia de fechamento maior que 31.
      await expectLater(
        service.cadastrarCartao(
          nome: 'Cartão Teste',
          instituicao: 'Banco Teste',
          limiteTotal: 100000,
          diaFechamento: 32,
          diaVencimento: 10,
        ),
        throwsA(isA<ArgumentError>()),
      );

      // TESTE 7: Dia de vencimento menor que 1.
      await expectLater(
        service.cadastrarCartao(
          nome: 'Cartão Teste',
          instituicao: 'Banco Teste',
          limiteTotal: 100000,
          diaFechamento: 2,
          diaVencimento: 0,
        ),
        throwsA(isA<ArgumentError>()),
      );

      // TESTE 8: Dia de vencimento maior que 31.
      await expectLater(
        service.cadastrarCartao(
          nome: 'Cartão Teste',
          instituicao: 'Banco Teste',
          limiteTotal: 100000,
          diaFechamento: 2,
          diaVencimento: 32,
        ),
        throwsA(isA<ArgumentError>()),
      );

      // TESTE 9: Limite zero é permitido.
      final cartaoZero = await service.cadastrarCartao(
        nome: 'Cartão Sem Limite',
        instituicao: 'Banco Teste',
        limiteTotal: 0,
        diaFechamento: 31,
        diaVencimento: 31,
      );

      expect(cartaoZero.id, isNotNull);
      expect(cartaoZero.limiteTotal, 0);

      // TESTE 10: Confirmar registros no banco.
      final cartoes = await repository.listar();

      expect(cartoes.length, 2);
      expect(cartoes[0].nome, 'Cartão Sem Limite');
      expect(cartoes[1].nome, 'Nubank Principal');

      // TESTE 11: Verificar integridade referencial.
      final integridade = await db.rawQuery(
        'PRAGMA foreign_key_check;',
      );

      expect(integridade, isEmpty);
    } finally {
      // Fecha e remove somente o banco de testes.
      await db.close();
      await deleteDatabase(caminho);
    }
  });


  testWidgets('Valida edicao e status no CartaoService', (tester) async {
    final pasta = await getDatabasesPath();
    final caminho = join(pasta, 'teste_cartao_service_edicao.db');

    // Banco exclusivo deste teste.
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
      final repository = CartaoRepository(banco: db);
      final service = CartaoService(repository);

      // TESTE 1: Cadastrar cartão.
      final cadastrado = await service.cadastrarCartao(
        nome: 'Cartão Principal',
        instituicao: 'Nubank',
        limiteTotal: 500000,
        diaFechamento: 2,
        diaVencimento: 10,
      );

      final id = cadastrado.id!;

      // TESTE 2: Consultar por ID.
      final encontrado = await service.buscarCartaoPorId(id);
      expect(encontrado.nome, 'Cartão Principal');

      // TESTE 3: Listar cartões.
      final lista = await service.listarCartoes();
      expect(lista.length, 1);

      // TESTE 4: Atualizar informações.
      final atualizado = await service.atualizarCartao(
        cartaoId: id,
        nome: ' Cartão Atualizado ',
        instituicao: ' Banco Teste ',
        limiteTotal: 750050,
        diaFechamento: 15,
        diaVencimento: 22,
        observacao: 'Dados atualizados',
      );

      expect(atualizado.nome, 'Cartão Atualizado');
      expect(atualizado.instituicao, 'Banco Teste');
      expect(atualizado.limiteTotal, 750050);
      expect(atualizado.diaFechamento, 15);
      expect(atualizado.diaVencimento, 22);
      expect(atualizado.observacao, 'Dados atualizados');

      // Confere persistência no SQLite.
      final salvo = await service.buscarCartaoPorId(id);

      expect(salvo.nome, 'Cartão Atualizado');
      expect(salvo.limiteTotal, 750050);

      // TESTE 5: Nome vazio.
      await expectLater(
        service.atualizarCartao(
          cartaoId: id,
          nome: '   ',
          instituicao: 'Banco Teste',
          limiteTotal: 100000,
          diaFechamento: 5,
          diaVencimento: 12,
        ),
        throwsA(isA<ArgumentError>()),
      );

      // TESTE 6: Instituição vazia.
      await expectLater(
        service.atualizarCartao(
          cartaoId: id,
          nome: 'Cartão Teste',
          instituicao: '   ',
          limiteTotal: 100000,
          diaFechamento: 5,
          diaVencimento: 12,
        ),
        throwsA(isA<ArgumentError>()),
      );

      // TESTE 7: Limite negativo.
      await expectLater(
        service.atualizarCartao(
          cartaoId: id,
          nome: 'Cartão Teste',
          instituicao: 'Banco Teste',
          limiteTotal: -100,
          diaFechamento: 5,
          diaVencimento: 12,
        ),
        throwsA(isA<ArgumentError>()),
      );

      // TESTE 8: Fechamento inválido.
      await expectLater(
        service.atualizarCartao(
          cartaoId: id,
          nome: 'Cartão Teste',
          instituicao: 'Banco Teste',
          limiteTotal: 100000,
          diaFechamento: 32,
          diaVencimento: 12,
        ),
        throwsA(isA<ArgumentError>()),
      );

      // TESTE 9: Vencimento inválido.
      await expectLater(
        service.atualizarCartao(
          cartaoId: id,
          nome: 'Cartão Teste',
          instituicao: 'Banco Teste',
          limiteTotal: 100000,
          diaFechamento: 5,
          diaVencimento: 0,
        ),
        throwsA(isA<ArgumentError>()),
      );

      // TESTE 10: Status inválido.
      await expectLater(
        service.atualizarCartao(
          cartaoId: id,
          nome: 'Cartão Teste',
          instituicao: 'Banco Teste',
          limiteTotal: 100000,
          diaFechamento: 5,
          diaVencimento: 12,
          status: 'BLOQUEADO',
        ),
        throwsA(isA<ArgumentError>()),
      );

      // TESTE 11: Atualizar cartão inexistente.
      await expectLater(
        service.atualizarCartao(
          cartaoId: 999999,
          nome: 'Cartão Inexistente',
          instituicao: 'Banco Teste',
          limiteTotal: 100000,
          diaFechamento: 5,
          diaVencimento: 12,
        ),
        throwsA(isA<ArgumentError>()),
      );

      // TESTE 12: Inativar.
      final inativo = await service.inativarCartao(id);
      expect(inativo.status, 'INATIVO');

      // TESTE 13: Confirmar que os dados foram preservados.
      final aposInativacao = await service.buscarCartaoPorId(id);
      expect(aposInativacao.nome, 'Cartão Atualizado');
      expect(aposInativacao.limiteTotal, 750050);
      expect(aposInativacao.status, 'INATIVO');

      // TESTE 14: Reativar.
      final reativado = await service.reativarCartao(id);
      expect(reativado.status, 'ATIVO');

      // TESTE 15: Inativar cartão inexistente.
      await expectLater(
        service.inativarCartao(999999),
        throwsA(isA<ArgumentError>()),
      );

      // TESTE 16: Reativar cartão inexistente.
      await expectLater(
        service.reativarCartao(999999),
        throwsA(isA<ArgumentError>()),
      );

      // TESTE 17: Conferir o estado final no banco.
      final finalizado = await service.buscarCartaoPorId(id);

      expect(finalizado.status, 'ATIVO');
      expect(finalizado.nome, 'Cartão Atualizado');
      expect(finalizado.limiteTotal, 750050);

      final cartoes = await service.listarCartoes();
      expect(cartoes.length, 1);

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
