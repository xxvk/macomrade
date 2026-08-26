# OpenCode 选型配置（plan3 / plan4）

模型与价格依据见 [`../llm-pricing-and-features.md`](../llm-pricing-and-features.md)。
两份配置引用的**每个模型都已用 `opencode run` 实测通过**。

## 两份配置的定位

| | plan3 | plan4 |
| --- | --- | --- |
| 用途 | DeepSeek **空闲时段**（半价） | 以 **Gemini** 为核心，扁平计价 |
| 生效时间 | 北京时间工作日 9–12、14–18 **以外** | 高峰时段 |
| 成本特征 | 最低，但随时段波动 | 主力模型走赠送配额，域内模型兜底 |

| agent | plan3 | plan4 |
| --- | --- | --- |
| build | `deepseek/deepseek-v4-pro` | `google/gemini-3.7-flash` |
| plan | `minimax-cn/MiniMax-M3` | `google/gemini-3.6-flash` |
| general | `alibaba-cn/qwen3.7-flash` | `google/gemini-3.1-flash-lite` |
| scout | `doubao/doubao-seed-2-0-mini-260428` | `google/gemini-3.5-flash-lite` |
| reviewer | `minimax-cn/MiniMax-M3` | `zhipuai/glm-5.1` |
| tester | `zhipuai/glm-4.7-flashx` | `google/gemini-3.5-flash-lite` |
| compaction | `minimax-cn/MiniMax-M3` | `minimax-cn/MiniMax-M3` |
| title | `doubao/doubao-seed-2-0-mini-260428` | `google/gemini-3.1-flash-lite` |
| summary | `alibaba-cn/qwen3.7-flash` | `google/gemini-3.5-flash-lite` |

**reviewer 和 compaction 刻意留在域内模型上**：reviewer 与 build 错开厂商，避免同源模型的
相关性盲区；compaction 是会话记忆，一旦 Gemini 配额耗尽，它必须还能把上下文压缩完。

## 安装

```bash
cp plan3.json plan4.json ~/.config/opencode/
mkdir -p ~/.config/opencode/agent
cp agent/reviewer.md agent/tester.md ~/.config/opencode/agent/
```

### 环境变量

| 变量 | 平台 | 获取 |
| --- | --- | --- |
| `DEEPSEEK_API_KEY` | DeepSeek | platform.deepseek.com |
| `DASHSCOPE_API_KEY` | 阿里云百炼（Qwen） | bailian.console.aliyun.com |
| `MINIMAX_API_KEY` | MiniMax（minimaxi.com） | platform.minimaxi.com |
| `ZHIPU_API_KEY` | 智谱 BigModel | bigmodel.cn |
| `ARK_API_KEY` | 火山方舟（豆包） | console.volcengine.com/ark |
| `GEMINI_API_KEY` | Google Gemini | aistudio.google.com |

`DASHSCOPE_API_KEY` 里的 DashScope（灵积）是阿里这套服务的旧名，现在叫「百炼 / Model Studio」，
但 base URL 和 SDK 约定的变量名仍沿用旧称，拿的就是百炼控制台那把 key。

## 按时段自动选配置

```bash
# ~/.zshrc
oc() {
  local h dow
  h=$(TZ=Asia/Shanghai date +%H); dow=$(TZ=Asia/Shanghai date +%u)
  # DeepSeek 高峰：北京时间周一至周五 09:00-11:59、14:00-17:59
  if (( dow <= 5 )) && { (( h >= 9 && h < 12 )) || (( h >= 14 && h < 18 )); }; then
    OPENCODE_CONFIG=~/.config/opencode/plan4.json command opencode "$@"
  else
    OPENCODE_CONFIG=~/.config/opencode/plan3.json command opencode "$@"
  fi
}
```

## 实测发现（2026-08-24）

### Gemini：这把 key 只有 Flash 档可用，Pro 档不可用

逐个实测结果：

| 型号 | 结果 |
| --- | --- |
| `gemini-3.7-flash`（1M / 64K） | ✅ |
| `gemini-3.6-flash`（1M / 64K） | ✅ |
| `gemini-3.5-flash-lite`（1M / 64K） | ✅ |
| `gemini-3.1-flash-lite`（1M / 64K） | ✅ |
| `gemini-3.1-pro-preview` | ❌ `You exceeded your current quota` |
| `gemini-3.5-flash` | ❌ 同上 |
| `gemini-pro-latest` | ❌ `UnknownError` |

配额是**按型号**给的，且不连续（3.5-flash 不可用而 3.6/3.7-flash 可用）。
因此 plan4 的 build 是 **Flash 档**而不是 Pro 档——`gemini-3.7-flash` 有 1M 上下文和 64K 输出，
但它终究不是 Pro 级模型。若发现复杂任务力不从心，把 build 换回
`doubao/doubao-seed-evolving`（6/30/1.2，Coding/Agent 专用）或 `minimax-cn/MiniMax-M3`。

**配额不可依赖**：赠送额度随时可能耗尽或收紧，plan4 的主力全在 Gemini 上，
一旦断供需要手动切回 plan3 或改 build 模型。

### `@ai-sdk/google` 只认 `GOOGLE_GENERATIVE_AI_API_KEY`

只设 `GEMINI_API_KEY` 会报 `Google Generative AI API key is missing`，
尽管 models.dev 的 provider 定义里列了三个变量名。

本配置的解法是在 `provider.google.options.apiKey` 里写 `{env:GEMINI_API_KEY}` 显式映射，
**不需要改 shell 配置**，已实测在只有 `GEMINI_API_KEY` 的环境下跑通。

### `zhipuai/glm-4.7` 在 OpenCode 里基本不可用

7 次调用只成功 1 次，其余返回**空输出**（无报错）。直接打智谱 API 一切正常
（`content` 有值，另带一大段 `reasoning_content`），问题出在 OpenCode /
`@ai-sdk/openai-compatible` 对该模型思考内容的解析。

同厂的 `glm-4.7-flashx`、`glm-5.1`、`glm-5.2` 均稳定（各 3/3 通过），
故 reviewer 用 `glm-5.1`。**价格表里 glm-4.7 那行价格正确，但在 OpenCode 场景下暂不可选。**

### 豆包 model ID 必须带日期后缀，且可用版本因账号而异

裸名 `doubao-seed-2-0-mini` 会返回 `does not exist or you do not have access to it`。
列出账号实际可用版本：

```bash
curl -s https://ark.cn-beijing.volces.com/api/v3/models \
  -H "Authorization: Bearer $ARK_API_KEY" | jq -r '.data[] | select(.status != "Shutdown") | .id'
```

本账号 `mini`/`lite` 只有 `-260428` 可用（`-260215` 返回 404），而 `pro` 只有 `-260215` 可用。
`doubao-seed-2-1-pro`、`doubao-seed-2-1-turbo` 需在控制台单独开通。

### 豆包最大输出是 128K，不是 4K

早前依据第三方资料写的「默认最大输出 4K」是错的。Ark `/models` 接口对 `doubao-seed-2-0-*`
报告 `max_output_token_length: 131072`、`context_window: 262144`、`max_input_token_length: 229376`。

### 环境变量建议放 `~/.zshenv`

zsh 只在**交互式** shell 加载 `~/.zshrc`。key 写在那里时，从脚本、cron、CI 启动 opencode
读不到。放 `~/.zshenv` 则所有 shell 都加载。日常终端手敲命令不受影响。

## 其他注意事项

- **四家（DeepSeek / 阿里 / MiniMax / 智谱 / Google）用 models.dev 内置 provider**，
  自带上下文长度、价格、能力元数据；只有豆包不在 models.dev 里，需自定义。
  `doubao` 这个 provider id 是本配置自取的，改名需同步改 `agent` 里的引用。
- **MiniMax 内置 provider 走 Anthropic 端点**（`api.minimaxi.com/anthropic/v1`）。
  它的 OpenAI 兼容接口不支持 `developer` 角色，自己配 OpenAI 端点会报错。
- **`compaction` 的上下文必须覆盖 build**。`MiniMax-M3` 是 1M 上下文
  （512K 只是价格分档边界，不是长度上限），覆盖两份配置里的任何 build 模型都够。
- **`title` / `summary` 必须显式配置**，否则跟随主模型，每个会话标题都按 build 的输出价计费。
- **豆包的 `cost` 字段按 1 USD = 7.2 CNY 换算**，仅用于 OpenCode 成本显示，不是计费依据。
- **`reviewer` / `tester` 不是 OpenCode 内置 agent**，靠 `agent/*.md` 定义。
  内置 `scout` 的官方职责是外部文档调研，与此处「代码侦察」用法不同；
  要严格对齐 OpenCode 语义应改用内置的 `explore`。
