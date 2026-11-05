
import 'package:flutter_test/flutter_test.dart';

import 'package:controle_financeiro_android/services/competencia_fatura_service.dart';

void main() {
  group('CompetenciaFaturaService', () {
    group('calcularMesFatura', () {
      // TESTE 1: Compra antes do fechamento.
      test('mantem a competencia atual', () {
        final mes = CompetenciaFaturaService.calcularMesFatura(
          dataCompra: '2026-11-09',
          diaFechamento: 10,
        );

        expect(mes, '2026-11');
      });

      // TESTE 2: Compra no dia do fechamento.
      test('passa para o mes seguinte no fechamento', () {
        final mes = CompetenciaFaturaService.calcularMesFatura(
          dataCompra: '2026-11-10',
          diaFechamento: 10,
        );

        expect(mes, '2026-12');
      });

      // TESTE 3: Compra depois do fechamento.
      test('passa para o mes seguinte apos fechamento', () {
        final mes = CompetenciaFaturaService.calcularMesFatura(
          dataCompra: '2026-11-15',
          diaFechamento: 10,
        );

        expect(mes, '2026-12');
      });

      // TESTE 4: Virada de ano.
      test('avanca de dezembro para janeiro', () {
        final mes = CompetenciaFaturaService.calcularMesFatura(
          dataCompra: '2026-12-20',
          diaFechamento: 15,
        );

        expect(mes, '2027-01');
      });

      // TESTE 5: Fevereiro em ano nao bissexto.
      test('ajusta fechamento 31 para 28 de fevereiro', () {
        final antes = CompetenciaFaturaService.calcularMesFatura(
          dataCompra: '2027-02-27',
          diaFechamento: 31,
        );

        final noFechamento =
            CompetenciaFaturaService.calcularMesFatura(
          dataCompra: '2027-02-28',
          diaFechamento: 31,
        );

        expect(antes, '2027-02');
        expect(noFechamento, '2027-03');
      });

      // TESTE 6: Fevereiro em ano bissexto.
      test('considera 29 de fevereiro', () {
        final antes = CompetenciaFaturaService.calcularMesFatura(
          dataCompra: '2028-02-28',
          diaFechamento: 31,
        );

        final noFechamento =
            CompetenciaFaturaService.calcularMesFatura(
          dataCompra: '2028-02-29',
          diaFechamento: 31,
        );

        expect(antes, '2028-02');
        expect(noFechamento, '2028-03');
      });

      // TESTE 7: Data em formato incorreto.
      test('rejeita formato de data invalido', () {
        expect(
          () => CompetenciaFaturaService.calcularMesFatura(
            dataCompra: '09/11/2026',
            diaFechamento: 10,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      // TESTE 8: Data impossivel.
      test('rejeita dia inexistente', () {
        expect(
          () => CompetenciaFaturaService.calcularMesFatura(
            dataCompra: '2026-02-30',
            diaFechamento: 10,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      // TESTE 9: Fechamento fora do intervalo.
      test('rejeita dia de fechamento invalido', () {
        for (final dia in [0, 32]) {
          expect(
            () => CompetenciaFaturaService.calcularMesFatura(
              dataCompra: '2026-11-05',
              diaFechamento: dia,
            ),
            throwsA(isA<ArgumentError>()),
          );
        }
      });
    });

    group('calcularDatasFatura', () {
      // TESTE 10: Fechamento e vencimento no mesmo mes.
      test('calcula datas no mesmo mes', () {
        final datas = CompetenciaFaturaService.calcularDatasFatura(
          mesReferencia: '2026-11',
          diaFechamento: 10,
          diaVencimento: 20,
        );

        expect(datas.dataFechamento, '2026-11-10');
        expect(datas.dataVencimento, '2026-11-20');
      });

      // TESTE 11: Vencimento no mes seguinte.
      test('calcula vencimento no mes seguinte', () {
        final datas = CompetenciaFaturaService.calcularDatasFatura(
          mesReferencia: '2026-11',
          diaFechamento: 25,
          diaVencimento: 5,
        );

        expect(datas.dataFechamento, '2026-11-25');
        expect(datas.dataVencimento, '2026-12-05');
      });

      // TESTE 12: Fechamento e vencimento no mesmo dia.
      test('move vencimento igual ao fechamento', () {
        final datas = CompetenciaFaturaService.calcularDatasFatura(
          mesReferencia: '2026-11',
          diaFechamento: 10,
          diaVencimento: 10,
        );

        expect(datas.dataFechamento, '2026-11-10');
        expect(datas.dataVencimento, '2026-12-10');
      });

      // TESTE 13: Ano bissexto.
      test('ajusta fechamento para 29 de fevereiro', () {
        final datas = CompetenciaFaturaService.calcularDatasFatura(
          mesReferencia: '2028-02',
          diaFechamento: 31,
          diaVencimento: 10,
        );

        expect(datas.dataFechamento, '2028-02-29');
        expect(datas.dataVencimento, '2028-03-10');
      });

      // TESTE 14: Ano nao bissexto.
      test('ajusta fechamento para 28 de fevereiro', () {
        final datas = CompetenciaFaturaService.calcularDatasFatura(
          mesReferencia: '2027-02',
          diaFechamento: 31,
          diaVencimento: 10,
        );

        expect(datas.dataFechamento, '2027-02-28');
        expect(datas.dataVencimento, '2027-03-10');
      });

      // TESTE 15: Virada do ano.
      test('calcula vencimento em janeiro do proximo ano', () {
        final datas = CompetenciaFaturaService.calcularDatasFatura(
          mesReferencia: '2026-12',
          diaFechamento: 15,
          diaVencimento: 5,
        );

        expect(datas.dataFechamento, '2026-12-15');
        expect(datas.dataVencimento, '2027-01-05');
      });

      // TESTE 16: Ajuste para mes com 30 dias.
      test('ajusta vencimento 31 para 30 de abril', () {
        final datas = CompetenciaFaturaService.calcularDatasFatura(
          mesReferencia: '2026-04',
          diaFechamento: 10,
          diaVencimento: 31,
        );

        expect(datas.dataFechamento, '2026-04-10');
        expect(datas.dataVencimento, '2026-04-30');
      });

      // TESTE 17: Competencia invalida.
      test('rejeita mes de referencia invalido', () {
        for (final mes in ['2026-13', '2026-00', '11/2026']) {
          expect(
            () => CompetenciaFaturaService.calcularDatasFatura(
              mesReferencia: mes,
              diaFechamento: 10,
              diaVencimento: 20,
            ),
            throwsA(isA<ArgumentError>()),
          );
        }
      });

      // TESTE 18: Dias invalidos.
      test('rejeita fechamento e vencimento invalidos', () {
        expect(
          () => CompetenciaFaturaService.calcularDatasFatura(
            mesReferencia: '2026-11',
            diaFechamento: 0,
            diaVencimento: 20,
          ),
          throwsA(isA<ArgumentError>()),
        );

        expect(
          () => CompetenciaFaturaService.calcularDatasFatura(
            mesReferencia: '2026-11',
            diaFechamento: 10,
            diaVencimento: 32,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      // TESTE 19: Vencimento sempre posterior ao fechamento.
      test('garante vencimento posterior ao fechamento', () {
        final datas = CompetenciaFaturaService.calcularDatasFatura(
          mesReferencia: '2027-02',
          diaFechamento: 31,
          diaVencimento: 28,
        );

        expect(datas.dataFechamento, '2027-02-28');
        expect(datas.dataVencimento, '2027-03-28');

        expect(
          DateTime.parse(datas.dataVencimento).isAfter(
            DateTime.parse(datas.dataFechamento),
          ),
          isTrue,
        );
      });
    });
  });
}
