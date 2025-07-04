#!/bin/sh
# ====================================================================================
# CDC 커넥터 자동 설정 스크립트 (Docker 컨테이너용)
# ====================================================================================

set -e  # 에러 발생 시 스크립트 중단

echo "🤖 CDC 커넥터 자동 설정 시작..."
echo "📅 시작 시간: $(date)"

# 환경 변수 설정
KAFKA_CONNECT_URL="${KAFKA_CONNECT_URL:-http://kafka-connect:8083}"
ELASTICSEARCH_URL="${ELASTICSEARCH_URL:-http://elasticsearch:9200}"

# 함수 정의: 서비스 준비 상태 확인
wait_for_service() {
  local service_name="$1"
  local url="$2"
  local max_attempts=30
  local attempt=1
  
  echo "⏳ $service_name 서비스 준비 대기..."
  while [ $attempt -le $max_attempts ]; do
    if curl -s -f "$url" > /dev/null 2>&1; then
      echo "   ✅ $service_name 준비 완료 (시도: $attempt/$max_attempts)"
      return 0
    fi
    echo "   🔄 $service_name 연결 시도 중... ($attempt/$max_attempts)"
    sleep 5
    attempt=$((attempt + 1))
  done
  
  echo "   ❌ $service_name 서비스 준비 실패 (최대 시도 횟수 초과)"
  return 1
}

# 커넥터 등록 함수
register_connector() {
  local connector_name="$1"
  local config_file="$2"
  local max_attempts=3
  local attempt=1
  
  echo "📡 $connector_name 커넥터 등록 중..."
  while [ $attempt -le $max_attempts ]; do
    response=$(curl -s -w "HTTPSTATUS:%{http_code}" \
                   -X POST \
                   -H "Content-Type: application/json" \
                   "$KAFKA_CONNECT_URL/connectors/" \
                   -d @"$config_file")
    
    http_code=$(echo "$response" | grep -o "HTTPSTATUS:[0-9]*" | cut -d: -f2)
    
    if [ "$http_code" = "201" ] || [ "$http_code" = "200" ]; then
      echo "   ✅ $connector_name 등록 성공 (HTTP: $http_code)"
      return 0
    else
      echo "   🔄 $connector_name 등록 재시도... (시도: $attempt/$max_attempts, HTTP: $http_code)"
      if [ $attempt -eq $max_attempts ]; then
        echo "   📝 응답 내용: $(echo "$response" | sed 's/HTTPSTATUS:[0-9]*//')"
      fi
    fi
    
    sleep 3
    attempt=$((attempt + 1))
  done
  
  echo "   ❌ $connector_name 등록 실패"
  return 1
}

# 커넥터 삭제 함수
delete_connector() {
  local connector_name="$1"
  echo "   🗑️  기존 $connector_name 커넥터 삭제 중..."
  curl -s -X DELETE "$KAFKA_CONNECT_URL/connectors/$connector_name" || true
}

# 1. 서비스 준비 상태 최종 확인
wait_for_service "Kafka Connect" "$KAFKA_CONNECT_URL/connectors"
wait_for_service "Elasticsearch" "$ELASTICSEARCH_URL/_cluster/health"

# 2. 기존 커넥터 확인 및 정리
echo "🔍 기존 커넥터 상태 확인..."
existing_connectors=$(curl -s "$KAFKA_CONNECT_URL/connectors" 2>/dev/null || echo "[]")

# 기존 커넥터들 삭제
for connector in postgres-connector elasticsearch-sink-connector elasticsearch-ex-platform-connector elasticsearch-history-connector; do
  if echo "$existing_connectors" | grep -q "$connector"; then
    delete_connector "$connector"
  fi
done

# 잠시 대기 (커넥터 정리 완료까지)
echo "⏳ 커넥터 정리 완료 대기..."
sleep 5

# 3. 새로운 커넥터 등록
echo "📡 핵심 CDC 커넥터 등록..."
if ! register_connector "Debezium PostgreSQL" "/connectors/debezium-postgres-connector.json"; then
  echo "❌ Debezium 커넥터 등록 실패"
  exit 1
fi

echo "🔗 Elasticsearch 싱크 커넥터들 등록..."
if ! register_connector "Elasticsearch Main (novels)" "/connectors/elasticsearch-connector.json"; then
  echo "❌ 메인 Elasticsearch 커넥터 등록 실패"
  exit 1
fi

if ! register_connector "Elasticsearch Platform Novels" "/connectors/elasticsearch-ex-platform-connector.json"; then
  echo "❌ Platform Novels 커넥터 등록 실패"
  exit 1
fi

if ! register_connector "Elasticsearch Change History" "/connectors/elasticsearch-history-connector.json"; then
  echo "❌ Change History 커넥터 등록 실패"
  exit 1
fi

# 4. 등록 결과 확인
echo "📊 최종 커넥터 상태 확인:"
sleep 3
curl -s "$KAFKA_CONNECT_URL/connectors" | sed 's/,/,\n  /g' | sed 's/\[/[\n  /' | sed 's/\]/\n]/' || echo "커넥터 목록 조회 실패"

# 5. 커넥터 상태 확인
echo "🔍 커넥터 상태 점검:"
for connector in postgres-connector elasticsearch-sink-connector elasticsearch-ex-platform-connector elasticsearch-history-connector; do
  status=$(curl -s "$KAFKA_CONNECT_URL/connectors/$connector/status" 2>/dev/null | grep -o '"state":"[^"]*"' | cut -d'"' -f4 || echo "UNKNOWN")
  echo "   - $connector: $status"
done

echo "📅 완료 시간: $(date)"
echo "🎉 CDC 파이프라인 자동 설정 완료!"
echo "📺 모니터링 URL:"
echo "   - Kafka UI: http://localhost:6080"
echo "   - Kibana: http://localhost:6601"
echo ""
echo "📊 생성되는 Elasticsearch 인덱스:"
echo "   - novel-platform-novels: 메인 소설 데이터"
echo "   - ex-platform-novel: 크롤링 플랫폼 소설 최신 상태"
echo "   - ex-platform-novel-history-YYYY-MM-DD: 일별 변경 이력" 