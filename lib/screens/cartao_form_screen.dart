import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/cartao_model.dart';
import '../services/cartao_service.dart';
import '../services/competencia_fatura_service.dart';

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
  DateTime? _dataFechamento;
  DateTime? _dataVencimento;
  int? _diaFechamento;
  int? _diaVencimento;

  @override
  void initState() {
    super.initState();
    final c = widget.cartao;
    if (c != null) {
      _nome.text = c.nome;
      _instituicao.text = c.instituicao;
      _limite.text = '${c.limiteTotal ~/ 100},${(c.limiteTotal % 100).toString().padLeft(2, '0')}';
      _diaFechamento = c.diaFechamento;
      _diaVencimento = c.diaVencimento;
      final hoje = DateTime.now();
      final mes = CompetenciaFaturaService.calcularMesFatura(
        dataCompra: hoje.toIso8601String().substring(0, 10),
        diaFechamento: c.diaFechamento,
      );
      final ciclo = CompetenciaFaturaService.calcularDatasFatura(
        mesReferencia: mes, diaFechamento: c.diaFechamento,
        diaVencimento: c.diaVencimento,
      );
      _dataFechamento = DateTime.parse(ciclo.dataFechamento);
      _dataVencimento = DateTime.parse(ciclo.dataVencimento);
      _fechamento.text = _formatar(_dataFechamento!);
      _vencimento.text = _formatar(_dataVencimento!);
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

  String _formatar(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year.toString().padLeft(4, '0')}';

  Future<void> _selecionar(bool fechamento) async {
    final data = await showDatePicker(
      context: context,
      initialDate: (fechamento ? _dataFechamento : _dataVencimento)
          ?? _dataFechamento ?? DateTime.now(),
      firstDate: DateTime(1), lastDate: DateTime(9999, 12, 31),
      initialEntryMode: DatePickerEntryMode.calendarOnly,
    );
    if (data == null || !mounted) return;
    setState(() {
      if (fechamento) {
        _dataFechamento = data;
        _diaFechamento = data.day;
        _fechamento.text = _formatar(data);
      } else {
        _dataVencimento = data;
        _diaVencimento = data.day;
        _vencimento.text = _formatar(data);
      }
    });
  }

  String? _validarCiclo() {
    if (_dataFechamento == null || _dataVencimento == null) {
      return 'Selecione as duas datas.';
    }
    final mes = _dataFechamento!.toIso8601String().substring(0, 7);
    final ciclo = CompetenciaFaturaService.calcularDatasFatura(
      mesReferencia: mes, diaFechamento: _diaFechamento!,
      diaVencimento: _diaVencimento!,
    );
    if (ciclo.dataVencimento != _dataVencimento!.toIso8601String().substring(0, 10)) {
      return 'Escolha o vencimento do mesmo ciclo mensal.';
    }
    return null;
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
          diaFechamento: _diaFechamento!,
          diaVencimento: _diaVencimento!,
          observacao: _observacao.text.trim(),
        );
      } else {
        await widget.service.atualizarCartao(
          cartaoId: existente.id!,
          nome: _nome.text,
          instituicao: _instituicao.text,
          limiteTotal: centavos,
          diaFechamento: _diaFechamento!,
          diaVencimento: _diaVencimento!,
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
            TextFormField(
              key: const ValueKey('cartao-fechamento'),
              controller: _fechamento, readOnly: true,
              onTap: _salvando ? null : () => _selecionar(true),
              decoration: const InputDecoration(labelText: 'Fechamento de referência',
                suffixIcon: Icon(Icons.calendar_today_outlined)),
              validator: (_) => _dataFechamento == null ? 'Selecione a data.' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const ValueKey('cartao-vencimento'),
              controller: _vencimento, readOnly: true,
              onTap: _salvando ? null : () => _selecionar(false),
              decoration: const InputDecoration(labelText: 'Vencimento de referência',
                suffixIcon: Icon(Icons.calendar_today_outlined)),
              validator: (_) => _validarCiclo(),
            ),
            if (_diaFechamento != null && _diaVencimento != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text('Ciclo mensal: fecha dia $_diaFechamento · vence dia $_diaVencimento. '
                  'Compras no dia do fechamento entram na próxima fatura.'),
              ),
            const Text('As datas são referências; o ciclo se repete mensalmente. '
              'Faturas existentes não serão alteradas.'),
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
