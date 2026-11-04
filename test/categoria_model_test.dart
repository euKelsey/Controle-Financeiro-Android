
import 'package:flutter_test/flutter_test.dart';
import 'package:controle_financeiro_android/models/categoria_model.dart';

void main() {
  group('CategoriaModel', () {
    test('Cria categoria com status padrão ATIVA', () {
      final categoria = CategoriaModel(
        nome: 'Alimentação',
        tipo: 'DESPESA',
      );

      expect(categoria.id, isNull);
      expect(categoria.nome, 'Alimentação');
      expect(categoria.tipo, 'DESPESA');
      expect(categoria.descricao, isNull);
      expect(categoria.status, 'ATIVA');
    });

    test('Converte CategoriaModel para Map', () {
      final categoria = CategoriaModel(
        nome: 'Transporte',
        tipo: 'DESPESA',
        descricao: 'Gastos com transporte',
      );

      final mapa = categoria.toMap();

      expect(mapa['nome'], 'Transporte');
      expect(mapa['tipo'], 'DESPESA');
      expect(mapa['descricao'], 'Gastos com transporte');
      expect(mapa['status'], 'ATIVA');

      // Sem ID, o campo não deve aparecer no Map.
      expect(mapa.containsKey('id'), isFalse);
    });

    test('Converte Map para CategoriaModel', () {
      final mapa = <String, Object?>{
        'id': 1,
        'nome': 'Salário',
        'tipo': 'RECEITA',
        'descricao': 'Salário mensal',
        'status': 'ATIVA',
      };

      final categoria = CategoriaModel.fromMap(mapa);

      expect(categoria.id, 1);
      expect(categoria.nome, 'Salário');
      expect(categoria.tipo, 'RECEITA');
      expect(categoria.descricao, 'Salário mensal');
      expect(categoria.status, 'ATIVA');
    });

    test('Preserva categoria inativa na conversão', () {
      final categoria = CategoriaModel(
        id: 5,
        nome: 'Lazer',
        tipo: 'DESPESA',
        status: 'INATIVA',
      );

      final mapa = categoria.toMap();
      final restaurada = CategoriaModel.fromMap(mapa);

      expect(restaurada.id, 5);
      expect(restaurada.nome, 'Lazer');
      expect(restaurada.status, 'INATIVA');
      expect(restaurada.descricao, isNull);
    });
  });
}
