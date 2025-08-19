# Streamlit 대시보드 설계 문서

## 1. 개요

메타게놈 파이프라인 벤치마크 결과를 시각화하고 관리하는 웹 기반 대시보드

## 2. 기술 스택

- **Frontend**: Streamlit 1.30+
- **Backend**: FastAPI (API 서버)
- **Database**: SQLite (로컬) / PostgreSQL (프로덕션)
- **Visualization**: Plotly, Altair, Matplotlib
- **Deployment**: Docker + Nginx

## 3. 디렉토리 구조

```
dashboard/
├── app.py                    # 메인 애플리케이션
├── pages/                    # 멀티페이지 앱
│   ├── 1_🏃_Run_Benchmark.py
│   ├── 2_📊_Compare.py
│   ├── 3_🌍_Community.py
│   ├── 4_📈_Analytics.py
│   └── 5_⚙️_Settings.py
├── components/               # 재사용 컴포넌트
│   ├── __init__.py
│   ├── metrics_card.py
│   ├── pipeline_selector.py
│   ├── result_viewer.py
│   └── comparison_chart.py
├── utils/                    # 유틸리티 함수
│   ├── __init__.py
│   ├── data_loader.py
│   ├── chart_builder.py
│   └── api_client.py
├── static/                   # 정적 파일
│   ├── css/
│   └── images/
├── config/                   # 설정 파일
│   ├── dashboard.yaml
│   └── themes.py
└── requirements.txt          # 의존성

```

## 4. 페이지별 설계

### 4.1 홈페이지 (app.py)

```python
# dashboard/app.py
import streamlit as st
import pandas as pd
from utils.data_loader import load_benchmark_summary
from components.metrics_card import MetricsCard

st.set_page_config(
    page_title="Metagenome Pipeline Benchmark",
    page_icon="🧬",
    layout="wide",
    initial_sidebar_state="expanded"
)

def main():
    st.title("🧬 Metagenome Pipeline Benchmark Dashboard")
    
    # 사이드바
    with st.sidebar:
        st.image("static/images/logo.png", width=200)
        st.markdown("---")
        
        # 프로젝트 선택
        projects = load_available_projects()
        selected_project = st.selectbox(
            "Select Project",
            projects,
            index=0
        )
        
        # 필터 옵션
        st.subheader("Filters")
        date_range = st.date_input(
            "Date Range",
            value=(datetime.now() - timedelta(days=30), datetime.now())
        )
        
    # 메인 대시보드
    col1, col2, col3, col4 = st.columns(4)
    
    with col1:
        MetricsCard(
            title="Total Benchmarks",
            value="127",
            delta="+12 this week",
            color="blue"
        )
    
    with col2:
        MetricsCard(
            title="Active Projects",
            value="8",
            delta="+2 new",
            color="green"
        )
    
    with col3:
        MetricsCard(
            title="Best Pipeline",
            value="nf-core/mag",
            subtitle="93% accuracy",
            color="purple"
        )
    
    with col4:
        MetricsCard(
            title="Avg Runtime",
            value="18.5h",
            delta="-2.3h improved",
            color="orange"
        )
    
    # 최근 벤치마크 결과
    st.subheader("📊 Recent Benchmark Results")
    
    recent_results = load_recent_results(selected_project)
    
    # 인터랙티브 차트
    fig = create_performance_chart(recent_results)
    st.plotly_chart(fig, use_container_width=True)
    
    # 상세 테이블
    with st.expander("View Detailed Results"):
        st.dataframe(
            recent_results,
            use_container_width=True,
            hide_index=True
        )

if __name__ == "__main__":
    main()
```

### 4.2 벤치마크 실행 페이지

```python
# dashboard/pages/1_🏃_Run_Benchmark.py
import streamlit as st
from utils.api_client import BenchmarkAPI
from components.pipeline_selector import PipelineSelector

st.title("🏃 Run New Benchmark")

# Step 1: 데이터 입력
st.header("1. Select Input Data")

data_source = st.radio(
    "Data Source",
    ["Upload Files", "Use Test Dataset", "From URL"]
)

if data_source == "Upload Files":
    uploaded_files = st.file_uploader(
        "Choose FASTQ files",
        type=['fastq', 'fq', 'gz'],
        accept_multiple_files=True
    )
    
    if uploaded_files:
        st.success(f"✅ {len(uploaded_files)} files uploaded")

elif data_source == "Use Test Dataset":
    test_datasets = ["CAMI2", "MetaSUB Sample", "Mock Community"]
    selected_dataset = st.selectbox("Select Dataset", test_datasets)

# Step 2: 파이프라인 선택
st.header("2. Select Pipelines")

pipelines = PipelineSelector()
selected_pipelines = pipelines.render()

# Step 3: 파라미터 설정
st.header("3. Configure Parameters")

with st.expander("Advanced Settings", expanded=False):
    col1, col2 = st.columns(2)
    
    with col1:
        min_contig_size = st.number_input(
            "Min Contig Size",
            min_value=500,
            max_value=10000,
            value=1500,
            step=500
        )
        
        max_memory = st.slider(
            "Max Memory (GB)",
            min_value=8,
            max_value=500,
            value=100,
            step=8
        )
    
    with col2:
        num_threads = st.number_input(
            "Number of Threads",
            min_value=1,
            max_value=64,
            value=16
        )
        
        assemblers = st.multiselect(
            "Assemblers",
            ["MEGAHIT", "SPAdes", "metaSPAdes"],
            default=["MEGAHIT"]
        )

# Step 4: 실행
st.header("4. Run Benchmark")

col1, col2, col3 = st.columns([1, 1, 2])

with col1:
    run_button = st.button(
        "🚀 Start Benchmark",
        type="primary",
        use_container_width=True
    )

with col2:
    dry_run = st.button(
        "🔍 Dry Run",
        use_container_width=True
    )

if run_button:
    with st.spinner("Starting benchmark..."):
        api = BenchmarkAPI()
        run_id = api.start_benchmark(
            data=uploaded_files or selected_dataset,
            pipelines=selected_pipelines,
            params={
                'min_contig_size': min_contig_size,
                'max_memory': max_memory,
                'threads': num_threads,
                'assemblers': assemblers
            }
        )
    
    st.success(f"✅ Benchmark started! Run ID: {run_id}")
    
    # 실시간 진행 상황 표시
    progress_placeholder = st.empty()
    status_placeholder = st.empty()
    
    while True:
        status = api.get_status(run_id)
        
        progress_placeholder.progress(
            status['progress'],
            text=f"Progress: {status['progress']}%"
        )
        
        status_placeholder.info(
            f"Current step: {status['current_step']}"
        )
        
        if status['completed']:
            break
        
        time.sleep(5)
    
    st.balloons()
    st.success("🎉 Benchmark completed!")
    
    # 결과 요약 표시
    results = api.get_results(run_id)
    st.subheader("Results Summary")
    st.json(results['summary'])
```

### 4.3 비교 분석 페이지

```python
# dashboard/pages/2_📊_Compare.py
import streamlit as st
import plotly.graph_objects as go
from utils.chart_builder import create_comparison_charts

st.title("📊 Pipeline Comparison")

# 비교할 벤치마크 선택
st.header("Select Benchmarks to Compare")

col1, col2 = st.columns(2)

with col1:
    run_a = st.selectbox(
        "Benchmark A",
        get_available_runs(),
        format_func=lambda x: f"{x['date']} - {x['pipeline']}"
    )

with col2:
    run_b = st.selectbox(
        "Benchmark B",
        get_available_runs(),
        format_func=lambda x: f"{x['date']} - {x['pipeline']}"
    )

# 비교 메트릭 선택
metrics_to_compare = st.multiselect(
    "Select Metrics",
    ["Completeness", "Contamination", "N50", "Runtime", "Memory", "F1-Score"],
    default=["Completeness", "Runtime", "F1-Score"]
)

if st.button("Compare", type="primary"):
    # 데이터 로드
    data_a = load_benchmark_data(run_a)
    data_b = load_benchmark_data(run_b)
    
    # 비교 차트 생성
    st.subheader("📈 Comparison Results")
    
    # 레이더 차트
    fig_radar = create_radar_chart(data_a, data_b, metrics_to_compare)
    st.plotly_chart(fig_radar, use_container_width=True)
    
    # 상세 비교 테이블
    comparison_df = create_comparison_table(data_a, data_b)
    
    st.subheader("📋 Detailed Comparison")
    st.dataframe(
        comparison_df.style.highlight_max(axis=0, color='lightgreen'),
        use_container_width=True
    )
    
    # 승자 판정
    winner = determine_winner(data_a, data_b, metrics_to_compare)
    
    if winner:
        st.success(f"🏆 **{winner['name']}** performs better overall!")
        st.metric(
            "Performance Advantage",
            f"{winner['advantage']:.1%}",
            delta=f"+{winner['delta']:.1f} points"
        )
```

### 4.4 커뮤니티 페이지

```python
# dashboard/pages/3_🌍_Community.py
import streamlit as st
import pandas as pd
from utils.api_client import CommunityAPI

st.title("🌍 Community Benchmarks")

# 리더보드
st.header("🏆 Leaderboard")

category = st.selectbox(
    "Category",
    ["Overall", "AMR Detection", "Taxonomic Classification", "Assembly Quality"]
)

timeframe = st.radio(
    "Timeframe",
    ["All Time", "This Month", "This Week"],
    horizontal=True
)

# 리더보드 표시
leaderboard = load_leaderboard(category, timeframe)

for idx, entry in enumerate(leaderboard[:10]):
    col1, col2, col3, col4 = st.columns([1, 3, 2, 2])
    
    with col1:
        if idx < 3:
            st.markdown(f"### {['🥇', '🥈', '🥉'][idx]}")
        else:
            st.markdown(f"### #{idx+1}")
    
    with col2:
        st.markdown(f"**{entry['project_name']}**")
        st.caption(f"by {entry['team']}")
    
    with col3:
        st.metric("Score", f"{entry['score']:.2f}")
    
    with col4:
        st.button(
            "View Details",
            key=f"view_{entry['id']}",
            use_container_width=True
        )

# 커뮤니티 통계
st.header("📊 Community Statistics")

col1, col2, col3 = st.columns(3)

with col1:
    st.metric("Total Benchmarks", "1,247")
    st.metric("Active Projects", "89")

with col2:
    st.metric("Avg Completeness", "87.3%")
    st.metric("Avg Runtime", "22.4h")

with col3:
    st.metric("Best F1-Score", "0.94")
    st.metric("Data Processed", "127 TB")

# 트렌드 차트
st.header("📈 Trends")

trend_metric = st.selectbox(
    "Select Metric",
    ["Performance", "Usage", "Accuracy"]
)

fig_trend = create_trend_chart(trend_metric)
st.plotly_chart(fig_trend, use_container_width=True)
```

### 4.5 설정 페이지

```python
# dashboard/pages/5_⚙️_Settings.py
import streamlit as st
from utils.config_manager import ConfigManager

st.title("⚙️ Settings")

tabs = st.tabs(["General", "Database", "API", "Appearance"])

with tabs[0]:  # General
    st.header("General Settings")
    
    project_name = st.text_input(
        "Project Name",
        value=st.session_state.get('project_name', '')
    )
    
    auto_upload = st.checkbox(
        "Auto-upload results to community",
        value=False
    )
    
    notification_email = st.text_input(
        "Notification Email",
        placeholder="user@example.com"
    )

with tabs[1]:  # Database
    st.header("Database Configuration")
    
    st.info("🔗 Current DB Root: `/data/shared/metagenome-db`")
    
    # DB 상태 체크
    db_status = check_database_status()
    
    for db_name, status in db_status.items():
        col1, col2, col3 = st.columns([2, 1, 1])
        
        with col1:
            st.text(db_name)
        
        with col2:
            if status['available']:
                st.success("✅ Available")
            else:
                st.error("❌ Missing")
        
        with col3:
            st.caption(status['size'])
    
    if st.button("Setup Database Links"):
        setup_database_links()
        st.rerun()

with tabs[2]:  # API
    st.header("API Configuration")
    
    api_url = st.text_input(
        "Central Hub URL",
        value="http://localhost:8000"
    )
    
    api_key = st.text_input(
        "API Key",
        type="password",
        value=st.session_state.get('api_key', '')
    )
    
    if st.button("Test Connection"):
        if test_api_connection(api_url, api_key):
            st.success("✅ Connection successful!")
        else:
            st.error("❌ Connection failed")

with tabs[3]:  # Appearance
    st.header("Appearance")
    
    theme = st.selectbox(
        "Theme",
        ["Light", "Dark", "Auto"]
    )
    
    chart_style = st.selectbox(
        "Chart Style",
        ["Plotly", "Altair", "Matplotlib"]
    )
    
    show_tooltips = st.checkbox(
        "Show tooltips",
        value=True
    )

# 저장 버튼
if st.button("💾 Save Settings", type="primary"):
    save_settings({
        'project_name': project_name,
        'auto_upload': auto_upload,
        'notification_email': notification_email,
        'api_url': api_url,
        'api_key': api_key,
        'theme': theme,
        'chart_style': chart_style,
        'show_tooltips': show_tooltips
    })
    st.success("✅ Settings saved successfully!")
```

## 5. 컴포넌트 라이브러리

### 5.1 메트릭 카드 컴포넌트

```python
# dashboard/components/metrics_card.py
import streamlit as st

def MetricsCard(title, value, delta=None, subtitle=None, color="blue"):
    """재사용 가능한 메트릭 카드 컴포넌트"""
    
    colors = {
        "blue": "#1f77b4",
        "green": "#2ca02c",
        "orange": "#ff7f0e",
        "purple": "#9467bd"
    }
    
    with st.container():
        st.markdown(
            f"""
            <div style="
                background: linear-gradient(135deg, {colors[color]}22 0%, {colors[color]}11 100%);
                border-left: 4px solid {colors[color]};
                padding: 1rem;
                border-radius: 0.5rem;
                margin: 0.5rem 0;
            ">
                <div style="color: #666; font-size: 0.9rem;">{title}</div>
                <div style="font-size: 1.8rem; font-weight: bold; color: {colors[color]};">
                    {value}
                </div>
                {f'<div style="color: #666; font-size: 0.8rem;">{subtitle}</div>' if subtitle else ''}
                {f'<div style="color: {"green" if "+" in str(delta) else "red"}; font-size: 0.9rem;">{delta}</div>' if delta else ''}
            </div>
            """,
            unsafe_allow_html=True
        )
```

## 6. 배포 구성

### 6.1 Docker 설정

```dockerfile
# dashboard/Dockerfile
FROM python:3.11-slim

WORKDIR /app

# 의존성 설치
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 앱 복사
COPY . .

# Streamlit 포트
EXPOSE 8501

# 헬스체크
HEALTHCHECK CMD curl --fail http://localhost:8501/_stcore/health

# 실행
CMD ["streamlit", "run", "app.py", \
     "--server.port=8501", \
     "--server.address=0.0.0.0", \
     "--server.headless=true"]
```

### 6.2 docker-compose.yml

```yaml
# docker-compose.yml
version: '3.8'

services:
  dashboard:
    build: ./dashboard
    ports:
      - "8501:8501"
    environment:
      - METAGENOME_DB_ROOT=/data/shared/metagenome-db
      - API_URL=http://api:8000
    volumes:
      - ./dashboard:/app
      - /data/shared/metagenome-db:/data/shared/metagenome-db:ro
      - ./results:/results
    depends_on:
      - api
      - postgres
    
  api:
    build: ./api
    ports:
      - "8000:8000"
    environment:
      - DATABASE_URL=postgresql://user:pass@postgres:5432/benchmark
    
  postgres:
    image: postgres:15
    environment:
      - POSTGRES_USER=user
      - POSTGRES_PASSWORD=pass
      - POSTGRES_DB=benchmark
    volumes:
      - postgres_data:/var/lib/postgresql/data

  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
      - ./ssl:/etc/nginx/ssl:ro
    depends_on:
      - dashboard

volumes:
  postgres_data:
```

## 7. 보안 설정

### 7.1 인증 시스템

```python
# dashboard/utils/auth.py
import streamlit as st
import streamlit_authenticator as stauth

def setup_authentication():
    """Streamlit 인증 설정"""
    
    # 사용자 정보 (실제로는 DB에서 로드)
    credentials = {
        "usernames": {
            "admin": {
                "name": "Administrator",
                "password": hash_password("admin123"),
                "email": "admin@example.com"
            },
            "user": {
                "name": "User",
                "password": hash_password("user123"),
                "email": "user@example.com"
            }
        }
    }
    
    authenticator = stauth.Authenticate(
        credentials,
        "benchmark_dashboard",
        "auth_key_123",
        cookie_expiry_days=30
    )
    
    return authenticator

# 앱 시작 시 인증
authenticator = setup_authentication()
name, authentication_status, username = authenticator.login()

if authentication_status:
    st.write(f'Welcome *{name}*')
    # 메인 앱 로직
elif authentication_status == False:
    st.error('Username/password is incorrect')
elif authentication_status == None:
    st.warning('Please enter your username and password')
```

## 8. 모니터링 및 로깅

```python
# dashboard/utils/monitoring.py
import logging
from datetime import datetime

# 로깅 설정
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('logs/dashboard.log'),
        logging.StreamHandler()
    ]
)

def log_user_action(username, action, details=None):
    """사용자 액션 로깅"""
    logger = logging.getLogger('user_actions')
    logger.info(f"User: {username}, Action: {action}, Details: {details}")

def track_performance(func):
    """성능 모니터링 데코레이터"""
    def wrapper(*args, **kwargs):
        start = datetime.now()
        result = func(*args, **kwargs)
        duration = (datetime.now() - start).total_seconds()
        
        if duration > 1:  # 1초 이상 걸리면 경고
            logging.warning(f"{func.__name__} took {duration:.2f}s")
        
        return result
    return wrapper
```

## 9. 성능 최적화

### 9.1 캐싱 전략

```python
# dashboard/utils/cache.py
import streamlit as st
from functools import lru_cache

@st.cache_data(ttl=600)  # 10분 캐시
def load_benchmark_data(run_id):
    """벤치마크 데이터 캐싱"""
    return fetch_from_database(run_id)

@st.cache_resource  # 세션 동안 유지
def get_database_connection():
    """DB 연결 캐싱"""
    return create_connection()

@lru_cache(maxsize=128)
def calculate_metrics(data_hash):
    """계산 결과 캐싱"""
    return expensive_calculation(data_hash)
```

## 10. 테스트 및 CI/CD

```yaml
# .github/workflows/dashboard.yml
name: Dashboard CI/CD

on:
  push:
    paths:
      - 'dashboard/**'

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Set up Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.11'
      
      - name: Install dependencies
        run: |
          cd dashboard
          pip install -r requirements.txt
          pip install pytest streamlit-testing
      
      - name: Run tests
        run: |
          cd dashboard
          pytest tests/
      
      - name: Build Docker image
        run: |
          docker build -t metagenome-benchmark-dashboard ./dashboard
      
      - name: Deploy to server
        if: github.ref == 'refs/heads/main'
        run: |
          docker push registry.example.com/metagenome-benchmark-dashboard:latest
```

이 설계로 안전하고 확장 가능한 Streamlit 대시보드를 구축할 수 있습니다.