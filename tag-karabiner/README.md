# tag-karabiner

Karabiner-Elements 配置，通过软链接部署到 `~/.config/karabiner/`。

## 软链接结构

`~/.config/karabiner/assets/complex_modifications/` 下所有 `*.json` 均为软链接，
真实文件在本仓的 `config/karabiner/assets/complex_modifications/` 下。

用 Edit/Write 类工具直接写软链接路径会被拒绝（"Refusing to write through symlink"），
需先 `readlink -f <symlink>` 解析出真实路径，再对真实路径操作。

## 规则匹配顺序

Karabiner complex_modifications 的 `manipulators` 数组按顺序匹配，
**命中第一条满足条件的规则就停止**，不会继续尝试后面更精确的规则。

因此当同一个 `from` 按键有多条规则、且修饰键条件有包含关系时
（例如一条 `modifiers: {"optional": ["any"]}`、一条 `modifiers: {"mandatory": ["left_command"]}`），
**更精确（modifiers 更严格）的规则必须排在更宽泛的规则前面**，
否则宽泛规则会抢先命中，精确规则永远执行不到。
