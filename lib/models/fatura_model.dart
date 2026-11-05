
class FaturaModel {
  final int? id;
  final int cartaoId;
  final String mesReferencia;
  final String dataFechamento;
  final String dataVencimento;
  final String status;

  FaturaModel({
    this.id,
    required this.cartaoId,
    required this.mesReferencia,
    required this.dataFechamento,
    required this.dataVencimento,
    this.status = 'ABERTA',
  });

  // Converte um registro SQLite em um objeto Dart.
  factory FaturaModel.fromMap(
    Map<String, dynamic> map,
  ) {
    return FaturaModel(
      id: map['id'] as int?,
      cartaoId: map['cartao_id'] as int,
      mesReferencia: map['mes_referencia'] as String,
      dataFechamento: map['data_fechamento'] as String,
      dataVencimento: map['data_vencimento'] as String,
      status: map['status'] as String,
    );
  }

  // Converte o objeto Dart em Map para o SQLite.
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'cartao_id': cartaoId,
      'mes_referencia': mesReferencia,
      'data_fechamento': dataFechamento,
      'data_vencimento': dataVencimento,
      'status': status,
    };

    // O SQLite gera o ID quando ele ainda não existe.
    if (id != null) {
      map['id'] = id;
    }

    return map;
  }
}
