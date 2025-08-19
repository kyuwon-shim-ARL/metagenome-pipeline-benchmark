# CLAUDE.md - 간단한 메타게놈 벤치마크 도구

## 🎯 목적

메타게놈 분석 파이프라인의 간단한 성능 비교 도구입니다.
**복잡한 시스템 대신 실용적인 접근법을 사용합니다.**

## 📁 구조

```
metagenome-pipeline-benchmark/
├── scripts/
│   └── quick_benchmark.sh        # 핵심: 간단한 벤치마크
├── data/
│   └── shared/metagenome-db/    # 공용 데이터베이스
├── docs/CURRENT/                # 현실적 접근법 문서
└── /data/shared/metagenome-db/  # 실제 DB 위치
```

## 🚀 사용법

### 1. 공용 DB 환경 로딩 (필요시만)
```bash
source ~/.metagenome_db_env
```

### 2. 간단한 벤치마크 실행
```bash
cd scripts/
./quick_benchmark.sh
```

### 3. 결과 확인
```bash
cat benchmark_results/*/benchmark_summary.txt
```

## 📊 공용 데이터베이스

### DB 위치
```bash
/data/shared/metagenome-db/
├── reference/          # /db/에서 링크된 기존 DB들
├── metagenome/         # 새로운 메타게놈 특화 DB들
└── specialized/        # AMR, 플라스미드 등
```

### 환경 변수
```bash
METAGENOME_DB_ROOT="/data/shared/metagenome-db"
BUSCO_DB="$METAGENOME_DB_ROOT/metagenome/busco/latest"
GTDBTK_DB="$METAGENOME_DB_ROOT/metagenome/gtdbtk/latest"
```

### DB 상태 확인
```bash
source ~/.metagenome_db_env
check_production_db
```

## 💡 핵심 철학

### ✅ 이것을 사용하세요
1. **직접 실행**: `nextflow run nf-core/mag --assembler megahit`
2. **간단 비교**: 2-3개 파라미터만 테스트
3. **수동 기록**: Excel/CSV로 결과 정리
4. **필요시 분석**: 간단한 Python 스크립트

### ❌ 이런 건 하지 마세요
1. **복잡한 SDK**: Python wrapper 만들기
2. **과도한 추상화**: 모든 걸 모듈화
3. **불필요한 캐싱**: Nextflow가 알아서 해줌
4. **거창한 시스템**: 간단한 걸로 충분함

## 🔧 트러블슈팅

### DB 접근 문제
```bash
# DB 경로 확인
echo $METAGENOME_DB_ROOT

# DB 상태 확인
ls -la /data/shared/metagenome-db/

# 환경 재로드
source ~/.metagenome_db_env
```

### 벤치마크 실행 문제
```bash
# 스크립트 권한 확인
chmod +x scripts/quick_benchmark.sh

# Nextflow 설치 확인
nextflow version
```

## 📚 추가 문서

현실적 접근법과 교훈은 `docs/CURRENT/` 폴더를 참고하세요:
- `realistic-approach.md` - 왜 단순한 게 좋은지
- `caching-reality-check.md` - 캐싱의 한계
- `storage-strategy.md` - 스토리지 최적화
- `simple-conclusion.md` - 최종 결론

## 🎯 요약

**메타게놈 분석에서 파이프라인 비교가 필요하면:**

1. `./quick_benchmark.sh` 실행
2. 2-3개 조합 테스트  
3. 결과를 Excel에 기록
4. 최적 파라미터 선택
5. 끝

**Simple is Best!**