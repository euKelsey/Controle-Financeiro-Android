import 'package:flutter/material.dart';
import '../models/cartao_model.dart';
import '../repositories/cartao_repository.dart';
import '../repositories/fatura_repository.dart';
import '../repositories/lancamento_repository.dart';
import '../repositories/movimentacao_repository.dart';
import '../services/cartao_service.dart';
import '../services/fatura_service.dart';
import '../theme/app_theme.dart';
import 'cartao_form_screen.dart';
import 'compra_cartao_form_screen.dart';
import '../models/compra_cartao_model.dart';
import '../repositories/compra_cartao_repository.dart';
import '../repositories/categoria_repository.dart';
import '../services/compra_cartao_service.dart';

class CartoesScreen extends StatefulWidget {
  final CartaoService? cartaoService;
  final FaturaService? faturaService;
  final FaturaRepository? faturaRepository;
  final CompraCartaoService? compraService;

  const CartoesScreen({
    super.key,
    this.cartaoService,
    this.faturaService,
    this.faturaRepository,
    this.compraService,
  });

  @override
  State<CartoesScreen> createState() => _CartoesScreenState();
}

class _CartoesScreenState extends State<CartoesScreen> {
  late final CartaoService _cartaoService;
  late final CompraCartaoService _compraService;
  late final FaturaService _faturaService;
  late final FaturaRepository _faturaRepository;
  late Future<List<CartaoModel>> _cartoes;
  late Future<List<FaturaResumoDashboard>> _faturas;
  late int _ano;
  late int _mes;
  bool _pagando = false;

  static const meses = [
    'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
    'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro',
  ];

  @override
  void initState() {
    super.initState();
    final hoje = DateTime.now();
    _ano = hoje.year;
    _mes = hoje.month;
    _cartaoService = widget.cartaoService ?? CartaoService(CartaoRepository());
    _faturaRepository = widget.faturaRepository ?? FaturaRepository();
    _faturaService = widget.faturaService ?? FaturaService(
      _faturaRepository,
      lancamentoRepository: LancamentoRepository(),
      movimentacaoRepository: MovimentacaoRepository(),
    );
    _compraService = widget.compraService ?? CompraCartaoService(
      CompraCartaoRepository(),
      cartaoRepository: CartaoRepository(),
      categoriaRepository: CategoriaRepository(),
    );
    _consultar();
  }

  void _consultar() {
    _cartoes = _cartaoService.listarCartoes();
    _faturas = _faturaRepository.listarResumoDashboard(
      ano: _ano, mes: _mes, limite: 50,
    );
  }

  void _atualizar() => setState(_consultar);

  Future<void> _atualizarPorGesto() async {
    setState(_consultar);
    try {
      await Future.wait([_cartoes, _faturas]);
    } catch (_) {
      // Erros aparecem nos FutureBuilders.
    }
  }

  void _mudarMes(int deslocamento) {
    final novo = DateTime(_ano, _mes + deslocamento);
    if (novo.year < 1 || novo.year > 9999) return;
    setState(() {
      _ano = novo.year;
      _mes = novo.month;
      _consultar();
    });
  }

  String _isoHoje() {
    final hoje = DateTime.now();
    return '${hoje.year.toString().padLeft(4, '0')}-'
        '${hoje.month.toString().padLeft(2, '0')}-'
        '${hoje.day.toString().padLeft(2, '0')}';
  }

  String _data(String iso) {
    final partes = iso.split('-');
    return partes.length == 3
        ? '${partes[2]}/${partes[1]}/${partes[0]}' : iso;
  }

  String _moeda(int valor) {
    final inteiro = (valor.abs() ~/ 100).toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.',
    );
    return '${valor < 0 ? '-' : ''}R\$ $inteiro,${(valor.abs() % 100).toString().padLeft(2, '0')}';
  }

  String _situacao(String situacao) {
    switch (situacao) {
      case 'ABERTA': return 'Aberta';
      case 'PENDENTE': return 'Pendente';
      case 'PAGA': return 'Paga';
      case 'CANCELADA': return 'Cancelada';
      default: return 'Fechada';
    }
  }

  Future<void> _pagarFatura(FaturaResumoDashboard fatura) async {
    String forma = 'PIX';
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, mudarDialogo) => AlertDialog(
          title: const Text('Confirmar pagamento'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(fatura.cartaoNome),
              Text('Valor integral: ${_moeda(fatura.valorTotal)}'),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: forma,
                decoration: const InputDecoration(labelText: 'Forma de pagamento'),
                items: const [
                  DropdownMenuItem(value: 'PIX', child: Text('PIX')),
                  DropdownMenuItem(value: 'DINHEIRO', child: Text('Dinheiro')),
                  DropdownMenuItem(value: 'DEBITO', child: Text('Débito')),
                  DropdownMenuItem(value: 'TRANSFERENCIA', child: Text('Transferência')),
                  DropdownMenuItem(value: 'BOLETO', child: Text('Boleto')),
                  DropdownMenuItem(value: 'OUTRO', child: Text('Outro')),
                ],
                onChanged: (valor) {
                  if (valor != null) mudarDialogo(() => forma = valor);
                },
              ),
              const SizedBox(height: 12),
              const Text('Data do pagamento: hoje.'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Voltar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Confirmar pagamento'),
            ),
          ],
        ),
      ),
    );
    if (confirmar != true || !mounted || _pagando) return;
    setState(() => _pagando = true);
    try {
      await _faturaService.pagarFatura(
        faturaId: fatura.id,
        dataPagamento: _isoHoje(),
        forma: forma,
      );
      if (mounted) {
        _atualizar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pagamento registrado com sucesso.')),
        );
      }
    } catch (erro) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível pagar a fatura: $erro')),
        );
      }
    } finally {
      if (mounted) setState(() => _pagando = false);
    }
  }

  Future<void> _novaCompra() async {
    final mudou = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CompraCartaoFormScreen(service: _compraService),
      ),
    );
    if (mudou == true && mounted) _atualizar();
  }

  Future<void> _verCompras() async {
    final compras = _compraService.listarCompras();
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Compras no cartão')),
          body: FutureBuilder<List<CompraCartaoModel>>(
            future: compras,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(child: Text('Não foi possível carregar as compras.'));
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final lista = snapshot.data!;
              if (lista.isEmpty) {
                return const Center(child: Text('Nenhuma compra cadastrada.'));
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: lista.length,
                itemBuilder: (context, i) {
                  final compra = lista[i];
                  return Card(
                    child: ListTile(
                      title: Text(compra.descricao),
                      subtitle: Text(
                        '${_data(compra.dataCompra)} · ${compra.quantidadeParcelas}x'
                        ' · ${compra.status == 'ATIVA' ? 'Ativa' : 'Cancelada'}',
                      ),
                      trailing: Text(_moeda(compra.valorTotal)),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _abrirFormulario([CartaoModel? cartao]) async {
    final mudou = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CartaoFormScreen(
          service: _cartaoService,
          cartao: cartao,
        ),
      ),
    );
    if (mudou == true && mounted) _atualizar();
  }

  Future<void> _alterarStatus(CartaoModel cartao) async {
    final inativar = cartao.status == 'ATIVO';
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(inativar ? 'Inativar cartão?' : 'Reativar cartão?'),
        content: Text(
          inativar
              ? 'O cartão será inativado sem apagar suas faturas e histórico.'
              : 'O cartão voltará a ficar disponível para novas compras.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Voltar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(inativar ? 'Confirmar inativação' : 'Confirmar reativação'),
          ),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;
    try {
      if (inativar) {
        await _cartaoService.inativarCartao(cartao.id!);
      } else {
        await _cartaoService.reativarCartao(cartao.id!);
      }
      if (mounted) _atualizar();
    } catch (erro) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível alterar o cartão: $erro')),
        );
      }
    }
  }

  Widget _linhaCartao(CartaoModel cartao) {
    final cores = Theme.of(context).colorScheme;
    return Card(
      child: ListTile(
        leading: Icon(Icons.credit_card, color: cores.onSurfaceVariant),
        title: Text(cartao.nome),
        subtitle: Text(
          '${cartao.instituicao} · Fecha dia ${cartao.diaFechamento} '
          '· Vence dia ${cartao.diaVencimento}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(_moeda(cartao.limiteTotal)),
                Text(
                  cartao.status == 'ATIVO' ? 'Ativo' : 'Inativo',
                  style: TextStyle(
                    color: cartao.status == 'ATIVO'
                        ? AppTheme.corReceita(context) : cores.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            PopupMenuButton<String>(
              tooltip: 'Ações do cartão ${cartao.nome}',
              onSelected: (acao) {
                if (acao == 'editar') {
                  _abrirFormulario(cartao);
                } else if (acao == 'status') {
                  _alterarStatus(cartao);
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'editar', child: Text('Editar cartão')),
                PopupMenuItem(
                  value: 'status',
                  child: Text(cartao.status == 'ATIVO'
                      ? 'Inativar cartão' : 'Reativar cartão'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _linhaFatura(FaturaResumoDashboard fatura) {
    final situacao = fatura.situacaoPagamento;
    final cores = Theme.of(context).colorScheme;
    final podePagar = situacao == 'PENDENTE' &&
        fatura.statusFatura == 'FECHADA' && fatura.valorTotal > 0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(fatura.cartaoNome,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                Text(_moeda(fatura.valorTotal)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Vencimento: ${_data(fatura.dataVencimento)} · ${_situacao(situacao)}',
              style: TextStyle(
                color: situacao == 'PAGA'
                    ? AppTheme.corReceita(context) : cores.onSurfaceVariant,
              ),
            ),
            if (podePagar) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: _pagando ? null : () => _pagarFatura(fatura),
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Pagar fatura'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return RefreshIndicator(
      onRefresh: _atualizarPorGesto,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(child: Text('Cartões',
                style: textos.headlineSmall?.copyWith(fontWeight: FontWeight.bold))),
              IconButton(
                onPressed: () => _abrirFormulario(),
                tooltip: 'Novo cartão',
                icon: const Icon(Icons.add_circle_outline),
              ),
              IconButton(
                onPressed: _atualizar,
                tooltip: 'Atualizar cartões e faturas',
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: _novaCompra,
                icon: const Icon(Icons.shopping_cart_outlined),
                label: const Text('Nova compra'),
              ),
              OutlinedButton(
                onPressed: _verCompras,
                child: const Text('Ver compras'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Meus cartões', style: textos.titleLarge),
          const SizedBox(height: 12),
          FutureBuilder<List<CartaoModel>>(
            future: _cartoes,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return const Text('Não foi possível carregar os cartões.');
              }
              final cartoes = snapshot.data ?? [];
              if (cartoes.isEmpty) return const Text('Nenhum cartão cadastrado.');
              return Column(children: [
                for (final cartao in cartoes) ...[
                  _linhaCartao(cartao), const SizedBox(height: 8),
                ],
              ]);
            },
          ),
          const SizedBox(height: 24),
          Text('Faturas', style: textos.titleLarge),
          const SizedBox(height: 12),
          Card(child: Row(children: [
            IconButton(
              tooltip: 'Mês anterior',
              onPressed: () => _mudarMes(-1),
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Text('${meses[_mes - 1]} de $_ano', textAlign: TextAlign.center),
            ),
            IconButton(
              tooltip: 'Próximo mês',
              onPressed: () => _mudarMes(1),
              icon: const Icon(Icons.chevron_right),
            ),
          ])),
          const SizedBox(height: 12),
          FutureBuilder<List<FaturaResumoDashboard>>(
            future: _faturas,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return const Text('Não foi possível carregar as faturas.');
              }
              final faturas = snapshot.data ?? [];
              if (faturas.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Nenhuma fatura neste período.'),
                );
              }
              return Column(children: [
                for (final fatura in faturas) ...[
                  _linhaFatura(fatura), const SizedBox(height: 8),
                ],
                if (faturas.length == 50)
                  const Text('Exibindo até 50 faturas neste período.'),
              ]);
            },
          ),
        ],
      ),
    );
  }
}
