#!/bin/bash
#
# ====================================================================================
#  PostgreSQL에 테스트용 소설 10개 삽입 스크립트
# ====================================================================================
#
#  CDC 파이프라인 테스트를 위한 샘플 데이터 생성 스크립트
#
# ====================================================================================

echo "==================== 테스트 소설 데이터 삽입 시작 ===================="

# 테스트 소설 데이터 배열
declare -a titles=("마법사의 모험" "드래곤 헌터" "사이버펑크 2077" "우주 전쟁" "타임 패러독스" 
                   "로봇의 꿈" "비밀의 정원" "해리포터와 마법사의 돌" "반지의 제왕" "아바타 아바타")

declare -a authors=("김마법" "이드래곤" "박사이버" "최우주" "정시간" 
                    "한로봇" "송비밀" "조해리" "윤반지" "장아바타")

declare -a platforms=("네이버 시리즈" "카카오페이지" "리디북스" "문피아" "조아라" 
                      "웹툰미리보기" "투믹스" "레진코믹스" "봄툰" "탑툰")

declare -a genres=("판타지" "SF" "로맨스" "무협" "스릴러" 
                   "미스터리" "드라마" "코미디" "액션" "호러")

declare -a statuses=("연재중" "완결" "휴재" "연재중" "완결" 
                     "연재중" "완결" "연재중" "휴재" "완결")

echo "📚 10개의 테스트 소설 데이터를 삽입합니다..."

for i in {0..9}; do
    title="${titles[$i]}"
    author="${authors[$i]}"
    platform="${platforms[$i]}"
    url="https://example.com/novel/$((i+1))"
    description="${title}에 대한 흥미진진한 이야기입니다."
    genre="${genres[$i]}"
    status="${statuses[$i]}"
    total_chapters=$((RANDOM % 100 + 10))  # 10-109 사이 랜덤
    view_count=$((RANDOM % 100000 + 1000)) # 1000-100999 사이 랜덤
    like_count=$((RANDOM % 10000 + 100))   # 100-10099 사이 랜덤
    rating=$(echo "scale=1; $(($RANDOM % 50 + 30)) / 10" | bc) # 3.0-7.9 사이 랜덤
    
    echo "  $((i+1)). '$title' by $author [$platform]"
    
    docker exec postgres-db psql -U postgres -d novel_platform -c "
        INSERT INTO novels (
            title, author, platform, url, description, genre, status, 
            total_chapters, view_count, like_count, rating
        ) VALUES (
            '$title', '$author', '$platform', '$url', '$description', '$genre', '$status',
            $total_chapters, $view_count, $like_count, $rating
        );"
    
    # 각 삽입 사이에 0.5초 대기 (CDC 파이프라인 관찰용)
    sleep 0.5
done

echo ""
echo "✅ 총 10개의 테스트 소설이 성공적으로 삽입되었습니다!"
echo ""
echo "🔍 삽입된 데이터 확인:"
docker exec postgres-db psql -U postgres -d novel_platform -c "
    SELECT id, title, author, platform, genre, status 
    FROM novels 
    ORDER BY id DESC 
    LIMIT 10;"

echo ""
echo "📊 Elasticsearch 동기화 확인 (10초 후):"
echo "  잠시 후 다음 명령어로 확인하세요:"
echo "  curl -s \"http://localhost:6200/novel-platform-novels/_search?pretty\" | jq '.hits.total.value'"
echo ""
echo "==================== 테스트 데이터 삽입 완료 ====================" 