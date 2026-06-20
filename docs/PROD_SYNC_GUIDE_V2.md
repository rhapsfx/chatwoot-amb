# Production Source + Data Retrieval Guide (msp.rhaps.net)

This guide documents how to:

1. Retrieve the production **source code** into a separate Git branch and push it to GitHub.
2. Export the production **database** and import it into a local Docker instance.

> ⚠️ **Important**
> - Run all SSH commands **in your terminal**, not via Claude (SSH/rsync are blocked here).
> - Always create backups before any restore.
> - Avoid direct `psql` access from this environment; use Docker container commands on the server.

---

## 0) Variables you’ll need

Set these in your terminal session to avoid typos (copy/paste-safe, no inline comments):

```zsh
export PROD_HOST="msp.rhaps.net"
export PROD_APP_DIR="/opt/chatwoot"
export PROD_GIT_REMOTE="origin"
export PROD_BRANCH_NAME="prod-snapshot"
export LOCAL_IMPORT_BRANCH="prod-sync"
export DB_NAME="chatwoot:production"
```

Notes:
- If your DB name includes special characters (e.g., `chatwoot:production`), keep it quoted:
  `export DB_NAME='chatwoot:production'`
- If you want different names, update the variables above before running any SSH commands.

Quick sanity check (prevents empty variables):

```zsh
echo $PROD_HOST $PROD_APP_DIR $PROD_BRANCH_NAME $LOCAL_IMPORT_BRANCH $DB_NAME
```

---

## 1) Retrieve production source code and push to GitHub

### 1.1) Inspect current production repo status

```zsh
ssh root@${PROD_HOST} "cd ${PROD_APP_DIR} && git status && git rev-parse --abbrev-ref HEAD && git log -1 --oneline"
```

If you see **“No commits yet”** or **“fatal: ambiguous argument 'HEAD'”**, initialize the repo by creating the first commit:

```zsh
ssh root@${PROD_HOST} "cd ${PROD_APP_DIR} && git add . && git commit -m 'chore: initialize repo snapshot'"
```

Confirm:
- Current branch
- Whether there are uncommitted changes

### 1.2) Create a snapshot branch on production

```zsh
ssh root@${PROD_HOST} "cd ${PROD_APP_DIR} && git checkout -b ${PROD_BRANCH_NAME}"
```

If you get **“switch `b` requires a value”**, it means `${PROD_BRANCH_NAME}` is empty. Re-export variables from step 0 and re-run the command.

If production has uncommitted changes, either commit them or stash them:

```zsh
ssh root@${PROD_HOST} "cd ${PROD_APP_DIR} && git add . && git commit -m 'chore: prod snapshot'"
```

### 1.3) Add your GitHub remote (if missing)

```zsh
ssh root@${PROD_HOST} "cd ${PROD_APP_DIR} && git remote -v"
```

If your GitHub remote isn’t present, add it (SSH format):

```zsh
ssh root@${PROD_HOST} "cd ${PROD_APP_DIR} && git remote add github git@github.com:<ORG>/<REPO>.git"
```

> ❌ Avoid `git@https://...` (invalid). Use `git@github.com:ORG/REPO.git`.

### 1.4) Push production snapshot branch to GitHub

```zsh
ssh root@${PROD_HOST} "cd ${PROD_APP_DIR} && git push github ${PROD_BRANCH_NAME}"
```

If GitHub warns about large files (e.g., `vendor/db/sentiment-analysis.onnx`), consider Git LFS for those assets.

### 1.5) Pull the prod snapshot branch locally

```zsh
git fetch origin ${PROD_BRANCH_NAME}
git checkout -b ${LOCAL_IMPORT_BRANCH} origin/${PROD_BRANCH_NAME}
```

You now have the production source in a dedicated branch for comparison and migration planning.

---

## 2) Export production database from Docker (server)

### 2.0) Find the current production database name

```zsh
ssh root@${PROD_HOST} "cd ${PROD_APP_DIR} && docker compose -f docker-compose.production.yml exec -T web /bin/sh -lc 'ruby -ruri -e "puts URI(ENV.fetch(\"DATABASE_URL\")).path.delete_prefix(\"/\")"'"
```

### 2.1) Identify the Postgres container name

```zsh
ssh root@${PROD_HOST} "cd ${PROD_APP_DIR} && docker compose -f docker-compose.production.yml ps"
```

Look for the `postgres` service. The container name will look like `chatwoot-postgres` or similar.

### 2.2) Create a SQL dump inside the container

```zsh
ssh root@${PROD_HOST} "cd ${PROD_APP_DIR} && docker compose -f docker-compose.production.yml exec -T postgres pg_dump -U postgres '${DB_NAME}' > /opt/chatwoot/tmp/${DB_NAME}_backup_$(date +%Y%m%d_%H%M%S).sql"
```

If you see `role "root" does not exist`, it means `pg_dump` used the wrong user. The command above forces `-U postgres` inside the container.

If you see `role "postgres" does not exist`, the container is using a non-default user (see `POSTGRES_USERNAME` in [`config/database.yml`](config/database.yml:27)). Discover the correct user/db from the container and retry:

```zsh
ssh root@${PROD_HOST} "cd ${PROD_APP_DIR} && docker compose -f docker-compose.production.yml exec -T -u postgres postgres /bin/sh -lc 'echo POSTGRES_USER=$POSTGRES_USER POSTGRES_DB=$POSTGRES_DB'"
```

Then run:

```zsh
ssh root@${PROD_HOST} "cd ${PROD_APP_DIR} && docker compose -f docker-compose.production.yml exec -T -u postgres postgres pg_dump -U ${POSTGRES_USER} '${POSTGRES_DB}' > /opt/chatwoot/tmp/${POSTGRES_DB}_backup_$(date +%Y%m%d_%H%M%S).sql"
```

### 2.3) Copy the dump from the server to your local machine

```zsh
scp root@${PROD_HOST}:/opt/chatwoot/tmp/${DB_NAME}_backup_*.sql ./
```

Verify the dump size locally:

```zsh
ls -lh ${DB_NAME}_backup_*.sql
```

---

## 3) Import the production dump into your local Docker instance

### 3.1) Identify your local postgres container

```zsh
docker compose ps
```

Look for the `postgres` service name (commonly `chatwoot-postgres`).

### 3.2) Restore into local DB

```zsh
cat ${DB_NAME}_backup_*.sql | docker exec -i <LOCAL_POSTGRES_CONTAINER> psql ${DB_NAME}
```

> If your local DB name differs (e.g., `chatwoot_development`), replace `${DB_NAME}` accordingly.

---

## 4) Validate schema compatibility (recommended)

### 4.1) Check migration status locally

```zsh
docker exec -it <LOCAL_WEB_CONTAINER> bundle exec rails db:migrate:status | tail -n 20
```

### 4.2) Compare to production migrations

```zsh
ssh root@${PROD_HOST} "cd ${PROD_APP_DIR} && docker compose -f docker-compose.production.yml exec -T web bundle exec rails db:migrate:status | tail -n 20"
```

If production is ahead, you may need to pull additional migration files from the prod source branch (step 1).

---

## 5) Suggested next step

Open a PR from `${LOCAL_IMPORT_BRANCH}` into your main branch to inspect code differences and decide how to migrate safely.

---

## Troubleshooting

### Reset an admin password on production

Run the reset **inside the web container** (uses the correct Ruby version). If the script is not present on the server, copy it first.

**1) Copy the script to production** (run locally):

```zsh
scp script/reset_user_password.rb root@${PROD_HOST}:${PROD_APP_DIR}/script/reset_user_password.rb
```

If the container still can’t see the script, copy it into the running container:

```zsh
ssh root@${PROD_HOST} "cd ${PROD_APP_DIR} && docker cp script/reset_user_password.rb $(docker compose -f docker-compose.production.yml ps -q web):/app/script/reset_user_password.rb"
```

**2) Run the reset in the web container**:

```zsh
ssh root@${PROD_HOST} "cd ${PROD_APP_DIR} && docker compose -f docker-compose.production.yml exec -T web bundle exec rails runner script/reset_user_password.rb 'admin@example.com' 'NewStrongPass123!'"
```

> If you saw `Your Ruby version is ...` locally, this avoids it by running in the container.

### “Permission denied” on SSH
Ensure your SSH key is loaded and authorized on `msp.rhaps.net`.

### Dump too large
Compress during transfer:

```zsh
ssh root@${PROD_HOST} "gzip -9 /opt/chatwoot/tmp/${DB_NAME}_backup_*.sql"
scp root@${PROD_HOST}:/opt/chatwoot/tmp/${DB_NAME}_backup_*.sql.gz ./
gunzip ${DB_NAME}_backup_*.sql.gz
```

### Local restore conflicts
If you want a clean restore, drop and recreate the local DB (run in your local environment only):

```zsh
docker exec -it <LOCAL_POSTGRES_CONTAINER> psql -c "DROP DATABASE IF EXISTS ${DB_NAME}; CREATE DATABASE ${DB_NAME};"
```

### Reset Postgres credentials on production (discover or rotate)

**A) Discover current credentials from the container/env** (read-only):

```zsh
ssh root@${PROD_HOST} "cd ${PROD_APP_DIR} && docker compose -f docker-compose.production.yml exec -T -u postgres postgres /bin/sh -lc 'echo POSTGRES_USER=$POSTGRES_USER POSTGRES_DB=$POSTGRES_DB'"
```

If you have a `.env` on the server, you can also inspect it:

```zsh
ssh root@${PROD_HOST} "cd ${PROD_APP_DIR} && sed -n 's/^POSTGRES_.*$/&/p' .env"
```

> Note: this project uses `POSTGRES_USERNAME`/`POSTGRES_PASSWORD` (not `POSTGRES_USER`) in `.env`. If `POSTGRES_USER` is empty, use `POSTGRES_USERNAME`.

**B) Rotate credentials (requires restart; may impact app until updated):**

1) Choose new values (example below):

```zsh
export NEW_DB_USER="chatwoot_prod"
export NEW_DB_PASS="ChangeThisStrongPassword!"
export NEW_DB_NAME="chatwoot_production"
```

2) Update `.env` on the server:

```zsh
ssh root@${PROD_HOST} "cd ${PROD_APP_DIR} && sed -i.bak \
  -e 's/^POSTGRES_USER=.*/POSTGRES_USER='"$NEW_DB_USER"'/' \
  -e 's/^POSTGRES_PASSWORD=.*/POSTGRES_PASSWORD='"$NEW_DB_PASS"'/' \
  -e 's/^POSTGRES_DATABASE=.*/POSTGRES_DATABASE='"$NEW_DB_NAME"'/' \
  .env"
```

3) Apply inside Postgres (run as container `postgres` user):

```zsh
ssh root@${PROD_HOST} "cd ${PROD_APP_DIR} && docker compose -f docker-compose.production.yml exec -T -u postgres postgres /bin/sh -lc \
  'psql -v ON_ERROR_STOP=1 -c "ALTER USER '"$NEW_DB_USER"' WITH PASSWORD '\''"$NEW_DB_PASS"'\'';"'"
```

4) Restart containers so app picks up new env:

```zsh
ssh root@${PROD_HOST} "cd ${PROD_APP_DIR} && docker compose -f docker-compose.production.yml restart web worker"
```

**C) Recovery if roles are unknown (single-user mode reset)**

If the existing roles are unknown and `pg_dump` fails with `role ... does not exist`, you can create a new superuser directly in single-user mode and then use it for dumps.

1) Capture the Postgres data directory and credentials from the running container (do this before stopping it):

```zsh
ssh root@${PROD_HOST} "cd /opt/chatwoot && docker compose -f docker-compose.production.yml exec -T postgres /bin/sh -lc 'echo PGDATA=$PGDATA'"
```

If `PGDATA` is empty, use the default for the official Postgres image:

```text
/var/lib/postgresql/data
```

You can also inspect the container to get the actual `POSTGRES_USER`/`POSTGRES_DB` values:

```zsh
ssh root@${PROD_HOST} "docker inspect chatwoot-postgres --format='Env={{json .Config.Env}}'"
```

2) Stop Postgres container:

```zsh
ssh root@${PROD_HOST} "cd ${PROD_APP_DIR} && docker compose -f docker-compose.production.yml stop postgres"
```

3) Create a new superuser (replace values):

```zsh
ssh root@${PROD_HOST} 'cd /opt/chatwoot && docker compose -f docker-compose.production.yml run --rm -u postgres postgres /bin/sh -lc "PGDATA=/var/lib/postgresql/data; printf \"CREATE ROLE chatwoot_prod WITH LOGIN SUPERUSER PASSWORD \\\"ChangeThisStrongPassword!\\\";\\n\" | postgres --single -D $PGDATA postgres"'
```

4) Start Postgres:

```zsh
ssh root@${PROD_HOST} "cd ${PROD_APP_DIR} && docker compose -f docker-compose.production.yml start postgres"
```

5) Dump using the new role:

```zsh
ssh root@${PROD_HOST} "cd ${PROD_APP_DIR} && docker compose -f docker-compose.production.yml exec -T postgres pg_dump -U chatwoot_prod '${DB_NAME}' > /opt/chatwoot/tmp/${DB_NAME}_backup_$(date +%Y%m%d_%H%M%S).sql"
```

---

## Safety checklist

- [ ] Production source snapshotted into a dedicated branch
- [ ] Production database dump created and copied locally
- [ ] Local DB restore completed
- [ ] Migration status compared between prod and local
- [ ] All changes reviewed in a PR before merging
