# CLAUDE.md

如无必要，勿增实体。中文回复，言简意赅，直接执行。巧用 Emoji，按需使用 Plan Mode。
不确定时主动用 `AskUserQuestion` 向用户提问。

<important if="you are debugging or fixing a bug">

- 定位底层根因，禁止前端遮丑
</important>

<important if="you are creating a git commit">

- 每个小功能原子化独立提交，不碰无关代码
- Commit message 须包含: 问题描述 / 复现路径 / 修复思路
</important>

<important if="you need to search the web for current information">

- 用 `/web-search` skill（inferen.sh：Exa + Tavily）
</important>

<important if="you need to conduct in-depth research on a topic">

- 用 `/deep-research` skill（199-biotechnologies，8 阶段方法论 + 引用验证）
</important>

<important if="you need to browse the web, inspect a page, take screenshots, or interact with any website">

- 使用 `/browse` skill（gstack），**禁止**使用 `mcp__claude-in-chrome__*` 工具
</important>

<important if="you are about to use, import, or configure a third-party library">

- 用 `context7` skill（`ctx7` CLI）查询最新文档，禁止依赖过时训练数据
</important>

<important if="you are building React or Next.js applications">

- 用 `vercel-react-best-practices` skill（Vercel 官方 React/Next.js 最佳实践）
</important>

## gstack

可用 skills: `/office-hours`, `/plan-ceo-review`, `/plan-eng-review`, `/plan-design-review`, `/design-consultation`, `/review`, `/ship`, `/browse`, `/qa`, `/qa-only`, `/design-review`, `/setup-browser-cookies`, `/retro`, `/investigate`, `/document-release`, `/codex`, `/careful`, `/freeze`, `/guard`, `/unfreeze`, `/gstack-upgrade`
