const fs = require('fs');
const path = require('path');

const SERVICE_KEY = 'gmEfo21K0CwlPVfkCLdiUlo390I1j5qZutzQfdDeotTDrylJEEm5IizrVpJ8j7DXy3lkohkvlTJ3mdSZqoXJzw%3D%3D';
const SUPABASE_URL = 'https://cqtojdswnwgshqhnwzmg.supabase.co';
const SUPABASE_ANON_KEY = 'sb_publishable_4nbwJnVgf34sKrCKpNsSTQ_zy8QudVU';

const STATE_FILE = path.join(__dirname, 'import_state.json');

// 시작 페이지 및 시작 ID 설정
const DEFAULT_START_PAGE = 51; // 1페이지당 1000개 -> 50,000개 완료 후 51페이지부터
const DEFAULT_START_ID = 50001;
const NUM_OF_ROWS = 1000;

function loadState() {
  if (fs.existsSync(STATE_FILE)) {
    try {
      const data = JSON.parse(fs.readFileSync(STATE_FILE, 'utf8'));
      return data;
    } catch (e) {
      console.warn('상태 파일 읽기 실패, 기본값 사용');
    }
  }
  return { currentPage: DEFAULT_START_PAGE, nextId: DEFAULT_START_ID, totalInserted: 0 };
}

function saveState(currentPage, nextId, totalInserted) {
  fs.writeFileSync(STATE_FILE, JSON.stringify({ currentPage, nextId, totalInserted }, null, 2), 'utf8');
}

async function fetchPage(pageNo) {
  const url = `https://api.data.go.kr/openapi/tn_pubr_public_prhsmk_zn_api?serviceKey=${SERVICE_KEY}&pageNo=${pageNo}&numOfRows=${NUM_OF_ROWS}&type=json`;
  
  for (let retry = 0; retry < 5; retry++) {
    try {
      const res = await fetch(url);
      if (!res.ok) {
        throw new Error(`HTTP ${res.status} ${res.statusText}`);
      }
      const data = await res.json();
      const items = data.body?.items?.item || [];
      const totalCount = data.body?.totalCount || 0;
      return { items, totalCount };
    } catch (err) {
      console.warn(`[Page ${pageNo}] API 요청 실패 (${retry + 1}/5): ${err.message}. 2초 후 재시도...`);
      await new Promise(r => setTimeout(r, 2000));
    }
  }
  throw new Error(`[Page ${pageNo}] 5회 재시도 후 API 요청 최종 실패`);
}

async function insertBatch(records) {
  if (records.length === 0) return true;

  const url = `${SUPABASE_URL}/rest/v1/non_smoking_areas`;
  for (let retry = 0; retry < 5; retry++) {
    try {
      const res = await fetch(url, {
        method: 'POST',
        headers: {
          'apikey': SUPABASE_ANON_KEY,
          'Authorization': `Bearer ${SUPABASE_ANON_KEY}`,
          'Content-Type': 'application/json',
          'Prefer': 'return=minimal'
        },
        body: JSON.stringify(records)
      });

      if (res.status === 201 || res.status === 200) {
        return true;
      }

      const errorText = await res.text();
      if (res.status === 401 || res.status === 403 || errorText.includes('row-level security')) {
        console.error('\n🚨 [Supabase RLS 오류] 테이블에 INSERT 권한이 없습니다!');
        console.error('Supabase SQL Editor에서 아래 쿼리를 1회 실행해 주세요:');
        console.error('--------------------------------------------------');
        console.error('CREATE POLICY "Allow public insert for non_smoking_areas" ON public.non_smoking_areas FOR INSERT WITH CHECK (true);');
        console.error('--------------------------------------------------\n');
        process.exit(1);
      }

      throw new Error(`HTTP ${res.status}: ${errorText}`);
    } catch (err) {
      if (err.message.includes('RLS 오류')) throw err;
      console.warn(`[Supabase Insert] 실패 (${retry + 1}/5): ${err.message}. 2초 후 재시도...`);
      await new Promise(r => setTimeout(r, 2000));
    }
  }
  throw new Error('Supabase Insert 5회 재시도 실패');
}

function parseRecord(item, id) {
  let lat = parseFloat(item.latitude);
  let lng = parseFloat(item.longitude);
  if (isNaN(lat) || lat < 30 || lat > 45) lat = null;
  if (isNaN(lng) || lng < 120 || lng > 135) lng = null;

  let areaAr = null;
  if (item.prhsmkAr && item.prhsmkAr.trim() !== '') {
    const parsedAr = parseFloat(item.prhsmkAr);
    if (!isNaN(parsedAr)) areaAr = parsedAr;
  }

  return {
    id: String(id),
    area_nm: (item.prhsmkNm || '지정 금연구역').trim().substring(0, 255),
    area_desc: item.prhsmkScopeDesc ? item.prhsmkScopeDesc.trim() : null,
    area_ar: areaAr,
    latitude: lat,
    longitude: lng,
    lnmadr: item.lnmadr ? item.lnmadr.trim().substring(0, 500) : null,
    rdnmadr: item.rdnmadr ? item.rdnmadr.trim().substring(0, 500) : null,
    ref_date: item.referenceDate ? item.referenceDate.trim().substring(0, 20) : null,
  };
}

async function main() {
  console.log('====================================================');
  console.log('🚀 전국 금연구역 공공데이터 Supabase 일괄 적재 시작');
  console.log('====================================================');

  const state = loadState();
  let currentPage = state.currentPage;
  let nextId = state.nextId;
  let totalInserted = state.totalInserted;

  console.log(`시작 위치: 페이지 ${currentPage}부터, 시작 ID: ${nextId}`);

  // 1페이지 메타데이터 확인 (총 개수 계산)
  const { totalCount } = await fetchPage(1);
  const totalPages = Math.ceil(totalCount / NUM_OF_ROWS);
  console.log(`공공데이터 전체 건수: ${totalCount.toLocaleString()}건 (총 ${totalPages}페이지)`);
  console.log(`적재 대상: ${nextId.toLocaleString()}번부터 ~ ${totalCount.toLocaleString()}번까지\n`);

  const startTime = Date.now();

  while (currentPage <= totalPages) {
    const pageStartTime = Date.now();
    const { items } = await fetchPage(currentPage);

    if (items.length === 0) {
      console.log(`[Page ${currentPage}] 더 이상 데이터가 없습니다. 완료.`);
      break;
    }

    const records = items.map(item => {
      const record = parseRecord(item, nextId);
      nextId++;
      return record;
    });

    await insertBatch(records);
    totalInserted += records.length;

    saveState(currentPage + 1, nextId, totalInserted);

    const elapsedTotalSec = (Date.now() - startTime) / 1000;
    const pageElapsedSec = (Date.now() - pageStartTime) / 1000;
    const speed = totalInserted / elapsedTotalSec;
    const remainingItems = totalCount - nextId + 1;
    const estimatedRemainingSec = speed > 0 ? remainingItems / speed : 0;

    const progressPct = ((nextId - 1) / totalCount * 100).toFixed(2);

    console.log(
      `[Page ${currentPage}/${totalPages}] ${records.length}건 적재 완료 ` +
      `(ID: ${records[0].id} ~ ${records[records.length - 1].id}) | ` +
      `진행률: ${progressPct}% | ` +
      `속도: ${speed.toFixed(0)}건/초 | ` +
      `남은 예상시간: ${(estimatedRemainingSec / 60).toFixed(1)}분`
    );

    currentPage++;
    // 공공데이터 API Rate Limit 방지 100ms 대기
    await new Promise(r => setTimeout(r, 100));
  }

  console.log('\n====================================================');
  console.log(`🎉 모든 금연구역 데이터 적재가 성공적으로 완료되었습니다!`);
  console.log(`총 적재 수: ${totalInserted.toLocaleString()}건`);
  console.log('====================================================');
}

main().catch(err => {
  console.error('\n❌ 실행 중 치명적 에러 발생:', err);
  process.exit(1);
});
