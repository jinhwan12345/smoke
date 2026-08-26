# 🗄️ 흡연구역 데이터베이스 테이블 구조 (Table Schema)

이 문서는 **담뱃불좀꺼줄래** 앱에서 사용하는 흡연구역(`smoking_areas`) 테이블의 최신 스키마 구조입니다.

---

## 📋 테이블 정보
- **테이블명**: `smoking_areas`
- **총 컬럼 수**: 8개

---

## 🏷️ 컬럼 정의 (Columns)

| 순번 | 컬럼명 (Field) | 데이터 타입 (Type) | 필수여부 | 설명 (Description) | 예시 (Example) |
| :---: | :--- | :--- | :---: | :--- | :--- |
| **1** | `id` | `VARCHAR` / `BIGINT` | **PK (필수)** | 흡연구역 고유 식별자 | `"1"`, `1001` |
| **2** | `area_nm` | `VARCHAR(255)` | **필수** | 흡연구역 명칭 | `"강남역 9번 출구 흡연구역"` |
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
CREATE TABLE smoking_areas (
    id VARCHAR(50) PRIMARY KEY,
    area_nm VARCHAR(255) NOT NULL,
    area_ar NUMERIC(10,2) DEFAULT 0.0,
    latitude NUMERIC(12,8) NOT NULL,
    longitude NUMERIC(12,8) NOT NULL,
    lnmadr VARCHAR(500),
    rdnmadr VARCHAR(500),
    ref_date VARCHAR(20)
);

-- 공간 검색 인덱스 (선택 사항)
CREATE INDEX idx_smoking_areas_lat_lng ON smoking_areas (latitude, longitude);
```

---

## 📦 JSON 데이터 포맷 예시

```json
[
  {
    "id": "1",
    "area_nm": "강남역 9번 출구 흡연부스",
    "area_ar": 36.0,
    "latitude": 37.498095,
    "longitude": 127.027610,
    "lnmadr": "서울특별시 서초구 서초동 1318",
    "rdnmadr": "서울특별시 서초구 강남대로 405",
    "ref_date": "2024-06-30"
  },
  {
    "id": "2",
    "area_nm": "역삼역 3번 출구 지정 흡연구역",
    "area_ar": 25.0,
    "latitude": 37.500622,
    "longitude": 127.036421,
    "lnmadr": "서울특별시 강남구 역삼동 737",
    "rdnmadr": "서울특별시 강남구 테헤란로 152",
    "ref_date": "2024-06-30"
  }
]
```
