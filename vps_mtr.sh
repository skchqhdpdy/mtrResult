#!/usr/bin/env bash
set -u

# mtr 설치 여부 확인
if ! command -v mtr >/dev/null 2>&1; then
  echo "[오류] mtr이 설치되어 있지 않습니다."
  echo "설치 명령어: apt update && apt install -y mtr-tiny  (RHEL/Rocky: dnf install -y mtr)"
  exit 1
fi

# 기본 측정 설정 (1초 간격 x 30회 = 타깃당 약 30초)
COUNT=30
INTERVAL=1
HOST_NAME=$(hostname -s 2>/dev/null || hostname)
FILE_TS=$(TZ='Asia/Seoul' date '+%Y%m%d_%H%M%S')
START_TIME=$(TZ='Asia/Seoul' date '+%Y-%m-%d %H:%M:%S KST')
OUT_FILE="mtr_${HOST_NAME}_${FILE_TS}.txt"

# VPS 공인 IP / ASN / 위치 자동 감지
IPINFO=""
if command -v curl >/dev/null 2>&1; then
  IPINFO=$(curl -4 -s --max-time 5 https://ipinfo.io/json || true)
elif command -v wget >/dev/null 2>&1; then
  IPINFO=$(wget -4 -qO- --timeout=5 https://ipinfo.io/json || true)
fi

get_json_val() {
  printf '%s\n' "$IPINFO" | grep -o "\"$1\": *\"[^\"]*\"" | head -n1 | sed 's/^[^:]*: *"\(.*\)"/\1/'
}

PUB_IP=$(get_json_val "ip")
ASN_ORG=$(get_json_val "org")
CITY=$(get_json_val "city")
COUNTRY=$(get_json_val "country")

[ -z "$PUB_IP" ] && PUB_IP="Unknown"
[ -z "$ASN_ORG" ] && ASN_ORG="Unknown"
LOCATION="${CITY:-Unknown}, ${COUNTRY:-Unknown}"

# 측정 대상 목록 ("라벨|도메인 또는 IP")
TARGETS=(
  "SKB_본가|aodd.xyz"
  "KT_기숙사_QoS우회|dorm.dongseo.vip"
  "KT_기숙사|qos.dorm.dongseo.vip"
  "oracle-chuncheon|ns3.aodd.xyz"
  "oracle-osaka|ns2.aodd.xyz"
  "hostbrr-frankfurt|hostbrr-frankfurt.wgvpn.in"
  "하바롭스크_1_Misaka|185.209.84.131"
  "하바롭스크_2_Rostelecom|87.225.45.1"
)

TOTAL=${#TARGETS[@]}

# 리포트 헤더 기록
{
  echo "================================================================================"
  echo "VPS MTR Benchmark Report"
  echo "================================================================================"
  echo "Measured At : ${START_TIME}"
  echo "Hostname    : ${HOST_NAME}"
  echo "Public IPv4 : ${PUB_IP}"
  echo "ASN / Org   : ${ASN_ORG}"
  echo "Location    : ${LOCATION}"
  echo "Command     : mtr -4 -rwzb -c ${COUNT} -i ${INTERVAL}"
  echo "================================================================================"
  echo ""
} > "$OUT_FILE"

echo "측정 시작: ${HOST_NAME} (${PUB_IP} / ${ASN_ORG})"
echo "저장 파일: ${OUT_FILE} (총 ${TOTAL}개 대상, 약 $((TOTAL * COUNT / 60))분 소요)"
echo ""

# 순차 측정 실행
IDX=1
for entry in "${TARGETS[@]}"; do
  LABEL="${entry%%|*}"
  TARGET="${entry#*|}"
  NOW=$(TZ='Asia/Seoul' date '+%Y-%m-%d %H:%M:%S KST')

  echo "[${IDX}/${TOTAL}] 측정 중: ${LABEL} (${TARGET}) ..."

  {
    echo "--------------------------------------------------------------------------------"
    echo "[${IDX}/${TOTAL}] ${LABEL} (${TARGET}) | Start: ${NOW}"
    echo "--------------------------------------------------------------------------------"
    mtr -4 -rwzb -c "$COUNT" -i "$INTERVAL" "$TARGET" 2>&1
    echo ""
  } >> "$OUT_FILE"

  IDX=$((IDX + 1))
done

END_TIME=$(TZ='Asia/Seoul' date '+%Y-%m-%d %H:%M:%S KST')
{
  echo "================================================================================"
  echo "Finished At : ${END_TIME}"
  echo "================================================================================"
} >> "$OUT_FILE"

echo ""
echo "측정 완료! 결과 파일: ${OUT_FILE}"