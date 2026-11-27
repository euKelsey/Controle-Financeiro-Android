import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/categoria_model.dart';
import '../models/lancamento_model.dart';
import '../services/lancamento_service.dart';

/// Formulario de cadastro e edicao. Nenhuma regra financeira e
/// implementada aqui: todas as gravacoes passam pelo LancamentoService.
class LancamentoFormScreen extends StatefulWidget {
  final LancamentoService service;
  final LancamentoModel? lancamento;

  const LancamentoFormScreen({
    super.key,
    required this.service,
    this.lancamento,
  });

  @override
  State<LancamentoFormScreen> createState() => _LancamentoFormScreenState();
}

class _LancamentoFormScreenState extends State<LancamentoFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descricao = TextEditingController();
  final _valor = TextEditingController();
  final _data = TextEditingController();
  final _observacao = TextEditingController();

  late String _tipo;
  late Future<List<CategoriaModel>> _categorias;
  int? _categoriaId;
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    final existente = widget.lancamento;
    _tipo = existente?.tipo ?? 'DESPESA';
    _categoriaId = existente?.categoriaId;
    _descricao.text = existente?.descricao ?? '';
    if (existente != null) {
      _valor.text = (existente.valorPrevisto / 100)
          .toStringAsFixed(2).replaceAll('.', ',');
      _data.text = _formatarData(existente.dataPrevista);
      _observacao.text = existente.observacao ?? '';
    } else {
      _data.text = _formatarData(_iso(DateTime.now()));
    }
    _carregarCategorias();
  }

  void _carregarCategorias() {
    _categorias = widget.service.listarCategoriasFormulario(
      tipo: _tipo,
      categoriaAtualId: widget.lancamento?.categoriaId,
    );
  }

  String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  String _formatarData(String iso) {
    final partes = iso.split('-');
    return '${partes[2]}/${partes[1]}/${partes[0]}';
  }

  String? _validarData(String? entrada) {
    if (entrada == null ||
        !RegExp(r'^\d{2}/\d{2}/\d{4}$').hasMatch(entrada)) {
      return 'Use o formato DD/MM/AAAA.';
    }
    final partes = entrada.split('/');
    final dia = int.parse(partes[0]);
    final mes = int.parse(partes[1]);
    final ano = int.parse(partes[2]);
    if (ano < 1 || ano > 9999) return 'Data inválida.';
    final d = DateTime(ano, mes, dia);
    if (d.year != ano || d.month != mes || d.day != dia) {
      return 'Data inválida.';
    }
    return null;
  }

  String _dataIso(String entrada) {
    final partes = entrada.split('/');
    return '${partes[2]}-${partes[1]}-${partes[0]}';
  }

  int? _valorCentavos(String texto) {
    final normalizado = texto.trim().replaceAll('.', '').replaceAll(',', '.');
    if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(normalizado)) {
      return null;
    }
    final partes = normalizado.split('.');
    final reais = int.tryParse(partes.first);
    if (reais == null) return null;
    final centavos = partes.length == 2
        ? int.parse(partes[1].padRight(2, '0'))
        : 0;
    return reais * 100 + centavos;
  }

  Future<void> _salvar() async {
    if (_salvando || !_formKey.currentState!.validate()) return;
    if (_categoriaId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione uma categoria.')),
      );
      return;
    }
    setState(() => _salvando = true);
    try {
      final valor = _valorCentavos(_valor.text)!;
      final existente = widget.lancamento;
      if (existente == null) {
        await widget.service.cadastrarLancamento(
          tipo: _tipo,
          descricao: _descricao.text,
          valorPrevisto: valor,
          dataPrevista: _dataIso(_data.text),
          categoriaId: _categoriaId,
          observacao: _observacao.text.trim(),
          registroDireto: true,
        );
      } else {
        await widget.service.atualizarLancamento(
          lancamentoId: existente.id!,
          tipo: _tipo,
          descricao: _descricao.text,
          valorPrevisto: valor,
          dataPrevista: _dataIso(_data.text),
          categoriaId: _categoriaId,
          observacao: _observacao.text.trim(),
          registroDireto: true,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (erro) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível salvar: $erro')),
        );
      }
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
    final editando = widget.lancamento != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(editando ? 'Editar lançamento' : 'Novo lançamento'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<String>(
              key: ValueKey('tipo-$_tipo'),
              initialValue: _tipo,
              decoration: const InputDecoration(labelText: 'Tipo'),
              items: const [
                DropdownMenuItem(value: 'DESPESA', child: Text('Despesa')),
                DropdownMenuItem(value: 'RECEITA', child: Text('Receita')),
              ],
              onChanged: _salvando ? null : (tipo) {
                if (tipo == null) return;
                setState(() {
                  _tipo = tipo;
                  _categoriaId = null;
                  _carregarCategorias();
                });
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descricao,
              decoration: const InputDecoration(labelText: 'Descrição'),
              maxLength: 150,
              validator: (v) => v == null || v.trim().isEmpty
                  ? 'Informe a descrição.'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _valor,
              decoration: const InputDecoration(
                labelText: 'Valor (R\$)',
                hintText: 'Ex.: 125,90',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),
              ],
              validator: (v) {
                final centavos = _valorCentavos(v ?? '');
                return centavos == null || centavos <= 0
                    ? 'Informe um valor positivo com até 2 decimais.'
                    : null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _data,
              decoration: const InputDecoration(
                labelText: 'Data prevista',
                hintText: 'DD/MM/AAAA',
              ),
              keyboardType: TextInputType.datetime,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9/]')),
                LengthLimitingTextInputFormatter(10),
              ],
              validator: _validarData,
            ),
            const SizedBox(height: 12),
            FutureBuilder<List<CategoriaModel>>(
              future: _categorias,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  if (snapshot.hasError) {
                    return const Text('Erro ao carregar categorias.');
                  }
                  return const Center(child: CircularProgressIndicator());
                }
                final categorias = snapshot.data!;
                return DropdownButtonFormField<int>(
                  key: ValueKey('categoria-$_tipo'),
                  initialValue: categorias.any((c) => c.id == _categoriaId)
                      ? _categoriaId
                      : null,
                  decoration: const InputDecoration(labelText: 'Categoria'),
                  items: [
                    for (final c in categorias)
                      DropdownMenuItem(
                        value: c.id,
                        child: Text(
                          c.status == 'ATIVA' ? c.nome : '${c.nome} (inativa)',
                        ),
                      ),
                  ],
                  onChanged: _salvando ? null : (valor) {
                    setState(() => _categoriaId = valor);
                  },
                  validator: (_) => _categoriaId == null
                      ? 'Selecione uma categoria.'
                      : null,
                );
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _observacao,
              decoration: const InputDecoration(
                labelText: 'Observação (opcional)',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _salvando ? null : _salvar,
              icon: const Icon(Icons.save_outlined),
              label: Text(_salvando ? 'Salvando...' : 'Salvar lançamento'),
            ),
          ],
        ),
      ),
    );
  }
}
