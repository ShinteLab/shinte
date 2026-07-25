# Shinte

このプロジェクトは将棋関連のプロジェクトになります。
かつて開発したプロジェクト群をここに並べており、**サブディレクトリごとに独立した Go モジュール**
（= `github.com/ShinteLab/<ディレクトリ名>` として 1 リポジトリ）で管理します。
ルートに go.mod はありません。

## 構成

```
shinte/          （ここ自体はモジュールではない）
├── core/           将棋フォント生成・軽量HTML表示（旧 board / shogifont）
├── engine/         PureGo 将棋エンジン（旧 shogi）
├── prokishi/       USI をクライアント・サーバで伝達する仕組み
├── suteme/         盤画像から SFEN を抽出
└── kicho/          棋帳。棋譜の取得・保存・配信（Wails3 アプリ）
```

| ディレクトリ | モジュールパス |
|---|---|
| `core/` | `github.com/ShinteLab/core` |
| `engine/` | `github.com/ShinteLab/engine` |
| `prokishi/` | `github.com/ShinteLab/prokishi` |
| `suteme/` | `github.com/ShinteLab/suteme` |
| `kicho/` | `github.com/ShinteLab/kicho` |

モジュール間の参照は、まだタグを打っていないので **`replace` による相対パス参照**にしています
（例: `engine/go.mod` の `replace github.com/ShinteLab/core => ../core`）。
`go` コマンドは各サブディレクトリで実行してください。

## セットアップ

このリポジトリ（`ShinteLab/shinte`）はワークスペースのガワだけで、5 つのサブプロジェクトは
含まれていません。clone したら次で取得します。

```powershell
git clone https://github.com/ShinteLab/shinte
cd shinte
.\bootstrap.ps1              # 5 リポジトリを clone（-Protocol ssh も可）
.\bootstrap.ps1 -Verify      # clone に続けて全モジュールの build / test を流す
```

**`replace` が相対パス指定なので、5 つはこのディレクトリ直下に並んでいる必要があります。**
配置を変えるとビルドが通りません。

## 各プロジェクト

### core

全プロジェクトで利用できる共通基盤。将棋の仕様（SFEN / USI 表記）を集約し、
engine・suteme はここを参照して重複実装を持たないようにしています。

| パッケージ | import パス | 役割 |
|---|---|---|
| `core/sfen` | `github.com/ShinteLab/core/sfen` | 駒種↔SFEN文字マッピング、SFEN盤面の解析(`ParseBoard`)・生成(`FormatBoard`) |
| `core/usi` | `github.com/ShinteLab/core/usi` | USIマス座標(`FormatSquare`/`ParseSquare`)・手表記(`Move`/`ParseMove`) |
| `core`（root, `package main`） | — | 将棋駒表示用の軽量フォント生成ツール（旧 `board` / 旧モジュール名 `shogifont`）。`core/` で `go run . {inputfont}` |
| `core/web`（`@shinte/web`, フロント） | — | 盤表示 Web Component `<shogi-board>` と SFEN/USI の JS 共通ロジック。prokishi(React)・suteme(素HTML) 双方から利用。詳細は `core/web/README.md` |

`core/sfen` の駒コードの整数値は engine の `PieceType` と一致させてあり、engine は
自身の駒種を変換なしで渡せます（ホットパスに変換を持ち込まない設計）。SFEN/USI の
変換は「position 受信」「bestmove 出力」等の I/O 境界でのみ呼ばれます。

### engine

PureGo で書かれた将棋エンジン（旧 `shogi` をリネーム）。
盤面表現・合法手生成・探索 (`search`) などを提供します。

import パス: `github.com/ShinteLab/engine`, `github.com/ShinteLab/engine/search`

- `_cmd/` … 個別に `go run` する動作確認用コマンド群（各ファイルが独立した `main`）
- `_samples/` … サンプルコード
- `_dist/` … 配布物

### prokishi

将棋エンジンは将棋ソフトと USI という通信プロトコルを通じて動作しますが、それをクライアント・サーバで伝達することで、UI 部分と実際の算出を分離する仕組みです。

import パス: `github.com/ShinteLab/prokishi`（`api`, `client`, `db`, `registry`, `server`, `usi` などのサブパッケージ）

- `_cmd/prokishi/` … CLI クライアント
- `_cmd/prokishi-server/` … Wails v3 デスクトップアプリ。**独立したネストモジュール**（`replace github.com/ShinteLab/prokishi => ../../` で親モジュールを参照）。ビルドには frontend のビルドが別途必要（`npm install` → `wails build`）

### suteme

将棋盤の画像から、SFEN と呼ばれる盤の情報を抜き出そうとしているプロジェクト。
学習用のコード (`training`) やモデルデータ (`data`) を含みます。

import パス: `github.com/ShinteLab/suteme`, `github.com/ShinteLab/suteme/training`

### kicho（棋帳）

将棋情報サイトから棋譜を取得して保存し、外部ツールへ HTTP で配信する Wails3 デスクトップアプリ。
将来的には棋譜データベースにしたい。

（旧称 `kifu`、旧実装は Node.js + express。「棋譜」は共有モジュール `core/web/kifu.js` や
URL など各所で使う語で紛らわしいため、プロジェクト名を `kicho` に変更した）

import パス: `github.com/ShinteLab/kicho`（`scrape`, `store`, `httpapi`, `settings` のサブパッケージ）

- `_cmd/kicho/` … Wails3 デスクトップアプリ。**独立したネストモジュール** `kicho-app`
- 保存先は `os.UserConfigDir()/kicho/`（SQLite。ドライバは PureGo の `modernc.org/sqlite`）
- KIF 形式の仕様は `core/kifu`（Go）/ `core/web/kifu.js`（JS）に集約

ShogiHome 等の外部ツール向けに HTTP エンドポイントを持つ（既定 `127.0.0.1:3000`）:

| ルート | 内容 |
|---|---|
| `GET /kifu` | 保存済み棋譜の一覧（JSON） |
| `GET /kifu/{id}` | 保存済み棋譜を KIF で返す |
| `GET /ryuoh/kifu/{id}` | 読売から直接取得して KIF を返す（Node 版との互換） |

読売のペイロードは Nuxt の IIFE で値が変数共有されており文字列パースでは解けないため、
goja（PureGo の JS エンジン）で評価している。

（Go モジュールには含まれません）

## 開発メモ

- 各サブプロジェクト（core / kicho を除く engine / prokishi / suteme）は移行元の git 履歴を `.git` として保持しています。
- `_cmd` などアンダースコア始まりのディレクトリは Go ツールの通常ビルド (`go build ./...`) から除外されます。これらのエントリポイントが必要とする依存（例: `_cmd/prokishi` が使う `github.com/BurntSushi/toml`）は `go mod tidy` の走査対象外のため、`prokishi/go.mod` に手動で保持しています。
