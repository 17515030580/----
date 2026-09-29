#!/usr/bin/env bash
# ============================================================
# OncoFusion 前端 一键部署脚本（Linux 服务器）
#
# 用法：
#   cd oncofusion-frontend
#   BACKEND_URL=http://你的后端地址:8000 ./deploy.sh
#
# 或者先编辑同目录的 .env 文件写好 BACKEND_URL，再直接 ./deploy.sh
# ============================================================
set -euo pipefail

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$APP_DIR"
PORT="${FRONTEND_PORT:-8501}"

echo "=========================================="
echo " OncoFusion 前端部署"
echo " 目录: $APP_DIR"
echo " 端口: $PORT"
echo "=========================================="

# ---------- 1. 生成 .env ----------
if [ ! -f .env ]; then
    cat > .env <<EOF
BACKEND_URL=${BACKEND_URL:-http://127.0.0.1:8000}
REQUEST_TIMEOUT_SECONDS=600
FRONTEND_MAX_UPLOAD_MB=25
DEMO_MODE_ENABLED=true
FRONTEND_PORT=${PORT}
EOF
    echo "==> 已生成 .env"
else
    if [ -n "${BACKEND_URL:-}" ]; then
        # 命令行传了 BACKEND_URL，覆盖进 .env（保留其他行）
        if grep -q '^BACKEND_URL=' .env; then
            sed -i "s|^BACKEND_URL=.*|BACKEND_URL=${BACKEND_URL}|" .env
        else
            echo "BACKEND_URL=${BACKEND_URL}" >> .env
        fi
        echo "==> 已用命令行参数更新 .env 中的 BACKEND_URL"
    fi
    echo "==> 检测到已有 .env，沿用（如需改后端地址请编辑它）"
fi

echo "==> 当前后端地址: $(grep '^BACKEND_URL=' .env | cut -d= -f2-)"

# ---------- 2. 选择部署方式 ----------
if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
    echo ""
    echo "==> 检测到 Docker，使用容器方式部署"
    # 容器内的 127.0.0.1 指向容器自己，不是宿主机。同机后端必须换成 host.docker.internal，
    # 否则现象是"页面能正常打开、但一点预测就失败"，很容易误判成后端挂了。
    CUR_BACKEND="$(sed -n 's|^BACKEND_URL=||p' .env | head -1)"
    case "$CUR_BACKEND" in
        *127.0.0.1*|*localhost*|*0.0.0.0*)
            NEW_BACKEND="$(printf '%s' "$CUR_BACKEND" | sed -E 's#(127\.0\.0\.1|localhost|0\.0\.0\.0)#host.docker.internal#')"
            sed -i "s|^BACKEND_URL=.*|BACKEND_URL=${NEW_BACKEND}|" .env
            echo "==> 容器内访问不到宿主机的 127.0.0.1，已自动改写后端地址为: ${NEW_BACKEND}"
            ;;
    esac
    docker compose up -d --build
    echo ""
    echo "==> 等待容器启动..."
    sleep 8
    if curl -fsS -m 10 "http://127.0.0.1:${PORT}/healthz" >/dev/null 2>&1; then
        echo "==> 容器健康检查通过"
    else
        echo "==> !! 健康检查未通过，查看日志： docker compose logs -f --tail=80"
    fi
else
    echo ""
    echo "==> 未检测到 Docker，改用 Python 虚拟环境方式部署"
    # 反向处理：宿主机上解析不了 host.docker.internal，换回 127.0.0.1
    CUR_BACKEND="$(sed -n 's|^BACKEND_URL=||p' .env | head -1)"
    case "$CUR_BACKEND" in
        *host.docker.internal*)
            NEW_BACKEND="$(printf '%s' "$CUR_BACKEND" | sed 's|host.docker.internal|127.0.0.1|')"
            sed -i "s|^BACKEND_URL=.*|BACKEND_URL=${NEW_BACKEND}|" .env
            echo "==> 虚拟环境方式解析不了 host.docker.internal，已自动改写后端地址为: ${NEW_BACKEND}"
            ;;
    esac

    if command -v apt-get >/dev/null 2>&1; then
        echo "==> 安装系统依赖（中文字体 / python venv）"
        sudo apt-get update -qq
        sudo apt-get install -y -qq python3-venv python3-pip fonts-noto-cjk
    else
        echo "==> 非 apt 系统，请自行确认已安装中文字体（否则报告 PDF 中文会变方块）"
    fi

    echo "==> 创建虚拟环境并安装依赖（首次约 3-5 分钟）"
    python3 -m venv .venv
    ./.venv/bin/pip install -q -U pip
    ./.venv/bin/pip install -q -r requirements.txt

    echo "==> 生成 systemd 服务文件（供开机自启 / 崩溃自动重启）"
    cat > oncofusion-frontend.service <<EOF
[Unit]
Description=OncoFusion Streamlit Frontend
After=network.target

[Service]
Type=simple
WorkingDirectory=${APP_DIR}
EnvironmentFile=${APP_DIR}/.env
ExecStart=${APP_DIR}/.venv/bin/streamlit run streamlit_app.py --server.address=0.0.0.0 --server.port=${PORT}
Restart=always
RestartSec=5
User=$(whoami)

[Install]
WantedBy=multi-user.target
EOF

    echo "==> 先以 nohup 方式启动，确认可用"
    pkill -f "streamlit run streamlit_app.py" 2>/dev/null || true
    nohup ./.venv/bin/streamlit run streamlit_app.py \
        --server.address=0.0.0.0 --server.port="$PORT" > run.log 2>&1 &
    sleep 10

    echo ""
    echo "--------------------------------------------------"
    echo "已用 nohup 临时启动，日志：$APP_DIR/run.log"
    echo "如需【开机自启 + 崩溃自动重启】，执行以下两条："
    echo "  sudo cp oncofusion-frontend.service /etc/systemd/system/"
    echo "  sudo systemctl daemon-reload && sudo systemctl enable --now oncofusion-frontend"
    echo "--------------------------------------------------"
fi

# ---------- 3. 打印访问地址 ----------
PUBLIC_IP="$(curl -fsS -m 8 https://api.ipify.org 2>/dev/null || hostname -I 2>/dev/null | awk '{print $1}' || echo '<你的公网IP>')"

echo ""
echo "=========================================="
echo " 部署完成，访问地址："
echo "   http://${PUBLIC_IP}:${PORT}"
echo "   本机验证: curl http://127.0.0.1:${PORT}/healthz"
echo "=========================================="
echo ""
echo "!! 如果浏览器打不开，按顺序排查："
echo "   1) 云控制台【安全组 / 防火墙】是否放行了 ${PORT} 端口（最常见原因）"
echo "   2) 服务器本机防火墙: sudo ufw allow ${PORT}/tcp"
echo "   3) 服务是否在跑: ss -lntp | grep ${PORT}"
echo "   4) 后端地址是否正确: cat .env | grep BACKEND_URL"
echo ""
echo "注意：如果本页面是 http:// 打开，后端用 http:// 即可（不会有跨协议拦截）；"
echo "      如果配了 HTTPS 域名，后端也必须 HTTPS，否则浏览器会拦截请求。"
