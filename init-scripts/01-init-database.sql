-- Novel Platform CDC Pipeline Database Initialization Script
-- This script is executed automatically when the PostgreSQL container starts.

-- The basic database and user settings are handled by environment variables in docker-compose.yml

-- ====================================================================================
-- 1. Table Definitions
-- ====================================================================================

-- Table for crawled novels from various platforms (new)
CREATE TABLE IF NOT EXISTS ex_platform_novel (
    id SERIAL PRIMARY KEY,
    platform_id VARCHAR(100) NOT NULL,    -- Platform-specific ID
    platform_name VARCHAR(100) NOT NULL,  -- Platform name (e.g., Naver Series, Kakao Page)
    title VARCHAR(500) NOT NULL,          -- Novel title
    author VARCHAR(200) NOT NULL,         -- Author name
    url TEXT NOT NULL,                    -- Original URL
    description TEXT,                     -- Novel description
    genre VARCHAR(100),                   -- Genre
    status VARCHAR(50),                   -- Serialization status
    total_chapters INTEGER DEFAULT 0,    -- Total number of chapters
    view_count BIGINT DEFAULT 0,          -- View count (can be large depending on platform)
    like_count INTEGER DEFAULT 0,        -- Number of likes/stars
    rating DECIMAL(3,2),                 -- Rating
    tags TEXT,                            -- Tag information
    cover_image_url TEXT,                 -- Cover image URL
    publication_date TIMESTAMP,           -- Initial publication date
    last_chapter_date TIMESTAMP,          -- Last chapter update date
    crawled_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,  -- Crawling timestamp
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

-- Ensure uniqueness per platform
UNIQUE(platform_name, platform_id) );

-- Table for platform information
CREATE TABLE IF NOT EXISTS platforms (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) UNIQUE NOT NULL, -- Platform name
    base_url TEXT NOT NULL, -- Base URL
    crawl_enabled BOOLEAN DEFAULT true, -- Whether crawling is enabled
    last_crawl_at TIMESTAMP, -- Last crawl time
    crawl_interval_hours INTEGER DEFAULT 24, -- Crawl interval in hours
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ====================================================================================
-- 2. Index Creation
-- ====================================================================================

-- Indexes for the crawling table
CREATE INDEX IF NOT EXISTS idx_ex_platform_novel_platform ON ex_platform_novel (platform_name);

CREATE INDEX IF NOT EXISTS idx_ex_platform_novel_platform_id ON ex_platform_novel (platform_name, platform_id);

CREATE INDEX IF NOT EXISTS idx_ex_platform_novel_updated_at ON ex_platform_novel (updated_at);

CREATE INDEX IF NOT EXISTS idx_ex_platform_novel_crawled_at ON ex_platform_novel (crawled_at);

-- ====================================================================================
-- 3. Trigger for Automatic Timestamp Updates
-- ====================================================================================

-- Trigger function to automatically update 'updated_at'
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Drop and recreate triggers to ensure idempotency
DROP TRIGGER IF EXISTS update_ex_platform_novel_updated_at ON ex_platform_novel;

CREATE TRIGGER update_ex_platform_novel_updated_at
    BEFORE UPDATE ON ex_platform_novel
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_platforms_updated_at ON platforms;

CREATE TRIGGER update_platforms_updated_at
    BEFORE UPDATE ON platforms
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ====================================================================================
-- 4. Sample Data Insertion
-- ====================================================================================

-- Insert sample platform data
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

COMMIT;