# Nextflow 메타게놈 벤치마크를 위한 데이터베이스 관리 전략

## 1. 현재 문제점 분석

### 1.1 데이터베이스 관리의 복잡성
- **용량 문제**: GTDB-Tk(~70GB), Kraken2(~100GB), BUSCO(~10GB) 등 대용량 DB
- **중복 다운로드**: 프로젝트마다 DB를 재다운로드하는 비효율
- **버전 관리**: 동일 DB의 여러 버전 관리 어려움
- **경로 하드코딩**: 각 프로젝트마다 DB 경로 개별 설정 필요

### 1.2 결과물 분기 처리 문제
- **네이밍 충돌**: 여러 벤치마크 실행 시 결과물 덮어쓰기
- **비교 어려움**: 다른 파라미터 실행 결과 체계적 관리 부재
- **추적성 부족**: 어떤 설정으로 어떤 결과가 나왔는지 추적 어려움

## 2. 제안하는 해결 방안

### 2.1 중앙집중식 데이터베이스 관리 시스템

```bash
# 권장 디렉토리 구조
/data/shared/metagenome-db/              # NAS 또는 대용량 스토리지
├── registry.yaml                        # DB 메타데이터 레지스트리
├── busco/
│   ├── v5_prokaryotes/                  # 버전별 관리
│   ├── v5_eukaryotes/
│   └── latest -> v5_prokaryotes/        # 심볼릭 링크로 기본값
├── gtdbtk/
│   ├── r207/
│   ├── r214/
│   ├── r220/
│   └── latest -> r220/
├── kraken2/
│   ├── standard_20240101/
│   ├── standard_20240601/
│   └── latest -> standard_20240601/
└── checkm/
    ├── v1.2.2/
    └── latest -> v1.2.2/
```

### 2.2 환경 변수 기반 DB 경로 관리

```bash
# ~/.bashrc 또는 /etc/profile.d/metagenome-db.sh
export METAGENOME_DB_ROOT="/data/shared/metagenome-db"
export BUSCO_DB="${METAGENOME_DB_ROOT}/busco/latest"
export GTDBTK_DB="${METAGENOME_DB_ROOT}/gtdbtk/latest"
export KRAKEN2_DB="${METAGENOME_DB_ROOT}/kraken2/latest"
export CHECKM_DB="${METAGENOME_DB_ROOT}/checkm/latest"
```

### 2.3 Nextflow 통합 설정 파일

```groovy
// configs/database.config
params {
    // DB 루트 경로 (환경변수 우선, 없으면 기본값)
    db_root = System.getenv('METAGENOME_DB_ROOT') ?: '/data/shared/metagenome-db'
    
    // 각 DB 경로 자동 구성
    databases {
        busco {
            path = "${params.db_root}/busco/latest"
            version = 'auto'  // 자동 버전 감지
            download_if_missing = false  // 중앙 DB 사용
        }
        gtdbtk {
            path = "${params.db_root}/gtdbtk/latest"
            version = 'r220'
            download_if_missing = false
        }
        kraken2 {
            path = "${params.db_root}/kraken2/latest"
            version = 'standard_20240601'
            download_if_missing = false
        }
        checkm {
            path = "${params.db_root}/checkm/latest"
            version = 'v1.2.2'
            download_if_missing = false
        }
    }
    
    // 폴백 옵션: 로컬 캐시
    local_db_cache = "${HOME}/.metagenome_db_cache"
}
```

## 3. 결과물 분기 처리 전략

### 3.1 동적 결과 디렉토리 구조

```groovy
// configs/output.config
params {
    // 타임스탬프 기반 고유 실행 ID
    run_id = new Date().format('yyyyMMdd_HHmmss')
    
    // 파라미터 해시 기반 디렉토리
    param_hash = generateParamHash(params)
    
    // 계층적 결과 구조
    outdir = "results/${params.run_id}_${params.param_hash}"
    
    // 결과 구성
    output_structure {
        by_pipeline = true      // 파이프라인별 분리
        by_dataset = true       // 데이터셋별 분리
        by_parameter = true     // 파라미터별 분리
    }
}

// 결과 디렉토리 예시
results/
├── 20240119_143022_a3f2b1/       # 실행 ID + 파라미터 해시
│   ├── metadata.json              # 실행 메타데이터
│   ├── params.json                # 사용된 파라미터
│   ├── nfcore_mag_standard/       # 파이프라인별
│   │   ├── cami2/                 # 데이터셋별
│   │   │   ├── assembly/
│   │   │   ├── binning/
│   │   │   └── evaluation/
│   │   └── metasub/
│   └── nfcore_mag_optimized/
└── comparison_reports/            # 비교 분석 결과
    └── 20240119_comparison.html
```

### 3.2 메타데이터 추적 시스템

```groovy
// modules/metadata_tracker.nf
process TRACK_METADATA {
    publishDir "${params.outdir}/metadata", mode: 'copy'
    
    input:
    val pipeline_name
    val dataset_name
    val parameters
    
    output:
    path "run_metadata.json"
    
    script:
    """
    cat << EOF > run_metadata.json
    {
        "run_id": "${params.run_id}",
        "timestamp": "${new Date()}",
        "pipeline": "${pipeline_name}",
        "dataset": "${dataset_name}",
        "parameters": ${groovy.json.JsonOutput.toJson(parameters)},
        "databases": {
            "busco": "${params.databases.busco.path}",
            "gtdbtk": "${params.databases.gtdbtk.path}",
            "kraken2": "${params.databases.kraken2.path}"
        },
        "system": {
            "nextflow_version": "${nextflow.version}",
            "executor": "${params.executor}",
            "max_cpus": ${params.max_cpus},
            "max_memory": "${params.max_memory}"
        }
    }
    EOF
    """
}
```

## 4. 심볼릭 링크 vs 대안 방법

### 4.1 심볼릭 링크 방식 (권장)

**장점:**
- 디스크 공간 절약
- 중앙 관리 용이
- 버전 전환 간단

**구현:**
```bash
# 심볼릭 링크 생성 스크립트
#!/bin/bash
# scripts/setup_db_links.sh

DB_ROOT="/data/shared/metagenome-db"
USER_DB_DIR="${HOME}/.metagenome_dbs"

mkdir -p ${USER_DB_DIR}

# 각 DB에 대한 심볼릭 링크 생성
for db in busco gtdbtk kraken2 checkm; do
    ln -sfn ${DB_ROOT}/${db}/latest ${USER_DB_DIR}/${db}
done

echo "Database links created in ${USER_DB_DIR}"
```

### 4.2 대안 1: 마운트 포인트 사용

```bash
# /etc/fstab 설정 (관리자 권한 필요)
nas-server:/shared/metagenome-db /mnt/metagenome-db nfs defaults 0 0
```

### 4.3 대안 2: 환경 모듈 시스템

```bash
# modules/metagenome-db/2024.01
#%Module
set DB_ROOT /data/shared/metagenome-db
setenv BUSCO_DB ${DB_ROOT}/busco/latest
setenv GTDBTK_DB ${DB_ROOT}/gtdbtk/latest

# 사용
module load metagenome-db/2024.01
```

### 4.4 대안 3: 컨테이너 볼륨 마운팅

```yaml
# docker-compose.yml
services:
  benchmark:
    image: metagenome-benchmark:latest
    volumes:
      - /data/shared/metagenome-db:/databases:ro
      - ./results:/results:rw
    environment:
      - METAGENOME_DB_ROOT=/databases
```

## 5. 벤치마크 자동화 워크플로우

### 5.1 마스터 벤치마크 스크립트

```bash
#!/bin/bash
# bin/run_benchmark_suite.sh

# 설정 로드
source configs/benchmark.env

# DB 체크 및 설정
check_databases() {
    for db in BUSCO GTDBTK KRAKEN2 CHECKM; do
        db_path=$(eval echo \$${db}_DB)
        if [ ! -d "$db_path" ]; then
            echo "Warning: ${db} database not found at ${db_path}"
            echo "Attempting to use fallback..."
            setup_fallback_db $db
        fi
    done
}

# 파라미터 조합 생성
generate_parameter_combinations() {
    cat << EOF > params_matrix.json
    {
        "assemblers": ["megahit", "spades", "metaspades"],
        "binners": ["metabat2", "maxbin2", "concoct"],
        "min_contig_size": [1500, 2500, 5000],
        "datasets": ["cami2", "metasub", "custom"]
    }
EOF
}

# 벤치마크 실행
run_benchmarks() {
    local params_file=$1
    local combinations=$(generate_combinations $params_file)
    
    for combo in $combinations; do
        run_id=$(date +%Y%m%d_%H%M%S)_$(echo $combo | md5sum | cut -c1-8)
        
        nextflow run main.nf \
            -profile singularity,benchmark \
            -params-file $combo \
            --run_id $run_id \
            --outdir results/${run_id} \
            -resume \
            -with-report results/${run_id}/execution_report.html \
            -with-timeline results/${run_id}/timeline.html \
            -with-trace results/${run_id}/trace.txt
    done
}

# 결과 통합 및 비교
aggregate_results() {
    python scripts/aggregate_benchmarks.py \
        --results_dir results/ \
        --output_dir results/comparison_$(date +%Y%m%d) \
        --generate_report
}

# 메인 실행
main() {
    check_databases
    generate_parameter_combinations
    run_benchmarks params_matrix.json
    aggregate_results
}

main "$@"
```

### 5.2 파라미터 관리 시스템

```python
# src/utils/parameter_manager.py
import hashlib
import json
from pathlib import Path
from itertools import product

class ParameterManager:
    def __init__(self, base_config='configs/benchmark.config'):
        self.base_config = self.load_config(base_config)
        self.param_space = {}
        
    def add_parameter_space(self, param_dict):
        """파라미터 공간 정의"""
        self.param_space.update(param_dict)
        
    def generate_combinations(self):
        """모든 파라미터 조합 생성"""
        keys = self.param_space.keys()
        values = self.param_space.values()
        
        for combo in product(*values):
            params = dict(zip(keys, combo))
            yield self.create_param_set(params)
            
    def create_param_set(self, params):
        """파라미터 세트 생성 with 고유 ID"""
        param_hash = hashlib.md5(
            json.dumps(params, sort_keys=True).encode()
        ).hexdigest()[:8]
        
        return {
            'id': param_hash,
            'params': params,
            'config_file': self.write_config(param_hash, params)
        }
        
    def write_config(self, param_id, params):
        """Nextflow 설정 파일 생성"""
        config_path = Path(f'configs/generated/{param_id}.config')
        config_path.parent.mkdir(exist_ok=True)
        
        with open(config_path, 'w') as f:
            f.write(f"// Auto-generated config for {param_id}\n")
            f.write("params {\n")
            for key, value in params.items():
                f.write(f"    {key} = {self.format_value(value)}\n")
            f.write("}\n")
            
        return config_path
```

## 6. 실무 적용 예시

### 6.1 resistance-tracker 프로젝트 적용

```bash
# 1. 초기 설정
cd ~/metagenome-resistance-tracker
source /data/shared/metagenome-db/setup.sh

# 2. 벤치마크 실행
benchmark_resistance_pipeline() {
    # 자신의 데이터로 테스트
    nextflow run metagenome-benchmark \
        --input ./data/TARA_samples.csv \
        --pipelines "nfcore_mag,nfcore_funcscan" \
        --focus "amr_genes" \
        --db_config /data/shared/metagenome-db/configs/amr_dbs.config \
        --outdir ./benchmark_results
}

# 3. 최적 파이프라인 선택
select_best_pipeline() {
    python -m metagenome_benchmark.analyze \
        --results ./benchmark_results \
        --criteria "amr_sensitivity>0.9,runtime<24h" \
        --recommend
}
```

### 6.2 CI/CD 통합

```yaml
# .github/workflows/benchmark.yml
name: Benchmark Pipeline

on:
  push:
    paths:
      - 'configs/**.config'
      - 'pipelines/**.nf'

jobs:
  benchmark:
    runs-on: self-hosted
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Database Links
        run: |
          ./scripts/setup_db_links.sh
          
      - name: Run Benchmark
        run: |
          nextflow run main.nf \
            -profile test,singularity \
            --quick_test true
            
      - name: Compare with Baseline
        run: |
          python scripts/compare_with_baseline.py \
            --new results/latest \
            --baseline results/baseline \
            --threshold 0.95
```

## 7. 모니터링 및 유지보수

### 7.1 DB 버전 관리 대시보드

```python
# src/utils/db_monitor.py
class DatabaseMonitor:
    def check_updates(self):
        """새 버전 확인"""
        pass
        
    def validate_integrity(self):
        """DB 무결성 검증"""
        pass
        
    def generate_report(self):
        """사용 통계 및 상태 리포트"""
        pass
```

### 7.2 자동 정리 스크립트

```bash
# scripts/cleanup_old_results.sh
#!/bin/bash

# 30일 이상 된 결과 압축
find results/ -type d -mtime +30 -exec tar -czf {}.tar.gz {} \;

# 90일 이상 된 압축 파일 아카이브로 이동
find results/ -name "*.tar.gz" -mtime +90 -exec mv {} archive/ \;
```

## 8. 결론 및 권장사항

### 최종 권장 아키텍처:
1. **중앙 DB 저장소**: NAS/공유 스토리지에 모든 DB 통합 관리
2. **심볼릭 링크**: 사용자 홈에서 중앙 DB로 링크
3. **환경 변수**: 시스템 전역 DB 경로 설정
4. **동적 결과 관리**: 타임스탬프 + 파라미터 해시 기반 디렉토리
5. **메타데이터 추적**: 모든 실행 정보 JSON 저장

이 구조로 자유로운 벤치마킹과 체계적인 관리가 모두 가능합니다.