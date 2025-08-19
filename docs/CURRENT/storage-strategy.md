# 스토리지 전략 분석 - 공용 DB vs Local SSD

## 📊 현황 분석

### 현재 스토리지 구성
1. **Local SSD**: 2.6TB PERC H755 (RAID Controller)
   - 현재 사용: 23GB / 421GB (6%)
   - 타입: SSD (ROTA=0)
   - 위치: `/data/shared` (로컬)

2. **NAS**: `/mnt/NAS` (SSHFS mount)
   - 네트워크 마운트 (192.168.100.10)
   - 프로토콜: SSHFS (SSH File System)

## 🔍 핵심 질문 분석

### Q1: 공용 DB 구조는 여전히 유효한가?
**답: 예, 유효합니다.**

#### 이유:
1. **중복 제거**: 프로젝트마다 같은 DB 반복 다운로드 방지
2. **버전 일관성**: 모든 프로젝트가 동일 DB 버전 사용
3. **관리 효율성**: 한 곳에서 업데이트, 모든 프로젝트 적용
4. **스토리지 절약**: BUSCO(10GB), GTDB-Tk(70GB), Kraken2(100GB) 등 한 번만 저장

### Q2: NAS를 공용 DB로 사용하면 느려서 못 쓰는가?
**답: 부분적으로 맞습니다.**

#### 성능 비교:
| 작업 유형 | Local SSD | NAS (SSHFS) | 영향도 |
|----------|-----------|-------------|--------|
| 순차 읽기 | 500MB/s | 10-50MB/s | 중간 |
| 랜덤 읽기 | 높음 | 매우 낮음 | 심각 |
| 레이턴시 | <1ms | 10-100ms | 심각 |
| 대용량 파일 | 양호 | 허용 가능 | 낮음 |
| 작은 파일 많이 | 양호 | 매우 느림 | 심각 |

#### 특히 문제가 되는 DB:
- **Kraken2**: 수백만 개 작은 파일, 랜덤 액세스 → NAS 사용 불가
- **BLAST indices**: 빈번한 랜덤 읽기 → 성능 저하 심각
- **GTDB-Tk**: 대용량 인덱스 파일 → 초기 로딩 매우 느림

### Q3: 결국 Local SSD 용량을 늘려야 하나?
**답: 하이브리드 전략이 최적입니다.**

## 🎯 권장 스토리지 전략

### 1. 계층적 스토리지 구조

```
최적 배치:
├── Local SSD (빠른 액세스 필요)
│   ├── 작업 디렉토리 (work/)
│   ├── 임시 파일 (temp/)
│   ├── 자주 사용하는 DB
│   │   ├── Kraken2 (랜덤 액세스)
│   │   ├── BLAST indices
│   │   └── 현재 프로젝트 DB
│   └── Input 데이터 (분석 중)
│
├── Local HDD (중간 속도)
│   ├── 덜 자주 사용하는 DB
│   ├── 완료된 결과 (아카이브)
│   └── 백업
│
└── NAS (장기 보관, 공유)
    ├── 원본 시퀀싱 데이터
    ├── 참조 게놈 (순차 읽기)
    ├── 최종 결과 공유
    └── 드물게 사용하는 DB
```

### 2. 실용적 구현 방법

#### Phase 1: 즉시 적용 (현재 상황 최적화)
```bash
# 핵심 DB는 Local SSD에
/data/shared/metagenome-db/
├── kraken2/        # 필수: Local SSD
├── blast_indices/  # 필수: Local SSD
└── current_project_db/  # 활성 프로젝트용

# 대용량 순차 읽기 DB는 NAS 가능
/mnt/NAS/shared-db/
├── reference_genomes/  # 순차 읽기 위주
├── gtdbtk/            # 초기 로딩만 느림
└── archived_results/
```

#### Phase 2: 캐싱 전략
```bash
#!/bin/bash
# smart_cache.sh - 필요시 NAS→Local 복사

DB_NAME=$1
NAS_PATH="/mnt/NAS/shared-db/$DB_NAME"
LOCAL_CACHE="/data/shared/cache/$DB_NAME"

if [ ! -d "$LOCAL_CACHE" ]; then
    echo "Caching $DB_NAME to local SSD..."
    rsync -av --progress "$NAS_PATH/" "$LOCAL_CACHE/"
fi

# 심볼릭 링크 업데이트
ln -sfn "$LOCAL_CACHE" "/data/shared/metagenome-db/$DB_NAME"
```

#### Phase 3: 동적 관리
```python
# db_manager.py - 사용 빈도 기반 자동 관리

import os
import time
from pathlib import Path

class DBManager:
    def __init__(self):
        self.local_ssd = Path("/data/shared/metagenome-db")
        self.nas = Path("/mnt/NAS/shared-db")
        self.cache_size_limit = 500_000_000_000  # 500GB
    
    def get_db_path(self, db_name, performance_critical=False):
        """DB 위치 결정"""
        if performance_critical or db_name in ['kraken2', 'blast']:
            return self.ensure_local(db_name)
        else:
            return self.nas / db_name
    
    def ensure_local(self, db_name):
        """필요시 로컬로 복사"""
        local_path = self.local_ssd / db_name
        if not local_path.exists():
            self.cache_to_local(db_name)
        return local_path
```

### 3. 용량 계획

#### 최소 요구사항 (Local SSD)
```
필수 DB (상시 로컬):
- Kraken2 standard: 100GB
- BLAST nt: 200GB
- 작업 공간: 200GB
- 캐시: 100GB
─────────────────────
최소: 600GB

권장: 1TB (여유 공간 포함)
현재: 421GB 중 399GB 가용 → 부족
```

#### 확장 옵션
1. **SSD 추가**: 1-2TB NVMe 추가 (최적)
2. **선택적 캐싱**: 프로젝트별 필요 DB만 로컬
3. **압축 활용**: DB 압축 저장, 사용시 압축 해제

## 💡 최종 권장사항

### DO's ✅
1. **공용 DB 구조 유지**: 중복 제거, 버전 관리 이점
2. **하이브리드 스토리지**: 성능 요구사항별 배치
3. **캐싱 전략**: 자주 쓰는 것만 Local SSD
4. **모니터링**: 사용 패턴 분석 후 최적화

### DON'Ts ❌
1. **모든 DB를 NAS에**: 성능 저하 심각
2. **모든 DB를 Local에**: 용량 낭비
3. **수동 관리만**: 자동화 필요

### 즉시 실행 계획
```bash
# 1. 현재 Local SSD 활용 최대화
cd /data/shared/metagenome-db
mkdir -p cache work temp

# 2. 성능 중요 DB 로컬 유지
# Kraken2, BLAST는 반드시 로컬

# 3. NAS는 아카이브/백업용
# 완료된 프로젝트, 원본 데이터

# 4. 필요시 SSD 증설 검토
# 1TB NVMe 추가 권장
```

## 📈 비용-효과 분석

| 옵션 | 비용 | 성능 | 권장도 |
|------|------|------|--------|
| 현상 유지 | $0 | 낮음 | ❌ |
| SSD 1TB 추가 | ~$100 | 높음 | ✅ |
| 모든 DB NAS | $0 | 매우 낮음 | ❌ |
| 클라우드 스토리지 | $$$/월 | 중간 | △ |

**결론: Local SSD 1TB 추가가 가장 현실적**