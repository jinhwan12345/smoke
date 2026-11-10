-- ============================================================================
-- 지역별 흡연구역 / 금연구역 집계 테이블 (district_counts) 생성 및 초기 데이터/자동 집계 스크립트
-- Supabase Dashboard -> SQL Editor 에 붙여넣고 Run 을 눌러 실행하세요.
-- ============================================================================

SET statement_timeout = '5min';

-- 1. 지역별 구역 수 집계 테이블 생성 (전국 229개 시·군·구)
CREATE TABLE IF NOT EXISTS public.district_counts (
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

-- 2. RLS (Row Level Security) 설정 - 앱(anon/authenticated)에서 조회 허용
ALTER TABLE public.district_counts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow public read access on district_counts" ON public.district_counts;
CREATE POLICY "Allow public read access on district_counts"
    ON public.district_counts
    FOR SELECT
    USING (true);

-- 3. 전국 229개 시·군·구 기본 행 삽입 (이미 존재하면 메타데이터 및 현재 흡연구역 수 갱신)
INSERT INTO public.district_counts (
    code, name, full_name, sido_key, sigungu_name, latitude, longitude, smoking_count, non_smoking_count
) VALUES
    ('seoul_jongno', '종로구', '서울 종로구', '서울', '종로구', 37.5730, 126.9794, 0, 0),
    ('seoul_jung', '중구', '서울 중구', '서울', '중구', 37.5641, 126.9979, 0, 0),
    ('seoul_yongsan', '용산구', '서울 용산구', '서울', '용산구', 37.5326, 126.9900, 0, 0),
    ('seoul_seongdong', '성동구', '서울 성동구', '서울', '성동구', 37.5633, 127.0371, 16, 0),
    ('seoul_gwangjin', '광진구', '서울 광진구', '서울', '광진구', 37.5385, 127.0823, 32, 0),
    ('seoul_dongdaemun', '동대문구', '서울 동대문구', '서울', '동대문구', 37.5744, 127.0400, 0, 0),
    ('seoul_jungnang', '중랑구', '서울 중랑구', '서울', '중랑구', 37.6066, 127.0927, 1, 0),
    ('seoul_seongbuk', '성북구', '서울 성북구', '서울', '성북구', 37.5891, 127.0182, 0, 0),
    ('seoul_gangbuk', '강북구', '서울 강북구', '서울', '강북구', 37.6396, 127.0257, 40, 0),
    ('seoul_dobong', '도봉구', '서울 도봉구', '서울', '도봉구', 37.6688, 127.0471, 0, 0),
    ('seoul_nowon', '노원구', '서울 노원구', '서울', '노원구', 37.6542, 127.0568, 0, 0),
    ('seoul_eunpyeong', '은평구', '서울 은평구', '서울', '은평구', 37.6027, 126.9291, 0, 0),
    ('seoul_seodaemun', '서대문구', '서울 서대문구', '서울', '서대문구', 37.5791, 126.9368, 0, 0),
    ('seoul_mapo', '마포구', '서울 마포구', '서울', '마포구', 37.5663, 126.9016, 0, 0),
    ('seoul_yangcheon', '양천구', '서울 양천구', '서울', '양천구', 37.5170, 126.8665, 0, 0),
    ('seoul_gangseo', '강서구', '서울 강서구', '서울', '강서구', 37.5509, 126.8495, 0, 0),
    ('seoul_guro', '구로구', '서울 구로구', '서울', '구로구', 37.4954, 126.8874, 0, 0),
    ('seoul_geumcheon', '금천구', '서울 금천구', '서울', '금천구', 37.4569, 126.8954, 60, 0),
    ('seoul_yeongdeungpo', '영등포구', '서울 영등포구', '서울', '영등포구', 37.5264, 126.8962, 0, 0),
    ('seoul_dongjak', '동작구', '서울 동작구', '서울', '동작구', 37.5124, 126.9393, 0, 0),
    ('seoul_gwanak', '관악구', '서울 관악구', '서울', '관악구', 37.4784, 126.9516, 0, 0),
    ('seoul_seocho', '서초구', '서울 서초구', '서울', '서초구', 37.4837, 127.0324, 0, 0),
    ('seoul_gangnam', '강남구', '서울 강남구', '서울', '강남구', 37.5172, 127.0473, 0, 0),
    ('seoul_songpa', '송파구', '서울 송파구', '서울', '송파구', 37.5145, 127.1066, 0, 0),
    ('seoul_gangdong', '강동구', '서울 강동구', '서울', '강동구', 37.5301, 127.1238, 12, 0),
    ('incheon_jung', '인천 중구', '인천 중구', '인천', '중구', 37.4738, 126.6215, 0, 0),
    ('incheon_dong', '인천 동구', '인천 동구', '인천', '동구', 37.4739, 126.6432, 0, 0),
    ('incheon_michuhol', '미추홀구', '인천 미추홀구', '인천', '미추홀구', 37.4635, 126.6505, 0, 0),
    ('incheon_yeonsu', '연수구', '인천 연수구', '인천', '연수구', 37.4102, 126.6788, 0, 0),
    ('incheon_namdong', '남동구', '인천 남동구', '인천', '남동구', 37.4473, 126.7314, 0, 0),
    ('incheon_bupyeong', '부평구', '인천 부평구', '인천', '부평구', 37.5070, 126.7218, 0, 0),
    ('incheon_gyeyang', '계양구', '인천 계양구', '인천', '계양구', 37.5374, 126.7377, 0, 0),
    ('incheon_seo', '인천 서구', '인천 서구', '인천', '서구', 37.5454, 126.6759, 0, 0),
    ('incheon_ganghwa', '강화군', '인천 강화군', '인천', '강화군', 37.7465, 126.4881, 0, 0),
    ('incheon_ongjin', '옹진군', '인천 옹진군', '인천', '옹진군', 37.2500, 126.1500, 0, 0),
    ('gg_suwon', '수원시', '경기 수원시', '경기', '수원시', 37.2636, 127.0286, 0, 0),
    ('gg_seongnam', '성남시', '경기 성남시', '경기', '성남시', 37.4200, 127.1265, 0, 0),
    ('gg_goyang', '고양시', '경기 고양시', '경기', '고양시', 37.6584, 126.8320, 0, 0),
    ('gg_yongin', '용인시', '경기 용인시', '경기', '용인시', 37.2411, 127.1776, 0, 0),
    ('gg_bucheon', '부천시', '경기 부천시', '경기', '부천시', 37.5034, 126.7660, 0, 0),
    ('gg_ansan', '안산시', '경기 안산시', '경기', '안산시', 37.3219, 126.8309, 0, 0),
    ('gg_anyang', '안양시', '경기 안양시', '경기', '안양시', 37.3943, 126.9568, 0, 0),
    ('gg_namyangju', '남양주시', '경기 남양주시', '경기', '남양주시', 37.6360, 127.2165, 0, 0),
    ('gg_hwaseong', '화성시', '경기 화성시', '경기', '화성시', 37.1995, 126.8313, 0, 0),
    ('gg_pyeongtaek', '평택시', '경기 평택시', '경기', '평택시', 36.9921, 127.1129, 0, 0),
    ('gg_uijeongbu', '의정부시', '경기 의정부시', '경기', '의정부시', 37.7381, 127.0337, 0, 0),
    ('gg_siheung', '시흥시', '경기 시흥시', '경기', '시흥시', 37.3800, 126.8029, 0, 0),
    ('gg_paju', '파주시', '경기 파주시', '경기', '파주시', 37.7599, 126.7802, 1, 0),
    ('gg_gimpo', '김포시', '경기 김포시', '경기', '김포시', 37.6152, 126.7156, 0, 0),
    ('gg_gwangmyeong', '광명시', '경기 광명시', '경기', '광명시', 37.4786, 126.8646, 0, 0),
    ('gg_gwangju', '광주시', '경기 광주시', '경기', '광주시', 37.4294, 127.2551, 3, 0),
    ('gg_gunpo', '군포시', '경기 군포시', '경기', '군포시', 37.3617, 126.9352, 0, 0),
    ('gg_hanam', '하남시', '경기 하남시', '경기', '하남시', 37.5393, 127.2149, 0, 0),
    ('gg_osan', '오산시', '경기 오산시', '경기', '오산시', 37.1499, 127.0772, 0, 0),
    ('gg_icheon', '이천시', '경기 이천시', '경기', '이천시', 37.2720, 127.4350, 0, 0),
    ('gg_anseong', '안성시', '경기 안성시', '경기', '안성시', 37.0080, 127.2797, 0, 0),
    ('gg_uiwang', '의왕시', '경기 의왕시', '경기', '의왕시', 37.3448, 126.9683, 0, 0),
    ('gg_yangju', '양주시', '경기 양주시', '경기', '양주시', 37.7853, 127.0458, 0, 0),
    ('gg_yeoju', '여주시', '경기 여주시', '경기', '여주시', 37.2983, 127.6374, 0, 0),
    ('gg_yangpyeong', '양평군', '경기 양평군', '경기', '양평군', 37.4912, 127.4876, 0, 0),
    ('gg_gwacheon', '과천시', '경기 과천시', '경기', '과천시', 37.4292, 126.9876, 0, 0),
    ('gg_guri', '구리시', '경기 구리시', '경기', '구리시', 37.5943, 127.1296, 0, 0),
    ('gg_pocheon', '포천시', '경기 포천시', '경기', '포천시', 37.8949, 127.2003, 0, 0),
    ('gg_dongducheon', '동두천시', '경기 동두천시', '경기', '동두천시', 37.9035, 127.0605, 0, 0),
    ('gg_gapyeong', '가평군', '경기 가평군', '경기', '가평군', 37.8315, 127.5096, 0, 0),
    ('gg_yeoncheon', '연천군', '경기 연천군', '경기', '연천군', 38.0966, 127.0750, 0, 0),
    ('busan_jung', '부산 중구', '부산 중구', '부산', '중구', 35.1062, 129.0323, 0, 0),
    ('busan_seo', '부산 서구', '부산 서구', '부산', '서구', 35.0979, 129.0243, 0, 0),
    ('busan_dong', '부산 동구', '부산 동구', '부산', '동구', 35.1293, 129.0455, 0, 0),
    ('busan_yeongdo', '영도구', '부산 영도구', '부산', '영도구', 35.0912, 129.0679, 0, 0),
    ('busan_busanjin', '부산진구', '부산 부산진구', '부산', '부산진구', 35.1631, 129.0532, 0, 0),
    ('busan_dongnae', '동래구', '부산 동래구', '부산', '동래구', 35.2048, 129.0837, 0, 0),
    ('busan_nam', '부산 남구', '부산 남구', '부산', '남구', 35.1366, 129.0844, 0, 0),
    ('busan_buk', '부산 북구', '부산 북구', '부산', '북구', 35.1972, 128.9904, 0, 0),
    ('busan_haeundae', '해운대구', '부산 해운대구', '부산', '해운대구', 35.1631, 129.1636, 0, 0),
    ('busan_saha', '사하구', '부산 사하구', '부산', '사하구', 35.1045, 128.9749, 0, 0),
    ('busan_geumjeong', '금정구', '부산 금정구', '부산', '금정구', 35.2429, 129.0926, 0, 0),
    ('busan_gangseo', '부산 강서구', '부산 강서구', '부산', '강서구', 35.2122, 128.9806, 0, 0),
    ('busan_yeonje', '연제구', '부산 연제구', '부산', '연제구', 35.1762, 129.0797, 0, 0),
    ('busan_suyeong', '수영구', '부산 수영구', '부산', '수영구', 35.1456, 129.1132, 0, 0),
    ('busan_sasang', '사상구', '부산 사상구', '부산', '사상구', 35.1526, 128.9912, 0, 0),
    ('busan_gijang', '기장군', '부산 기장군', '부산', '기장군', 35.2446, 129.2223, 0, 0),
    ('daegu_jung', '대구 중구', '대구 중구', '대구', '중구', 35.8693, 128.6062, 0, 0),
    ('daegu_dong', '대구 동구', '대구 동구', '대구', '동구', 35.8868, 128.6356, 0, 0),
    ('daegu_seo', '대구 서구', '대구 서구', '대구', '서구', 35.8718, 128.5592, 0, 0),
    ('daegu_nam', '대구 남구', '대구 남구', '대구', '남구', 35.8460, 128.5977, 0, 0),
    ('daegu_buk', '대구 북구', '대구 북구', '대구', '북구', 35.8857, 128.5829, 0, 0),
    ('daegu_suseong', '수성구', '대구 수성구', '대구', '수성구', 35.8582, 128.6306, 0, 0),
    ('daegu_dalseo', '달서구', '대구 달서구', '대구', '달서구', 35.8299, 128.5327, 0, 0),
    ('daegu_dalseong', '달성군', '대구 달성군', '대구', '달성군', 35.7747, 128.4314, 0, 0),
    ('daegu_gunwi', '군위군', '대구 군위군', '대구', '군위군', 36.2429, 128.5728, 1, 0),
    ('daejeon_dong', '대전 동구', '대전 동구', '대전', '동구', 36.3120, 127.4549, 0, 0),
    ('daejeon_jung', '대전 중구', '대전 중구', '대전', '중구', 36.3256, 127.4214, 0, 0),
    ('daejeon_seo', '대전 서구', '대전 서구', '대전', '서구', 36.3555, 127.3838, 0, 0),
    ('daejeon_yuseong', '유성구', '대전 유성구', '대전', '유성구', 36.3622, 127.3561, 0, 0),
    ('daejeon_daedeok', '대덕구', '대전 대덕구', '대전', '대덕구', 36.3467, 127.4157, 0, 0),
    ('gwangju_dong', '광주 동구', '광주 동구', '광주', '동구', 35.1460, 126.9231, 0, 0),
    ('gwangju_seo', '광주 서구', '광주 서구', '광주', '서구', 35.1520, 126.8895, 0, 0),
    ('gwangju_nam', '광주 남구', '광주 남구', '광주', '남구', 35.1329, 126.9025, 0, 0),
    ('gwangju_buk', '광주 북구', '광주 북구', '광주', '북구', 35.1741, 126.9120, 0, 0),
    ('gwangju_gwangsan', '광산구', '광주 광산구', '광주', '광산구', 35.1396, 126.7937, 1, 0),
    ('ulsan_jung', '울산 중구', '울산 중구', '울산', '중구', 35.5694, 129.3328, 0, 0),
    ('ulsan_nam', '울산 남구', '울산 남구', '울산', '남구', 35.5438, 129.3301, 0, 0),
    ('ulsan_dong', '울산 동구', '울산 동구', '울산', '동구', 35.5050, 129.4166, 0, 0),
    ('ulsan_buk', '울산 북구', '울산 북구', '울산', '북구', 35.5826, 129.3612, 0, 0),
    ('ulsan_ulju', '울주군', '울산 울주군', '울산', '울주군', 35.5222, 129.2424, 0, 0),
    ('sejong', '세종시', '세종특별자치시', '세종', '세종시', 36.4800, 127.2890, 0, 0),
    ('gw_chuncheon', '춘천시', '강원 춘천시', '강원', '춘천시', 37.8813, 127.7298, 0, 0),
    ('gw_wonju', '원주시', '강원 원주시', '강원', '원주시', 37.3422, 127.9202, 0, 0),
    ('gw_gangneung', '강릉시', '강원 강릉시', '강원', '강릉시', 37.7519, 128.8761, 0, 0),
    ('gw_donghae', '동해시', '강원 동해시', '강원', '동해시', 37.5247, 129.1143, 0, 0),
    ('gw_taebaek', '태백시', '강원 태백시', '강원', '태백시', 37.1641, 128.9856, 0, 0),
    ('gw_sokcho', '속초시', '강원 속초시', '강원', '속초시', 38.2070, 128.5918, 0, 0),
    ('gw_samcheok', '삼척시', '강원 삼척시', '강원', '삼척시', 37.4499, 129.1652, 0, 0),
    ('gw_hongcheon', '홍천군', '강원 홍천군', '강원', '홍천군', 37.6970, 127.8887, 0, 0),
    ('gw_hoengseong', '횡성군', '강원 횡성군', '강원', '횡성군', 37.4918, 127.9850, 0, 0),
    ('gw_yeongwol', '영월군', '강원 영월군', '강원', '영월군', 37.1836, 128.4618, 0, 0),
    ('gw_pyeongchang', '평창군', '강원 평창군', '강원', '평창군', 37.3708, 128.3902, 0, 0),
    ('gw_jeongseon', '정선군', '강원 정선군', '강원', '정선군', 37.3806, 128.6608, 0, 0),
    ('gw_cheorwon', '철원군', '강원 철원군', '강원', '철원군', 38.1466, 127.3133, 0, 0),
    ('gw_hwacheon', '화천군', '강원 화천군', '강원', '화천군', 38.1062, 127.7082, 0, 0),
    ('gw_yanggu', '양구군', '강원 양구군', '강원', '양구군', 38.1099, 127.9899, 0, 0),
    ('gw_inje', '인제군', '강원 인제군', '강원', '인제군', 38.0697, 128.1703, 0, 0),
    ('gw_goseong', '고성군', '강원 고성군', '강원', '고성군', 38.3806, 128.4678, 0, 0),
    ('gw_yangyang', '양양군', '강원 양양군', '강원', '양양군', 38.0754, 128.6189, 0, 0),
    ('cb_cheongju', '청주시', '충북 청주시', '충북', '청주시', 36.6424, 127.4890, 0, 0),
    ('cb_chungju', '충주시', '충북 충주시', '충북', '충주시', 36.9910, 127.9259, 0, 0),
    ('cb_jecheon', '제천시', '충북 제천시', '충북', '제천시', 37.1326, 128.1909, 0, 0),
    ('cb_boeun', '보은군', '충북 보은군', '충북', '보은군', 36.4894, 127.7295, 0, 0),
    ('cb_okcheon', '옥천군', '충북 옥천군', '충북', '옥천군', 36.3064, 127.5714, 0, 0),
    ('cb_yeongdong', '영동군', '충북 영동군', '충북', '영동군', 36.1750, 127.7834, 0, 0),
    ('cb_jeungpyeong', '증평군', '충북 증평군', '충북', '증평군', 36.7854, 127.5815, 0, 0),
    ('cb_jincheon', '진천군', '충북 진천군', '충북', '진천군', 36.8554, 127.4355, 0, 0),
    ('cb_goesan', '괴산군', '충북 괴산군', '충북', '괴산군', 36.8153, 127.7867, 0, 0),
    ('cb_eumseong', '음성군', '충북 음성군', '충북', '음성군', 36.9403, 127.6905, 0, 0),
    ('cb_danyang', '단양군', '충북 단양군', '충북', '단양군', 36.9845, 128.3655, 0, 0),
    ('cn_cheonan', '천안시', '충남 천안시', '충남', '천안시', 36.8151, 127.1139, 0, 0),
    ('cn_gongju', '공주시', '충남 공주시', '충남', '공주시', 36.4465, 127.1190, 0, 0),
    ('cn_boryeong', '보령시', '충남 보령시', '충남', '보령시', 36.3334, 126.6129, 0, 0),
    ('cn_asan', '아산시', '충남 아산시', '충남', '아산시', 36.7898, 127.0018, 0, 0),
    ('cn_seosan', '서산시', '충남 서산시', '충남', '서산시', 36.7845, 126.4503, 0, 0),
    ('cn_nonsan', '논산시', '충남 논산시', '충남', '논산시', 36.1872, 127.0989, 0, 0),
    ('cn_gyeryong', '계룡시', '충남 계룡시', '충남', '계룡시', 36.2745, 127.2486, 0, 0),
    ('cn_dangjin', '당진시', '충남 당진시', '충남', '당진시', 36.8936, 126.6283, 0, 0),
    ('cn_geumsan', '금산군', '충남 금산군', '충남', '금산군', 36.1086, 127.4882, 0, 0),
    ('cn_buyeo', '부여군', '충남 부여군', '충남', '부여군', 36.2758, 126.9098, 0, 0),
    ('cn_seocheon', '서천군', '충남 서천군', '충남', '서천군', 36.0803, 126.6914, 0, 0),
    ('cn_cheongyang', '청양군', '충남 청양군', '충남', '청양군', 36.4590, 126.8022, 0, 0),
    ('cn_hongseong', '홍성군', '충남 홍성군', '충남', '홍성군', 36.6013, 126.6608, 0, 0),
    ('cn_yesan', '예산군', '충남 예산군', '충남', '예산군', 36.6826, 126.8484, 0, 0),
    ('cn_taean', '태안군', '충남 태안군', '충남', '태안군', 36.7456, 126.2979, 0, 0),
    ('jb_jeonju', '전주시', '전북 전주시', '전북', '전주시', 35.8242, 127.1480, 0, 0),
    ('jb_gunsan', '군산시', '전북 군산시', '전북', '군산시', 35.9677, 126.7366, 0, 0),
    ('jb_iksan', '익산시', '전북 익산시', '전북', '익산시', 35.9483, 126.9576, 0, 0),
    ('jb_jeongeup', '정읍시', '전북 정읍시', '전북', '정읍시', 35.5699, 126.8560, 0, 0),
    ('jb_namwon', '남원시', '전북 남원시', '전북', '남원시', 35.4164, 127.3904, 0, 0),
    ('jb_gimje', '김제시', '전북 김제시', '전북', '김제시', 35.8036, 126.8808, 0, 0),
    ('jb_wanju', '완주군', '전북 완주군', '전북', '완주군', 35.9047, 127.1620, 0, 0),
    ('jb_jinan', '진안군', '전북 진안군', '전북', '진안군', 35.7918, 127.4249, 0, 0),
    ('jb_무주', '무주군', '전북 무주군', '전북', '무주군', 36.0068, 127.6608, 0, 0),
    ('jb_jangsu', '장수군', '전북 장수군', '전북', '장수군', 35.6474, 127.5215, 0, 0),
    ('jb_imsil', '임실군', '전북 임실군', '전북', '임실군', 35.6178, 127.2891, 0, 0),
    ('jb_sunchang', '순창군', '전북 순창군', '전북', '순창군', 35.3744, 127.1374, 0, 0),
    ('jb_gochang', '고창군', '전북 고창군', '전북', '고창군', 35.4358, 126.7020, 0, 0),
    ('jb_buan', '부안군', '전북 부안군', '전북', '부안군', 35.7318, 126.7330, 0, 0),
    ('jn_mokpo', '목포시', '전남 목포시', '전남', '목포시', 34.8118, 126.3922, 0, 0),
    ('jn_yeosu', '여수시', '전남 여수시', '전남', '여수시', 34.7604, 127.6622, 14, 0),
    ('jn_suncheon', '순천시', '전남 순천시', '전남', '순천시', 34.9506, 127.4872, 0, 0),
    ('jn_naju', '나주시', '전남 나주시', '전남', '나주시', 35.0158, 126.7108, 0, 0),
    ('jn_gwangyang', '광양시', '전남 광양시', '전남', '광양시', 34.9407, 127.6959, 0, 0),
    ('jn_damyang', '담양군', '전남 담양군', '전남', '담양군', 35.3211, 126.9882, 1, 0),
    ('jn_gokseong', '곡성군', '전남 곡성군', '전남', '곡성군', 35.2820, 127.2919, 18, 0),
    ('jn_gurye', '구례군', '전남 구례군', '전남', '구례군', 35.2025, 127.4628, 0, 0),
    ('jn_goheung', '고흥군', '전남 고흥군', '전남', '고흥군', 34.6112, 127.2850, 0, 0),
    ('jn_boseong', '보성군', '전남 보성군', '전남', '보성군', 34.7715, 127.0800, 0, 0),
    ('jn_hwasun', '화순군', '전남 화순군', '전남', '화순군', 35.0645, 126.9865, 0, 0),
    ('jn_jangheung', '장흥군', '전남 장흥군', '전남', '장흥군', 34.6817, 126.9069, 0, 0),
    ('jn_gangjin', '강진군', '전남 강진군', '전남', '강진군', 34.6421, 126.7672, 0, 0),
    ('jn_haenam', '해남군', '전남 해남군', '전남', '해남군', 34.5735, 126.5989, 35, 0),
    ('jn_yeongam', '영암군', '전남 영암군', '전남', '영암군', 34.8002, 126.6968, 1, 0),
    ('jn_muan', '무안군', '전남 무안군', '전남', '무안군', 34.9904, 126.4817, 46, 0),
    ('jn_hampyeong', '함평군', '전남 함평군', '전남', '함평군', 35.0659, 126.5165, 0, 0),
    ('jn_yeonggwang', '영광군', '전남 영광군', '전남', '영광군', 35.2772, 126.5120, 0, 0),
    ('jn_jangseong', '장성군', '전남 장성군', '전남', '장성군', 35.3019, 126.7848, 0, 0),
    ('jn_wando', '완도군', '전남 완도군', '전남', '완도군', 34.3110, 126.7550, 0, 0),
    ('jn_jindo', '진도군', '전남 진도군', '전남', '진도군', 34.4868, 126.2635, 10, 0),
    ('jn_sinan', '신안군', '전남 신안군', '전남', '신안군', 34.8336, 126.1086, 0, 0),
    ('gb_pohang', '포항시', '경북 포항시', '경북', '포항시', 36.0190, 129.3435, 0, 0),
    ('gb_gyeongju', '경주시', '경북 경주시', '경북', '경주시', 35.8562, 129.2247, 0, 0),
    ('gb_gimcheon', '김천시', '경북 김천시', '경북', '김천시', 36.1398, 128.1136, 0, 0),
    ('gb_andong', '안동시', '경북 안동시', '경북', '안동시', 36.5684, 128.7294, 0, 0),
    ('gb_gumi', '구미시', '경북 구미시', '경북', '구미시', 36.1195, 128.3446, 19, 0),
    ('gb_yeongju', '영주시', '경북 영주시', '경북', '영주시', 36.8057, 128.6241, 0, 0),
    ('gb_yeongcheon', '영천시', '경북 영천시', '경북', '영천시', 35.9733, 128.9386, 0, 0),
    ('gb_sangju', '상주시', '경북 상주시', '경북', '상주시', 36.4109, 128.1591, 0, 0),
    ('gb_mungyeong', '문경시', '경북 문경시', '경북', '문경시', 36.5865, 128.1868, 0, 0),
    ('gb_gyeongsan', '경산시', '경북 경산시', '경북', '경산시', 35.8251, 128.7413, 0, 0),
    ('gb_uiseong', '의성군', '경북 의성군', '경북', '의성군', 36.3527, 128.6970, 0, 0),
    ('gb_cheongsong', '청송군', '경북 청송군', '경북', '청송군', 36.4363, 129.0571, 0, 0),
    ('gb_yeongyang', '영양군', '경북 영양군', '경북', '영양군', 36.6667, 129.1125, 0, 0),
    ('gb_yeongdeok', '영덕군', '경북 영덕군', '경북', '영덕군', 36.4151, 129.3653, 0, 0),
    ('gb_cheongdo', '청도군', '경북 청도군', '경북', '청도군', 35.6473, 128.7340, 0, 0),
    ('gb_goryeong', '고령군', '경북 고령군', '경북', '고령군', 35.7261, 128.2629, 0, 0),
    ('gb_seongju', '성주군', '경북 성주군', '경북', '성주군', 35.9191, 128.2830, 0, 0),
    ('gb_chilgok', '칠곡군', '경북 칠곡군', '경북', '칠곡군', 35.9954, 128.4017, 0, 0),
    ('gb_예천', '예천군', '경북 예천군', '경북', '예천군', 36.6577, 128.4528, 0, 0),
    ('gb_bonghwa', '봉화군', '경북 봉화군', '경북', '봉화군', 36.8931, 128.7324, 0, 0),
    ('gb_uljin', '울진군', '경북 울진군', '경북', '울진군', 36.9931, 129.4004, 0, 0),
    ('gb_ulleung', '울릉군', '경북 울릉군', '경북', '울릉군', 37.4844, 130.9057, 0, 0),
    ('gn_changwon', '창원시', '경남 창원시', '경남', '창원시', 35.2280, 128.6811, 0, 0),
    ('gn_jinju', '진주시', '경남 진주시', '경남', '진주시', 35.1800, 128.1076, 0, 0),
    ('gn_tongyeong', '통영시', '경남 통영시', '경남', '통영시', 34.8544, 128.4332, 0, 0),
    ('gn_sacheon', '사천시', '경남 사천시', '경남', '사천시', 35.0038, 128.0642, 0, 0),
    ('gn_gimhae', '김해시', '경남 김해시', '경남', '김해시', 35.2285, 128.8894, 0, 0),
    ('gn_miryang', '밀양시', '경남 밀양시', '경남', '밀양시', 35.5038, 128.7464, 0, 0),
    ('gn_geoje', '거제시', '경남 거제시', '경남', '거제시', 34.8806, 128.6211, 0, 0),
    ('gn_yangsan', '양산시', '경남 양산시', '경남', '양산시', 35.3350, 129.0372, 0, 0),
    ('gn_uiryeong', '의령군', '경남 의령군', '경남', '의령군', 35.3222, 128.2617, 0, 0),
    ('gn_haman', '함안군', '경남 함안군', '경남', '함안군', 35.2726, 128.4065, 0, 0),
    ('gn_changnyeong', '창녕군', '경남 창녕군', '경남', '창녕군', 35.5446, 128.4922, 0, 0),
    ('gn_goseong', '경남 고성군', '경남 고성군', '경남', '고성군', 34.9731, 128.3222, 0, 0),
    ('gn_namhae', '남해군', '경남 남해군', '경남', '남해군', 34.8377, 127.8924, 0, 0),
    ('gn_hadong', '하동군', '경남 하동군', '경남', '하동군', 35.0672, 127.7513, 0, 0),
    ('gn_sancheong', '산청군', '경남 산청군', '경남', '산청군', 35.4156, 127.8735, 0, 0),
    ('gn_hamyang', '함양군', '경남 함양군', '경남', '함양군', 35.5205, 127.7252, 0, 0),
    ('gn_geochang', '거창군', '경남 거창군', '경남', '거창군', 35.6867, 127.9095, 0, 0),
    ('gn_hapcheon', '합천군', '경남 합천군', '경남', '합천군', 35.5666, 128.1658, 0, 0),
    ('jeju_jeju', '제주시', '제주 제주시', '제주', '제주시', 33.4996, 126.5312, 0, 0),
    ('jeju_seogwipo', '서귀포시', '제주 서귀포시', '제주', '서귀포시', 33.2541, 126.5601, 0, 0)
ON CONFLICT (code) DO UPDATE SET
    name = EXCLUDED.name,
    full_name = EXCLUDED.full_name,
    sido_key = EXCLUDED.sido_key,
    sigungu_name = EXCLUDED.sigungu_name,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    updated_at = NOW();

-- 4. smoking_areas 데이터 보정 (ID 오타 수정 및 시·군·구 누락 주소 보완)
-- (1) 구미시 ID 오타 수정 (gumi_ -> gumi_18)
UPDATE public.smoking_areas
SET id = 'gumi_18'
WHERE id = 'gumi_'
  AND NOT EXISTS (SELECT 1 FROM public.smoking_areas WHERE id = 'gumi_18');

-- (2) 무안군(muan_*) 시·군·구 누락 주소에 '전라남도 무안군' 추가
UPDATE public.smoking_areas
SET rdnmadr = '전라남도 무안군 ' || BTRIM(rdnmadr)
WHERE id LIKE 'muan_%'
  AND COALESCE(rdnmadr, '') <> ''
  AND rdnmadr NOT LIKE '%무안군%';

-- (3) 해남군(haenam_*) 시·군·구 누락 주소에 '전라남도 해남군' 추가
UPDATE public.smoking_areas
SET rdnmadr = '전라남도 해남군 ' || BTRIM(rdnmadr)
WHERE id LIKE 'haenam_%'
  AND COALESCE(rdnmadr, '') <> ''
  AND rdnmadr NOT LIKE '%해남군%';

-- 5. 주소 단어(w1, w2) 및 평균 좌표를 229개 시·군·구 코드(code)로 매핑하는 헬퍼 함수
--    (도로명주소/지번주소 중 한 가지만 있어도 작동하며, 전남·광주·전남광주·전남광주통합시·전남광주통합특별시를 통합 처리)
CREATE OR REPLACE FUNCTION public.resolve_district_code(
    p_w1 TEXT,
    p_w2 TEXT,
    p_lat NUMERIC,
    p_lng NUMERIC
) RETURNS VARCHAR(50)
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_code VARCHAR(50);
    v_sgg TEXT;
BEGIN
    -- (1) 세종특별자치시 예외 처리
    IF p_w1 LIKE '세종%' OR p_w2 LIKE '세종%' THEN
        RETURN 'sejong';
    END IF;

    -- (2) 인천 남구(구 명칭) -> 인천 미추홀구 매핑
    IF p_w1 LIKE '인천%' AND p_w2 = '남구' THEN
        RETURN 'incheon_michuhol';
    END IF;

    -- (3) 군위군(경북 -> 대구 편입) 매핑
    IF p_w1 = '군위군' OR p_w2 = '군위군' THEN
        RETURN 'daegu_gunwi';
    END IF;

    -- (4) 시·도 및 시·군·구가 생략된 읍·면 단위 주소 처리 (무안군 / 해남군 등)
    IF p_w1 IN ('무안읍', '삼향읍', '일로읍', '청계면', '해제면', '몽탄면', '현경면', '망운면', '운남면') THEN
        RETURN 'jn_muan';
    END IF;

    IF p_w1 IN ('해남읍', '옥천면', '산이면', '송지면', '문내면', '화원면', '계곡면', '삼산면', '화산면', '현산면', '북평면', '북일면')
       AND COALESCE(p_lat, 34.57) < 35.0 THEN
        RETURN 'jn_haenam';
    END IF;

    -- (5) w2 또는 w1에서 시·군·구명 추출
    IF EXISTS (SELECT 1 FROM public.district_counts WHERE sigungu_name = p_w2) THEN
        v_sgg := p_w2;
    ELSIF EXISTS (SELECT 1 FROM public.district_counts WHERE sigungu_name = p_w1) THEN
        v_sgg := p_w1;
    ELSE
        v_sgg := NULL;
    END IF;

    -- (6) 시·군·구명이 매칭된 경우 (단일 지역이면 즉시 반환, 동명이인 구·군은 시·도명/좌표로 구분)
    --     전남 / 광주 / 전남광주 / 전남광주통합시 / 전남광주통합특별시는 모두 동일 권역으로 함께 취급
    IF v_sgg IS NOT NULL THEN
        SELECT d.code
        INTO v_code
        FROM public.district_counts d
        WHERE d.sigungu_name = v_sgg
        ORDER BY
            CASE
                WHEN p_w1 LIKE d.sido_key || '%' THEN 0
                WHEN d.sido_key IN ('광주', '전남')
                     AND (p_w1 LIKE '%전남%' OR p_w1 LIKE '전라남도%' OR p_w1 LIKE '%광주%') THEN 0
                WHEN d.sido_key = '경북' AND p_w1 LIKE '경상북도%' THEN 0
                WHEN d.sido_key = '경남' AND p_w1 LIKE '경상남도%' THEN 0
                WHEN d.sido_key = '충북' AND p_w1 LIKE '충청북도%' THEN 0
                WHEN d.sido_key = '충남' AND p_w1 LIKE '충청남도%' THEN 0
                WHEN d.sido_key = '전북' AND (p_w1 LIKE '전라북도%' OR p_w1 LIKE '전북%') THEN 0
                ELSE 1
            END ASC,
            ((d.latitude - COALESCE(p_lat, d.latitude)) ^ 2 + (d.longitude - COALESCE(p_lng, d.longitude)) ^ 2) ASC
        LIMIT 1;

        IF v_code IS NOT NULL THEN
            RETURN v_code;
        END IF;
    END IF;

    -- (7) 주소에 시·군·구명이 아예 없는 경우 좌표 기준 가장 가까운 시·군·구로 매핑
    IF p_lat IS NOT NULL AND p_lng IS NOT NULL THEN
        SELECT d.code
        INTO v_code
        FROM public.district_counts d
        ORDER BY ((d.latitude - p_lat) ^ 2 + (d.longitude - p_lng) ^ 2) ASC
        LIMIT 1;
        RETURN v_code;
    END IF;

    RETURN NULL;
END;
$$ ;

-- 5. 흡연구역(smoking_areas) 개수만 빠르게 재집계하는 함수 (데이터 추가 시 수 밀리초 내 완료)
CREATE OR REPLACE FUNCTION public.refresh_smoking_counts()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    WITH addr_groups AS (
        SELECT
            split_part(LTRIM(COALESCE(NULLIF(BTRIM(rdnmadr), ''), NULLIF(BTRIM(lnmadr), ''), '')), ' ', 1) AS w1,
            split_part(LTRIM(COALESCE(NULLIF(BTRIM(rdnmadr), ''), NULLIF(BTRIM(lnmadr), ''), '')), ' ', 2) AS w2,
            AVG(latitude) AS avg_lat,
            AVG(longitude) AS avg_lng,
            COUNT(*)::INTEGER AS cnt
        FROM public.smoking_areas
        GROUP BY 1, 2
    ),
    mapped AS (
        SELECT
            public.resolve_district_code(w1, w2, avg_lat, avg_lng) AS code,
            SUM(cnt)::INTEGER AS total_cnt
        FROM addr_groups
        GROUP BY 1
    )
    UPDATE public.district_counts d
    SET
        smoking_count = COALESCE(m.total_cnt, 0),
        updated_at = NOW()
    FROM (
        SELECT dc.code, mp.total_cnt
        FROM public.district_counts dc
        LEFT JOIN mapped mp ON mp.code = dc.code
    ) m
    WHERE d.code = m.code;
END;
$$ ;

-- 6. 흡연구역 + 금연구역(55만+ 건) 전체를 1회 스캔으로 고속 집계하는 함수
CREATE OR REPLACE FUNCTION public.refresh_district_counts()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- (1) 흡연구역 집계 갱신
    PERFORM public.refresh_smoking_counts();

    -- (2) 금연구역 집계 갱신 (단일 GROUP BY 스캔 후 매핑하여 1초 내 처리)
    WITH addr_groups AS (
        SELECT
            split_part(LTRIM(COALESCE(NULLIF(BTRIM(rdnmadr), ''), NULLIF(BTRIM(lnmadr), ''), '')), ' ', 1) AS w1,
            split_part(LTRIM(COALESCE(NULLIF(BTRIM(rdnmadr), ''), NULLIF(BTRIM(lnmadr), ''), '')), ' ', 2) AS w2,
            AVG(latitude) AS avg_lat,
            AVG(longitude) AS avg_lng,
            COUNT(*)::INTEGER AS cnt
        FROM public.non_smoking_areas
        GROUP BY 1, 2
    ),
    mapped AS (
        SELECT
            public.resolve_district_code(w1, w2, avg_lat, avg_lng) AS code,
            SUM(cnt)::INTEGER AS total_cnt
        FROM addr_groups
        GROUP BY 1
    )
    UPDATE public.district_counts d
    SET
        non_smoking_count = COALESCE(m.total_cnt, 0),
        updated_at = NOW()
    FROM (
        SELECT dc.code, mp.total_cnt
        FROM public.district_counts dc
        LEFT JOIN mapped mp ON mp.code = dc.code
    ) m
    WHERE d.code = m.code;
END;
$$ ;

-- 7. smoking_areas 테이블에 데이터 추가/수정/삭제 시 자동으로 district_counts.smoking_count 동기화 트리거
CREATE OR REPLACE FUNCTION public.trg_sync_smoking_counts()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    PERFORM public.refresh_smoking_counts();
    RETURN NULL;
END;
$$ ;

DROP TRIGGER IF EXISTS trg_smoking_areas_count_sync ON public.smoking_areas;
CREATE TRIGGER trg_smoking_areas_count_sync
    AFTER INSERT OR UPDATE OR DELETE ON public.smoking_areas
    FOR EACH STATEMENT
    EXECUTE FUNCTION public.trg_sync_smoking_counts();

-- 8. 최초 1회 전체 집계 즉시 실행 (smoking_areas + non_smoking_areas)
SELECT public.refresh_district_counts();