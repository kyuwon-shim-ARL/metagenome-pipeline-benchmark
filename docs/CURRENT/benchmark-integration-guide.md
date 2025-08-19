# 벤치마크 도구 통합 사용 가이드

## 1. 개념 정리

### 역할 분담
- **메인 분석**: `resistance-tracker` 같은 개별 프로젝트에서 실제 분석 수행
- **벤치마크**: `metagenome-pipeline-benchmark`를 라이브러리처럼 import해서 성능 측정

### 사용 패턴
```
[개별 프로젝트] → import → [벤치마크 도구] → 성능 측정 → 최적화
```

## 2. 통합 방법 (3가지)

### 방법 1: Python SDK로 사용 (권장) ⭐

```python
# resistance-tracker/scripts/optimize_pipeline.py

# 벤치마크 도구를 패키지로 import
from metagenome_benchmark import BenchmarkSDK, PipelineOptimizer

# 1. SDK 초기화
benchmark = BenchmarkSDK(
    project='resistance-tracker',
    config='.benchmark/config.yaml'
)

# 2. 현재 파이프라인 테스트
results = benchmark.test_pipeline(
    pipeline='nfcore_mag',
    data='./data/sample_sheet.csv',
    params={
        'assembler': 'megahit',
        'binner': 'metabat2',
        'min_contig_size': 1500
    }
)

# 3. 다른 조합 테스트
optimizer = PipelineOptimizer(benchmark)
best_params = optimizer.find_optimal(
    constraints={
        'max_memory': '150GB',
        'max_time': '24h',
        'min_accuracy': 0.85
    }
)

print(f"최적 파라미터: {best_params}")
```

### 방법 2: CLI 도구로 사용

```bash
# resistance-tracker 프로젝트에서

# 1. 벤치마크 CLI 설치 (한 번만)
pip install metagenome-benchmark-cli

# 2. 프로젝트에서 직접 벤치마크 실행
cd ~/resistance-tracker

# 3. 빠른 테스트
benchmark quick-test \
    --pipeline nfcore_mag \
    --input data/sample.csv

# 4. 파라미터 스윕
benchmark parameter-sweep \
    --pipeline nfcore_mag \
    --param assembler=megahit,spades \
    --param min_contig=1500,2000,2500 \
    --output results/benchmark/

# 5. 최적 조합 찾기
benchmark optimize \
    --goal "amr_detection" \
    --constraints "memory<150GB,time<24h"
```

### 방법 3: Git Submodule로 통합

```bash
# resistance-tracker에 벤치마크 도구 포함
cd ~/resistance-tracker

# 서브모듈로 추가
git submodule add https://github.com/your/metagenome-pipeline-benchmark.git benchmark-tools
git submodule update --init

# 직접 스크립트 실행
python benchmark-tools/src/run_benchmark.py --local
```

## 3. 실제 사용 시나리오

### 시나리오 1: AMR 검출 최적화

```python
# resistance-tracker/optimize_amr_detection.py

from metagenome_benchmark import AMRBenchmark

def optimize_amr_pipeline():
    """AMR 검출에 최적화된 파이프라인 찾기"""
    
    # AMR 특화 벤치마크
    amr_bench = AMRBenchmark()
    
    # 테스트할 파이프라인 조합
    pipelines = [
        {'name': 'nfcore_mag', 'version': '3.1.0'},
        {'name': 'nfcore_funcscan', 'version': '1.1.0'},
        {'name': 'custom_amr', 'version': 'latest'}
    ]
    
    # 각 파이프라인 테스트
    results = {}
    for pipeline in pipelines:
        result = amr_bench.test(
            pipeline=pipeline,
            test_data='./data/known_resistance_samples.csv',
            metrics=['sensitivity', 'specificity', 'f1_score']
        )
        results[pipeline['name']] = result
    
    # 최적 파이프라인 선택
    best = max(results.items(), key=lambda x: x[1]['f1_score'])
    print(f"최적 AMR 파이프라인: {best[0]}")
    
    return best
```

### 시나리오 2: 리소스 제약 하에서 최적화

```python
# resistance-tracker/resource_optimization.py

from metagenome_benchmark import ResourceOptimizer

def find_efficient_params():
    """제한된 리소스에서 최선의 파라미터 찾기"""
    
    optimizer = ResourceOptimizer(
        max_memory='32GB',  # 서버 제약
        max_cores=8,
        max_time='12h'
    )
    
    # 가능한 파라미터 공간 정의
    param_space = {
        'assembler': ['megahit'],  # SPAdes는 메모리 부족
        'min_contig_size': [1000, 1500, 2000],
        'binner': ['metabat2', 'maxbin2'],
        'min_bin_size': [200000, 500000]
    }
    
    # 제약 조건 내에서 최적화
    best_params = optimizer.optimize(
        param_space=param_space,
        objective='maximize_bins',
        constraints=['memory', 'time']
    )
    
    return best_params
```

### 시나리오 3: A/B 테스트

```python
# resistance-tracker/ab_testing.py

from metagenome_benchmark import ABTester

def compare_versions():
    """새 버전 vs 기존 버전 비교"""
    
    tester = ABTester()
    
    # A: 현재 프로덕션 설정
    config_a = {
        'name': 'current_production',
        'pipeline': 'nfcore_mag',
        'version': '2.5.0',
        'params': load_current_config()
    }
    
    # B: 새로운 버전
    config_b = {
        'name': 'new_version',
        'pipeline': 'nfcore_mag',
        'version': '3.1.0',
        'params': load_new_config()
    }
    
    # 동일 데이터로 비교
    comparison = tester.compare(
        config_a=config_a,
        config_b=config_b,
        test_data='./data/validation_set.csv',
        metrics=['accuracy', 'runtime', 'memory']
    )
    
    # 통계적 유의성 검정
    if comparison.is_significant():
        print(f"새 버전이 {comparison.improvement}% 개선")
        return 'upgrade'
    else:
        print("유의미한 차이 없음")
        return 'keep_current'
```

## 4. 워크플로우 통합

### Nextflow 파이프라인에 벤치마크 통합

```groovy
// resistance-tracker/workflows/benchmark.nf

include { BENCHMARK_MODULE } from '../benchmark-tools/modules/benchmark'

workflow BENCHMARK_PIPELINE {
    take:
    input_data
    pipeline_config
    
    main:
    // 실제 분석 실행
    ANALYSIS_PIPELINE(input_data, pipeline_config)
    
    // 벤치마크 메트릭 수집
    BENCHMARK_MODULE(
        ANALYSIS_PIPELINE.out.results,
        ANALYSIS_PIPELINE.out.logs
    )
    
    // 결과 비교
    COMPARE_WITH_BASELINE(
        BENCHMARK_MODULE.out.metrics,
        params.baseline_metrics
    )
    
    emit:
    results = ANALYSIS_PIPELINE.out.results
    metrics = BENCHMARK_MODULE.out.metrics
    comparison = COMPARE_WITH_BASELINE.out
}
```

### CI/CD 통합

```yaml
# .github/workflows/benchmark.yml
name: Benchmark on PR

on:
  pull_request:
    paths:
      - 'configs/*.config'
      - 'workflows/*.nf'

jobs:
  benchmark:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Benchmark Tools
        run: pip install metagenome-benchmark-cli
      
      - name: Run Benchmark
        run: |
          benchmark ci-test \
            --baseline main \
            --changes ${{ github.sha }} \
            --threshold 5%  # 5% 이상 성능 저하시 실패
      
      - name: Comment Results
        uses: actions/github-script@v6
        with:
          script: |
            const results = require('./benchmark-results.json');
            github.issues.createComment({
              issue_number: context.issue.number,
              body: `## 벤치마크 결과\n${results.summary}`
            });
```

## 5. 설정 파일 구조

### resistance-tracker/.benchmark/config.yaml

```yaml
# 프로젝트별 벤치마크 설정
benchmark:
  # 벤치마크 도구 연결
  tool_path: "~/metagenome-pipeline-benchmark"
  
  # 또는 패키지로 설치된 경우
  use_package: true
  package_name: "metagenome-benchmark"
  
  # 프로젝트 특성
  project:
    type: "amr_detection"
    focus: ["resistance_genes", "plasmids"]
    
  # 벤치마크 대상
  targets:
    - pipeline: "nfcore_mag"
      profile: "singularity"
    - pipeline: "nfcore_funcscan"
      profile: "docker"
      
  # 평가 메트릭
  metrics:
    primary:
      - amr_sensitivity
      - amr_specificity
    secondary:
      - runtime
      - memory_usage
      
  # 자동화
  auto_benchmark:
    enabled: true
    frequency: "weekly"
    compare_with: "baseline"
```

## 6. 실용적 팁

### DO's ✅
1. **선택적 사용**: 필요한 모듈만 import
2. **캐싱 활용**: 반복 실행시 결과 재사용
3. **점진적 통합**: 작은 부분부터 시작
4. **버전 관리**: 벤치마크 도구 버전 고정

### DON'Ts ❌
1. **과도한 벤치마킹**: 모든 실행마다 X
2. **프로덕션 혼합**: 벤치마크는 별도 환경
3. **무시한 최적화**: 벤치마크 결과 무시 X

## 7. 예제: resistance-tracker 통합

```python
# resistance-tracker/run_analysis_with_benchmark.py

import sys
sys.path.append('~/metagenome-pipeline-benchmark/src')

from metagenome_benchmark import Benchmark
import subprocess

def run_with_optimization():
    # 1. 벤치마크로 최적 파라미터 찾기
    bench = Benchmark()
    optimal_params = bench.get_optimal_params(
        data_type='metagenome',
        goal='amr_detection'
    )
    
    # 2. 최적 파라미터로 실제 분석 실행
    cmd = f"""
    nextflow run nf-core/mag \\
        -r 3.1.0 \\
        --assembler {optimal_params['assembler']} \\
        --min_contig_size {optimal_params['min_contig']} \\
        --binner {optimal_params['binner']}
    """
    
    subprocess.run(cmd, shell=True)
    
    # 3. 결과 검증
    bench.validate_results('./results/')

if __name__ == "__main__":
    run_with_optimization()
```

## 8. 요약

**네, 정확합니다!** 벤치마크 도구를 의존성 패키지처럼 사용하면서:

1. **분석은 개별 프로젝트에서** (resistance-tracker)
2. **벤치마킹은 필요시 import** (metagenome-pipeline-benchmark)
3. **최적화 결과를 분석에 반영**

이렇게 하면 깔끔한 관심사 분리(Separation of Concerns)가 가능합니다!