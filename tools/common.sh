# shared helpers for the tools/ scripts
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
[ -f "$ROOT/config.sh" ] || { echo "Missing config.sh: copy config.example.sh to config.sh and fill it in." >&2; exit 1; }
. "$ROOT/config.sh"
SSH_OPTS="-i $SSH_KEY -o BatchMode=yes -o ConnectTimeout=8"
tv() { ssh $SSH_OPTS "$TV_USER@$TV_HOST" "$@"; }
tv_put() { scp -q $SSH_OPTS "$1" "$TV_USER@$TV_HOST:$2"; }
