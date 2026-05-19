#
# run_all.ps1 — 시드 SQL 5종을 순서대로 실행
#
# 사전 조건:
#   1. docker compose -f docker-compose.local.yml up -d  (PG 컨테이너 기동)
#   2. cd Backend && ./gradlew bootRun  (한 번 부팅해 스키마 초기화)
#   3. POST /api/dev/register  로 본인 userId 발급
#
# 사용:
#   .\Backend\scripts\seed\run_all.ps1 -TesterId 123
#

param(
    [Parameter(Mandatory=$true)]
    [int]$TesterId,

    [string]$Container = "ember-local-postgres",
    [string]$DbUser    = "ember",
    [string]$DbName    = "ember"
)

$ErrorActionPreference = "Stop"
$SeedDir = Split-Path -Parent $MyInvocation.MyCommand.Path

$Files = @(
    "00_reset.sql",
    "01_dummy_users.sql",
    "02_keywords_consents.sql",
    "03_diaries.sql",
    "04_messaging_scenario.sql",
    "99_grant_role.sql"
)

foreach ($f in $Files) {
    $Path = Join-Path $SeedDir $f
    if (-not (Test-Path $Path)) {
        Write-Host "❌ $f 없음 — 건너뜀" -ForegroundColor Red
        continue
    }

    Write-Host ""
    Write-Host "▶ $f 실행 (tester_id=$TesterId)..." -ForegroundColor Cyan

    # 도커 컨테이너 안에서 psql 실행. -v 로 tester_id 변수 전달.
    Get-Content $Path -Raw | docker exec -i $Container `
        psql -U $DbUser -d $DbName -v "tester_id=$TesterId"

    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ $f 실패 (exit=$LASTEXITCODE)" -ForegroundColor Red
        exit 1
    }
}

Write-Host ""
Write-Host "✅ 모든 시드 SQL 실행 완료" -ForegroundColor Green
Write-Host ""
Write-Host "다음 단계:" -ForegroundColor Yellow
Write-Host "  1. 본인 토큰 재발급:  GET http://localhost:8080/api/dev/token?userId=$TesterId"
Write-Host "  2. Swagger UI:        http://localhost:8080/swagger-ui.html"
Write-Host "  3. 채팅방 조회:       GET /api/chat/rooms  (Bearer 위 토큰)"
Write-Host "  4. 추천 탐색:         GET /api/explore?sort=latest"
