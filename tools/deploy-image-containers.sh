#!/usr/bin/env bash
# 部署：把 /opt/dom-mirror-full 的引擎运行时代码同步进「镜像烘焙型」站点容器
# 背景（v0.92 教训）：rbi-81/82/90..96 的代码打包在镜像里、无 bind mount——
# 只更新 /opt/dom-mirror-full 只会生效于 rbi-dl(8737)，站点入口(:81 等)长期
# 停留在旧镜像代码，导致"修了九轮用户端毫无变化"。
#
# 用法：
#   ./deploy-image-containers.sh            # 同步默认容器列表
#   CONTAINERS="rbi-81" ./deploy-image-containers.sh
# 注意：docker cp 写入容器可写层，容器 recreate/镜像重构建后需重跑；
#      长期方案是把这些容器改为 bind mount 后 recreate（见 docs 待办）。
set -euo pipefail
SRC=${SRC:-/opt/dom-mirror-full}
FILES="server.js client/index.html lib/page-helpers.js lib/input.js lib/skp-bridge.js lib/displaylist.js lib/sessions.js"
CONTAINERS=${CONTAINERS:-"rbi-81 rbi-82 rbi-90 rbi-91 rbi-92 rbi-93 rbi-94 rbi-96"}

for n in $CONTAINERS; do
  echo "== $n"
  mkdir -p "/opt/rbi-img-bak-$n"
  for f in $FILES; do
    docker cp "$n:/app/$f" "/opt/rbi-img-bak-$n/$(basename "$f")" 2>/dev/null || true
    docker cp "$SRC/$f" "$n:/app/$f"
  done
  docker exec "$n" node --check /app/server.js >/dev/null
  docker restart "$n" >/dev/null
done

sleep 7
for n in $CONTAINERS; do
  port=$(docker port "$n" 8088/tcp | head -1 | sed 's/.*://')
  code=$(curl -s -o /dev/null -w '%{http_code}' -m 6 "http://127.0.0.1:$port/" || true)
  mk=$(curl -s -m 6 "http://127.0.0.1:$port/" | grep -c 'if (!frameMode) { el.style.transform' || true)
  echo "$n :$port http=$code v092=$mk"
done
