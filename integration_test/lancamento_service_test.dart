import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'package:controle_financeiro_android/repositories/lancamento_repository.dart';
import 'package:controle_financeiro_android/repositories/categoria_repository.dart';
import 'package:controle_financeiro_android/services/lancamento_service.dart';
import 'package:controle_financeiro_android/models/lancamento_model.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Valida cadastro no LancamentoService', (tester) async {
    // Banco exclusivo deste teste.
    final pasta = await getDatabasesPath();
    final caminho = join(pasta, 'teste_lancamento_service.db');

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
      final repository = LancamentoRepository(banco: db);
      final service = LancamentoService(
        repository,
        categoriaRepository: CategoriaRepository(banco: db),
      );

      // TESTE 1: Criar categorias válidas.
      final categoriaDespesaId = await db.insert('categoria', {
        'nome': 'Moradia',
        'tipo': 'DESPESA',
        'status': 'ATIVA',
      });

      final categoriaReceitaId = await db.insert('categoria', {
        'nome': 'Trabalho',
        'tipo': 'RECEITA',
        'status': 'ATIVA',
      });

      // TESTE 2: Cadastrar despesa e padronizar dados.
      final despesa = await service.cadastrarLancamento(
        tipo: ' despesa ',
        descricao: ' Conta de energia ',
        valorPrevisto: 18590,
        dataPrevista: '2026-11-10',
        categoriaId: categoriaDespesaId,
      );

      expect(despesa.id, isNotNull);
      expect(despesa.tipo, 'DESPESA');
      expect(despesa.descricao, 'Conta de energia');
      expect(despesa.valorPrevisto, 18590);
      expect(despesa.status, 'PENDENTE');
      expect(despesa.origem, 'MANUAL');

      // TESTE 3: Cadastrar receita.
      final receita = await service.cadastrarLancamento(
        tipo: 'receita',
        descricao: 'Salário',
        valorPrevisto: 350000,
        dataPrevista: '2026-11-05',
        categoriaId: categoriaReceitaId,
      );

      expect(receita.id, isNotNull);
      expect(receita.tipo, 'RECEITA');
      expect(receita.valorPrevisto, 350000);
      expect(receita.status, 'PENDENTE');

      // TESTE 4: Rejeitar tipo inválido.
      await expectLater(
        service.cadastrarLancamento(
          tipo: 'TRANSFERENCIA',
          descricao: 'Teste',
          valorPrevisto: 10000,
          dataPrevista: '2026-11-15',
          categoriaId: categoriaDespesaId,
        ),
        throwsA(isA<ArgumentError>()),
      );

      // TESTE 5: Rejeitar descrição vazia.
      await expectLater(
        service.cadastrarLancamento(
          tipo: 'DESPESA',
          descricao: '   ',
          valorPrevisto: 10000,
          dataPrevista: '2026-11-15',
          categoriaId: categoriaDespesaId,
        ),
        throwsA(isA<ArgumentError>()),
      );

      // TESTE 6: Rejeitar valor zero.
      await expectLater(
        service.cadastrarLancamento(
          tipo: 'DESPESA',
          descricao: 'Valor zero',
          valorPrevisto: 0,
          dataPrevista: '2026-11-15',
          categoriaId: categoriaDespesaId,
        ),
        throwsA(isA<ArgumentError>()),
      );

      // TESTE 7: Rejeitar valor negativo.
      await expectLater(
        service.cadastrarLancamento(
          tipo: 'DESPESA',
          descricao: 'Valor negativo',
          valorPrevisto: -500,
          dataPrevista: '2026-11-15',
          categoriaId: categoriaDespesaId,
        ),
        throwsA(isA<ArgumentError>()),
      );

      // TESTE 8: Rejeitar categoria não informada.
      await expectLater(
        service.cadastrarLancamento(
          tipo: 'DESPESA',
          descricao: 'Sem categoria',
          valorPrevisto: 10000,
          dataPrevista: '2026-11-15',
          categoriaId: null,
        ),
        throwsA(isA<ArgumentError>()),
      );

      // TESTE 9: Rejeitar categoria inexistente.
      // Neste caso, a chave estrangeira do SQLite
      // impede a inserção do lançamento.
      await expectLater(
        service.cadastrarLancamento(
          tipo: 'DESPESA',
          descricao: 'Categoria inexistente',
          valorPrevisto: 10000,
          dataPrevista: '2026-11-15',
          categoriaId: 999999,
        ),
       throwsA(isA<ArgumentError>()),
      );

      // TESTE 10: Verificar dados gravados.
      final lancamentos = await repository.listar();

      expect(lancamentos.length, 2);

      // A listagem é ordenada pela data prevista.
      expect(lancamentos[0].descricao, 'Salário');
      expect(lancamentos[1].descricao, 'Conta de energia');

      expect(lancamentos[0].valorPrevisto, 350000);
      expect(lancamentos[1].valorPrevisto, 18590);

      // TESTE 11: Confirmar persistência no SQLite.
      final registros = await db.query('lancamento');

      expect(registros.length, 2);

      // TESTE 12: Conferir integridade referencial.
      final integridade = await db.rawQuery('PRAGMA foreign_key_check;');

      expect(integridade, isEmpty);
    } finally {
      // Fecha e exclui somente o banco temporário.
      await db.close();
      await deleteDatabase(caminho);
    }
  });

  testWidgets('Valida edicao e cancelamento no LancamentoService', (
    tester,
  ) async {
    final pasta = await getDatabasesPath();

    final caminho = join(pasta, 'teste_lancamento_service_edicao.db');

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
      final repository = LancamentoRepository(banco: db);
      final service = LancamentoService(
        repository,
        categoriaRepository: CategoriaRepository(banco: db),
      );

      // TESTE 1: Criar uma categoria de despesa.
      final categoriaId = await db.insert('categoria', {
        'nome': 'Moradia',
        'tipo': 'DESPESA',
        'status': 'ATIVA',
      });

      // TESTE 2: Cadastrar lançamento manual.
      final cadastrado = await service.cadastrarLancamento(
        tipo: 'DESPESA',
        descricao: 'Conta de energia',
        valorPrevisto: 18590,
        dataPrevista: '2026-11-10',
        categoriaId: categoriaId,
      );

      final id = cadastrado.id!;

      // TESTE 3: Consultar por ID.
      final encontrado = await service.buscarLancamentoPorId(id);

      expect(encontrado.id, id);
      expect(encontrado.descricao, 'Conta de energia');
      expect(encontrado.status, 'PENDENTE');

      // TESTE 4: Atualizar lançamento.
      final atualizado = await service.atualizarLancamento(
        lancamentoId: id,
        tipo: ' despesa ',
        descricao: ' Energia atualizada ',
        valorPrevisto: 21050,
        dataPrevista: '2026-11-15',
        categoriaId: categoriaId,
        observacao: 'Valor corrigido',
      );

      expect(atualizado.tipo, 'DESPESA');
      expect(atualizado.descricao, 'Energia atualizada');
      expect(atualizado.valorPrevisto, 21050);
      expect(atualizado.dataPrevista, '2026-11-15');
      expect(atualizado.status, 'PENDENTE');
      expect(atualizado.origem, 'MANUAL');

      // TESTE 5: Conferir persistência.
      final salvo = await service.buscarLancamentoPorId(id);

      expect(salvo.descricao, 'Energia atualizada');
      expect(salvo.valorPrevisto, 21050);
      expect(salvo.categoriaId, categoriaId);
      expect(salvo.observacao, 'Valor corrigido');

      // TESTE 6: Rejeitar tipo inválido.
      await expectLater(
        service.atualizarLancamento(
          lancamentoId: id,
          tipo: 'TRANSFERENCIA',
          descricao: 'Teste',
          valorPrevisto: 10000,
          dataPrevista: '2026-11-20',
          categoriaId: categoriaId,
        ),
        throwsA(isA<ArgumentError>()),
      );

      // TESTE 7: Rejeitar descrição vazia.
      await expectLater(
        service.atualizarLancamento(
          lancamentoId: id,
          tipo: 'DESPESA',
          descricao: '   ',
          valorPrevisto: 10000,
          dataPrevista: '2026-11-20',
          categoriaId: categoriaId,
        ),
        throwsA(isA<ArgumentError>()),
      );

      // TESTE 8: Rejeitar valor zero.
      await expectLater(
        service.atualizarLancamento(
          lancamentoId: id,
          tipo: 'DESPESA',
          descricao: 'Teste',
          valorPrevisto: 0,
          dataPrevista: '2026-11-20',
          categoriaId: categoriaId,
        ),
        throwsA(isA<ArgumentError>()),
      );

      // TESTE 9: Rejeitar valor negativo.
      await expectLater(
        service.atualizarLancamento(
          lancamentoId: id,
          tipo: 'DESPESA',
          descricao: 'Teste',
          valorPrevisto: -100,
          dataPrevista: '2026-11-20',
          categoriaId: categoriaId,
        ),
        throwsA(isA<ArgumentError>()),
      );

      // TESTE 10: Rejeitar categoria nula.
      await expectLater(
        service.atualizarLancamento(
          lancamentoId: id,
          tipo: 'DESPESA',
          descricao: 'Teste',
          valorPrevisto: 10000,
          dataPrevista: '2026-11-20',
          categoriaId: null,
        ),
        throwsA(isA<ArgumentError>()),
      );

      // TESTE 11: Rejeitar status inválido.
      await expectLater(
        service.atualizarLancamento(
          lancamentoId: id,
          tipo: 'DESPESA',
          descricao: 'Teste',
          valorPrevisto: 10000,
          dataPrevista: '2026-11-20',
          categoriaId: categoriaId,
          status: 'PAGO',
        ),
        throwsA(isA<ArgumentError>()),
      );

      // TESTE 12: Rejeitar lançamento inexistente.
      await expectLater(
        service.buscarLancamentoPorId(999999),
        throwsA(isA<ArgumentError>()),
      );

      await expectLater(
        service.atualizarLancamento(
          lancamentoId: 999999,
          tipo: 'DESPESA',
          descricao: 'Teste',
          valorPrevisto: 10000,
          dataPrevista: '2026-11-20',
          categoriaId: categoriaId,
        ),
        throwsA(isA<ArgumentError>()),
      );

      // TESTE 13: Cancelar lançamento manual.
      final cancelado = await service.cancelarLancamento(id);

      expect(cancelado.status, 'CANCELADO');
      expect(cancelado.descricao, 'Energia atualizada');
      expect(cancelado.valorPrevisto, 21050);

      // Confirma cancelamento no SQLite.
      final aposCancelamento = await service.buscarLancamentoPorId(id);

      expect(aposCancelamento.status, 'CANCELADO');

      // TESTE 14: Criar cartão para a fatura.
      final cartaoId = await db.insert('cartao', {
        'nome': 'Cartão Teste',
        'instituicao': 'Banco Teste',
        'limite_total': 500000,
        'dia_fechamento': 2,
        'dia_vencimento': 10,
      });

      // TESTE 15: Criar fatura.
      final faturaId = await db.insert('fatura', {
        'cartao_id': cartaoId,
        'mes_referencia': '2026-11',
        'data_fechamento': '2026-11-02',
        'data_vencimento': '2026-11-10',
        'status': 'FECHADA',
      });

      // TESTE 16: Criar lançamento de fatura.
      // O Repository é usado porque o Service
      // cadastra somente lançamentos manuais.
      final lancamentoFatura = await repository.inserir(
        LancamentoModel(
          tipo: 'DESPESA',
          descricao: 'Fatura Cartão Teste',
          valorPrevisto: 85000,
          dataPrevista: '2026-11-10',
          categoriaId: null,
          faturaId: faturaId,
          origem: 'FATURA',
        ),
      );

      final idFatura = lancamentoFatura.id!;

      // TESTE 17: Impedir edição manual de fatura.
      await expectLater(
        service.atualizarLancamento(
          lancamentoId: idFatura,
          tipo: 'DESPESA',
          descricao: 'Alteração indevida',
          valorPrevisto: 10000,
          dataPrevista: '2026-11-20',
          categoriaId: categoriaId,
        ),
        throwsA(isA<ArgumentError>()),
      );

      // TESTE 18: Impedir cancelamento de fatura.
      await expectLater(
        service.cancelarLancamento(idFatura),
        throwsA(isA<ArgumentError>()),
      );

      // TESTE 19: Confirmar preservação da fatura.
      final faturaPreservada = await service.buscarLancamentoPorId(idFatura);

      expect(faturaPreservada.origem, 'FATURA');
      expect(faturaPreservada.faturaId, faturaId);
      expect(faturaPreservada.valorPrevisto, 85000);
      expect(faturaPreservada.status, 'PENDENTE');

      // TESTE 20: Conferir a listagem final.
      final lancamentos = await service.listarLancamentos();

      expect(lancamentos.length, 2);

      // TESTE 21: Verificar integridade referencial.
      final integridade = await db.rawQuery('PRAGMA foreign_key_check;');

      expect(integridade, isEmpty);
    } finally {
      await db.close();
      await deleteDatabase(caminho);
    }
  });

  testWidgets('Valida datas no cadastro e atualizacao', (tester) async {
    final pasta = await getDatabasesPath();

    final caminho = join(pasta, 'teste_lancamento_service_datas.db');

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
      final repository = LancamentoRepository(banco: db);
      final service = LancamentoService(
        repository,
        categoriaRepository: CategoriaRepository(banco: db),
      );

      // Cria uma categoria válida para os lançamentos.
      final categoriaId = await db.insert('categoria', {
        'nome': 'Moradia',
        'tipo': 'DESPESA',
        'status': 'ATIVA',
      });

      // TESTE 1: Data válida.
      final lancamento = await service.cadastrarLancamento(
        tipo: 'DESPESA',
        descricao: 'Conta de energia',
        valorPrevisto: 18590,
        dataPrevista: '2026-11-10',
        categoriaId: categoriaId,
      );

      expect(lancamento.id, isNotNull);
      expect(lancamento.dataPrevista, '2026-11-10');

      // TESTE 2: Data válida em ano bissexto.
      final bissexto = await service.cadastrarLancamento(
        tipo: 'DESPESA',
        descricao: 'Lançamento bissexto',
        valorPrevisto: 10000,
        dataPrevista: '2028-02-29',
        categoriaId: categoriaId,
      );

      expect(bissexto.id, isNotNull);
      expect(bissexto.dataPrevista, '2028-02-29');

      // TESTE 3: Datas inválidas no cadastro.
      final datasInvalidas = [
        '2026-02-29',
        '2026-02-30',
        '2026-13-10',
        '10/11/2026',
        '2026-11-31',
        '2026-00-10',
        '2026-11-00',
        '2026-1-10',
        '',
      ];

      for (final data in datasInvalidas) {
        await expectLater(
          service.cadastrarLancamento(
            tipo: 'DESPESA',
            descricao: 'Teste de data inválida',
            valorPrevisto: 10000,
            dataPrevista: data,
            categoriaId: categoriaId,
          ),
          throwsA(isA<ArgumentError>()),
          reason: 'A data $data deveria ser rejeitada.',
        );
      }

      // TESTE 4: Atualização com data válida.
      final atualizado = await service.atualizarLancamento(
        lancamentoId: lancamento.id!,
        tipo: 'DESPESA',
        descricao: 'Energia atualizada',
        valorPrevisto: 21050,
        dataPrevista: '2026-12-15',
        categoriaId: categoriaId,
      );

      expect(atualizado.dataPrevista, '2026-12-15');

      // TESTE 5: Atualização com data inválida.
      await expectLater(
        service.atualizarLancamento(
          lancamentoId: lancamento.id!,
          tipo: 'DESPESA',
          descricao: 'Alteração indevida',
          valorPrevisto: 99999,
          dataPrevista: '2026-02-30',
          categoriaId: categoriaId,
        ),
        throwsA(isA<ArgumentError>()),
      );

      // TESTE 6: Confirmar que a atualização inválida
      // não modificou o registro no SQLite.
      final preservado = await service.buscarLancamentoPorId(lancamento.id!);

      expect(preservado.descricao, 'Energia atualizada');
      expect(preservado.valorPrevisto, 21050);
      expect(preservado.dataPrevista, '2026-12-15');

      // TESTE 7: Confirmar apenas dois registros válidos.
      final registros = await repository.listar();

      expect(registros.length, 2);

      // TESTE 8: Conferir integridade referencial.
      final integridade = await db.rawQuery('PRAGMA foreign_key_check;');

      expect(integridade, isEmpty);
    } finally {
      await db.close();
      await deleteDatabase(caminho);
    }
  });

  
  testWidgets('Valida categorias dos lancamentos', (tester) async {
    final pasta = await getDatabasesPath();

    final caminho = join(
      pasta,
      'teste_lancamento_service_categorias.db',
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
      final repository = LancamentoRepository(banco: db);

      final service = LancamentoService(
        repository,
        categoriaRepository: CategoriaRepository(banco: db),
      );

      // TESTE 1: Criar categorias ativas.
      final despesaId = await db.insert(
        'categoria',
        {
          'nome': 'Moradia',
          'tipo': 'DESPESA',
          'status': 'ATIVA',
        },
      );

      final receitaId = await db.insert(
        'categoria',
        {
          'nome': 'Trabalho',
          'tipo': 'RECEITA',
          'status': 'ATIVA',
        },
      );

      // TESTE 2: Cadastrar despesa válida.
      final despesa = await service.cadastrarLancamento(
        tipo: 'DESPESA',
        descricao: 'Conta de energia',
        valorPrevisto: 18590,
        dataPrevista: '2026-11-10',
        categoriaId: despesaId,
      );

      expect(despesa.id, isNotNull);

      // TESTE 3: Cadastrar receita válida.
      final receita = await service.cadastrarLancamento(
        tipo: 'RECEITA',
        descricao: 'Salário',
        valorPrevisto: 350000,
        dataPrevista: '2026-11-05',
        categoriaId: receitaId,
      );

      expect(receita.id, isNotNull);

      // TESTE 4: Rejeitar despesa com categoria RECEITA.
      await expectLater(
        service.cadastrarLancamento(
          tipo: 'DESPESA',
          descricao: 'Despesa incorreta',
          valorPrevisto: 10000,
          dataPrevista: '2026-11-15',
          categoriaId: receitaId,
        ),
        throwsA(isA<ArgumentError>()),
      );

      // TESTE 5: Rejeitar receita com categoria DESPESA.
      await expectLater(
        service.cadastrarLancamento(
          tipo: 'RECEITA',
          descricao: 'Receita incorreta',
          valorPrevisto: 10000,
          dataPrevista: '2026-11-15',
          categoriaId: despesaId,
        ),
        throwsA(isA<ArgumentError>()),
      );

      // TESTE 6: Rejeitar categoria inexistente.
      await expectLater(
        service.cadastrarLancamento(
          tipo: 'DESPESA',
          descricao: 'Categoria inexistente',
          valorPrevisto: 10000,
          dataPrevista: '2026-11-15',
          categoriaId: 999999,
        ),
        throwsA(isA<ArgumentError>()),
      );

      // TESTE 7: Inativar a categoria Moradia.
      await db.update(
        'categoria',
        {'status': 'INATIVA'},
        where: 'id = ?',
        whereArgs: [despesaId],
      );

      // TESTE 8: Impedir novo cadastro com categoria inativa.
      await expectLater(
        service.cadastrarLancamento(
          tipo: 'DESPESA',
          descricao: 'Nova despesa',
          valorPrevisto: 15000,
          dataPrevista: '2026-11-20',
          categoriaId: despesaId,
        ),
        throwsA(isA<ArgumentError>()),
      );

      // TESTE 9: Permitir edição mantendo a categoria original.
      final atualizado = await service.atualizarLancamento(
        lancamentoId: despesa.id!,
        tipo: 'DESPESA',
        descricao: 'Energia atualizada',
        valorPrevisto: 21050,
        dataPrevista: '2026-11-15',
        categoriaId: despesaId,
      );

      expect(atualizado.descricao, 'Energia atualizada');
      expect(atualizado.categoriaId, despesaId);
      expect(atualizado.valorPrevisto, 21050);

      // TESTE 10: Criar outra categoria inativa.
      final outraCategoriaId = await db.insert(
        'categoria',
        {
          'nome': 'Outras despesas',
          'tipo': 'DESPESA',
          'status': 'INATIVA',
        },
      );

      // TESTE 11: Impedir troca para outra categoria inativa.
      await expectLater(
        service.atualizarLancamento(
          lancamentoId: despesa.id!,
          tipo: 'DESPESA',
          descricao: 'Alteração indevida',
          valorPrevisto: 99999,
          dataPrevista: '2026-11-25',
          categoriaId: outraCategoriaId,
        ),
        throwsA(isA<ArgumentError>()),
      );

      // TESTE 12: Impedir troca para categoria de outro tipo.
      await expectLater(
        service.atualizarLancamento(
          lancamentoId: despesa.id!,
          tipo: 'DESPESA',
          descricao: 'Categoria incompatível',
          valorPrevisto: 99999,
          dataPrevista: '2026-11-25',
          categoriaId: receitaId,
        ),
        throwsA(isA<ArgumentError>()),
      );

      // TESTE 13: Verificar preservação do lançamento.
      final preservado = await service.buscarLancamentoPorId(
        despesa.id!,
      );

      expect(preservado.descricao, 'Energia atualizada');
      expect(preservado.valorPrevisto, 21050);
      expect(preservado.categoriaId, despesaId);
      expect(preservado.status, 'PENDENTE');

      // TESTE 14: Conferir quantidade de lançamentos.
      final lancamentos = await repository.listar();

      expect(lancamentos.length, 2);

      // TESTE 15: Conferir integridade referencial.
      final integridade = await db.rawQuery(
        'PRAGMA foreign_key_check;',
      );

      expect(integridade, isEmpty);
    } finally {
      await db.close();
      await deleteDatabase(caminho);
    }
  });


  testWidgets('Protege alteracoes de status dos lancamentos', (tester) async {
    final pasta = await getDatabasesPath();

    final caminho = join(
      pasta,
      'teste_lancamento_service_status.db',
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
      final repository = LancamentoRepository(banco: db);

      final service = LancamentoService(
        repository,
        categoriaRepository: CategoriaRepository(banco: db),
      );

      // TESTE 1: Criar categoria válida.
      final categoriaId = await db.insert(
        'categoria',
        {
          'nome': 'Moradia',
          'tipo': 'DESPESA',
          'status': 'ATIVA',
        },
      );

      // TESTE 2: Criar lançamento pendente.
      final lancamento = await service.cadastrarLancamento(
        tipo: 'DESPESA',
        descricao: 'Conta de energia',
        valorPrevisto: 18590,
        dataPrevista: '2026-11-10',
        categoriaId: categoriaId,
      );

      final id = lancamento.id!;

      expect(lancamento.status, 'PENDENTE');

      // TESTE 3: Permitir edição mantendo PENDENTE.
      final atualizado = await service.atualizarLancamento(
        lancamentoId: id,
        tipo: 'DESPESA',
        descricao: 'Energia atualizada',
        valorPrevisto: 21050,
        dataPrevista: '2026-11-15',
        categoriaId: categoriaId,
        status: 'PENDENTE',
      );

      expect(atualizado.descricao, 'Energia atualizada');
      expect(atualizado.valorPrevisto, 21050);
      expect(atualizado.status, 'PENDENTE');

      // TESTE 4: Impedir efetivação pela edição.
      await expectLater(
        service.atualizarLancamento(
          lancamentoId: id,
          tipo: 'DESPESA',
          descricao: 'Alteração indevida',
          valorPrevisto: 99999,
          dataPrevista: '2026-11-20',
          categoriaId: categoriaId,
          status: 'EFETIVADO',
        ),
        throwsA(isA<ArgumentError>()),
      );

      // TESTE 5: Impedir cancelamento pela edição.
      await expectLater(
        service.atualizarLancamento(
          lancamentoId: id,
          tipo: 'DESPESA',
          descricao: 'Cancelamento indevido',
          valorPrevisto: 99999,
          dataPrevista: '2026-11-20',
          categoriaId: categoriaId,
          status: 'CANCELADO',
        ),
        throwsA(isA<ArgumentError>()),
      );

      // TESTE 6: Confirmar preservação dos dados.
      final preservado = await service.buscarLancamentoPorId(id);

      expect(preservado.descricao, 'Energia atualizada');
      expect(preservado.valorPrevisto, 21050);
      expect(preservado.dataPrevista, '2026-11-15');
      expect(preservado.status, 'PENDENTE');

      // TESTE 7: Cancelar pelo método específico.
      final cancelado = await service.cancelarLancamento(id);

      expect(cancelado.status, 'CANCELADO');

      // TESTE 8: Impedir edição após cancelamento.
      await expectLater(
        service.atualizarLancamento(
          lancamentoId: id,
          tipo: 'DESPESA',
          descricao: 'Edição após cancelamento',
          valorPrevisto: 10000,
          dataPrevista: '2026-11-25',
          categoriaId: categoriaId,
        ),
        throwsA(isA<ArgumentError>()),
      );

      // TESTE 9: Impedir novo cancelamento.
      await expectLater(
        service.cancelarLancamento(id),
        throwsA(isA<ArgumentError>()),
      );

      // TESTE 10: Criar outro lançamento pendente.
      final segundo = await service.cadastrarLancamento(
        tipo: 'DESPESA',
        descricao: 'Conta de internet',
        valorPrevisto: 12000,
        dataPrevista: '2026-11-20',
        categoriaId: categoriaId,
      );

      final segundoId = segundo.id!;

      // TESTE 11: Simular um lançamento efetivado.
      // Apenas preparação de teste: o pagamento real
      // será implementado no MovimentacaoService.
      await db.update(
        'lancamento',
        {'status': 'EFETIVADO'},
        where: 'id = ?',
        whereArgs: [segundoId],
      );

      final efetivado = await service.buscarLancamentoPorId(
        segundoId,
      );

      expect(efetivado.status, 'EFETIVADO');

      // TESTE 12: Impedir edição do efetivado.
      await expectLater(
        service.atualizarLancamento(
          lancamentoId: segundoId,
          tipo: 'DESPESA',
          descricao: 'Edição indevida',
          valorPrevisto: 15000,
          dataPrevista: '2026-11-25',
          categoriaId: categoriaId,
        ),
        throwsA(isA<ArgumentError>()),
      );

      // TESTE 13: Impedir cancelamento do efetivado.
      await expectLater(
        service.cancelarLancamento(segundoId),
        throwsA(isA<ArgumentError>()),
      );

      // TESTE 14: Confirmar estados finais.
      final primeiroFinal = await service.buscarLancamentoPorId(
        id,
      );

      final segundoFinal = await service.buscarLancamentoPorId(
        segundoId,
      );

      expect(primeiroFinal.status, 'CANCELADO');
      expect(primeiroFinal.valorPrevisto, 21050);

      expect(segundoFinal.status, 'EFETIVADO');
      expect(segundoFinal.valorPrevisto, 12000);
      expect(segundoFinal.descricao, 'Conta de internet');

      // TESTE 15: Conferir quantidade de registros.
      final lancamentos = await repository.listar();

      expect(lancamentos.length, 2);

      // TESTE 16: Verificar integridade referencial.
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
