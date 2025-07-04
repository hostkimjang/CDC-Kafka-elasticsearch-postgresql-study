-- 소설 플랫폼 데이터베이스 초기화 스크립트

-- 소설 정보 테이블
CREATE TABLE IF NOT EXISTS novels (
    id SERIAL PRIMARY KEY,
    title VARCHAR(500) NOT NULL,
    author VARCHAR(200) NOT NULL,
    platform VARCHAR(100) NOT NULL,
    url TEXT NOT NULL,
    description TEXT,
    genre VARCHAR(100),
    status VARCHAR(50),
    total_chapters INTEGER DEFAULT 0,
    view_count INTEGER DEFAULT 0,
    like_count INTEGER DEFAULT 0,
    rating DECIMAL(3,2),
    tags TEXT[], -- PostgreSQL 배열 타입
    cover_image_url TEXT,
    publication_date DATE,
    last_updated_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 챕터 정보 테이블
CREATE TABLE IF NOT EXISTS chapters (
    id SERIAL PRIMARY KEY,
    novel_id INTEGER REFERENCES novels (id) ON DELETE CASCADE,
    chapter_number INTEGER NOT NULL,
    title VARCHAR(500),
    content TEXT,
    word_count INTEGER DEFAULT 0,
    publication_date TIMESTAMP,
    view_count INTEGER DEFAULT 0,
    like_count INTEGER DEFAULT 0,
    url TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (novel_id, chapter_number)
);

-- 크롤링 로그 테이블
CREATE TABLE IF NOT EXISTS crawl_logs (
    id SERIAL PRIMARY KEY,
    platform VARCHAR(100) NOT NULL,
    crawl_type VARCHAR(50) NOT NULL, -- 'novel', 'chapter', 'metadata'
    target_id INTEGER, -- novel_id 또는 chapter_id
    status VARCHAR(20) NOT NULL, -- 'success', 'failed', 'skipped'
    message TEXT,
    crawled_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 플랫폼 정보 테이블
CREATE TABLE IF NOT EXISTS platforms (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) UNIQUE NOT NULL,
    base_url TEXT NOT NULL,
    is_active BOOLEAN DEFAULT true,
    last_crawl_date TIMESTAMP,
    crawl_interval_hours INTEGER DEFAULT 24,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 인덱스 생성
CREATE INDEX idx_novels_platform ON novels (platform);

CREATE INDEX idx_novels_updated_at ON novels (updated_at);

CREATE INDEX idx_novels_status ON novels (status);

CREATE INDEX idx_chapters_novel_id ON chapters (novel_id);

CREATE INDEX idx_chapters_publication_date ON chapters (publication_date);

CREATE INDEX idx_crawl_logs_platform ON crawl_logs (platform);

CREATE INDEX idx_crawl_logs_crawled_at ON crawl_logs (crawled_at);

-- 트리거 함수: updated_at 자동 업데이트
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- 트리거 적용
CREATE TRIGGER update_novels_updated_at BEFORE UPDATE ON novels
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_chapters_updated_at BEFORE UPDATE ON chapters
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- 샘플 플랫폼 데이터 삽입
INSERT INTO
    platforms (
        name,
        base_url,
        crawl_interval_hours
    )
VALUES (
        '네이버 시리즈',
        'https://series.naver.com',
        12
    ),
    (
        '카카오페이지',
        'https://page.kakao.com',
        12
    ),
    (
        '리디북스',
        'https://ridibooks.com',
        24
    ),
    (
        '문피아',
        'https://munpia.com',
        6
    ) ON CONFLICT (name) DO NOTHING;

-- 샘플 소설 데이터 (테스트용)
INSERT INTO novels (title, author, platform, url, description, genre, status, total_chapters, view_count, like_count, rating, tags) VALUES
('샘플 소설 1', '작가1', '네이버 시리즈', 'https://series.naver.com/novel/sample1', '샘플 소설 설명입니다.', '판타지', '연재중', 50, 10000, 500, 4.5, ARRAY['판타지', '모험', '성장'])
ON CONFLICT DO NOTHING;

-- ====================================================================================
-- Novel Platform CDC 파이프라인 데이터베이스 초기화 스크립트
-- ====================================================================================
-- 이 스크립트는 PostgreSQL 컨테이너 시작 시 자동으로 실행됩니다.

-- 기본 데이터베이스 및 사용자 설정은 docker-compose.yml의 환경변수로 처리됨

-- ====================================================================================
-- 1. 메인 소설 테이블 (기존)
-- ====================================================================================
CREATE TABLE IF NOT EXISTS novels (
    id SERIAL PRIMARY KEY,
    title VARCHAR(500) NOT NULL, -- 소설 제목
    author VARCHAR(200) NOT NULL, -- 작가명
    platform VARCHAR(100) NOT NULL, -- 플랫폼 (네이버시리즈, 카카오페이지 등)
    url TEXT NOT NULL, -- 원본 URL
    description TEXT, -- 소설 설명
    genre VARCHAR(100), -- 장르
    status VARCHAR(50), -- 연재 상태 (연재중, 완결, 휴재)
    total_chapters INTEGER DEFAULT 0, -- 총 화수
    view_count INTEGER DEFAULT 0, -- 조회수
    like_count INTEGER DEFAULT 0, -- 좋아요 수
    rating DECIMAL(3, 2), -- 평점
    tags TEXT, -- 태그 (JSON 배열 형태)
    cover_image_url TEXT, -- 표지 이미지 URL
    publication_date TIMESTAMP, -- 최초 발행일
    last_updated_date TIMESTAMP, -- 마지막 업데이트일
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ====================================================================================
-- 2. 크롤링 플랫폼 소설 테이블 (신규)
-- ====================================================================================
CREATE TABLE IF NOT EXISTS ex_platform_novel (
    id SERIAL PRIMARY KEY,
    platform_id VARCHAR(100) NOT NULL,    -- 플랫폼 내부 ID
    platform_name VARCHAR(100) NOT NULL,  -- 플랫폼명 (네이버시리즈, 카카오페이지 등)
    title VARCHAR(500) NOT NULL,          -- 소설 제목
    author VARCHAR(200) NOT NULL,         -- 작가명
    url TEXT NOT NULL,                    -- 원본 URL
    description TEXT,                     -- 소설 설명
    genre VARCHAR(100),                   -- 장르
    status VARCHAR(50),                   -- 연재 상태
    total_chapters INTEGER DEFAULT 0,    -- 총 화수
    view_count BIGINT DEFAULT 0,          -- 조회수 (플랫폼별로 큰 수치 가능)
    like_count INTEGER DEFAULT 0,        -- 좋아요/별점 수
    rating DECIMAL(3,2),                 -- 평점
    tags TEXT,                            -- 태그 정보
    cover_image_url TEXT,                 -- 표지 이미지 URL
    publication_date TIMESTAMP,           -- 최초 발행일
    last_chapter_date TIMESTAMP,          -- 마지막 회차 업데이트일
    crawled_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,  -- 크롤링 시간
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

-- 플랫폼별 고유성 보장
UNIQUE(platform_name, platform_id) );

-- ====================================================================================
-- 3. 소설 회차 테이블
-- ====================================================================================
CREATE TABLE IF NOT EXISTS chapters (
    id SERIAL PRIMARY KEY,
    novel_id INTEGER REFERENCES novels (id) ON DELETE CASCADE,
    chapter_number INTEGER NOT NULL, -- 회차 번호
    title VARCHAR(500), -- 회차 제목
    content TEXT, -- 회차 내용
    word_count INTEGER DEFAULT 0, -- 글자 수
    published_at TIMESTAMP, -- 발행 시간
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (novel_id, chapter_number)
);

-- ====================================================================================
-- 4. 크롤링 로그 테이블
-- ====================================================================================
CREATE TABLE IF NOT EXISTS crawl_logs (
    id SERIAL PRIMARY KEY,
    platform VARCHAR(100) NOT NULL, -- 크롤링 대상 플랫폼
    crawl_type VARCHAR(50) NOT NULL, -- 크롤링 타입 (novel, chapter, ranking 등)
    target_url TEXT, -- 크롤링 대상 URL
    status VARCHAR(20) NOT NULL, -- 상태 (success, failed, partial)
    items_count INTEGER DEFAULT 0, -- 수집된 아이템 수
    error_message TEXT, -- 에러 메시지 (실패 시)
    execution_time_ms INTEGER, -- 실행 시간 (밀리초)
    started_at TIMESTAMP, -- 시작 시간
    completed_at TIMESTAMP, -- 완료 시간
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ====================================================================================
-- 5. 플랫폼 정보 테이블
-- ====================================================================================
CREATE TABLE IF NOT EXISTS platforms (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) UNIQUE NOT NULL, -- 플랫폼명
    base_url TEXT NOT NULL, -- 기본 URL
    crawl_enabled BOOLEAN DEFAULT true, -- 크롤링 활성화 여부
    last_crawl_at TIMESTAMP, -- 마지막 크롤링 시간
    crawl_interval_hours INTEGER DEFAULT 24, -- 크롤링 주기 (시간)
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ====================================================================================
-- 6. 인덱스 생성
-- ====================================================================================

-- 기존 테이블 인덱스
CREATE INDEX IF NOT EXISTS idx_novels_platform ON novels (platform);

CREATE INDEX IF NOT EXISTS idx_novels_genre ON novels (genre);

CREATE INDEX IF NOT EXISTS idx_novels_status ON novels (status);

CREATE INDEX IF NOT EXISTS idx_novels_updated_at ON novels (updated_at);

-- 크롤링 테이블 인덱스
CREATE INDEX IF NOT EXISTS idx_ex_platform_novel_platform ON ex_platform_novel (platform_name);

CREATE INDEX IF NOT EXISTS idx_ex_platform_novel_platform_id ON ex_platform_novel (platform_name, platform_id);

CREATE INDEX IF NOT EXISTS idx_ex_platform_novel_updated_at ON ex_platform_novel (updated_at);

CREATE INDEX IF NOT EXISTS idx_ex_platform_novel_crawled_at ON ex_platform_novel (crawled_at);

-- 기타 인덱스
CREATE INDEX IF NOT EXISTS idx_chapters_novel_id ON chapters (novel_id);

CREATE INDEX IF NOT EXISTS idx_crawl_logs_platform ON crawl_logs (platform);

CREATE INDEX IF NOT EXISTS idx_crawl_logs_status ON crawl_logs (status);

-- ====================================================================================
-- 7. 트리거 함수 (updated_at 자동 갱신)
-- ====================================================================================
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- updated_at 트리거 적용
CREATE TRIGGER update_novels_updated_at BEFORE UPDATE ON novels
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_ex_platform_novel_updated_at BEFORE UPDATE ON ex_platform_novel
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_chapters_updated_at BEFORE UPDATE ON chapters
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_platforms_updated_at BEFORE UPDATE ON platforms
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ====================================================================================
-- 8. 초기 샘플 데이터
-- ====================================================================================

-- 플랫폼 정보 삽입
INSERT INTO
    platforms (name, base_url, crawl_enabled)
VALUES (
        '네이버시리즈',
        'https://series.naver.com',
        true
    ),
    (
        '카카오페이지',
        'https://page.kakao.com',
        true
    ),
    (
        '조아라',
        'https://www.joara.com',
        true
    ),
    (
        '문피아',
        'https://novel.munpia.com',
        true
    ) ON CONFLICT (name) DO NOTHING;

-- 기본 소설 데이터 삽입
INSERT INTO
    novels (
        title,
        author,
        platform,
        url,
        description,
        genre,
        status,
        total_chapters,
        view_count,
        like_count,
        rating
    )
VALUES (
        '판타지 대모험',
        '김판타지',
        '네이버시리즈',
        'https://series.naver.com/novel/detail.series?productNo=1',
        '흥미진진한 판타지 모험 이야기',
        '판타지',
        '연재중',
        25,
        15000,
        1200,
        4.5
    ),
    (
        '현대 로맨스',
        '박로맨스',
        '카카오페이지',
        'https://page.kakao.com/content/1',
        '달콤한 현대 로맨스 소설',
        '로맨스',
        '완결',
        30,
        8500,
        800,
        4.2
    ),
    (
        '무협의 전설',
        '이무협',
        '조아라',
        'https://www.joara.com/novel/1',
        '전설적인 무협 소설',
        '무협',
        '연재중',
        40,
        12000,
        950,
        4.7
    ) ON CONFLICT DO NOTHING;

-- 크롤링 플랫폼 소설 샘플 데이터
INSERT INTO
    ex_platform_novel (
        platform_id,
        platform_name,
        title,
        author,
        url,
        description,
        genre,
        status,
        total_chapters,
        view_count,
        like_count,
        rating
    )
VALUES (
        'naver_12345',
        '네이버시리즈',
        '신작 판타지',
        '새로운작가',
        'https://series.naver.com/novel/detail.series?productNo=12345',
        '새로운 판타지 작품',
        '판타지',
        '연재중',
        10,
        5000,
        300,
        4.3
    ),
    (
        'kakao_67890',
        '카카오페이지',
        '달콤한 로맨스',
        '로맨스작가',
        'https://page.kakao.com/content/67890',
        '달콤한 사랑 이야기',
        '로맨스',
        '연재중',
        15,
        7500,
        450,
        4.1
    ),
    (
        'joara_111',
        '조아라',
        '무협 신작',
        '무협대가',
        'https://www.joara.com/novel/111',
        '새로운 무협 세계',
        '무협',
        '연재중',
        20,
        3200,
        200,
        4.6
    ) ON CONFLICT (platform_name, platform_id) DO NOTHING;

-- ====================================================================================
-- 9. 논리적 복제를 위한 설정
-- ====================================================================================

-- Debezium을 위한 복제 권한 설정
ALTER USER postgres WITH REPLICATION;

-- 테이블별 복제 ID 설정 (필요시)
-- ALTER TABLE novels REPLICA IDENTITY FULL;
-- ALTER TABLE ex_platform_novel REPLICA IDENTITY FULL;

COMMIT;