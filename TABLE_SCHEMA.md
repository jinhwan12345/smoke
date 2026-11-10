# 🗄️ 데이터베이스 테이블 구조 (Table Schema)

이 문서는 **담뱃불좀꺼줄래** 앱에서 사용하는 흡연구역(`smoking_areas`) 및 금연구역(`non_smoking_areas`) 테이블의 최신 스키마 구조입니다.

---

## 📋 테이블 정보
- **흡연구역 테이블명**: `smoking_areas`
- **금연구역 테이블명**: `non_smoking_areas`
- **총 컬럼 수**: 8개 (동일 구조)

---

## 🏷️ 컬럼 정의 (Columns)

| 순번 | 컬럼명 (Field) | 데이터 타입 (Type) | 필수여부 | 설명 (Description) | 예시 (Example) |
| :---: | :--- | :--- | :---: | :--- | :--- |
| **1** | `id` | `VARCHAR` / `BIGINT` | **PK (필수)** | 구역 고유 식별자 | `"1"`, `1001` |
| **2** | `area_nm` | `VARCHAR(255)` | **필수** | 구역 명칭 | `"강남역 9번 출구 흡연구역"` / `"역삼공원 금연구역"` |
| **3** | `area_ar` | `NUMERIC(10,2)` | 선택 | 구역 면적 (㎡) *(앱 반경 계산용)* | `35.50` |
| **4** | `latitude` | `NUMERIC(12,8)` | **필수** | 위도 (Latitude, WGS84) | `37.498095` |
| **5** | `longitude` | `NUMERIC(12,8)` | **필수** | 경도 (Longitude, WGS84) | `127.027610` |
| **6** | `lnmadr` | `VARCHAR(500)` | 선택 | **지번주소** | `"서울특별시 강남구 역삼동 825"` |
| **7** | `rdnmadr` | `VARCHAR(500)` | 선택 | **도로명주소** | `"서울특별시 강남구 강남대로 396"` |
| **8** | `ref_date` | `VARCHAR(20)` | 선택 | 데이터 기준일자 | `"2024-06-30"` |

---

## 🗑️ 삭제된 컬럼 (Removed Columns)
아래 6개 컬럼은 데이터 경량화 및 최적화를 위해 제거되었습니다:
- ❌ `area_se` (구역구분)
- ❌ `ctprvnnm` (시도명)
- ❌ `signgunm` (시군구명)
- ❌ `endnm` (읍면동명)
- ❌ `inst_nm` (관리기관명)
- ❌ `fclty_knm` (시설구분명)

---

## 💡 SQL 테이블 생성 쿼리 (PostgreSQL / Supabase)

```sql
-- 1. 흡연구역 테이블
CREATE TABLE IF NOT EXISTS smoking_areas (
    id VARCHAR(50) PRIMARY KEY,
    area_nm VARCHAR(255) NOT NULL,
    area_ar NUMERIC(10,2) DEFAULT 0.0,
    latitude NUMERIC(12,8) NOT NULL,
    longitude NUMERIC(12,8) NOT NULL,
    lnmadr VARCHAR(500),
    rdnmadr VARCHAR(500),
    ref_date VARCHAR(20)
);

-- 2. 금연구역 테이블
CREATE TABLE IF NOT EXISTS non_smoking_areas (
    id VARCHAR(50) PRIMARY KEY,
    area_nm VARCHAR(255) NOT NULL,
    area_ar NUMERIC(10,2) DEFAULT 0.0,
    latitude NUMERIC(12,8) NOT NULL,
    longitude NUMERIC(12,8) NOT NULL,
    lnmadr VARCHAR(500),
    rdnmadr VARCHAR(500),
    ref_date VARCHAR(20)
);

-- 공간 검색 인덱스
CREATE INDEX IF NOT EXISTS idx_smoking_areas_lat_lng ON smoking_areas (latitude, longitude);
CREATE INDEX IF NOT EXISTS idx_non_smoking_areas_lat_lng ON non_smoking_areas (latitude, longitude);

-- 3. 시·군·구별 구역 수 집계 테이블 (전국 229개 지역)
CREATE TABLE IF NOT EXISTS district_counts (
    code VARCHAR(50) PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    full_name VARCHAR(100) NOT NULL,
    sido_key VARCHAR(50) NOT NULL,
    sigungu_name VARCHAR(100) NOT NULL,
    latitude NUMERIC(12,8) NOT NULL,
    longitude NUMERIC(12,8) NOT NULL,
    smoking_count INTEGER NOT NULL DEFAULT 0,
    non_smoking_count INTEGER NOT NULL DEFAULT 0,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

---

## 📊 지역별 구역 수 집계 테이블 (`district_counts`) 안내
- 전체 생성·초기화·자동 집계 트리거 스크립트: `supabase_district_counts.sql`
- `smoking_areas`에 데이터를 추가/수정/삭제하면 트리거(`trg_smoking_areas_count_sync`)를 통해 `smoking_count`가 자동 갱신됩니다.
- 대량의 `non_smoking_areas` 변경 시에는 Supabase SQL Editor에서 `SELECT public.refresh_district_counts();`를 실행하면 전체 집계가 갱신됩니다.
