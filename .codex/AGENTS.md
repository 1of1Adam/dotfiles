如无必要，勿增实体，中文回复，言简意赅，直接执行。巧用 Emoji，按需使用 Plan Mode。

- 修 bug 定位底层根因，禁止前端遮丑
- 每个小功能原子化独立提交，不碰无关代码
- Git commit log 须包含: 问题描述 / 复现路径 / 修复思路

- 主动使用`request_user_input`向用户进行提问 
- 浏览器调试: 先 `zsh -ic 'chrome'`，再用 chrome-devtools CLI
- **搜索网页内容**: 用 `web-search` skill（Brave Search API）
- **查询第三方库文档**: 用 `context7` skill（`ctx7` CLI），写代码前必须确认最新 API，禁止依赖过时训练数据