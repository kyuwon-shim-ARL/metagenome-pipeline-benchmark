#!/bin/bash
# quick_benchmark.sh - 실용적인 벤치마크 스크립트
# 과도한 추상화 없이 바로 사용 가능

set -e

# 색상 코드
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== Metagenome Pipeline Quick Benchmark ===${NC}"
echo "Start time: $(date)"
echo

# 설정
INPUT_DATA="sample_sheet_public.csv"
RESULTS_BASE="benchmark_results"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# 결과 디렉토리 생성
mkdir -p $RESULTS_BASE/$TIMESTAMP

# 간단한 로그 파일
LOG_FILE="$RESULTS_BASE/$TIMESTAMP/benchmark_summary.txt"

# 헤더 작성
echo "Benchmark Run: $TIMESTAMP" > $LOG_FILE
echo "================================" >> $LOG_FILE
echo "" >> $LOG_FILE

# 테스트 1: MEGAHIT (빠른 실행)
echo -e "${YELLOW}Test 1: MEGAHIT + MetaBAT2 (Fast)${NC}"
echo "Test 1: MEGAHIT + MetaBAT2" >> $LOG_FILE

START_TIME=$(date +%s)

nextflow run nf-core/mag \
    -r 3.1.0 \
    -profile test,singularity \
    --assembler megahit \
    --min_contig_size 1500 \
    --binner metabat2 \
    --skip_gtdbtk \
    --outdir $RESULTS_BASE/$TIMESTAMP/megahit_metabat2 \
    -resume \
    2>&1 | tee $RESULTS_BASE/$TIMESTAMP/megahit.log | grep -E "Completed|WARN|ERROR"

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

echo "  Duration: $DURATION seconds" | tee -a $LOG_FILE
echo "  Peak memory: $(grep 'peak_rss' $RESULTS_BASE/$TIMESTAMP/megahit_metabat2/pipeline_info/execution_trace.txt 2>/dev/null | awk '{print $7}' | sort -n | tail -1 || echo 'N/A')" | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE

# 테스트 2: SPAdes (정확도 우선) - 선택적
read -p "Run SPAdes test? (slower, more accurate) [y/N]: " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Test 2: SPAdes + CONCOCT (Accurate)${NC}"
    echo "Test 2: SPAdes + CONCOCT" >> $LOG_FILE
    
    START_TIME=$(date +%s)
    
    nextflow run nf-core/mag \
        -r 3.1.0 \
        -profile test,singularity \
        --assembler spades \
        --min_contig_size 2500 \
        --binner concoct \
        --skip_gtdbtk \
        --outdir $RESULTS_BASE/$TIMESTAMP/spades_concoct \
        -resume \
        2>&1 | tee $RESULTS_BASE/$TIMESTAMP/spades.log | grep -E "Completed|WARN|ERROR"
    
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    
    echo "  Duration: $DURATION seconds" | tee -a $LOG_FILE
    echo "  Peak memory: $(grep 'peak_rss' $RESULTS_BASE/$TIMESTAMP/spades_concoct/pipeline_info/execution_trace.txt 2>/dev/null | awk '{print $7}' | sort -n | tail -1 || echo 'N/A')" | tee -a $LOG_FILE
    echo "" | tee -a $LOG_FILE
fi

# 간단한 결과 비교
echo -e "${GREEN}=== Quick Comparison ===${NC}"
echo "Quick Comparison" >> $LOG_FILE
echo "================================" >> $LOG_FILE

# Assembly 통계 비교
for dir in $RESULTS_BASE/$TIMESTAMP/*/; do
    if [ -d "$dir" ]; then
        echo "$(basename $dir):" | tee -a $LOG_FILE
        
        # N50 확인
        if [ -f "$dir/Assembly/QC/quast_summary.tsv" ]; then
            echo "  N50: $(grep 'N50' $dir/Assembly/QC/quast_summary.tsv | cut -f2)" | tee -a $LOG_FILE
        fi
        
        # Bin 개수 확인
        if [ -f "$dir/GenomeBinning/bin_summary.tsv" ]; then
            echo "  Bins: $(wc -l < $dir/GenomeBinning/bin_summary.tsv)" | tee -a $LOG_FILE
        fi
        
        echo "" | tee -a $LOG_FILE
    fi
done

echo -e "${GREEN}=== Benchmark Complete ===${NC}"
echo "Results saved in: $RESULTS_BASE/$TIMESTAMP/"
echo "Summary: $LOG_FILE"

# 가장 기본적인 추천
echo
echo -e "${GREEN}Recommendation:${NC}"
echo "- For quick analysis: Use MEGAHIT + MetaBAT2"
echo "- For publication: Consider SPAdes + CONCOCT (if resources allow)"
echo
echo "To use optimal settings:"
echo "  nextflow run nf-core/mag --assembler megahit --min_contig_size 1500 --binner metabat2"