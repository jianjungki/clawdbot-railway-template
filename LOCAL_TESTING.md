# Railway 本地部署测试指南

本指南将帮助你在本地环境中模拟 Railway 的部署效果，确保线上部署不会出现问题。

## 前置要求

- 已安装 Docker（版本 20.10+）
- 已安装 Docker Compose（可选）

## 方法一：使用 Docker 构建和测试（推荐）

这种方法完全模拟 Railway 的部署环境。

### 1. 构建 Docker 镜像

```bash
# 使用与 Railway 相同的 Dockerfile 构建镜像
docker build -t moltbot-railway-test .
```

**注意**：构建过程可能需要 10-20 分钟，因为需要从源码编译 moltbot。

### 2. 运行容器

```bash
# 使用与 Railway 相同的环境变量运行容器
docker run -d \
  --name moltbot-test \
  -p 8080:8080 \
  -e PORT=8080 \
  -e MOLTBOT_PUBLIC_PORT=8080 \
  moltbot-railway-test
```

### 3. 查看容器日志

```bash
# 实时查看日志
docker logs -f moltbot-test

# 或者查看最近的日志
docker logs --tail 100 moltbot-test
```

### 4. 测试健康检查端点

```bash
# Railway 使用这个端点进行健康检查
curl http://localhost:8080/setup/healthz
```

预期响应：HTTP 200 OK

### 5. 测试应用程序

在浏览器中访问：
- http://localhost:8080

或使用 curl：
```bash
curl http://localhost:8080
```

### 6. 停止和清理

```bash
# 停止容器
docker stop moltbot-test

# 删除容器
docker rm moltbot-test

# 删除镜像（可选）
docker rmi moltbot-railway-test
```

## 方法二：使用 Docker Compose（简化版）

创建 `docker-compose.test.yml` 文件后运行：

```bash
# 启动服务
docker-compose -f docker-compose.test.yml up --build

# 后台运行
docker-compose -f docker-compose.test.yml up -d --build

# 停止服务
docker-compose -f docker-compose.test.yml down
```

## 方法三：快速本地测试（不使用 Docker）

如果你只想快速测试wrapper逻辑而不想等待完整的Docker构建：

### 1. 安装依赖

```bash
npm install
```

### 2. 运行开发服务器

```bash
npm run dev
```

**注意**：这种方法不会构建真实的 moltbot，只测试 wrapper 服务器，不能完全模拟 Railway 环境。

## 常见问题排查

### 构建失败

1. **网络问题**：确保可以访问 GitHub 和 npm registry
2. **磁盘空间**：确保有至少 5GB 可用空间
3. **Docker 资源**：增加 Docker Desktop 的内存限制（推荐 4GB+）

### 容器启动失败

```bash
# 检查容器状态
docker ps -a

# 查看详细日志
docker logs moltbot-test

# 检查端口占用
netstat -ano | findstr :8080  # Windows
lsof -i :8080                 # Linux/Mac
```

### 健康检查超时

Railway 配置的健康检查超时时间是 300 秒（5分钟）。首次启动可能需要较长时间初始化 moltbot。

```bash
# 持续监控健康状态
while true; do curl -s -o /dev/null -w "%{http_code}\n" http://localhost:8080/setup/healthz; sleep 5; done
```

## 环境变量测试

如果需要测试特定的环境变量：

```bash
docker run -d \
  --name moltbot-test \
  -p 8080:8080 \
  -e PORT=8080 \
  -e MOLTBOT_PUBLIC_PORT=8080 \
  -e YOUR_ENV_VAR=value \
  moltbot-railway-test
```

## 性能测试

### 简单压力测试

```bash
# 使用 curl 进行简单测试
for i in {1..10}; do
  curl -s -o /dev/null -w "Request $i: %{http_code} - %{time_total}s\n" http://localhost:8080/setup/healthz
done
```

### 使用 ab (Apache Bench)

```bash
# 安装 ab
# Windows: 下载 Apache httpd
# Linux: apt-get install apache2-utils
# Mac: 已预装

# 运行测试（100个请求，并发10）
ab -n 100 -c 10 http://localhost:8080/setup/healthz
```

## 验证清单

在部署到 Railway 之前，确保以下检查都通过：

- [ ] Docker 镜像成功构建
- [ ] 容器可以正常启动
- [ ] 健康检查端点返回 200
- [ ] 应用程序可以通过浏览器访问
- [ ] 日志中没有错误信息
- [ ] 容器可以正常重启
- [ ] 端口 8080 正确暴露
- [ ] 环境变量正确传递

## 与 Railway 的差异

需要注意的是，本地测试与 Railway 环境的一些差异：

1. **网络环境**：Railway 提供公网访问和自动 HTTPS
2. **持久化存储**：Railway 提供卷挂载，本地测试时数据会在容器删除后丢失
3. **环境变量**：Railway 可能会注入额外的环境变量
4. **资源限制**：Railway 有内存和 CPU 限制

## 自动化测试脚本

运行项目提供的烟雾测试：

```bash
npm run smoke
```

这将自动测试关键端点是否正常工作。
