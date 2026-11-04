import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sqflite/sqflite.dart';

import 'package:controle_financeiro_android/database/database_helper.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Valida o banco SQLite Android', (tester) async {
    // Abre ou cria o banco.
    final db = await DatabaseHelper.obterBanco();

    expect(db.isOpen, isTrue);

    // Consulta as tabelas existentes.
    final resultado = await db.rawQuery('''
      SELECT name
      FROM sqlite_master
      WHERE type = 'table'
        AND name NOT LIKE 'sqlite_%'
        AND name NOT LIKE 'android_%'
      ORDER BY name
    ''');

    final tabelas = resultado.map((linha) => linha['name'] as String).toSet();

    const tabelasEsperadas = {
      'cartao',
      'categoria',
      'compra_cartao',
      'configuracao',
      'fatura',
      'lancamento',
      'meta_reserva',
      'movimentacao',
      'parcela_cartao',
      'recorrencia',
      'reserva_movimentacao',
    };

    expect(tabelas, equals(tabelasEsperadas));

    // Verifica se as chaves estrangeiras estão ativadas.
    final foreignKeys = await db.rawQuery('PRAGMA foreign_keys;');

    expect(foreignKeys.first['foreign_keys'], 1);

    // Verifica a integridade referencial existente.
    final integridade = await db.rawQuery('PRAGMA foreign_key_check;');

    expect(integridade, isEmpty);

    // Encerra a conexão.
    await DatabaseHelper.fecharBanco();
  });


  testWidgets('Valida restricoes do banco SQLite', (tester) async {
    final db = await DatabaseHelper.obterBanco();

    try {
      await db.transaction((txn) async {
        // TESTE 1: CHECK
        // O tipo OUTRO não é permitido.
        await expectLater(
          txn.insert('categoria', {
            'nome': 'Teste tipo invalido',
            'tipo': 'OUTRO',
          }),
          throwsA(isA<DatabaseException>()),
        );

        // TESTE 2: UNIQUE
        // Criamos uma categoria válida.
        final categoriaId = await txn.insert('categoria', {
          'nome': 'Categoria Teste Android',
          'tipo': 'DESPESA',
        });

        // O banco deve rejeitar uma categoria duplicada.
        await expectLater(
          txn.insert('categoria', {
            'nome': 'Categoria Teste Android',
            'tipo': 'DESPESA',
          }),
          throwsA(isA<DatabaseException>()),
        );

        // TESTE 3: FOREIGN KEY
        // Criamos um lançamento associado à categoria.
        await txn.insert('lancamento', {
          'tipo': 'DESPESA',
          'descricao': 'Lancamento de teste',
          'valor_previsto': 10000,
          'data_prevista': '2026-11-04',
          'categoria_id': categoriaId,
        });

        // A exclusão deve ser bloqueada pela chave estrangeira.
        await expectLater(
          txn.delete(
            'categoria',
            where: 'id = ?',
            whereArgs: [categoriaId],
          ),
          throwsA(isA<DatabaseException>()),
        );

        // Força rollback de todos os dados criados.
        throw const _RollbackTeste();
      });
    } on _RollbackTeste {
      // Rollback intencional do teste.
    } finally {
      await DatabaseHelper.fecharBanco();
    }
  });
}

// Exceção utilizada apenas para desfazer os dados do teste.
class _RollbackTeste implements Exception {
  const _RollbackTeste();
}



