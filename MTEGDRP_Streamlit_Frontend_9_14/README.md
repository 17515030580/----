# OncoFusion Streamlit 前端

基于 **Streamlit + Plotly** 的多组学肿瘤预测系统前端，对接现有 FastAPI 聚合服务：

- `POST /predict`
- `GET /health`
- `GET /models/status`
- `GET /results/{prediction_id}/download/{filename}`
- `GET /drugs/{drug_id}/structure`

前端以绿色为统一视觉主题，支持真实预测和演示模式。

## 主要页面

1. **首页**：系统状态、双模型就绪情况和分析流程。
2. **新建分析**：上传一个包含三种组学 CSV 的 ZIP，校验通过后一次提交到 `/predict`。
3. **结果中心**：
   - 联合结果概览
   - 亚型概率、Top 1/Top 2、概率差和预测熵
   - Top 10 候选药物
   - 全部药物散点图、筛选和表格
   - 231种候选药物全量三维知识图谱、模型证据与二维结构图
   - 三组学质量控制
   - 模型版本、任务追溯和结果下载
4. **历史记录**：本地保存预测快照，可重新加载或删除。
5. **模型状态**：查看后端、药敏模型和亚型模型状态。
6. **使用说明**：数据格式与结果解释。

## 项目结构

```text
MTEGDRP_Streamlit_Frontend/
├── streamlit_app.py
├── run_frontend.py
├── app/
│   ├── api_client.py
│   ├── charts.py
│   ├── components.py
│   ├── config.py
│   ├── demo_data.py
│   ├── history_store.py
│   ├── state.py
│   ├── styles.py
│   ├── utils.py
│   └── pages/
│       ├── home.py
│       ├── analysis.py
│       ├── results.py
│       ├── history.py
│       ├── models.py
│       └── help.py
├── .streamlit/config.toml
├── sample_data/
├── frontend_data/history/
├── tests/
├── requirements.txt
├── Dockerfile
└── docker-compose.yml
```

## 本地运行

### 1. 启动 FastAPI 后端

在后端项目中运行：

```bash
python run.py
```

默认地址为：

```text
http://127.0.0.1:8000
```

### 2. 安装前端依赖

```bash
pip install -r requirements.txt
```

### 3. 配置环境变量

```bash
cp .env.example .env
```

主要配置：

```env
BACKEND_URL=http://127.0.0.1:8000
REQUEST_TIMEOUT_SECONDS=600
FRONTEND_MAX_UPLOAD_MB=25
DEMO_MODE_ENABLED=true
```

### 4. 启动 Streamlit

```bash
streamlit run streamlit_app.py
```

或者：

```bash
python run_frontend.py
```

浏览器打开：

```text
http://127.0.0.1:8501
```

## Docker 运行

FastAPI 后端在宿主机 8000 端口运行时：

```bash
docker compose up --build
```

## 三组学ZIP上传

ZIP根目录或同一个一级文件夹内必须且只能包含以下三个文件，文件名按规则精确识别：

```text
expression.csv
mutation.csv
methylation.csv
```

前端在提交预测前检查压缩包结构、文件名、CSV可读性、基本数值格式、突变0/1编码、甲基化取值范围和患者编号一致性。校验通过后，仍按后端要求拆分为以下 multipart 字段：

前端严格使用后端要求的 multipart 字段：

```text
patient_id
cancer_type
expression_file
mutation_file
methylation_file
```

三种CSV均支持：

- 宽表：首列样本编号，其余列为特征
- 两列长表：`feature,value`

`cancer_type` 必须为 `BRCA`、`ESCA`、`KIDNEY`、`LUNG` 或 `UCEC`。
前端会要求用户选择癌种，并将其随三种组学文件一并提交。

## 演示模式

当亚型模型尚未接入或后端未启动时，可以点击“使用演示数据”预览完整页面。页面右上角会出现 `DEMO DATA` 标识，避免与真实预测混淆。

关闭演示模式：

```env
DEMO_MODE_ENABLED=false
```

## 设计说明

- `.streamlit/config.toml` 设置统一绿色主题。
- 自定义 CSS 提供渐变英雄区、玻璃卡片、状态标签和轻量动画。
- Plotly 提供亚型概率图、置信度仪表、Top 10 IC50 图、全部药物散点图、可靠性环图和质量控制图。
- `st.session_state` 保存当前结果和页面状态。
- `frontend_data/history` 保存前端历史任务快照，不保存用户上传的原始三组学文件。
- 药物靶点、通路使用GDSC release 8.5数据；作用机制与已收录获批适应证使用ChEMBL数据。
- 只有同时记录来源和授权信息的上市药包装图才会显示；研究化合物统一显示中性药物示意图。

## 使用边界

当前页面中的药物排序依据模型预测 IC50。该结果适合科研与临床研究辅助展示，不应单独作为临床处方依据。
