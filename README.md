# Moltbot Railway Template (1‑click deploy)

This repo packages **Moltbot** for Railway with a small **/setup** web wizard so users can deploy and onboard **without running any commands**.

## What you get

- **Moltbot Gateway + Control UI** (served at `/` and `/moltbot`)
- A friendly **Setup Wizard** at `/setup` (protected by a password)
- Persistent state via **Railway Volume** (so config/credentials/memory survive redeploys)
- One-click **Export backup** (so users can migrate off Railway later)

## How it works (high level)

- The container runs a wrapper web server.
- The wrapper protects `/setup` with `SETUP_PASSWORD`.
- During setup, the wrapper runs `moltbot onboard --non-interactive ...` inside the container, writes state to the volume, and then starts the gateway.
- After setup, **`/` is Moltbot**. The wrapper reverse-proxies all traffic (including WebSockets) to the local gateway process.

## Railway deploy instructions (what you’ll publish as a Template)

In Railway Template Composer:

1) Create a new template from this GitHub repo.
2) Add a **Volume** mounted at `/data`.
3) Set the following variables:

Required:
- `SETUP_PASSWORD` — user-provided password to access `/setup`

Recommended:
- `MOLTBOT_STATE_DIR=/data/.moltbot`
- `MOLTBOT_WORKSPACE_DIR=/data/workspace`

Optional:
- `MOLTBOT_GATEWAY_TOKEN` — if not set, the wrapper generates one (not ideal). In a template, set it using a generated secret.

Notes:
- This template pins Moltbot to a known-good version by default via Docker build arg `MOLTBOT_VERSION`.

4) Enable **Public Networking** (HTTP). Railway will assign a domain.
5) Deploy.

Then:
- Visit `https://<your-app>.up.railway.app/setup`
- Complete setup
- Visit `https://<your-app>.up.railway.app/` and `/moltbot`

## Getting chat tokens (so you don’t have to scramble)

### Telegram bot token
1) Open Telegram and message **@BotFather**
2) Run `/newbot` and follow the prompts
3) BotFather will give you a token that looks like: `123456789:AA...`
4) Paste that token into `/setup`

### Discord bot token
1) Go to the Discord Developer Portal: https://discord.com/developers/applications
2) **New Application** → pick a name
3) Open the **Bot** tab → **Add Bot**
4) Copy the **Bot Token** and paste it into `/setup`
5) Invite the bot to your server (OAuth2 URL Generator → scopes: `bot`, `applications.commands`; then choose permissions)

## 本地测试

### 方法一：使用自动化测试脚本（推荐）

我们提供了便捷的测试脚本，完全模拟 Railway 部署环境：

**Windows (PowerShell):**
```powershell
# 运行完整测试（构建、启动、健康检查）
.\scripts\test-local.ps1

# 或分步执行
.\scripts\test-local.ps1 build   # 仅构建镜像
.\scripts\test-local.ps1 start   # 启动容器
.\scripts\test-local.ps1 test    # 测试健康检查
.\scripts\test-local.ps1 logs -Follow  # 查看实时日志
.\scripts\test-local.ps1 clean   # 清理资源
```

**Linux/Mac (Bash):**
```bash
# 运行完整测试
./scripts/test-local.sh

# 或分步执行
./scripts/test-local.sh build    # 仅构建镜像
./scripts/test-local.sh start    # 启动容器
./scripts/test-local.sh test     # 测试健康检查
./scripts/test-local.sh follow   # 查看实时日志
./scripts/test-local.sh clean    # 清理资源
```

**使用 Docker Compose:**
```bash
# 一键启动测试环境
docker-compose -f docker-compose.test.yml up --build

# 后台运行
docker-compose -f docker-compose.test.yml up -d --build

# 停止并清理
docker-compose -f docker-compose.test.yml down
```

测试成功后访问: http://localhost:8080

📚 **详细测试指南**: 请查看 [`LOCAL_TESTING.md`](LOCAL_TESTING.md) 获取完整的测试说明、故障排查和最佳实践。

### 方法二：手动测试

```bash
docker build -t moltbot-railway-template .

docker run --rm -p 8080:8080 \
  -e PORT=8080 \
  -e SETUP_PASSWORD=test \
  -e MOLTBOT_STATE_DIR=/data/.moltbot \
  -e MOLTBOT_WORKSPACE_DIR=/data/workspace \
  -v $(pwd)/.tmpdata:/data \
  moltbot-railway-template

# 访问 http://localhost:8080/setup (密码: test)
```

### 验证清单

在部署到 Railway 前，确保：
- ✅ Docker 镜像成功构建
- ✅ 容器正常启动
- ✅ 健康检查端点 `/setup/healthz` 返回 200
- ✅ 可以通过浏览器访问应用
- ✅ 日志中没有错误信息
