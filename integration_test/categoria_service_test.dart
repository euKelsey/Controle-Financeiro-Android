import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'package:controle_financeiro_android/repositories/categoria_repository.dart';
import 'package:controle_financeiro_android/services/categoria_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Valida cadastro no CategoriaService', (tester) async {
    // Banco temporário exclusivo deste teste.
    final pasta = await getDatabasesPath();
    final caminho = join(pasta, 'teste_categoria_service.db');

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
      final repository = CategoriaRepository(banco: db);
      final service = CategoriaService(repository);

      // TESTE 1: Cadastro válido e padronização.
      final categoria = await service.cadastrarCategoria(
        nome: ' Alimentação ',
        tipo: 'despesa',
        descricao: 'Gastos com alimentação',
      );

      expect(categoria.id, isNotNull);
      expect(categoria.nome, 'Alimentação');
      expect(categoria.tipo, 'DESPESA');
      expect(categoria.status, 'ATIVA');

      // TESTE 2: Nome vazio.
      await expectLater(
        service.cadastrarCategoria(nome: '   ', tipo: 'DESPESA'),
        throwsA(
          isA<ArgumentError>().having(
            (erro) => erro.message,
            'mensagem',
            'O nome da categoria é obrigatório.',
          ),
        ),
      );

      // TESTE 3: Tipo inválido.
      await expectLater(
        service.cadastrarCategoria(nome: 'Teste inválido', tipo: 'OUTRO'),
        throwsA(isA<ArgumentError>()),
      );

      // TESTE 4: Categoria duplicada.
      await expectLater(
        service.cadastrarCategoria(nome: 'Alimentação', tipo: 'DESPESA'),
        throwsA(
          isA<ArgumentError>().having(
            (erro) => erro.message,
            'mensagem',
            'Já existe uma categoria com esse nome e tipo.',
          ),
        ),
      );

      // TESTE 5: Mesmo nome com tipo diferente é permitido.
      final receita = await service.cadastrarCategoria(
        nome: 'Alimentação',
        tipo: 'RECEITA',
      );

      expect(receita.id, isNotNull);
      expect(receita.tipo, 'RECEITA');

      // Confirma que somente duas categorias foram gravadas.
      final categorias = await repository.listar();

      expect(categorias.length, 2);

      final nomes = categorias.map((c) => c.nome).toList();

      expect(nomes, ['Alimentação', 'Alimentação']);
    } finally {
      // Fecha e exclui somente o banco de testes.
      await db.close();
      await deleteDatabase(caminho);
    }
  });

  testWidgets('Valida consulta, edicao e status de categorias', (tester) async {
    final pasta = await getDatabasesPath();
    final caminho = join(pasta, 'teste_categoria_service_edicao.db');

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
      final repository = CategoriaRepository(banco: db);
      final service = CategoriaService(repository);

      // Prepara duas categorias para os testes.
      final alimentacao = await service.cadastrarCategoria(
        nome: 'Alimentação',
        tipo: 'DESPESA',
        descricao: 'Gastos com alimentação',
      );

      final transporte = await service.cadastrarCategoria(
        nome: 'Transporte',
        tipo: 'DESPESA',
      );

      final id = alimentacao.id!;

      // TESTE 1: Listar todas.
      final todas = await service.listarCategorias();
      expect(todas.length, 2);

      // TESTE 2: Listar ativas.
      final ativas = await service.listarCategoriasAtivas();
      expect(ativas.length, 2);

      // TESTE 3: Buscar por ID.
      final encontrada = await service.buscarCategoriaPorId(id);
      expect(encontrada, isNotNull);
      expect(encontrada!.nome, 'Alimentação');

      // TESTE 4: Atualizar nome e descrição.
      final atualizada = await service.atualizarCategoria(
        categoriaId: id,
        nome: 'Alimentação Atualizada',
        tipo: 'DESPESA',
        descricao: 'Descrição modificada',
      );

      expect(atualizada.nome, 'Alimentação Atualizada');
      expect(atualizada.descricao, 'Descrição modificada');

      final salvaNoBanco = await service.buscarCategoriaPorId(id);
      expect(salvaNoBanco!.nome, 'Alimentação Atualizada');

      // TESTE 5: Categoria inexistente.
      await expectLater(
        service.atualizarCategoria(
          categoriaId: 999999,
          nome: 'Inexistente',
          tipo: 'DESPESA',
        ),
        throwsA(isA<ArgumentError>()),
      );

      // TESTE 6: Nome vazio.
      await expectLater(
        service.atualizarCategoria(
          categoriaId: id,
          nome: '   ',
          tipo: 'DESPESA',
        ),
        throwsA(isA<ArgumentError>()),
      );

      // TESTE 7: Tipo inválido.
      await expectLater(
        service.atualizarCategoria(
          categoriaId: id,
          nome: 'Teste',
          tipo: 'OUTRO',
        ),
        throwsA(isA<ArgumentError>()),
      );

      // TESTE 8: Status inválido.
      await expectLater(
        service.atualizarCategoria(
          categoriaId: id,
          nome: 'Teste',
          tipo: 'DESPESA',
          status: 'BLOQUEADA',
        ),
        throwsA(isA<ArgumentError>()),
      );

      // TESTE 9: Nome e tipo duplicados.
      await expectLater(
        service.atualizarCategoria(
          categoriaId: id,
          nome: 'Transporte',
          tipo: 'DESPESA',
        ),
        throwsA(isA<ArgumentError>()),
      );

      // TESTE 10: Inativar categoria.
      final inativa = await service.inativarCategoria(id);
      expect(inativa.status, 'INATIVA');

      // TESTE 11: Listar somente ativas após inativação.
      final ativasDepois = await service.listarCategoriasAtivas();

      expect(ativasDepois.length, 1);
      expect(ativasDepois.first.id, transporte.id);

      // TESTE 12: Reativar categoria.
      final reativada = await service.atualizarCategoria(
        categoriaId: id,
        nome: 'Alimentação Atualizada',
        tipo: 'DESPESA',
        descricao: 'Descrição modificada',
        status: 'ATIVA',
      );

      expect(reativada.status, 'ATIVA');

      final confirmada = await service.buscarCategoriaPorId(id);
      expect(confirmada!.status, 'ATIVA');

      // TESTE 13: Inativar categoria inexistente.
      await expectLater(
        service.inativarCategoria(999999),
        throwsA(isA<ArgumentError>()),
      );

      // Confirma que continuam existindo apenas dois registros.
      final resultadoFinal = await service.listarCategorias();
      expect(resultadoFinal.length, 2);
    } finally {
      // Remove somente o banco temporário de testes.
      await db.close();
      await deleteDatabase(caminho);
    }
  });
}
