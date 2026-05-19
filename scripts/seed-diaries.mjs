#!/usr/bin/env node
/**
 * 시드 일기 생성 스크립트
 *
 * 사용법:
 *   node scripts/seed-diaries.mjs --users 8,10,11,12,13 --days 7
 *   node scripts/seed-diaries.mjs --users 8-17 --days 5
 *   node scripts/seed-diaries.mjs --users 59 --days 10
 *
 * 옵션:
 *   --users   유저 ID (쉼표 구분 또는 범위, 예: 8,10,11 또는 8-17)
 *   --days    과거 며칠치 일기를 생성할지 (기본 7)
 *   --server  서버 URL (기본 https://ember-app.duckdns.org)
 *   --delay   요청 간 딜레이 ms (기본 500, AI 서버 부하 방지)
 */

const BASE = process.argv.includes('--server')
  ? process.argv[process.argv.indexOf('--server') + 1]
  : 'https://ember-app.duckdns.org';

const DELAY_MS = process.argv.includes('--delay')
  ? parseInt(process.argv[process.argv.indexOf('--delay') + 1])
  : 500;

// ── 유저 ID 파싱 ──────────────────────────────────────────────────────────────

function parseUsers() {
  const idx = process.argv.indexOf('--users');
  if (idx === -1 || !process.argv[idx + 1]) {
    console.error('사용법: node seed-diaries.mjs --users 8,10,11 --days 7');
    process.exit(1);
  }
  const raw = process.argv[idx + 1];
  if (raw.includes('-') && !raw.includes(',')) {
    const [start, end] = raw.split('-').map(Number);
    return Array.from({ length: end - start + 1 }, (_, i) => start + i);
  }
  return raw.split(',').map(Number);
}

function parseDays() {
  const idx = process.argv.indexOf('--days');
  return idx !== -1 ? parseInt(process.argv[idx + 1]) : 7;
}

// ── 샘플 일기 (200자 이상, 다양한 감정/주제) ──────────────────────────────────

const SAMPLE_DIARIES = [
  `오늘은 정말 기분 좋은 하루였다. 아침에 일어나자마자 창문을 열었는데 날씨가 너무 좋았다. 산책을 하면서 동네 카페에 들러 아메리카노 한 잔을 마셨다. 카페 테라스에서 따뜻한 햇살을 받으며 책을 읽었는데, 이런 여유가 정말 오랜만이었다. 바쁜 일상 속에서 이렇게 나만의 시간을 갖는 것이 얼마나 소중한지 다시 한번 깨달았다. 내일도 이렇게 좋은 날이 되었으면 좋겠다.`,

  `회사에서 힘든 일이 있었다. 프로젝트 마감이 코앞인데 갑자기 요구사항이 바뀌었다. 팀원들 모두 야근을 했지만 분위기가 무거웠다. 그래도 서로 격려하면서 버텼고, 결국 밤 11시에 겨우 마무리했다. 퇴근길에 편의점에서 맥주 한 캔을 사서 마시면서 걸었는데, 차가운 바람이 불어와서 기분이 조금 나아졌다. 힘들지만 이런 경험이 나를 성장시키는 거라고 생각하려고 노력했다.`,

  `주말에 부모님 댁에 다녀왔다. 엄마가 해주신 된장찌개가 정말 맛있었다. 오랜만에 가족들과 함께 식사를 하니까 마음이 따뜻해졌다. 아버지는 여전히 텃밭을 가꾸고 계셨는데, 토마토가 빨갛게 익어가고 있었다. 함께 텃밭에서 이야기를 나누다 보니 시간이 금방 지나갔다. 자주 와야겠다고 다짐했지만, 항상 바쁘다는 핑계로 미루게 된다. 다음에는 꼭 더 자주 찾아뵙겠다.`,

  `오늘 처음으로 볼더링을 해봤다. 친구가 추천해줘서 갔는데 생각보다 훨씬 어려웠다. 처음에는 팔이 떨리고 높은 곳이 무서웠지만, 한 루트를 완등했을 때의 성취감은 정말 대단했다. 온몸이 아프지만 기분은 최고였다. 새로운 것을 도전하는 것이 이렇게 설레는 일인 줄 몰랐다. 다음 주에도 가기로 했는데 벌써부터 기대된다. 운동을 통해 스트레스도 풀리고 자신감도 생기는 것 같다.`,

  `오늘 길을 걷다가 옛날에 자주 가던 분식집을 발견했다. 고등학교 때 친구들과 맨날 떡볶이를 먹으러 갔던 곳인데, 아직도 영업을 하고 있었다. 혼자 들어가서 떡볶이와 순대를 시켜 먹었다. 맛은 그때 그대로였다. 먹으면서 고등학교 시절이 떠올랐다. 그때는 고민이라고 해봐야 시험 성적뿐이었는데, 지금은 걱정할 것이 너무 많다. 그래도 이런 추억이 있어서 다행이다.`,

  `비가 오는 날이면 항상 감성적이 된다. 오늘도 창밖을 보면서 커피를 마셨다. 빗소리를 들으며 좋아하는 음악을 틀었다. 요즘 듣고 있는 재즈 플레이리스트가 비 오는 날과 정말 잘 어울린다. 이런 날은 아무것도 하고 싶지 않고 그냥 멍하니 있고 싶다. 가끔은 이렇게 아무것도 안 하는 시간이 필요하다고 생각한다. 내일은 다시 바쁜 하루가 시작되겠지만, 오늘만큼은 이 여유를 즐기고 싶다.`,

  `운동을 시작한 지 한 달이 됐다. 처음에는 5분도 못 뛰었는데 이제는 30분을 달릴 수 있게 됐다. 몸이 가벼워진 느낌이고 잠도 잘 온다. 무엇보다 아침에 일어나는 것이 덜 힘들어졌다. 같이 운동하는 사람들과도 친해져서 서로 응원해주는 것이 큰 힘이 된다. 건강한 습관을 만들어가고 있다는 것 자체가 뿌듯하다. 꾸준히 이어가는 것이 중요하다는 걸 몸소 느끼고 있다.`,

  `오랜만에 혼자 영화관에 갔다. 보고 싶었던 영화가 마침 개봉해서 바로 예매했다. 혼자 영화 보는 것을 좋아하는데, 아무 눈치 안 보고 내가 먹고 싶은 것 사서 편하게 볼 수 있어서 좋다. 영화가 생각보다 감동적이어서 눈물이 좀 났다. 끝나고 나와서 저녁을 먹으면서 영화 내용을 곱씹어봤다. 가끔은 이렇게 혼자만의 시간을 보내는 것도 나쁘지 않다.`,

  `요즘 새로 시작한 독서 모임이 정말 재미있다. 한 달에 한 권씩 책을 읽고 모여서 토론하는 형식인데, 다양한 관점을 들을 수 있어서 시야가 넓어지는 느낌이다. 이번 달 책은 심리학 관련 도서였는데, 읽으면서 나 자신에 대해 많이 생각하게 됐다. 모임 사람들도 좋은 사람들이라 대화가 즐겁다. 이런 활동을 더 일찍 시작할 걸 그랬다는 생각이 든다.`,

  `친구의 결혼식에 다녀왔다. 대학교 때부터 알고 지낸 친구인데 벌써 결혼을 하다니 시간이 정말 빠르다. 식장에서 다른 동기들도 만났는데, 다들 각자의 삶을 열심히 살고 있었다. 축하하면서도 한편으로는 나도 이런 날이 올까 하는 생각이 들었다. 결혼식 끝나고 2차로 카페에 가서 이야기꽃을 피웠다. 소중한 사람들과 함께하는 시간이 가장 행복하다는 것을 느꼈다.`,

  `오늘 봉사활동을 다녀왔다. 노인 복지관에서 어르신들과 함께 점심을 준비하고 대화를 나눴다. 할머니 한 분이 손을 잡으시며 고맙다고 하셨는데, 그 따뜻한 손길이 오래 기억에 남을 것 같다. 바쁜 일상에서 누군가를 위해 시간을 쓰는 것이 이렇게 보람찬 일인 줄 몰랐다. 매주는 어렵겠지만 한 달에 한 번은 꼭 참여하고 싶다. 작은 것이라도 나눌 수 있다는 것에 감사하다.`,

  `카페에서 공부를 하다가 옆 테이블 사람과 이야기를 나눴다. 알고 보니 같은 분야를 공부하고 있어서 서로 정보를 공유했다. 이런 우연한 만남이 참 좋다. 혼자 공부하면 지루하고 외로운데, 같은 목표를 가진 사람을 만나니 동기부여가 됐다. 연락처를 교환했는데 앞으로도 종종 만나서 같이 공부하기로 했다. 오늘은 생산적이면서도 즐거운 하루였다.`,

  `새벽에 잠이 안 와서 산책을 나갔다. 조용한 거리를 걸으면서 별을 봤다. 도시에서는 별이 잘 안 보이는데 오늘따라 유난히 맑아서 몇 개가 보였다. 걸으면서 이런저런 생각을 했다. 앞으로 어떻게 살아야 할지, 지금 하고 있는 일이 맞는 건지. 답은 안 나왔지만 걷고 나니 마음이 한결 편안해졌다. 가끔은 이렇게 멈춰서 생각하는 시간이 필요하다.`,

  `요리를 해봤다. 유튜브에서 본 파스타 레시피를 따라 했는데 생각보다 잘 됐다. 직접 만든 음식을 먹으니까 뿌듯하고 맛도 좋았다. 앞으로 배달 대신 직접 요리를 좀 더 자주 해봐야겠다. 건강에도 좋고 돈도 절약되고 일석이조다. 다음에는 한식에도 도전해봐야겠다. 엄마한테 된장찌개 레시피를 물어봐야지. 혼자 살면서 이런 소소한 즐거움을 찾아가는 것도 나쁘지 않다.`,

  `오늘 면접을 봤다. 떨려서 말을 잘 못했는데 면접관분이 편하게 해주셔서 나중에는 괜찮았다. 결과가 어떻게 될지 모르겠지만 최선을 다했다고 생각한다. 면접 끝나고 친구를 만나서 이야기를 나눴는데 친구가 잘했을 거라고 격려해줬다. 결과에 상관없이 이 과정에서 배운 것이 많다. 자기소개서 쓰면서 나 자신에 대해 깊이 생각해볼 수 있었고, 면접 준비하면서 말하는 연습도 많이 했다.`,
];

// ── 날짜 유틸 ──────────────────────────────────────────────────────────────────

function formatDate(date) {
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, '0');
  const d = String(date.getDate()).padStart(2, '0');
  return `${y}-${m}-${d}`;
}

function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

// ── 메인 ──────────────────────────────────────────────────────────────────────

async function main() {
  const userIds = parseUsers();
  const days = parseDays();

  console.log(`\n🔥 시드 일기 생성 시작`);
  console.log(`   서버: ${BASE}`);
  console.log(`   유저: ${userIds.join(', ')} (${userIds.length}명)`);
  console.log(`   일수: ${days}일 (오늘 포함 과거 ${days}일치)`);
  console.log(`   예상 생성: ${userIds.length * days}건\n`);

  let success = 0, skipped = 0, failed = 0;
  const today = new Date();

  for (const userId of userIds) {
    // 유저별 토큰 발급 (dev 엔드포인트는 토큰 불필요하지만 확인용)
    console.log(`--- userId=${userId} ---`);

    for (let d = days - 1; d >= 0; d--) {
      const date = new Date(today);
      date.setDate(date.getDate() - d);
      const dateStr = formatDate(date);

      // 유저별로 다른 일기 배정 (userId + 날짜 기반 인덱스)
      const diaryIdx = (userId * 7 + d) % SAMPLE_DIARIES.length;
      const content = SAMPLE_DIARIES[diaryIdx];

      try {
        const res = await fetch(`${BASE}/api/dev/diaries`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ userId, content, date: dateStr }),
        });

        const data = await res.json();

        if (data.error === 'DUPLICATE') {
          console.log(`  ${dateStr} — 스킵 (이미 존재)`);
          skipped++;
        } else if (data.diaryId) {
          console.log(`  ${dateStr} — 생성 (diaryId=${data.diaryId})`);
          success++;
        } else {
          console.log(`  ${dateStr} — 실패:`, JSON.stringify(data));
          failed++;
        }
      } catch (err) {
        console.log(`  ${dateStr} — 에러: ${err.message}`);
        failed++;
      }

      await sleep(DELAY_MS);
    }
  }

  console.log(`\n📊 결과 요약`);
  console.log(`   성공: ${success}건`);
  console.log(`   스킵: ${skipped}건 (중복)`);
  console.log(`   실패: ${failed}건`);
  console.log(`\n   AI 분석은 5~10초 후 자동 반영됩니다.\n`);
}

main().catch(console.error);
