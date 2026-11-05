
import 'package:flutter_test/flutter_test.dart';
import 'package:controle_financeiro_android/models/cartao_model.dart';

void main() {
  group('CartaoModel', () {
    test('Cria cartão com status padrão ATIVO', () {
      final cartao = CartaoModel(
        nome: 'Cartão Principal',
        instituicao: 'Nubank',
        limiteTotal: 500000,
        diaFechamento: 2,
        diaVencimento: 10,
      );

      expect(cartao.id, isNull);
      expect(cartao.nome, 'Cartão Principal');
      expect(cartao.instituicao, 'Nubank');
      expect(cartao.limiteTotal, 500000);
      expect(cartao.diaFechamento, 2);
      expect(cartao.diaVencimento, 10);
      expect(cartao.status, 'ATIVO');
      expect(cartao.observacao, isNull);
    });

    test('Converte CartaoModel para Map', () {
      final cartao = CartaoModel(
        nome: 'Cartão Secundário',
        instituicao: 'Itaú',
        limiteTotal: 250050,
        diaFechamento: 15,
        diaVencimento: 22,
        observacao: 'Cartão de uso pessoal',
      );

      final mapa = cartao.toMap();

      expect(mapa.containsKey('id'), isFalse);
      expect(mapa['nome'], 'Cartão Secundário');
      expect(mapa['instituicao'], 'Itaú');
      expect(mapa['limite_total'], 250050);
      expect(mapa['dia_fechamento'], 15);
      expect(mapa['dia_vencimento'], 22);
      expect(mapa['status'], 'ATIVO');
      expect(mapa['observacao'], 'Cartão de uso pessoal');
    });

    test('Converte Map para CartaoModel', () {
      final mapa = <String, Object?>{
        'id': 1,
        'nome': 'Cartão Principal',
        'instituicao': 'Nubank',
        'limite_total': 500000,
        'dia_fechamento': 2,
        'dia_vencimento': 10,
        'status': 'ATIVO',
        'observacao': null,
      };

      final cartao = CartaoModel.fromMap(mapa);

      expect(cartao.id, 1);
      expect(cartao.nome, 'Cartão Principal');
      expect(cartao.instituicao, 'Nubank');
      expect(cartao.limiteTotal, 500000);
      expect(cartao.diaFechamento, 2);
      expect(cartao.diaVencimento, 10);
      expect(cartao.status, 'ATIVO');
      expect(cartao.observacao, isNull);
    });

    test('Preserva cartão inativo na conversão', () {
      final cartao = CartaoModel(
        id: 5,
        nome: 'Cartão Antigo',
        instituicao: 'Banco Teste',
        limiteTotal: 100000,
        diaFechamento: 28,
        diaVencimento: 5,
        status: 'INATIVO',
      );

      final mapa = cartao.toMap();
      final restaurado = CartaoModel.fromMap(mapa);

      expect(restaurado.id, 5);
      expect(restaurado.nome, 'Cartão Antigo');
      expect(restaurado.limiteTotal, 100000);
      expect(restaurado.diaFechamento, 28);
      expect(restaurado.diaVencimento, 5);
      expect(restaurado.status, 'INATIVO');
    });

    test('Preserva valores financeiros em centavos', () {
      final cartao = CartaoModel(
        nome: 'Cartão Teste',
        instituicao: 'Banco Teste',
        limiteTotal: 123456,
        diaFechamento: 10,
        diaVencimento: 17,
      );

      final restaurado = CartaoModel.fromMap(
        cartao.toMap(),
      );

      // R$ 1.234,56 deve continuar sendo 123456 centavos.
      expect(restaurado.limiteTotal, 123456);
      expect(restaurado.limiteTotal, isA<int>());
    });
  });
}
