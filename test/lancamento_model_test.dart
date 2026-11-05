
import 'package:flutter_test/flutter_test.dart';

import 'package:controle_financeiro_android/models/lancamento_model.dart';

void main() {
  group('LancamentoModel', () {
    // TESTE 1: Verifica os valores padrão.
    test('cria lançamento manual pendente', () {
      final lancamento = LancamentoModel(
        tipo: 'DESPESA',
        descricao: 'Conta de energia',
        valorPrevisto: 18590,
        dataPrevista: '2026-11-10',
        categoriaId: 1,
      );

      expect(lancamento.id, isNull);
      expect(lancamento.tipo, 'DESPESA');
      expect(lancamento.valorPrevisto, 18590);
      expect(lancamento.status, 'PENDENTE');
      expect(lancamento.origem, 'MANUAL');
      expect(lancamento.recorrenciaId, isNull);
      expect(lancamento.faturaId, isNull);
    });

    // TESTE 2: Converte objeto em Map.
    test('converte lançamento para Map', () {
      final lancamento = LancamentoModel(
        id: 5,
        tipo: 'RECEITA',
        descricao: 'Salário',
        valorPrevisto: 350000,
        dataPrevista: '2026-11-05',
        categoriaId: 2,
        observacao: 'Pagamento mensal',
      );

      final map = lancamento.toMap();

      expect(map['id'], 5);
      expect(map['tipo'], 'RECEITA');
      expect(map['descricao'], 'Salário');
      expect(map['valor_previsto'], 350000);
      expect(map['data_prevista'], '2026-11-05');
      expect(map['categoria_id'], 2);
      expect(map['status'], 'PENDENTE');
      expect(map['origem'], 'MANUAL');
      expect(map['observacao'], 'Pagamento mensal');
    });

    // TESTE 3: Converte Map em objeto.
    test('converte Map em LancamentoModel', () {
      final map = <String, dynamic>{
        'id': 8,
        'tipo': 'DESPESA',
        'descricao': 'Internet',
        'valor_previsto': 12000,
        'data_prevista': '2026-11-15',
        'categoria_id': 3,
        'recorrencia_id': null,
        'fatura_id': null,
        'status': 'EFETIVADO',
        'observacao': null,
        'origem': 'MANUAL',
      };

      final lancamento = LancamentoModel.fromMap(map);

      expect(lancamento.id, 8);
      expect(lancamento.descricao, 'Internet');
      expect(lancamento.valorPrevisto, 12000);
      expect(lancamento.status, 'EFETIVADO');
      expect(lancamento.categoriaId, 3);
      expect(lancamento.observacao, isNull);
    });

    // TESTE 4: Lançamento de recorrência.
    test('representa lançamento de recorrência', () {
      final lancamento = LancamentoModel(
        tipo: 'DESPESA',
        descricao: 'Aluguel',
        valorPrevisto: 150000,
        dataPrevista: '2026-12-05',
        categoriaId: 4,
        recorrenciaId: 10,
        origem: 'RECORRENCIA',
      );

      final map = lancamento.toMap();

      expect(map['origem'], 'RECORRENCIA');
      expect(map['recorrencia_id'], 10);
      expect(map['fatura_id'], isNull);
    });

    // TESTE 5: Lançamento de fatura.
    test('representa lançamento de fatura', () {
      final lancamento = LancamentoModel(
        tipo: 'DESPESA',
        descricao: 'Fatura Nubank',
        valorPrevisto: 275050,
        dataPrevista: '2026-12-10',
        categoriaId: null,
        faturaId: 7,
        origem: 'FATURA',
      );

      final map = lancamento.toMap();

      expect(map['tipo'], 'DESPESA');
      expect(map['origem'], 'FATURA');
      expect(map['categoria_id'], isNull);
      expect(map['fatura_id'], 7);
      expect(map['valor_previsto'], 275050);
    });

    // TESTE 6: Lançamento sem ID não envia a coluna id.
    test('omite ID quando ainda não foi cadastrado', () {
      final lancamento = LancamentoModel(
        tipo: 'RECEITA',
        descricao: 'Renda extra',
        valorPrevisto: 50000,
        dataPrevista: '2026-11-20',
        categoriaId: 2,
      );

      final map = lancamento.toMap();

      expect(map.containsKey('id'), isFalse);
    });

    // TESTE 7: Confirma conversão completa.
    test('preserva os dados ao converter para Map e voltar', () {
      final original = LancamentoModel(
        id: 12,
        tipo: 'DESPESA',
        descricao: 'Mercado',
        valorPrevisto: 25990,
        dataPrevista: '2026-11-25',
        categoriaId: 3,
        status: 'CANCELADO',
        observacao: 'Compra cancelada',
      );

      final convertido = LancamentoModel.fromMap(
        original.toMap(),
      );

      expect(convertido.id, original.id);
      expect(convertido.tipo, original.tipo);
      expect(convertido.descricao, original.descricao);
      expect(convertido.valorPrevisto, original.valorPrevisto);
      expect(convertido.dataPrevista, original.dataPrevista);
      expect(convertido.categoriaId, original.categoriaId);
      expect(convertido.status, original.status);
      expect(convertido.origem, original.origem);
      expect(convertido.observacao, original.observacao);
    });
  });
}
