
class CategoriaModel {
  final int? id;
  final String nome;
  final String tipo;
  final String? descricao;
  final String status;

  CategoriaModel({
    this.id,
    required this.nome,
    required this.tipo,
    this.descricao,
    this.status = 'ATIVA',
  });

  // Converte os dados do SQLite em um objeto CategoriaModel.
  factory CategoriaModel.fromMap(Map<String, Object?> map) {
    return CategoriaModel(
      id: map['id'] as int?,
      nome: map['nome'] as String,
      tipo: map['tipo'] as String,
      descricao: map['descricao'] as String?,
      status: map['status'] as String,
    );
  }

  // Converte o objeto em dados para o SQLite.
  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'nome': nome,
      'tipo': tipo,
      'descricao': descricao,
      'status': status,
    };
  }
}
