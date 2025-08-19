# 벤치마크 시스템 정리 계획 - 옵션A (최소 유지)

## 🎯 목표
복잡한 벤치마크 시스템을 정리하고 실용적인 최소 구성만 유지

## 📋 정리 대상

### ✅ 유지할 것 (Keep)
```
유지 이유: 실제 가치가 있고 사용 중
├── /data/shared/metagenome-db/     # 공용 DB 구조
├── ~/.metagenome_db_env            # DB 경로 설정 (수동 실행)
├── quick_benchmark.sh              # 실용적 벤치마크 스크립트
├── docs/CURRENT/                   # 현실 체크 문서들
└── 공용 DB 심볼릭 링크들            # 실제 작동 중
```

### ❌ 제거할 것 (Remove)
```
제거 이유: 복잡성만 증가, 실제 사용 안함
├── src/                           # Python SDK 모듈들
├── pipelines/modules/             # 복잡한 래퍼들  
├── configs/pipeline_registry.yml  # 과도한 설정
├── workflows/main.nf              # 사용하지 않는 워크플로우
├── bashrc 자동 로딩               # 매번 메시지 출력 불필요
└── 복잡한 통합 스크립트들          # 과도한 엔지니어링
```

### 🔄 단순화할 것 (Simplify)
```
변경 이유: 기능은 유지하되 복잡성 제거
├── .metagenome_db_env    # 자동→수동 실행으로 변경
├── CLAUDE.md            # 복잡한 SDK 설명→간단한 사용법
└── README.md            # 과도한 아키텍처→실용적 가이드
```

## 🚀 실행 단계

### Step 1: bashrc 정리
```bash
# ~/.bashrc에서 제거
# [ -f ~/.metagenome_db_env ] && source ~/.metagenome_db_env
```

### Step 2: 복잡한 모듈 제거
```bash
# 사용하지 않는 복잡한 구조 제거
rm -rf src/
rm -rf pipelines/modules/
rm -rf workflows/
rm configs/pipeline_registry.yml
```

### Step 3: 문서 단순화
- CLAUDE.md → 간단한 사용법만
- README.md → 실용적 가이드로

### Step 4: 검증
- 공용 DB 접근 확인
- quick_benchmark.sh 실행 테스트

## 📊 예상 효과

### Before (복잡함)
```
30+ 파일, 복잡한 구조
매번 환경 변수 로딩 메시지
사용하지 않는 모듈들
과도한 추상화
```

### After (단순함)  
```
5-10개 핵심 파일만
필요할 때만 수동 실행
실제 사용하는 것만 유지
직접적이고 명확함
```

## ✅ 성공 기준
1. bashrc 정리 완료
2. 불필요한 파일 제거 완료  
3. 공용 DB 정상 접근 가능
4. quick_benchmark.sh 정상 실행
5. 문서 간소화 완료