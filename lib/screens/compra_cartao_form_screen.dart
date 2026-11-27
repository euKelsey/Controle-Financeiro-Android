import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/cartao_model.dart';
import '../models/compra_cartao_model.dart';
import '../models/categoria_model.dart';
import '../services/compra_cartao_service.dart';

class CompraCartaoFormScreen extends StatefulWidget {
  final CompraCartaoService service;
  final CompraCartaoModel? compra;
  const CompraCartaoFormScreen({super.key, required this.service, this.compra});

  @override
  State<CompraCartaoFormScreen> createState() => _CompraCartaoFormScreenState();
}

class _CompraCartaoFormScreenState extends State<CompraCartaoFormScreen> {
  final _form = GlobalKey<FormState>();
  final _descricao = TextEditingController();
  final _valor = TextEditingController();
  final _data = TextEditingController();
  final _observacao = TextEditingController();
  int? _cartaoId;
  int? _categoriaId;
  bool _salvando = false;
  late final Future<List<CartaoModel>> _cartoes;
  late final Future<List<CategoriaModel>> _categorias;

  @override
  void initState() {
    super.initState();
    final hoje = DateTime.now();
    _data.text = '${hoje.day.toString().padLeft(2, '0')}/'
        '${hoje.month.toString().padLeft(2, '0')}/${hoje.year.toString().padLeft(4, '0')}';
    final compra = widget.compra;
    if (compra != null) {
      _cartaoId = compra.cartaoId;
      _categoriaId = compra.categoriaId;
      _descricao.text = compra.descricao;
      _valor.text = '${compra.valorTotal ~/ 100},${(compra.valorTotal % 100).toString().padLeft(2, '0')}';
      _data.text = compra.dataCompra.split('-').reversed.join('/');
      _observacao.text = compra.observacao ?? '';
    }
    _cartoes = widget.service.listarCartoesFormulario(cartaoAtualId: compra?.cartaoId);
    _categorias = widget.service.listarCategoriasFormulario(categoriaAtualId: compra?.categoriaId);
  }

  int? _centavos(String texto) {
    final v = texto.trim();
    if (!RegExp(r'^(\d+|\d{1,3}(\.\d{3})+)(,\d{1,2})?$').hasMatch(v)) {
      return null;
    }
    final partes = v.replaceAll('.', '').split(',');
    final reais = int.tryParse(partes[0]);
    if (reais == null || reais > 92233720368547757) return null;
    final centavos = partes.length == 2
        ? int.parse(partes[1].padRight(2, '0')) : 0;
    if (reais == 92233720368547757 && centavos > 7) return null;
    return reais * 100 + centavos;
  }

  String? _iso(String texto) {
    if (!RegExp(r'^\d{2}/\d{2}/\d{4}$').hasMatch(texto)) return null;
    final p = texto.split('/');
    final iso = '${p[2]}-${p[1]}-${p[0]}';
    final d = DateTime.tryParse(iso);
    if (d == null || d.year < 1 || d.year != int.parse(p[2]) ||
        d.month != int.parse(p[1]) || d.day != int.parse(p[0])) return null;
    return iso;
  }

  Future<void> _selecionarData() async {
    final partes = _data.text.split('/');
    final inicial = partes.length == 3
        ? DateTime.tryParse(partes.reversed.join('-')) : null;
    final escolhida = await showDatePicker(
      context: context,
      initialDate: inicial ?? DateTime.now(),
      firstDate: DateTime(1),
      lastDate: DateTime(9999, 12, 31),
      initialEntryMode: DatePickerEntryMode.calendarOnly,
    );
    if (escolhida != null && mounted) {
      setState(() {
        _data.text = '${escolhida.day.toString().padLeft(2, '0')}/'
            '${escolhida.month.toString().padLeft(2, '0')}/'
            '${escolhida.year.toString().padLeft(4, '0')}';
      });
    }
  }

  Future<void> _salvar() async {
    if (_salvando || !_form.currentState!.validate()) return;
    if (_cartaoId == null || _categoriaId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione cartão e categoria.')),
      );
      return;
    }
    setState(() => _salvando = true);
    try {
      if (widget.compra != null) {
        await widget.service.atualizarCompra(
          compraId: widget.compra!.id!,
          categoriaId: _categoriaId!,
          descricao: _descricao.text,
          dataCompra: _iso(_data.text)!,
          valorTotal: _centavos(_valor.text)!,
          observacao: _observacao.text.trim(),
        );
      } else {
        await widget.service.cadastrarCompra(
        cartaoId: _cartaoId!,
        categoriaId: _categoriaId!,
        descricao: _descricao.text,
        dataCompra: _iso(_data.text)!,
        valorTotal: _centavos(_valor.text)!,
        observacao: _observacao.text.trim(),
      );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (erro) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível registrar a compra: $erro')),
      );
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  void dispose() {
    _descricao.dispose();
    _valor.dispose();
    _data.dispose();
    _observacao.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.compra == null ? 'Nova compra no cartão' : 'Editar compra')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Compra em 1x · Fatura vinculada automaticamente'),
            const SizedBox(height: 12),
            FutureBuilder<List<CartaoModel>>(
              future: _cartoes,
              builder: (context, snapshot) {
                if (snapshot.hasError) return const Text('Erro ao consultar cartões.');
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final lista = snapshot.data!;
                if (lista.isEmpty) return const Text('Cadastre ou reative um cartão primeiro.');
                return DropdownButtonFormField<int>(
                  key: const ValueKey('compra-cartao'),
                  initialValue: _cartaoId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Cartão'),
                  items: [for (final c in lista)
                    DropdownMenuItem(value: c.id!, child: Text(c.nome))],
                  onChanged: _salvando || widget.compra != null ? null : (v) => setState(() => _cartaoId = v),
                  validator: (v) => v == null ? 'Selecione o cartão.' : null,
                );
              },
            ),
            const SizedBox(height: 12),
            FutureBuilder<List<CategoriaModel>>(
              future: _categorias,
              builder: (context, snapshot) {
                if (snapshot.hasError) return const Text('Erro ao consultar categorias.');
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final lista = snapshot.data!;
                if (lista.isEmpty) return const Text('Nenhuma categoria de despesa ativa.');
                return DropdownButtonFormField<int>(
                  key: const ValueKey('compra-categoria'),
                  initialValue: _categoriaId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Categoria'),
                  items: [for (final c in lista)
                    DropdownMenuItem(value: c.id!, child: Text(c.nome))],
                  onChanged: _salvando ? null : (v) => setState(() => _categoriaId = v),
                  validator: (v) => v == null ? 'Selecione a categoria.' : null,
                );
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const ValueKey('compra-descricao'),
              controller: _descricao,
              decoration: const InputDecoration(labelText: 'Descrição'),
              validator: (v) => v == null || v.trim().isEmpty ? 'Informe a descrição.' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const ValueKey('compra-valor'),
              controller: _valor,
              decoration: const InputDecoration(labelText: 'Valor (R\$)', hintText: '125,90'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]'))],
              validator: (v) => (_centavos(v ?? '') ?? 0) <= 0 ? 'Informe um valor positivo válido.' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const ValueKey('compra-data'),
              controller: _data,
              decoration: const InputDecoration(labelText: 'Data da compra', hintText: 'DD/MM/AAAA', suffixIcon: Icon(Icons.calendar_today_outlined)),
              readOnly: true,
              onTap: _salvando ? null : _selecionarData,
              validator: (v) => _iso(v ?? '') == null ? 'Informe uma data válida.' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _observacao,
              decoration: const InputDecoration(labelText: 'Observação (opcional)'),
              maxLines: 2,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _salvando ? null : _salvar,
              child: Text(_salvando ? 'Salvando...' : 'Salvar compra'),
            ),
          ],
        ),
      ),
    );
  }
}
