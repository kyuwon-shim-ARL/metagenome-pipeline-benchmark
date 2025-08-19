# resistance-tracker 프로젝트 마이그레이션 계획

## 1. 현재 상태 분석 (As-Is)

### 현재 구조
```
resistance-tracker/
├── pipelines/           # 파이프라인 정의
├── shared/
│   ├── databases/       # 🔴 DB가 프로젝트 내부에 위치
│   └── containers/      # 컨테이너 이미지
├── nextflow.config      # DB 경로 하드코딩
└── results/             # 결과 파일
```

### 문제점
- DB가 프로젝트 내부에 있어 용량 문제
- 다른 프로젝트와 DB 공유 불가
- 벤치마크 도구 부재
- 체계적인 결과 관리 부족

## 2. 목표 상태 (To-Be)

### 개선된 구조
```
resistance-tracker/
├── .benchmark/          # ✅ 벤치마크 통합
│   ├── config.yaml      # 벤치마크 설정
│   ├── cache/           # 로컬 캐시
│   └── results/         # 벤치마크 결과
├── pipelines/           # 기존 파이프라인
├── nextflow.config      # ✅ 환경변수 기반 DB 경로
└── results/             # 파이프라인 실행 결과

/data/shared/metagenome-db/  # ✅ 공용 DB (외부)
├── busco/
├── gtdbtk/
└── kraken2/
```

## 3. 마이그레이션 단계별 계획

### Phase 1: DB 이전 (Week 1)

#### Step 1.1: 공용 DB 디렉토리 생성
```bash
#!/bin/bash
# scripts/migrate_db_phase1.sh

# 1. 공용 디렉토리 생성
sudo mkdir -p /data/shared/metagenome-db
sudo chown -R $(whoami):$(id -gn) /data/shared/metagenome-db

# 2. 기존 DB 이동
echo "Moving databases to shared location..."
mv ~/resistance-tracker/shared/databases/* /data/shared/metagenome-db/

# 3. 심볼릭 링크 생성 (하위 호환성)
ln -s /data/shared/metagenome-db ~/resistance-tracker/shared/databases

echo "✅ Database migration completed"
```

#### Step 1.2: 환경 변수 설정
```bash
# ~/.bashrc 추가
export METAGENOME_DB_ROOT="/data/shared/metagenome-db"
export BUSCO_DB="${METAGENOME_DB_ROOT}/busco/v5"
export GTDBTK_DB="${METAGENOME_DB_ROOT}/gtdbtk/r220"
export KRAKEN2_DB="${METAGENOME_DB_ROOT}/kraken2/standard_20240601"
export CHECKM_DB="${METAGENOME_DB_ROOT}/checkm/v1.2.2"
```

#### Step 1.3: Nextflow 설정 업데이트
```groovy
// nextflow.config (수정)
params {
    // 이전 (하드코딩)
    // busco_reference_path = '/home/kyuwon/resistance-tracker/shared/databases/busco/v5'
    
    // 이후 (환경변수)
    busco_reference_path = System.getenv('BUSCO_DB') ?: '/data/shared/metagenome-db/busco/v5'
    gtdb_path = System.getenv('GTDBTK_DB') ?: '/data/shared/metagenome-db/gtdbtk/r220'
    kraken2_db = System.getenv('KRAKEN2_DB') ?: '/data/shared/metagenome-db/kraken2/standard_20240601'
    checkm_path = System.getenv('CHECKM_DB') ?: '/data/shared/metagenome-db/checkm/v1.2.2'
}
```

### Phase 2: 벤치마크 도구 통합 (Week 2)

#### Step 2.1: 벤치마크 CLI 설치
```bash
# 벤치마크 도구 설치
pip install metagenome-benchmark-cli

# 또는 개발 모드로 설치
cd ~/metagenome-pipeline-benchmark
pip install -e ./cli
```

#### Step 2.2: 프로젝트 벤치마크 설정
```yaml
# resistance-tracker/.benchmark/config.yaml
benchmark:
  # 프로젝트 정보
  project:
    name: "resistance-tracker"
    type: "amr-detection"
    description: "TARA ocean samples AMR analysis"
    
  # 중앙 Hub 연결
  central_hub:
    url: "http://localhost:8501"  # Streamlit 대시보드
    api_url: "http://localhost:8000"  # API 서버
    auto_upload: false  # 수동 업로드
    
  # 로컬 설정
  local:
    cache_dir: ".benchmark/cache"
    results_dir: ".benchmark/results"
    work_dir: "work"
    
  # 데이터베이스 설정
  databases:
    root: "/data/shared/metagenome-db"
    use_env_vars: true
    
  # 파이프라인 정의
  pipelines:
    - name: "nfcore_mag"
      version: "3.1.0"
      config: "./nextflow.config"
      profile: "singularity"
      focus: ["assembly", "binning"]
      
    - name: "nfcore_funcscan"
      version: "1.1.0"
      focus: ["amr_genes", "functional_annotation"]
      databases: ["card", "resfinder", "amrfinderplus"]
      
  # 평가 메트릭
  evaluation:
    primary_metrics:
      - amr_sensitivity
      - amr_specificity
      - assembly_quality
    secondary_metrics:
      - runtime
      - memory_usage
      - storage_footprint
    thresholds:
      min_sensitivity: 0.85
      max_runtime: "24h"
      max_memory: "150GB"
```

#### Step 2.3: 벤치마크 실행 스크립트
```bash
#!/bin/bash
# resistance-tracker/scripts/run_benchmark.sh

# 벤치마크 초기화 (첫 실행 시)
if [ ! -f ".benchmark/config.yaml" ]; then
    benchmark init \
        --project-name "resistance-tracker" \
        --project-type "amr-detection" \
        --template amr
fi

# 벤치마크 실행
benchmark run \
    --config .benchmark/config.yaml \
    --input data/sample_sheet_public.csv \
    --pipelines nfcore_mag,nfcore_funcscan \
    --output .benchmark/results/$(date +%Y%m%d_%H%M%S) \
    --compare-with baseline \
    --verbose

# 결과 요약
benchmark report \
    --latest \
    --format html \
    --output .benchmark/reports/latest.html

echo "✅ Benchmark completed. View report at .benchmark/reports/latest.html"
```

### Phase 3: 기존 스크립트 업데이트 (Week 2-3)

#### Step 3.1: 실행 스크립트 수정
```bash
#!/bin/bash
# run_nf_mag_public.sh (수정)

# 환경 변수 체크
if [ -z "$METAGENOME_DB_ROOT" ]; then
    echo "⚠️ METAGENOME_DB_ROOT not set. Using default."
    export METAGENOME_DB_ROOT="/data/shared/metagenome-db"
fi

# 벤치마크 모드 확인
if [ "$1" == "--benchmark" ]; then
    echo "🏃 Running in benchmark mode..."
    BENCHMARK_MODE=true
    BENCHMARK_ID=$(date +%Y%m%d_%H%M%S)
else
    BENCHMARK_MODE=false
fi

# Nextflow 실행
nextflow run nf-core/mag \
    -r 3.1.0 \
    -c nextflow.config \
    -profile singularity \
    --input sample_sheet_public.csv \
    --outdir results_public \
    --busco_auto_lineage_prok \
    -resume \
    -with-report \
    -with-timeline \
    -with-trace

# 벤치마크 모드일 경우 메트릭 수집
if [ "$BENCHMARK_MODE" == "true" ]; then
    benchmark collect-metrics \
        --run-id $BENCHMARK_ID \
        --nextflow-report results_public/pipeline_info/execution_report*.html \
        --nextflow-trace results_public/pipeline_info/execution_trace*.txt \
        --output .benchmark/results/$BENCHMARK_ID/metrics.json
fi
```

#### Step 3.2: CLAUDE.md 작성
```markdown
# resistance-tracker/CLAUDE.md

# resistance-tracker 프로젝트 가이드

## 프로젝트 개요
TARA 해양 메타게놈 샘플에서 항생제 내성 유전자를 검출하고 분석하는 프로젝트

## 중요 변경사항 (2024.01)
- ✅ DB를 공용 폴더로 이전 (`/data/shared/metagenome-db`)
- ✅ 벤치마크 도구 통합 (`.benchmark/`)
- ✅ 환경변수 기반 설정

## 디렉토리 구조
```
resistance-tracker/
├── .benchmark/          # 벤치마크 도구 (새로 추가)
├── pipelines/           # 파이프라인 정의
├── data/               # 입력 데이터
├── results_public/     # 실행 결과
└── scripts/            # 실행 스크립트
```

## 주요 명령어

### 파이프라인 실행
```bash
# 일반 실행
./run_nf_mag_public.sh

# 벤치마크 모드
./run_nf_mag_public.sh --benchmark
```

### 벤치마크 실행
```bash
# 빠른 벤치마크
benchmark quick-test --pipeline nfcore_mag

# 전체 벤치마크
benchmark run --config .benchmark/config.yaml

# 결과 확인
benchmark view --latest
```

### DB 관리
```bash
# DB 상태 확인
benchmark check-db

# DB 경로 확인
echo $METAGENOME_DB_ROOT
```

## 환경 변수
```bash
METAGENOME_DB_ROOT=/data/shared/metagenome-db
BENCHMARK_API_URL=http://localhost:8000
```

## 벤치마크 통합
이 프로젝트는 `metagenome-pipeline-benchmark`와 통합되어 있습니다:
- 벤치마크 도구로 파이프라인 성능 평가
- 커뮤니티 결과와 비교
- 최적 파라미터 추천

## 트러블슈팅

### DB 경로 문제
```bash
# 심볼릭 링크 재생성
ln -sfn /data/shared/metagenome-db ~/.metagenome_db
```

### 벤치마크 연결 실패
```bash
# API 서버 확인
curl http://localhost:8000/health

# 대시보드 확인
curl http://localhost:8501/_stcore/health
```
```

### Phase 4: 검증 및 최적화 (Week 3)

#### Step 4.1: 통합 테스트
```python
# resistance-tracker/tests/test_integration.py
import pytest
from pathlib import Path
import subprocess

def test_db_migration():
    """DB 마이그레이션 검증"""
    db_root = Path("/data/shared/metagenome-db")
    
    # DB 디렉토리 존재 확인
    assert db_root.exists()
    
    # 주요 DB 확인
    assert (db_root / "busco").exists()
    assert (db_root / "gtdbtk").exists()
    
    # 환경변수 확인
    import os
    assert os.getenv("METAGENOME_DB_ROOT") == str(db_root)

def test_benchmark_integration():
    """벤치마크 도구 통합 테스트"""
    # 벤치마크 설정 파일 존재
    assert Path(".benchmark/config.yaml").exists()
    
    # 벤치마크 CLI 사용 가능
    result = subprocess.run(
        ["benchmark", "--version"],
        capture_output=True,
        text=True
    )
    assert result.returncode == 0

def test_pipeline_execution():
    """파이프라인 실행 테스트"""
    # 테스트 데이터로 빠른 실행
    result = subprocess.run(
        ["nextflow", "run", "test.nf", "-profile", "test"],
        capture_output=True,
        text=True
    )
    assert "SUCCESS" in result.stdout
```

#### Step 4.2: 성능 비교
```bash
#!/bin/bash
# scripts/compare_performance.sh

echo "🔍 Comparing before/after migration..."

# 이전 실행 시간 (예시)
OLD_TIME="24h 30m"

# 새 실행 시간 측정
START=$(date +%s)
./run_nf_mag_public.sh --test
END=$(date +%s)
NEW_TIME=$((END - START))

echo "Old execution time: $OLD_TIME"
echo "New execution time: $(printf '%dh %dm' $((NEW_TIME/3600)) $((NEW_TIME%3600/60)))"

# 벤치마크 비교
benchmark compare \
    --before migration_baseline \
    --after .benchmark/results/latest \
    --output comparison_report.html
```

## 4. 롤백 계획

### 롤백 스크립트
```bash
#!/bin/bash
# scripts/rollback.sh

echo "⚠️ Rolling back migration..."

# 1. DB 원위치로 복구
if [ -L ~/resistance-tracker/shared/databases ]; then
    rm ~/resistance-tracker/shared/databases
    mv /data/shared/metagenome-db/* ~/resistance-tracker/shared/databases/
fi

# 2. 설정 파일 복구
git checkout HEAD -- nextflow.config

# 3. 환경변수 제거
unset METAGENOME_DB_ROOT
unset BUSCO_DB
unset GTDBTK_DB

echo "✅ Rollback completed"
```

## 5. 체크리스트

### Phase 1 체크리스트
- [ ] 공용 DB 디렉토리 생성
- [ ] 기존 DB 이동
- [ ] 심볼릭 링크 설정
- [ ] 환경변수 설정
- [ ] nextflow.config 업데이트

### Phase 2 체크리스트
- [ ] 벤치마크 CLI 설치
- [ ] .benchmark/config.yaml 생성
- [ ] 벤치마크 실행 테스트
- [ ] 대시보드 연결 확인

### Phase 3 체크리스트
- [ ] 실행 스크립트 업데이트
- [ ] CLAUDE.md 작성
- [ ] 문서 업데이트
- [ ] 팀 교육

### Phase 4 체크리스트
- [ ] 통합 테스트 실행
- [ ] 성능 비교
- [ ] 문제점 수정
- [ ] 최종 검증

## 6. 예상 이슈 및 대응

### 이슈 1: 디스크 공간 부족
**해결**: NAS 마운트 또는 용량 증설

### 이슈 2: 권한 문제
**해결**: 그룹 권한 설정
```bash
sudo groupadd metagenome
sudo usermod -a -G metagenome $(whoami)
sudo chgrp -R metagenome /data/shared/metagenome-db
sudo chmod -R 775 /data/shared/metagenome-db
```

### 이슈 3: 네트워크 지연
**해결**: 로컬 캐시 활용
```yaml
# .benchmark/config.yaml
cache:
  enabled: true
  ttl: 86400  # 1일
  max_size: "10GB"
```

## 7. 타임라인

| 주차 | 작업 | 담당 | 상태 |
|------|------|------|------|
| Week 1 | DB 이전 | DevOps | 🔄 진행중 |
| Week 2 | 벤치마크 통합 | 개발팀 | ⏳ 대기 |
| Week 2-3 | 스크립트 업데이트 | 개발팀 | ⏳ 대기 |
| Week 3 | 검증 및 최적화 | QA팀 | ⏳ 대기 |

## 8. 완료 후 이점

1. **용량 절약**: 프로젝트별 DB 중복 제거
2. **벤치마킹**: 체계적인 성능 평가
3. **최적화**: 데이터 기반 파라미터 선택
4. **공유**: 커뮤니티 지식 활용
5. **관리**: 중앙화된 DB 관리

마이그레이션 완료 후 resistance-tracker는 더 효율적이고 체계적인 메타게놈 분석 프로젝트가 됩니다.