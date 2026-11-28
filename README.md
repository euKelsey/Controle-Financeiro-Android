# Controle Financeiro Android

![Versão](https://img.shields.io/badge/versão-1.0.1-success?style=flat-square)
![Flutter](https://img.shields.io/badge/Flutter-027DFD?style=flat-square&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-0175C2?style=flat-square&logo=dart&logoColor=white)
![SQLite](https://img.shields.io/badge/SQLite-17638B?style=flat-square&logo=sqlite&logoColor=white)

Aplicativo pessoal de gerenciamento financeiro para Android, desenvolvido para organizar receitas, despesas, cartões de crédito e faturas, com acompanhamento mensal e anual.

**Status:** versão 1.0.1 funcional, disponível para instalação e em fase de utilização prática.

## Download e instalação

[**Baixar APK da versão 1.0.1**](https://github.com/euKelsey/Controle-Financeiro-Android/releases/download/v1.0.1/Controle-Financeiro-Android-v1.0.1.apk) · [Notas da versão](https://github.com/euKelsey/Controle-Financeiro-Android/releases/tag/v1.0.1)

- APK release assinado digitalmente (51,7 MB).
- Baixe o arquivo no dispositivo Android e autorize a instalação pelo aplicativo de origem, se solicitado pelo sistema.
- Os dados são armazenados localmente. Backup e restauração ainda estão no planejamento; desinstalar o aplicativo pode apagar os dados.

## Funcionalidades

- Login local e gerenciamento de categorias.
- Cadastro e gerenciamento de receitas, despesas e cartões de crédito.
- Compras no cartão, edição e cancelamento de compras e acompanhamento de faturas.
- Lançamentos fixos e recorrentes, com duração definida ou indeterminada.
- Dashboard mensal e anual com previsão dos 12 meses.
- Gráfico interativo de receitas e despesas e detalhamento mensal.
- Vencimentos filtrados pelo mês selecionado.
- Temas claro e escuro, calendários em português e datas padronizadas.

## Arquitetura

O projeto separa interface, regras de negócio e persistência de dados.

| Diretório | Responsabilidade |
|---|---|
| `lib/app/` | Organização da aplicação |
| `lib/models/` | Modelos de dados |
| `lib/repositories/` | Acesso aos dados |
| `lib/services/` | Regras de negócio |
| `lib/database/` | Persistência SQLite |
| `lib/screens/` | Interface |
| `lib/theme/` | Temas |
| `test/` e `integration_test/` | Testes automatizados |

## Execução para desenvolvimento

Requisitos: Flutter SDK, ambiente Android configurado e dispositivo ou emulador.

```bash
git clone https://github.com/euKelsey/Controle-Financeiro-Android.git
cd Controle-Financeiro-Android
flutter pub get
flutter run
```

## Qualidade e testes

Resultados registrados na release v1.0.1:

| Suite | Testes aprovados |
|---|---:|
| Unitários e de interface | 58 |
| Integração | 50 |
| Total | 108 |

Análise estática sem erros ou avisos de nível warning.

```bash
flutter analyze
flutter test
flutter test integration_test
```

Os testes de integração exigem um dispositivo ou emulador compatível.

## Próximos passos

- Utilização prática e correções incrementais nas versões 1.0.2 e 1.0.3.
- Backup e restauração dos dados.
- Revisão de dependências, arquitetura, segurança e desempenho.
- Avaliação futura de uma versão para iOS.

A aplicação é independente da versão desktop; sincronização entre plataformas não faz parte do planejamento atual.

---

*Projeto pessoal voltado ao aprendizado prático e à evolução contínua de uma aplicação funcional.*
