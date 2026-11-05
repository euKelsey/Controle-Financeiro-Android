
class CompraCartaoModel {
  final int? id;
  final int cartaoId;
  final int categoriaId;
  final int? recorrenciaId;
  final String descricao;
  final String dataCompra;
  final int valorTotal;
  final int quantidadeParcelas;
  final int primeiraParcelaControlada;
  final String? dataPrimeiraParcelaControlada;
  final String status;
  final String? observacao;

  CompraCartaoModel({
    this.id,
    required this.cartaoId,
    required this.categoriaId,
    this.recorrenciaId,
    required this.descricao,
    required this.dataCompra,
    required this.valorTotal,
    this.quantidadeParcelas = 1,
    this.primeiraParcelaControlada = 0,
    this.dataPrimeiraParcelaControlada,
    this.status = 'ATIVA',
    this.observacao,
  });

  // Converte um registro SQLite em um objeto Dart.
  factory CompraCartaoModel.fromMap(
    Map<String, dynamic> map,
  ) {
    return CompraCartaoModel(
      id: map['id'] as int?,
      cartaoId: map['cartao_id'] as int,
      categoriaId: map['categoria_id'] as int,
      recorrenciaId: map['recorrencia_id'] as int?,
      descricao: map['descricao'] as String,
      dataCompra: map['data_compra'] as String,
      valorTotal: map['valor_total'] as int,
      quantidadeParcelas: map['quantidade_parcelas'] as int,
      primeiraParcelaControlada:
          map['primeira_parcela_controlada'] as int,
      dataPrimeiraParcelaControlada:
          map['data_primeira_parcela_controlada'] as String?,
      status: map['status'] as String,
      observacao: map['observacao'] as String?,
    );
  }

  // Converte o objeto Dart em Map para o SQLite.
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'cartao_id': cartaoId,
      'categoria_id': categoriaId,
      'recorrencia_id': recorrenciaId,
      'descricao': descricao,
      'data_compra': dataCompra,
      'valor_total': valorTotal,
      'quantidade_parcelas': quantidadeParcelas,
      'primeira_parcela_controlada':
          primeiraParcelaControlada,
      'data_primeira_parcela_controlada':
          dataPrimeiraParcelaControlada,
      'status': status,
      'observacao': observacao,
    };

    if (id != null) {
      map['id'] = id;
    }

    return map;
  }
}
