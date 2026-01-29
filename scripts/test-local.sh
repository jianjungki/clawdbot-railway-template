#!/usr/bin/env bash
# Railway 本地测试脚本 (Bash)
# 用法: ./scripts/test-local.sh [选项]

set -e

IMAGE_NAME="moltbot-railway-test"
CONTAINER_NAME="moltbot-test"
PORT=8080

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

show_help() {
    cat << EOF
Railway 本地测试脚本

用法: ./scripts/test-local.sh [操作]

操作:
  build    仅构建 Docker 镜像
  start    启动容器（需要先构建）
  stop     停止容器
  logs     查看容器日志
  follow   实时跟踪日志输出
  test     测试健康检查端点
  clean    清理容器和镜像
  full     完整测试流程（默认）
  help     显示此帮助信息

示例:
  ./scripts/test-local.sh              # 运行完整测试
  ./scripts/test-local.sh build        # 仅构建镜像
  ./scripts/test-local.sh follow       # 实时查看日志
  ./scripts/test-local.sh test         # 测试健康检查
EOF
}

print_step() {
    echo -e "\n${CYAN}==> $1${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}$1${NC}"
}

check_docker() {
    if ! command -v docker &> /dev/null; then
        print_error "Docker 未安装或未运行"
        echo "请先安装 Docker: https://www.docker.com/get-started"
        exit 1
    fi
}

build_image() {
    print_step "构建 Docker 镜像..."
    print_warning "注意：这可能需要 10-20 分钟"
    
    if docker build -t "$IMAGE_NAME" .; then
        print_success "镜像构建成功"
    else
        print_error "镜像构建失败"
        exit 1
    fi
}

start_container() {
    print_step "启动容器..."
    
    # 检查容器是否已存在
    if docker ps -a --filter "name=$CONTAINER_NAME" --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        print_warning "容器已存在，正在删除..."
        docker rm -f "$CONTAINER_NAME" > /dev/null
    fi
    
    # 检查端口是否被占用
    if ss -lnt | grep -q ":$PORT"; then
        print_error "端口 $PORT 已被占用"
        echo "使用以下命令查看占用进程:"
        echo "  ss -ltnp | grep :$PORT"
        exit 1
    fi
    
    if docker run -d \
        --name "$CONTAINER_NAME" \
        -p "${PORT}:${PORT}" \
        -e "PORT=$PORT" \
        -e "MOLTBOT_PUBLIC_PORT=$PORT" \
        "$IMAGE_NAME"; then
        print_success "容器已启动"
        echo -e "${CYAN}容器名称:${NC} $CONTAINER_NAME"
        echo -e "${CYAN}访问地址:${NC} http://localhost:$PORT"
    else
        print_error "容器启动失败"
        exit 1
    fi
}

stop_container() {
    print_step "停止容器..."
    if docker stop "$CONTAINER_NAME" 2>/dev/null; then
        print_success "容器已停止"
    else
        print_warning "容器未运行或不存在"
    fi
}

show_logs() {
    print_step "查看容器日志..."
    docker logs --tail 50 "$CONTAINER_NAME"
}

follow_logs() {
    print_step "实时跟踪日志..."
    docker logs -f "$CONTAINER_NAME"
}

test_healthcheck() {
    print_step "测试健康检查端点..."
    
    # 检查容器是否运行
    if ! docker ps --filter "name=$CONTAINER_NAME" --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        print_error "容器未运行"
        exit 1
    fi
    
    print_warning "等待服务启动..."
    local max_attempts=60
    local attempt=0
    local success=false
    
    while [ $attempt -lt $max_attempts ]; do
        attempt=$((attempt + 1))
        echo -n "."
        
        if curl -sf "http://localhost:$PORT/setup/healthz" > /dev/null 2>&1; then
            success=true
            break
        fi
        
        sleep 5
    done
    
    echo ""
    
    if [ "$success" = true ]; then
        print_success "健康检查通过！"
        echo ""
        echo -e "${CYAN}测试访问主页:${NC}"
        if curl -sf "http://localhost:$PORT" > /dev/null; then
            print_success "主页访问成功"
        else
            print_error "主页访问失败"
        fi
    else
        print_error "健康检查失败（超时）"
        echo ""
        print_warning "查看日志以了解详情:"
        docker logs --tail 20 "$CONTAINER_NAME"
        exit 1
    fi
}

clean_all() {
    print_step "清理容器和镜像..."
    
    if docker rm -f "$CONTAINER_NAME" 2>/dev/null; then
        print_success "容器已删除"
    fi
    
    if docker rmi "$IMAGE_NAME" 2>/dev/null; then
        print_success "镜像已删除"
    fi
    
    print_success "清理完成"
}

run_full_test() {
    echo -e "${CYAN}"
    cat << "EOF"
╔══════════════════════════════════════════════════════╗
║     Railway 本地部署测试 - 完整流程                 ║
╚══════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    
    build_image
    start_container
    test_healthcheck
    
    echo -e "${GREEN}"
    cat << EOF

╔══════════════════════════════════════════════════════╗
║                  测试完成！                          ║
╚══════════════════════════════════════════════════════╝

下一步:
  • 在浏览器中访问: http://localhost:$PORT
  • 查看实时日志: ./scripts/test-local.sh follow
  • 停止容器: ./scripts/test-local.sh stop
  • 清理资源: ./scripts/test-local.sh clean

EOF
    echo -e "${NC}"
}

# 主逻辑
check_docker

ACTION=${1:-full}

case "$ACTION" in
    build)
        build_image
        ;;
    start)
        start_container
        ;;
    stop)
        stop_container
        ;;
    logs)
        show_logs
        ;;
    follow)
        follow_logs
        ;;
    test)
        test_healthcheck
        ;;
    clean)
        clean_all
        ;;
    full)
        run_full_test
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        echo "未知操作: $ACTION"
        echo ""
        show_help
        exit 1
        ;;
esac
