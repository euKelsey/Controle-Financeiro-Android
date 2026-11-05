
import '../models/cartao_model.dart';
import '../repositories/cartao_repository.dart';

class CartaoService {
  final CartaoRepository _repository;

  CartaoService(this._repository);

  // Valida e cadastra um novo cartão.
  Future<CartaoModel> cadastrarCartao({
    required String nome,
    required String instituicao,
    required int limiteTotal,
    required int diaFechamento,
    required int diaVencimento,
    String? observacao,
  }) async {
    // Remove espaços das extremidades.
    nome = nome.trim();
    instituicao = instituicao.trim();

    // REGRA 1: Nome obrigatório.
    if (nome.isEmpty) {
      throw ArgumentError(
        'O nome do cartão é obrigatório.',
      );
    }

    // REGRA 2: Instituição obrigatória.
    if (instituicao.isEmpty) {
      throw ArgumentError(
        'A instituição do cartão é obrigatória.',
      );
    }

    // REGRA 3: Limite não negativo.
    if (limiteTotal < 0) {
      throw ArgumentError(
        'O limite total não pode ser negativo.',
      );
    }

    // REGRA 4: Dia de fechamento válido.
    if (diaFechamento < 1 || diaFechamento > 31) {
      throw ArgumentError(
        'O dia de fechamento deve estar entre 1 e 31.',
      );
    }

    // REGRA 5: Dia de vencimento válido.
    if (diaVencimento < 1 || diaVencimento > 31) {
      throw ArgumentError(
        'O dia de vencimento deve estar entre 1 e 31.',
      );
    }

    // Cria o Model após todas as validações.
    final cartao = CartaoModel(
      nome: nome,
      instituicao: instituicao,
      limiteTotal: limiteTotal,
      diaFechamento: diaFechamento,
      diaVencimento: diaVencimento,
      observacao: observacao,
    );

    // Solicita ao Repository a gravação no SQLite.
    return _repository.inserir(cartao);
  }


  // Lista todos os cartões, inclusive os inativos.
  Future<List<CartaoModel>> listarCartoes() async {
    return _repository.listar();
  }

  // Busca um cartão e verifica se ele existe.
  Future<CartaoModel> buscarCartaoPorId(int id) async {
    final cartao = await _repository.buscarPorId(id);

    if (cartao == null) {
      throw ArgumentError('Cartão não encontrado.');
    }

    return cartao;
  }

  // Valida e atualiza os dados de um cartão existente.
  Future<CartaoModel> atualizarCartao({
    required int cartaoId,
    required String nome,
    required String instituicao,
    required int limiteTotal,
    required int diaFechamento,
    required int diaVencimento,
    String status = 'ATIVO',
    String? observacao,
  }) async {
    // Confirma que o cartão existe.
    await buscarCartaoPorId(cartaoId);

    nome = nome.trim();
    instituicao = instituicao.trim();
    status = status.trim().toUpperCase();

    if (nome.isEmpty) {
      throw ArgumentError(
        'O nome do cartão é obrigatório.',
      );
    }

    if (instituicao.isEmpty) {
      throw ArgumentError(
        'A instituição do cartão é obrigatória.',
      );
    }

    if (limiteTotal < 0) {
      throw ArgumentError(
        'O limite total não pode ser negativo.',
      );
    }

    if (diaFechamento < 1 || diaFechamento > 31) {
      throw ArgumentError(
        'O dia de fechamento deve estar entre 1 e 31.',
      );
    }

    if (diaVencimento < 1 || diaVencimento > 31) {
      throw ArgumentError(
        'O dia de vencimento deve estar entre 1 e 31.',
      );
    }

    if (status != 'ATIVO' && status != 'INATIVO') {
      throw ArgumentError(
        'O status deve ser ATIVO ou INATIVO.',
      );
    }

    final atualizado = CartaoModel(
      id: cartaoId,
      nome: nome,
      instituicao: instituicao,
      limiteTotal: limiteTotal,
      diaFechamento: diaFechamento,
      diaVencimento: diaVencimento,
      status: status,
      observacao: observacao,
    );

    final linhas = await _repository.atualizar(atualizado);

    if (linhas == 0) {
      throw StateError('Não foi possível atualizar o cartão.');
    }

    return atualizado;
  }

  // Inativa um cartão preservando seu histórico.
  Future<CartaoModel> inativarCartao(int cartaoId) async {
    await buscarCartaoPorId(cartaoId);

    final linhas = await _repository.inativar(cartaoId);

    if (linhas == 0) {
      throw StateError('Não foi possível inativar o cartão.');
    }

    return buscarCartaoPorId(cartaoId);
  }

  // Reativa um cartão anteriormente inativado.
  Future<CartaoModel> reativarCartao(int cartaoId) async {
    await buscarCartaoPorId(cartaoId);

    final linhas = await _repository.reativar(cartaoId);

    if (linhas == 0) {
      throw StateError('Não foi possível reativar o cartão.');
    }

    return buscarCartaoPorId(cartaoId);
  }

}
