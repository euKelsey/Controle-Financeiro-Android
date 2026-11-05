
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'package:controle_financeiro_android/models/cartao_model.dart';
import 'package:controle_financeiro_android/repositories/cartao_repository.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Testa cadastro e consultas do CartaoRepository', (tester) async {
    // Caminho exclusivo do banco de testes.
    final pasta = await getDatabasesPath();
    final caminho = join(pasta, 'teste_cartao_repository.db');

    // Remove somente um possível banco anterior deste teste.
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

      // TESTE 1: Inserir o primeiro cartão.
      final primeiro = await repository.inserir(
        CartaoModel(
          nome: 'Nubank Principal',
          instituicao: 'Nubank',
          limiteTotal: 500000,
          diaFechamento: 2,
          diaVencimento: 10,
          observacao: 'Cartão principal',
        ),
      );

      expect(primeiro.id, isNotNull);
      expect(primeiro.id, greaterThan(0));
      expect(primeiro.status, 'ATIVO');
      expect(primeiro.limiteTotal, 500000);

      // TESTE 2: Buscar cartão pelo ID.
      final encontrado = await repository.buscarPorId(
        primeiro.id!,
      );

      expect(encontrado, isNotNull);
      expect(encontrado!.nome, 'Nubank Principal');
      expect(encontrado.instituicao, 'Nubank');
      expect(encontrado.limiteTotal, 500000);
      expect(encontrado.diaFechamento, 2);
      expect(encontrado.diaVencimento, 10);
      expect(encontrado.observacao, 'Cartão principal');

      // TESTE 3: Inserir outro cartão.
      final segundo = await repository.inserir(
        CartaoModel(
          nome: 'Itaú Secundário',
          instituicao: 'Itaú',
          limiteTotal: 250050,
          diaFechamento: 15,
          diaVencimento: 22,
        ),
      );

      expect(segundo.id, isNotNull);
      expect(segundo.id, isNot(primeiro.id));

      // TESTE 4: Listar cartões em ordem alfabética.
      final cartoes = await repository.listar();

      expect(cartoes.length, 2);
      expect(cartoes[0].nome, 'Itaú Secundário');
      expect(cartoes[1].nome, 'Nubank Principal');
      expect(cartoes[0].limiteTotal, 250050);

      // TESTE 5: Buscar cartão inexistente.
      final inexistente = await repository.buscarPorId(999999);

      expect(inexistente, isNull);

      // TESTE 6: Conferir integridade referencial.
      final integridade = await db.rawQuery(
        'PRAGMA foreign_key_check;',
      );

      expect(integridade, isEmpty);

    } finally {
      // Fecha a conexão antes de excluir o banco temporário.
      await db.close();
      await deleteDatabase(caminho);
    }
  });


  testWidgets('Testa atualizacao e status de cartoes', (tester) async {
    final pasta = await getDatabasesPath();
    final caminho = join(pasta, 'teste_cartao_repository_edicao.db');

    // Remove apenas o banco temporário deste teste.
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

      // TESTE 1: Cadastrar cartão inicial.
      final cadastrado = await repository.inserir(
        CartaoModel(
          nome: 'Cartão Principal',
          instituicao: 'Nubank',
          limiteTotal: 500000,
          diaFechamento: 2,
          diaVencimento: 10,
          observacao: 'Cartão de teste',
        ),
      );

      final id = cadastrado.id!;
      expect(cadastrado.status, 'ATIVO');

      // TESTE 2: Atualizar informações.
      final atualizado = CartaoModel(
        id: id,
        nome: 'Cartão Atualizado',
        instituicao: 'Banco Teste',
        limiteTotal: 750050,
        diaFechamento: 15,
        diaVencimento: 22,
        observacao: 'Dados atualizados',
      );

      final linhasAtualizadas = await repository.atualizar(
        atualizado,
      );

      expect(linhasAtualizadas, 1);

      final encontrado = await repository.buscarPorId(id);

      expect(encontrado, isNotNull);
      expect(encontrado!.nome, 'Cartão Atualizado');
      expect(encontrado.instituicao, 'Banco Teste');
      expect(encontrado.limiteTotal, 750050);
      expect(encontrado.diaFechamento, 15);
      expect(encontrado.diaVencimento, 22);
      expect(encontrado.observacao, 'Dados atualizados');

      // TESTE 3: Inativar cartão.
      final linhasInativadas = await repository.inativar(id);

      expect(linhasInativadas, 1);

      final inativo = await repository.buscarPorId(id);

      expect(inativo!.status, 'INATIVO');
      expect(inativo.nome, 'Cartão Atualizado');
      expect(inativo.limiteTotal, 750050);
      expect(inativo.diaFechamento, 15);
      expect(inativo.diaVencimento, 22);

      // TESTE 4: Reativar cartão.
      final linhasReativadas = await repository.reativar(id);

      expect(linhasReativadas, 1);

      final reativado = await repository.buscarPorId(id);

      expect(reativado!.status, 'ATIVO');
      expect(reativado.nome, 'Cartão Atualizado');
      expect(reativado.instituicao, 'Banco Teste');

      // TESTE 5: Atualizar cartão inexistente.
      final inexistente = CartaoModel(
        id: 999999,
        nome: 'Cartão Inexistente',
        instituicao: 'Banco Teste',
        limiteTotal: 100000,
        diaFechamento: 5,
        diaVencimento: 12,
      );

      final atualizacoesInexistentes =
          await repository.atualizar(inexistente);

      expect(atualizacoesInexistentes, 0);

      // TESTE 6: Inativar cartão inexistente.
      final inativacoesInexistentes =
          await repository.inativar(999999);

      expect(inativacoesInexistentes, 0);

      // TESTE 7: Reativar cartão inexistente.
      final reativacoesInexistentes =
          await repository.reativar(999999);

      expect(reativacoesInexistentes, 0);

      // TESTE 8: Atualizar cartão sem ID.
      final semId = CartaoModel(
        nome: 'Cartão Sem ID',
        instituicao: 'Banco Teste',
        limiteTotal: 100000,
        diaFechamento: 5,
        diaVencimento: 12,
      );

      await expectLater(
        repository.atualizar(semId),
        throwsA(isA<ArgumentError>()),
      );

      // TESTE 9: Conferir integridade referencial.
      final integridade = await db.rawQuery(
        'PRAGMA foreign_key_check;',
      );

      expect(integridade, isEmpty);

      // Confirma que somente o cartão inicial existe.
      final cartoes = await repository.listar();

      expect(cartoes.length, 1);
      expect(cartoes.first.id, id);
      expect(cartoes.first.status, 'ATIVO');
    } finally {
      // Fecha e exclui exclusivamente o banco temporário.
      await db.close();
      await deleteDatabase(caminho);
    }
  });

}
