
import 'package:flutter_test/flutter_test.dart';

import 'package:controle_financeiro_android/models/compra_cartao_model.dart';

void main() {
  group('CompraCartaoModel', () {
    // TESTE 1: Verifica os valores padrão.
    test('cria compra em 1x com valores padrão', () {
      final compra = CompraCartaoModel(
        cartaoId: 1,
        categoriaId: 2,
        descricao: 'Supermercado',
        dataCompra: '2026-11-05',
        valorTotal: 25990,
      );

      expect(compra.id, isNull);
      expect(compra.cartaoId, 1);
      expect(compra.categoriaId, 2);
      expect(compra.valorTotal, 25990);
      expect(compra.quantidadeParcelas, 1);
      expect(compra.primeiraParcelaControlada, 0);
      expect(compra.dataPrimeiraParcelaControlada, isNull);
      expect(compra.recorrenciaId, isNull);
      expect(compra.status, 'ATIVA');
      expect(compra.observacao, isNull);
    });

    // TESTE 2: Converte o objeto em Map.
    test('converte compra para Map', () {
      final compra = CompraCartaoModel(
        id: 5,
        cartaoId: 1,
        categoriaId: 2,
        descricao: 'Farmácia',
        dataCompra: '2026-11-10',
        valorTotal: 8500,
        observacao: 'Compra de medicamentos',
      );

      final map = compra.toMap();

      expect(map['id'], 5);
      expect(map['cartao_id'], 1);
      expect(map['categoria_id'], 2);
      expect(map['descricao'], 'Farmácia');
      expect(map['data_compra'], '2026-11-10');
      expect(map['valor_total'], 8500);
      expect(map['quantidade_parcelas'], 1);
      expect(map['primeira_parcela_controlada'], 0);
      expect(map['status'], 'ATIVA');
      expect(map['observacao'], 'Compra de medicamentos');
    });

    // TESTE 3: Converte Map em objeto.
    test('converte Map em CompraCartaoModel', () {
      final map = <String, dynamic>{
        'id': 8,
        'cartao_id': 3,
        'categoria_id': 4,
        'recorrencia_id': null,
        'descricao': 'Restaurante',
        'data_compra': '2026-11-12',
        'valor_total': 12050,
        'quantidade_parcelas': 1,
        'primeira_parcela_controlada': 0,
        'data_primeira_parcela_controlada': null,
        'status': 'ATIVA',
        'observacao': null,
      };

      final compra = CompraCartaoModel.fromMap(map);

      expect(compra.id, 8);
      expect(compra.cartaoId, 3);
      expect(compra.categoriaId, 4);
      expect(compra.descricao, 'Restaurante');
      expect(compra.valorTotal, 12050);
      expect(compra.quantidadeParcelas, 1);
      expect(compra.status, 'ATIVA');
      expect(compra.observacao, isNull);
    });

    // TESTE 4: Omite ID quando ainda não foi cadastrado.
    test('não inclui ID nulo no Map', () {
      final compra = CompraCartaoModel(
        cartaoId: 1,
        categoriaId: 2,
        descricao: 'Combustível',
        dataCompra: '2026-11-15',
        valorTotal: 20000,
      );

      final map = compra.toMap();

      expect(map.containsKey('id'), isFalse);
    });

    // TESTE 5: Preserva os dados na conversão completa.
    test('preserva dados ao converter para Map e voltar', () {
      final original = CompraCartaoModel(
        id: 12,
        cartaoId: 3,
        categoriaId: 5,
        descricao: 'Compra online',
        dataCompra: '2026-11-20',
        valorTotal: 49990,
        observacao: 'Pedido entregue',
      );

      final convertido = CompraCartaoModel.fromMap(
        original.toMap(),
      );

      expect(convertido.id, original.id);
      expect(convertido.cartaoId, original.cartaoId);
      expect(convertido.categoriaId, original.categoriaId);
      expect(convertido.recorrenciaId, original.recorrenciaId);
      expect(convertido.descricao, original.descricao);
      expect(convertido.dataCompra, original.dataCompra);
      expect(convertido.valorTotal, original.valorTotal);
      expect(
        convertido.quantidadeParcelas,
        original.quantidadeParcelas,
      );
      expect(
        convertido.primeiraParcelaControlada,
        original.primeiraParcelaControlada,
      );
      expect(
        convertido.dataPrimeiraParcelaControlada,
        original.dataPrimeiraParcelaControlada,
      );
      expect(convertido.status, original.status);
      expect(convertido.observacao, original.observacao);
    });

    // TESTE 6: Representa uma compra cancelada.
    test('representa compra cancelada', () {
      final compra = CompraCartaoModel(
        id: 15,
        cartaoId: 1,
        categoriaId: 2,
        descricao: 'Compra cancelada',
        dataCompra: '2026-11-22',
        valorTotal: 15000,
        status: 'CANCELADA',
      );

      expect(compra.status, 'CANCELADA');
      expect(compra.toMap()['status'], 'CANCELADA');
    });

    // TESTE 7: Preserva os campos herdados do Windows.
    test('representa campos de parcelamento existentes', () {
      final compra = CompraCartaoModel(
        id: 20,
        cartaoId: 1,
        categoriaId: 2,
        descricao: 'Compra histórica',
        dataCompra: '2026-10-15',
        valorTotal: 30000,
        quantidadeParcelas: 3,
        primeiraParcelaControlada: 1,
        dataPrimeiraParcelaControlada: '2026-10-20',
      );

      final convertido = CompraCartaoModel.fromMap(
        compra.toMap(),
      );

      expect(convertido.quantidadeParcelas, 3);
      expect(convertido.primeiraParcelaControlada, 1);
      expect(
        convertido.dataPrimeiraParcelaControlada,
        '2026-10-20',
      );
    });
  });
}
