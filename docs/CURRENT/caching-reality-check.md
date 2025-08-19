# 캐싱 효과 현실 체크 - DB와 Input 데이터 비교

## 🔍 핵심 질문: "캐싱한다고 뭐가 크게 바뀌나?"

### 정답: **별로 안 바뀝니다** 😅

## 📊 데이터 특성 비교

### 1. Reference DB 특성
```
크기: 10-200GB (DB당)
사용 패턴: 읽기 전용, 반복 사용
업데이트: 년 1-2회
프로젝트 공유: 가능
```

### 2. Input FASTA/FASTQ 특성
```
크기: 20-200GB (샘플당), 1-5TB (프로젝트당)
사용 패턴: 1회성, 프로젝트별 고유
업데이트: 없음 (새 데이터)
프로젝트 공유: 불가능
```

## 🎭 캐싱 효과 분석

### DB 캐싱 시나리오
```
NAS에 GTDB-Tk (70GB) 있을 때:

[첫 실행]
- NAS → Local 복사: 30분 (40MB/s)
- 이후 실행: 로컬에서 즉시 사용
- 효과: ✅ 2회차부터 30분 절약

[문제]
- 70GB 로컬 공간 차지
- 어차피 한 번은 30분 걸림
```

### Input Data 캐싱 시나리오
```
NAS에 FASTQ (100GB) 있을 때:

[옵션 1: 캐싱]
- NAS → Local 복사: 40분
- 분석 실행: 2시간
- 총 시간: 2시간 40분
- 사용 후 삭제 필요 (공간 부족)

[옵션 2: 직접 처리]
- NAS에서 직접 읽기: 3시간
- 총 시간: 3시간

차이: 20분... 🤷
```

## 📈 실제 Nextflow 파이프라인 동작

### 어차피 Nextflow가 하는 일
```groovy
// Nextflow 내부 동작
process ASSEMBLY {
    input:
    path reads from input_channel
    
    script:
    """
    # Nextflow가 자동으로:
    # 1. NAS의 reads를 work/xx/yyyy/ 로 복사 (캐싱)
    # 2. 프로세스 실행
    # 3. 결과를 output으로 복사
    
    megahit -1 ${reads[0]} -2 ${reads[1]} -o assembly
    """
}
```

**Nextflow가 이미 캐싱을 하고 있음!**

## 💡 진짜 문제와 해결책

### 문제 1: 스토리지 I/O 병목
```
실제 병목:
├── NAS 읽기: 40MB/s (느림)
├── Local SSD: 500MB/s (빠름)
└── 메모리: 10GB/s (매우 빠름)

해결책:
- Input을 처음부터 Local에 저장
- NAS는 백업/아카이브만
```

### 문제 2: 반복 실행 시
```
시나리오: 파라미터 튜닝으로 5번 재실행

[DB on NAS]
5회 × 30분 로딩 = 150분 낭비

[DB on Local]
1회 복사 30분 + 5회 즉시 = 30분

차이: 120분 절약 ✅
```

### 문제 3: 동시 실행
```
3개 프로젝트 동시 실행 시:

[NAS 직접]
- 대역폭 공유: 40MB/s ÷ 3 = 13MB/s
- 각 프로젝트 3배 느려짐

[Local 캐싱]
- 독립적 I/O
- 성능 영향 없음
```

## 🎯 현실적 전략

### ✅ 캐싱이 의미 있는 경우
1. **반복 사용 DB**: Kraken2, BLAST (여러 번 사용)
2. **작은 참조 파일**: <10GB (복사 빠름)
3. **동시 접근**: 여러 프로젝트가 같은 DB 사용

### ❌ 캐싱이 무의미한 경우
1. **Input FASTQ**: 1회성, 프로젝트별 고유
2. **임시 파일**: Nextflow work 디렉토리
3. **최종 결과**: 생성 후 이동만

## 📊 구체적 수치 비교

| 데이터 유형 | 크기 | 사용 빈도 | 캐싱 효과 | 권장 |
|------------|------|-----------|-----------|------|
| Kraken2 DB | 100GB | 매일 | 높음 | Local 필수 |
| GTDB-Tk | 70GB | 주 2-3회 | 중간 | 선택적 |
| BUSCO | 10GB | 주 1회 | 낮음 | NAS 가능 |
| Input FASTQ | 100GB/샘플 | 1회 | 없음 | 캐싱 불필요 |
| 중간 결과 | 50-200GB | 1회 | 없음 | Local 직접 |

## 🚀 실용적 접근

### 1. DB 배치 전략
```bash
# 필수 Local (자주 사용 + 랜덤 액세스)
/data/local/
├── kraken2/     # 100GB, 매일 사용
├── blast_nt/    # 200GB, 랜덤 액세스
└── current_project_db/

# NAS 가능 (가끔 사용 + 순차 읽기)
/mnt/NAS/
├── gtdbtk/      # 70GB, 주 2-3회
├── busco/       # 10GB, 가끔
└── reference_genomes/
```

### 2. Input 데이터 전략
```bash
# 옵션 A: 처음부터 Local에 저장 (최선)
wget -O /data/local/input/sample.fastq.gz http://...

# 옵션 B: NAS에서 직접 처리 (차선)
nextflow run --input /mnt/NAS/data/sample.fastq.gz

# 옵션 C: 캐싱 (불필요)
# 어차피 Nextflow가 work/에 복사함
```

### 3. 스크립트 예시
```bash
#!/bin/bash
# smart_run.sh - 데이터 위치별 최적 실행

INPUT=$1
DB_TYPE=$2

# DB는 사용 빈도에 따라 결정
if [[ "$DB_TYPE" == "kraken2" ]]; then
    DB_PATH="/data/local/kraken2"  # 항상 로컬
else
    DB_PATH="/mnt/NAS/dbs/$DB_TYPE"  # NAS 직접
fi

# Input은 크기와 위치 확인
INPUT_SIZE=$(du -b "$INPUT" | cut -f1)
if [[ $INPUT_SIZE -gt 50000000000 ]]; then  # 50GB 이상
    echo "Large input - using direct streaming"
    STREAMING="--stream"
fi

nextflow run pipeline.nf \
    --input "$INPUT" \
    --db "$DB_PATH" \
    $STREAMING \
    -resume
```

## 💰 비용-효과 정리

### 캐싱 구현 비용
- 개발 시간: 2-3일
- 복잡도 증가: 중간
- 유지보수: 지속 필요

### 실제 이득
- DB: 반복 사용 시 유효 (30-50% 시간 절약)
- Input: 거의 없음 (5-10% 차이)
- 전체: 제한적

## 🎯 최종 결론

### 현실적 답변
1. **DB 캐싱**: 자주 쓰는 것만 Local에 (Kraken2, BLAST)
2. **Input 캐싱**: 불필요 (Nextflow가 알아서 함)
3. **복잡한 캐싱 시스템**: 과도한 엔지니어링

### 진짜 해결책
```bash
# Simple is Best
1. 자주 쓰는 DB → Local SSD
2. 가끔 쓰는 DB → NAS 직접 사용
3. Input 데이터 → 처음부터 Local에 받기
4. 끝
```

**"캐싱 시스템"보다 "SSD 추가"가 정답**