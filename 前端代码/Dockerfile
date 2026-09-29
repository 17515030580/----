FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    STREAMLIT_SERVER_HEADLESS=true \
    TZ=Asia/Shanghai

# 系统依赖：
#   fonts-noto-cjk —— 报告导出的 PDF/图片里中文渲染（缺了会显示成方块/豆腐块）
#   libnss3 等     —— kaleido 内置 chromium 运行所需（缺了 PDF 导出会失败）
RUN apt-get update && apt-get install -y --no-install-recommends \
        fonts-noto-cjk \
        tzdata \
        libnss3 libatk1.0-0 libatk-bridge2.0-0 libcups2 libdrm2 \
        libxkbcommon0 libxcomposite1 libxdamage1 libxfixes3 libxrandr2 \
        libgbm1 libasound2 libpango-1.0-0 libcairo2 libx11-6 libxcb1 libxext6 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 8501

HEALTHCHECK --interval=30s --timeout=5s --start-period=45s --retries=3 \
    CMD python -c "import urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:8501/healthz', timeout=4).status==200 else 1)"

CMD ["streamlit", "run", "streamlit_app.py", "--server.address=0.0.0.0", "--server.port=8501"]
