
class MovimentacaoModel {
  final int? id;
  final int lancamentoId;
  final int valor;
  final String dataMovimentacao;
  final String forma;
  final String? observacao;

  MovimentacaoModel({
    this.id,
    required this.lancamentoId,
    required this.valor,
    required this.dataMovimentacao,
    required this.forma,
    this.observacao,
  });

  // Converte os dados do SQLite em um objeto Dart.
  factory MovimentacaoModel.fromMap(
    Map<String, dynamic> map,
  ) {
    return MovimentacaoModel(
      id: map['id'] as int?,
      lancamentoId: map['lancamento_id'] as int,
      valor: map['valor'] as int,
      dataMovimentacao: map['data_movimentacao'] as String,
      forma: map['forma'] as String,
      observacao: map['observacao'] as String?,
    );
  }

  // Converte o objeto Dart em um Map para o SQLite.
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'lancamento_id': lancamentoId,
      'valor': valor,
      'data_movimentacao': dataMovimentacao,
      'forma': forma,
      'observacao': observacao,
    };

    if (id != null) {
      map['id'] = id;
    }

    return map;
  }
}
