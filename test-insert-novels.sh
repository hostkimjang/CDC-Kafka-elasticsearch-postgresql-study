#!/bin/bash
#
# ====================================================================================
#  PostgreSQL에 테스트용 소설 데이터 삽입 스크립트 (차별화된 데이터)
# ====================================================================================
#
#  CDC 파이프라인 테스트를 위한 샘플 데이터 생성 스크립트
#  - novels 테이블: 한국 웹소설 데이터
#  - ex_platform_novel 테이블: 해외 플랫폼 소설 데이터
#
# ====================================================================================

echo "==================== 테스트 소설 데이터 삽입 시작 ===================="

# novels 테이블용 - 한국 웹소설 데이터
declare -a kr_titles=("나 혼자만 레벨업" "전지적 독자 시점" "김독자의 생존기" "달빛조각사" "템페스트" 
                      "마왕 학원의 불적격자" "재벌집 막내아들" "북검전기" "무림세가 막내아들" "회귀자의 마법은 특별해야 한다")

declare -a kr_authors=("추공" "싱숑" "김독자" "남희성" "박재우" 
                       "이준원" "산경" "무진" "유진강" "현오")

declare -a kr_platforms=("네이버 시리즈" "카카오페이지" "리디북스" "문피아" "조아라" 
                         "웹툰미리보기" "투믹스" "레진코믹스" "봄툰" "탑툰")

declare -a kr_genres=("판타지" "무협" "현판" "게임" "회귀" 
                      "학원" "경영" "무협" "가족" "마법")

# ex_platform_novel 테이블용 - 해외 플랫폼 소설 데이터
declare -a en_titles=("Harry Potter and the Philosophers Stone" "Lord of the Rings" "Game of Thrones" "The Witcher" "Dune" 
                      "Foundation" "Neuromancer" "The Matrix" "Blade Runner" "Star Wars")

declare -a en_authors=("J.K. Rowling" "J.R.R. Tolkien" "George R.R. Martin" "Andrzej Sapkowski" "Frank Herbert" 
                       "Isaac Asimov" "William Gibson" "Lana Wachowski" "Philip K. Dick" "George Lucas")

declare -a en_platforms=("Amazon Kindle" "Webnovel" "Royal Road" "Wattpad" "Archive of Our Own" 
                         "FanFiction.Net" "Scribble Hub" "Novel Updates" "Goodreads" "Barnes & Noble")

declare -a en_genres=("Fantasy" "Epic Fantasy" "Political Drama" "Dark Fantasy" "Science Fiction" 
                      "Space Opera" "Cyberpunk" "Sci-Fi Thriller" "Dystopian" "Space Adventure")

declare -a statuses=("연재중" "완결" "휴재" "연재중" "완결" 
                     "연재중" "완결" "연재중" "휴재" "완결")

echo "📚 10개의 한국 웹소설 데이터를 'novels' 테이블에 삽입합니다..."

for i in {0..9}; do
    title="${kr_titles[$i]}"
    author="${kr_authors[$i]}"
    platform="${kr_platforms[$i]}"
    url="https://series.naver.com/novel/kr_$((i+1))"
    description="${title}는 ${kr_genres[$i]} 장르의 대표적인 한국 웹소설입니다."
    genre="${kr_genres[$i]}"
    status="${statuses[$i]}"
    total_chapters=$((RANDOM % 100 + 50))   # 50-149 사이 랜덤
    view_count=$((RANDOM % 1000000 + 10000)) # 10K-1M 사이 랜덤
    like_count=$((RANDOM % 50000 + 1000))    # 1K-50K 사이 랜덤
    rating=$(echo "scale=1; $(($RANDOM % 30 + 40)) / 10" | bc) # 4.0-6.9 사이 랜덤
    
    echo "  $((i+1)). '$title' by $author [$platform] - $genre"
    
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
echo "✅ 'novels' 테이블에 총 10개의 한국 웹소설이 성공적으로 삽입되었습니다!"
echo ""

echo "📚 10개의 해외 플랫폼 소설 데이터를 'ex_platform_novel' 테이블에 삽입합니다..."

# 'ex_platform_novel'용 데이터 삽입 - 해외 소설
for i in {0..9}; do
    platform_id="EN-$(($i+1000))"
    platform_name="${en_platforms[$i]}"
    title="${en_titles[$i]}"
    author="${en_authors[$i]}"
    url="https://amazon.com/kindle/novel/en_$((i+1))"
    description="${title} is a renowned ${en_genres[$i]} novel from international platforms."
    genre="${en_genres[$i]}"
    status="${statuses[$i]}"
    total_chapters=$((RANDOM % 300 + 100))   # 100-399 사이 랜덤
    view_count=$((RANDOM % 5000000 + 100000)) # 100K-5M 사이 랜덤
    like_count=$((RANDOM % 100000 + 5000))    # 5K-100K 사이 랜덤
    rating=$(echo "scale=1; $(($RANDOM % 25 + 45)) / 10" | bc) # 4.5-6.9 사이 랜덤
    
    echo "  $((i+1)). '$title' by $author [$platform_name] - $genre"
    
    docker exec postgres-db psql -U postgres -d novel_platform -c "
        INSERT INTO ex_platform_novel (
            platform_id, platform_name, title, author, url, description, genre, status,
            total_chapters, view_count, like_count, rating
        ) VALUES (
            '$platform_id', '$platform_name', '$title', '$author', '$url', '$description', '$genre', '$status',
            $total_chapters, $view_count, $like_count, $rating
        );"
    
    sleep 0.5
done

echo ""
echo "✅ 'ex_platform_novel' 테이블에 총 10개의 해외 플랫폼 소설이 성공적으로 삽입되었습니다!"
echo ""
echo "🔍 삽입된 데이터 확인:"
echo "📖 한국 웹소설 (novels 테이블):"
docker exec postgres-db psql -U postgres -d novel_platform -c "
    SELECT id, title, author, platform, genre, status 
    FROM novels 
    ORDER BY id DESC 
    LIMIT 10;"

echo ""
echo "🌍 해외 플랫폼 소설 (ex_platform_novel 테이블):"
docker exec postgres-db psql -U postgres -d novel_platform -c "
    SELECT id, title, author, platform_name, genre, status 
    FROM ex_platform_novel 
    ORDER BY id DESC 
    LIMIT 10;"

echo ""
echo "📊 Elasticsearch 동기화 확인 (10초 후):"
echo "  잠시 후 다음 명령어로 각 인덱스를 확인하세요:"
echo "  🇰🇷 한국 웹소설: curl -s \"http://localhost:9200/ex_platform.public.novels/_search?pretty\""
echo "  🌍 해외 플랫폼: curl -s \"http://localhost:9200/ex_platform.public.ex_platform_novel/_search?pretty\""
echo ""
echo "==================== 테스트 데이터 삽입 완료 ====================" 