import '../models/compra_cartao_model.dart';
import '../repositories/cartao_repository.dart';
import '../repositories/categoria_repository.dart';
import '../repositories/compra_cartao_repository.dart';
import 'competencia_fatura_service.dart';

class CompraCartaoService {
  final CompraCartaoRepository _repository;
  final CartaoRepository _cartaoRepository;
  final CategoriaRepository _categoriaRepository;

  CompraCartaoService(
    this._repository, {
    required this._cartaoRepository,
    required this._categoriaRepository,
  });

  // Valida uma data no formato AAAA-MM-DD.
  void _validarData(String data) {
    final formato = RegExp(r'^\d{4}-\d{2}-\d{2}$');

    if (!formato.hasMatch(data)) {
      throw ArgumentError('Informe uma data no formato AAAA-MM-DD.');
    }

    final convertida = DateTime.tryParse(data);

    if (convertida == null ||
        convertida.year.toString().padLeft(4, '0') != data.substring(0, 4) ||
        convertida.month.toString().padLeft(2, '0') != data.substring(5, 7) ||
        convertida.day.toString().padLeft(2, '0') != data.substring(8, 10)) {
      throw ArgumentError('A data da compra é inválida.');
    }
  }

  // Lista as compras cadastradas.
  Future<List<CompraCartaoModel>> listarCompras() async {
    return _repository.listar();
  }

  // Busca uma compra por ID.
  Future<CompraCartaoModel> buscarCompraPorId(int compraId) async {
    final compra = await _repository.buscarPorId(compraId);

    if (compra == null) {
      throw ArgumentError('Compra não encontrada.');
    }

    return compra;
  }

  // Cadastra uma compra em 1x no cartão de crédito.
  Future<CompraCartaoModel> cadastrarCompra({
    required int cartaoId,
    required int categoriaId,
    required String descricao,
    required String dataCompra,
    required int valorTotal,
    String? observacao,
  }) async {
    // REGRA 1: O cartão precisa existir.
    final cartao = await _cartaoRepository.buscarPorId(cartaoId);

    if (cartao == null) {
      throw ArgumentError('Cartão não encontrado.');
    }

    // REGRA 2: O cartão precisa estar ativo.
    if (cartao.status != 'ATIVO') {
      throw ArgumentError('O cartão está inativo.');
    }

    // REGRA 3: A categoria precisa existir.
    final categoria = await _categoriaRepository.buscarPorId(categoriaId);

    if (categoria == null) {
      throw ArgumentError('Categoria não encontrada.');
    }

    // REGRA 4: A categoria precisa estar ativa.
    if (categoria.status != 'ATIVA') {
      throw ArgumentError('A categoria está inativa.');
    }

    // REGRA 5: A categoria deve ser de despesa.
    if (categoria.tipo != 'DESPESA') {
      throw ArgumentError(
        'Compras no cartão precisam utilizar '
        'uma categoria de DESPESA.',
      );
    }

    // REGRA 6: A descrição é obrigatória.
    descricao = descricao.trim();

    if (descricao.isEmpty) {
      throw ArgumentError('A descrição da compra é obrigatória.');
    }

    // REGRA 7: O valor deve ser positivo.
    if (valorTotal <= 0) {
      throw ArgumentError('O valor da compra deve ser maior que zero.');
    }

    // REGRA 8: Validar a data da compra.
    _validarData(dataCompra);

    // REGRA 9: Criar o objeto da compra.
    // Na V1 Android, todas as compras são em 1x.
    final compra = CompraCartaoModel(
      cartaoId: cartaoId,
      categoriaId: categoriaId,
      descricao: descricao,
      dataCompra: dataCompra,
      valorTotal: valorTotal,
      quantidadeParcelas: 1,
      observacao: observacao,
    );

    // REGRA 10: Calcular o mês da fatura.
    final mesReferencia = CompetenciaFaturaService.calcularMesFatura(
      dataCompra: dataCompra,
      diaFechamento: cartao.diaFechamento,
    );

    // REGRA 11: Calcular fechamento e vencimento.
    final datas = CompetenciaFaturaService.calcularDatasFatura(
      mesReferencia: mesReferencia,
      diaFechamento: cartao.diaFechamento,
      diaVencimento: cartao.diaVencimento,
    );

    // REGRA 12: Cadastrar a compra com sua fatura.
    return _repository.inserirCompraComParcela(
      compra: compra,
      mesReferencia: mesReferencia,
      dataFechamento: datas.dataFechamento,
      dataVencimento: datas.dataVencimento,
    );
  }
}
