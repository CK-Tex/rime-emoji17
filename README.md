# 自用 Emoji 17 独立 Rime 输入方案

**注意：本项目完全是用 GPT 5.5 Vibe 出来的，个人刚刚接触 Rime ，很多标准和特性还不了解，因此可能有一些 bug 。**

**正确渲染 Emoji 需要合适的字体。**

这是一个独立的 Emoji 输入方案，不挂到拼音方案里，避免普通拼音候选被 emoji 挤占。

## 安装

把以下文件复制到 Rime 用户目录：

```text
emoji_u17.schema.yaml
emoji_u17.tsv
emoji_u17_categories.tsv
lua/emoji_u17.lua
lua/emoji_u17_processor.lua
```

在 `default.custom.yaml` 添加：

```yaml
patch:
  schema_list/+:
    - schema: emoji_u17
```

重新部署，然后切换到 `Emoji 17`。

## 用法

### 普通搜索

直接输入关键词拼音、简拼、英文名或英文关键词：

```text
k
kaixin
xiaolian
heart
flagchina
taiwan
```

普通搜索模式下，候选右侧不显示备注，尽量减少横排候选宽度。

### 分类搜索

输入 `v` 显示分类提示：

```text
v
```

候选示例：

```text
国旗
表情
人物
动物
```

继续输入完整分类码后列出该分类全部 emoji：

```text
vguoqi
vbiaoqing
vren
vdongwu
vshiwu
vjiaotong
vfuhao
```

分类模式下，emoji 候选右侧可以显示简体中文备注，例如：

```text
🇨🇳  中国
😁  呲牙
```

输入分类前缀时也会提示，并在前缀足够明确时直接把该分类的 emoji 列在后面。例如：

```text
vbiao
```

会先显示“表情”，下面直接显示表情类 emoji。

在分类提示页，可以按数字键、空格或回车跳到对应分类。例如输入 `vbiao` 后按 `1`，输入码会变成 `vbiaoqing`，然后显示表情列表。

## 候选数量

本方案的 `menu/page_size` 已设为 `10`，第 10 项用 `0` 选择。

## 左右键

这个方案里左右键、Home、End 会被 Lua processor 吃掉，避免光标移动到输入串中间导致候选错乱。翻页请用 `[`、`]`、`-`、`=` 或 PageUp/PageDown。

生成数据包含 Emoji 17 的 fully-qualified emoji 和 component。

以下内容被加入作为搜索码：

```text
rime-emoji 中文关键词
中文关键词拼音
中文关键词简拼
中文关键词常用同义词
Unicode 英文全名
Unicode 英文单词
Unicode 英文相邻词组
类别名和子类别名
旗帜国家/地区英文名
性别、肤色变体继承基础 emoji 关键词
```