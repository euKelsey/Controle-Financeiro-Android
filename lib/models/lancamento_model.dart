
class LancamentoModel {
  final int? id;
  final String tipo;
  final String descricao;
  final int valorPrevisto;
  final String dataPrevista;
  final int? categoriaId;
  final int? recorrenciaId;
  final int? faturaId;
  final String status;
  final String? observacao;
  final String origem;

  LancamentoModel({
    this.id,
    required this.tipo,
    required this.descricao,
    required this.valorPrevisto,
    required this.dataPrevista,
    required this.categoriaId,
    this.recorrenciaId,
    this.faturaId,
    this.status = 'PENDENTE',
    this.observacao,
    this.origem = 'MANUAL',
  });

  // Converte um registro do SQLite em objeto Dart.
  factory LancamentoModel.fromMap(Map<String, dynamic> map) {
    return LancamentoModel(
      id: map['id'] as int?,
      tipo: map['tipo'] as String,
      descricao: map['descricao'] as String,
      valorPrevisto: map['valor_previsto'] as int,
      dataPrevista: map['data_prevista'] as String,
      categoriaId: map['categoria_id'] as int?,
      recorrenciaId: map['recorrencia_id'] as int?,
      faturaId: map['fatura_id'] as int?,
      status: map['status'] as String,
      observacao: map['observacao'] as String?,
      origem: map['origem'] as String,
    );
  }

  // Converte o objeto Dart em um Map para o SQLite.
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'tipo': tipo,
      'descricao': descricao,
      'valor_previsto': valorPrevisto,
      'data_prevista': dataPrevista,
      'categoria_id': categoriaId,
      'recorrencia_id': recorrenciaId,
      'fatura_id': faturaId,
      'status': status,
      'observacao': observacao,
      'origem': origem,
    };

    if (id != null) {
      map['id'] = id;
    }

    return map;
  }
}
