<div align="right">

[English](./CONTRIBUTING.en.md) | 简体中文 | [正體中文](./CONTRIBUTING.zh-TW.md)

</div>

# 为 gentoo-zh 贡献

**不要破坏用户的系统。**

我们欢迎所有人贡献，但请提交者在提交前谨慎确认。

## ebuild 质量

* 用所继承的 [eclass](https://devmanual.gentoo.org/eclass-reference/index.html) 都支持的最新 [EAPI](https://devmanual.gentoo.org/ebuild-writing/eapi/index.html)。
* 字符串变量展开要用双引号引用：`"${P}"`，而非 `${P}`。
* 编码风格按 [Policy Guide](https://projects.gentoo.org/qa/policy-guide/ebuild-format.html#pg0101)：tab 缩进、用 `${foo}` 不用 `$foo`、用 `[[ ]]` 不用 `[ ]`。
* 不要用符号链接，例如 `foobar-1.2.3.ebuild -> foobar-9999.ebuild`。每个 ebuild 都要是独立文件。
* 不要依赖已弃用的 EAPI、eclass 和软件包，清单见 [Policy Guide](https://projects.gentoo.org/qa/policy-guide/deprecation.html) 和 `$(portageq get_repo_path / gentoo)/profiles/package.deprecated`。
* bash 补全、init.d 脚本、logrotate 配置、systemd unit 这类小文件一律安装，不要用 USE 标志控制。因为它们不增加构建依赖，也不明显拉长构建时间，见 [PG 0301](https://projects.gentoo.org/qa/policy-guide/installed-files.html#pg0301)。
* 不改变编译产物、仅引入可选运行时依赖的 USE 标志也不要加，改用 `optfeature` 提示用户，见 [PG 0001](https://projects.gentoo.org/qa/policy-guide/dependencies.html#pg0001)。
* 在打开 pull request 前，请先在本地运行 `pkgcheck scan --commits --net`。

## 授权

* `LICENSE` 要与上游实际授权一致。授权不在 `::gentoo` 时把全文放进 [`licenses/`](./licenses)，归入 [`profiles/license_groups`](./profiles/license_groups) 的相应分组，并按其散布条款设置 `RESTRICT`。
* 上游授权文件与源码文件头要同时核对：文件头没有 `or later` 时是 `GPL-3`，不是 `GPL-3+`。
* Rust、Go、Node 软件包捆绑依赖，`LICENSE` 要一并列出依赖的授权，用 `dev-util/cargo-license` 和 `dev-go/lichen` 核对。
* [`RESTRICT`](https://devmanual.gentoo.org/ebuild-writing/variables/index.html#restrict) 按散布条款设置：distfile 不可镜像用 `mirror`，二进制包不可再散布用 `bindist`。

## 依赖打包

因为 Portage 默认启用 `FEATURES=network-sandbox`，所以不要使用 `EGO_SUM`。
请把依赖打包成 tarball，发布后从 `SRC_URI` 取用，用法见
[gentoo-deps](https://github.com/gentoo-zh/gentoo-deps)。

## 版本追踪

* 新增的软件包需要添加到 [`.github/workflows/overlay.toml`](./.github/workflows/overlay.toml) 中，并按照 `category/package` 的字母顺序插入相应位置。如果可以自动 bump，参见 [scripts/autobump.zh.md](./scripts/autobump.zh.md)。
* 如果软件包不适合使用 nvchecker 检查版本更新，请在对应位置添加注释并说明原因。当多个 nvchecker 条目指向同一来源时，也请注释其中之一；该包若可启用 autobump 则可例外。
* `prefix` 只把版本号开头的该前缀去掉，不筛选版本。上游在同一个仓库还发布其他 tag 时，使用 `include_regex` 或 `exclude_regex` 筛选，两者都对原始 tag 做完整匹配。
* 写好条目后执行一次 `nvchecker -c <config> -k <keyfile>`，确认它选择了你期望的版本。

## 提交

* pull request 中的每个提交都要包含所需的所有修改，不要无故拆分，例如 ebuild 和它的 `Manifest` 要在同一个提交里。
* 每个 ebuild 修改在提交前要确保编译正确。
* 使用 [pull request 模板](./.github/pull_request_template.md)。

建议用 `pkgdev commit` 生成提交信息。版本升级格式如下：

```
$category/$package: add $new_version, drop $old_version
```

其他改动格式如下：

```
$category/$package: one line short description message

multiple lines of description about why you change this.
if you change to fix the bug, and if there is an GitHub
issue entry for that bug, then point the bug link here.
```

## CI

* CI 的 [`PORTAGE_ELOG_CLASSES`](https://wiki.gentoo.org/wiki/Portage_log#Setup) 是 `qa warn error`。
* `einfo`、`elog`、`ewarn`、`eerror`、`eqawarn` 的用法遵循 [devmanual](https://devmanual.gentoo.org/ebuild-writing/messages/index.html)。
* 请检查并修正 pkgcheck report 和 CI 报出的错误，QA 提示也要处理。
* CI 会在 amd64 和 arm64 上构建。如果在你没有的架构上出现无法解决的问题，请移除那个 keyword。

## 维护

* 新增的软件包请持续维护。
* 不再维护自己的软件包时，请在 issues 里找新维护者，或者在 [`profiles/package.mask`](./profiles/package.mask) 里 mask，到期后再移除。
* 移除软件包时，一并移除它在 [`.github/workflows/overlay.toml`](./.github/workflows/overlay.toml) 中的条目。

## AI 政策

可以用生成式 AI 辅助，但它必须遵守 [AGENTS.md](./AGENTS.md)，且每个提交由贡献者负责：确保 ebuild 的质量和验证功能正确，ebuild 要实际做一遍冒烟测试再提交，pull request 描述要简短、精准、专业，写实测结果而不是猜测。贡献者、提交者与提交作者必须是人类，不能是 AI 工具或模型身份。

## 参考

### 本仓库

* [AGENTS.md](./AGENTS.md)：本仓库的详细规范，生成式 AI 辅助时必须遵守
* [scripts/autobump.zh.md](./scripts/autobump.zh.md)：autobump 的接入方式
* [gentoo-deps](https://github.com/gentoo-zh/gentoo-deps)：生成依赖 tarball 的 workflow
* [依赖关系表](https://github.com/gentoo-zh/overlay/blob/deps-table/relation.md)：软件包之间的依赖

### Gentoo 官方

* [Gentoo Development Manual](https://devmanual.gentoo.org/)：写 ebuild 的总纲
* [Basic guide to write Gentoo Ebuilds](https://wiki.gentoo.org/wiki/Basic_guide_to_write_Gentoo_Ebuilds)：入门
* [Package Manager Specification](https://projects.gentoo.org/pms/8/pms.html)：EAPI 8 的规范原文
* [eclass reference](https://devmanual.gentoo.org/eclass-reference/index.html)：各 eclass 的变量、phase 与支持的 EAPI
* [Python Guide](https://projects.gentoo.org/python/guide/)：`distutils-r1` 与 Python 软件包
* [Repository format](https://wiki.gentoo.org/wiki/Repository_format)：`metadata/`、`profiles/` 与 `layout.conf` 的格式
* [Package testing](https://wiki.gentoo.org/wiki/Package_testing)：本地测试与 QA 检查的配置
* [Gentoo Policy Guide](https://projects.gentoo.org/qa/policy-guide/)：QA 政策原文，pkgcheck 的规则
* [License groups](https://wiki.gentoo.org/wiki/License_groups)：`ACCEPT_LICENSE` 与授权分组
* [A better ebuild workflow with pure git and pkgcheck](https://blogs.gentoo.org/mgorny/2019/12/12/a-better-ebuild-workflow-with-pure-git-and-pkgcheck/)：`pkgdev` 的用法与理由
* [GURU CONTRIBUTING.md](https://github.com/gentoo/guru/blob/master/CONTRIBUTING.md)：官方社区 overlay 的常见错误与建议
