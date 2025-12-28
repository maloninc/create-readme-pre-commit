# セットアップガイド：自動ドキュメント更新チェック

このガイドでは、GitHub ActionsとAIを使用した自動ドキュメント更新チェック機能のセットアップ方法を説明します。

## 概要

この機能により、PRが作成されるたびに：
- AIがコードの変更を自動分析
- README.mdやAPI-spec.mdの更新が必要かを判断
- 必要に応じて具体的な更新提案をPRコメントとして投稿

## ステップ1: GitHub Models Personal Access Tokenの作成

### 1.1 GitHubの設定にアクセス

1. GitHubにログイン
2. 右上のプロフィール画像をクリック → **Settings**
3. 左サイドバーの下部にある **Developer settings** をクリック
4. **Personal access tokens** → **Tokens (classic)** をクリック

または直接アクセス: https://github.com/settings/tokens

### 1.2 新しいトークンを生成

1. **Generate new token** → **Generate new token (classic)** をクリック
2. トークンの設定：
   - **Note**: `GitHub Models for Doc Checker` (わかりやすい名前)
   - **Expiration**: お好みの期限（90日間推奨）
   - **Select scopes**:
     - ✅ `repo` (プライベートリポジトリの場合)
     - または ✅ `public_repo` (パブリックリポジトリのみの場合)

3. **Generate token** をクリック
4. 🔑 **重要**: 表示されたトークンをコピーして安全な場所に保存
   - このトークンは二度と表示されません！

## ステップ2: GitHub Secretsの設定

### 2.1 リポジトリの設定にアクセス

1. このリポジトリのページに移動
2. **Settings** タブをクリック
3. 左サイドバーの **Secrets and variables** → **Actions** をクリック

### 2.2 Secretを追加

1. **New repository secret** ボタンをクリック
2. Secret の設定：
   - **Name**: `MODELS_TOKEN`
   - **Secret**: ステップ1でコピーしたPersonal Access Token
3. **Add secret** をクリック

## ステップ3: 動作確認

### 3.1 テストPRの作成

1. 新しいブランチを作成：
   ```bash
   git checkout -b test-doc-checker
   ```

2. `app.rb`に小さな変更を加える：
   ```bash
   # 例：新しいエンドポイントを追加
   echo "\nget '/test' do\n  'Test endpoint'\nend" >> app.rb
   ```

3. コミットしてプッシュ：
   ```bash
   git add .
   git commit -m "test: Add test endpoint for doc checker"
   git push -u origin test-doc-checker
   ```

4. GitHubでPRを作成

### 3.2 GitHub Actionsの確認

1. PRページの **Checks** タブを確認
2. **Documentation Checker** ワークフローが実行されているか確認
3. 実行完了後、PRにコメントが投稿されているか確認

## トラブルシューティング

### エラー: "MODELS_TOKEN not set"

**原因**: Secretが正しく設定されていない

**解決方法**:
1. リポジトリの Settings → Secrets → Actions を確認
2. `MODELS_TOKEN` が存在することを確認（**Repository secrets**に設定）
3. 存在しない場合は、ステップ2を再実行

**注意**: `GITHUB_`で始まる名前は使用できません

### エラー: "Error calling GitHub Models API"

**原因**: Personal Access Tokenが無効または期限切れ

**解決方法**:
1. Personal Access Tokenを再生成（ステップ1）
2. Secretを更新（ステップ2）

### ワークフローが実行されない

**原因**: GitHub Actionsが有効になっていない可能性

**解決方法**:
1. リポジトリの Settings → Actions → General を確認
2. **Allow all actions and reusable workflows** が選択されているか確認

### API レート制限エラー

**原因**: GitHub Models APIの使用量が上限に達した

**解決方法**:
- 無料枠の場合、時間をおいて再試行
- より高い使用枠が必要な場合は、GitHub Models の pricing を確認

## 高度な設定

### AIモデルの変更

`.github/scripts/analyze_docs.sh` の `call_github_models_api` 関数呼び出し部分を変更：

```bash
# デフォルト
call_github_models_api "$prompt" "gpt-4o" "$github_models_token"

# 他のモデル例
# call_github_models_api "$prompt" "gpt-4o-mini" "$github_models_token"  # より高速・低コスト
# call_github_models_api "$prompt" "o1-preview" "$github_models_token"   # より高度な推論
```

### プロンプトのカスタマイズ

`.github/scripts/analyze_docs.sh` の `analyze_changes` 関数内のプロンプト構築部分でプロンプトをカスタマイズできます。

### ワークフローのトリガー条件の変更

`.github/workflows/doc-checker.yml` の `on` セクションを編集：

```yaml
on:
  pull_request:
    types: [opened, synchronize, reopened]
    paths:
      - '**.rb'  # Rubyファイルのみ監視
      - '**.ru'
```

## セキュリティのベストプラクティス

1. **Personal Access Tokenは絶対にコードにコミットしない**
2. **最小権限の原則**: 必要最小限のスコープのみ付与
3. **定期的なトークンのローテーション**: 90日ごとに更新推奨
4. **使用していないトークンは削除**

## コスト管理

GitHub Models（プレビュー版）は無料枠がありますが、使用量に注意：

- PRごとに1回のAPI呼び出し
- 大きな変更の場合、トークン消費量が増加
- 月次使用量をモニタリング推奨

## サポート

問題が発生した場合：
1. GitHub Actionsのログを確認
2. `.github/scripts/analyze_docs.sh` のデバッグ出力を確認
3. Issue を作成して報告

## 次のステップ

- ✅ セットアップ完了後、実際のPRで動作確認
- 📝 チームメンバーにこの機能を共有
- 🔄 プロンプトをプロジェクトに合わせて調整
- 📊 定期的に提案の品質を確認・改善
