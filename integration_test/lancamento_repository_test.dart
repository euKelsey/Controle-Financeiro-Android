
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'package:controle_financeiro_android/models/lancamento_model.dart';
import 'package:controle_financeiro_android/repositories/lancamento_repository.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Testa cadastro e consultas de lançamentos', (tester) async {
    // Banco exclusivo deste teste.
    final pasta = await getDatabasesPath();
    final caminho = join(pasta, 'teste_lancamento_repository.db');

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

      // TESTE 1: Criar categoria de despesa.
      final categoriaDespesaId = await db.insert(
        'categoria',
        {
          'nome': 'Moradia',
          'tipo': 'DESPESA',
          'status': 'ATIVA',
        },
      );

      // Criar categoria de receita.
      final categoriaReceitaId = await db.insert(
        'categoria',
        {
          'nome': 'Trabalho',
          'tipo': 'RECEITA',
          'status': 'ATIVA',
        },
      );

      // TESTE 2: Inserir lançamento de despesa.
      final despesa = await repository.inserir(
        LancamentoModel(
          tipo: 'DESPESA',
          descricao: 'Conta de energia',
          valorPrevisto: 18590,
          dataPrevista: '2026-11-10',
          categoriaId: categoriaDespesaId,
          observacao: 'Pagamento mensal',
        ),
      );

      expect(despesa.id, isNotNull);
      expect(despesa.id, greaterThan(0));
      expect(despesa.tipo, 'DESPESA');
      expect(despesa.status, 'PENDENTE');
      expect(despesa.origem, 'MANUAL');

      // TESTE 3: Buscar lançamento pelo ID.
      final encontrado = await repository.buscarPorId(
        despesa.id!,
      );

      expect(encontrado, isNotNull);
      expect(encontrado!.descricao, 'Conta de energia');
      expect(encontrado.valorPrevisto, 18590);
      expect(encontrado.dataPrevista, '2026-11-10');
      expect(encontrado.categoriaId, categoriaDespesaId);
      expect(encontrado.observacao, 'Pagamento mensal');

      // TESTE 4: Inserir lançamento de receita.
      final receita = await repository.inserir(
        LancamentoModel(
          tipo: 'RECEITA',
          descricao: 'Salário',
          valorPrevisto: 350000,
          dataPrevista: '2026-11-05',
          categoriaId: categoriaReceitaId,
        ),
      );

      expect(receita.id, isNotNull);
      expect(receita.id, isNot(despesa.id));

      // TESTE 5: Listar por data prevista.
      final lancamentos = await repository.listar();

      expect(lancamentos.length, 2);

      // Salário: 05/11/2026.
      expect(lancamentos[0].descricao, 'Salário');

      // Energia: 10/11/2026.
      expect(lancamentos[1].descricao, 'Conta de energia');

      // TESTE 6: Buscar ID inexistente.
      final inexistente = await repository.buscarPorId(
        999999,
      );

      expect(inexistente, isNull);

      // TESTE 7: Conferir valores em centavos.
      expect(lancamentos[0].valorPrevisto, 350000);
      expect(lancamentos[1].valorPrevisto, 18590);

      // TESTE 8: Confirmar integridade referencial.
      final integridade = await db.rawQuery(
        'PRAGMA foreign_key_check;',
      );

      expect(integridade, isEmpty);

      // TESTE 9: Confirmar os registros no SQLite.
      final registros = await db.query(
        'lancamento',
        orderBy: 'data_prevista ASC',
      );

      expect(registros.length, 2);
      expect(registros[0]['tipo'], 'RECEITA');
      expect(registros[1]['tipo'], 'DESPESA');
    } finally {
      // Fecha e remove apenas o banco temporário.
      await db.close();
      await deleteDatabase(caminho);
    }
  });

  
  testWidgets('Testa edicao, cancelamento e busca por fatura', (tester) async {
    final pasta = await getDatabasesPath();

    final caminho = join(
      pasta,
      'teste_lancamento_repository_edicao.db',
    );

    // Utiliza um banco exclusivo deste teste.
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

      // TESTE 1: Criar categoria válida.
      final categoriaId = await db.insert(
        'categoria',
        {
          'nome': 'Moradia',
          'tipo': 'DESPESA',
          'status': 'ATIVA',
        },
      );

      // TESTE 2: Cadastrar lançamento manual.
      final cadastrado = await repository.inserir(
        LancamentoModel(
          tipo: 'DESPESA',
          descricao: 'Conta de energia',
          valorPrevisto: 18590,
          dataPrevista: '2026-11-10',
          categoriaId: categoriaId,
        ),
      );

      final id = cadastrado.id!;

      expect(cadastrado.status, 'PENDENTE');

      // TESTE 3: Atualizar lançamento.
      final atualizado = LancamentoModel(
        id: id,
        tipo: 'DESPESA',
        descricao: 'Energia atualizada',
        valorPrevisto: 21050,
        dataPrevista: '2026-11-15',
        categoriaId: categoriaId,
        observacao: 'Valor corrigido',
      );

      final linhasAtualizadas = await repository.atualizar(
        atualizado,
      );

      expect(linhasAtualizadas, 1);

      // TESTE 4: Verificar persistência.
      final salvo = await repository.buscarPorId(id);

      expect(salvo, isNotNull);
      expect(salvo!.descricao, 'Energia atualizada');
      expect(salvo.valorPrevisto, 21050);
      expect(salvo.dataPrevista, '2026-11-15');
      expect(salvo.categoriaId, categoriaId);
      expect(salvo.observacao, 'Valor corrigido');
      expect(salvo.status, 'PENDENTE');

      // TESTE 5: Cancelar lançamento.
      final linhasCanceladas = await repository.cancelar(id);

      expect(linhasCanceladas, 1);

      final cancelado = await repository.buscarPorId(id);

      expect(cancelado!.status, 'CANCELADO');
      expect(cancelado.descricao, 'Energia atualizada');
      expect(cancelado.valorPrevisto, 21050);

      // TESTE 6: Atualizar ID inexistente.
      final inexistente = LancamentoModel(
        id: 999999,
        tipo: 'DESPESA',
        descricao: 'Lançamento inexistente',
        valorPrevisto: 10000,
        dataPrevista: '2026-11-20',
        categoriaId: categoriaId,
      );

      final atualizacoes = await repository.atualizar(
        inexistente,
      );

      expect(atualizacoes, 0);

      // TESTE 7: Cancelar ID inexistente.
      final cancelamentos = await repository.cancelar(999999);

      expect(cancelamentos, 0);

      // TESTE 8: Atualizar sem ID.
      final semId = LancamentoModel(
        tipo: 'DESPESA',
        descricao: 'Sem identificador',
        valorPrevisto: 10000,
        dataPrevista: '2026-11-20',
        categoriaId: categoriaId,
      );

      await expectLater(
        repository.atualizar(semId),
        throwsA(isA<ArgumentError>()),
      );

      // TESTE 9: Criar cartão para a fatura.
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

      // TESTE 10: Criar fatura válida.
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

      // TESTE 11: Criar lançamento de fatura.
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

      expect(lancamentoFatura.id, isNotNull);

      // TESTE 12: Buscar lançamento pela fatura.
      final encontradoFatura = await repository.buscarPorFaturaId(
        faturaId,
      );

      expect(encontradoFatura, isNotNull);
      expect(encontradoFatura!.id, lancamentoFatura.id);
      expect(encontradoFatura.faturaId, faturaId);
      expect(encontradoFatura.origem, 'FATURA');
      expect(encontradoFatura.tipo, 'DESPESA');
      expect(encontradoFatura.valorPrevisto, 85000);
      expect(encontradoFatura.categoriaId, isNull);

      // TESTE 13: Buscar fatura inexistente.
      final faturaInexistente =
          await repository.buscarPorFaturaId(999999);

      expect(faturaInexistente, isNull);

      // TESTE 14: Conferir os registros.
      final lancamentos = await repository.listar();

      expect(lancamentos.length, 2);

      // TESTE 15: Conferir integridade referencial.
      final integridade = await db.rawQuery(
        'PRAGMA foreign_key_check;',
      );

      expect(integridade, isEmpty);
    } finally {
      // Fecha antes de apagar o banco de teste.
      await db.close();
      await deleteDatabase(caminho);
    }
  });

}
