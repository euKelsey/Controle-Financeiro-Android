
import 'package:flutter_test/flutter_test.dart';

import 'package:controle_financeiro_android/models/movimentacao_model.dart';

void main() {
  group('MovimentacaoModel', () {

    // TESTE 1: Cria movimentação com os campos obrigatórios.
    test('cria movimentacao sem ID', () {
      final movimentacao = MovimentacaoModel(
        lancamentoId: 1,
        valor: 18590,
        dataMovimentacao: '2026-11-09',
        forma: 'PIX',
      );

      expect(movimentacao.id, isNull);
      expect(movimentacao.lancamentoId, 1);
      expect(movimentacao.valor, 18590);
      expect(movimentacao.dataMovimentacao, '2026-11-09');
      expect(movimentacao.forma, 'PIX');
      expect(movimentacao.observacao, isNull);
    });

    // TESTE 2: Converte objeto em Map.
    test('converte movimentacao para Map', () {
      final movimentacao = MovimentacaoModel(
        id: 5,
        lancamentoId: 10,
        valor: 250050,
        dataMovimentacao: '2026-11-10',
        forma: 'TRANSFERENCIA',
        observacao: 'Pagamento confirmado',
      );

      final map = movimentacao.toMap();

      expect(map['id'], 5);
      expect(map['lancamento_id'], 10);
      expect(map['valor'], 250050);
      expect(map['data_movimentacao'], '2026-11-10');
      expect(map['forma'], 'TRANSFERENCIA');
      expect(map['observacao'], 'Pagamento confirmado');
    });

    // TESTE 3: Converte Map em objeto.
    test('converte Map em MovimentacaoModel', () {
      final map = <String, dynamic>{
        'id': 8,
        'lancamento_id': 3,
        'valor': 12000,
        'data_movimentacao': '2026-11-15',
        'forma': 'BOLETO',
        'observacao': null,
      };

      final movimentacao = MovimentacaoModel.fromMap(map);

      expect(movimentacao.id, 8);
      expect(movimentacao.lancamentoId, 3);
      expect(movimentacao.valor, 12000);
      expect(movimentacao.dataMovimentacao, '2026-11-15');
      expect(movimentacao.forma, 'BOLETO');
      expect(movimentacao.observacao, isNull);
    });

    // TESTE 4: Omite o ID antes do cadastro.
    test('nao inclui ID nulo no Map', () {
      final movimentacao = MovimentacaoModel(
        lancamentoId: 2,
        valor: 5000,
        dataMovimentacao: '2026-11-20',
        forma: 'DINHEIRO',
      );

      final map = movimentacao.toMap();

      expect(map.containsKey('id'), isFalse);
    });

    // TESTE 5: Preserva dados na conversão completa.
    test('preserva os dados ao converter para Map e voltar', () {
      final original = MovimentacaoModel(
        id: 12,
        lancamentoId: 7,
        valor: 125075,
        dataMovimentacao: '2026-11-25',
        forma: 'DEBITO',
        observacao: 'Pagamento realizado',
      );

      final convertido = MovimentacaoModel.fromMap(
        original.toMap(),
      );

      expect(convertido.id, original.id);
      expect(convertido.lancamentoId, original.lancamentoId);
      expect(convertido.valor, original.valor);
      expect(
        convertido.dataMovimentacao,
        original.dataMovimentacao,
      );
      expect(convertido.forma, original.forma);
      expect(convertido.observacao, original.observacao);
    });

    // TESTE 6: Representa todas as formas permitidas.
    test('representa formas de movimentacao', () {
      final formas = [
        'PIX',
        'DINHEIRO',
        'DEBITO',
        'TRANSFERENCIA',
        'BOLETO',
        'OUTRO',
      ];

      for (final forma in formas) {
        final movimentacao = MovimentacaoModel(
          lancamentoId: 1,
          valor: 10000,
          dataMovimentacao: '2026-11-10',
          forma: forma,
        );

        expect(movimentacao.toMap()['forma'], forma);
      }
    });
  });
}
