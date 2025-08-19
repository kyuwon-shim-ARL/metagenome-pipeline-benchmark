# 기존 공용 DB 재구성 및 통합 전략

## 1. 현재 DB 구조 분석

### 현재 구조
```
/db/  (현재 공용 DB 위치)
├── annotations/          # 주석 데이터
│   └── Homo_sapiens/
├── genomes/             # 참조 게놈
│   ├── GCF_000013425.1/
│   ├── GCF_000756205.1/
│   ├── GCF_042193205.1/
│   ├── Homo_sapiens/
│   └── staphylococcus_aureus/
├── indices/             # 인덱스 파일
│   └── Homo_sapiens/
└── tool_specific_db/    # 도구별 DB
    └── busco/           # 현재 BUSCO만 있음
```

### 기존 구조의 장점
- ✅ 논리적 구조 (카테고리별 분류)
- ✅ 이미 구축된 게놈/주석 데이터
- ✅ 기존 프로젝트들이 사용 중

### 기존 구조의 단점
- ❌ 메타게놈 특화 도구들 (GTDB-Tk, Kraken2 등) 부족
- ❌ 버전 관리 구조 없음
- ❌ 도구별 표준화 부족

## 2. 통합 DB 구조 설계

### 제안하는 통합 구조
```
/data/shared/  (새로운 통합 DB 루트)
├── reference/           # 기존 데이터 통합
│   ├── genomes/         # 기존 genomes/ 이전
│   ├── annotations/     # 기존 annotations/ 이전
│   └── indices/         # 기존 indices/ 이전
│
├── metagenome/          # 메타게놈 특화 DB
│   ├── busco/
│   │   ├── v5_prokaryotes/
│   │   └── latest -> v5_prokaryotes/
│   ├── gtdbtk/
│   │   ├── r220/
│   │   └── latest -> r220/
│   ├── kraken2/
│   │   ├── standard_20240601/
│   │   └── latest -> standard_20240601/
│   └── checkm/
│       ├── v1.2.2/
│       └── latest -> v1.2.2/
│
├── specialized/         # 특화 분석용
│   ├── amr/            # 항생제 내성
│   │   ├── card/
│   │   ├── resfinder/
│   │   └── amrfinderplus/
│   ├── virulence/      # 독성 인자
│   └── plasmid/        # 플라스미드
│
└── registry.yaml       # 전체 DB 메타데이터
```

## 3. 권한 문제 해결 방안

### 문제점
- 현재 `/db/` 디렉토리에 쓰기 권한 없음
- 대용량 데이터 이동 시 시간과 권한 이슈
- 기존 사용자들에게 영향 최소화 필요

### 해결책 1: 관리자 협업 (권장)
```bash
# 관리자가 실행할 스크립트
#!/bin/bash
# admin_db_migration.sh

# 1. 새 공용 디렉토리 생성
sudo mkdir -p /data/shared
sudo chgrp -R researchers /data/shared  # 연구진 그룹
sudo chmod -R 775 /data/shared

# 2. 기존 DB 복사 (이동 대신)
sudo cp -r /db/* /data/shared/reference/

# 3. 메타게놈 DB 디렉토리 생성
sudo mkdir -p /data/shared/metagenome/{busco,gtdbtk,kraken2,checkm}
sudo mkdir -p /data/shared/specialized/{amr,virulence,plasmid}

# 4. 소유권 설정
sudo chown -R kyuwon:researchers /data/shared
```

### 해결책 2: 홈 디렉토리 활용 (임시)
```bash
# 홈 디렉토리에 구성 후 나중에 이전
TEMP_DB_ROOT="$HOME/shared_db"
mkdir -p $TEMP_DB_ROOT

# 기존 DB 링크
ln -s /db/* $TEMP_DB_ROOT/reference/

# 새 메타게놈 DB 구성
mkdir -p $TEMP_DB_ROOT/metagenome/{busco,gtdbtk,kraken2,checkm}
```

### 해결책 3: NFS 마운트 (확장성)
```bash
# NAS 스토리지 마운트
sudo mount nas-server:/shared/databases /data/shared
```

## 4. 점진적 마이그레이션 전략

### Phase 1: 현재 DB 유지하며 확장
```bash
# 기존 /db 구조 그대로 두고 메타게놈 추가
/db/
├── [기존 구조 유지]
└── tool_specific_db/
    ├── busco/           # 기존
    ├── gtdbtk/          # 추가
    ├── kraken2/         # 추가
    └── checkm/          # 추가
```

**장점**: 기존 시스템 무중단
**단점**: 완전한 표준화 미달성

### Phase 2: 심볼릭 링크 활용
```bash
# 새 구조 생성 후 호환성 링크
ln -s /data/shared/reference/genomes /db/genomes
ln -s /data/shared/metagenome/busco /db/tool_specific_db/busco
```

### Phase 3: 완전 이전
```bash
# 모든 사용자가 새 구조 적응 후 완전 이전
```

## 5. 실무 적용 방안

### 즉시 실행 가능한 방법 (권한 없을 때)
```bash
# 1. 개인 DB 구조 생성
USER_DB_ROOT="$HOME/.metagenome_db"
mkdir -p $USER_DB_ROOT/{reference,metagenome,specialized}

# 2. 기존 DB 링크 (읽기 전용)
ln -s /db/genomes $USER_DB_ROOT/reference/genomes
ln -s /db/annotations $USER_DB_ROOT/reference/annotations
ln -s /db/indices $USER_DB_ROOT/reference/indices
ln -s /db/tool_specific_db/busco $USER_DB_ROOT/metagenome/busco

# 3. 환경 변수 설정
export METAGENOME_DB_ROOT="$USER_DB_ROOT"
export REFERENCE_DB_ROOT="$USER_DB_ROOT/reference"
```

### 환경 변수 통합 설정
```bash
# ~/.metagenome_db_env
# 통합 DB 환경 설정

# DB 루트 경로 (상황에 따라 변경)
if [ -d "/data/shared" ]; then
    export DB_ROOT="/data/shared"
elif [ -d "/db" ]; then
    export DB_ROOT="/db"  # 기존 구조
else
    export DB_ROOT="$HOME/.metagenome_db"  # 개인 구조
fi

# 레퍼런스 DB (기존)
export REFERENCE_GENOMES="$DB_ROOT/reference/genomes"
export REFERENCE_ANNOTATIONS="$DB_ROOT/reference/annotations"
export REFERENCE_INDICES="$DB_ROOT/reference/indices"

# 메타게놈 DB (새로 추가)
export METAGENOME_DB_ROOT="$DB_ROOT/metagenome"
export BUSCO_DB="$METAGENOME_DB_ROOT/busco/latest"
export GTDBTK_DB="$METAGENOME_DB_ROOT/gtdbtk/latest"
export KRAKEN2_DB="$METAGENOME_DB_ROOT/kraken2/latest"
export CHECKM_DB="$METAGENOME_DB_ROOT/checkm/latest"

# 특화 DB
export AMR_DB_ROOT="$DB_ROOT/specialized/amr"
export CARD_DB="$AMR_DB_ROOT/card"
export RESFINDER_DB="$AMR_DB_ROOT/resfinder"
```

## 6. Nextflow 설정 업데이트

### 유연한 설정 구조
```groovy
// configs/databases.config
params {
    // DB 루트 자동 감지
    db_root = System.getenv('DB_ROOT') ?: 
              (file('/data/shared').exists() ? '/data/shared' :
               file('/db').exists() ? '/db' : 
               "${System.properties['user.home']}/.metagenome_db")
    
    // 레퍼런스 DB (기존 구조 호환)
    reference_genomes = System.getenv('REFERENCE_GENOMES') ?: "${params.db_root}/reference/genomes"
    reference_annotations = System.getenv('REFERENCE_ANNOTATIONS') ?: "${params.db_root}/reference/annotations"
    
    // 메타게놈 DB (신규 구조)
    busco_db = System.getenv('BUSCO_DB') ?: "${params.db_root}/metagenome/busco/latest"
    gtdbtk_db = System.getenv('GTDBTK_DB') ?: "${params.db_root}/metagenome/gtdbtk/latest"
    kraken2_db = System.getenv('KRAKEN2_DB') ?: "${params.db_root}/metagenome/kraken2/latest"
    
    // 하위 호환성 (기존 tool_specific_db 구조)
    busco_db_fallback = "${params.db_root}/tool_specific_db/busco/v5"
}

// DB 존재 여부 확인 및 폴백
process CHECK_DATABASES {
    script:
    """
    # 메인 DB 경로 확인
    if [ -d "${params.busco_db}" ]; then
        echo "Using new structure: ${params.busco_db}"
    elif [ -d "${params.busco_db_fallback}" ]; then
        echo "Using legacy structure: ${params.busco_db_fallback}"
        export BUSCO_DB="${params.busco_db_fallback}"
    else
        echo "ERROR: BUSCO DB not found"
        exit 1
    fi
    """
}
```

## 7. 마이그레이션 스크립트 (권한 고려)

### 사용자용 스크립트
```bash
#!/bin/bash
# user_db_setup.sh - 권한 없을 때 사용

set -e

USER_DB="$HOME/.metagenome_db"
echo "Setting up personal metagenome DB at $USER_DB"

# 1. 개인 DB 구조 생성
mkdir -p $USER_DB/{reference,metagenome,specialized}
mkdir -p $USER_DB/metagenome/{busco,gtdbtk,kraken2,checkm}
mkdir -p $USER_DB/specialized/{amr,virulence,plasmid}

# 2. 기존 DB 링크 (가능한 것만)
if [ -d "/db/genomes" ]; then
    ln -sfn /db/genomes $USER_DB/reference/genomes
    echo "✓ Linked reference genomes"
fi

if [ -d "/db/annotations" ]; then
    ln -sfn /db/annotations $USER_DB/reference/annotations
    echo "✓ Linked annotations"
fi

if [ -d "/db/tool_specific_db/busco" ]; then
    ln -sfn /db/tool_specific_db/busco $USER_DB/metagenome/busco
    echo "✓ Linked BUSCO DB"
fi

# 3. 환경 설정 파일 생성
cat > ~/.metagenome_db_env << EOF
# Personal Metagenome DB Configuration
export DB_ROOT="$USER_DB"
export METAGENOME_DB_ROOT="$USER_DB/metagenome"
export REFERENCE_DB_ROOT="$USER_DB/reference"

# 메타게놈 도구 DB
export BUSCO_DB="\$METAGENOME_DB_ROOT/busco"
export GTDBTK_DB="\$METAGENOME_DB_ROOT/gtdbtk/latest"
export KRAKEN2_DB="\$METAGENOME_DB_ROOT/kraken2/latest"

# 상태 체크 함수
check_db_status() {
    echo "Metagenome DB Status:"
    echo "  Root: \$DB_ROOT"
    [ -L "\$REFERENCE_DB_ROOT/genomes" ] && echo "  ✓ Reference genomes linked" || echo "  ○ Reference genomes not available"
    [ -L "\$METAGENOME_DB_ROOT/busco" ] && echo "  ✓ BUSCO linked" || echo "  ○ BUSCO not available"
    [ -d "\$GTDBTK_DB" ] && echo "  ✓ GTDB-Tk available" || echo "  ○ GTDB-Tk not available"
}
EOF

# 4. bashrc에 추가
if ! grep -q "metagenome_db_env" ~/.bashrc; then
    echo "" >> ~/.bashrc
    echo "# Metagenome DB Environment" >> ~/.bashrc
    echo "source ~/.metagenome_db_env" >> ~/.bashrc
fi

echo "✅ Personal DB setup completed!"
echo "Run 'source ~/.bashrc' or 'source ~/.metagenome_db_env' to activate"
echo "Check status with: check_db_status"
```

### 관리자용 스크립트 (나중에 관리자가 실행)
```bash
#!/bin/bash
# admin_full_migration.sh - 관리자 권한 필요

# 1. 공용 디렉토리 생성
sudo mkdir -p /data/shared/{reference,metagenome,specialized}

# 2. 기존 DB 이전
sudo mv /db/genomes /data/shared/reference/
sudo mv /db/annotations /data/shared/reference/
sudo mv /db/indices /data/shared/reference/

# 3. tool_specific_db 재구성
sudo mv /db/tool_specific_db/busco /data/shared/metagenome/

# 4. 권한 설정
sudo chown -R kyuwon:researchers /data/shared
sudo chmod -R 775 /data/shared

# 5. 하위 호환성 링크
sudo ln -s /data/shared/reference/genomes /db/genomes
sudo ln -s /data/shared/reference/annotations /db/annotations
```

## 8. 즉시 실행 계획

### 현재 상황에서 할 수 있는 것
1. **개인 DB 구조 구축** (권한 불필요)
2. **기존 DB 읽기 전용 링크** (심볼릭 링크)
3. **벤치마크 도구 개발** (새 구조 대응)
4. **관리자와 협의** (공용 구조 이전)

### 실행 순서
```bash
# 1. 개인 DB 구조 생성
bash user_db_setup.sh

# 2. 환경 로드
source ~/.bashrc

# 3. 상태 확인
check_db_status

# 4. 벤치마크 도구 테스트
cd ~/metagenome-pipeline-benchmark
python -c "import os; print('DB Root:', os.getenv('DB_ROOT'))"
```

## 9. 권장사항

### 단기 (즉시 가능)
- ✅ 개인 DB 구조로 프로토타입 구축
- ✅ 기존 DB 심볼릭 링크 활용
- ✅ 벤치마크 도구 개발 진행

### 중기 (관리자 협의 후)
- ⏳ `/data/shared` 공용 구조 생성
- ⏳ 점진적 데이터 이전
- ⏳ 팀 전체 표준화

### 장기 (완전 통합)
- ⏳ 기존 `/db` 구조 단계적 폐기
- ⏳ 모든 프로젝트 신규 구조 적용

## 결론

현재 권한 없는 상황에서도 개인 DB 구조를 만들어 즉시 시작할 수 있습니다. 이후 관리자와 협의하여 점진적으로 전체 시스템을 통합하는 것이 현실적입니다.