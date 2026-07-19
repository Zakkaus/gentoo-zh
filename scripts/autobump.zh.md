# autobump 使用说明

[English](autobump.md)

对 nvchecker 报告的、**可机械升级**的包执行自动 bump:更新版本号、重新生成 Manifest、执行一次实际 emerge 验证,通过后创建 PR。无法机械处理的情况(需人工修改依赖 / USE / patch,或缺少 vendor bundle)仅在 issue 上记录证据,不创建 PR。**所有 PR 均经人工 review 后合并,不会自动 merge。**

## 开启 / 关闭单个包

在 `.github/workflows/overlay.toml` 中为该包添加一行 `autobump = true`:

```toml
["net-proxy/mihomo"]
source = "github"
github = "MetaCubeX/mihomo"
autobump = true          # 添加此行开启;删除即关闭
```

未添加该行的包不会被 autobump。若某个包频繁产生错误的 PR,删除该行即可停用。适合开启的类型:`-bin` 预编译包、单文件源码包,以及 vendor 内容稳定的 rust / npm 包。

若某个包需要刻意保留多个版本,在 `autobump = true` 旁再加一行 `keep_old = N`:bump 时保留最近 N 个版本(新增新版、删除更旧的),而非只替换最新那一个——例如 `app-misc/go-yq-bin`、`media-fonts/sarasa-gothic` 用 `keep_old = 2`。`keep_old = 0` 表示保留全部版本。

## 查找可开启的包(推荐)

`autobump-recommend`(Actions → autobump-recommend → Run workflow)会定期将**尚未开启、但可能可机械 bump** 的包汇总至**同一个 issue**,每次就地更新正文,不重复创建 issue。数据来源有三个:

- `scripts/autobump-discover.sh`:扫描 git 历史,列出最近若干次升级均为纯机械 bump 的包。
- `scripts/autobump-probe.sh`:对当前处于 open 状态的 nvchecker issue 实际运行 `--check`,列出当前判定为可机械、但尚未开启的包。
- **Trial 已 build 通过**:一小批尚未开启的可机械候选包,经真实 build trial(gentoo 容器,独立的 `trial-build` job)实际 build + install 通过。这是最强的信号,因为它越过分类判定、直到真实 build。

以上均为推荐,需人工 review 后自行添加 `autobump = true`,不会自动开启。discover 与 probe 脚本也可在本地单独运行。

## 使用方法

- **手动运行**:仓库 → Actions → autobump → Run workflow。`issues` 留空表示处理所有 open 的 nvchecker issue(未开启的自动跳过);`limit` 为本次处理数量上限。
- **对候选包做 build-test**(未开启的包):仓库 → Actions → autobump-trial → Run workflow,`targets` 填 nvchecker issue 号(空格分隔)。在 CI 容器内对每个目标执行真实的 bump + emerge + install + pkgcheck 并汇报 PASS/FAIL——不创建 PR、无需 opt-in。用于在添加 `autobump = true` 前确认某个包能机械 build 通过。
- **本地运行**:先将引擎 clone 至 overlay 根目录(`git clone https://github.com/gentoo-zh/autobump-rb`),安装 `dev-lang/ruby`,然后运行 `AUTOBUMP_ENGINE='ruby autobump-rb/bin/autobump' bash scripts/autobump-sweep.sh [issue#...] [--limit N] [--pr]`。
- **定时运行**:`autobump.yml` 顶部的 cron 默认为注释状态;手动运行数次确认稳定后取消注释,即每日自动运行。

## 引擎的三种判定结果

- **可机械处理**:仅更新版本、emerge 通过 → 创建 PR。
- **需人工处理**:大版本跳变、依赖变化、`files/` 中的 patch 需重新验证、缺少 per-version vendor bundle → 在 issue 上记录证据,不创建 PR。
- **暂缓**:网络 / 镜像 / 上游文件暂不可用,或某个过重的依赖在 binhost 没有对应 binpkg、需从源码编译超出 CI 限时——下次自动重试。

创建的 PR 仍需通过 `emerge-on-pr` 与 `pkgcheck`,并经人工 review 后合并。每次运行处理的 issue 及各自结果(bumped / deferred / skip),见该次 Actions run 日志末尾的 sweep summary。

---

引擎实现、判定细节、部署与运维见引擎仓库:**[autobump-rb](https://github.com/gentoo-zh/autobump-rb)**。
