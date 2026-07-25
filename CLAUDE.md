# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

将棋関連のプロジェクト群を並べた作業ディレクトリ。**各サブディレクトリが独立した Go モジュール**で、
それぞれ `github.com/ShinteLab/<ディレクトリ名>` として公開する（= 1 ディレクトリ 1 リポジトリ）。
ルートには go.mod を置かない。ドキュメント・コメントは日本語。

## リポジトリ構成

```
shinte/          （ここ自体はモジュールではない。go.mod は無い）
├── core/           共通基盤（SFEN/USI 仕様・フォント生成・共有フロント @shinte/web）
├── engine/         PureGo 将棋エンジン（bitboard・合法手生成・探索・USI）
├── prokishi/       USI をクライアント/サーバに分離する gRPC プロキシ
├── suteme/         盤画像 → SFEN の画像認識
└── kicho/          棋帳。棋譜の取得・保存・配信（Wails3 アプリ）
```

各サブディレクトリに個別の CLAUDE.md がある。そのディレクトリで作業するときは
まずそちらを読むこと。

| ディレクトリ | モジュールパス | 種別 |
|---|---|---|
| `core/` | `github.com/ShinteLab/core/sfen`, `github.com/ShinteLab/core/usi`, `github.com/ShinteLab/core/kifu`, `github.com/ShinteLab/core/web` | Go ライブラリ + `package main`(フォント生成) + JS 共有パッケージ |
| `engine/` | `github.com/ShinteLab/engine`, `github.com/ShinteLab/engine/search` | Go ライブラリ |
| `prokishi/` | `github.com/ShinteLab/prokishi` ほか (`api`,`client`,`db`,`registry`,`server`,`usi`) | Go ライブラリ + CLI + Wails3 アプリ |
| `suteme/` | `github.com/ShinteLab/suteme`, `github.com/ShinteLab/suteme/training` | Go ライブラリ + 学習用 Web サーバ |
| `kicho/` | `github.com/ShinteLab/kicho` ほか (`scrape`,`store`,`httpapi`,`settings`) | Go ライブラリ + Wails3 アプリ |

## 依存の方向（重要）

```
engine ─┐
suteme ─┼→ core (sfen / usi / kifu)   Go: 仕様は core に集約、逆参照はしない
kicho  ─┘
prokishi                              現状 core への Go 依存は無し（フロントのみ @shinte/web を使う）

prokishi(React) ─┐
suteme(素HTML)  ─┼→ core/web (@shinte/web)   フロント: 盤描画・SFEN/USI/KIF ロジック
core(*.html)    ─┘
```

- **将棋の仕様（SFEN / USI / KIF）は `core` に一本化する。** engine・suteme・prokishi・kicho は
  自前で重複実装を持たない。新しい表記変換が必要になったら core に足す。
- `core/sfen` の駒コードの整数値は engine の `PieceType` と**一致させてある**ので、
  engine は自身の駒種を変換なしで渡せる。**探索などのホットパスに変換を持ち込まない**
  設計であり、SFEN/USI 変換は「position 受信」「bestmove 出力」等の I/O 境界でのみ呼ぶ。
- 同じ仕様を Go 側 (`core/sfen`,`core/usi`,`core/kifu`) と JS 側 (`core/web`) の 2 ソースで持つ。
  挙動は `core/web/test.mjs` と Go 側テストのゴールデンで揃える。片方だけ直さない。

## よく使うコマンド

**ルートに go.mod は無いので、`go` コマンドは必ずサブプロジェクトのディレクトリで実行する。**

```powershell
cd core      # / engine / suteme / prokishi / kicho
go build ./...      # アンダースコア始まりのディレクトリは対象外
go test ./...
go vet ./...
```

全モジュールをまとめて回すなら:

```powershell
foreach ($d in "core","engine","suteme","prokishi","kicho") { Push-Location $d; go test ./...; Pop-Location }
```

サブプロジェクト固有のビルド（Wails3、学習サーバ、フォント生成など）は
各 CLAUDE.md を参照。

## モジュール構成の注意点

- モジュールは **5 つ + Wails3 アプリの 2 つ**、計 7 つ。

  | モジュールパス | 場所 |
  |---|---|
  | `github.com/ShinteLab/core` | `core/` |
  | `github.com/ShinteLab/engine` | `engine/` |
  | `github.com/ShinteLab/suteme` | `suteme/` |
  | `github.com/ShinteLab/prokishi` | `prokishi/` |
  | `github.com/ShinteLab/kicho` | `kicho/` |
  | `prokishi-server` | `prokishi/_cmd/prokishi-server/`（Wails3, alpha.98） |
  | `kicho-app` | `kicho/_cmd/kicho/`（Wails3, alpha2.117） |

- **モジュール間はすべて `replace` で相対パス参照している。** タグを打って
  proxy 経由で引く運用に切り替えるまでは、この replace を外さないこと。

  ```
  engine/go.mod                        replace .../core => ../core
  suteme/go.mod                        replace .../core => ../core
  kicho/go.mod                         replace .../core => ../core
  kicho/_cmd/kicho/go.mod              replace .../core => ../../../core, .../kicho => ../../
  prokishi/_cmd/prokishi-server/go.mod replace .../prokishi => ../../
  ```

- Wails3 アプリ 2 つの**バージョンが揃っていない。** 手元の CLI は alpha2.117 なので
  kicho はそれに合わせてある。prokishi を触るときはバージョン差に注意すること
  （alpha2.117 では `app.Window.NewWithOptions` など API 名が変わっている）。
  ビルドには frontend のビルドが別途必要（`npm install` → `wails3 build`）。
- `_cmd` / `_samples` / `_dist` / `_work` などアンダースコア始まりのディレクトリは
  Go ツールの通常ビルド (`go build ./...`) から**除外される**。そのため
  これらのエントリポイントだけが必要とする依存は `go mod tidy` の走査対象外になる。
  現状は `prokishi/go.mod` の `github.com/BurntSushi/toml`（`_cmd/prokishi` が使う）が該当。
  **`go mod tidy` の実行後は require 行が消えていないか確認すること。**
- `_cmd` 配下は「1 ファイル = 1 `main`」の動作確認用コマンドが同居していることがあり
  （特に `engine/_cmd`）、ディレクトリ単位ではビルドできない。ファイル指定でビルドする。
- `kicho/` のロジック側（`scrape`/`store`/`httpapi`/`settings`）は `kicho` モジュールに含まれるので
  `go build ./...` / `go test ./...` の対象。Wails アプリ本体だけが `_cmd` 配下で対象外。

## git について

**1 ディレクトリ = 1 リポジトリ**（`github.com/ShinteLab/<ディレクトリ名>`）。
ルートも `ShinteLab/shinte` という**ワークスペースリポジトリ**だが、
`.gitignore` で 5 つのサブディレクトリを除外しているので、追跡しているのは
このファイル・`README.md`・`bootstrap.ps1` だけ。

**git 操作は必ず対象サブプロジェクトのディレクトリで実行すること。**
ルートで `git add -A` しても 5 つは無視される（意図した挙動。取りこぼしではない）。

- submodule は使っていない。5 つを跨いで同時に編集するため、
  サブリポジトリを commit するたびにポインタ更新の commit が要る構成は割に合わない。
  タグを打って `replace` を外す段階で再検討する。
- clone 直後は `.\bootstrap.ps1` で 5 つを取得する（`-Verify` で build/test まで流す）。
  **replace が相対パス指定なので、5 つはこのディレクトリ直下に並んでいる必要がある。**
- `_org-github/` は org プロフィール（`ShinteLab/.github` の `profile/README.md`）の
  下書き置き場。別リポジトリとして切り出す前提で、ここでは追跡していない。

## 開発上の約束

- 実装は Sonnet サブエージェントに委譲し、メイン側は計画・指示・レビューに徹する運用。
- 新しい共通ロジックを書く前に、`core`（Go）/ `core/web`（JS）に既にないか確認する。
- ドキュメント（README.md / CLAUDE.md）は日本語で書く。
