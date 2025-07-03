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