# 현실적인 벤치마크 접근 방법

## 1. 현실 체크 ✋

### 지금까지 만든 것의 문제점
- **과도한 추상화**: SDK, API, 모듈... 실제로 구현된 건 없음
- **Wrapper의 함정**: Nextflow를 Python으로 감싸는 불필요한 레이어
- **복잡도 증가**: 오히려 직접 실행보다 복잡해짐
- **유지보수 부담**: Wrapper 자체를 계속 업데이트해야 함

### 진짜 필요한 것
1. **파라미터 조합 테스트**: 어떤 조합이 가장 좋은지
2. **실행 시간/메모리 측정**: 리소스 사용량 파악
3. **결과 비교**: 어셈블리 품질, 비닝 결과 등

## 2. 가장 단순하고 실용적인 방법

### 방법 1: 단순 Bash 스크립트 (가장 현실적) ⭐

```bash
#!/bin/bash
# benchmark_simple.sh - 직접 실행하고 비교

# 테스트할 파라미터 조합
ASSEMBLERS=("megahit" "spades")
MIN_CONTIGS=(1500 2000 2500)
BINNERS=("metabat2" "maxbin2")

# 각 조합 실행
for assembler in "${ASSEMBLERS[@]}"; do
  for min_contig in "${MIN_CONTIGS[@]}"; do
    for binner in "${BINNERS[@]}"; do
      
      # 결과 디렉토리
      OUTDIR="results/${assembler}_${min_contig}_${binner}"
      
      # Nextflow 직접 실행
      echo "Testing: $assembler, $min_contig, $binner"
      
      time nextflow run nf-core/mag \
        -r 3.1.0 \
        --assembler $assembler \
        --min_contig_size $min_contig \
        --binner $binner \
        --input sample_sheet.csv \
        --outdir $OUTDIR \
        -profile singularity \
        -resume
      
      # 간단한 메트릭 수집
      echo "$assembler,$min_contig,$binner,$(date)" >> benchmark_log.csv
      
      # 메모리 사용량 기록
      grep "Peak" $OUTDIR/pipeline_info/execution_trace.txt >> benchmark_log.csv
    done
  done
done

# 결과 요약
echo "Benchmark completed. Results in benchmark_log.csv"
```

### 방법 2: 간단한 Python 스크립트 (분석용)

```python
#!/usr/bin/env python3
# analyze_results.py - 결과 분석만 담당

import pandas as pd
import glob
from pathlib import Path

def analyze_benchmark_results():
    """실행 결과 분석"""
    
    results = []
    
    # 각 결과 디렉토리 분석
    for result_dir in glob.glob("results/*"):
        # 디렉토리 이름에서 파라미터 추출
        params = Path(result_dir).name.split('_')
        
        # MultiQC 리포트에서 메트릭 추출
        metrics = {
            'assembler': params[0],
            'min_contig': params[1],
            'binner': params[2]
        }
        
        # BUSCO 결과 읽기
        busco_file = f"{result_dir}/QC_shortreads/BUSCO/busco_summary.tsv"
        if Path(busco_file).exists():
            busco_df = pd.read_csv(busco_file, sep='\t')
            metrics['completeness'] = busco_df['Complete'].mean()
        
        # 실행 시간 읽기
        trace_file = f"{result_dir}/pipeline_info/execution_trace.txt"
        if Path(trace_file).exists():
            trace_df = pd.read_csv(trace_file, sep='\t')
            metrics['total_time'] = trace_df['realtime'].sum()
            metrics['peak_memory'] = trace_df['peak_rss'].max()
        
        results.append(metrics)
    
    # 결과 테이블 생성
    df = pd.DataFrame(results)
    
    # 최적 조합 찾기
    best_by_completeness = df.nlargest(1, 'completeness')
    best_by_speed = df.nsmallest(1, 'total_time')
    
    print("Best by completeness:")
    print(best_by_completeness)
    print("\nBest by speed:")
    print(best_by_speed)
    
    # CSV로 저장
    df.to_csv('benchmark_analysis.csv', index=False)
    
    return df

if __name__ == "__main__":
    analyze_benchmark_results()
```

### 방법 3: Nextflow 자체 기능 활용

```groovy
// benchmark.nf - Nextflow로 직접 벤치마킹

params.assemblers = ['megahit', 'spades']
params.min_contigs = [1500, 2000, 2500]
params.binners = ['metabat2', 'maxbin2']

// 파라미터 조합 생성
parameter_combinations = []
params.assemblers.each { assembler ->
    params.min_contigs.each { min_contig ->
        params.binners.each { binner ->
            parameter_combinations << [
                assembler: assembler,
                min_contig: min_contig,
                binner: binner
            ]
        }
    }
}

// 각 조합에 대해 워크플로우 실행
workflow {
    Channel
        .from(parameter_combinations)
        .map { combo ->
            // MAG 파이프라인 실행
            RUN_MAG(
                params.input,
                combo.assembler,
                combo.min_contig,
                combo.binner
            )
        }
        .collect()
        .map { results ->
            // 결과 비교
            COMPARE_RESULTS(results)
        }
}
```

## 3. 실제로 지금 당장 할 수 있는 것

### Step 1: 테스트 데이터 준비
```bash
# 작은 테스트 데이터셋 만들기
head -n 100000 ERR599039_1.fastq > test_R1.fastq
head -n 100000 ERR599039_2.fastq > test_R2.fastq
```

### Step 2: 2-3개 조합만 테스트
```bash
# 조합 1: 빠른 실행
nextflow run nf-core/mag \
  --assembler megahit \
  --min_contig_size 1500 \
  --binner metabat2 \
  --outdir results/fast \
  --max_memory 32GB

# 조합 2: 정확도 우선
nextflow run nf-core/mag \
  --assembler spades \
  --min_contig_size 2500 \
  --binner concoct \
  --outdir results/accurate \
  --max_memory 150GB
```

### Step 3: 간단 비교
```bash
# 실행 시간 비교
grep "Completed" results/*/pipeline_info/execution_report.html

# 어셈블리 통계 비교
grep "N50" results/*/Assembly/QC/quast_summary.tsv

# 비닝 결과 비교
wc -l results/*/GenomeBinning/bin_summary.tsv
```

## 4. 복잡한 도구가 필요한 시점

### 지금은 불필요
- 파라미터 조합이 10개 미만
- 수동으로 충분히 관리 가능
- 결과 비교가 단순함

### 나중에 필요할 때
- 파라미터 조합이 100개 이상
- 여러 프로젝트에서 반복 사용
- 자동화된 의사결정이 필요
- 팀 단위 사용

## 5. 권장 접근법

### 1단계: 수동 테스트 (현재)
```bash
# 직접 실행하고 엑셀에 기록
./run_test_1.sh
./run_test_2.sh
# 결과를 benchmark_results.xlsx에 수동 입력
```

### 2단계: 간단한 자동화 (필요시)
```bash
# 반복 작업만 스크립트로
for param in 1500 2000 2500; do
    ./run_with_param.sh $param
done
```

### 3단계: 분석 도구 (데이터 쌓인 후)
```python
# 쌓인 데이터 분석
import pandas as pd
df = pd.read_csv('all_results.csv')
df.groupby('assembler')['completeness'].mean()
```

## 6. 결론

### ❌ 지금 하지 말아야 할 것
- 복잡한 SDK/API 구축
- 과도한 추상화 레이어
- Nextflow를 감싸는 Python wrapper
- 범용 벤치마크 프레임워크

### ✅ 지금 해야 할 것
1. **직접 실행**: `nextflow run` 명령어 직접 사용
2. **간단 기록**: 엑셀이나 CSV에 결과 기록
3. **수동 비교**: 2-3개 조합만 비교
4. **점진적 개선**: 필요할 때만 자동화 추가

### 🎯 핵심 원칙
> "Premature optimization is the root of all evil" - Donald Knuth

지금은 단순하게, 나중에 필요하면 복잡하게!

## 7. 즉시 실행 가능한 실용 스크립트

```bash
#!/bin/bash
# quick_benchmark.sh - 30분 안에 결과 확인

echo "Quick Benchmark Starting..."

# 옵션 1 실행
echo "Testing Option 1: Fast mode"
/usr/bin/time -v nextflow run nf-core/mag \
    --assembler megahit \
    --outdir results/option1 \
    -profile test,singularity \
    2>&1 | tee option1.log

# 옵션 2 실행  
echo "Testing Option 2: Accurate mode"
/usr/bin/time -v nextflow run nf-core/mag \
    --assembler spades \
    --outdir results/option2 \
    -profile test,singularity \
    2>&1 | tee option2.log

# 결과 요약
echo "=== RESULTS ==="
echo "Option 1 time: $(grep "Elapsed" option1.log)"
echo "Option 2 time: $(grep "Elapsed" option2.log)"
echo "Option 1 memory: $(grep "Maximum" option1.log)"
echo "Option 2 memory: $(grep "Maximum" option2.log)"

echo "Done! Check results/ directory for details"
```

**이게 진짜 현실적인 벤치마크입니다!**