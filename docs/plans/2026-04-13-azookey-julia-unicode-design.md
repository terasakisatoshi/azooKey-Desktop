# azooKey Julia Unicode Design

## Goal

azooKey の通常の日本語変換を維持したまま、直接入力した `\` を起点にだけ Julia REPL 風の Unicode 補完を起動できるようにする。

対象機能は次の 3 系統を最初から含む。

- LaTeX 風補完: `\alpha` -> `α`
- Emoji 補完: `\:koala:` -> `🐨`
- 上付き / 下付き補完: `\^n` -> `ⁿ`, `\_(123)n` -> `₍₁₂₃₎ₙ`

## Constraints

- 通常のかな漢字変換フローは壊さない
- 発火条件は「`\` の直接入力」のみ
- 操作感は Julia REPL 寄りにする
- 候補 UI は既存の azooKey 候補窓を流用する
- 既存の `Shift+Ctrl+U` コードポイント入力は別機能として維持する

## Recommended Architecture

### Mode split

azooKey の主状態とは別に、Julia 補完を明示的なサブモードとして扱う。

- 通常入力: 既存の `none` / `composing` / `previewing` / `selecting` / `replaceSuggestion`
- Julia 補完: `juliaComposing` / `juliaSelecting`
- 既存 Unicode コードポイント入力: `unicodeInput`

`juliaComposing` / `juliaSelecting` への遷移は `\` の直接入力時だけに限定する。

### Responsibility split

- `Core`
  - Julia 辞書
  - 正規化
  - 完全一致 / 前方一致 / 上付き下付き解決
  - 純粋な Julia 補完状態機械
- `azooKeyMac`
  - `NSEvent` からの発火
  - marked text 更新
  - 候補窓への表示
  - 確定 / キャンセル / 候補移動

この分割により、複雑なロジックは `Core` でテストし、`azooKeyMac` 側は薄い IMK 統合に留める。

## Data Model

Julia 補完は controller 側で持つセッションを 1 つ持つ。

- `buffer`: 現在の入力文字列。例: `\alp`
- `selectedIndex`: 候補選択中のインデックス
- `matches`: resolver が返した候補配列

候補は既存候補窓に載せるため、表示用に次の情報を持つ。

- `text`: 確定時に挿入する Unicode 文字列
- `annotation`: 元のトリガー。例: `\alpha`, `\:koala:`

## Trigger Rules

### Entering Julia mode

- `none` 中に `\` を直接入力したら `juliaComposing` に入る
- `composing` / `previewing` / `selecting` 中に `\` を直接入力したら、先に現在の marked text を確定し、その後 `juliaComposing` に入る
- `replaceSuggestion` 中は Julia 補完を優先せず、まず replace suggestion を閉じてから `juliaComposing` に入る

### Staying in Julia mode

`juliaComposing` 中は英数字と `:`, `_`, `^`, `(`, `)` など Julia 補完に必要な記号をバッファへ追加する。かな漢字変換には渡さない。

## Interaction Design

### Marked text

- `juliaComposing` 中は生の入力を marked text として見せる
  - 例: `\alpha`
- `juliaSelecting` 中は選択中候補の Unicode を focused 表示し、必要なら annotation は候補窓側で見せる

### Candidate window

既存の `CandidatesViewController` をそのまま使う。Julia 候補では以下の表示にする。

- 候補本文: `α`
- 注釈: `\alpha`

複数候補がある場合のみ候補窓を表示する。完全一致 1 件だけなら候補窓なしでもよいが、選択中表示との一貫性を優先して、選択モードに入ったときは 1 件でも候補窓を許容する。

## Key Behavior

Julia REPL 寄りの操作に合わせる。

- `Tab`
  - 完全一致があれば即確定
  - 完全一致がなく、単一候補または共通接頭辞があればバッファを伸ばす
  - それ以外は `juliaSelecting` に入る
- `Space`
  - 候補があれば `juliaSelecting` に入る / 次候補へ進む
- `Shift+Space`
  - `juliaSelecting` 中は前候補へ戻る
- `Up` / `Down`
  - `juliaSelecting` 中の候補移動
- `Enter`
  - 選択中候補があれば確定
  - 完全一致があればその Unicode を確定
  - 一致がなければ生の `\foo` をそのまま確定
- `Escape`
  - Julia 補完だけキャンセルして通常状態へ戻る
- `Backspace`
  - バッファを 1 文字削除
  - 空になったら Julia 補完を終了

## Dictionary Strategy

辞書は Julia 本家 `stdlib/REPL` の定義を元に生成した Swift ソースとして持つ。

- `extern/julia/stdlib/REPL/src/latex_symbols.jl`
- `extern/julia/stdlib/REPL/src/emoji_symbols.jl`

上付き / 下付きは Julia 本家と同様に 1 文字辞書 + 連続変換ルールで解決する。

手書き辞書にすると追随コストが高いので、生成スクリプトを用意して生成物をチェックインする。

## Error Handling

- 未一致入力はクラッシュさせず、そのままリテラル確定できるようにする
- 辞書にない入力でも候補窓を空表示しない
- replace suggestion / prediction window と競合する場合は Julia 補完を優先し、他ウィンドウを閉じる
- 日本語変換の残り状態がある場合は、Julia 補完開始前に安全に commit する

## Testing Strategy

### Core unit tests

- `\alpha` の完全一致
- `\:koala:` の完全一致
- `\^n`, `\^(123)n`, `\_123` の解決
- 部分一致 `\:ko`
- full-width reverse solidus の正規化
- `Tab` / `Space` / `Enter` / `Escape` / `Backspace` を含む Julia 補完状態遷移

### Integration checks

- 日本語 composing 中に `\` を押すと composing を確定して Julia 補完へ入る
- 候補窓に Unicode 本文 + trigger 注釈が出る
- `Enter` で Unicode が挿入される
- 未一致はリテラル確定される

## Implementation Notes

- `SegmentsManager` のかな漢字候補はそのまま使い、Julia 候補は controller 側の別配列で管理する
- `refreshMarkedText` と `refreshCandidateWindow` だけ Julia 補完用の分岐を追加する
- `CandidatesViewControllerDelegate` は Julia 補完中だけ controller 内の Julia 選択状態を更新する

## Out of Scope

- かな混じりの Julia 補完入力
- 曖昧検索
- `?` ヘルプ相当の逆引き表示
- VS Code 拡張等への横展開
