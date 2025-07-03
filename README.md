# 📚 Novel Platform CDC 파이프라인 스터디

> **개인 스터디 및 연구 목적**으로 제작된 CDC(Change Data Capture) 파이프라인 구현 프로젝트입니다.

## 🎯 학습 목표

이 프로젝트는 다음과 같은 기술들을 학습하고 실습하기 위해 만들어졌습니다:

- **CDC(Change Data Capture)** 개념과 실제 구현
- **Debezium**을 활용한 데이터베이스 변경 추적
- **Apache Kafka** 기반 실시간 데이터 스트리밍
- **Elasticsearch**를 통한 검색 시스템 구축
- **Docker Compose**를 활용한 마이크로서비스 오케스트레이션
- **데이터 파이프라인** 설계 및 구축

## 🏗️ 시스템 아키텍처

```
PostgreSQL → Debezium → Kafka → Elasticsearch
     ↓           ↓         ↓         ↓
  소설 데이터   CDC 감지  실시간 스트림  검색 인덱스
```

**실제 구현된 데이터 플로우:**
1. PostgreSQL `novels` 테이블에 소설 데이터 저장
2. Debezium이 PostgreSQL WAL(Write-Ahead Logging) 모니터링
3. 데이터 변경사항을 Kafka 토픽 `novel-platform-novels`로 전송
4. Elasticsearch Sink Connector가 Kafka에서 데이터를 읽어 Elasticsearch로 동기화
5. Kibana를 통해 실시간 데이터 시각화

## 📦 기술 스택

| 구분 | 기술 | 버전 | 역할 |
|------|------|------|------|
| **Database** | PostgreSQL | 15 | 메인 데이터 저장소 |
| **CDC** | Debezium | 2.4 | 데이터베이스 변경 감지 |
| **Message Broker** | Apache Kafka | 7.5.0 | 실시간 데이터 스트리밍 |
| **Coordination** | Zookeeper | 7.5.0 | Kafka 클러스터 관리 |
| **Search Engine** | Elasticsearch | 8.11.0 | 검색 및 분석 |
| **Visualization** | Kibana | 8.11.0 | 데이터 시각화 |
| **Monitoring** | Kafka UI | latest | Kafka 클러스터 모니터링 |

## 🚀 프로젝트 실행 가이드

### 1️⃣ 사전 준비
```bash
# 레포지토리 클론
git clone <repository-url>
cd novel-platform-cdc

# 환경 변수 설정
cp env.example .env
```

### 2️⃣ 🎯 원클릭 실행 (자동화 완료!)
```bash
# 모든 서비스 시작 + 커넥터 자동 설정
docker-compose up -d

# 서비스 상태 확인
docker-compose ps
```

> **✨ 새로운 기능**: 이제 CDC 커넥터가 **자동으로 설정**됩니다! 
> - Debezium PostgreSQL 커넥터 자동 등록
> - Elasticsearch 싱크 커넥터 자동 등록  
> - 서비스 의존성 자동 관리 (헬스체크 기반)

### 3️⃣ 설정 상태 확인
```bash
# 커넥터 상태 확인
curl -s http://localhost:6083/connectors | jq

# 또는 Kafka UI에서 확인
# http://localhost:6080 접속
```

### 4️⃣ 테스트 데이터 삽입
```bash
# 테스트용 소설 10개 자동 삽입
bash test-insert-novels.sh
```

## 🔄 이전 방식 (수동 설정)

기존의 수동 설정이 필요한 경우:
```bash
# 커넥터 수동 설정 (선택사항)
bash setup-connectors.sh
```

## 🌐 접속 정보

| 서비스 | URL | 용도 |
|--------|-----|------|
| **Kafka UI** | http://localhost:6080 | Kafka 토픽 및 메시지 모니터링 |
| **Kibana** | http://localhost:6601 | Elasticsearch 데이터 시각화 |
| **Elasticsearch** | http://localhost:6200 | 검색 API 및 인덱스 관리 |

## 📊 데이터베이스 스키마

### novels 테이블 (메인 테이블)
```sql
CREATE TABLE novels (
    id SERIAL PRIMARY KEY,
    title VARCHAR(500) NOT NULL,           -- 소설 제목
    author VARCHAR(200) NOT NULL,          -- 작가명
    platform VARCHAR(100) NOT NULL,       -- 플랫폼 (네이버시리즈, 카카오페이지 등)
    url TEXT NOT NULL,                     -- 원본 URL
    description TEXT,                      -- 소설 설명
    genre VARCHAR(100),                    -- 장르
    status VARCHAR(50),                    -- 연재 상태 (연재중, 완결, 휴재)
    total_chapters INTEGER DEFAULT 0,     -- 총 화수
    view_count INTEGER DEFAULT 0,         -- 조회수
    like_count INTEGER DEFAULT 0,         -- 좋아요 수
    rating DECIMAL(3,2),                  -- 평점
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

## 🧪 실습 가이드

### Step 1: 데이터 삽입 테스트
```bash
# 개별 소설 삽입
docker exec postgres-db psql -U postgres -d novel_platform -c "
INSERT INTO novels (title, author, platform, url, genre, status) 
VALUES ('새로운 소설', '김작가', '킴장플랫폼', 'https://example.com', '판타지', '연재중');
"
```

### Step 2: CDC 파이프라인 확인
```bash
# Kafka 토픽에서 변경사항 실시간 확인
docker exec kafka-broker kafka-console-consumer \
  --bootstrap-server localhost:6092 \
  --topic novel-platform-novels \
  --from-beginning
```

### Step 3: Elasticsearch 동기화 확인
```bash
# Elasticsearch에서 데이터 조회
curl -s "http://localhost:6200/novel-platform-novels/_search?pretty" | jq '.hits.total.value'
```

### Step 4: 데이터 업데이트 테스트
```bash
# 조회수 업데이트
docker exec postgres-db psql -U postgres -d novel_platform -c "
UPDATE novels SET view_count = view_count + 100 WHERE id = 1;
"
```

## 🔧 트러블슈팅 가이드

### 자주 발생하는 문제들

#### 1. Windows CRLF 문제
```bash
# .env 파일의 줄바꿈 문자 제거
tr -d '\r' < .env > .env.tmp && mv .env.tmp .env
```

#### 2. Kafka Connect 커넥터 상태 확인
```bash
# 모든 커넥터 상태 조회
curl -s http://localhost:6083/connectors | jq

# 특정 커넥터 상태 확인
curl -s http://localhost:6083/connectors/debezium-postgres-connector/status | jq
curl -s http://localhost:6083/connectors/elasticsearch-sink-connector/status | jq
```

#### 3. 커넥터 재시작
```bash
# Debezium 커넥터 재시작
curl -X POST http://localhost:6083/connectors/debezium-postgres-connector/restart

# Elasticsearch 커넥터 재시작
curl -X POST http://localhost:6083/connectors/elasticsearch-sink-connector/restart
```

## 📁 프로젝트 구조

```
novel-platform-cdc/
├── docker-compose.yml              # 전체 시스템 구성
├── .env                           # 환경 변수 설정
├── connectors/                    # Kafka Connect 커넥터 설정
│   ├── debezium-postgres-connector.json
│   └── elasticsearch-connector.json
├── init-scripts/                 # 데이터베이스 초기화 스크립트
│   └── 01-init-database.sql
├── setup-connectors.sh           # 커넥터 자동 설정 스크립트
├── test-insert-novels.sh         # 테스트 데이터 삽입 스크립트
└── README.md                     # 프로젝트 문서
```

## 🎓 학습 포인트

### 이 프로젝트를 통해 배울 수 있는 것들:

1. **CDC 개념**: 데이터베이스 변경사항을 실시간으로 감지하고 전파하는 방법
2. **Debezium 활용**: PostgreSQL WAL을 모니터링하여 변경사항을 Kafka로 스트리밍
3. **Kafka 생태계**: Kafka Connect, 토픽, 컨슈머/프로듀서 패턴
4. **Elasticsearch 통합**: 검색 시스템 구축과 실시간 인덱싱
5. **Docker 오케스트레이션**: 복잡한 마이크로서비스 환경 관리
6. **데이터 파이프라인**: 실시간 데이터 처리 아키텍처 설계

## 📚 참고 자료

- [Debezium Documentation](https://debezium.io/documentation/)
- [Apache Kafka Documentation](https://kafka.apache.org/documentation/)
- [Elasticsearch Guide](https://www.elastic.co/guide/en/elasticsearch/reference/current/index.html)
- [Docker Compose Reference](https://docs.docker.com/compose/)

## 🏷️ 태그

`#CDC` `#Debezium` `#Kafka` `#Elasticsearch` `#Docker` `#PostgreSQL` `#DataPipeline` `#RealTimeProcessing` `#StudyProject`

---

> **Note**: 이 프로젝트는 개인 학습 및 연구 목적으로 제작되었습니다. 프로덕션 환경에서 사용하기 전에 보안 설정과 성능 최적화를 반드시 검토하세요.