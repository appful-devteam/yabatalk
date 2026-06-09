#!/usr/bin/env bash
# やばトーク めろまる/あいまる アセット一括 restyle 生成。
# Codex image_gen (image-to-image) で 元ポーズを保持しつつ app icon の世界観へ。
# 出力: assets/generated/2026-06-09/batch/<name>.png （緑/単色背景、後で cutout.py で透過化）
set -uo pipefail

ROOT="/Users/chisato/Desktop/apps/yabatalk"
cd "$ROOT"
ICON="$ROOT/yabatalk_icon.png"
SH="$ROOT/../.claude/skills/img-gpt/scripts/codex-image.sh"
ASSETS="$ROOT/lovetalk/Assets.xcassets"
OUTDIR="$ROOT/assets/generated/2026-06-09/batch"
mkdir -p "$OUTDIR"
LOG="$OUTDIR/_batch.log"
: > "$LOG"

PROMPT_SINGLE='Re-render the FIRST image (a fluffy blue plush mascot) so its art style EXACTLY matches the reference character in the 2nd image: ultra-detailed soft 3D plush fur texture, large glossy round expressive eyes with bright catchlights, small dark nose, soft pink blush cheeks, vivid blue fur color, Pixar-like 3D rendering with soft studio lighting. KEEP the exact same body pose, gesture, proportions and centered composition as the FIRST image. Change only the facial expression to a cheeky, slightly grumpy / mischievous attitude look (NOT a sugary-sweet open smile) to fit an edgy, sassy brand tone. Single character only, plain soft solid background, no ground shadow, no text, square, high resolution.'

PROMPT_PAIR='Re-render the FIRST image (a blue plush mascot and a pink plush mascot together) so the art style EXACTLY matches the reference characters in the 2nd image: ultra-detailed soft 3D plush fur, large glossy round eyes with bright catchlights, small dark nose, soft pink blush cheeks, Pixar-like 3D rendering with soft studio lighting. The BLUE character keeps vivid blue fur; the PINK character keeps soft pink fur. KEEP the exact same two-character pose, gesture, proportions and composition as the FIRST image. Change expressions to fit an edgy brand: the BLUE one looks grumpy / annoyed / sulky, the PINK one looks anxious / timid / worried. Two characters only, plain soft solid background, no ground shadow, no text, square, high resolution.'

gen () {
  local name="$1" src="$2" prompt="$3"
  local out="$OUTDIR/$name.png"
  if [[ -f "$out" ]]; then echo "SKIP exists $name" | tee -a "$LOG"; return 0; fi
  if [[ ! -f "$src" ]]; then echo "MISS src $name ($src)" | tee -a "$LOG"; return 0; fi
  echo "GEN  $name ..." | tee -a "$LOG"
  OUTPUT_PATH="$out" INPUT_IMAGES="$src
$ICON" PROMPT="$prompt" bash "$SH" >>"$LOG" 2>&1
  if [[ -f "$out" ]]; then echo "OK   $name" | tee -a "$LOG"; else echo "FAIL $name" | tee -a "$LOG"; fi
}

# --- consult_partner_meromaru 02..16 (01 はパイロット済) ---
for n in 02 03 04 05 06 07 08 09 10 11 12 13 14 15 16; do
  gen "consult_partner_meromaru_$n" "$ASSETS/consult_partner_meromaru_$n.imageset/consult_partner_meromaru_$n.png" "$PROMPT_SINGLE"
done

# --- mero_pair 01..16 (08 はパイロット済) ---
for n in 01 02 03 04 05 06 07 09 10 11 12 13 14 15 16; do
  gen "mero_pair_$n" "$ASSETS/mero_pair_$n.imageset/mero_pair_$n.png" "$PROMPT_PAIR"
done

echo "=== BATCH GENERATION DONE ===" | tee -a "$LOG"
ls -1 "$OUTDIR"/*.png 2>/dev/null | wc -l | xargs echo "generated files:"
