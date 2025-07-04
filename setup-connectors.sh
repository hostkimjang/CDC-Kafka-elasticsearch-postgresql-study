#!/bin/bash
#
# ====================================================================================
#  PostgreSQL -> Debezium -> Kafka -> Elasticsearch CDC 파이프라인 설정 스크립트
# ====================================================================================
#
#  이 스크립트는 다음 작업을 수행합니다:
#  1. .env 파일 로드 (Windows CRLF 문제 자동 해결)
#  2. 모든 서비스 (PostgreSQL, Kafka Connect, Elasticsearch) 상태 확인
#  3. Debezium PostgreSQL 커넥터 등록
#  4. Elasticsearch 인덱스 매핑 생성
#  5. Elasticsearch Sink 커넥터 등록
#  6. 최종 상태 확인 및 요약 정보 출력
#
# ====================================================================================

set -e # 에러 발생 시 스크립트 중단

echo "==================== CDC 시스템 설정 시작 ===================="

# --- 1. 환경 변수 로드 ---
if [ ! -f .env ]; then
    echo "📄 .env 파일이 없어서 env.example을 복사합니다..."
    cp env.example .env
fi

if [ -f .env ]; then
    echo "📄 .env 파일에서 환경변수 로드 중..."
    # Windows CRLF(\r\n) 문제를 해결하기 위해 tr -d '\r' 사용
    export $(cat .env | tr -d '\r' | grep -v '^#' | grep -v '^$' | xargs)
else
    echo "⚠️  .env 파일을 찾을 수 없습니다. 스크립트를 종료합니다."
    exit 1
fi

# --- 2. 설정값 확인 ---
KAFKA_CONNECT_URL="http://localhost:${KAFKA_CONNECT_PORT:-6083}"
ES_CONNECT_URL="http://localhost:${ELASTICSEARCH_CONNECT_PORT:-6084}"
ES_URL="http://localhost:${ES_PORT:-6200}"

echo ""
echo "🔧 최종 설정값 확인:"
echo "  - PostgreSQL: localhost:${POSTGRES_PORT} (DB: ${POSTGRES_DB}, User: ${POSTGRES_USER})"
echo "  - Kafka Connect: ${KAFKA_CONNECT_URL}"
echo "  - Elasticsearch Connect: ${ES_CONNECT_URL}"
echo "  - Elasticsearch: ${ES_URL}"

# jq가 없으면 cat으로 대체
JQ_CMD=$(command -v jq &> /dev/null && echo "jq ." || echo "cat")

# --- 3. 서비스 상태 확인 ---
echo ""
echo "🔍 서비스 상태 확인 중... (최대 60초 대기)"

# PostgreSQL 확인
if ! docker exec postgres-db pg_isready -U "${POSTGRES_USER}" -q; then
    echo "❌ PostgreSQL이 준비되지 않았습니다. 스크립트를 종료합니다."
    exit 1
fi
echo "  - ✅ PostgreSQL 준비 완료"

# Kafka Connect, ES Connect, Elasticsearch 확인
for i in {1..12}; do
    KAFKA_CONNECT_OK=$(curl -s -o /dev/null -w "%{http_code}" "${KAFKA_CONNECT_URL}/connectors")
    ES_CONNECT_OK=$(curl -s -o /dev/null -w "%{http_code}" "${ES_CONNECT_URL}/connectors")
    ES_OK=$(curl -s -o /dev/null -w "%{http_code}" "${ES_URL}")
    
    if [ "$KAFKA_CONNECT_OK" -eq 200 ] && [ "$ES_CONNECT_OK" -eq 200 ] && [ "$ES_OK" -eq 200 ]; then
        break
    fi
    echo "  - 서비스 대기 중... (${i}/12)"
    sleep 5
done

if [ "$KAFKA_CONNECT_OK" -ne 200 ] || [ "$ES_CONNECT_OK" -ne 200 ] || [ "$ES_OK" -ne 200 ]; then
    echo "❌ 일부 서비스가 시간 내에 준비되지 않았습니다."
    echo "  - Kafka Connect Status: ${KAFKA_CONNECT_OK}"
    echo "  - ES Connect Status: ${ES_CONNECT_OK}"
    echo "  - Elasticsearch Status: ${ES_OK}"
    exit 1
fi
echo "  - ✅ Kafka Connect 준비 완료"
echo "  - ✅ Elasticsearch Connect 준비 완료"
echo "  - ✅ Elasticsearch 준비 완료"

# --- 4. Debezium 커넥터 등록 ---
echo ""
echo "📡 Debezium PostgreSQL 커넥터 등록..."
DEBEZIUM_CONFIG_FILE="connectors/debezium-postgres-connector.json"
if [ ! -f "$DEBEZIUM_CONFIG_FILE" ]; then
    echo "❌ ${DEBEZIUM_CONFIG_FILE}을 찾을 수 없습니다."
    exit 1
fi
curl -i -X POST -H "Accept:application/json" -H "Content-Type:application/json" \
    "${KAFKA_CONNECT_URL}/connectors/" -d "@${DEBEZIUM_CONFIG_FILE}"

# --- 5. Elasticsearch 인덱스 매핑 ---
echo ""
echo "📊 Elasticsearch 인덱스 매핑 생성..."
echo "  - Elasticsearch Sink 커넥터가 자동으로 인덱스를 생성합니다"

sleep 3

# --- 6. Elasticsearch Sink 커넥터 등록 ---
echo ""
echo "🔗 Elasticsearch Sink 커넥터 등록..."
ES_CONFIG_FILE="connectors/elasticsearch-connector.json"
if [ ! -f "$ES_CONFIG_FILE" ]; then
    echo "❌ ${ES_CONFIG_FILE}을 찾을 수 없습니다."
    exit 1
fi

curl -i -X POST -H "Accept:application/json" -H "Content-Type:application/json" \
    "${ES_CONNECT_URL}/connectors/" -d "@${ES_CONFIG_FILE}"

# --- 7. 최종 확인 ---
echo ""
echo "📊 ==================== 최종 상태 확인 ===================="
echo "  - Kafka Connect 커넥터:"
curl -s "${KAFKA_CONNECT_URL}/connectors" | ${JQ_CMD}
echo "  - Elasticsearch Connect 커넥터:"
curl -s "${ES_CONNECT_URL}/connectors" | ${JQ_CMD}
echo "  - Elasticsearch 인덱스:"
curl -s "${ES_URL}/_cat/indices?v"

echo ""
echo "🎉 ==================== CDC 시스템 설정 완료 ===================="
echo "  - Kafka UI: http://localhost:${KAFKA_UI_PORT:-6080}"
echo "  - Kibana: http://localhost:${KIBANA_PORT:-6601}"
echo ""
# echo "🧪 테스트 명령어:"
# echo "  docker exec postgres-db psql -U ${POSTG-RES_USER} -d ${POSTGRES_DB} -c \"INSERT INTO novels (title, author, platform, url, genre) VALUES ('테스트 소설', '테스트 작가', '테스트 플랫폼', 'http://test.com', '판타지');\"" 