import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/cartao_model.dart';
import '../services/cartao_service.dart';

class CartaoFormScreen extends StatefulWidget {
  final CartaoService service;
  final CartaoModel? cartao;

  const CartaoFormScreen({
    super.key,
    required this.service,
    this.cartao,
  });

  @override
  State<CartaoFormScreen> createState() => _CartaoFormScreenState();
}

class _CartaoFormScreenState extends State<CartaoFormScreen> {
  final _chave = GlobalKey<FormState>();
  final _nome = TextEditingController();
  final _instituicao = TextEditingController();
  final _limite = TextEditingController();
  final _fechamento = TextEditingController();
  final _vencimento = TextEditingController();
  final _observacao = TextEditingController();
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    final c = widget.cartao;
    if (c != null) {
      _nome.text = c.nome;
      _instituicao.text = c.instituicao;
      _limite.text = '${c.limiteTotal ~/ 100},${(c.limiteTotal % 100).toString().padLeft(2, '0')}';
      _fechamento.text = c.diaFechamento.toString();
      _vencimento.text = c.diaVencimento.toString();
      _observacao.text = c.observacao ?? '';
    }
  }

  int? _centavos(String texto) {
    final bruto = texto.trim().replaceAll('.', '').replaceAll(',', '.');
    if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(bruto)) return null;
    final partes = bruto.split('.');
    final reais = int.tryParse(partes[0]);
    if (reais == null) return null;
    final centavos = partes.length == 2
        ? int.parse(partes[1].padRight(2, '0'))
        : 0;
    return reais * 100 + centavos;
  }

  String? _diaValido(String? texto) {
    final dia = int.tryParse(texto?.trim() ?? '');
    return dia == null || dia < 1 || dia > 31
        ? 'Informe um dia de 1 a 31.'
        : null;
  }

  Future<void> _salvar() async {
    if (_salvando || !_chave.currentState!.validate()) return;
    final centavos = _centavos(_limite.text);
    if (centavos == null) return;
    setState(() => _salvando = true);
    try {
      final existente = widget.cartao;
      if (existente == null) {
        await widget.service.cadastrarCartao(
          nome: _nome.text,
          instituicao: _instituicao.text,
          limiteTotal: centavos,
          diaFechamento: int.parse(_fechamento.text.trim()),
          diaVencimento: int.parse(_vencimento.text.trim()),
          observacao: _observacao.text.trim(),
        );
      } else {
        await widget.service.atualizarCartao(
          cartaoId: existente.id!,
          nome: _nome.text,
          instituicao: _instituicao.text,
          limiteTotal: centavos,
          diaFechamento: int.parse(_fechamento.text.trim()),
          diaVencimento: int.parse(_vencimento.text.trim()),
          status: existente.status,
          observacao: _observacao.text.trim(),
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (erro) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível salvar o cartão: $erro')),
        );
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  void dispose() {
    _nome.dispose();
    _instituicao.dispose();
    _limite.dispose();
    _fechamento.dispose();
    _vencimento.dispose();
    _observacao.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editando = widget.cartao != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(editando ? 'Editar cartão' : 'Novo cartão'),
      ),
      body: Form(
        key: _chave,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nome,
              decoration: const InputDecoration(labelText: 'Nome do cartão'),
              maxLength: 80,
              validator: (v) => v == null || v.trim().isEmpty
                  ? 'Informe o nome do cartão.'
                  : null,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _instituicao,
              decoration: const InputDecoration(labelText: 'Instituição'),
              maxLength: 80,
              validator: (v) => v == null || v.trim().isEmpty
                  ? 'Informe a instituição.'
                  : null,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _limite,
              decoration: const InputDecoration(
                labelText: 'Limite total (R\$)',
                hintText: 'Ex.: 3500,00',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),
              ],
              validator: (v) => _centavos(v ?? '') == null
                  ? 'Informe um limite válido com até 2 decimais.'
                  : null,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _fechamento,
                    decoration: const InputDecoration(labelText: 'Dia fechamento'),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: _diaValido,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _vencimento,
                    decoration: const InputDecoration(labelText: 'Dia vencimento'),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: _diaValido,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _observacao,
              decoration: const InputDecoration(labelText: 'Observação (opcional)'),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _salvando ? null : _salvar,
              icon: const Icon(Icons.save_outlined),
              label: Text(_salvando ? 'Salvando...' : 'Salvar cartão'),
            ),
          ],
        ),
      ),
    );
  }
}
