# 项目架构

## Java 项目

- 不允许写行尾注释，注释必须另起一行
- 所有常规代码开发必须参照已有代码，比如 po, mapper 等格式
- 不允许出现魔法值，必须新建枚举
- 工具类必须全局搜索，不要重复定义
- 不允许使用 import \*，必须显式引入依赖
- request/response vo/controller 必须要有 swagger 注解
- 所有 java 文件必须有完整的 javadoc（pojo，enum, service，interface 等）
- author 写 liwenxuan01

## 数据库相关

- 所连数据库均假定为读写分离，在先写后读场景需要提前考虑读写分离导致读不到的问题（使用 master hint 或者事务）

# 项目约束

在使用 openspec / superpowers 完成一个较大需求后，需自动按照以上开发规范重新 review 代码，并修复不规范的代码

### 工程约定

- **subagent-driven 开发:按依赖分层跨 worktree 并行,不要串行逐任务**:`[2026-07-17]` 现象:一次需求用 superpowers:subagent-driven-development 跑了 2.86h,32 个 subagent **完全串行零并行**(implement 占 59% / review 14% / 编排间隙 22%)→ 根因:任务列表是线性的,规划阶段没产出依赖 DAG,导致跨 repo(如 giraffe / leopard / adnest 三个 worktree)本可并行的早期任务排成一条线 → 防御性约定:规划阶段就把任务组织成**依赖 DAG**,同一层无依赖的任务并行分发(尤其跨服务/跨 worktree 的任务天然可并行),只在出现跨 repo 依赖点时汇合。可借助 superpowers:dispatching-parallel-agents。**注意:多 worktree 并行跑单测会互抢 CPU,须配合上面的单测加速约定。**

- **review 分级:低风险机械任务不开独立 review subagent**:`[2026-07-17]` 现象:同一 session 开了 14 个独立 review agent(占 14% 墙钟),其中不少是给 DTO / enum / PO+Mapper / VO 这类机械代码做的 → 根因:对所有任务一视同仁地"实现 agent + review agent"两跳,低风险任务的 review 性价比低,且每次 subagent 冷启动都要重读 brief+依赖上下文(纯开销)→ 防御性约定:① 低风险机械任务(DTO/enum/PO/VO/简单 Mapper)让 implement agent 自查即可,不开独立 review;只对高风险任务(cache service、parser、gateway、有复杂分支/外部契约的服务)保留独立 review。② 同一 repo 的多个机械小任务尽量**合并成一个更粗的任务**,减少 subagent 冷启动次数。

### 工程约定

- **Java 单测 TDD 内循环加速(leopard 等多模块 Maven 项目)**:`[2026-07-17]` 现象:`mvn -pl <mod> test -Dtest=X` 改一个文件重跑要 28~43s,而测试本身只跑 0.1s → 根因:Maven compiler 插件默认 `useIncrementalCompilation=true` 实为"脏检测触发全量重编",改 1 个文件会 `Compiling 1263 source files` 全量重编整个模块;jacoco 不是主因 → 防御性约定:subagent 做 TDD 内循环(反复改代码重跑)时用下面这条命令,实测 43s→7~8s(快 5.5 倍,测试真实执行不跳过):

  ```
  mvn -o -pl <module> test-compile surefire:test -Dtest=<测试类> \
    -Djacoco.skip=true -Dmaven.compiler.useIncrementalCompilation=false \
    -DfailIfNoTests=false -Dsurefire.failIfNoSpecifiedTests=false -q
  ```

  三个关键开关按贡献:`-Dmaven.compiler.useIncrementalCompilation=false`(最大,砍掉全量重编)> `-o`(离线,跳依赖检查)> `-Djacoco.skip=true`。代码没改只想复跑 → 只调 `surefire:test`(约 4s)。**任务收尾校验必须去掉这些加速开关、跑 `-am` 全量**,确认没破坏依赖模块。多 worktree/多 session 并行跑 mvn 会互抢 CPU 拖慢,此约定在并行场景收益叠乘。
