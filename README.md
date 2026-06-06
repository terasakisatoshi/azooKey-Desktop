# azooKey on macOS

[azooKey](https://github.com/ensan-hcl/azooKey)のmacOS版です。高精度なニューラルかな漢字変換エンジン「Zenzai」を導入した、オープンソースの日本語入力システムです。

このリポジトリは ensan-hcl/azooKey を Fork したものです．

### Julia Unicode Completion

直接入力した `\` から、Julia REPL 風の Unicode 補完を使えます。

- `Tab`: 完全一致を確定、または候補の共通接頭辞まで補完
- `Space`: 候補を開く、または次候補へ移動
- `Shift+Space` / `Up`: 前候補へ移動
- `Down`: 次候補へ移動
- `Enter`: 選択中候補を確定。一致がなければ入力中の `\foo` をそのまま確定
- `Escape`: Julia 補完をキャンセル

例:

- `\alpha` -> `α`
- `\:koala:` -> `🐨`
- `\^n` -> `ⁿ`


### 推奨環境
* macOS 15+
* Xcode 26.1+
* Git LFS導入済み
* SwiftLint導入済み

### 開発版のビルド・デバッグ

まず、想定環境が整っていることを確認してください。 git-lfs のない状態では正しく clone できません。

cloneする際には`--recursive`をつけてサブモジュールまでローカルに落としてください。

```bash
git clone https://github.com/azooKey/azooKey-Desktop --recursive
```

#### Zenzaiの重みファイルの取得

かな漢字変換に使う Zenzai の重みファイルは、Hugging Face のサブモジュール内で Git LFS 管理されています。clone 後、以下を実行して重みファイル本体を取得してください。

```bash
git submodule update --init --recursive
git -C azooKeyMac/Resources/zenz-v3.1-small-gguf lfs pull --include=ggml-model-Q5_K_M.gguf
```

正しく取得できている場合、`ggml-model-Q5_K_M.gguf` は約70MBのファイルになります。

```bash
ls -lh azooKeyMac/Resources/zenz-v3.1-small-gguf/ggml-model-Q5_K_M.gguf
```

このファイルが100B程度で、先頭が `version https://git-lfs.github.com/spec/v1` となっている場合は、LFSのポインタだけが残っており、重みファイル本体が取得できていません。その場合は Git LFS を導入したうえで、上記の `git -C ... lfs pull` を再実行してください。

submodule が更新されている場合は `git submodule update --init --recursive` を行ってください。その後、以下のスクリプトで `Release` 構成の開発版をビルド・インストールできます。配布版と同様に最適化が有効になります。

```bash
# submoduleを更新
git submodule update --init --recursive
git -C azooKeyMac/Resources/zenz-v3.1-small-gguf lfs pull --include=ggml-model-Q5_K_M.gguf

# Release 構成でビルドして ~/Library/Input Methods にインストール
./install.sh --ignore-lint
```

### リリース版と並行して開発版を再インストールする

`/Library/Input Methods/azooKeyMac.app` にリリース版が入っている状態で開発版も試したい場合は、別 bundle id の user-local input method として入れ直すと衝突を避けられます。以下の例では `azooKey Julia` という名前で再インストールします。

配布版と同様に `Release` 構成でビルドします。最適化が有効になり、実使用時のパフォーマンスに近い状態で試せます。

下記のコマンドをそのままコピーandペーストしてください:

```bash
BUILD_DIR=/tmp/azookey-julia-dev-install
APP_SRC="$BUILD_DIR/Build/Products/Release/azooKeyMac.app"
APP_DST="$HOME/Library/Input Methods/azooKeyJulia.app"

xcodebuild -project ./azooKeyMac.xcodeproj \
  -scheme azooKeyMac \
  -configuration Release \
  -derivedDataPath "$BUILD_DIR" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  build

rm -rf "$APP_DST"
cp -R "$APP_SRC" "$APP_DST"

/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier local.atelierarith.inputmethod.azooKeyJulia" "$APP_DST/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleName azooKeyJulia" "$APP_DST/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :InputMethodConnectionName local.atelierarith.inputmethod.azooKeyJulia_Connection" "$APP_DST/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :ComponentInputModeDict:tsInputModeListKey:com.apple.inputmethod.Japanese:TISInputSourceID local.atelierarith.inputmethod.azooKeyJulia.Japanese" "$APP_DST/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :ComponentInputModeDict:tsInputModeListKey:com.apple.inputmethod.Roman:TISInputSourceID local.atelierarith.inputmethod.azooKeyJulia.Roman" "$APP_DST/Contents/Info.plist"

cat > "$APP_DST/Contents/Resources/en.lproj/InfoPlist.strings" <<'EOF'
CFBundleName = "azooKey Julia";
com.apple.inputmethod.Roman = "azooKey Julia (English)";
com.apple.inputmethod.Japanese = "azooKey Julia (日本語)";
EOF

codesign --force --deep --sign - --entitlements ./azooKeyMac/azooKeyMac.entitlements "$APP_DST"
"/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister" -f -R -trusted "$APP_DST"
killall TextInputMenuAgent cfprefsd
```

その後、「設定」>「キーボード」>「入力ソース」から `azooKey Julia` を追加してください。既に `azooKey Julia` を入れている場合は、一度削除してから追加し直すと確実です。

### pkgファイルの作成
`pkgbuild.sh`によって配布用のdmgファイルを作成できます。`build/azooKeyMac.app` としてDeveloper IDで署名済みの.appを配置してください。

### Julia Unicode symbol tables の更新

`extern/julia` の参照実装を更新したら、次のコマンドで Swift の生成テーブルを再生成してください。

```bash
swift ./tools/generate_julia_unicode_symbols.swift
```
