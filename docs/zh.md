# tmux-autosize（中文說明）

> English README: [../README.md](../README.md)

**讓 tmux 視窗不再卡在 `80x24` 或某個過時尺寸。四個 hook 會把每個視窗自動收斂到「正在看它的那個 client」的實際大小。**

## 這是什麼？

tmux 三不五時會把視窗留在錯的尺寸——最經典的就是那個迷你的 `80x24` 預設值——而且它會一直卡著，直到你手動戳它一下才恢復。這在幾種很常見的情況都會發生：

- **背景建立的視窗**（`new-window -d`，或是腳本／agent 自動開的視窗）從沒被任何 client 看過，所以誕生時就是預設尺寸，然後就卡在那。
- **`window-size manual` 使用者**——一旦你關掉 tmux 的自動縮放，非作用中的視窗會維持上次的尺寸，不會跟著 client 走。
- **終端在還沒到最終大小就 attach**（tiling 視窗管理器、還原 session、慢速 SSH）會讓視窗慢一拍。
- **拖拉 resize 的過程中**，tmux 會短暫看到一堆中間尺寸。

tmux-autosize 裝上四個 hook——attach 時、resize 時、切換視窗時、建立視窗時——每個都用明確的 `resize-window -x -y` 把受影響的視窗收斂到目前 client 的真實寬高。第五個 hook 負責補做那些因為你正在捲動（copy-mode）而被延後的 resize（見下方 copy-mode 說明）。沒有狀態列、沒有 token、沒有顏色——它只修尺寸。

> **誠實定位。** 如果你用 tmux 預設的 **`window-size latest`**，tmux 本來就會自己把作用中視窗對齊到最新的 client，所以對你來說這個外掛比較像一個**保險絲**——它接住那些漏網的情況（背景／腳本建立的視窗、第二個 client attach、在終端穩定前就發生的 attach）。如果你用 **`window-size manual`**（開始寫腳本開視窗、或跑多個 client 之後很常見），tmux 會刻意停止自動縮放，這時這個外掛就變成**維持視窗正確尺寸的那個關鍵**。copy-mode 守衛是對「resize 觸發 scrollback 重排」這類成本的保守防禦——上游 [tmux/tmux#4814](https://github.com/tmux/tmux/issues/4814) 記錄的就是這一類（拖拉 resize＋超大歷史導致凍結；並非 copy-mode 專屬，所以說「保守」）。它和這個外掛家族的其他件共用 `@`-option 命名慣例，但對它們**零依賴**。

## 快速上手

不熟 tmux 的 `prefix` 鍵？預設 prefix 是 `Ctrl-b`——先按 `Ctrl-b`、放開，再按下一個鍵。（下面只有 `prefix + I` 會用到。）

你需要 **tmux 3.0 或更新版**（見[系統需求](#系統需求)）。從下面兩種安裝方式擇一，然後 reload。

### 1. 安裝外掛

#### 方式 A —— 用 TPM（tmux 外掛管理器）

沒裝過 TPM 的話先跑這三行（原封不動貼上）：

```sh
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
printf '\n%s\n' "run '~/.tmux/plugins/tpm/tpm'" >> ~/.tmux.conf
tmux source ~/.tmux.conf
```

（tmux 還沒啟動時，`tmux source` 可能印 "no server running"——沒關係，下次啟動 tmux 就會生效。）

然後加上 tmux-autosize。把這行放在 `~/.tmux.conf` 裡、`run '~/.tmux/plugins/tpm/tpm'` 那行的**上面**：

```tmux
set -g @plugin 'joneshong/tmux-autosize'
```

#### 方式 B —— 不用 TPM（一行，無外掛管理器）

Clone 到任何地方，然後在 `~/.tmux.conf` 加一行：

```sh
git clone https://github.com/joneshong/tmux-autosize ~/.tmux/plugins/tmux-autosize
printf '%s\n' "run-shell '~/.tmux/plugins/tmux-autosize/autosize.tmux'" >> ~/.tmux.conf
```

### 2.（選用）設定 options

所有 option 都有合理預設值，可以直接跳過。想改的話，放在 `~/.tmux.conf` 裡外掛那行的**前面**——見 [Options](#options)。

### 3. Reload（用 TPM 的話還要安裝）

```sh
tmux source ~/.tmux.conf   # 重新載入設定
```

用 **TPM** 的話，再按一次 `prefix + I`（大寫 i）把外掛抓下來。

就這樣。之後你的視窗會自己收斂到正確尺寸。

## Demo

*Demo GIF coming soon.*

## Options

以下都放在 `~/.tmux.conf` 外掛那行的**前面**，全部選用。

| Option | 預設 | 白話說明 |
|---|---|---|
| `@autosize-debounce-ms` | `250` | 一連串 resize 事件要「安靜」多久（毫秒）才真的收斂視窗。調大＝拖拉時更沉穩；調小＝反應更快。 |
| `@autosize-on-attach` | `on` | client attach 時收斂目前視窗。 |
| `@autosize-on-new-window` | `on` | 收斂剛建立的視窗（背景 `new-window -d` 卡尺寸就是靠這條修的）。 |
| `@autosize-on-select-window` | `on` | 切換到某視窗時收斂它（`window-size manual` 下特別重要）。 |
| `@autosize-copy-mode-safe` | `on` | 有 pane 在 copy-mode 時，延後它的 resize（離開時再補做），避開上游 re-wrap spin。只有在你確定要立即 resize 時才關掉。 |
| `@autosize-rebalance` | `off` | 視窗收斂之後，選擇性地重排它的 pane。`off` 交給 tmux 自己的等比例縮放；`spread` 把 pane 攤平均勻但*不*改變佈局形狀（`select-layout -E`）；`even-horizontal` / `even-vertical` / `tiled` 則套用對應的具名 tmux 佈局。其他值一律忽略。詳見 pane 比例那則 FAQ。 |
| `@autosize-debug` | `off` | 把每個動作寫一行到 runtime 目錄的 log（見最後一則 FAQ）。回報 bug 時很好用。 |

> **`@autosize-rebalance` 版本說明。** `spread` 用的是 `select-layout -E`，官方
> [tmux CHANGES](https://github.com/tmux/tmux/blob/master/CHANGES) 在
> **"CHANGES FROM 2.6 TO 2.7"** 加入（*"Add select-layout -E to spread panes out
> evenly"*）。`even-horizontal` / `even-vertical` / `tiled` 這幾個佈局更早就有。
> 全都低於這個外掛自己的 **tmux 3.0** 下限，所以 `@autosize-rebalance` 不需要比
> 外掛本來就要求的更新的 tmux。

把任何 option 設成 `on` 以外的值就會停用該 hook。要明確關掉某條：

```tmux
set -g @autosize-on-attach 'off'
```

> **注意：**選項是在外掛載入時讀取的。對已經在跑的 server 改選項，要先跑
> `scripts/teardown.sh` 再重新 source 設定（或重啟 tmux）才會生效——
> 單純 reload 不會改動已裝好的 hook。

## 解除安裝

跑內建的 teardown 腳本（只拆掉這個外掛裝的 hook、清掉它的 runtime 目錄），再刪掉資料夾：

```sh
~/.tmux/plugins/tmux-autosize/scripts/teardown.sh
rm -rf ~/.tmux/plugins/tmux-autosize
```

（用 TPM 安裝的話，也把 `~/.tmux.conf` 裡 `set -g @plugin '.../tmux-autosize'` 那行刪掉。）

teardown **只**會移除這個外掛裝進去的 hook 陣列元素——你或其他外掛在同一個事件上設的 hook 都會原封不動保留。

## 常見問題（FAQ）

**這會不會跟 tmux 自己的縮放打架？**
不會。在 `window-size latest` 下，tmux 本來就會把*作用中*視窗對齊到最新 client，所以外掛在那裡的 resize 是 no-op，只補 tmux 沒碰到的視窗（背景的、manual 下非作用中的、第二個 client 的）。對一個已經是正確尺寸的視窗做 resize 不會有任何效果。

**為什麼我在捲動／copy-mode 時，resize 會等一下？**
因為 resize 會迫使 tmux 重排該 pane 的 scrollback，歷史一大這個重排就很貴——上游 [tmux/tmux#4814](https://github.com/tmux/tmux/issues/4814) 記錄過這一類的凍結（拖拉 resize＋超大歷史）。而 copy-mode 正是你在使用 scrollback 的時刻，所以外掛選擇保守處理。`@autosize-copy-mode-safe on`（預設）時，外掛會記下想要的尺寸，在你一離開 copy-mode 就套用——最後你還是會是正確尺寸，只是晚一點。如果你從不會踩到這個 bug，可以把它設成 `off` 讓 resize 立即發生。

**它沒有 resize 一個沒有 client 的 detached／背景 session——為什麼？**
這是刻意的。外掛是把視窗收斂到*正在看它的那個 client* 的尺寸；沒有 client attach 就沒有尺寸可以對齊，所以它選擇什麼都不做、而不是亂猜。attach 一個 client，尺寸就會跟上。

**resize 之後我的 pane 比例會變嗎？**
預設**不會**——外掛只改**視窗**尺寸，tmux 自己會把 pane *等比例*縮放到新尺寸（原本佔一半寬的還是大約一半）。它不會跑 `select-layout`。

如果你*想要*每次收斂時重排 pane，就設 `@autosize-rebalance`：

- `spread`——把 pane 攤平均勻但*不*改變佈局形狀（`select-layout -E`）。
- `even-horizontal` / `even-vertical` / `tiled`——套用對應的具名 tmux 佈局。

跟 on/off 的 hook 開關不同，`@autosize-rebalance` 是*每次收斂時當場重讀*的，所以改了它會在**下一次** resize 生效，不用 teardown／reload——[Options](#options) 那則 running-server 備註是講 hook 安裝類的開關，不適用於這一個。

**我怎麼看它在做什麼？**
打開 debug log：

```tmux
set -g @autosize-debug 'on'
```

reload 後盯著看：

```sh
tail -f "${TMUX_TMPDIR:-/tmp}/tmux-autosize-$(id -u)/autosize.log"
```

每一行記一次 `resize:`、`defer:`（copy-mode）、或 `flush resize:`。

## 系統需求

- **tmux 3.0 或更新版。** 這個下限是對照官方原始資料查證的，不是猜的。外掛是靠**對 hook 陣列 option append**（`set-hook -ga <hook>` / `<hook>[N]` 索引語法）來裝 hook。hook 是在 tmux 3.0 才*變成*陣列 option——官方 [tmux CHANGES](https://github.com/tmux/tmux/blob/master/CHANGES) 在 **"CHANGES FROM 2.9 TO 3.0"** 明講：*"Hooks are now stored in the options tree as array options, allowing them to have multiple separate commands."* 在 tmux 2.9 或更舊版本上，append 會蓋掉使用者既有的 hook，所以那些版本不支援。
- **測試環境：** tmux `next-3.8`（開發版）on macOS，以及 CI 裡 `ubuntu-latest` 內建的 tmux（目前是 3.x）。headless 功能測試在兩邊都跑。
- **沒有額外 runtime 依賴**，只需要 tmux 和 POSIX shell——用到的 `awk`、`grep`、`date`、`stat` 之類 macOS／Linux 本來就有。debounce 計時器用 identity token 而非次秒級時間戳，所以就算 `date +%N` 不可用（原生 BSD／macOS）也照樣運作。

## 出處 / 授權

這套 resize 手法——明確 `-x/-y` 收斂、per-client 尺寸、避開 [tmux/tmux#4814](https://github.com/tmux/tmux/issues/4814) 所記錄那類 resize 重排成本的 copy-mode 延後／補做配對、以及給背景 `new-window -d` 用的 `TARGET_WIN` 定錨——是從作者私有 tmux resize 工具鏈抽出的通用核心。以 [MIT License](../LICENSE) 釋出。
