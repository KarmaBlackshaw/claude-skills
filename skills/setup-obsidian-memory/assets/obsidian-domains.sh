#!/usr/bin/env bash
# Sourced by obsidian-recall.sh + obsidian-retrieve.sh. Resolves which Learnings
# spokes a repo cares about: the pointer's DOMAINS= wins (`all` = every spoke);
# otherwise detect from the repo's own manifests. Workflow is always in — memory /
# agents / shell lessons are stack-agnostic. A repo with no manifest at all (docs,
# skills, dotfiles) is Workflow-only. Callers treat "" as "no filter".
#   resolve_domains <repo-root> <pointer DOMAINS= value>   -> prints "Frontend,Workflow" | ""
resolve_domains() {
  local r="$1" want="$2" pj="$1/package.json" fe=0 be=0 mob=0 m
  case "$want" in all|ALL) printf ''; return ;; ?*) printf '%s' "$want"; return ;; esac
  if [ -f "$pj" ]; then
    grep -qE '"(react-native|expo)"' "$pj" && mob=1
    grep -qE '"(vue|nuxt|next|svelte|@angular/core)"' "$pj" && fe=1
    [ "$mob" = 0 ] && grep -qE '"react"' "$pj" && fe=1
    grep -qE '"(@supabase/supabase-js|@prisma/client|prisma|drizzle-orm|pg|knex|typeorm|mongoose|express|fastify|@nestjs/core|hono)"' "$pj" && be=1
  fi
  [ -d "$r/supabase" ] && be=1
  for m in "$r"/*.sql "$r"/migrations/*.sql; do [ -e "$m" ] && { be=1; break; }; done
  for m in requirements.txt pyproject.toml go.mod Cargo.toml composer.json Gemfile; do [ -f "$r/$m" ] && { be=1; break; }; done
  local d=""
  [ "$fe" = 1 ] && d="$d,Frontend"
  [ "$be" = 1 ] && d="$d,Backend-Data"
  [ "$mob" = 1 ] && d="$d,Mobile"
  printf '%s' "${d#,}${d:+,}Workflow"
}
