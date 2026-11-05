
import 'package:flutter_test/flutter_test.dart';

import 'package:controle_financeiro_android/models/fatura_model.dart';

void main() {
  group('FaturaModel', () {
    // TESTE 1: Confirma os valores padrão.
    test('cria fatura aberta por padrão', () {
      final fatura = FaturaModel(
        cartaoId: 1,
        mesReferencia: '2026-11',
        dataFechamento: '2026-11-10',
        dataVencimento: '2026-11-20',
      );

      expect(fatura.id, isNull);
      expect(fatura.cartaoId, 1);
      expect(fatura.mesReferencia, '2026-11');
      expect(fatura.dataFechamento, '2026-11-10');
      expect(fatura.dataVencimento, '2026-11-20');
      expect(fatura.status, 'ABERTA');
    });

    // TESTE 2: Converte o objeto para Map.
    test('converte FaturaModel para Map', () {
      final fatura = FaturaModel(
        id: 5,
        cartaoId: 2,
        mesReferencia: '2026-12',
        dataFechamento: '2026-12-15',
        dataVencimento: '2027-01-05',
        status: 'FECHADA',
      );

      final map = fatura.toMap();

      expect(map['id'], 5);
      expect(map['cartao_id'], 2);
      expect(map['mes_referencia'], '2026-12');
      expect(map['data_fechamento'], '2026-12-15');
      expect(map['data_vencimento'], '2027-01-05');
      expect(map['status'], 'FECHADA');
    });

    // TESTE 3: Converte Map para objeto.
    test('converte Map em FaturaModel', () {
      final map = <String, dynamic>{
        'id': 8,
        'cartao_id': 3,
        'mes_referencia': '2027-01',
        'data_fechamento': '2027-01-10',
        'data_vencimento': '2027-01-20',
        'status': 'ABERTA',
      };

      final fatura = FaturaModel.fromMap(map);

      expect(fatura.id, 8);
      expect(fatura.cartaoId, 3);
      expect(fatura.mesReferencia, '2027-01');
      expect(fatura.dataFechamento, '2027-01-10');
      expect(fatura.dataVencimento, '2027-01-20');
      expect(fatura.status, 'ABERTA');
    });

    // TESTE 4: Omite o ID antes do cadastro.
    test('não inclui ID nulo no Map', () {
      final fatura = FaturaModel(
        cartaoId: 1,
        mesReferencia: '2027-02',
        dataFechamento: '2027-02-15',
        dataVencimento: '2027-02-25',
      );

      final map = fatura.toMap();

      expect(map.containsKey('id'), isFalse);
    });

    // TESTE 5: Preserva os dados na conversão completa.
    test('preserva os dados ao converter para Map e voltar', () {
      final original = FaturaModel(
        id: 12,
        cartaoId: 4,
        mesReferencia: '2027-03',
        dataFechamento: '2027-03-25',
        dataVencimento: '2027-04-05',
        status: 'FECHADA',
      );

      final convertido = FaturaModel.fromMap(
        original.toMap(),
      );

      expect(convertido.id, original.id);
      expect(convertido.cartaoId, original.cartaoId);
      expect(convertido.mesReferencia, original.mesReferencia);
      expect(convertido.dataFechamento, original.dataFechamento);
      expect(convertido.dataVencimento, original.dataVencimento);
      expect(convertido.status, original.status);
    });

    // TESTE 6: Representa uma fatura fechada.
    test('representa fatura com status FECHADA', () {
      final fatura = FaturaModel(
        id: 15,
        cartaoId: 1,
        mesReferencia: '2026-10',
        dataFechamento: '2026-10-10',
        dataVencimento: '2026-10-20',
        status: 'FECHADA',
      );

      expect(fatura.status, 'FECHADA');
      expect(fatura.toMap()['status'], 'FECHADA');
    });
  });
}
