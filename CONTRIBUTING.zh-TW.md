<div align="right">

[English](./CONTRIBUTING.en.md) | [简体中文](./CONTRIBUTING.md) | 正體中文

</div>

# 為 gentoo-zh 貢獻

**不要破壞使用者的系統。**

我們歡迎所有人貢獻，但請提交者在提交前謹慎確認。

## ebuild 品質

* 用所繼承的 [eclass](https://devmanual.gentoo.org/eclass-reference/index.html) 都支援的最新 [EAPI](https://devmanual.gentoo.org/ebuild-writing/eapi/index.html)。
* 字串變數展開要用雙引號引用：`"${P}"`，而非 `${P}`。
* 編碼風格按 [Policy Guide](https://projects.gentoo.org/qa/policy-guide/ebuild-format.html#pg0101)：tab 縮排、用 `${foo}` 不用 `$foo`、用 `[[ ]]` 不用 `[ ]`。
* 不要用符號連結，例如 `foobar-1.2.3.ebuild -> foobar-9999.ebuild`。每個 ebuild 都要是獨立檔案。
* 不要相依已棄用的 EAPI、eclass 和套件，清單見 [Policy Guide](https://projects.gentoo.org/qa/policy-guide/deprecation.html) 和 `$(portageq get_repo_path / gentoo)/profiles/package.deprecated`。
* bash 補全、init.d 指令碼、logrotate 設定、systemd unit 這類小檔案一律安裝，不要用 USE 旗標控制。因為它們不增加建置相依性，也不明顯拉長建置時間，見 [PG 0301](https://projects.gentoo.org/qa/policy-guide/installed-files.html#pg0301)。
* 不改變編譯產物、僅引入選用執行期相依套件的 USE 旗標也不要加，改用 `optfeature` 提示使用者，見 [PG 0001](https://projects.gentoo.org/qa/policy-guide/dependencies.html#pg0001)。
* 在開啟 pull request 前，請先在本機執行 `pkgcheck scan --commits --net`。

## 授權

* `LICENSE` 要與上游實際授權一致。授權不在 `::gentoo` 時把全文放進 [`licenses/`](./licenses)，歸入 [`profiles/license_groups`](./profiles/license_groups) 的相應分組，並按其散布條款設定 `RESTRICT`。
* 上游授權檔與原始碼檔頭要同時核對：檔頭沒有 `or later` 時是 `GPL-3`，不是 `GPL-3+`。
* Rust、Go、Node 套件捆綁相依套件，`LICENSE` 要一併列出這些套件的授權，用 `dev-util/cargo-license` 和 `dev-go/lichen` 核對。
* [`RESTRICT`](https://devmanual.gentoo.org/ebuild-writing/variables/index.html#restrict) 按散布條款設定：distfile 不可鏡像用 `mirror`，二進位套件不可再散布用 `bindist`。

## 相依套件打包

因為 Portage 預設啟用 `FEATURES=network-sandbox`，所以不要使用 `EGO_SUM`。
請把相依套件打包成 tarball，發布後從 `SRC_URI` 取用，用法見
[gentoo-deps](https://github.com/gentoo-zh/gentoo-deps)。

## 版本追蹤

* 新增的套件需要加入 [`.github/workflows/overlay.toml`](./.github/workflows/overlay.toml)，並按照 `category/package` 的字母順序插入相應位置。如果可以自動 bump，參見 [scripts/autobump.zh.md](./scripts/autobump.zh.md)。
* 如果套件不適合使用 nvchecker 檢查版本更新，請在對應位置加上註解並說明原因。當多個 nvchecker 條目指向同一來源時，也請註解其中之一；該套件若可啟用 autobump 則可例外。
* `prefix` 只把版本號開頭的該前綴去掉，不篩選版本。上游在同一個倉庫還發布其他 tag 時，使用 `include_regex` 或 `exclude_regex` 篩選，兩者都對原始 tag 做完整比對。
* 寫好條目後執行一次 `nvchecker -c <config> -k <keyfile>`，確認它選擇了你期望的版本。

## 提交

* pull request 中的每個提交都要包含所需的所有修改，不要無故拆分，例如 ebuild 和它的 `Manifest` 要在同一個提交裡。
* 每個 ebuild 修改在提交前要確保編譯正確。
* 使用 [pull request 範本](./.github/pull_request_template.md)。

建議用 `pkgdev commit` 產生提交訊息。版本升級格式如下：

```
$category/$package: add $new_version, drop $old_version
```

其他改動格式如下：

```
$category/$package: one line short description message

multiple lines of description about why you change this.
if you change to fix the bug, and if there is an GitHub
issue entry for that bug, then point the bug link here.
```

## CI

* CI 的 [`PORTAGE_ELOG_CLASSES`](https://wiki.gentoo.org/wiki/Portage_log#Setup) 是 `qa warn error`。
* `einfo`、`elog`、`ewarn`、`eerror`、`eqawarn` 的用法遵循 [devmanual](https://devmanual.gentoo.org/ebuild-writing/messages/index.html)。
* 請檢查並修正 pkgcheck report 和 CI 報出的錯誤，QA 提示也要處理。
* CI 會在 amd64 和 arm64 上建置。如果在你沒有的架構上出現無法解決的問題，請移除那個 keyword。

## 維護

* 新增的套件請持續維護。
* 不再維護自己的套件時，請在 issues 裡找新維護者，或者在 [`profiles/package.mask`](./profiles/package.mask) 裡 mask，到期後再移除。
* 移除套件時，一併移除它在 [`.github/workflows/overlay.toml`](./.github/workflows/overlay.toml) 中的條目。

## AI 政策

可以用生成式 AI 輔助，但它必須遵守 [AGENTS.md](./AGENTS.md)，且每個提交由貢獻者負責：確保 ebuild 的品質和驗證功能正確，ebuild 要實際做一遍冒煙測試再提交，pull request 描述要簡短、精準、專業，寫實測結果而不是猜測。貢獻者、提交者與提交作者必須是人類，不能是 AI 工具或模型身分。

## 參考

### 本倉庫

* [AGENTS.md](./AGENTS.md)：本倉庫的詳細規範，生成式 AI 輔助時必須遵守
* [scripts/autobump.zh.md](./scripts/autobump.zh.md)：autobump 的接入方式
* [gentoo-deps](https://github.com/gentoo-zh/gentoo-deps)：產生相依 tarball 的 workflow
* [相依關係表](https://github.com/gentoo-zh/overlay/blob/deps-table/relation.md)：套件之間的相依

### Gentoo 官方

* [Gentoo Development Manual](https://devmanual.gentoo.org/)：寫 ebuild 的總綱
* [Basic guide to write Gentoo Ebuilds](https://wiki.gentoo.org/wiki/Basic_guide_to_write_Gentoo_Ebuilds)：入門
* [Package Manager Specification](https://projects.gentoo.org/pms/8/pms.html)：EAPI 8 的規範原文
* [eclass reference](https://devmanual.gentoo.org/eclass-reference/index.html)：各 eclass 的變數、phase 與支援的 EAPI
* [Python Guide](https://projects.gentoo.org/python/guide/)：`distutils-r1` 與 Python 套件
* [Repository format](https://wiki.gentoo.org/wiki/Repository_format)：`metadata/`、`profiles/` 與 `layout.conf` 的格式
* [Package testing](https://wiki.gentoo.org/wiki/Package_testing)：本機測試與 QA 檢查的設定
* [Gentoo Policy Guide](https://projects.gentoo.org/qa/policy-guide/)：QA 政策原文，pkgcheck 的規則
* [License groups](https://wiki.gentoo.org/wiki/License_groups)：`ACCEPT_LICENSE` 與授權分組
* [A better ebuild workflow with pure git and pkgcheck](https://blogs.gentoo.org/mgorny/2019/12/12/a-better-ebuild-workflow-with-pure-git-and-pkgcheck/)：`pkgdev` 的用法與理由
* [GURU CONTRIBUTING.md](https://github.com/gentoo/guru/blob/master/CONTRIBUTING.md)：官方社群 overlay 的常見錯誤與建議
