# 多平台支持 + 图片上传设计文档

## 背景

mnote 目前只支持 GitHub。本次改动新增 Gitee 支持（两个平台可同时配置、随时切换），并在 FileTree 页面增加图片上传功能（上传到当前浏览的仓库目录）。

## 功能范围

1. **多平台支持**：GitHub 和 Gitee 同时配置，独立存储各自 token、仓库列表和缓存，通过页面按钮切换当前激活平台。
2. **图片上传**：在 FileTree 页面上传图片（jpg/png/gif/webp）到当前目录，上传后刷新文件列表。

---

## 数据层设计

### localStorage key 变更

| 旧 key | 新 key | 说明 |
|---|---|---|
| `mnote_token` | `mnote_token_github` / `mnote_token_gitee` | 按平台分开存 |
| `mnote_repos` | `mnote_repos_github` / `mnote_repos_gitee` | 按平台分开存 |
| `mnote_cache_{path}` | `mnote_cache_{platform}_{path}` | 缓存加平台前缀 |
| `mnote_scroll_{path}` | `mnote_scroll_{platform}_{path}` | 滚动位置加平台前缀 |
| —— | `mnote_platform` | 当前激活平台，`'github'` 或 `'gitee'` |

首次启动时若检测到旧 `mnote_token` 存在，自动迁移为 `mnote_token_github`。

### `useStorage.js` 新增接口

```js
getPlatform()                    // 返回当前激活平台，默认 'github'
setPlatform(platform)            // 切换当前平台
getToken(platform?)              // 不传 platform 则用当前激活平台
setToken(token, platform?)
clearToken(platform?)            // 只清该平台的 token + 缓存
getRepos(platform?)
addRepo(repo, platform?)
removeRepo(fullName, platform?)
```

---

## API 层设计

### `useGitProvider(platform, token)`

替换现有 `useGitHub`，对外接口完全一致，新增 `uploadFile`：

```js
validateToken()
searchRepos(query)
getContents(owner, repo, path)
getFileContent(owner, repo, path)
putFile(owner, repo, path, content, sha)       // 文本文件，内部做 UTF-8→base64
getFileSha(owner, repo, path)
uploadFile(owner, repo, path, base64, sha)     // 图片，直接传 base64
```

### 平台差异

| 差异点 | GitHub | Gitee |
|---|---|---|
| Base URL | `https://api.github.com` | `https://gitee.com/api/v5` |
| Auth header | `Authorization: Bearer {token}` | `Authorization: token {token}` |
| 搜索接口 | `GET /search/repositories?q=` | `GET /repos/search?q=` |
| Rate limit | `X-RateLimit-Reset` header | 无，统一当 403 处理 |

文件读写接口（contents）两者路径结构相同，可共用。

内部用 `_base(platform)` 和 `_headers(platform, token)` 两个私有函数封装差异，其余逻辑共用。

---

## UI 层设计

### Setup 页面

- 新增平台选择：两个 Tab（GitHub / Gitee），各自有独立的 token 输入框和验证按钮
- 已配置的平台显示绿色勾，未配置显示灰色
- 底部"开始使用"按钮：进入 app，默认激活第一个已配置的平台

### RepoList / 顶部栏

- 页面顶部右侧加平台切换按钮（`GitHub ⇄ Gitee` 样式，或两个 tab）
- 切换后仓库列表、收藏夹立即切换到对应平台数据
- 未配置的平台点击切换后跳转到 Setup 配置对应 token

### FileTree 页面

- 顶部操作区现有"＋新建文件"按钮旁边加"↑上传图片"按钮
- 点击触发隐藏的 `<input type="file" accept="image/*">`
- 上传流程：
  1. 用户选择图片文件
  2. 读取为 base64（`FileReader`）
  3. 调用 `uploadFile(owner, repo, currentPath + '/' + filename, base64)`
  4. 上传中显示 loading 状态，按钮禁用
  5. 成功后刷新当前目录文件列表
  6. 失败显示错误提示

---

## 错误处理

- `UNAUTHORIZED`：行为与现有一致，跳转 `/setup`
- `RATE_LIMIT`：Gitee 无 reset header，显示"请求过于频繁，请稍后再试"
- 图片上传文件大小：GitHub 单文件 API 限制 ~100MB，Gitee 限制 ~1MB（base64 后），超限时给用户明确提示
- 同名文件：先调 `getFileSha` 检查是否存在，存在则覆盖（传 sha），不存在则新建

---

## 不在本次范围内

- 上传非图片文件
- 上传后自动插入 Markdown 链接
- 多文件批量上传
- GitLab 或其他平台支持
