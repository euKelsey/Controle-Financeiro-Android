
class CartaoModel {
  final int? id;
  final String nome;
  final String instituicao;
  final int limiteTotal;
  final int diaFechamento;
  final int diaVencimento;
  final String status;
  final String? observacao;

  CartaoModel({
    this.id,
    required this.nome,
    required this.instituicao,
    required this.limiteTotal,
    required this.diaFechamento,
    required this.diaVencimento,
    this.status = 'ATIVO',
    this.observacao,
  });

  // Converte os dados do SQLite em um objeto Dart.
  factory CartaoModel.fromMap(Map<String, Object?> map) {
    return CartaoModel(
      id: map['id'] as int?,
      nome: map['nome'] as String,
      instituicao: map['instituicao'] as String,
      limiteTotal: map['limite_total'] as int,
      diaFechamento: map['dia_fechamento'] as int,
      diaVencimento: map['dia_vencimento'] as int,
      status: map['status'] as String,
      observacao: map['observacao'] as String?,
    );
  }

  // Converte o objeto Dart para os campos do SQLite.
  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'nome': nome,
      'instituicao': instituicao,
      'limite_total': limiteTotal,
      'dia_fechamento': diaFechamento,
      'dia_vencimento': diaVencimento,
      'status': status,
      'observacao': observacao,
    };
  }
}
