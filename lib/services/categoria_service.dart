import '../models/categoria_model.dart';
import '../repositories/categoria_repository.dart';

class CategoriaService {
  final CategoriaRepository _repository;

  CategoriaService(this._repository);

  // Valida e cadastra uma nova categoria.
  Future<CategoriaModel> cadastrarCategoria({
    required String nome,
    required String tipo,
    String? descricao,
  }) async {
    // Remove espaços extras das extremidades.
    nome = nome.trim();

    // Padroniza o tipo em letras maiúsculas.
    tipo = tipo.trim().toUpperCase();

    // REGRA 1: nome obrigatório.
    if (nome.isEmpty) {
      throw ArgumentError('O nome da categoria é obrigatório.');
    }

    // REGRA 2: tipos permitidos.
    if (tipo != 'RECEITA' && tipo != 'DESPESA') {
      throw ArgumentError('O tipo da categoria deve ser RECEITA ou DESPESA.');
    }

    // REGRA 3: impedir nome e tipo duplicados.
    final existente = await _repository.buscarPorNomeTipo(nome, tipo);

    if (existente != null) {
      throw ArgumentError('Já existe uma categoria com esse nome e tipo.');
    }

    // Cria o objeto após passar pelas validações.
    final categoria = CategoriaModel(
      nome: nome,
      tipo: tipo,
      descricao: descricao,
    );

    // Solicita ao Repository a gravação no SQLite.
    return _repository.inserir(categoria);
  }

  // Lista todas as categorias, inclusive inativas.
  Future<List<CategoriaModel>> listarCategorias() async {
    return _repository.listar();
  }

  // Lista somente categorias ativas.
  Future<List<CategoriaModel>> listarCategoriasAtivas() async {
    return _repository.listarAtivas();
  }

  // Busca uma categoria pelo ID.
  Future<CategoriaModel?> buscarCategoriaPorId(int id) async {
    return _repository.buscarPorId(id);
  }

  // Atualiza os dados de uma categoria existente.
  Future<CategoriaModel> atualizarCategoria({
    required int categoriaId,
    required String nome,
    required String tipo,
    String? descricao,
    String status = 'ATIVA',
  }) async {
    // Verifica se a categoria existe.
    final categoriaAtual = await _repository.buscarPorId(categoriaId);

    if (categoriaAtual == null) {
      throw ArgumentError('Categoria não encontrada.');
    }

    // Padroniza os dados.
    nome = nome.trim();
    tipo = tipo.trim().toUpperCase();
    status = status.trim().toUpperCase();

    // REGRA 1: nome obrigatório.
    if (nome.isEmpty) {
      throw ArgumentError('O nome da categoria é obrigatório.');
    }

    // REGRA 2: tipo permitido.
    if (tipo != 'RECEITA' && tipo != 'DESPESA') {
      throw ArgumentError('O tipo da categoria deve ser RECEITA ou DESPESA.');
    }

    // REGRA 3: status permitido.
    if (status != 'ATIVA' && status != 'INATIVA') {
      throw ArgumentError('O status deve ser ATIVA ou INATIVA.');
    }

    // REGRA 4: impedir duplicidade com outra categoria.
    final existente = await _repository.buscarPorNomeTipo(nome, tipo);

    if (existente != null && existente.id != categoriaId) {
      throw ArgumentError('Já existe uma categoria com esse nome e tipo.');
    }

    // Cria a versão atualizada do objeto.
    final categoriaAtualizada = CategoriaModel(
      id: categoriaId,
      nome: nome,
      tipo: tipo,
      descricao: descricao,
      status: status,
    );

    // Atualiza o registro no SQLite.
    final linhasAtualizadas = await _repository.atualizar(categoriaAtualizada);

    if (linhasAtualizadas == 0) {
      throw StateError('Não foi possível atualizar a categoria.');
    }

    return categoriaAtualizada;
  }

  // Inativa uma categoria sem excluí-la.
  Future<CategoriaModel> inativarCategoria(int categoriaId) async {
    final categoria = await _repository.buscarPorId(categoriaId);

    if (categoria == null) {
      throw ArgumentError('Categoria não encontrada.');
    }

    await _repository.inativar(categoriaId);

    final atualizada = await _repository.buscarPorId(categoriaId);

    if (atualizada == null) {
      throw StateError('Não foi possível consultar a categoria.');
    }

    return atualizada;
  }
}
