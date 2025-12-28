# Ruby Sinatra Example App

シンプルなSinatra Webアプリケーションで、複数のエンドポイントを提供します。

## 機能

- Hello Worldエンドポイント
- 環境変数の表示
- 外部サイト（Google）へのプロキシ
- 自動テストスイート
- Yahooへのプロキシ
- **AI駆動の自動ドキュメント更新チェック** 🤖

## エンドポイント

詳細なAPI仕様は[API-spec.md](./API-spec.md)を参照してください。

- `GET /hello` - Hello worldメッセージと環境変数を表示
- `GET /greetings` - シンプルな挨拶メッセージ
- `GET /hello-world` - Hello, Worldメッセージ
- `GET /google` - Google.comのプロキシ
- `GET /yahoo` - Yahoo.comのプロキシ

## セットアップ

### 必要要件

- Ruby 2.0.0以上
- Bundler

### インストール

```bash
# 依存関係のインストール
bundle install
```

### 実行

```bash
# Rackupで起動
bundle exec rackup config.ru

# または直接実行
bundle exec ruby app.rb
```

アプリケーションは http://localhost:4567 で起動します。

## テスト

RSpecを使用したテストスイートが含まれています。

```bash
# テストの実行
bundle exec rspec
```

## 自動ドキュメント更新チェック 🤖

このプロジェクトでは、GitHub Actionsを使用してPR作成時に自動的にドキュメントの更新が必要かをチェックします。

### 仕組み

1. **PRが作成/更新される** → GitHub Actionsがトリガーされます
2. **コード変更を分析** → AIがソースコードの変更を読み取ります
3. **ドキュメントと比較** → 既存のREADME.mdとAPI-spec.mdと比較します
4. **更新提案** → 必要に応じてドキュメント更新をPRにコメントします

### セットアップ方法

GitHub Actionsを有効にするには、以下の手順でシークレットを設定してください：

1. GitHubリポジトリの **Settings** → **Secrets and variables** → **Actions** に移動
2. **New repository secret** をクリック
3. 以下のシークレットを追加：
   - **Name**: `MODELS_TOKEN`
   - **Value**: あなたのGitHub Models用Personal Access Token

### GitHub Models Personal Access Tokenの作成方法

1. GitHub設定の [Personal Access Tokens](https://github.com/settings/tokens) にアクセス
2. **Generate new token (classic)** をクリック
3. 以下のスコープを選択：
   - `repo` - プライベートリポジトリの場合
   - `public_repo` - パブリックリポジトリの場合
4. トークンを生成してコピー
5. リポジトリのSecretsに追加

### 使用するAIモデル

- **デフォルト**: `gpt-4o` (GitHub Models経由)
- モデルは `.github/scripts/analyze_docs.sh` で変更可能

### 動作確認

1. コードを変更するPRを作成
2. GitHub Actionsが自動実行されます
3. ドキュメント更新が必要な場合、PRにコメントが投稿されます

## 開発

### プロジェクト構成

```
.
├── app.rb                 # メインアプリケーション
├── config.ru             # Rack設定
├── Gemfile               # Ruby依存関係
├── API-spec.md           # API仕様書
├── spec/                 # テストファイル
│   └── app_spec.rb
└── .github/
    ├── workflows/
    │   └── doc-checker.yml      # ドキュメントチェックワークフロー
    └── scripts/
        └── analyze_docs.sh      # AI分析スクリプト (bash)
```

### 注意事項

1. **セキュリティ**: `/hello`エンドポイントは環境変数を表示します。本番環境では無効化またはアクセス制限を設けてください。
2. **外部依存**: `/google`エンドポイントは外部サービスに依存しているため、Googleのサービス状態に影響を受けます。

## ライセンス

詳細については、プロジェクトリポジトリを参照してください。
