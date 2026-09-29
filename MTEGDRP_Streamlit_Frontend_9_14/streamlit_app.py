# -*- coding: utf-8 -*-
from __future__ import annotations

import streamlit as st

from app.api_client import APIClientError, BackendClient
from app.components import sidebar_brand, status_pill
from app.config import get_settings
from app.flow_status_bar import render_flow_bar
from app.history_store import HistoryStore
from app.pages import analysis, help as help_page, history, home, models, results
from app.state import initialize_state
from app.styles import apply_global_styles




settings = get_settings()
st.set_page_config(
    page_title=settings.app_title,
    page_icon="️🧬",
    layout="wide",
    initial_sidebar_state="expanded",
    menu_items={
        "Get help": None,
        "Report a bug": None,
        "About": "OncoFusion 智能肿瘤诊疗系统",
    },
)
apply_global_styles()
initialize_state()

client = BackendClient(settings.backend_url, settings.request_timeout_seconds)
history_store = HistoryStore(settings.history_root)

sidebar_brand(settings.app_title)
PAGES = ["首页", "新建分析", "结果中心", "历史记录", "模型状态", "使用说明"]
# 页面内部跳转（卡片按钮 -> state.navigate）会在 _nav_request 里留下目标页，
# 只有这种情况才覆盖 radio 的选择。若像以前那样用 index= 驱动 radio，
# 每次 rerun 都会把用户刚点的值覆盖掉，表现为「要点两次才切换」。
if st.session_state.active_page not in PAGES:
    st.session_state.active_page = PAGES[0]
_requested = st.session_state.pop("_nav_request", None)
if _requested in PAGES:
    st.session_state["__nav_radio"] = _requested
selected_page = st.sidebar.radio(
    "导航",
    PAGES,
    key="__nav_radio",
    label_visibility="collapsed",
)
st.session_state.active_page = selected_page

st.sidebar.markdown("---")
try:
    health = client.health()
    st.session_state.backend_health = health
    if health.get("status") == "ready":
        st.sidebar.markdown(status_pill("后端服务在线", "ok"), unsafe_allow_html=True)
    else:
        st.sidebar.markdown(status_pill("后端部分就绪", "warn"), unsafe_allow_html=True)
except APIClientError:
    health = st.session_state.get("backend_health")
    st.sidebar.markdown(status_pill("后端未连接", "bad"), unsafe_allow_html=True)

# 顶部全局 AI 流程状态悬浮条（默认细长条，悬停展开流程图；点击节点跳转）
render_flow_bar(health)

#st.sidebar.caption(f"API · {settings.backend_url}")

st.sidebar.markdown("---")
st.sidebar.markdown(
    #"<div style='font-size:.72rem;line-height:1.65;opacity:.76;'>科研和临床研究辅助界面<br/>预测结果不直接构成处方建议</div>",
    "<div style='font-size:.72rem;line-height:1.65;opacity:.76;'>科研和临床研究辅助界面<br/><br/>联系我们：1XXXXXXXXXX</div>",
    unsafe_allow_html=True,
)

page = st.session_state.active_page
if page == "首页":
    home.render(health)
elif page == "新建分析":
    analysis.render(client, history_store, settings.max_upload_size_mb)
elif page == "结果中心":
    results.render(client, settings.demo_mode_enabled)
elif page == "历史记录":
    history.render(history_store)
elif page == "模型状态":
    models.render(client, settings.backend_url, health)
elif page == "使用说明":
    help_page.render()


