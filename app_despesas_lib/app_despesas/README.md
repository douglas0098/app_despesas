# App Despesas — Integração

Este pacote contém só a pasta `lib/`, pronta para entrar num projeto Flutter
criado por você. Como já tem Flutter e Android Studio instalados, siga:

## 1. Criar o projeto (se ainda não criou)

```bash
flutter create app_despesas
cd app_despesas
```

## 2. Adicionar as dependências

Abra o `pubspec.yaml` do projeto criado e, dentro de `dependencies:`,
adicione (mantendo o `flutter:` que já vem por padrão):

```yaml
dependencies:
  flutter:
    sdk: flutter
  sqflite: ^2.3.3
  path: ^1.9.0
```

Depois rode:

```bash
flutter pub get
```

## 3. Copiar os arquivos

Substitua a pasta `lib/` do seu projeto pela pasta `lib/` deste pacote
(ou copie arquivo por arquivo mantendo a mesma estrutura de subpastas:
`models/`, `database/`, `screens/`).

## 4. Rodar

```bash
flutter run
```

Escolha o emulador do Android Studio ou seu celular físico (com depuração
USB ativada) quando o Flutter perguntar o dispositivo.

## 5. Gerar o APK

```bash
flutter build apk --release
```

O arquivo fica em `build/app/outputs/flutter-apk/app-release.apk`.

## O que já está pronto

- Banco SQLite local (`sqflite`) com 4 tabelas: `categorias`, `cartoes`,
  `boletos`, `lancamentos`.
- Sem nenhum valor da planilha original — só a estrutura de categorias e
  a lógica de cálculo. Você cadastra tudo manualmente pelo app.
- Cadastro livre de categorias, cartões e boletos (sem limite de colunas,
  como você pediu).
- Dashboard com saldo do mês dividido por quinzena de vencimento
  (dia ≤14 / dia ≥15), replicando a lógica "Despesas dia 01 / dia 15" da
  planilha.
- Tela de novo lançamento (despesa ou receita), vinculável a uma
  categoria, cartão ou boleto.

## O que falta / próximos passos sugeridos

- Geração automática do lançamento do boleto no início do mês (hoje o
  boleto só existe como cadastro; o lançamento em si ainda é manual).
- Gráficos/histórico de meses anteriores.
- Edição de lançamentos (hoje só dá pra excluir, arrastando o item na lista).
- Ícone e nome do app personalizados (hoje usa o padrão do `flutter create`).
