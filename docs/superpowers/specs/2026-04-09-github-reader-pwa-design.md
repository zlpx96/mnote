# GitHub Reader PWA — Design Spec

**Date:** 2026-04-09  
**Status:** Approved

---

## Overview

一个 PWA 移动端应用，通过 GitHub API 读取私有仓库中的 Markdown 文件，支持多仓库切换，部署到 GitHub Pages，无需服务器。

**目标用户：** 个人使用  
**核心功能：** 浏览私有仓库的 Markdown 文件  
**技术栈：** Vue 3 + Vite + Vue Router + marked.js  
**部署：** GitHub Pages（静态托管，免费）

---

## 架构

### 目录结构

```
src/
  views/
    Setup.vue        # 首次配置：输入 Token
    RepoList.vue     # 仓库列表
    FileTree.vue     # 仓库文件树
    MarkdownView.vue # MD 文件渲染
  composables/
    useGitHub.js     # GitHub API 封装
    useStorage.js    # Token / 仓库列表本地存储
  router/index.js
  App.vue
public/
  manifest.json      # PWA 配置
  sw.js              # Service Worker
```

### 数据流

1. 首次打开 → Setup 页面输入 Personal Access Token → 存入 localStorage
2. 主页显示已添加的仓库列表，可增删
3. 点击仓库 → 显示文件树（支持展开目录）
4. 点击 `.md` 文件 → 获取文件内容 → marked.js 渲染

### GitHub API

| 接口 | 用途 |
|------|------|
| `GET /user/repos` | 获取用户仓库列表 |
| `GET /repos/{owner}/{repo}/contents/{path}` | 获取文件树或文件内容 |

认证方式：请求头 `Authorization: Bearer <token>`

---

## 页面设计

### Setup 页面
- 输入 GitHub Personal Access Token（需要 `repo` 读取权限）
- 验证 Token 有效性（调用 `/user` 接口）
- 验证通过后跳转仓库列表，Token 存入 localStorage
- 之后不再显示，除非用户主动重置

### 仓库列表页
- 卡片列表，显示仓库名和描述
- 右上角：「添加仓库」按钮（搜索并添加）、「设置」入口（重置 Token）
- 点击仓库卡片进入文件树

### 文件树页
- 顶部 breadcrumb 路径导航，支持点击跳转上级
- 文件列表：目录和 `.md` 文件用不同图标区分，其他文件类型置灰不可点击
- 点击目录展开，点击 `.md` 文件进入阅读器

### Markdown 阅读器页
- 全屏阅读模式
- 顶部返回按钮
- 基础 Markdown 渲染（标题、加粗、列表、代码块）
- 字体大小适合手机阅读（16px+，行高 1.6）

---

## PWA 配置

- `manifest.json`：应用名、图标、主题色、`display: standalone`
- Service Worker：缓存已读的 MD 文件内容，支持离线查看
- 支持「添加到主屏幕」

---

## 错误处理

| 场景 | 处理方式 |
|------|----------|
| Token 无效 / 过期 | 提示用户重新设置 Token |
| API 限流（5000次/小时） | 提示等待并显示重置时间 |
| 网络断开 | 显示 Service Worker 缓存内容 |
| 仓库无 `.md` 文件 | 显示空状态提示 |

---

## 不在范围内

- Markdown 编辑 / 提交
- Issue、PR 管理
- 推送通知
- 多用户 / 团队功能
- 数学公式、Mermaid 图表渲染
