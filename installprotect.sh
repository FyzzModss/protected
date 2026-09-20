#!/bin/bash
# ============================================================================
# INSTALLPROTECT.SH - SATU FILE UNTUK SEMUA FITUR PROTEKSI
#
# Pakai:
#   bash installprotect.sh <fitur>    contoh: bash installprotect.sh protect5c
#   bash installprotect.sh list       lihat semua fitur yang tersedia
#   bash installprotect.sh all        pasang semua fitur sekaligus
# ============================================================================

set -o pipefail

PROTECT_KEY="${1:-${PROTECT_KEY:-}}"

protect_payload() {
  case "$1" in
    protect1)
      cat << 'PROTECT1_PLAIN'
#!/bin/bash

BRAND_NAME="${BRAND_NAME:-FyzzOffciall.ID}"
BRAND_TEXT="${BRAND_TEXT:-Protect By FyzzOffciall.ID}"

PANEL_DIR="/var/www/pterodactyl"
REMOTE_PATH="$PANEL_DIR/app/Services/Servers/ServerDeletionService.php"
SERVER_MODEL="$PANEL_DIR/app/Models/Server.php"
APP_SERVER_CONTROLLER="$PANEL_DIR/app/Http/Controllers/Api/Application/Servers/ServerController.php"
TIMESTAMP=$(date -u +"%Y-%m-%d-%H-%M-%S-%N")
BACKUP_PATH="${REMOTE_PATH}.bak_${TIMESTAMP}"

echo "🚀 Memasang proteksi Anti Delete Server..."

if [ -f "$REMOTE_PATH" ]; then
  mv "$REMOTE_PATH" "$BACKUP_PATH"
  echo "📦 Backup file lama dibuat di $BACKUP_PATH"
fi

mkdir -p "$(dirname "$REMOTE_PATH")"
chmod 755 "$(dirname "$REMOTE_PATH")"

cat > "$REMOTE_PATH" << 'EOF'
<?php

namespace Pterodactyl\Services\Servers;

use Illuminate\Support\Facades\Auth;
use Pterodactyl\Exceptions\DisplayException;
use Illuminate\Http\Response;
use Pterodactyl\Models\Server;
use Illuminate\Support\Facades\Log;
use Illuminate\Database\ConnectionInterface;
use Pterodactyl\Repositories\Wings\DaemonServerRepository;
use Pterodactyl\Services\Databases\DatabaseManagementService;
use Pterodactyl\Exceptions\Http\Connection\DaemonConnectionException;

class ServerDeletionService
{
    protected bool $force = false;

    /**
     * ServerDeletionService constructor.
     */
    public function __construct(
        private ConnectionInterface $connection,
        private DaemonServerRepository $daemonServerRepository,
        private DatabaseManagementService $databaseManagementService
    ) {
    }

    /**
     * Set if the server should be forcibly deleted from the panel (ignoring daemon errors) or not.
     */
    public function withForce(bool $bool = true): self
    {
        $this->force = $bool;
        return $this;
    }

    /**
     * Delete a server from the panel and remove any associated databases from hosts.
     *
     * @throws \Throwable
     * @throws \Pterodactyl\Exceptions\DisplayException
     */
    public function handle(Server $server): void
    {
        $this->assertDeletionAllowed($server);

        try {
            $this->daemonServerRepository->setServer($server)->delete();
        } catch (DaemonConnectionException $exception) {
            // Abaikan error 404, tapi lempar error lain jika tidak mode force
            if (!$this->force && $exception->getStatusCode() !== Response::HTTP_NOT_FOUND) {
                throw $exception;
            }

            Log::warning($exception);
        }

        $this->connection->transaction(function () use ($server) {
            foreach ($server->databases as $database) {
                try {
                    $this->databaseManagementService->delete($database);
                } catch (\Exception $exception) {
                    if (!$this->force) {
                        throw $exception;
                    }

                    // Jika gagal delete database di host, tetap hapus dari panel
                    $database->delete();
                    Log::warning($exception);
                }
            }

            $server->delete();
        });
    }

    private function assertDeletionAllowed(Server $server): void
    {
        // PROTEKSI_FIT_SERVER_DELETE_GUARD_V2
        // Mode ketat: delete server via panel/API/PLTA/PLTC hanya boleh oleh User ID 1.
        $actorId = $this->resolveActorId();

        if ($actorId === 1) {
            return;
        }

        // Request HTTP/API tanpa actor ID 1 tetap ditolak agar tidak bypass via token/bot.
        if ($this->isHttpRequest()) {
            throw new DisplayException('Akses ditolak: hanya Admin ID 1 yang dapat menghapus server via panel/API/PLTA/PLTC @ PROTECTED BY VANTAXZMD.');
        }

        // CLI/background job bawaan panel tetap aman; bot/API tidak lewat CLI.
    }

    private function resolveActorId(): ?int
    {
        $request = null;
        try {
            $request = request();
        } catch (\Throwable $e) {}

        foreach ([null, 'web', 'api', 'application', 'client', 'sanctum'] as $guard) {
            try {
                $user = $guard === null ? Auth::user() : Auth::guard($guard)->user();
                $id = $this->extractUserId($user);
                if ($id !== null) {
                    return $id;
                }
            } catch (\Throwable $e) {}
        }

        try {
            $id = $this->extractUserId($request ? $request->user() : null);
            if ($id !== null) {
                return $id;
            }
        } catch (\Throwable $e) {}

        if ($request) {
            foreach (['api_key', 'apiKey', 'application_api_key', 'account_api_key', 'token', 'sanctum_token'] as $name) {
                try {
                    $id = $this->extractActorIdFromApiKey($request->attributes->get($name));
                    if ($id !== null) {
                        return $id;
                    }
                } catch (\Throwable $e) {}
            }
        }

        return null;
    }

    private function extractActorIdFromApiKey(mixed $apiKey): ?int
    {
        if (!$apiKey) {
            return null;
        }

        foreach (['user_id', 'owner_id', 'created_by'] as $field) {
            try {
                if (isset($apiKey->{$field}) && is_numeric($apiKey->{$field})) {
                    return (int) $apiKey->{$field};
                }
            } catch (\Throwable $e) {}
        }

        foreach (['user', 'tokenable', 'owner'] as $relation) {
            try {
                $related = $apiKey->{$relation} ?? null;
                if (!$related && method_exists($apiKey, $relation)) {
                    $related = $apiKey->{$relation}()->first();
                }
                $id = $this->extractUserId($related);
                if ($id !== null) {
                    return $id;
                }
            } catch (\Throwable $e) {}
        }

        return null;
    }

    private function extractUserId(mixed $user): ?int
    {
        try {
            if ($user && isset($user->id) && is_numeric($user->id)) {
                return (int) $user->id;
            }
        } catch (\Throwable $e) {}

        return null;
    }

    private function isHttpRequest(): bool
    {
        try {
            $request = request();
            return $request && app()->runningInConsole() === false;
        } catch (\Throwable $e) {
            return false;
        }
    }
}
EOF

chmod 644 "$REMOTE_PATH"

cleanup_marker_block() {
  local file="$1"
  local marker_regex="$2"
  [ -f "$file" ] || return 0
  if grep -Eq "$marker_regex" "$file"; then
    local tmp_file
    tmp_file=$(mktemp)
    awk -v marker="$marker_regex" '
      BEGIN { skip=0; skip_simple=0; depth=0 }
      skip_simple==1 {
        if ($0 ~ /throw new .*DisplayException/) { skip_simple=0; next }
        skip_simple=0
        print
        next
      }
      $0 ~ marker {
        if (marker ~ /BLOCK_APPLICATION_API_SERVER_DELETE/) {
          skip_simple=1
          next
        }
        skip=1
        depth=0
        open_count=gsub(/\{/, "{")
        close_count=gsub(/\}/, "}")
        depth += open_count - close_count
        next
      }
      skip==1 {
        open_count=gsub(/\{/, "{")
        close_count=gsub(/\}/, "}")
        depth += open_count - close_count
        if (depth <= 0 && $0 ~ /^[[:space:]]*}[);]?[[:space:]]*$/) {
          skip=0
        }
        next
      }
      { print }
    ' "$file" > "$tmp_file" && mv "$tmp_file" "$file"
  fi
}

# Bersihkan guard lama yang memblokir semua API/PLTA agar update tidak ke-skip.
for F in "$SERVER_MODEL" "$APP_SERVER_CONTROLLER"; do
  [ -f "$F" ] && cp "$F" "${F}.bak_${TIMESTAMP}_preclean" 2>/dev/null || true
done
cleanup_marker_block "$SERVER_MODEL" "PROTEKSI_FIT_SERVER_MODEL_DELETE_GUARD"
cleanup_marker_block "$APP_SERVER_CONTROLLER" "PROTEKSI_FIT_BLOCK_APPLICATION_API_SERVER_DELETE"

# Fallback tambahan: pasang guard di model Server agar jalur force/offline/API yang bypass ServerDeletionService tetap divalidasi.
if [ -f "$SERVER_MODEL" ]; then
  cp "$SERVER_MODEL" "${SERVER_MODEL}.bak_${TIMESTAMP}"
  if ! grep -q "PROTEKSI_FIT_SERVER_MODEL_DELETE_GUARD_V2" "$SERVER_MODEL"; then
    TMP_FILE=$(mktemp)
    awk '
      BEGIN { inserted=0 }
      /^}[[:space:]]*$/ && inserted==0 {
        print ""
        print "    // PROTEKSI_FIT_SERVER_MODEL_DELETE_GUARD_V2: fallback anti delete server, hanya actor User ID 1"
        print "    protected static function booted(): void"
        print "    {"
        print "        static::deleting(function ($server) {"
        print "            try {"
        print "                if (app()->runningInConsole()) { return; }"
        print "                $request = request();"
        print "                $actorId = null;"
        print "                foreach ([null, '\''web'\'', '\''api'\'', '\''application'\'', '\''client'\'', '\''sanctum'\''] as $guard) {"
        print "                    try {"
        print "                        $user = $guard === null ? \\Illuminate\\Support\\Facades\\Auth::user() : \\Illuminate\\Support\\Facades\\Auth::guard($guard)->user();"
        print "                        if ($user && isset($user->id) && is_numeric($user->id)) { $actorId = (int) $user->id; break; }"
        print "                    } catch (\\Throwable $e) {}"
        print "                }"
        print "                if ($actorId === null && $request) {"
        print "                    try { $user = $request->user(); if ($user && isset($user->id) && is_numeric($user->id)) { $actorId = (int) $user->id; } } catch (\\Throwable $e) {}"
        print "                }"
        print "                if ($actorId === null && $request) {"
        print "                    foreach (['\''api_key'\'', '\''apiKey'\'', '\''application_api_key'\'', '\''account_api_key'\'', '\''token'\'', '\''sanctum_token'\''] as $name) {"
        print "                        try {"
        print "                            $apiKey = $request->attributes->get($name);"
        print "                            if (!$apiKey) { continue; }"
        print "                            foreach (['\''user_id'\'', '\''owner_id'\'', '\''created_by'\''] as $field) { if (isset($apiKey->{$field}) && is_numeric($apiKey->{$field})) { $actorId = (int) $apiKey->{$field}; break 2; } }"
        print "                            foreach (['\''user'\'', '\''tokenable'\'', '\''owner'\''] as $relation) {"
        print "                                $related = $apiKey->{$relation} ?? null;"
        print "                                if (!$related && method_exists($apiKey, $relation)) { $related = $apiKey->{$relation}()->first(); }"
        print "                                if ($related && isset($related->id) && is_numeric($related->id)) { $actorId = (int) $related->id; break 2; }"
        print "                            }"
        print "                        } catch (\\Throwable $e) {}"
        print "                    }"
        print "                }"
        print "                if ($actorId !== 1) {"
        print "                    throw new \\Pterodactyl\\Exceptions\\DisplayException('\''Akses ditolak: hanya Admin ID 1 yang dapat menghapus server via panel/API/PLTA/PLTC @ PROTECTED BY VANTAXZMD.'\'');"
        print "                }"
        print "            } catch (\\Pterodactyl\\Exceptions\\DisplayException $e) {"
        print "                throw $e;"
        print "            } catch (\\Throwable $e) {"
        print "                throw new \\Pterodactyl\\Exceptions\\DisplayException('\''Akses ditolak: validasi hapus server gagal @ PROTECTED BY VANTAXZMD.'\'');"
        print "            }"
        print "        });"
        print "    }"
        inserted=1
      }
      { print }
    ' "$SERVER_MODEL" > "$TMP_FILE" && mv "$TMP_FILE" "$SERVER_MODEL"
    chmod 644 "$SERVER_MODEL"
    if php -l "$SERVER_MODEL" >/dev/null 2>&1; then
      echo "✅ Fallback guard Server model V2 terpasang."
    else
      echo "❌ Syntax error Server model setelah inject — rollback otomatis."
      cp "${SERVER_MODEL}.bak_${TIMESTAMP}" "$SERVER_MODEL"
    fi
  else
    echo "⚠️ Fallback guard Server model V2 sudah ada, skip."
  fi
else
  echo "⚠️ Server model tidak ditemukan, fallback guard dilewati: $SERVER_MODEL"
fi

# Fallback khusus PLTA/Application API: jangan blok total, validasi pemilik API key harus User ID 1.
if [ -f "$APP_SERVER_CONTROLLER" ]; then
  cp "$APP_SERVER_CONTROLLER" "${APP_SERVER_CONTROLLER}.bak_${TIMESTAMP}"
  if ! grep -q "PROTEKSI_FIT_APPLICATION_API_SERVER_DELETE_V2" "$APP_SERVER_CONTROLLER"; then
    TMP_FILE=$(mktemp)
    awk '
      BEGIN { in_delete=0; inserted=0 }
      /function[[:space:]]+delete[[:space:]]*[(]/ { in_delete=1 }
      {
        print
        if (in_delete==1 && inserted==0 && $0 ~ /^[[:space:]]*\{[[:space:]]*$/) {
          print "        // PROTEKSI_FIT_APPLICATION_API_SERVER_DELETE_V2: Application API delete hanya API key/Admin ID 1"
          print "        $__actorId = null;"
          print "        try {"
          print "            $__req = request();"
          print "            foreach ([null, '\''web'\'', '\''api'\'', '\''application'\'', '\''client'\'', '\''sanctum'\''] as $__guard) {"
          print "                try {"
          print "                    $__user = $__guard === null ? \\Illuminate\\Support\\Facades\\Auth::user() : \\Illuminate\\Support\\Facades\\Auth::guard($__guard)->user();"
          print "                    if ($__user && isset($__user->id) && is_numeric($__user->id)) { $__actorId = (int) $__user->id; break; }"
          print "                } catch (\\Throwable $e) {}"
          print "            }"
          print "            if ($__actorId === null && $__req) { try { $__user = $__req->user(); if ($__user && isset($__user->id) && is_numeric($__user->id)) { $__actorId = (int) $__user->id; } } catch (\\Throwable $e) {} }"
          print "            if ($__actorId === null && $__req) {"
          print "                foreach (['\''api_key'\'', '\''apiKey'\'', '\''application_api_key'\'', '\''account_api_key'\'', '\''token'\'', '\''sanctum_token'\''] as $__name) {"
          print "                    try {"
          print "                        $__apiKey = $__req->attributes->get($__name);"
          print "                        if (!$__apiKey) { continue; }"
          print "                        foreach (['\''user_id'\'', '\''owner_id'\'', '\''created_by'\''] as $__field) { if (isset($__apiKey->{$__field}) && is_numeric($__apiKey->{$__field})) { $__actorId = (int) $__apiKey->{$__field}; break 2; } }"
          print "                        foreach (['\''user'\'', '\''tokenable'\'', '\''owner'\''] as $__rel) {"
          print "                            $__related = $__apiKey->{$__rel} ?? null;"
          print "                            if (!$__related && method_exists($__apiKey, $__rel)) { $__related = $__apiKey->{$__rel}()->first(); }"
          print "                            if ($__related && isset($__related->id) && is_numeric($__related->id)) { $__actorId = (int) $__related->id; break 2; }"
          print "                        }"
          print "                    } catch (\\Throwable $e) {}"
          print "                }"
          print "            }"
          print "        } catch (\\Throwable $e) {}"
          print "        if ($__actorId !== 1) {"
          print "            throw new \\Pterodactyl\\Exceptions\\DisplayException('\''Akses ditolak: hapus server via API/PLTA hanya boleh memakai API key/Admin ID 1 @ PROTECTED BY VANTAXZMD.'\'');"
          print "        }"
          inserted=1
          in_delete=0
        }
      }
    ' "$APP_SERVER_CONTROLLER" > "$TMP_FILE" && mv "$TMP_FILE" "$APP_SERVER_CONTROLLER"
    chmod 644 "$APP_SERVER_CONTROLLER"
    if php -l "$APP_SERVER_CONTROLLER" >/dev/null 2>&1; then
      echo "✅ Guard Application API delete server V2 terpasang."
    else
      echo "❌ Syntax error Application API server controller setelah inject — rollback otomatis."
      cp "${APP_SERVER_CONTROLLER}.bak_${TIMESTAMP}" "$APP_SERVER_CONTROLLER"
    fi
  else
    echo "⚠️ Guard Application API delete server V2 sudah ada, skip."
  fi
else
  echo "⚠️ Controller Application API server tidak ditemukan, guard PLTA dilewati: $APP_SERVER_CONTROLLER"
fi

# Apply brand customization
for F in "$REMOTE_PATH" "$SERVER_MODEL" "$APP_SERVER_CONTROLLER"; do
  if [ -f "$F" ]; then
    sed -i "s|Protect By FyzzOffciall.ID|${BRAND_TEXT}|g" "$F" 2>/dev/null || true
    sed -i "s|FyzzOffciall.ID|${BRAND_NAME}|g" "$F" 2>/dev/null || true
    sed -i "s|PROTECTED BY VANTAXZMD|${BRAND_TEXT}|g" "$F" 2>/dev/null || true
  fi
done

cd "$PANEL_DIR" 2>/dev/null && {
  php artisan config:clear >/dev/null 2>&1 || true
  php artisan cache:clear >/dev/null 2>&1 || true
  php artisan view:clear >/dev/null 2>&1 || true
  php artisan route:clear >/dev/null 2>&1 || true
}

echo "✅ Proteksi Anti Delete Server berhasil dipasang!"
echo "📂 Lokasi file: $REMOTE_PATH"
echo "🗂️ Backup file lama: $BACKUP_PATH (jika sebelumnya ada)"
echo "🔒 Hapus server via panel/API/PLTA/PLTC hanya boleh actor/API key milik Admin ID 1."
PROTECT1_PLAIN
      ;;
    protect2)
      cat << 'PROTECT2_PLAIN'
#!/bin/bash

BRAND_NAME="${BRAND_NAME:-FyzzOffciall.ID}"
BRAND_TEXT="${BRAND_TEXT:-Protect By FyzzOffciall.ID}"
BRAND_LABEL="${BRAND_LABEL:-$BRAND_NAME}"
CONTACT_TELEGRAM="${CONTACT_TELEGRAM:-@FyzzModss}"
CONTACT_TELEGRAM_2="${CONTACT_TELEGRAM_2:-@FyzAbout}"

REMOTE_PATH="/var/www/pterodactyl/app/Http/Controllers/Admin/UserController.php"
TIMESTAMP=$(date -u +"%Y-%m-%d-%H-%M-%S-%N")
BACKUP_PATH="${REMOTE_PATH}.bak_${TIMESTAMP}"

echo "🚀 Memasang proteksi UserController.php anti hapus dan anti ubah data user..."

# Backup file lama jika ada
if [ -f "$REMOTE_PATH" ]; then
  mv "$REMOTE_PATH" "$BACKUP_PATH"
  echo "📦 Backup file lama dibuat di $BACKUP_PATH"
fi

mkdir -p "$(dirname "$REMOTE_PATH")"
chmod 755 "$(dirname "$REMOTE_PATH")"

cat > "$REMOTE_PATH" <<'EOF'
<?php

namespace Pterodactyl\Http\Controllers\Admin;

use Illuminate\View\View;
use Illuminate\Http\Request;
use Pterodactyl\Models\User;
use Pterodactyl\Models\Model;
use Illuminate\Support\Collection;
use Illuminate\Http\RedirectResponse;
use Prologue\Alerts\AlertsMessageBag;
use Spatie\QueryBuilder\QueryBuilder;
use Illuminate\View\Factory as ViewFactory;
use Pterodactyl\Exceptions\DisplayException;
use Pterodactyl\Http\Controllers\Controller;
use Illuminate\Contracts\Translation\Translator;
use Pterodactyl\Services\Users\UserUpdateService;
use Pterodactyl\Traits\Helpers\AvailableLanguages;
use Pterodactyl\Services\Users\UserCreationService;
use Pterodactyl\Services\Users\UserDeletionService;
use Pterodactyl\Http\Requests\Admin\UserFormRequest;
use Pterodactyl\Http\Requests\Admin\NewUserFormRequest;
use Pterodactyl\Contracts\Repository\UserRepositoryInterface;
class UserController extends Controller
{
    use AvailableLanguages;

    /**
     * UserController constructor.
     */
    public function __construct(
        protected AlertsMessageBag $alert,
        protected UserCreationService $creationService,
        protected UserDeletionService $deletionService,
        protected Translator $translator,
        protected UserUpdateService $updateService,
        protected UserRepositoryInterface $repository,
        protected ViewFactory $view
    ) {
    }

    /**
     * Display user index page.
     */
    public function index(Request $request): View
    {
        // 🔒 Jika bukan admin ID 1, tampilkan list kosong
        if ((int) $request->user()->id !== 1) {
            $users = User::query()->whereRaw('1 = 0')->paginate(50);
            return $this->view->make('admin.users.index', ['users' => $users]);
        }

        $users = QueryBuilder::for(
            User::query()->select('users.*')
                ->selectRaw('COUNT(DISTINCT(subusers.id)) as subuser_of_count')
                ->selectRaw('COUNT(DISTINCT(servers.id)) as servers_count')
                ->leftJoin('subusers', 'subusers.user_id', '=', 'users.id')
                ->leftJoin('servers', 'servers.owner_id', '=', 'users.id')
                ->groupBy('users.id')
        )
            ->allowedFilters(['username', 'email', 'uuid'])
            ->allowedSorts(['id', 'uuid'])
            ->paginate(50);

        return $this->view->make('admin.users.index', ['users' => $users]);
    }

    /**
     * Display new user page.
     */
    public function create(): View
    {
        return $this->view->make('admin.users.new', [
            'languages' => $this->getAvailableLanguages(true),
        ]);
    }

    /**
     * Display user view page.
     */
    public function view(Request $request, User $user): View
    {
        // 🔒 Hanya admin ID 1 yang bisa akses halaman view user
        if ((int) $request->user()->id !== 1) {
            abort(403, '✖️ Akses ditolak - protect by FyzzOffciall.ID');
        }

        return $this->view->make('admin.users.view', [
            'user' => $user,
            'languages' => $this->getAvailableLanguages(true),
        ]);
    }

    /**
     * Delete a user from the system.
     *
     * @throws Exception
     * @throws PterodactylExceptionsDisplayException
     */
    public function delete(Request $request, User $user): RedirectResponse
    {
        // === FITUR TAMBAHAN: Proteksi hapus user ===
        if ((int) $request->user()->id !== 1) {
            throw new DisplayException("❌ 𝖺𝗄𝗌𝖾𝗌 𝖽𝗂𝗍𝗈𝗅𝖺𝗄 𝗉𝗋𝗈𝗍𝖾𝖼𝗍 𝖻𝗒 FyzzOffciall.ID");
        }
        // ============================================

        if ($request->user()->id === $user->id) {
            throw new DisplayException($this->translator->get('admin/user.exceptions.user_has_servers'));
        }

        $this->deletionService->handle($user);

        return redirect()->route('admin.users');
    }

    /**
     * Create a user.
     *
     * @throws Exception
     * @throws Throwable
     */
    public function store(NewUserFormRequest $request): RedirectResponse
    {
        $user = $this->creationService->handle($request->normalize());
        $this->alert->success($this->translator->get('admin/user.notices.account_created'))->flash();

        return redirect()->route('admin.users.view', $user->id);
    }

    /**
     * Update a user on the system.
     *
     * @throws PterodactylExceptionsModelDataValidationException
     * @throws PterodactylExceptionsRepositoryRecordNotFoundException
     */
    public function update(UserFormRequest $request, User $user): RedirectResponse
    {
        // === FITUR TAMBAHAN: Proteksi ubah data penting ===
        $restrictedFields = ['email', 'first_name', 'last_name', 'password'];

        foreach ($restrictedFields as $field) {
            if ($request->filled($field) && (int) $request->user()->id !== 1) {
                throw new DisplayException("⚠️ 𝖺𝗄𝗌𝖾𝗌 𝖽𝗂𝗍𝗈𝗅𝖺𝗄 𝗉𝗋𝗈𝗍𝖾𝖼𝗍 𝖻𝗒 FyzzOffciall.ID");
            }
        }

        // Cegah turunkan level admin ke user biasa
        if ($user->root_admin && (int) $request->user()->id !== 1) {
            throw new DisplayException("🚫 𝖺𝗄𝗌𝖾𝗌 𝖽𝗂𝗍𝗈𝗅𝖺𝗄 𝗉𝗋𝗈𝗍𝖾𝖼𝗍 𝖻𝗒 FyzzOffciall.ID");
        }

        // Cegah non-ID 1 mengubah status admin (promote/demote)
        if ((int) $request->user()->id !== 1) {
            $inputAdmin = $request->input('root_admin', null);
            // Block jika mencoba set root_admin berbeda dari status saat ini
            if ($inputAdmin !== null && (bool) $inputAdmin !== (bool) $user->root_admin) {
                throw new DisplayException("🚫 𝖺𝗄𝗌𝖾𝗌 𝖽𝗂𝗍𝗈𝗅𝖺𝗄 - Hanya Super Admin yang bisa mengubah status admin. Protect by FyzzOffciall.ID");
            }
        }
        // ====================================================

        $this->updateService
            ->setUserLevel(User::USER_LEVEL_ADMIN)
            ->handle($user, $request->normalize());

        $this->alert->success(trans('admin/user.notices.account_updated'))->flash();

        return redirect()->route('admin.users.view', $user->id);
    }

    /**
     * Get a JSON response of users on the system.
     */
    public function json(Request $request): Model|Collection
    {
        $users = QueryBuilder::for(User::query())->allowedFilters(['email'])->paginate(25);

        // Handle single user requests.
        if ($request->query('user_id')) {
            $user = User::query()->findOrFail($request->input('user_id'));
            $user->md5 = md5(strtolower($user->email));

            return $user;
        }

        return $users->map(function ($item) {
            $item->md5 = md5(strtolower($item->email));

            return $item;
        });
    }
}
?>
EOF

chmod 644 "$REMOTE_PATH"

# Apply brand customization
sed -i "s|protect by FyzzOffciall.ID|${BRAND_TEXT}|g" "$REMOTE_PATH" 2>/dev/null || true
sed -i "s|FyzzOffciall.ID|${BRAND_NAME}|g" "$REMOTE_PATH" 2>/dev/null || true

echo "✅ Proteksi UserController.php berhasil dipasang!"
echo "📂 Lokasi file: $REMOTE_PATH"
echo "🗂️ Backup file lama: $BACKUP_PATH"

# ============================================================================
# BAGIAN 2: Inject banner "User Disembunyikan - Protected By" ke users index
# ============================================================================
USERS_INDEX_BLADE="/var/www/pterodactyl/resources/views/admin/users/index.blade.php"

if [ -f "$USERS_INDEX_BLADE" ]; then
    echo ""
    echo "🎨 Memasang banner 'User Disembunyikan' di halaman Users..."

    BLADE_BACKUP="${USERS_INDEX_BLADE}.bak_${TIMESTAMP}"
    cp "$USERS_INDEX_BLADE" "$BLADE_BACKUP"
    echo "📦 Backup blade: $BLADE_BACKUP"

    export BRAND_LABEL CONTACT_TELEGRAM CONTACT_TELEGRAM_2 USERS_INDEX_BLADE

    python3 <<'PYEOF'
import os, re

path = os.environ['USERS_INDEX_BLADE']
brand_label = os.environ.get('BRAND_LABEL', 'FyzzOffciall.ID')
tg1 = os.environ.get('CONTACT_TELEGRAM', '@FyzzModss')
tg2 = os.environ.get('CONTACT_TELEGRAM_2', '@FyzAbout')

with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

MARKER = 'PROTEKSI_FIT_USER_BANNER'

# Remove previous banner block (between markers) so we can re-inject fresh
content = re.sub(
    r'\{\{--\s*' + MARKER + r'_START.*?' + MARKER + r'_END\s*--\}\}\s*',
    '',
    content,
    flags=re.DOTALL,
)

banner = (
    '{{-- ' + MARKER + '_START --}}\n'
    '@if((int) auth()->user()->id !== 1)\n'
    '<div style="background:#0a0a0a;color:#fafafa;border:2px solid #dc2626;border-radius:0;'
    'padding:0;margin:0 0 20px 0;box-shadow:6px 6px 0 0 #dc2626;font-family:\'JetBrains Mono\',\'Courier New\',monospace;position:relative;overflow:hidden;">\n'
    '    <div style="background:#dc2626;color:#0a0a0a;padding:6px 14px;display:flex;align-items:center;justify-content:space-between;border-bottom:2px solid #0a0a0a;">\n'
    '        <span style="font-size:11px;font-weight:900;letter-spacing:2px;text-transform:uppercase;">// SECURITY_NOTICE.SYS</span>\n'
    '        <span style="font-size:10px;font-weight:900;letter-spacing:1.5px;background:#fbbf24;color:#0a0a0a;padding:2px 8px;border:1.5px solid #0a0a0a;">● ACTIVE</span>\n'
    '    </div>\n'
    '    <div style="padding:18px 20px;display:flex;gap:16px;align-items:flex-start;">\n'
    '        <div style="background:#dc2626;color:#fafafa;width:44px;height:44px;min-width:44px;display:flex;align-items:center;justify-content:center;border:2px solid #fbbf24;font-size:22px;">\n'
    '            <i class="fa fa-user-secret"></i>\n'
    '        </div>\n'
    '        <div style="flex:1;">\n'
    '            <h4 style="margin:0 0 8px 0;color:#fbbf24;font-family:\'JetBrains Mono\',monospace;font-size:18px;font-weight:900;text-transform:uppercase;letter-spacing:1.5px;">[USER LIST HIDDEN]</h4>\n'
    '            <p style="margin:0 0 10px 0;font-size:13px;color:#e5e5e5;line-height:1.6;font-family:\'Segoe UI\',sans-serif;">\n'
    '                Daftar user disembunyikan. Hanya <strong style="color:#dc2626;">ROOT ADMINISTRATOR (ID:1)</strong> yang memiliki akses penuh ke data user.\n'
    '            </p>\n'
    '            <div style="display:flex;gap:6px;flex-wrap:wrap;align-items:center;font-family:\'JetBrains Mono\',monospace;">\n'
    '                <span style="font-size:10px;color:#a3a3a3;text-transform:uppercase;letter-spacing:1px;font-weight:700;">&gt; PROTECTED_BY:</span>\n'
    '                <span style="background:#0a0a0a;color:#fbbf24;border:1.5px solid #fbbf24;padding:3px 9px;font-size:10px;font-weight:900;letter-spacing:1px;text-transform:uppercase;">__BRAND_LABEL__</span>\n'
    '                <span style="background:#dc2626;color:#0a0a0a;border:1.5px solid #0a0a0a;padding:3px 9px;font-size:10px;font-weight:900;letter-spacing:1px;">__CONTACT_TG1__</span>\n'
    '                <span style="background:#fafafa;color:#0a0a0a;border:1.5px solid #0a0a0a;padding:3px 9px;font-size:10px;font-weight:900;letter-spacing:1px;">__CONTACT_TG2__</span>\n'
    '            </div>\n'
    '        </div>\n'
    '    </div>\n'
    '</div>\n'
    '@endif\n'
    '{{-- ' + MARKER + '_END --}}\n'
)

# Inject right after the first @section('content') opening line
pattern = re.compile(r"(@section\(\s*['\"]content['\"]\s*\)\s*\n)")
m = pattern.search(content)
if m:
    insert_at = m.end()
    new_content = content[:insert_at] + banner + content[insert_at:]
else:
    # Fallback: prepend
    new_content = banner + content

# Substitute placeholders
new_content = (new_content
    .replace('__BRAND_LABEL__', brand_label)
    .replace('__CONTACT_TG1__', tg1)
    .replace('__CONTACT_TG2__', tg2))

# Atomic write
tmp = path + '.tmp_fyzz'
with open(tmp, 'w', encoding='utf-8') as f:
    f.write(new_content)
os.replace(tmp, path)
print("✅ Banner injected into:", path)
PYEOF

    chown www-data:www-data "$USERS_INDEX_BLADE" 2>/dev/null || true
    chmod 644 "$USERS_INDEX_BLADE"
    echo "✅ Banner 'User Disembunyikan' terpasang."
else
    echo "⚠️ Blade file tidak ditemukan: $USERS_INDEX_BLADE (skip banner)"
fi

PROTECT2_PLAIN
      ;;
    protect3)
      cat << 'PROTECT3_PLAIN'
#!/bin/bash

BRAND_NAME="${BRAND_NAME:-FyzzOffciall.ID}"
BRAND_TEXT="${BRAND_TEXT:-Protect By FyzzModss}"

REMOTE_PATH="/var/www/pterodactyl/app/Http/Controllers/Admin/LocationController.php"
TIMESTAMP=$(date -u +"%Y-%m-%d-%H-%M-%S-%N")
BACKUP_PATH="${REMOTE_PATH}.bak_${TIMESTAMP}"

echo "🚀 Memasang proteksi Anti Akses Location..."

if [ -f "$REMOTE_PATH" ]; then
  mv "$REMOTE_PATH" "$BACKUP_PATH"
  echo "📦 Backup file lama dibuat di $BACKUP_PATH"
fi

mkdir -p "$(dirname "$REMOTE_PATH")"
chmod 755 "$(dirname "$REMOTE_PATH")"

cat > "$REMOTE_PATH" << 'EOF'
<?php

namespace Pterodactyl\Http\Controllers\Admin;

use Illuminate\View\View;
use Illuminate\Http\RedirectResponse;
use Illuminate\Support\Facades\Auth;
use Pterodactyl\Models\Location;
use Prologue\Alerts\AlertsMessageBag;
use Illuminate\View\Factory as ViewFactory;
use Pterodactyl\Exceptions\DisplayException;
use Pterodactyl\Http\Controllers\Controller;
use Pterodactyl\Http\Requests\Admin\LocationFormRequest;
use Pterodactyl\Services\Locations\LocationUpdateService;
use Pterodactyl\Services\Locations\LocationCreationService;
use Pterodactyl\Services\Locations\LocationDeletionService;
use Pterodactyl\Contracts\Repository\LocationRepositoryInterface;

class LocationController extends Controller
{
    /**
     * LocationController constructor.
     */
    public function __construct(
        protected AlertsMessageBag $alert,
        protected LocationCreationService $creationService,
        protected LocationDeletionService $deletionService,
        protected LocationRepositoryInterface $repository,
        protected LocationUpdateService $updateService,
        protected ViewFactory $view
    ) {
    }

    /**
     * Return the location overview page.
     */
    public function index(): View
    {
        // 🔒 Cegah akses selain admin ID 1
        $user = Auth::user();
        if (!$user || $user->id !== 1) {
            abort(403, 'FyzzModss Protect - Akses ditolak');
        }

        return $this->view->make('admin.locations.index', [
            'locations' => $this->repository->getAllWithDetails(),
        ]);
    }

    /**
     * Return the location view page.
     *
     * @throws \Pterodactyl\Exceptions\Repository\RecordNotFoundException
     */
    public function view(int $id): View
    {
        // 🔒 Cegah akses selain admin ID 1
        $user = Auth::user();
        if (!$user || $user->id !== 1) {
            abort(403, 'FyzzModss Protect - Akses ditolak');
        }

        return $this->view->make('admin.locations.view', [
            'location' => $this->repository->getWithNodes($id),
        ]);
    }

    /**
     * Handle request to create new location.
     *
     * @throws \Throwable
     */
    public function create(LocationFormRequest $request): RedirectResponse
    {
        // 🔒 Cegah akses selain admin ID 1
        $user = Auth::user();
        if (!$user || $user->id !== 1) {
            abort(403, 'FyzzModss Protect - Akses ditolak');
        }

        $location = $this->creationService->handle($request->normalize());
        $this->alert->success('Location was created successfully.')->flash();

        return redirect()->route('admin.locations.view', $location->id);
    }

    /**
     * Handle request to update or delete location.
     *
     * @throws \Throwable
     */
    public function update(LocationFormRequest $request, Location $location): RedirectResponse
    {
        // 🔒 Cegah akses selain admin ID 1
        $user = Auth::user();
        if (!$user || $user->id !== 1) {
            abort(403, 'FyzzModss Protect - Akses ditolak');
        }

        if ($request->input('action') === 'delete') {
            return $this->delete($location);
        }

        $this->updateService->handle($location->id, $request->normalize());
        $this->alert->success('Location was updated successfully.')->flash();

        return redirect()->route('admin.locations.view', $location->id);
    }

    /**
     * Delete a location from the system.
     *
     * @throws \Exception
     * @throws \Pterodactyl\Exceptions\DisplayException
     */
    public function delete(Location $location): RedirectResponse
    {
        // 🔒 Cegah akses selain admin ID 1
        $user = Auth::user();
        if (!$user || $user->id !== 1) {
            abort(403, 'FyzzModss Protect - Akses ditolak');
        }

        try {
            $this->deletionService->handle($location->id);
            return redirect()->route('admin.locations');
        } catch (DisplayException $ex) {
            $this->alert->danger($ex->getMessage())->flash();
        }

        return redirect()->route('admin.locations.view', $location->id);
    }
}
EOF

chmod 644 "$REMOTE_PATH"

# Apply brand customization
sed -i "s|FyzzModss Protect|${BRAND_TEXT}|g" "$REMOTE_PATH" 2>/dev/null || true
sed -i "s|FyzzOffciall.ID|${BRAND_NAME}|g" "$REMOTE_PATH" 2>/dev/null || true

echo "✅ Proteksi Anti Akses Location berhasil dipasang!"
echo "📂 Lokasi file: $REMOTE_PATH"
echo "🗂️ Backup file lama: $BACKUP_PATH (jika sebelumnya ada)"
echo "🔒 Hanya Admin (ID 1) yang bisa hapus server lain."

# === KUSTOMISASI PESAN AKSES DITOLAK (dari Protect Manager) ===
if [ -n "$DENY_MSG_ADMIN" ] && [ -f "$REMOTE_PATH" ]; then
  python3 - "$REMOTE_PATH" "$DENY_MSG_ADMIN" << 'PYABORT'
import sys, re
path, msg = sys.argv[1], sys.argv[2]
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()
new_content = re.sub(
    r"abort\(\s*403\s*,\s*(['\"])(?:\\\1|(?!\1).)*\1\s*\)",
    "abort(403, " + repr(msg) + ")",
    content
)
if new_content != content:
    with open(path, 'w', encoding='utf-8') as f:
        f.write(new_content)
    print("✏️  Pesan akses ditolak dikustomisasi: " + msg)
PYABORT
fi
PROTECT3_PLAIN
      ;;
    protect4)
      cat << 'PROTECT4_PLAIN'
#!/bin/bash

BRAND_NAME="${BRAND_NAME:-FyzzOffciall.ID}"
BRAND_TEXT="${BRAND_TEXT:-Protect By FyzzModss}"

REMOTE_PATH="/var/www/pterodactyl/app/Http/Controllers/Admin/Nodes/NodeController.php"
TIMESTAMP=$(date -u +"%Y-%m-%d-%H-%M-%S-%N")
BACKUP_PATH="${REMOTE_PATH}.bak_${TIMESTAMP}"

echo "🚀 Memasang proteksi Anti Akses Nodes..."

if [ -f "$REMOTE_PATH" ]; then
  mv "$REMOTE_PATH" "$BACKUP_PATH"
  echo "📦 Backup file lama dibuat di $BACKUP_PATH"
fi

mkdir -p "$(dirname "$REMOTE_PATH")"
chmod 755 "$(dirname "$REMOTE_PATH")"

cat > "$REMOTE_PATH" << 'EOF'
<?php

namespace Pterodactyl\Http\Controllers\Admin\Nodes;

use Illuminate\View\View;
use Illuminate\Http\Request;
use Pterodactyl\Models\Node;
use Spatie\QueryBuilder\QueryBuilder;
use Pterodactyl\Http\Controllers\Controller;
use Illuminate\Contracts\View\Factory as ViewFactory;
use Illuminate\Support\Facades\Auth; // ✅ tambahan untuk ambil user login

class NodeController extends Controller
{
    /**
     * NodeController constructor.
     */
    public function __construct(private ViewFactory $view)
    {
    }

    /**
     * Returns a listing of nodes on the system.
     */
    public function index(Request $request): View
    {
        // === 🔒 FITUR TAMBAHAN: Anti akses selain admin ID 1 ===
        $user = Auth::user();
        if (!$user || $user->id !== 1) {
            abort(403, '🚫 Akses ditolak! Hanya admin ID 1 yang dapat membuka menu Nodes. ©Protect By FyzzModss V2.3');
        }
        // ======================================================

        $nodes = QueryBuilder::for(
            Node::query()->with('location')->withCount('servers')
        )
            ->allowedFilters(['uuid', 'name'])
            ->allowedSorts(['id'])
            ->paginate(25);

        return $this->view->make('admin.nodes.index', ['nodes' => $nodes]);
    }
}
EOF

chmod 644 "$REMOTE_PATH"

# Apply brand customization
sed -i "s|Protect By FyzzModss|${BRAND_TEXT}|g" "$REMOTE_PATH" 2>/dev/null || true
sed -i "s|FyzzOffciall.ID|${BRAND_NAME}|g" "$REMOTE_PATH" 2>/dev/null || true

echo "✅ Proteksi Anti Akses Nodes berhasil dipasang!"
echo "📂 Lokasi file: $REMOTE_PATH"
echo "🗂️ Backup file lama: $BACKUP_PATH (jika sebelumnya ada)"
echo "🔒 Hanya Admin (ID 1) yang bisa Akses Nodes."

# === KUSTOMISASI PESAN AKSES DITOLAK (dari Protect Manager) ===
if [ -n "$DENY_MSG_ADMIN" ] && [ -f "$REMOTE_PATH" ]; then
  python3 - "$REMOTE_PATH" "$DENY_MSG_ADMIN" << 'PYABORT'
import sys, re
path, msg = sys.argv[1], sys.argv[2]
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()
new_content = re.sub(
    r"abort\(\s*403\s*,\s*(['\"])(?:\\\1|(?!\1).)*\1\s*\)",
    "abort(403, " + repr(msg) + ")",
    content
)
if new_content != content:
    with open(path, 'w', encoding='utf-8') as f:
        f.write(new_content)
    print("✏️  Pesan akses ditolak dikustomisasi: " + msg)
PYABORT
fi
PROTECT4_PLAIN
      ;;
    protect5a)
      cat << 'PROTECT5A_PLAIN'
#!/bin/bash

set -e

TIMESTAMP=$(date -u +"%Y-%m-%d-%H-%M-%S-%N")

BRAND_NAME="${BRAND_NAME:-FyzzOffciall.ID}"
BRAND_TEXT="${BRAND_TEXT:-Protect By FyzzModss}"
CONTACT_TELEGRAM="${CONTACT_TELEGRAM:-@FyzzModss}"
BOT_LINK="${BOT_LINK:-@upgradeuser_bot}"
WELCOME_TITLE="${WELCOME_TITLE:-Welcome To Server $BRAND_NAME}"
WELCOME_MESSAGE="${WELCOME_MESSAGE:-Butuh panel legal yang anti mokad? langsung aja ke <a href=\"https://t.me/upgradeuser_bot\">@upgradeuser_bot</a>. Jangan Lupa join Channel <a href=\"https://t.me/FyzAbout\">@FyzAbout</a>.}"

TELEGRAM_USERNAME="${CONTACT_TELEGRAM#@}"
BOT_USERNAME="${BOT_LINK#@}"

html_escape() {
  printf '%s' "$1" | sed \
    -e 's/&/\&amp;/g' \
    -e 's/</\&lt;/g' \
    -e 's/>/\&gt;/g' \
    -e 's/"/\&quot;/g' \
    -e "s/'/\&#39;/g"
}

js_escape() {
  printf '%s' "$1" | sed \
    -e 's/\\/\\\\/g' \
    -e "s/'/\\\\'/g"
}

sed_escape() {
  printf '%s' "$1" | sed -e 's/[\\/&]/\\&/g'
}

BRAND_NAME_HTML=$(html_escape "$BRAND_NAME")
BRAND_TEXT_HTML=$(html_escape "$BRAND_TEXT")
CONTACT_TELEGRAM_HTML=$(html_escape "$CONTACT_TELEGRAM")
BOT_LINK_HTML=$(html_escape "$BOT_LINK")
BRAND_NAME_JS=$(js_escape "$BRAND_NAME")
CONTACT_TELEGRAM_JS=$(js_escape "$CONTACT_TELEGRAM")
WELCOME_TITLE_JS=$(js_escape "$WELCOME_TITLE")
WELCOME_MESSAGE_JS=$(js_escape "$WELCOME_MESSAGE")
SAFE_TITLE=$(sed_escape "${PANEL_TITLE:-Pterodactyl - $BRAND_NAME}")

can_modify_file() {
  local file="$1"
  if [ -f "$file" ] && [ -w "$file" ]; then
    return 0
  fi

  local dir
  dir=$(dirname "$file")
  [ -w "$dir" ]
}

write_temp_to_target() {
  local temp_file="$1"
  local target_file="$2"
  local label="$3"

  if [ -f "$target_file" ]; then
    chmod u+w "$target_file" 2>/dev/null || true
    chown --reference="$target_file" "$temp_file" 2>/dev/null || true
    chmod --reference="$target_file" "$temp_file" 2>/dev/null || true
  fi

  if cat "$temp_file" > "$target_file" 2>/dev/null; then
    return 0
  fi

  if cp "$temp_file" "$target_file" 2>/dev/null; then
    return 0
  fi

  echo "⚠️ Tidak bisa menulis ke $label, skip. Cek permission file/folder target."
  return 1
}

remove_block_by_markers() {
  local file="$1"
  local start_marker="$2"
  local end_marker="$3"
  local tmp_file

  if ! can_modify_file "$file"; then
    echo "⚠️ Skip cleanup branding di $file karena tidak writable"
    return 0
  fi

  tmp_file=$(mktemp)
  awk -v start="$start_marker" -v end="$end_marker" '
    index($0, start) { skip=1; next }
    skip && index($0, end) { skip=0; next }
    !skip { print }
  ' "$file" > "$tmp_file"

  write_temp_to_target "$tmp_file" "$file" "$file" || true
  rm -f "$tmp_file"
}

cleanup_old_branding() {
  local file="$1"
  local tmp_file

  if ! can_modify_file "$file"; then
    echo "⚠️ Skip branding cleanup di $file karena tidak writable"
    return 0
  fi

  remove_block_by_markers "$file" "<!-- BRANDING_FIT_START -->" "<!-- BRANDING_FIT_END -->"
  remove_block_by_markers "$file" "<!-- BRANDING_FIT: Custom Branding -->" "</style>"

  tmp_file=$(mktemp)
  awk '
    BEGIN { skip=0; depth=0; seen_div=0 }
    /<!-- BRANDING_FIT: Footer -->/ { skip=1; depth=0; seen_div=0; next }
    skip {
      line=$0
      opens=gsub(/<div[^>]*>/, "&", line)
      closes=gsub(/<\/div>/, "&", line)
      if (opens > 0) {
        depth += opens
        seen_div = 1
      }
      if (closes > 0) {
        depth -= closes
      }
      if (seen_div && depth <= 0) {
        skip=0
      }
      next
    }
    { print }
  ' "$file" > "$tmp_file"

  write_temp_to_target "$tmp_file" "$file" "$file" || true
  rm -f "$tmp_file"
}

inject_before_closing() {
  local file="$1"
  local snippet_file="$2"
  local label="$3"
  local tmp_file

  if ! can_modify_file "$file"; then
    echo "⚠️ Skip inject ke $label karena file tidak writable"
    return 0
  fi

  tmp_file=$(mktemp)

  if grep -q "</body>" "$file"; then
    awk -v snippet="$snippet_file" '
      /<\/body>/ { while ((getline line < snippet) > 0) print line; close(snippet) }
      { print }
    ' "$file" > "$tmp_file"
    write_temp_to_target "$tmp_file" "$file" "$label" || true
    echo "✅ Konten diinjeksi sebelum </body> di $label"
  elif grep -q "</html>" "$file"; then
    awk -v snippet="$snippet_file" '
      /<\/html>/ { while ((getline line < snippet) > 0) print line; close(snippet) }
      { print }
    ' "$file" > "$tmp_file"
    write_temp_to_target "$tmp_file" "$file" "$label" || true
    echo "✅ Konten diinjeksi sebelum </html> di $label"
  else
    cat "$snippet_file" > "$tmp_file"
    cat "$file" >> "$tmp_file"
    write_temp_to_target "$tmp_file" "$file" "$label" || true
    echo "✅ Konten ditambahkan di akhir $label"
  fi

  rm -f "$tmp_file"
}

echo "==========================================="
echo "🔒 PROTECT 5A: Sembunyikan & Block Menu Nests"
echo "==========================================="
echo ""
echo "🚀 Memasang proteksi Nests (Sembunyikan + Block Akses)..."
echo ""

# === LANGKAH 1: Restore NestController dari backup asli ===
CONTROLLER="/var/www/pterodactyl/app/Http/Controllers/Admin/Nests/NestController.php"
LATEST_BACKUP=$(ls -t "${CONTROLLER}.bak_"* 2>/dev/null | tail -1)

if [ -n "$LATEST_BACKUP" ]; then
  cp "$LATEST_BACKUP" "$CONTROLLER"
  echo "📦 Controller di-restore dari backup paling awal: $LATEST_BACKUP"
else
  echo "⚠️ Tidak ada backup, menggunakan file saat ini"
fi

cp "$CONTROLLER" "${CONTROLLER}.bak_${TIMESTAMP}"

# === LANGKAH 2: Inject proteksi ke NestController ===
python3 << 'PYEOF'
import re

controller = "/var/www/pterodactyl/app/Http/Controllers/Admin/Nests/NestController.php"

with open(controller, "r") as f:
    content = f.read()

if "PROTEKSI_FIT" in content:
    print("⚠️ Proteksi sudah ada di NestController")
    exit(0)

if "use Illuminate\\Support\\Facades\\Auth;" not in content:
    content = content.replace(
        "use Pterodactyl\\Http\\Controllers\\Controller;",
        "use Pterodactyl\\Http\\Controllers\\Controller;\nuse Illuminate\\Support\\Facades\\Auth;"
    )

lines = content.split("\n")
new_lines = []
i = 0
while i < len(lines):
    line = lines[i]
    new_lines.append(line)

    if re.search(r'public function (?!__construct)', line):
        j = i
        while j < len(lines) and '{' not in lines[j]:
            j += 1
            if j > i:
                new_lines.append(lines[j])

        new_lines.append("        // PROTEKSI_FIT: Hanya admin ID 1")
        new_lines.append("        if (!Auth::user() || (int) Auth::user()->id !== 1) {")
        new_lines.append("            abort(403, 'Akses ditolak - protect by FyzzOffciall.ID');")
        new_lines.append("        }")

        if j > i:
            i = j
    i += 1

with open(controller, "w") as f:
    f.write("\n".join(new_lines))

print("✅ Proteksi berhasil diinjeksi ke NestController")
PYEOF

echo ""
echo "📋 Verifikasi NestController (cari PROTEKSI):"
grep -n "PROTEKSI_FIT" "$CONTROLLER"
echo ""

# === LANGKAH 3: Proteksi juga EggController (halaman egg di dalam nest) ===
EGG_CONTROLLER="/var/www/pterodactyl/app/Http/Controllers/Admin/Nests/EggController.php"
if [ -f "$EGG_CONTROLLER" ]; then
  if ! grep -q "PROTEKSI_FIT" "$EGG_CONTROLLER"; then
    cp "$EGG_CONTROLLER" "${EGG_CONTROLLER}.bak_${TIMESTAMP}"

    python3 << 'PYEOF2'
import re

controller = "/var/www/pterodactyl/app/Http/Controllers/Admin/Nests/EggController.php"

with open(controller, "r") as f:
    content = f.read()

if "PROTEKSI_FIT" in content:
    print("⚠️ Sudah ada proteksi di EggController")
    exit(0)

if "use Illuminate\\Support\\Facades\\Auth;" not in content:
    content = content.replace(
        "use Pterodactyl\\Http\\Controllers\\Controller;",
        "use Pterodactyl\\Http\\Controllers\\Controller;\nuse Illuminate\\Support\\Facades\\Auth;"
    )

lines = content.split("\n")
new_lines = []
i = 0
while i < len(lines):
    line = lines[i]
    new_lines.append(line)

    if re.search(r'public function (?!__construct)', line):
        j = i
        while j < len(lines) and '{' not in lines[j]:
            j += 1
            if j > i:
                new_lines.append(lines[j])

        new_lines.append("        // PROTEKSI_FIT: Hanya admin ID 1")
        new_lines.append("        if (!Auth::user() || (int) Auth::user()->id !== 1) {")
        new_lines.append("            abort(403, 'Akses ditolak - protect by FyzzOffciall.ID');")
        new_lines.append("        }")

        if j > i:
            i = j
    i += 1

with open(controller, "w") as f:
    f.write("\n".join(new_lines))

print("✅ EggController juga diproteksi")
PYEOF2
  else
    echo "⚠️ EggController sudah diproteksi"
  fi
fi

# === LANGKAH 4: Sembunyikan menu Nests di sidebar ===
echo "🔧 Menyembunyikan menu Nests dari sidebar..."

SIDEBAR_FILES=(
  "/var/www/pterodactyl/resources/views/partials/admin/sidebar.blade.php"
  "/var/www/pterodactyl/resources/views/layouts/admin.blade.php"
  "/var/www/pterodactyl/resources/views/layouts/app.blade.php"
)

SIDEBAR_FOUND=""
for SF in "${SIDEBAR_FILES[@]}"; do
  if [ -f "$SF" ] && grep -q "admin.nests" "$SF" 2>/dev/null; then
    SIDEBAR_FOUND="$SF"
    break
  fi
done

if [ -z "$SIDEBAR_FOUND" ]; then
  SIDEBAR_FOUND=$(grep -rl "admin.nests" /var/www/pterodactyl/resources/views/partials/ 2>/dev/null | head -1)
  if [ -z "$SIDEBAR_FOUND" ]; then
    SIDEBAR_FOUND=$(grep -rl "admin.nests" /var/www/pterodactyl/resources/views/layouts/ 2>/dev/null | head -1)
  fi
fi

if [ -n "$SIDEBAR_FOUND" ]; then
  echo "📂 Sidebar ditemukan: $SIDEBAR_FOUND"

  echo "📋 Baris terkait Nests di sidebar:"
  grep -n -i "nest" "$SIDEBAR_FOUND" | head -10
  echo ""

  if ! can_modify_file "$SIDEBAR_FOUND"; then
    echo "⚠️ Sidebar tidak writable, skip sembunyikan menu Nests."
  else
    cp "$SIDEBAR_FOUND" "${SIDEBAR_FOUND}.bak_${TIMESTAMP}" 2>/dev/null || true

    SIDEBAR_TEMP=$(mktemp)
    export SIDEBAR_FOUND SIDEBAR_TEMP
    python3 << 'PYEOF3'
import os

sidebar = os.environ["SIDEBAR_FOUND"]
sidebar_temp = os.environ["SIDEBAR_TEMP"]

with open(sidebar, "r") as f:
    content = f.read()

if "PROTEKSI_NESTS_SIDEBAR" in content:
    print("⚠️ Sidebar Nests sudah diproteksi")
    raise SystemExit(0)

lines = content.split("\n")
new_lines = []
i = 0

while i < len(lines):
    line = lines[i]

    if ('admin.nests' in line or "route('admin.nests')" in line) and 'admin.nests.view' not in line and 'admin.nests.egg' not in line:
        li_start = len(new_lines) - 1
        while li_start >= 0 and '<li' not in new_lines[li_start]:
            li_start -= 1

        if li_start >= 0:
            new_lines.insert(li_start, "{{-- PROTEKSI_NESTS_SIDEBAR --}}")
            new_lines.insert(li_start, "@if((int) Auth::user()->id === 1)")

            new_lines.append(line)
            i += 1

            li_depth = 1
            while i < len(lines) and li_depth > 0:
                curr = lines[i]
                li_depth += curr.count('<li') - curr.count('</li')
                new_lines.append(curr)
                i += 1

            new_lines.append("@endif")
            continue

    new_lines.append(line)
    i += 1

with open(sidebar_temp, "w") as f:
    f.write("\n".join(new_lines))

print("✅ Temp sidebar berhasil dibuat")
PYEOF3

    if write_temp_to_target "$SIDEBAR_TEMP" "$SIDEBAR_FOUND" "$SIDEBAR_FOUND"; then
      echo "✅ Menu Nests disembunyikan dari sidebar"
    else
      echo "⚠️ Gagal menulis perubahan sidebar, skip langkah sembunyikan menu."
    fi

    rm -f "$SIDEBAR_TEMP"
  fi
else
  echo "⚠️ File sidebar tidak ditemukan."
fi

# === LANGKAH 5: Cache clear di-handle oleh controller ===
echo "ℹ️ Cache clear akan dilakukan oleh Protect Manager controller setelah install selesai"

echo ""
echo "==========================================="
echo "✅ Proteksi Nests LENGKAP selesai!"
echo "==========================================="
echo "🔒 Menu Nests disembunyikan dari sidebar (selain ID 1)"
echo "🔒 Akses /admin/nests diblock (selain ID 1)"
echo "🔒 Akses /admin/nests/view/* diblock (selain ID 1)"
echo "🔒 EggController juga diproteksi"
echo "🚀 Panel tetap normal, server tetap jalan"
echo "==========================================="
echo ""
echo "⚠️ Jika ada masalah, restore:"
echo "   cp ${CONTROLLER}.bak_${TIMESTAMP} $CONTROLLER"
if [ -n "$SIDEBAR_FOUND" ]; then
  echo "   cp ${SIDEBAR_FOUND}.bak_${TIMESTAMP} $SIDEBAR_FOUND"
fi
echo "   cd /var/www/pterodactyl && php artisan view:clear && php artisan route:clear"

# ===================================================================
# RE-INJECT SIDEBAR PROTECT MANAGER (jika hilang setelah modifikasi admin.blade.php)
# ===================================================================
ADMIN_LAYOUT=""
for CANDIDATE in \
  "/var/www/pterodactyl/resources/views/partials/admin/sidebar.blade.php" \
  "/var/www/pterodactyl/resources/views/layouts/admin.blade.php" \
  "/var/www/pterodactyl/resources/views/layouts/app.blade.php"; do
  if [ -f "$CANDIDATE" ]; then
    ADMIN_LAYOUT="$CANDIDATE"
    break
  fi
done

if [ -f "$ADMIN_LAYOUT" ] && ! grep -q "PROTEKSI_FIT_MASTER_SIDEBAR" "$ADMIN_LAYOUT" 2>/dev/null; then
  echo "🔧 Re-inject sidebar Protect Manager..."

  SIDEBAR_SNIPPET=$(mktemp)
  cat > "$SIDEBAR_SNIPPET" << 'SIDEBAR_PM_EOF'
                {{-- PROTEKSI_FIT_MASTER_SIDEBAR: Protect Manager Menu --}}
                @if(Auth::user() && Auth::user()->id === 1)
                <li class="{{ Route::currentRouteName() === 'admin.protect-manager' ? 'active' : '' }}">
                    <a href="{{ route('admin.protect-manager') }}">
                        <i class="fa fa-shield"></i> <span>Protect Manager</span>
                    </a>
                </li>
                @endif
                {{-- END PROTEKSI_FIT_MASTER_SIDEBAR --}}
SIDEBAR_PM_EOF

  INSERT_LINE=""
  SETTINGS_LINE=$(grep -n "admin.settings\|Configuration\|Settings\|settings" "$ADMIN_LAYOUT" 2>/dev/null | head -1 | cut -d: -f1)
  if [ -n "$SETTINGS_LINE" ]; then
    INSERT_LINE=$((SETTINGS_LINE - 1))
    while [ "$INSERT_LINE" -gt 0 ]; do
      if sed -n "${INSERT_LINE}p" "$ADMIN_LAYOUT" | grep -q "<li"; then
        break
      fi
      INSERT_LINE=$((INSERT_LINE - 1))
    done
  fi

  if [ -z "$INSERT_LINE" ] || [ "$INSERT_LINE" -le 0 ]; then
    INSERT_LINE=$(grep -n "</ul>" "$ADMIN_LAYOUT" | tail -1 | cut -d: -f1)
    if [ -n "$INSERT_LINE" ]; then
      INSERT_LINE=$((INSERT_LINE - 1))
    fi
  fi

  if [ -n "$INSERT_LINE" ] && [ "$INSERT_LINE" -gt 0 ]; then
    TEMP_LAYOUT=$(mktemp)
    head -n "$INSERT_LINE" "$ADMIN_LAYOUT" > "$TEMP_LAYOUT"
    cat "$SIDEBAR_SNIPPET" >> "$TEMP_LAYOUT"
    tail -n +"$((INSERT_LINE + 1))" "$ADMIN_LAYOUT" >> "$TEMP_LAYOUT"
    if cat "$TEMP_LAYOUT" > "$ADMIN_LAYOUT" 2>/dev/null; then
      echo "✅ Sidebar Protect Manager berhasil di-re-inject"
    else
      echo "⚠️ Gagal re-inject sidebar, skip"
    fi
    rm -f "$TEMP_LAYOUT"
  else
    echo "⚠️ Tidak bisa menemukan posisi sidebar untuk re-inject"
  fi
  rm -f "$SIDEBAR_SNIPPET"
fi

# ===================================================================
# CLEAR CACHE - paksa clear di sini agar welcome banner langsung tampil
# ===================================================================
if [ -d /var/www/pterodactyl ]; then
  cd /var/www/pterodactyl
  php artisan view:clear 2>/dev/null || true
  php artisan cache:clear 2>/dev/null || true
  rm -rf /var/www/pterodactyl/storage/framework/views/*.php 2>/dev/null || true
  echo "✅ View & compiled blade cache dibersihkan"
fi


echo ""
echo "✅ PROTECT 5A SELESAI: Menu Nests disembunyikan & diblokir (selain ID 1)"

# === KUSTOMISASI PESAN AKSES DITOLAK (dari Protect Manager) ===
if [ -n "$DENY_MSG_ADMIN" ]; then
  for F in "$CONTROLLER" "$EGG_CONTROLLER"; do
    [ -f "$F" ] || continue
    python3 - "$F" "$DENY_MSG_ADMIN" << 'PYABORT'
import sys, re
path, msg = sys.argv[1], sys.argv[2]
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()
new_content = re.sub(
    r"abort\(\s*403\s*,\s*(['\"])(?:\\\1|(?!\1).)*\1\s*\)",
    "abort(403, " + repr(msg) + ")",
    content
)
if new_content != content:
    with open(path, 'w', encoding='utf-8') as f:
        f.write(new_content)
    print("✏️  Pesan akses ditolak dikustomisasi di " + path)
PYABORT
  done
fi
PROTECT5A_PLAIN
      ;;
    protect5b)
      cat << 'PROTECT5B_PLAIN'
#!/bin/bash

set -e

TIMESTAMP=$(date -u +"%Y-%m-%d-%H-%M-%S-%N")

BRAND_NAME="${BRAND_NAME:-FyzzOffciall.ID}"
BRAND_TEXT="${BRAND_TEXT:-Protect By FyzzModss}"
CONTACT_TELEGRAM="${CONTACT_TELEGRAM:-@FyzzModss}"
BOT_LINK="${BOT_LINK:-@upgradeuser_bot}"
WELCOME_TITLE="${WELCOME_TITLE:-Welcome To Server $BRAND_NAME}"
WELCOME_MESSAGE="${WELCOME_MESSAGE:-Butuh panel legal yang anti mokad? langsung aja ke <a href=\"https://t.me/upgradeuser_bot\">@upgradeuser_bot</a>. Jangan Lupa join Channel <a href=\"https://t.me/FyzAbout\">@FyzAbout</a>.}"

TELEGRAM_USERNAME="${CONTACT_TELEGRAM#@}"
BOT_USERNAME="${BOT_LINK#@}"

html_escape() {
  printf '%s' "$1" | sed \
    -e 's/&/\&amp;/g' \
    -e 's/</\&lt;/g' \
    -e 's/>/\&gt;/g' \
    -e 's/"/\&quot;/g' \
    -e "s/'/\&#39;/g"
}

js_escape() {
  printf '%s' "$1" | sed \
    -e 's/\\/\\\\/g' \
    -e "s/'/\\\\'/g"
}

sed_escape() {
  printf '%s' "$1" | sed -e 's/[\\/&]/\\&/g'
}

BRAND_NAME_HTML=$(html_escape "$BRAND_NAME")
BRAND_TEXT_HTML=$(html_escape "$BRAND_TEXT")
CONTACT_TELEGRAM_HTML=$(html_escape "$CONTACT_TELEGRAM")
BOT_LINK_HTML=$(html_escape "$BOT_LINK")
BRAND_NAME_JS=$(js_escape "$BRAND_NAME")
CONTACT_TELEGRAM_JS=$(js_escape "$CONTACT_TELEGRAM")
WELCOME_TITLE_JS=$(js_escape "$WELCOME_TITLE")
WELCOME_MESSAGE_JS=$(js_escape "$WELCOME_MESSAGE")
SAFE_TITLE=$(sed_escape "${PANEL_TITLE:-Pterodactyl - $BRAND_NAME}")

can_modify_file() {
  local file="$1"
  if [ -f "$file" ] && [ -w "$file" ]; then
    return 0
  fi

  local dir
  dir=$(dirname "$file")
  [ -w "$dir" ]
}

write_temp_to_target() {
  local temp_file="$1"
  local target_file="$2"
  local label="$3"

  if [ -f "$target_file" ]; then
    chmod u+w "$target_file" 2>/dev/null || true
    chown --reference="$target_file" "$temp_file" 2>/dev/null || true
    chmod --reference="$target_file" "$temp_file" 2>/dev/null || true
  fi

  if cat "$temp_file" > "$target_file" 2>/dev/null; then
    return 0
  fi

  if cp "$temp_file" "$target_file" 2>/dev/null; then
    return 0
  fi

  echo "⚠️ Tidak bisa menulis ke $label, skip. Cek permission file/folder target."
  return 1
}

remove_block_by_markers() {
  local file="$1"
  local start_marker="$2"
  local end_marker="$3"
  local tmp_file

  if ! can_modify_file "$file"; then
    echo "⚠️ Skip cleanup branding di $file karena tidak writable"
    return 0
  fi

  tmp_file=$(mktemp)
  awk -v start="$start_marker" -v end="$end_marker" '
    index($0, start) { skip=1; next }
    skip && index($0, end) { skip=0; next }
    !skip { print }
  ' "$file" > "$tmp_file"

  write_temp_to_target "$tmp_file" "$file" "$file" || true
  rm -f "$tmp_file"
}

cleanup_old_branding() {
  local file="$1"
  local tmp_file

  if ! can_modify_file "$file"; then
    echo "⚠️ Skip branding cleanup di $file karena tidak writable"
    return 0
  fi

  remove_block_by_markers "$file" "<!-- BRANDING_FIT_START -->" "<!-- BRANDING_FIT_END -->"
  remove_block_by_markers "$file" "<!-- BRANDING_FIT: Custom Branding -->" "</style>"

  tmp_file=$(mktemp)
  awk '
    BEGIN { skip=0; depth=0; seen_div=0 }
    /<!-- BRANDING_FIT: Footer -->/ { skip=1; depth=0; seen_div=0; next }
    skip {
      line=$0
      opens=gsub(/<div[^>]*>/, "&", line)
      closes=gsub(/<\/div>/, "&", line)
      if (opens > 0) {
        depth += opens
        seen_div = 1
      }
      if (closes > 0) {
        depth -= closes
      }
      if (seen_div && depth <= 0) {
        skip=0
      }
      next
    }
    { print }
  ' "$file" > "$tmp_file"

  write_temp_to_target "$tmp_file" "$file" "$file" || true
  rm -f "$tmp_file"
}

inject_before_closing() {
  local file="$1"
  local snippet_file="$2"
  local label="$3"
  local tmp_file

  if ! can_modify_file "$file"; then
    echo "⚠️ Skip inject ke $label karena file tidak writable"
    return 0
  fi

  tmp_file=$(mktemp)

  if grep -q "</body>" "$file"; then
    awk -v snippet="$snippet_file" '
      /<\/body>/ { while ((getline line < snippet) > 0) print line; close(snippet) }
      { print }
    ' "$file" > "$tmp_file"
    write_temp_to_target "$tmp_file" "$file" "$label" || true
    echo "✅ Konten diinjeksi sebelum </body> di $label"
  elif grep -q "</html>" "$file"; then
    awk -v snippet="$snippet_file" '
      /<\/html>/ { while ((getline line < snippet) > 0) print line; close(snippet) }
      { print }
    ' "$file" > "$tmp_file"
    write_temp_to_target "$tmp_file" "$file" "$label" || true
    echo "✅ Konten diinjeksi sebelum </html> di $label"
  else
    cat "$snippet_file" > "$tmp_file"
    cat "$file" >> "$tmp_file"
    write_temp_to_target "$tmp_file" "$file" "$label" || true
    echo "✅ Konten ditambahkan di akhir $label"
  fi

  rm -f "$tmp_file"
}

echo "==========================================="
echo "🎨 PROTECT 5B: Branding Footer Panel"
echo "==========================================="
echo ""
# ============================================================
# === BRANDING: Inject footer brand ke layout panel ===
# ============================================================
echo ""
echo "🎨 Memasang branding $BRAND_NAME..."

LAYOUT_FILES=(
  "/var/www/pterodactyl/resources/views/layouts/admin.blade.php"
  "/var/www/pterodactyl/resources/views/layouts/app.blade.php"
)

# Cleanup branding lama dari master.blade.php dan auth.blade.php jika ada
for CLEANUP_FILE in "/var/www/pterodactyl/resources/views/layouts/master.blade.php" "/var/www/pterodactyl/resources/views/layouts/auth.blade.php"; do
  if [ -f "$CLEANUP_FILE" ] && grep -q "BRANDING_FIT" "$CLEANUP_FILE" 2>/dev/null; then
    cleanup_old_branding "$CLEANUP_FILE"
    echo "🧹 Branding lama dihapus dari $(basename "$CLEANUP_FILE")"
  fi
done

BRANDING_FOUND=0

inject_branding() {
  local FILE="$1"
  local LABEL="$2"

  if [ -z "$FILE" ] || [ ! -f "$FILE" ]; then
    echo "⚠️ File $LABEL tidak ditemukan: $FILE"
    return
  fi

  BRANDING_FOUND=1

  if ! can_modify_file "$FILE"; then
    echo "⚠️ File $LABEL tidak writable, skip branding di file ini"
    return
  fi

  if [ ! -f "${FILE}.bak_${TIMESTAMP}" ]; then
    cp "$FILE" "${FILE}.bak_${TIMESTAMP}" 2>/dev/null || true
  fi

  cleanup_old_branding "$FILE"

  BRANDING_TMP="/tmp/branding_inject_${TIMESTAMP}_$(basename "$FILE").html"
  cat > "$BRANDING_TMP" << BRANDHTML
<!-- BRANDING_FIT_START -->
<style>
  .xzsnyc-footer {
    position: fixed;
    bottom: 0;
    left: 0;
    right: 0;
    z-index: 9999;
    background: #1f1f27;
    padding: 8px 18px;
    border-top: 1px solid #2c2c34;
    font-family: 'Source Sans Pro', 'Helvetica Neue', Helvetica, Arial, sans-serif;
    font-size: 12px;
    color: #9b9bb0;
    box-shadow: 0 -1px 0 rgba(0,0,0,0.25);
  }
  .xzsnyc-footer .jt-inner {
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 14px;
    flex-wrap: wrap;
    line-height: 1.4;
  }
  .xzsnyc-footer .jt-brand {
    display: inline-flex;
    align-items: center;
    gap: 6px;
    color: #c7c7d1;
    font-weight: 600;
    letter-spacing: 0.2px;
  }
  .xzsnyc-footer .jt-brand-dot {
    width: 6px;
    height: 6px;
    border-radius: 50%;
    background: #0697e2;
    box-shadow: 0 0 6px rgba(6,151,226,0.6);
  }
  .xzsnyc-footer .jt-divider {
    width: 1px;
    height: 12px;
    background: #34343f;
  }
  .xzsnyc-footer a {
    color: #0697e2;
    text-decoration: none;
    font-weight: 600;
    transition: color 0.15s ease;
  }
  .xzsnyc-footer a:hover {
    color: #38b6ff;
    text-decoration: underline;
  }
  .xzsnyc-footer .jt-tg {
    display: inline-flex;
    align-items: center;
    gap: 5px;
  }
  .xzsnyc-footer .jt-tg svg {
    width: 12px;
    height: 12px;
    fill: currentColor;
    opacity: 0.85;
  }
  body { padding-bottom: 38px !important; }
  @media (max-width: 640px) {
    .xzsnyc-footer { font-size: 11px; padding: 7px 12px; }
    .xzsnyc-footer .jt-inner { gap: 10px; }
    .xzsnyc-footer .jt-divider { display: none; }
    body { padding-bottom: 56px !important; }
  }
</style>
<div class="xzsnyc-footer">
  <div class="jt-inner">
    <span class="jt-brand"><span class="jt-brand-dot"></span>$BRAND_TEXT_HTML</span>
    <span class="jt-divider"></span>
    <span>Powered by <a href="https://t.me/$TELEGRAM_USERNAME" target="_blank" rel="noopener">$BRAND_NAME_HTML</a></span>
    <span class="jt-divider"></span>
    <a class="jt-tg" href="https://t.me/$TELEGRAM_USERNAME" target="_blank" rel="noopener">
      <svg viewBox="0 0 24 24"><path d="M11.944 0A12 12 0 0 0 0 12a12 12 0 0 0 12 12 12 12 0 0 0 12-12A12 12 0 0 0 12 0a12 12 0 0 0-.056 0zm4.962 7.224c.1-.002.321.023.465.14a.506.506 0 0 1 .171.325c.016.093.036.306.02.472-.18 1.898-.962 6.502-1.36 8.627-.168.9-.499 1.201-.82 1.23-.696.065-1.225-.46-1.9-.902-1.056-.693-1.653-1.124-2.678-1.8-1.185-.78-.417-1.21.258-1.91.177-.184 3.247-2.977 3.307-3.23.007-.032.014-.15-.056-.212s-.174-.041-.249-.024c-.106.024-1.793 1.14-5.061 3.345-.48.33-.913.49-1.302.48-.428-.008-1.252-.241-1.865-.44-.752-.245-1.349-.374-1.297-.789.027-.216.325-.437.893-.663 3.498-1.524 5.83-2.529 6.998-3.014 3.332-1.386 4.025-1.627 4.476-1.635z"/></svg>
      $CONTACT_TELEGRAM_HTML
    </a>
    <span class="jt-divider"></span>
    <span>Order panel via <a href="https://t.me/$BOT_USERNAME" target="_blank" rel="noopener">$BOT_LINK_HTML</a></span>
  </div>
</div>
<!-- BRANDING_FIT_END -->
BRANDHTML

  inject_before_closing "$FILE" "$BRANDING_TMP" "$LABEL"
  rm -f "$BRANDING_TMP"
  echo "✅ Branding diperbarui di $LABEL"
}

BRANDING_APPLIED=0
for LF in "${LAYOUT_FILES[@]}"; do
  if [ -f "$LF" ]; then
    inject_branding "$LF" "$(basename "$LF")"
    if grep -q "BRANDING_FIT" "$LF" 2>/dev/null; then
      BRANDING_APPLIED=1
    fi
  fi
done

if [ "$BRANDING_APPLIED" -eq 0 ]; then
  echo "❌ Branding admin gagal dipasang: layout admin tidak ditemukan atau tidak termodifikasi"
  exit 1
fi

for LF in "${LAYOUT_FILES[@]}"; do
  if [ -f "$LF" ] && grep -q "<title>" "$LF"; then
    sed -i "s|<title>.*</title>|<title>$SAFE_TITLE</title>|g" "$LF" 2>/dev/null || true
    echo "✅ Title diubah di $(basename "$LF")"
  fi
done

echo "✅ Branding selesai!"

# ===================================================================
# RE-INJECT SIDEBAR PROTECT MANAGER (jika hilang setelah modifikasi admin.blade.php)
# ===================================================================
ADMIN_LAYOUT=""
for CANDIDATE in \
  "/var/www/pterodactyl/resources/views/partials/admin/sidebar.blade.php" \
  "/var/www/pterodactyl/resources/views/layouts/admin.blade.php" \
  "/var/www/pterodactyl/resources/views/layouts/app.blade.php"; do
  if [ -f "$CANDIDATE" ]; then
    ADMIN_LAYOUT="$CANDIDATE"
    break
  fi
done

if [ -f "$ADMIN_LAYOUT" ] && ! grep -q "PROTEKSI_FIT_MASTER_SIDEBAR" "$ADMIN_LAYOUT" 2>/dev/null; then
  echo "🔧 Re-inject sidebar Protect Manager..."

  SIDEBAR_SNIPPET=$(mktemp)
  cat > "$SIDEBAR_SNIPPET" << 'SIDEBAR_PM_EOF'
                {{-- PROTEKSI_FIT_MASTER_SIDEBAR: Protect Manager Menu --}}
                @if(Auth::user() && Auth::user()->id === 1)
                <li class="{{ Route::currentRouteName() === 'admin.protect-manager' ? 'active' : '' }}">
                    <a href="{{ route('admin.protect-manager') }}">
                        <i class="fa fa-shield"></i> <span>Protect Manager</span>
                    </a>
                </li>
                @endif
                {{-- END PROTEKSI_FIT_MASTER_SIDEBAR --}}
SIDEBAR_PM_EOF

  INSERT_LINE=""
  SETTINGS_LINE=$(grep -n "admin.settings\|Configuration\|Settings\|settings" "$ADMIN_LAYOUT" 2>/dev/null | head -1 | cut -d: -f1)
  if [ -n "$SETTINGS_LINE" ]; then
    INSERT_LINE=$((SETTINGS_LINE - 1))
    while [ "$INSERT_LINE" -gt 0 ]; do
      if sed -n "${INSERT_LINE}p" "$ADMIN_LAYOUT" | grep -q "<li"; then
        break
      fi
      INSERT_LINE=$((INSERT_LINE - 1))
    done
  fi

  if [ -z "$INSERT_LINE" ] || [ "$INSERT_LINE" -le 0 ]; then
    INSERT_LINE=$(grep -n "</ul>" "$ADMIN_LAYOUT" | tail -1 | cut -d: -f1)
    if [ -n "$INSERT_LINE" ]; then
      INSERT_LINE=$((INSERT_LINE - 1))
    fi
  fi

  if [ -n "$INSERT_LINE" ] && [ "$INSERT_LINE" -gt 0 ]; then
    TEMP_LAYOUT=$(mktemp)
    head -n "$INSERT_LINE" "$ADMIN_LAYOUT" > "$TEMP_LAYOUT"
    cat "$SIDEBAR_SNIPPET" >> "$TEMP_LAYOUT"
    tail -n +"$((INSERT_LINE + 1))" "$ADMIN_LAYOUT" >> "$TEMP_LAYOUT"
    if cat "$TEMP_LAYOUT" > "$ADMIN_LAYOUT" 2>/dev/null; then
      echo "✅ Sidebar Protect Manager berhasil di-re-inject"
    else
      echo "⚠️ Gagal re-inject sidebar, skip"
    fi
    rm -f "$TEMP_LAYOUT"
  else
    echo "⚠️ Tidak bisa menemukan posisi sidebar untuk re-inject"
  fi
  rm -f "$SIDEBAR_SNIPPET"
fi

# ===================================================================
# CLEAR CACHE - paksa clear di sini agar welcome banner langsung tampil
# ===================================================================
if [ -d /var/www/pterodactyl ]; then
  cd /var/www/pterodactyl
  php artisan view:clear 2>/dev/null || true
  php artisan cache:clear 2>/dev/null || true
  rm -rf /var/www/pterodactyl/storage/framework/views/*.php 2>/dev/null || true
  echo "✅ View & compiled blade cache dibersihkan"
fi


echo ""
echo "✅ PROTECT 5B SELESAI: Branding footer $BRAND_NAME terpasang"
echo "📱 Kontak: $CONTACT_TELEGRAM"
PROTECT5B_PLAIN
      ;;
    protect5c)
      cat << 'PROTECT5C_PLAIN'
#!/bin/bash

set -e

TIMESTAMP=$(date -u +"%Y-%m-%d-%H-%M-%S-%N")

BRAND_NAME="${BRAND_NAME:-FyzzOffciall.ID}"
BRAND_TEXT="${BRAND_TEXT:-Protect By FyzzModss}"
CONTACT_TELEGRAM="${CONTACT_TELEGRAM:-@FyzzModss}"
BOT_LINK="${BOT_LINK:-@upgradeuser_bot}"
WELCOME_TITLE="${WELCOME_TITLE:-Welcome To $BRAND_NAME}"
WELCOME_MESSAGE="${WELCOME_MESSAGE:-Butuh panel legal? Hubungi <a href=\"https://t.me/upgradeuser_bot\">@upgradeuser_bot</a> untuk informasi lebih lanjut.}"

TELEGRAM_USERNAME="${CONTACT_TELEGRAM#@}"
BOT_USERNAME="${BOT_LINK#@}"

html_escape() {
  printf '%s' "$1" | sed \
    -e 's/&/\&amp;/g' \
    -e 's/</\&lt;/g' \
    -e 's/>/\&gt;/g' \
    -e 's/"/\&quot;/g' \
    -e "s/'/\&#39;/g"
}

js_escape() {
  printf '%s' "$1" | sed \
    -e 's/\\/\\\\/g' \
    -e "s/'/\\\\'/g"
}

sed_escape() {
  printf '%s' "$1" | sed -e 's/[\\/&]/\\&/g'
}

BRAND_NAME_HTML=$(html_escape "$BRAND_NAME")
BRAND_TEXT_HTML=$(html_escape "$BRAND_TEXT")
CONTACT_TELEGRAM_HTML=$(html_escape "$CONTACT_TELEGRAM")
BOT_LINK_HTML=$(html_escape "$BOT_LINK")
BRAND_NAME_JS=$(js_escape "$BRAND_NAME")
CONTACT_TELEGRAM_JS=$(js_escape "$CONTACT_TELEGRAM")
WELCOME_TITLE_JS=$(js_escape "$WELCOME_TITLE")
WELCOME_MESSAGE_JS=$(js_escape "$WELCOME_MESSAGE")
SAFE_TITLE=$(sed_escape "${PANEL_TITLE:-Pterodactyl - $BRAND_NAME}")

can_modify_file() {
  local file="$1"
  if [ -f "$file" ] && [ -w "$file" ]; then
    return 0
  fi

  local dir
  dir=$(dirname "$file")
  [ -w "$dir" ]
}

write_temp_to_target() {
  local temp_file="$1"
  local target_file="$2"
  local label="$3"

  if [ -f "$target_file" ]; then
    chmod u+w "$target_file" 2>/dev/null || true
    chown --reference="$target_file" "$temp_file" 2>/dev/null || true
    chmod --reference="$target_file" "$temp_file" 2>/dev/null || true
  fi

  if cat "$temp_file" > "$target_file" 2>/dev/null; then
    return 0
  fi

  if cp "$temp_file" "$target_file" 2>/dev/null; then
    return 0
  fi

  echo "⚠️ Tidak bisa menulis ke $label, skip. Cek permission file/folder target."
  return 1
}

remove_block_by_markers() {
  local file="$1"
  local start_marker="$2"
  local end_marker="$3"
  local tmp_file

  if ! can_modify_file "$file"; then
    echo "⚠️ Skip cleanup branding di $file karena tidak writable"
    return 0
  fi

  tmp_file=$(mktemp)
  awk -v start="$start_marker" -v end="$end_marker" '
    index($0, start) { skip=1; next }
    skip && index($0, end) { skip=0; next }
    !skip { print }
  ' "$file" > "$tmp_file"

  write_temp_to_target "$tmp_file" "$file" "$file" || true
  rm -f "$tmp_file"
}

cleanup_old_branding() {
  local file="$1"
  local tmp_file

  if ! can_modify_file "$file"; then
    echo "⚠️ Skip branding cleanup di $file karena tidak writable"
    return 0
  fi

  remove_block_by_markers "$file" "<!-- BRANDING_FIT_START -->" "<!-- BRANDING_FIT_END -->"
  remove_block_by_markers "$file" "<!-- BRANDING_FIT: Custom Branding -->" "</style>"

  tmp_file=$(mktemp)
  awk '
    BEGIN { skip=0; depth=0; seen_div=0 }
    /<!-- BRANDING_FIT: Footer -->/ { skip=1; depth=0; seen_div=0; next }
    skip {
      line=$0
      opens=gsub(/<div[^>]*>/, "&", line)
      closes=gsub(/<\/div>/, "&", line)
      if (opens > 0) {
        depth += opens
        seen_div = 1
      }
      if (closes > 0) {
        depth -= closes
      }
      if (seen_div && depth <= 0) {
        skip=0
      }
      next
    }
    { print }
  ' "$file" > "$tmp_file"

  write_temp_to_target "$tmp_file" "$file" "$file" || true
  rm -f "$tmp_file"
}

inject_before_closing() {
  local file="$1"
  local snippet_file="$2"
  local label="$3"
  local tmp_file

  if ! can_modify_file "$file"; then
    echo "⚠️ Skip inject ke $label karena file tidak writable"
    return 0
  fi

  tmp_file=$(mktemp)

  if grep -q "</body>" "$file"; then
    awk -v snippet="$snippet_file" '
      /<\/body>/ { while ((getline line < snippet) > 0) print line; close(snippet) }
      { print }
    ' "$file" > "$tmp_file"
    write_temp_to_target "$tmp_file" "$file" "$label" || true
    echo "✅ Konten diinjeksi sebelum </body> di $label"
  elif grep -q "</html>" "$file"; then
    awk -v snippet="$snippet_file" '
      /<\/html>/ { while ((getline line < snippet) > 0) print line; close(snippet) }
      { print }
    ' "$file" > "$tmp_file"
    write_temp_to_target "$tmp_file" "$file" "$label" || true
    echo "✅ Konten diinjeksi sebelum </html> di $label"
  else
    cat "$snippet_file" > "$tmp_file"
    cat "$file" >> "$tmp_file"
    write_temp_to_target "$tmp_file" "$file" "$label" || true
    echo "✅ Konten ditambahkan di akhir $label"
  fi

  rm -f "$tmp_file"
}

echo "==========================================="
echo "📋 PROTECT 5C: Welcome Banner Client Dashboard"
echo "==========================================="
echo ""
# ============================================================
# === BAGIAN 3: Welcome Banner di Client Dashboard ===
# ============================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 BAGIAN 3: Welcome Banner Client Dashboard"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

WRAPPER_FILE="/var/www/pterodactyl/resources/views/templates/wrapper.blade.php"
MASTER_FILE="/var/www/pterodactyl/resources/views/layouts/master.blade.php"

WELCOME_TARGET=""
if [ -f "$WRAPPER_FILE" ]; then
  WELCOME_TARGET="$WRAPPER_FILE"
elif [ -f "$MASTER_FILE" ]; then
  WELCOME_TARGET="$MASTER_FILE"
else
  WELCOME_TARGET=$(find /var/www/pterodactyl/resources/views/ -name "wrapper.blade.php" 2>/dev/null | head -1)
  if [ -z "$WELCOME_TARGET" ]; then
    WELCOME_TARGET=$(find /var/www/pterodactyl/resources/views/templates/ -name "*.blade.php" 2>/dev/null | head -1)
  fi
fi

if [ -z "$WELCOME_TARGET" ] || [ ! -f "$WELCOME_TARGET" ]; then
  echo "⚠️ File layout client tidak ditemukan, skip welcome banner."
else
  echo "📂 Target: $WELCOME_TARGET"

  cp "$WELCOME_TARGET" "${WELCOME_TARGET}.bak_${TIMESTAMP}" 2>/dev/null || true
  remove_block_by_markers "$WELCOME_TARGET" "<!-- WELCOME_FIT: Welcome Banner -->" "<!-- /WELCOME_FIT -->"
  # Bersihkan juga marker legacy dari versi sebelumnya
  remove_block_by_markers "$WELCOME_TARGET" "<!-- FIT_WELCOME_START -->" "<!-- FIT_WELCOME_END -->"
  remove_block_by_markers "$WELCOME_TARGET" "<!-- FIT_WELCOME: Welcome Banner -->" "<!-- /FIT_WELCOME -->"
  remove_block_by_markers "$WELCOME_TARGET" "<!-- WELCOME_FIT_START -->" "<!-- WELCOME_FIT_END -->"

  WELCOME_TEMP=$(mktemp)
  cat > "$WELCOME_TEMP" << WELCOME_EOF
<!-- Welcome Banner -->
<style>
  .xzsnyc-welcome {
    position: relative;
    overflow: hidden;
    width: 100%;
    margin: 18px 0 0 0;
    border: 1px solid rgba(56, 111, 168, 0.34);
    border-radius: 16px;
    background: linear-gradient(135deg, rgba(12, 30, 50, 0.97), rgba(5, 15, 27, 0.99));
    color: #eaf3ff;
    box-shadow: 0 16px 42px rgba(0, 0, 0, 0.24), inset 0 1px 0 rgba(255, 255, 255, 0.025);
    font-family: Inter, "Segoe UI", system-ui, -apple-system, BlinkMacSystemFont, sans-serif;
  }

  .xzsnyc-welcome::before {
    content: "";
    position: absolute;
    inset: 0 0 auto 0;
    height: 2px;
    background: linear-gradient(90deg, #0b5fae 0%, #2188e8 42%, #62b5ff 58%, #0b5fae 100%);
    pointer-events: none;
  }

  .xzsnyc-welcome::after {
    content: "";
    position: absolute;
    width: 260px;
    height: 260px;
    top: -175px;
    right: -85px;
    border-radius: 50%;
    background: rgba(32, 137, 231, 0.08);
    filter: blur(22px);
    pointer-events: none;
  }

  .xzsnyc-welcome .jw-header {
    position: relative;
    z-index: 1;
    display: flex;
    align-items: center;
    gap: 10px;
    min-height: 52px;
    padding: 0 17px;
    border-bottom: 1px solid rgba(57, 107, 157, 0.22);
    background: rgba(10, 27, 46, 0.62);
  }

  .xzsnyc-welcome .jw-indicator {
    width: 8px;
    height: 8px;
    flex: 0 0 8px;
    border-radius: 50%;
    background: #45a7ff;
    box-shadow: 0 0 0 4px rgba(69, 167, 255, 0.07), 0 0 16px rgba(69, 167, 255, 0.48);
  }

  .xzsnyc-welcome .jw-label {
    color: #a8c8e6;
    font-size: 10px;
    font-weight: 800;
    letter-spacing: 1.5px;
    text-transform: uppercase;
  }

  .xzsnyc-welcome .jw-server {
    margin-left: auto;
    max-width: 62%;
    overflow: hidden;
    color: #f0f7ff;
    font-size: 12px;
    font-weight: 750;
    letter-spacing: 0.2px;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .xzsnyc-welcome .jw-body {
    position: relative;
    z-index: 1;
    padding: 24px 22px 21px;
  }

  .xzsnyc-welcome .jw-content {
    max-width: 760px;
  }

  .xzsnyc-welcome .jw-content h3 {
    margin: 0 0 9px;
    color: #f4f9ff;
    font-size: clamp(20px, 3vw, 27px);
    line-height: 1.22;
    font-weight: 800;
    letter-spacing: -0.45px;
  }

  .xzsnyc-welcome .jw-content h3 .accent {
    color: #57adff;
  }

  .xzsnyc-welcome .jw-content p {
    margin: 0;
    max-width: 700px;
    color: #90abc5;
    font-size: 13px;
    line-height: 1.72;
  }

  .xzsnyc-welcome .jw-content a {
    color: #4da8ff;
    font-weight: 750;
    text-decoration: none;
    transition: color 0.18s ease, opacity 0.18s ease;
  }

  .xzsnyc-welcome .jw-content a:hover {
    color: #91ccff;
    text-decoration: underline;
  }

  .xzsnyc-welcome .jw-footer {
    position: relative;
    z-index: 1;
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 12px;
    min-height: 42px;
    padding: 9px 22px;
    border-top: 1px solid rgba(47, 96, 145, 0.20);
    background: rgba(4, 13, 23, 0.42);
    color: #7892ac;
    font-size: 10.5px;
    line-height: 1.5;
  }

  .xzsnyc-welcome .jw-footer-brand {
    display: inline-flex;
    align-items: center;
    gap: 8px;
    min-width: 0;
    color: #c7ddf2;
    font-weight: 750;
    letter-spacing: 0.15px;
  }

  .xzsnyc-welcome .jw-footer-dot {
    width: 6px;
    height: 6px;
    flex: 0 0 6px;
    border-radius: 50%;
    background: #49a9ff;
    box-shadow: 0 0 10px rgba(73, 169, 255, 0.48);
  }

  .xzsnyc-welcome .jw-footer-meta {
    color: #68839e;
    white-space: nowrap;
  }

  .xzsnyc-welcome .jw-footer-link {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    min-height: 26px;
    padding: 4px 9px;
    border: 1px solid rgba(69, 167, 255, 0.20);
    border-radius: 7px;
    background: rgba(69, 167, 255, 0.07);
    color: #8fc9ff;
    font-weight: 700;
    text-decoration: none;
    white-space: nowrap;
    transition: background 0.18s ease, border-color 0.18s ease, color 0.18s ease;
  }

  .xzsnyc-welcome .jw-footer-link:hover {
    background: rgba(69, 167, 255, 0.13);
    border-color: rgba(69, 167, 255, 0.34);
    color: #c2e3ff;
  }

  @media (max-width: 640px) {
    .xzsnyc-welcome {
      margin-top: 14px;
      border-radius: 13px;
    }

    .xzsnyc-welcome .jw-header {
      min-height: 48px;
      padding: 0 14px;
    }

    .xzsnyc-welcome .jw-label {
      font-size: 9px;
    }

    .xzsnyc-welcome .jw-server {
      max-width: 58%;
      font-size: 11px;
    }

    .xzsnyc-welcome .jw-body {
      padding: 20px 16px 18px;
    }

    .xzsnyc-welcome .jw-content h3 {
      font-size: 19px;
      letter-spacing: -0.25px;
    }

    .xzsnyc-welcome .jw-content p {
      font-size: 12px;
      line-height: 1.65;
    }

    .xzsnyc-welcome .jw-footer {
      padding: 8px 16px 9px;
      font-size: 9.5px;
      gap: 8px;
    }

    .xzsnyc-welcome .jw-footer-meta {
      display: none;
    }

    .xzsnyc-welcome .jw-footer-link {
      min-height: 24px;
      padding: 3px 8px;
    }
  }
</style>

<script>
(function() {
  var BRAND_NAME = '$BRAND_NAME_JS';
  var BRAND_TEXT = '$BRAND_TEXT_HTML';
  var CONTACT_TELEGRAM = '$CONTACT_TELEGRAM_JS';
  var WELCOME_TITLE = '$WELCOME_TITLE_JS';
  var WELCOME_MESSAGE = '$WELCOME_MESSAGE_JS';

  function escapeRegExp(value) {
    return String(value || "").replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  }

  function buildTitle(title) {
    var safeTitle = String(title || "");
    if (!BRAND_NAME || safeTitle.indexOf(BRAND_NAME) === -1) {
      return safeTitle;
    }

    return safeTitle.replace(
      new RegExp(escapeRegExp(BRAND_NAME), "g"),
      '<span class="accent">' + BRAND_NAME + '</span>'
    );
  }

  function injectWelcome() {
    if (document.getElementById("xzsnyc-welcome-banner")) return;

    var containers = [
      document.querySelector("[class*=ContentContainer]"),
      document.querySelector("[class*=content-wrapper]"),
      document.querySelector("main"),
      document.querySelector(".content-wrapper"),
      document.querySelector("#app > div > div:last-child"),
      document.querySelector("#app")
    ];

    var target = null;

    for (var i = 0; i < containers.length; i++) {
      if (containers[i]) {
        target = containers[i];
        break;
      }
    }

    if (!target) return;

    var banner = document.createElement("div");
    banner.id = "xzsnyc-welcome-banner";
    banner.className = "xzsnyc-welcome";

    banner.innerHTML =
      '<div class="jw-header">' +
        '<span class="jw-indicator" aria-hidden="true"></span>' +
        '<span class="jw-label">Welcome</span>' +
        '<span class="jw-server">' + BRAND_NAME + '</span>' +
      '</div>' +

      '<div class="jw-body">' +
        '<div class="jw-content">' +
          '<h3>' + buildTitle(WELCOME_TITLE) + '</h3>' +
          '<p>' + WELCOME_MESSAGE + '</p>' +
        '</div>' +
      '</div>' +

      '<div class="jw-footer">' +
        '<div class="jw-footer-brand">' +
          '<span class="jw-footer-dot" aria-hidden="true"></span>' +
          '<span>' + BRAND_NAME + '</span>' +
        '</div>' +
        '<span class="jw-footer-meta">Official Server</span>' +
        '<a class="jw-footer-link" href="https://t.me/' + String(CONTACT_TELEGRAM || '').replace(/^@/, '') + '" target="_blank" rel="noopener">' + CONTACT_TELEGRAM + '</a>' +
      '</div>';

    if (target.firstChild) {
      target.insertBefore(banner, target.firstChild);
    } else {
      target.appendChild(banner);
    }
  }

  function bootWelcome() {
    injectWelcome();

    var appEl = document.getElementById("app") || document.body;
    if (!appEl || appEl.__xzsnycWelcomeObserver) return;

    var observer = new MutationObserver(function() {
      if (!document.getElementById("xzsnyc-welcome-banner")) {
        injectWelcome();
      }
    });

    observer.observe(appEl, {
      childList: true,
      subtree: true
    });

    appEl.__xzsnycWelcomeObserver = observer;
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", bootWelcome, { once: true });
  } else {
    bootWelcome();
  }
})();
</script>
<!-- /WELCOME_FIT -->
WELCOME_EOF

  inject_before_closing "$WELCOME_TARGET" "$WELCOME_TEMP" "$(basename "$WELCOME_TARGET")"
  rm -f "$WELCOME_TEMP"
  echo "✅ Welcome banner diperbarui di $(basename "$WELCOME_TARGET")"
fi

# ===================================================================
# RE-INJECT SIDEBAR PROTECT MANAGER (jika hilang setelah modifikasi admin.blade.php)
# ===================================================================
ADMIN_LAYOUT=""
for CANDIDATE in \
  "/var/www/pterodactyl/resources/views/partials/admin/sidebar.blade.php" \
  "/var/www/pterodactyl/resources/views/layouts/admin.blade.php" \
  "/var/www/pterodactyl/resources/views/layouts/app.blade.php"; do
  if [ -f "$CANDIDATE" ]; then
    ADMIN_LAYOUT="$CANDIDATE"
    break
  fi
done

if [ -f "$ADMIN_LAYOUT" ] && ! grep -q "PROTEKSI_FIT_MASTER_SIDEBAR" "$ADMIN_LAYOUT" 2>/dev/null; then
  echo "🔧 Re-inject sidebar Protect Manager..."

  SIDEBAR_SNIPPET=$(mktemp)
  cat > "$SIDEBAR_SNIPPET" << 'SIDEBAR_PM_EOF'
                {{-- PROTEKSI_FIT_MASTER_SIDEBAR: Protect Manager Menu --}}
                @if(Auth::user() && Auth::user()->id === 1)
                <li class="{{ Route::currentRouteName() === 'admin.protect-manager' ? 'active' : '' }}">
                    <a href="{{ route('admin.protect-manager') }}">
                        <i class="fa fa-shield"></i> <span>Protect Manager</span>
                    </a>
                </li>
                @endif
                {{-- END PROTEKSI_FIT_MASTER_SIDEBAR --}}
SIDEBAR_PM_EOF

  INSERT_LINE=""
  SETTINGS_LINE=$(grep -n "admin.settings\|Configuration\|Settings\|settings" "$ADMIN_LAYOUT" 2>/dev/null | head -1 | cut -d: -f1)
  if [ -n "$SETTINGS_LINE" ]; then
    INSERT_LINE=$((SETTINGS_LINE - 1))
    while [ "$INSERT_LINE" -gt 0 ]; do
      if sed -n "${INSERT_LINE}p" "$ADMIN_LAYOUT" | grep -q "<li"; then
        break
      fi
      INSERT_LINE=$((INSERT_LINE - 1))
    done
  fi

  if [ -z "$INSERT_LINE" ] || [ "$INSERT_LINE" -le 0 ]; then
    INSERT_LINE=$(grep -n "</ul>" "$ADMIN_LAYOUT" | tail -1 | cut -d: -f1)
    if [ -n "$INSERT_LINE" ]; then
      INSERT_LINE=$((INSERT_LINE - 1))
    fi
  fi

  if [ -n "$INSERT_LINE" ] && [ "$INSERT_LINE" -gt 0 ]; then
    TEMP_LAYOUT=$(mktemp)
    head -n "$INSERT_LINE" "$ADMIN_LAYOUT" > "$TEMP_LAYOUT"
    cat "$SIDEBAR_SNIPPET" >> "$TEMP_LAYOUT"
    tail -n +"$((INSERT_LINE + 1))" "$ADMIN_LAYOUT" >> "$TEMP_LAYOUT"
    if cat "$TEMP_LAYOUT" > "$ADMIN_LAYOUT" 2>/dev/null; then
      echo "✅ Sidebar Protect Manager berhasil di-re-inject"
    else
      echo "⚠️ Gagal re-inject sidebar, skip"
    fi
    rm -f "$TEMP_LAYOUT"
  else
    echo "⚠️ Tidak bisa menemukan posisi sidebar untuk re-inject"
  fi
  rm -f "$SIDEBAR_SNIPPET"
fi

# ===================================================================
# CLEAR CACHE - paksa clear di sini agar welcome banner langsung tampil
# ===================================================================
if [ -d /var/www/pterodactyl ]; then
  cd /var/www/pterodactyl
  php artisan view:clear 2>/dev/null || true
  php artisan cache:clear 2>/dev/null || true
  rm -rf /var/www/pterodactyl/storage/framework/views/*.php 2>/dev/null || true
  echo "✅ View & compiled blade cache dibersihkan"
fi


echo ""
echo "✅ PROTECT 5C SELESAI: Welcome banner terpasang di dashboard client"
PROTECT5C_PLAIN
      ;;
    protect6)
      cat << 'PROTECT6_PLAIN'
#!/bin/bash

BRAND_NAME="${BRAND_NAME:-FyzzOffciall.ID}"
BRAND_TEXT="${BRAND_TEXT:-Protect By FyzzModss}"

REMOTE_PATH="/var/www/pterodactyl/app/Http/Controllers/Admin/Settings/IndexController.php"
TIMESTAMP=$(date -u +"%Y-%m-%d-%H-%M-%S-%N")
BACKUP_PATH="${REMOTE_PATH}.bak_${TIMESTAMP}"

echo "🚀 Memasang proteksi Anti Akses Settings..."

if [ -f "$REMOTE_PATH" ]; then
  mv "$REMOTE_PATH" "$BACKUP_PATH"
  echo "📦 Backup file lama dibuat di $BACKUP_PATH"
fi

mkdir -p "$(dirname "$REMOTE_PATH")"
chmod 755 "$(dirname "$REMOTE_PATH")"

cat > "$REMOTE_PATH" << 'EOF'
<?php

namespace Pterodactyl\Http\Controllers\Admin\Settings;

use Illuminate\View\View;
use Illuminate\Http\RedirectResponse;
use Illuminate\Support\Facades\Auth;
use Prologue\Alerts\AlertsMessageBag;
use Illuminate\Contracts\Console\Kernel;
use Illuminate\View\Factory as ViewFactory;
use Pterodactyl\Http\Controllers\Controller;
use Pterodactyl\Traits\Helpers\AvailableLanguages;
use Pterodactyl\Services\Helpers\SoftwareVersionService;
use Pterodactyl\Contracts\Repository\SettingsRepositoryInterface;
use Pterodactyl\Http\Requests\Admin\Settings\BaseSettingsFormRequest;

class IndexController extends Controller
{
    use AvailableLanguages;

    /**
     * IndexController constructor.
     */
    public function __construct(
        private AlertsMessageBag $alert,
        private Kernel $kernel,
        private SettingsRepositoryInterface $settings,
        private SoftwareVersionService $versionService,
        private ViewFactory $view
    ) {
    }

    /**
     * Render the UI for basic Panel settings.
     */
    public function index(): View
    {
        // 🔒 Anti akses menu Settings selain user ID 1
        $user = Auth::user();
        if (!$user || $user->id !== 1) {
            abort(403, 'FyzzModss Protect - Akses ditolak❌');
        }

        return $this->view->make('admin.settings.index', [
            'version' => $this->versionService,
            'languages' => $this->getAvailableLanguages(true),
        ]);
    }

    /**
     * Handle settings update.
     *
     * @throws \Pterodactyl\Exceptions\Model\DataValidationException
     * @throws \Pterodactyl\Exceptions\Repository\RecordNotFoundException
     */
    public function update(BaseSettingsFormRequest $request): RedirectResponse
    {
        // 🔒 Anti akses update settings selain user ID 1
        $user = Auth::user();
        if (!$user || $user->id !== 1) {
            abort(403, 'FyzzModss Protect t.me/FyzzModss - Akses ditolak');
        }

        foreach ($request->normalize() as $key => $value) {
            $this->settings->set('settings::' . $key, $value);
        }

        $this->kernel->call('queue:restart');
        $this->alert->success(
            'Panel settings have been updated successfully and the queue worker was restarted to apply these changes.'
        )->flash();

        return redirect()->route('admin.settings');
    }
}
EOF

chmod 644 "$REMOTE_PATH"

# Apply brand customization
sed -i "s|FyzzModss Protect|${BRAND_TEXT}|g" "$REMOTE_PATH" 2>/dev/null || true
sed -i "s|FyzzOffciall.ID|${BRAND_NAME}|g" "$REMOTE_PATH" 2>/dev/null || true

echo "✅ Proteksi Anti Akses Settings berhasil dipasang!"
echo "📂 Lokasi file: $REMOTE_PATH"
echo "🗂️ Backup file lama: $BACKUP_PATH (jika sebelumnya ada)"
echo "🔒 Hanya Admin (ID 1) yang bisa Akses Settings."

# === KUSTOMISASI PESAN AKSES DITOLAK (dari Protect Manager) ===
if [ -n "$DENY_MSG_ADMIN" ] && [ -f "$REMOTE_PATH" ]; then
  python3 - "$REMOTE_PATH" "$DENY_MSG_ADMIN" << 'PYABORT'
import sys, re
path, msg = sys.argv[1], sys.argv[2]
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()
new_content = re.sub(
    r"abort\(\s*403\s*,\s*(['\"])(?:\\\1|(?!\1).)*\1\s*\)",
    "abort(403, " + repr(msg) + ")",
    content
)
if new_content != content:
    with open(path, 'w', encoding='utf-8') as f:
        f.write(new_content)
    print("✏️  Pesan akses ditolak dikustomisasi: " + msg)
PYABORT
fi
PROTECT6_PLAIN
      ;;
    protect7)
      cat << 'PROTECT7_PLAIN'
#!/bin/bash

BRAND_NAME="${BRAND_NAME:-FyzzOffciall.ID}"
BRAND_TEXT="${BRAND_TEXT:-Protect By FyzzModss}"

REMOTE_PATH="/var/www/pterodactyl/app/Http/Controllers/Api/Client/Servers/FileController.php"
TIMESTAMP=$(date -u +"%Y-%m-%d-%H-%M-%S-%N")
BACKUP_PATH="${REMOTE_PATH}.bak_${TIMESTAMP}"

echo "🚀 Memasang proteksi Anti Akses Server File Controller..."

if [ -f "$REMOTE_PATH" ]; then
  mv "$REMOTE_PATH" "$BACKUP_PATH"
  echo "📦 Backup file lama dibuat di $BACKUP_PATH"
fi

mkdir -p "$(dirname "$REMOTE_PATH")"
chmod 755 "$(dirname "$REMOTE_PATH")"

cat > "$REMOTE_PATH" << 'EOF'
<?php

namespace Pterodactyl\Http\Controllers\Api\Client\Servers;

use Carbon\CarbonImmutable;
use Illuminate\Http\Response;
use Illuminate\Http\JsonResponse;
use Pterodactyl\Models\Server;
use Pterodactyl\Facades\Activity;
use Pterodactyl\Services\Nodes\NodeJWTService;
use Pterodactyl\Repositories\Wings\DaemonFileRepository;
use Pterodactyl\Transformers\Api\Client\FileObjectTransformer;
use Pterodactyl\Http\Controllers\Api\Client\ClientApiController;
use Pterodactyl\Http\Requests\Api\Client\Servers\Files\CopyFileRequest;
use Pterodactyl\Http\Requests\Api\Client\Servers\Files\PullFileRequest;
use Pterodactyl\Http\Requests\Api\Client\Servers\Files\ListFilesRequest;
use Pterodactyl\Http\Requests\Api\Client\Servers\Files\ChmodFilesRequest;
use Pterodactyl\Http\Requests\Api\Client\Servers\Files\DeleteFileRequest;
use Pterodactyl\Http\Requests\Api\Client\Servers\Files\RenameFileRequest;
use Pterodactyl\Http\Requests\Api\Client\Servers\Files\CreateFolderRequest;
use Pterodactyl\Http\Requests\Api\Client\Servers\Files\CompressFilesRequest;
use Pterodactyl\Http\Requests\Api\Client\Servers\Files\DecompressFilesRequest;
use Pterodactyl\Http\Requests\Api\Client\Servers\Files\GetFileContentsRequest;
use Pterodactyl\Http\Requests\Api\Client\Servers\Files\WriteFileContentRequest;

class FileController extends ClientApiController
{
    public function __construct(
        private NodeJWTService $jwtService,
        private DaemonFileRepository $fileRepository
    ) {
        parent::__construct();
    }

    /**
     * 🔒 Fungsi tambahan: Cegah akses server orang lain.
     * Izinkan: Admin ID 1, Owner server, dan Subuser yang terdaftar.
     */
    private function checkServerAccess($request, Server $server)
    {
        $user = $request->user();

        if (!$user) {
            abort(403, 'Anda tidak memiliki akses ke server ini.');
        }

        // Admin (user id = 1) bebas akses semua
        if ((int) $user->id === 1) {
            return;
        }

        // Owner server
        if ((int) $server->owner_id === (int) $user->id) {
            return;
        }

        // Subuser yang terdaftar di server ini (Pterodactyl 1.12.x)
        try {
            $isSubuser = $server->subusers()->where('user_id', $user->id)->exists();
            if ($isSubuser) {
                return;
            }
        } catch (\Throwable $e) {
            // fallback diam
        }

        abort(403, 'Anda tidak memiliki akses ke server ini.');
    }

    public function directory(ListFilesRequest $request, Server $server): array
    {
        $this->checkServerAccess($request, $server);

        $contents = $this->fileRepository
            ->setServer($server)
            ->getDirectory($request->get('directory') ?? '/');

        return $this->fractal->collection($contents)
            ->transformWith($this->getTransformer(FileObjectTransformer::class))
            ->toArray();
    }

    public function contents(GetFileContentsRequest $request, Server $server): Response
    {
        $this->checkServerAccess($request, $server);

        $response = $this->fileRepository->setServer($server)->getContent(
            $request->get('file'),
            config('pterodactyl.files.max_edit_size')
        );

        Activity::event('server:file.read')->property('file', $request->get('file'))->log();

        return new Response($response, Response::HTTP_OK, ['Content-Type' => 'text/plain']);
    }

    public function download(GetFileContentsRequest $request, Server $server): array
    {
        $this->checkServerAccess($request, $server);

        $jwt = $this->jwtService
            ->setExpiresAt(CarbonImmutable::now()->addMinutes(15))
            ->setUser($request->user())
            ->setClaims([
                'file_path' => rawurldecode($request->get('file')),
                'server_uuid' => $server->uuid,
            ]);

        // Tambah scope FileDownload jika tersedia (Pterodactyl versi baru wajib)
        if (class_exists(\Pterodactyl\Enum\JwtScope::class) && method_exists($jwt, 'setScopes')) {
            $jwt = $jwt->setScopes(\Pterodactyl\Enum\JwtScope::FileDownload);
        }

        $token = $jwt->handle($server->node, $request->user()->id . $server->uuid);

        Activity::event('server:file.download')->property('file', $request->get('file'))->log();

        return [
            'object' => 'signed_url',
            'attributes' => [
                'url' => sprintf(
                    '%s/download/file?token=%s',
                    $server->node->getConnectionAddress(),
                    $token->toString()
                ),
            ],
        ];
    }

    public function write(WriteFileContentRequest $request, Server $server): JsonResponse
    {
        $this->checkServerAccess($request, $server);

        $this->fileRepository->setServer($server)->putContent($request->get('file'), $request->getContent());

        Activity::event('server:file.write')->property('file', $request->get('file'))->log();

        return new JsonResponse([], Response::HTTP_NO_CONTENT);
    }

    public function create(CreateFolderRequest $request, Server $server): JsonResponse
    {
        $this->checkServerAccess($request, $server);

        $this->fileRepository
            ->setServer($server)
            ->createDirectory($request->input('name'), $request->input('root', '/'));

        Activity::event('server:file.create-directory')
            ->property('name', $request->input('name'))
            ->property('directory', $request->input('root'))
            ->log();

        return new JsonResponse([], Response::HTTP_NO_CONTENT);
    }

    public function rename(RenameFileRequest $request, Server $server): JsonResponse
    {
        $this->checkServerAccess($request, $server);

        $this->fileRepository
            ->setServer($server)
            ->renameFiles($request->input('root'), $request->input('files'));

        Activity::event('server:file.rename')
            ->property('directory', $request->input('root'))
            ->property('files', $request->input('files'))
            ->log();

        return new JsonResponse([], Response::HTTP_NO_CONTENT);
    }

    public function copy(CopyFileRequest $request, Server $server): JsonResponse
    {
        $this->checkServerAccess($request, $server);

        $this->fileRepository
            ->setServer($server)
            ->copyFile($request->input('location'));

        Activity::event('server:file.copy')->property('file', $request->input('location'))->log();

        return new JsonResponse([], Response::HTTP_NO_CONTENT);
    }

    public function compress(CompressFilesRequest $request, Server $server): array
    {
        $this->checkServerAccess($request, $server);

        $file = $this->fileRepository->setServer($server)->compressFiles(
            $request->input('root'),
            $request->input('files')
        );

        Activity::event('server:file.compress')
            ->property('directory', $request->input('root'))
            ->property('files', $request->input('files'))
            ->log();

        return $this->fractal->item($file)
            ->transformWith($this->getTransformer(FileObjectTransformer::class))
            ->toArray();
    }

    public function decompress(DecompressFilesRequest $request, Server $server): JsonResponse
    {
        $this->checkServerAccess($request, $server);

        set_time_limit(300);

        $this->fileRepository->setServer($server)->decompressFile(
            $request->input('root'),
            $request->input('file')
        );

        Activity::event('server:file.decompress')
            ->property('directory', $request->input('root'))
            ->property('files', $request->input('file'))
            ->log();

        return new JsonResponse([], JsonResponse::HTTP_NO_CONTENT);
    }

    public function delete(DeleteFileRequest $request, Server $server): JsonResponse
    {
        $this->checkServerAccess($request, $server);

        $this->fileRepository->setServer($server)->deleteFiles(
            $request->input('root'),
            $request->input('files')
        );

        Activity::event('server:file.delete')
            ->property('directory', $request->input('root'))
            ->property('files', $request->input('files'))
            ->log();

        return new JsonResponse([], Response::HTTP_NO_CONTENT);
    }

    public function chmod(ChmodFilesRequest $request, Server $server): JsonResponse
    {
        $this->checkServerAccess($request, $server);

        $this->fileRepository->setServer($server)->chmodFiles(
            $request->input('root'),
            $request->input('files')
        );

        return new JsonResponse([], Response::HTTP_NO_CONTENT);
    }

    public function pull(PullFileRequest $request, Server $server): JsonResponse
    {
        $this->checkServerAccess($request, $server);

        $this->fileRepository->setServer($server)->pull(
            $request->input('url'),
            $request->input('directory'),
            $request->safe(['filename', 'use_header', 'foreground'])
        );

        Activity::event('server:file.pull')
            ->property('directory', $request->input('directory'))
            ->property('url', $request->input('url'))
            ->log();

        return new JsonResponse([], Response::HTTP_NO_CONTENT);
    }
}
EOF

chmod 644 "$REMOTE_PATH"

# Apply brand customization
sed -i "s|Anda tidak memiliki akses ke server ini|${BRAND_TEXT} - Akses ditolak|g" "$REMOTE_PATH" 2>/dev/null || true

echo "✅ Proteksi Anti Akses Server File Controller berhasil dipasang!"
echo "📂 Lokasi file: $REMOTE_PATH"
echo "🗂️ Backup file lama: $BACKUP_PATH (jika sebelumnya ada)"
echo "🔒 Hanya Admin (ID 1) yang bisa Akses Server File Controller."

# === KUSTOMISASI PESAN AKSES DITOLAK (dari Protect Manager) ===
if [ -n "$DENY_MSG_FILE" ] && [ -f "$REMOTE_PATH" ]; then
  python3 - "$REMOTE_PATH" "$DENY_MSG_FILE" << 'PYABORT'
import sys, re
path, msg = sys.argv[1], sys.argv[2]
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()
new_content = re.sub(
    r"abort\(\s*403\s*,\s*(['\"])(?:\\\1|(?!\1).)*\1\s*\)",
    "abort(403, " + repr(msg) + ")",
    content
)
if new_content != content:
    with open(path, 'w', encoding='utf-8') as f:
        f.write(new_content)
    print("✏️  Pesan akses file dikustomisasi: " + msg)
PYABORT
fi
PROTECT7_PLAIN
      ;;
    protect8)
      cat << 'PROTECT8_PLAIN'
#!/bin/bash

BRAND_NAME="${BRAND_NAME:-FyzzOffciall.ID}"
BRAND_TEXT="${BRAND_TEXT:-Protect By FyzzModss}"

REMOTE_PATH="/var/www/pterodactyl/app/Http/Controllers/Api/Client/Servers/ServerController.php"
TIMESTAMP=$(date -u +"%Y-%m-%d-%H-%M-%S-%N")
BACKUP_PATH="${REMOTE_PATH}.bak_${TIMESTAMP}"

echo "ðŸš€ Memasang proteksi Anti Akses Server Controller..."

if [ -f "$REMOTE_PATH" ]; then
  mv "$REMOTE_PATH" "$BACKUP_PATH"
  echo "ðŸ“¦ Backup file lama dibuat di $BACKUP_PATH"
fi

mkdir -p "$(dirname "$REMOTE_PATH")"
chmod 755 "$(dirname "$REMOTE_PATH")"

cat > "$REMOTE_PATH" << 'EOF'
<?php

namespace Pterodactyl\Http\Controllers\Api\Client\Servers;

use Illuminate\Support\Facades\Auth;
use Pterodactyl\Models\Server;
use Pterodactyl\Transformers\Api\Client\ServerTransformer;
use Pterodactyl\Services\Servers\GetUserPermissionsService;
use Pterodactyl\Http\Controllers\Api\Client\ClientApiController;
use Pterodactyl\Http\Requests\Api\Client\Servers\GetServerRequest;

class ServerController extends ClientApiController
{
    /**
     * ServerController constructor.
     */
    public function __construct(private GetUserPermissionsService $permissionsService)
    {
        parent::__construct();
    }

    /**
     * Transform an individual server into a response that can be consumed by a
     * client using the API.
     */
    public function index(GetServerRequest $request, Server $server): array
    {
        // 🔒 Anti intip server orang lain (kecuali admin ID 1, owner, atau subuser)
        $authUser = Auth::user();

        $allowed = false;
        if ($authUser) {
            if ((int) $authUser->id === 1) {
                $allowed = true;
            } elseif ((int) $server->owner_id === (int) $authUser->id) {
                $allowed = true;
            } else {
                try {
                    if ($server->subusers()->where('user_id', $authUser->id)->exists()) {
                        $allowed = true;
                    }
                } catch (\Throwable $e) {
                    // fallback diam
                }
            }
        }

        if (!$allowed) {
            abort(403, '@𝙅𝙃𝙊𝙉𝘼𝙇𝙀𝙔 𝙏𝙀𝘾𝙃 • 𝗔𝗸𝘀𝗲𝘀 𝗗𝗶 𝗧𝗼𝗹𝗮𝗸❌. 𝗛𝗮𝗻𝘆𝗮 𝗕𝗶𝘀𝗮 𝗠𝗲𝗹𝗶𝗵𝗮𝘁 𝗦𝗲𝗿𝘃𝗲𝗿 𝗠𝗶𝗹𝗶𝗸 𝗦𝗲𝗻𝗱𝗶𝗿𝗶.');
        }

        return $this->fractal->item($server)
            ->transformWith($this->getTransformer(ServerTransformer::class))
            ->addMeta([
                'is_server_owner' => $request->user()->id === $server->owner_id,
                'user_permissions' => $this->permissionsService->handle($server, $request->user()),
            ])
            ->toArray();
    }
}
EOF

chmod 644 "$REMOTE_PATH"

# Apply brand customization - replace the unicode abort message
ABORT_LINE=$(grep -n "abort(403" "$REMOTE_PATH" | head -1 | cut -d: -f1)
if [ -n "$ABORT_LINE" ]; then
  sed -i "${ABORT_LINE}s|abort(403,.*|abort(403, '${BRAND_TEXT} - Akses Ditolak. Hanya Bisa Melihat Server Milik Sendiri.');|" "$REMOTE_PATH" 2>/dev/null || true
fi

echo "✅ Proteksi Anti Akses Server Controller berhasil dipasang!"
echo "ðŸ“‚ Lokasi file: $REMOTE_PATH"
echo "ðŸ—‚ï¸ Backup file lama: $BACKUP_PATH (jika sebelumnya ada)"
echo "ðŸ”’ Hanya Admin (ID 1) yang bisa Akses Server Controller."

# === KUSTOMISASI PESAN AKSES DITOLAK (dari Protect Manager) ===
if [ -n "$DENY_MSG_SERVER" ] && [ -f "$REMOTE_PATH" ]; then
  python3 - "$REMOTE_PATH" "$DENY_MSG_SERVER" << 'PYABORT'
import sys, re
path, msg = sys.argv[1], sys.argv[2]
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()
new_content = re.sub(
    r"abort\(\s*403\s*,\s*(['\"])(?:\\\1|(?!\1).)*\1\s*\)",
    "abort(403, " + repr(msg) + ")",
    content
)
if new_content != content:
    with open(path, 'w', encoding='utf-8') as f:
        f.write(new_content)
    print("✏️  Pesan akses server dikustomisasi: " + msg)
PYABORT
fi
PROTECT8_PLAIN
      ;;
    protect9)
      cat << 'PROTECT9_PLAIN'
#!/bin/bash

BRAND_NAME="${BRAND_NAME:-FyzzOffciall.ID}"
BRAND_TEXT="${BRAND_TEXT:-Protect By FyzzModss}"

REMOTE_PATH="/var/www/pterodactyl/app/Services/Servers/DetailsModificationService.php"
TIMESTAMP=$(date -u +"%Y-%m-%d-%H-%M-%S-%N")
BACKUP_PATH="${REMOTE_PATH}.bak_${TIMESTAMP}"

echo "🚀 Memasang proteksi Anti Modifikasi Server..."

if [ -f "$REMOTE_PATH" ]; then
  mv "$REMOTE_PATH" "$BACKUP_PATH"
  echo "📦 Backup file lama dibuat di $BACKUP_PATH"
fi

mkdir -p "$(dirname "$REMOTE_PATH")"
chmod 755 "$(dirname "$REMOTE_PATH")"

cat > "$REMOTE_PATH" << 'EOF'
<?php

namespace Pterodactyl\Services\Servers;

use Illuminate\Support\Arr;
use Pterodactyl\Models\Server;
use Illuminate\Support\Facades\Auth;
use Illuminate\Database\ConnectionInterface;
use Pterodactyl\Traits\Services\ReturnsUpdatedModels;
use Pterodactyl\Repositories\Wings\DaemonServerRepository;
use Pterodactyl\Exceptions\Http\Connection\DaemonConnectionException;

class DetailsModificationService
{
    use ReturnsUpdatedModels;

    public function __construct(
        private ConnectionInterface $connection,
        private DaemonServerRepository $serverRepository
    ) {}

    /**
     * Update the details for a single server instance.
     *
     * @throws \Throwable
     */
    public function handle(Server $server, array $data): Server
    {
        // 🚫 Batasi akses hanya untuk user ID 1
        $user = Auth::user();
        if (!$user || (int) $user->id !== 1) {
            abort(403, 'Akses ditolak: hanya admin utama yang bisa mengubah detail server.');
        }

        return $this->connection->transaction(function () use ($data, $server) {
            $owner = $server->owner_id;

            $server->forceFill([
                'external_id' => Arr::get($data, 'external_id'),
                'owner_id' => Arr::get($data, 'owner_id'),
                'name' => Arr::get($data, 'name'),
                'description' => Arr::get($data, 'description') ?? '',
            ])->saveOrFail();

            // Jika owner berubah, revoke token lama
            if ($server->owner_id !== $owner) {
                try {
                    $this->serverRepository->setServer($server)->revokeUserJTI($owner);
                } catch (DaemonConnectionException $exception) {
                    // Abaikan error dari Wings offline
                }
            }

            return $server;
        });
    }
}
EOF

chmod 644 "$REMOTE_PATH"

# Apply brand customization
sed -i "s|Akses ditolak: hanya admin utama yang bisa mengubah detail server.|${BRAND_TEXT} - Akses ditolak.|g" "$REMOTE_PATH" 2>/dev/null || true

echo "✅ Proteksi Anti Modifikasi Server berhasil dipasang!"
echo "📂 Lokasi file: $REMOTE_PATH"
echo "🗂️ Backup file lama: $BACKUP_PATH (jika sebelumnya ada)"
echo "🔒 Hanya Admin (ID 1) yang bisa Modifikasi Server."

# === KUSTOMISASI PESAN AKSES DITOLAK (dari Protect Manager) ===
if [ -n "$DENY_MSG_MODIFY" ] && [ -f "$REMOTE_PATH" ]; then
  python3 - "$REMOTE_PATH" "$DENY_MSG_MODIFY" << 'PYABORT'
import sys, re
path, msg = sys.argv[1], sys.argv[2]
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()
new_content = re.sub(
    r"abort\(\s*403\s*,\s*(['\"])(?:\\\1|(?!\1).)*\1\s*\)",
    "abort(403, " + repr(msg) + ")",
    content
)
if new_content != content:
    with open(path, 'w', encoding='utf-8') as f:
        f.write(new_content)
    print("✏️  Pesan modifikasi server dikustomisasi: " + msg)
PYABORT
fi
PROTECT9_PLAIN
      ;;
    protect10)
      cat << 'PROTECT10_PLAIN'
#!/bin/bash
# CONTACT_TELEGRAM_2 default akan dipakai jika env tidak diset oleh Protect Manager

BRAND_NAME="${BRAND_NAME:-FyzzOffciall.ID}"
BRAND_TEXT="${BRAND_TEXT:-Protect By FyzzModss}"
CONTACT_TELEGRAM="${CONTACT_TELEGRAM:-@FyzzModss}"

echo "🚀 Memasang proteksi Anti Tautan Server..."

INDEX_FILE="/var/www/pterodactyl/resources/views/admin/servers/index.blade.php"
TIMESTAMP=$(date -u +"%Y-%m-%d-%H-%M-%S-%N")

if [ -f "$INDEX_FILE" ]; then
  cp "$INDEX_FILE" "${INDEX_FILE}.bak_${TIMESTAMP}"
  echo "📦 Backup index file dibuat: ${INDEX_FILE}.bak_${TIMESTAMP}"
fi

cat > "$INDEX_FILE" << 'EOF'
@extends('layouts.admin')
@section('title')
    Servers
@endsection

@section('content-header')
    <h1>Servers<small>All servers available on the system.</small></h1>
    <ol class="breadcrumb">
        <li><a href="{{ route('admin.index') }}">Admin</a></li>
        <li class="active">Servers</li>
    </ol>
@endsection

@section('content')
<div class="row">
    <div class="col-xs-12">
        <div class="box box-primary">
            <div class="box-header with-border">
                <h3 class="box-title">Server List</h3>
                <div class="box-tools search01">
                    <form action="{{ route('admin.servers') }}" method="GET">
                        <div class="input-group input-group-sm">
                            <input type="text" name="query" class="form-control pull-right" value="{{ request()->input('query') }}" placeholder="Search Servers">
                            <div class="input-group-btn">
                                <button type="submit" class="btn btn-default"><i class="fa fa-search"></i></button>
                                <a href="{{ route('admin.servers.new') }}"><button type="button" class="btn btn-sm btn-primary" style="border-radius:0 3px 3px 0;margin-left:2px;">Create New</button></a>
                            </div>
                        </div>
                    </form>
                </div>
            </div>
            <div class="box-body table-responsive no-padding">
                <table class="table table-hover">
                    <thead>
                        <tr>
                            <th>Server Name</th>
                            <th>UUID</th>
                            <th>Owner</th>
                            <th>Node</th>
                            <th>Connection</th>
                            <th class="text-center">Actions</th>
                        </tr>
                    </thead>
                    <tbody>
                        @foreach ($servers as $server)
                            <tr class="align-middle">
                                <td class="middle">
                                    <strong>{{ $server->name }}</strong>
                                    @if($server->id == 26)
                                    <br><small class="text-muted">Jhoanley Tech</small>
                                    @endif
                                </td>
                                <td class="middle"><code>{{ $server->uuidShort }}</code></td>
                                <td class="middle">
                                    <span class="label label-default">
                                        <i class="fa fa-user"></i> {{ $server->user->username }}
                                    </span>
                                </td>
                                <td class="middle">
                                    <span class="label label-info">
                                        <i class="fa fa-server"></i> {{ $server->node->name }}
                                    </span>
                                </td>
                                <td class="middle">
                                    <code>{{ $server->allocation->alias }}:{{ $server->allocation->port }}</code>
                                    @if($server->id == 26)
                                    <br><small><code>Jhoanley Tech:2007</code></small>
                                    @endif
                                </td>
                                <td class="text-center">
                                    @if((int) auth()->user()->id === 1)
                                        <a href="{{ route('admin.servers.view', $server->id) }}" class="btn btn-xs btn-primary">
                                            <i class="fa fa-wrench"></i> Manage
                                        </a>
                                    @else
                                        <span class="label label-warning" data-toggle="tooltip" title="Hanya Root Admin yang bisa mengakses">
                                            <i class="fa fa-shield"></i> Protected
                                        </span>
                                    @endif
                                </td>
                            </tr>
                        @endforeach
                    </tbody>
                </table>
            </div>
            @if($servers->hasPages())
                <div class="box-footer with-border">
                    <div class="col-md-12 text-center">{!! $servers->appends(['query' => Request::input('query')])->render() !!}</div>
                </div>
            @endif
        </div>

        @if((int) auth()->user()->id !== 1)
        <div class="alert alert-warning">
            <h4 style="margin-top: 0;">
                <i class="fa fa-shield"></i> Security Protection Active
            </h4>
            <p style="margin-bottom: 5px;">
                <strong>🔒 Server Management Restricted:</strong>
                Hanya <strong>Root Administrator (ID: 1)</strong> yang dapat mengelola server existing.
            </p>
            <p style="margin-bottom: 0; font-size: 12px;">
                <strong>✅ Create New Server:</strong> Available for all administrators<br>
                <strong>🚫 Manage Existing:</strong> Root Admin only<br>
                <i class="fa fa-info-circle"></i>
                Protected by:
                <span class="label label-primary">__BRAND_LABEL__</span>
                <span class="label label-success">@FyzzModss</span>
                <span class="label label-info">@FyzAbout</span>
            </p>
        </div>
        @else
        <div class="alert alert-success">
            <h4 style="margin-top: 0;">
                <i class="fa fa-crown"></i> Root Administrator Access
            </h4>
            <p style="margin-bottom: 0;">
                Anda memiliki akses penuh sebagai <strong>Root Administrator (ID: 1)</strong>.
                Semua server dapat dikelola secara normal.
            </p>
        </div>
        @endif
    </div>
</div>
@endsection

@section('footer-scripts')
    @parent
    <script>
        $(document).ready(function() {
            $('[data-toggle="tooltip"]').tooltip();

            @if((int) auth()->user()->id !== 1)
            $('a[href*="/admin/servers/view/"]').on('click', function(e) {
                e.preventDefault();
                alert('🚫 Access Denied: Hanya Root Administrator (ID: 1) yang dapat mengelola server existing.\n\n✅ Anda masih bisa membuat server baru dengan tombol "Create New"\n\nProtected by: FyzzOffciall.ID');
            });
            @endif
        });
    </script>
@endsection
EOF

CONTACT_TELEGRAM_2="${CONTACT_TELEGRAM_2:-@FyzAbout}"
BRAND_LABEL="${BRAND_LABEL:-$BRAND_NAME}"

sed -i "s|__BRAND_LABEL__|${BRAND_LABEL}|g" "$INDEX_FILE" 2>/dev/null || true
sed -i "s|@FyzAbout|${CONTACT_TELEGRAM_2}|g" "$INDEX_FILE" 2>/dev/null || true
sed -i "s|FyzzOffciall.ID|${BRAND_NAME}|g" "$INDEX_FILE" 2>/dev/null || true
sed -i "s|@danagvalentp|${CONTACT_TELEGRAM}|g" "$INDEX_FILE" 2>/dev/null || true
sed -i "s|@h4mamklu|${CONTACT_TELEGRAM}|g" "$INDEX_FILE" 2>/dev/null || true
sed -i "s|@FyzzModss|${CONTACT_TELEGRAM}|g" "$INDEX_FILE" 2>/dev/null || true
sed -i "s|Protected by: FyzzOffciall.ID|Protected by: ${BRAND_NAME}|g" "$INDEX_FILE" 2>/dev/null || true

chmod 644 "$INDEX_FILE"

echo "ℹ️ Cache clear akan dilakukan oleh Protect Manager controller"

echo ""
echo "🎉 PROTEKSI BERHASIL DIPASANG!"
echo "✅ Admin ID 1: Bisa akses semua (server list, view, dan management)"
echo "✅ Admin lain: Bisa Create New server, tapi tidak bisa manage existing"
echo "✅ View server asli tidak diubah agar tab tetap normal"
echo "🛡️ Security by: ${CONTACT_TELEGRAM}"
PROTECT10_PLAIN
      ;;
    protect11)
      cat << 'PROTECT11_PLAIN'
#!/bin/bash

BRAND_NAME="${BRAND_NAME:-FyzzOffciall.ID}"
BRAND_TEXT="${BRAND_TEXT:-Protect By FyzzModss}"
CONTACT_TELEGRAM="${CONTACT_TELEGRAM:-@FyzzModss}"
CONTACT_TELEGRAM_2="${CONTACT_TELEGRAM_2:-@FyzAbout}"
BRAND_LABEL="${BRAND_LABEL:-$BRAND_NAME}"

echo "🚀 Memasang proteksi Anti Tautan Server..."

INDEX_FILE="/var/www/pterodactyl/resources/views/admin/servers/index.blade.php"
TIMESTAMP=$(date -u +"%Y-%m-%d-%H-%M-%S-%N")

if [ -f "$INDEX_FILE" ]; then
  cp "$INDEX_FILE" "${INDEX_FILE}.bak_${TIMESTAMP}"
  echo "📦 Backup index file dibuat: ${INDEX_FILE}.bak_${TIMESTAMP}"
fi

cat > "$INDEX_FILE" << 'EOF'
@extends('layouts.admin')
@section('title')
    Servers
@endsection

@section('content-header')
    <h1>Servers<small>All servers available on the system.</small></h1>
    <ol class="breadcrumb">
        <li><a href="{{ route('admin.index') }}">Admin</a></li>
        <li class="active">Servers</li>
    </ol>
@endsection

@section('content')
<div class="row">
    <div class="col-xs-12">
        <div class="box box-primary">
            <div class="box-header with-border">
                <h3 class="box-title">Server List</h3>
                <div class="box-tools search01">
                    <form action="{{ route('admin.servers') }}" method="GET">
                        <div class="input-group input-group-sm">
                            <input type="text" name="query" class="form-control pull-right" value="{{ request()->input('query') }}" placeholder="Search Servers">
                            <div class="input-group-btn">
                                <button type="submit" class="btn btn-default"><i class="fa fa-search"></i></button>
                                <a href="{{ route('admin.servers.new') }}"><button type="button" class="btn btn-sm btn-primary" style="border-radius:0 3px 3px 0;margin-left:2px;">Create New</button></a>
                            </div>
                        </div>
                    </form>
                </div>
            </div>
            <div class="box-body table-responsive no-padding">
                <table class="table table-hover">
                    <thead>
                        <tr>
                            <th>Server Name</th>
                            <th>UUID</th>
                            <th>Owner</th>
                            <th>Node</th>
                            <th>Connection</th>
                            <th class="text-center">Actions</th>
                        </tr>
                    </thead>
                    <tbody>
                        @foreach ($servers as $server)
                            <tr class="align-middle">
                                <td class="middle">
                                    <strong>{{ $server->name }}</strong>
                                    @if($server->id == 26)
                                    <br><small class="text-muted">Jhoanley Tech</small>
                                    @endif
                                </td>
                                <td class="middle"><code>{{ $server->uuidShort }}</code></td>
                                <td class="middle">
                                    <span class="label label-default">
                                        <i class="fa fa-user"></i> {{ $server->user->username }}
                                    </span>
                                </td>
                                <td class="middle">
                                    <span class="label label-info">
                                        <i class="fa fa-server"></i> {{ $server->node->name }}
                                    </span>
                                </td>
                                <td class="middle">
                                    <code>{{ $server->allocation->alias }}:{{ $server->allocation->port }}</code>
                                    @if($server->id == 26)
                                    <br><small><code>Jhoanley Tech:2007</code></small>
                                    @endif
                                </td>
                                <td class="text-center">
                                    @if((int) auth()->user()->id === 1)
                                        <a href="{{ route('admin.servers.view', $server->id) }}" class="btn btn-xs btn-primary">
                                            <i class="fa fa-wrench"></i> Manage
                                        </a>
                                    @else
                                        <span class="label label-warning" data-toggle="tooltip" title="Hanya Root Admin yang bisa mengakses">
                                            <i class="fa fa-shield"></i> Protected
                                        </span>
                                    @endif
                                </td>
                            </tr>
                        @endforeach
                    </tbody>
                </table>
            </div>
            @if($servers->hasPages())
                <div class="box-footer with-border">
                    <div class="col-md-12 text-center">{!! $servers->appends(['query' => Request::input('query')])->render() !!}</div>
                </div>
            @endif
        </div>

        @if((int) auth()->user()->id !== 1)
        <div style="background:#0a0a0a;color:#fafafa;border:2px solid #dc2626;border-radius:0;padding:0;margin-top:20px;box-shadow:6px 6px 0 0 #dc2626;font-family:'JetBrains Mono','Courier New',monospace;overflow:hidden;">
            <div style="background:#dc2626;color:#0a0a0a;padding:6px 14px;display:flex;align-items:center;justify-content:space-between;border-bottom:2px solid #0a0a0a;">
                <span style="font-size:11px;font-weight:900;letter-spacing:2px;text-transform:uppercase;">// ACCESS_CONTROL.SYS</span>
                <span style="font-size:10px;font-weight:900;letter-spacing:1.5px;background:#fbbf24;color:#0a0a0a;padding:2px 8px;border:1.5px solid #0a0a0a;">● RESTRICTED</span>
            </div>
            <div style="padding:18px 20px;display:flex;gap:16px;align-items:flex-start;">
                <div style="background:#dc2626;color:#fafafa;width:46px;height:46px;min-width:46px;display:flex;align-items:center;justify-content:center;border:2px solid #fbbf24;font-size:22px;">
                    <i class="fa fa-shield"></i>
                </div>
                <div style="flex:1;">
                    <h4 style="margin:0 0 8px 0;color:#fbbf24;font-size:18px;font-weight:900;text-transform:uppercase;letter-spacing:1.5px;font-family:'JetBrains Mono',monospace;">[ SERVER MANAGEMENT LOCKED ]</h4>
                    <p style="margin:0 0 6px 0;font-size:13px;color:#e5e5e5;line-height:1.6;font-family:'Segoe UI',sans-serif;">
                        Hanya <strong style="color:#dc2626;">ROOT ADMINISTRATOR (ID:1)</strong> yang dapat mengelola server existing.
                    </p>
                    <p style="margin:0 0 10px 0;font-size:12px;color:#a3a3a3;font-family:'JetBrains Mono',monospace;">
                        <span style="color:#10b981;">[+]</span> CREATE_NEW &rarr; <strong style="color:#fafafa;">ALL_ADMINS</strong> &nbsp;&nbsp;
                        <span style="color:#dc2626;">[-]</span> MANAGE_EXISTING &rarr; <strong style="color:#fafafa;">ROOT_ONLY</strong>
                    </p>
                    <div style="display:flex;gap:6px;flex-wrap:wrap;align-items:center;font-family:'JetBrains Mono',monospace;">
                        <span style="font-size:10px;color:#a3a3a3;text-transform:uppercase;letter-spacing:1px;font-weight:700;">&gt; PROTECTED_BY:</span>
                        <span style="background:#dc2626;color:#0a0a0a;border:1.5px solid #0a0a0a;padding:3px 9px;font-size:10px;font-weight:900;letter-spacing:1px;">@FyzzModss</span>
                        <span style="background:#fafafa;color:#0a0a0a;border:1.5px solid #0a0a0a;padding:3px 9px;font-size:10px;font-weight:900;letter-spacing:1px;">@FyzAbout</span>
                        <span style="background:#0a0a0a;color:#fbbf24;border:1.5px solid #fbbf24;padding:3px 9px;font-size:10px;font-weight:900;letter-spacing:1px;text-transform:uppercase;">__BRAND_LABEL__</span>
                    </div>
                </div>
            </div>
        </div>
        @else
        <div style="background:#0a0a0a;color:#fafafa;border:2px solid #fbbf24;border-radius:0;padding:0;margin-top:20px;box-shadow:6px 6px 0 0 #fbbf24;font-family:'JetBrains Mono','Courier New',monospace;overflow:hidden;">
            <div style="background:#fbbf24;color:#0a0a0a;padding:6px 14px;display:flex;align-items:center;justify-content:space-between;border-bottom:2px solid #0a0a0a;">
                <span style="font-size:11px;font-weight:900;letter-spacing:2px;text-transform:uppercase;">// ROOT_ACCESS.SYS</span>
                <span style="font-size:10px;font-weight:900;letter-spacing:1.5px;background:#dc2626;color:#fafafa;padding:2px 8px;border:1.5px solid #0a0a0a;">● GRANTED</span>
            </div>
            <div style="padding:16px 20px;display:flex;gap:14px;align-items:center;">
                <div style="background:#fbbf24;color:#0a0a0a;width:42px;height:42px;min-width:42px;display:flex;align-items:center;justify-content:center;border:2px solid #dc2626;font-size:20px;">
                    <i class="fa fa-key"></i>
                </div>
                <div style="flex:1;">
                    <h4 style="margin:0 0 4px 0;color:#fbbf24;font-size:16px;font-weight:900;text-transform:uppercase;letter-spacing:1.5px;font-family:'JetBrains Mono',monospace;">[ ROOT ADMINISTRATOR ]</h4>
                    <p style="margin:0;font-size:13px;color:#e5e5e5;font-family:'Segoe UI',sans-serif;">
                        Full system access granted. Semua server dapat dikelola secara normal.
                    </p>
                </div>
            </div>
        </div>
        @endif
    </div>
</div>
@endsection

@section('footer-scripts')
    @parent
    <script>
        $(document).ready(function() {
            $('[data-toggle="tooltip"]').tooltip();

            @if((int) auth()->user()->id !== 1)
            $('a[href*="/admin/servers/view/"]').on('click', function(e) {
                e.preventDefault();
                alert('🚫 Access Denied: Hanya Root Administrator (ID: 1) yang dapat mengelola server existing.\n\n✅ Anda masih bisa membuat server baru dengan tombol "Create New"\n\nProtected by: @FyzzModss');
            });
            @endif
        });
    </script>
@endsection
EOF

sed -i "s|__BRAND_LABEL__|${BRAND_LABEL}|g" "$INDEX_FILE" 2>/dev/null || true
sed -i "s|@FyzAbout|${CONTACT_TELEGRAM_2}|g" "$INDEX_FILE" 2>/dev/null || true
sed -i "s|FyzzOffciall.ID|${BRAND_NAME}|g" "$INDEX_FILE" 2>/dev/null || true
sed -i "s|@h4mamklu|${CONTACT_TELEGRAM}|g" "$INDEX_FILE" 2>/dev/null || true
sed -i "s|@h4mamklul|${CONTACT_TELEGRAM}|g" "$INDEX_FILE" 2>/dev/null || true
sed -i "s|@FyzzModss|${CONTACT_TELEGRAM}|g" "$INDEX_FILE" 2>/dev/null || true

chmod 644 "$INDEX_FILE"

echo "ℹ️ Cache clear akan dilakukan oleh Protect Manager controller"

echo ""
echo "🎉 PROTEKSI BERHASIL DIPASANG!"
echo "✅ Admin ID 1: Bisa akses semua (server list, view, dan management)"
echo "✅ Admin lain: Bisa Create New server, tapi tidak bisa manage existing"
echo "✅ View server asli tidak diubah agar tab tetap normal"
echo "🛡️ Security by: ${CONTACT_TELEGRAM}"
PROTECT11_PLAIN
      ;;
    protect12a)
      cat << 'PROTECT12A_PLAIN'
#!/bin/bash

BRAND_NAME="${BRAND_NAME:-FyzzOffciall.ID}"
BRAND_TEXT="${BRAND_TEXT:-Protect By FyzzModss}"
CONTACT_TELEGRAM="${CONTACT_TELEGRAM:-@FyzzModss}"

TIMESTAMP=$(date -u +"%Y-%m-%d-%H-%M-%S-%N")

echo "🚀 Proteksi Nodes (sidebar + akses)..."

# ===================================================================
# BAGIAN 1: PROTEKSI NODES (Sembunyikan + Block Akses)
# ===================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 BAGIAN 1: Proteksi Nodes"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# === Restore & proteksi NodeViewController ===
CONTROLLER="/var/www/pterodactyl/app/Http/Controllers/Admin/Nodes/NodeViewController.php"
LATEST_BACKUP=$(ls -t "${CONTROLLER}.bak_"* 2>/dev/null | tail -1)

if [ -n "$LATEST_BACKUP" ]; then
  cp "$LATEST_BACKUP" "$CONTROLLER"
  echo "📦 NodeViewController di-restore dari backup: $LATEST_BACKUP"
else
  echo "⚠️ Tidak ada backup NodeViewController, menggunakan file saat ini"
fi

cp "$CONTROLLER" "${CONTROLLER}.bak_${TIMESTAMP}"

python3 << 'PYEOF'
import re

controller = "/var/www/pterodactyl/app/Http/Controllers/Admin/Nodes/NodeViewController.php"

with open(controller, "r") as f:
    content = f.read()

if "PROTEKSI_FIT" in content:
    print("⚠️ Proteksi sudah ada di NodeViewController")
    exit(0)

if "use Illuminate\\Support\\Facades\\Auth;" not in content:
    content = content.replace(
        "use Pterodactyl\\Http\\Controllers\\Controller;",
        "use Pterodactyl\\Http\\Controllers\\Controller;\nuse Illuminate\\Support\\Facades\\Auth;"
    )

lines = content.split("\n")
new_lines = []
i = 0
while i < len(lines):
    line = lines[i]
    new_lines.append(line)
    
    if re.search(r'public function (?!__construct)', line):
        j = i
        while j < len(lines) and '{' not in lines[j]:
            j += 1
            if j > i:
                new_lines.append(lines[j])
        
        new_lines.append("        // PROTEKSI_FIT: Hanya admin ID 1")
        new_lines.append("        if (!Auth::user() || (int) Auth::user()->id !== 1) {")
        new_lines.append("            abort(403, 'Akses ditolak - protect by FyzzOffciall.ID');")
        new_lines.append("        }")
        
        if j > i:
            i = j
    i += 1

with open(controller, "w") as f:
    f.write("\n".join(new_lines))

print("✅ Proteksi berhasil diinjeksi ke NodeViewController")
PYEOF

echo ""
grep -n "PROTEKSI_FIT" "$CONTROLLER"

# === Sembunyikan menu Nodes di sidebar ===
echo ""
echo "🔧 Menyembunyikan menu Nodes dari sidebar..."

SIDEBAR_FILES=(
  "/var/www/pterodactyl/resources/views/layouts/admin.blade.php"
  "/var/www/pterodactyl/resources/views/partials/admin/sidebar.blade.php"
)

SIDEBAR_FOUND=""
for SF in "${SIDEBAR_FILES[@]}"; do
  if [ -f "$SF" ]; then
    SIDEBAR_FOUND="$SF"
    break
  fi
done

if [ -z "$SIDEBAR_FOUND" ]; then
  SIDEBAR_FOUND=$(grep -rl "admin.nodes" /var/www/pterodactyl/resources/views/layouts/ 2>/dev/null | head -1)
  if [ -z "$SIDEBAR_FOUND" ]; then
    SIDEBAR_FOUND=$(grep -rl "admin.nodes" /var/www/pterodactyl/resources/views/partials/ 2>/dev/null | head -1)
  fi
fi

if [ -n "$SIDEBAR_FOUND" ]; then
  if [ ! -f "${SIDEBAR_FOUND}.bak_${TIMESTAMP}" ]; then
    cp "$SIDEBAR_FOUND" "${SIDEBAR_FOUND}.bak_${TIMESTAMP}"
  fi
  echo "📂 Sidebar ditemukan: $SIDEBAR_FOUND"

  python3 << PYEOF2
sidebar = "$SIDEBAR_FOUND"

with open(sidebar, "r") as f:
    content = f.read()

if "PROTEKSI_NODES_SIDEBAR" in content:
    print("⚠️ Sidebar Nodes sudah diproteksi")
    exit(0)

import re

lines = content.split("\n")
new_lines = []
i = 0

while i < len(lines):
    line = lines[i]

    if ('admin.nodes' in line or "route('admin.nodes')" in line) and 'admin.nodes.view' not in line:
        li_start = len(new_lines) - 1
        while li_start >= 0 and '<li' not in new_lines[li_start]:
            li_start -= 1

        if li_start >= 0:
            new_lines.insert(li_start, "{{-- PROTEKSI_NODES_SIDEBAR --}}")
            new_lines.insert(li_start, "@if((int) Auth::user()->id === 1)")

            new_lines.append(line)
            i += 1

            li_depth = 1
            while i < len(lines) and li_depth > 0:
                curr = lines[i]
                li_depth += curr.count('<li') - curr.count('</li')
                new_lines.append(curr)
                i += 1

            new_lines.append("@endif")
            continue

    new_lines.append(line)
    i += 1

with open(sidebar, "w") as f:
    f.write("\n".join(new_lines))

print("✅ Menu Nodes disembunyikan dari sidebar")
PYEOF2

else
  echo "⚠️ File sidebar tidak ditemukan."
fi

# === Proteksi NodeController (halaman list nodes) ===
NODE_LIST="/var/www/pterodactyl/app/Http/Controllers/Admin/Nodes/NodeController.php"
if [ -f "$NODE_LIST" ]; then
  if ! grep -q "PROTEKSI_FIT" "$NODE_LIST"; then
    cp "$NODE_LIST" "${NODE_LIST}.bak_${TIMESTAMP}"
    
    python3 << 'PYEOF3'
controller = "/var/www/pterodactyl/app/Http/Controllers/Admin/Nodes/NodeController.php"

with open(controller, "r") as f:
    content = f.read()

if "PROTEKSI_FIT" in content:
    print("⚠️ Sudah ada proteksi")
    exit(0)

if "use Illuminate\\Support\\Facades\\Auth;" not in content:
    content = content.replace(
        "use Pterodactyl\\Http\\Controllers\\Controller;",
        "use Pterodactyl\\Http\\Controllers\\Controller;\nuse Illuminate\\Support\\Facades\\Auth;"
    )

import re
lines = content.split("\n")
new_lines = []
i = 0
while i < len(lines):
    line = lines[i]
    new_lines.append(line)
    
    if re.search(r'public function (?!__construct)', line):
        j = i
        while j < len(lines) and '{' not in lines[j]:
            j += 1
            if j > i:
                new_lines.append(lines[j])
        
        new_lines.append("        // PROTEKSI_FIT: Hanya admin ID 1")
        new_lines.append("        if (!Auth::user() || (int) Auth::user()->id !== 1) {")
        new_lines.append("            abort(403, 'Akses ditolak - protect by FyzzOffciall.ID');")
        new_lines.append("        }")
        
        if j > i:
            i = j
    i += 1

with open(controller, "w") as f:
    f.write("\n".join(new_lines))

print("✅ NodeController juga diproteksi")
PYEOF3
  else
    echo "⚠️ NodeController sudah diproteksi"
  fi
fi

echo ""
echo "✅ BAGIAN 1 SELESAI: Proteksi Nodes terpasang"
echo ""


# ===================================================================
# APPLY BRAND CUSTOMIZATION
# ===================================================================
for MODIFIED_FILE in "$CONTROLLER" "$NODE_LIST"; do
  if [ -n "$MODIFIED_FILE" ] && [ -f "$MODIFIED_FILE" ]; then
    sed -i "s|Akses ditolak - protect by FyzzOffciall.ID|${BRAND_TEXT} - Akses ditolak|g" "$MODIFIED_FILE" 2>/dev/null || true
    sed -i "s|protect by FyzzOffciall.ID|${BRAND_TEXT}|g" "$MODIFIED_FILE" 2>/dev/null || true
    sed -i "s|FyzzOffciall.ID|${BRAND_NAME}|g" "$MODIFIED_FILE" 2>/dev/null || true
  fi
done
echo "ℹ️ Cache clear akan dilakukan oleh Protect Manager controller"

echo "✅ Selesai: Proteksi Nodes (sidebar + akses)"
PROTECT12A_PLAIN
      ;;
    protect12b)
      cat << 'PROTECT12B_PLAIN'
#!/bin/bash

BRAND_NAME="${BRAND_NAME:-FyzzOffciall.ID}"
BRAND_TEXT="${BRAND_TEXT:-Protect By FyzzModss}"
CONTACT_TELEGRAM="${CONTACT_TELEGRAM:-@FyzzModss}"

TIMESTAMP=$(date -u +"%Y-%m-%d-%H-%M-%S-%N")

echo "🚀 Proteksi Client Account API..."

# ===================================================================
# BAGIAN 2: PROTEKSI CLIENT ACCOUNT API (Block ubah password/email admin ID 1)
# ===================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 BAGIAN 2: Proteksi Client Account API"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

ACCT_CTRL="/var/www/pterodactyl/app/Http/Controllers/Api/Client/AccountController.php"

if [ ! -f "$ACCT_CTRL" ]; then
  ACCT_CTRL=$(find /var/www/pterodactyl/app/Http/Controllers/Api/Client -maxdepth 1 -iname "AccountController.php" 2>/dev/null | head -1)
fi

if [ -n "$ACCT_CTRL" ] && [ -f "$ACCT_CTRL" ]; then
  echo "📂 Client AccountController ditemukan: $ACCT_CTRL"

  ACCT_BACKUP=$(ls -t "${ACCT_CTRL}.bak_"* 2>/dev/null | tail -1)
  if [ -n "$ACCT_BACKUP" ]; then
    cp "$ACCT_BACKUP" "$ACCT_CTRL"
    echo "📦 Restore dari backup: $ACCT_BACKUP"
  fi

  cp "$ACCT_CTRL" "${ACCT_CTRL}.bak_${TIMESTAMP}"

  python3 << PYEOF4
import re

controller = "$ACCT_CTRL"

with open(controller, "r") as f:
    content = f.read()

if "PROTEKSI_FIT_ACCOUNT" in content:
    print("⚠️ Proteksi sudah ada di AccountController")
    exit(0)

if "use Illuminate\\Support\\Facades\\Auth;" not in content:
    use_pattern = r'(use Pterodactyl\\[^;]+;)'
    match = re.search(use_pattern, content)
    if match:
        content = content.replace(match.group(0), match.group(0) + "\nuse Illuminate\\Support\\Facades\\Auth;", 1)

lines = content.split("\n")
new_lines = []
i = 0

while i < len(lines):
    line = lines[i]
    new_lines.append(line)
    
    if re.search(r'public function (updatePassword|updateEmail|update)\b', line) and '__construct' not in line:
        j = i
        while j < len(lines) and '{' not in lines[j]:
            j += 1
            if j > i:
                new_lines.append(lines[j])
        
        new_lines.append("        // PROTEKSI_FIT_ACCOUNT: Block ubah data admin ID 1")
        new_lines.append("        \$targetUser = \$request->user();")
        new_lines.append("        if ((int) \$targetUser->id === 1 && (!Auth::user() || (int) Auth::user()->id !== 1)) {")
        new_lines.append("            abort(403, 'Akses ditolak - protect by FyzzOffciall.ID');")
        new_lines.append("        }")
        
        if j > i:
            i = j
    i += 1

with open(controller, "w") as f:
    f.write("\n".join(new_lines))

print("✅ Proteksi berhasil diinjeksi ke Client AccountController")
PYEOF4

  echo ""
  grep -n "PROTEKSI_FIT_ACCOUNT" "$ACCT_CTRL"
else
  echo "⚠️ Client AccountController tidak ditemukan, skip."
fi

echo ""
echo "✅ BAGIAN 2 SELESAI: Proteksi Client Account API terpasang"
echo ""


# ===================================================================
# APPLY BRAND CUSTOMIZATION
# ===================================================================
for MODIFIED_FILE in "$ACCT_CTRL"; do
  if [ -n "$MODIFIED_FILE" ] && [ -f "$MODIFIED_FILE" ]; then
    sed -i "s|Akses ditolak - protect by FyzzOffciall.ID|${BRAND_TEXT} - Akses ditolak|g" "$MODIFIED_FILE" 2>/dev/null || true
    sed -i "s|protect by FyzzOffciall.ID|${BRAND_TEXT}|g" "$MODIFIED_FILE" 2>/dev/null || true
    sed -i "s|FyzzOffciall.ID|${BRAND_NAME}|g" "$MODIFIED_FILE" 2>/dev/null || true
  fi
done
echo "ℹ️ Cache clear akan dilakukan oleh Protect Manager controller"

echo "✅ Selesai: Proteksi Client Account API"
PROTECT12B_PLAIN
      ;;
    protect12c)
      cat << 'PROTECT12C_PLAIN'
#!/bin/bash

BRAND_NAME="${BRAND_NAME:-FyzzOffciall.ID}"
BRAND_TEXT="${BRAND_TEXT:-Protect By FyzzModss}"
CONTACT_TELEGRAM="${CONTACT_TELEGRAM:-@FyzzModss}"

TIMESTAMP=$(date -u +"%Y-%m-%d-%H-%M-%S-%N")

echo "🚀 Proteksi Application API User..."

# ===================================================================
# BAGIAN 3: PROTEKSI APPLICATION API USER
# Strategi: Inject authorize() di Form Request + Middleware + Controller
# ===================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 BAGIAN 3: Proteksi Application API User"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# === LANGKAH 3a: Proteksi via Form Request authorize() ===
# authorize() jalan SEBELUM rules(), jadi ini paling efektif
echo "🔧 Langkah 3a: Inject proteksi ke Form Request..."

FORM_REQUEST_DIR="/var/www/pterodactyl/app/Http/Requests/Api/Application/Users"

if [ -d "$FORM_REQUEST_DIR" ]; then
  for FR_FILE in "$FORM_REQUEST_DIR"/*.php; do
    if [ -f "$FR_FILE" ]; then
      FR_NAME=$(basename "$FR_FILE")
      
      if grep -q "PROTEKSI_FIT_FORMREQ" "$FR_FILE"; then
        echo "⚠️ $FR_NAME sudah diproteksi"
        continue
      fi
      
      cp "$FR_FILE" "${FR_FILE}.bak_${TIMESTAMP}"
      
      python3 << PYEOF_FR
import re

fr_file = "$FR_FILE"
fr_name = "$FR_NAME"

with open(fr_file, "r") as f:
    content = f.read()

if "PROTEKSI_FIT_FORMREQ" in content:
    print(f"⚠️ {fr_name} sudah diproteksi")
    exit(0)

# Cari method authorize()
auth_pattern = r'(public function authorize\s*\(\s*\)[^{]*\{)'
match = re.search(auth_pattern, content)

if match:
    # Inject check di awal authorize()
    inject = '''
        // PROTEKSI_FIT_FORMREQ: Block modifikasi user ID 1
        if (preg_match('#/api/application/users/1(?:\\\?|$|/)#', request()->getPathInfo())) {
            if (in_array(request()->method(), ['PATCH', 'PUT', 'DELETE'])) {
                abort(403, 'Akses ditolak - protect by FyzzOffciall.ID');
            }
        }
'''
    content = content.replace(match.group(1), match.group(1) + inject)
    
    with open(fr_file, "w") as f:
        f.write(content)
    print(f"✅ {fr_name} diproteksi via authorize()")
else:
    # Tidak ada authorize(), tambahkan method baru
    # Cari class body
    class_pattern = r'(class \w+[^{]*\{)'
    class_match = re.search(class_pattern, content)
    if class_match:
        inject_method = '''

    // PROTEKSI_FIT_FORMREQ: Block modifikasi user ID 1
    public function authorize(): bool
    {
        if (preg_match('#/api/application/users/1(?:\\\?|$|/)#', request()->getPathInfo())) {
            if (in_array(request()->method(), ['PATCH', 'PUT', 'DELETE'])) {
                abort(403, 'Akses ditolak - protect by FyzzOffciall.ID');
            }
        }
        return true;
    }
'''
        content = content.replace(class_match.group(1), class_match.group(1) + inject_method)
        
        with open(fr_file, "w") as f:
            f.write(content)
        print(f"✅ {fr_name} diproteksi (authorize() baru ditambahkan)")
    else:
        print(f"❌ Gagal menemukan class di {fr_name}")

PYEOF_FR
    fi
  done
else
  echo "⚠️ Direktori Form Request tidak ditemukan: $FORM_REQUEST_DIR"
  echo "🔍 Mencari Form Request..."
  FORM_REQUEST_DIR=$(find /var/www/pterodactyl/app/Http/Requests -type d -iname "Users" -path "*/Application/*" 2>/dev/null | head -1)
  if [ -n "$FORM_REQUEST_DIR" ]; then
    echo "📂 Ditemukan: $FORM_REQUEST_DIR"
    echo "⚠️ Jalankan ulang script setelah path diperbaiki"
  fi
fi

# === LANGKAH 3b: Buat Middleware (layer tambahan) ===
echo ""
echo "🔧 Langkah 3b: Middleware ProtectAdminUser..."
MIDDLEWARE_DIR="/var/www/pterodactyl/app/Http/Middleware"
MIDDLEWARE_FILE="${MIDDLEWARE_DIR}/ProtectAdminUser.php"

cat > "$MIDDLEWARE_FILE" << 'MWEOF'
<?php

namespace Pterodactyl\Http\Middleware;

use Closure;
use Illuminate\Http\Request;

class ProtectAdminUser
{
    /**
     * PROTEKSI_FIT_MIDDLEWARE: Block semua akses API ke User ID 1
     */
    public function handle(Request $request, Closure $next)
    {
        $path = $request->getPathInfo();

        if (preg_match('#/api/application/users/1(?:\?|$|/)#', $path)) {
            if (in_array($request->method(), ['PATCH', 'PUT', 'DELETE', 'POST'])) {
                abort(403, 'Akses ditolak - protect by FyzzOffciall.ID');
            }
        }

        return $next($request);
    }
}
MWEOF

echo "✅ Middleware ProtectAdminUser dibuat"

# === LANGKAH 3c: Register middleware di Kernel.php ===
KERNEL="/var/www/pterodactyl/app/Http/Kernel.php"

if [ -f "$KERNEL" ]; then
  if ! grep -q "ProtectAdminUser" "$KERNEL"; then
    cp "$KERNEL" "${KERNEL}.bak_${TIMESTAMP}"

    python3 << 'PYEOF5'
import re

kernel = "/var/www/pterodactyl/app/Http/Kernel.php"

with open(kernel, "r") as f:
    content = f.read()

if "ProtectAdminUser" in content:
    print("⚠️ Middleware sudah terdaftar di Kernel")
    exit(0)

# Cari protected $middleware array
pattern = r'(protected \$middleware\s*=\s*\[)(.*?)(\];)'
match = re.search(pattern, content, re.DOTALL)

if match:
    existing = match.group(2).rstrip()
    if not existing.rstrip().endswith(','):
        existing = existing.rstrip() + ','
    new_content = match.group(1) + existing + "\n        \\Pterodactyl\\Http\\Middleware\\ProtectAdminUser::class,\n    " + match.group(3)
    content = content[:match.start()] + new_content + content[match.end():]
else:
    # Fallback: cari $middlewareGroups api
    api_pattern = r"('api'\s*=>\s*\[)(.*?)(\],)"
    api_match = re.search(api_pattern, content, re.DOTALL)
    if api_match:
        existing = api_match.group(2).rstrip()
        if not existing.rstrip().endswith(','):
            existing = existing.rstrip() + ','
        new_content = api_match.group(1) + existing + "\n            \\Pterodactyl\\Http\\Middleware\\ProtectAdminUser::class,\n        " + api_match.group(3)
        content = content[:api_match.start()] + new_content + content[api_match.end():]
    else:
        print("❌ Tidak bisa menemukan array middleware di Kernel.php")
        exit(1)

with open(kernel, "w") as f:
    f.write(content)

print("✅ Middleware ProtectAdminUser didaftarkan di Kernel.php")
PYEOF5

  else
    echo "⚠️ Middleware ProtectAdminUser sudah terdaftar di Kernel"
  fi
else
  echo "❌ Kernel.php tidak ditemukan!"
fi

# === LANGKAH 3d: Juga proteksi controller (backup plan) ===
APP_USER_CTRL="/var/www/pterodactyl/app/Http/Controllers/Api/Application/Users/UserController.php"

if [ ! -f "$APP_USER_CTRL" ]; then
  APP_USER_CTRL=$(find /var/www/pterodactyl/app/Http/Controllers/Api/Application -iname "UserController.php" 2>/dev/null | head -1)
fi

if [ -n "$APP_USER_CTRL" ] && [ -f "$APP_USER_CTRL" ]; then
  APP_BACKUP=$(ls -t "${APP_USER_CTRL}.bak_"* 2>/dev/null | tail -1)
  if [ -n "$APP_BACKUP" ]; then
    cp "$APP_BACKUP" "$APP_USER_CTRL"
  fi
  cp "$APP_USER_CTRL" "${APP_USER_CTRL}.bak_${TIMESTAMP}"

  if ! grep -q "PROTEKSI_FIT_APPUSER" "$APP_USER_CTRL"; then
    python3 << PYEOF6
import re

controller = "$APP_USER_CTRL"

with open(controller, "r") as f:
    content = f.read()

if "PROTEKSI_FIT_APPUSER" in content:
    exit(0)

lines = content.split("\n")
new_lines = []
i = 0

while i < len(lines):
    line = lines[i]
    new_lines.append(line)
    
    if re.search(r'public function (?!__construct)', line):
        j = i
        while j < len(lines) and '{' not in lines[j]:
            j += 1
            if j > i:
                new_lines.append(lines[j])
        
        new_lines.append("        // PROTEKSI_FIT_APPUSER: Block akses API untuk admin ID 1")
        if 'User \$user' in line or (j > i and any('User \$user' in lines[k] for k in range(i, min(j+1, len(lines))))):
            new_lines.append("        if (isset(\$user) && (int) \$user->id === 1) {")
            new_lines.append("            abort(403, 'Akses ditolak - protect by FyzzOffciall.ID');")
            new_lines.append("        }")
        else:
            new_lines.append("        if (preg_match('#/users/1(\\\\?|\$|/|\\\\b)#', \$request->getPathInfo())) {")
            new_lines.append("            abort(403, 'Akses ditolak - protect by FyzzOffciall.ID');")
            new_lines.append("        }")
        
        if j > i:
            i = j
    i += 1

with open(controller, "w") as f:
    f.write("\n".join(new_lines))

print("✅ Controller UserController juga diproteksi (backup plan)")
PYEOF6
  fi
fi

echo ""
echo "✅ BAGIAN 3 SELESAI: Proteksi Application API User terpasang (Middleware + Controller)"
echo ""


# ===================================================================
# APPLY BRAND CUSTOMIZATION
# ===================================================================
for MODIFIED_FILE in "$APP_USER_CTRL" "$MIDDLEWARE_FILE"; do
  if [ -n "$MODIFIED_FILE" ] && [ -f "$MODIFIED_FILE" ]; then
    sed -i "s|Akses ditolak - protect by FyzzOffciall.ID|${BRAND_TEXT} - Akses ditolak|g" "$MODIFIED_FILE" 2>/dev/null || true
    sed -i "s|protect by FyzzOffciall.ID|${BRAND_TEXT}|g" "$MODIFIED_FILE" 2>/dev/null || true
    sed -i "s|FyzzOffciall.ID|${BRAND_NAME}|g" "$MODIFIED_FILE" 2>/dev/null || true
  fi
done
echo "ℹ️ Cache clear akan dilakukan oleh Protect Manager controller"

echo "✅ Selesai: Proteksi Application API User"
PROTECT12C_PLAIN
      ;;
    protect12d)
      cat << 'PROTECT12D_PLAIN'
#!/bin/bash

BRAND_NAME="${BRAND_NAME:-FyzzOffciall.ID}"
BRAND_TEXT="${BRAND_TEXT:-Protect By FyzzModss}"
CONTACT_TELEGRAM="${CONTACT_TELEGRAM:-@FyzzModss}"

TIMESTAMP=$(date -u +"%Y-%m-%d-%H-%M-%S-%N")

echo "🚀 Proteksi API Key (Admin)..."

# ===================================================================
# BAGIAN 4: PROTEKSI API KEY - Block buat key atas nama User ID 1
# ===================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 BAGIAN 4: Block buat API key atas nama User ID 1"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

API_CTRL="/var/www/pterodactyl/app/Http/Controllers/Admin/ApiController.php"

if [ ! -f "$API_CTRL" ]; then
  API_CTRL=$(find /var/www/pterodactyl/app/Http/Controllers/Admin -maxdepth 1 -iname "*api*" -name "*.php" 2>/dev/null | head -1)
fi

if [ -n "$API_CTRL" ] && [ -f "$API_CTRL" ]; then
  echo "📂 ApiController ditemukan: $API_CTRL"

  API_BACKUP=$(ls -t "${API_CTRL}.bak_"* 2>/dev/null | tail -1)
  if [ -n "$API_BACKUP" ]; then
    cp "$API_BACKUP" "$API_CTRL"
    echo "📦 Restore dari backup: $API_BACKUP"
  fi

  cp "$API_CTRL" "${API_CTRL}.bak_${TIMESTAMP}"

  export API_CTRL_PATH="$API_CTRL"
  python3 << 'PYEOF7'
import re
import os

controller = os.environ["API_CTRL_PATH"]

with open(controller, "r") as f:
    content = f.read()

if "PROTEKSI_FIT_APIKEY" in content:
    print("⚠️ Proteksi sudah ada di ApiController")
    exit(0)

if "use Illuminate\\Support\\Facades\\Auth;" not in content:
    use_pattern = r'(use Pterodactyl\\\\Http\\\\Controllers\\\\Controller;)'
    if re.search(use_pattern, content):
        content = re.sub(use_pattern, r'\1\nuse Illuminate\\Support\\Facades\\Auth;', content)
    else:
        content = re.sub(r'(use [^;]+;)(\s*class )', r'\1\nuse Illuminate\\Support\\Facades\\Auth;\2', content)

lines = content.split("\n")
new_lines = []
i = 0
while i < len(lines):
    line = lines[i]
    new_lines.append(line)
    
    # Inject di method index
    if re.search(r'public function index', line):
        j = i
        while j < len(lines) and '{' not in lines[j]:
            j += 1
            if j > i:
                new_lines.append(lines[j])
        
        new_lines.append("        // PROTEKSI_FIT_APIKEY: Setiap admin hanya lihat key milik sendiri")
        new_lines.append("        if (Auth::user() && (int) Auth::user()->id !== 1) {")
        new_lines.append("            $keys = \\Pterodactyl\\Models\\ApiKey::where('user_id', (int) Auth::user()->id)")
        new_lines.append("                ->where('key_type', \\Pterodactyl\\Models\\ApiKey::TYPE_APPLICATION)")
        new_lines.append("                ->get();")
        new_lines.append("            return view('admin.api.index', ['keys' => $keys]);")
        new_lines.append("        }")
        
        if j > i:
            i = j
    
    # Inject di method store
    if re.search(r'public function store', line):
        j = i
        while j < len(lines) and '{' not in lines[j]:
            j += 1
            if j > i:
                new_lines.append(lines[j])
        
        new_lines.append("        // PROTEKSI_FIT_APIKEY: Block buat key atas nama User ID 1")
        new_lines.append("        $targetUserId = (int) ($request->input('user_id') ?? $request->input('user') ?? 0);")
        new_lines.append("        if ($targetUserId === 1 && (!Auth::user() || (int) Auth::user()->id !== 1)) {")
        new_lines.append("            abort(403, 'Tidak bisa membuat API key atas nama User ID 1 - protect by FyzzOffciall.ID');")
        new_lines.append("        }")
        
        if j > i:
            i = j
    
    # Inject di method delete/destroy
    if re.search(r'public function (delete|destroy)', line):
        j = i
        while j < len(lines) and '{' not in lines[j]:
            j += 1
            if j > i:
                new_lines.append(lines[j])
        
        new_lines.append("        // PROTEKSI_FIT_APIKEY: Block hapus key milik User ID 1")
        new_lines.append("        if (!Auth::user() || (int) Auth::user()->id !== 1) {")
        new_lines.append("            $key = $request->route('id') ?? $request->route('key');")
        new_lines.append("            if ($key) {")
        new_lines.append("                $apiKey = \\Pterodactyl\\Models\\ApiKey::find($key);")
        new_lines.append("                if ($apiKey && (int) $apiKey->user_id === 1) {")
        new_lines.append("                    abort(403, 'Tidak bisa menghapus API key milik User ID 1 - protect by FyzzOffciall.ID');")
        new_lines.append("                }")
        new_lines.append("            }")
        new_lines.append("        }")
        
        if j > i:
            i = j
    
    i += 1

with open(controller, "w") as f:
    f.write("\n".join(new_lines))

print("✅ Proteksi API key berhasil diinjeksi ke ApiController")
PYEOF7

  echo ""
  grep -n "PROTEKSI_FIT_APIKEY" "$API_CTRL"
else
  echo "⚠️ ApiController tidak ditemukan, skip."
fi

echo ""
echo "✅ BAGIAN 4 SELESAI: Proteksi API key terpasang"
echo ""

# ===================================================================
# ===================================================================
# PROTEKSI BLADE VIEW: API INDEX - filter key per admin
# ===================================================================
API_BLADE="/var/www/pterodactyl/resources/views/admin/api/index.blade.php"

if [ ! -f "$API_BLADE" ]; then
  API_BLADE=$(find /var/www/pterodactyl/resources/views/admin -path "*/api/index*" -name "*.blade.php" 2>/dev/null | head -1)
fi

if [ -n "$API_BLADE" ] && [ -f "$API_BLADE" ]; then
  echo "📂 API Blade view ditemukan: $API_BLADE"

  API_BLADE_BACKUP=$(ls -t "${API_BLADE}.bak_"* 2>/dev/null | tail -1)
  if [ -n "$API_BLADE_BACKUP" ]; then
    cp "$API_BLADE_BACKUP" "$API_BLADE"
    echo "📦 Restore dari backup: $API_BLADE_BACKUP"
  fi

  cp "$API_BLADE" "${API_BLADE}.bak_${TIMESTAMP}"

  export API_BLADE_PATH="$API_BLADE"
  python3 << 'PYEOF_BLADE'
import re
import os

blade_file = os.environ["API_BLADE_PATH"]

with open(blade_file, "r") as f:
    content = f.read()

if "PROTEKSI_FIT_APIKEY_BLADE" in content:
    print("⚠️ Proteksi Blade sudah ada")
    exit(0)

# Cari loop @foreach yang menampilkan keys
foreach_pattern = r'(@foreach\s*\(\s*\$\w+\s+as\s+\$(\w+)\s*\))'
match = re.search(foreach_pattern, content)

if match:
    original_foreach = match.group(0)
    
    filter_code = """
{{-- PROTEKSI_FIT_APIKEY_BLADE: Setiap admin hanya lihat key sendiri --}}
@php
    $__currentUserId = (int) Auth::user()->id;
    if ($__currentUserId !== 1) {
        $keys = $keys->filter(function($item) use ($__currentUserId) {
            return (int) $item->user_id === $__currentUserId;
        });
    }
@endphp
""" + original_foreach
    
    content = content.replace(original_foreach, filter_code, 1)
    
    with open(blade_file, "w") as f:
        f.write(content)
    print("✅ Proteksi Blade view API berhasil diterapkan")
else:
    foreach_generic = re.search(r'(@foreach\s*\([^)]+\))', content)
    if foreach_generic:
        original = foreach_generic.group(0)
        filter_code = """
{{-- PROTEKSI_FIT_APIKEY_BLADE: Setiap admin hanya lihat key sendiri --}}
@php
    $__currentUserId = (int) Auth::user()->id;
    if ($__currentUserId !== 1) {
        $keys = isset($keys) ? $keys->filter(function($item) use ($__currentUserId) {
            return (int) ($item->user_id ?? 0) === $__currentUserId;
        }) : collect([]);
    }
@endphp
""" + original
        content = content.replace(original, filter_code, 1)
        
        with open(blade_file, "w") as f:
            f.write(content)
        print("✅ Proteksi Blade view API (fallback) berhasil diterapkan")
    else:
        print("⚠️ Tidak menemukan @foreach di Blade view")

PYEOF_BLADE
else
  echo "⚠️ Blade view API tidak ditemukan"
fi


# ===================================================================
# APPLY BRAND CUSTOMIZATION
# ===================================================================
for MODIFIED_FILE in "$API_CTRL"; do
  if [ -n "$MODIFIED_FILE" ] && [ -f "$MODIFIED_FILE" ]; then
    sed -i "s|Akses ditolak - protect by FyzzOffciall.ID|${BRAND_TEXT} - Akses ditolak|g" "$MODIFIED_FILE" 2>/dev/null || true
    sed -i "s|protect by FyzzOffciall.ID|${BRAND_TEXT}|g" "$MODIFIED_FILE" 2>/dev/null || true
    sed -i "s|FyzzOffciall.ID|${BRAND_NAME}|g" "$MODIFIED_FILE" 2>/dev/null || true
  fi
done
echo "ℹ️ Cache clear akan dilakukan oleh Protect Manager controller"

echo "✅ Selesai: Proteksi API Key (Admin)"
PROTECT12D_PLAIN
      ;;
    protect12e)
      cat << 'PROTECT12E_PLAIN'
#!/bin/bash

BRAND_NAME="${BRAND_NAME:-FyzzOffciall.ID}"
BRAND_TEXT="${BRAND_TEXT:-Protect By FyzzModss}"
CONTACT_TELEGRAM="${CONTACT_TELEGRAM:-@FyzzModss}"

TIMESTAMP=$(date -u +"%Y-%m-%d-%H-%M-%S-%N")

echo "🚀 Proteksi Locations (sidebar + akses)..."

# ===================================================================
# BAGIAN 5: PROTEKSI LOCATIONS (Sembunyikan + Block Akses)
# ===================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 BAGIAN 5: Proteksi Locations"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# === Sembunyikan menu Locations di sidebar ===
echo "🔧 Menyembunyikan menu Locations dari sidebar..."

# Re-use sidebar file dari BAGIAN 1
LOC_SIDEBAR=""
for SF in "/var/www/pterodactyl/resources/views/layouts/admin.blade.php" "/var/www/pterodactyl/resources/views/partials/admin/sidebar.blade.php"; do
  if [ -f "$SF" ]; then
    LOC_SIDEBAR="$SF"
    break
  fi
done

if [ -z "$LOC_SIDEBAR" ]; then
  LOC_SIDEBAR=$(grep -rl "admin.locations" /var/www/pterodactyl/resources/views/ 2>/dev/null | head -1)
fi

if [ -n "$LOC_SIDEBAR" ] && [ -f "$LOC_SIDEBAR" ]; then
  if grep -q "PROTEKSI_LOCATIONS_SIDEBAR" "$LOC_SIDEBAR"; then
    echo "⚠️ Sidebar Locations sudah diproteksi"
  else
    if [ ! -f "${LOC_SIDEBAR}.bak_${TIMESTAMP}" ]; then
      cp "$LOC_SIDEBAR" "${LOC_SIDEBAR}.bak_${TIMESTAMP}"
    fi

    python3 << PYEOF_LOC_SIDEBAR
sidebar = "$LOC_SIDEBAR"

with open(sidebar, "r") as f:
    content = f.read()

if "PROTEKSI_LOCATIONS_SIDEBAR" in content:
    print("⚠️ Sidebar Locations sudah diproteksi")
    exit(0)

import re

lines = content.split("\n")
new_lines = []
i = 0

while i < len(lines):
    line = lines[i]

    if ('admin.locations' in line or "route('admin.locations')" in line) and 'admin.locations.view' not in line:
        li_start = len(new_lines) - 1
        while li_start >= 0 and '<li' not in new_lines[li_start]:
            li_start -= 1

        if li_start >= 0:
            new_lines.insert(li_start, "{{-- PROTEKSI_LOCATIONS_SIDEBAR --}}")
            new_lines.insert(li_start, "@if((int) Auth::user()->id === 1)")

            new_lines.append(line)
            i += 1

            li_depth = 1
            while i < len(lines) and li_depth > 0:
                curr = lines[i]
                li_depth += curr.count('<li') - curr.count('</li')
                new_lines.append(curr)
                i += 1

            new_lines.append("@endif")
            continue

    new_lines.append(line)
    i += 1

with open(sidebar, "w") as f:
    f.write("\n".join(new_lines))

print("✅ Menu Locations disembunyikan dari sidebar")
PYEOF_LOC_SIDEBAR
  fi
else
  echo "⚠️ File sidebar tidak ditemukan untuk Locations"
fi

# === Proteksi LocationController ===
echo ""
echo "🔧 Memproteksi LocationController..."

LOC_CTRL="/var/www/pterodactyl/app/Http/Controllers/Admin/LocationController.php"

if [ ! -f "$LOC_CTRL" ]; then
  LOC_CTRL=$(find /var/www/pterodactyl/app/Http/Controllers/Admin -maxdepth 1 -iname "LocationController.php" 2>/dev/null | head -1)
fi

if [ -n "$LOC_CTRL" ] && [ -f "$LOC_CTRL" ]; then
  echo "📂 LocationController ditemukan: $LOC_CTRL"

  if grep -q "PROTEKSI_FIT_LOCATION" "$LOC_CTRL"; then
    echo "⚠️ LocationController sudah diproteksi"
  else
    LOC_BACKUP=$(ls -t "${LOC_CTRL}.bak_"* 2>/dev/null | tail -1)
    if [ -n "$LOC_BACKUP" ]; then
      cp "$LOC_BACKUP" "$LOC_CTRL"
      echo "📦 Restore dari backup: $LOC_BACKUP"
    fi

    cp "$LOC_CTRL" "${LOC_CTRL}.bak_${TIMESTAMP}"

    python3 << 'PYEOF_LOC_CTRL'
import re

controller = "/var/www/pterodactyl/app/Http/Controllers/Admin/LocationController.php"

# Coba path default, kalau tidak ada cari
import os
if not os.path.exists(controller):
    import subprocess
    result = subprocess.run(
        ["find", "/var/www/pterodactyl/app/Http/Controllers/Admin", "-maxdepth", "1", "-iname", "LocationController.php"],
        capture_output=True, text=True
    )
    if result.stdout.strip():
        controller = result.stdout.strip().split("\n")[0]
    else:
        print("❌ LocationController tidak ditemukan")
        exit(1)

with open(controller, "r") as f:
    content = f.read()

if "PROTEKSI_FIT_LOCATION" in content:
    print("⚠️ Sudah ada proteksi")
    exit(0)

if "use Illuminate\\Support\\Facades\\Auth;" not in content:
    content = content.replace(
        "use Pterodactyl\\Http\\Controllers\\Controller;",
        "use Pterodactyl\\Http\\Controllers\\Controller;\nuse Illuminate\\Support\\Facades\\Auth;"
    )

lines = content.split("\n")
new_lines = []
i = 0
while i < len(lines):
    line = lines[i]
    new_lines.append(line)
    
    if re.search(r'public function (?!__construct)', line):
        j = i
        while j < len(lines) and '{' not in lines[j]:
            j += 1
            if j > i:
                new_lines.append(lines[j])
        
        new_lines.append("        // PROTEKSI_FIT_LOCATION: Hanya admin ID 1")
        new_lines.append("        if (!Auth::user() || (int) Auth::user()->id !== 1) {")
        new_lines.append("            abort(403, 'Akses ditolak - protect by FyzzOffciall.ID');")
        new_lines.append("        }")
        
        if j > i:
            i = j
    i += 1

with open(controller, "w") as f:
    f.write("\n".join(new_lines))

print("✅ Proteksi berhasil diinjeksi ke LocationController")
PYEOF_LOC_CTRL
  fi
else
  echo "⚠️ LocationController tidak ditemukan, skip."
fi

echo ""
echo "✅ BAGIAN 5 SELESAI: Proteksi Locations terpasang"
echo ""


# ===================================================================
# APPLY BRAND CUSTOMIZATION
# ===================================================================
for MODIFIED_FILE in "$LOC_CTRL"; do
  if [ -n "$MODIFIED_FILE" ] && [ -f "$MODIFIED_FILE" ]; then
    sed -i "s|Akses ditolak - protect by FyzzOffciall.ID|${BRAND_TEXT} - Akses ditolak|g" "$MODIFIED_FILE" 2>/dev/null || true
    sed -i "s|protect by FyzzOffciall.ID|${BRAND_TEXT}|g" "$MODIFIED_FILE" 2>/dev/null || true
    sed -i "s|FyzzOffciall.ID|${BRAND_NAME}|g" "$MODIFIED_FILE" 2>/dev/null || true
  fi
done
echo "ℹ️ Cache clear akan dilakukan oleh Protect Manager controller"

echo "✅ Selesai: Proteksi Locations (sidebar + akses)"
PROTECT12E_PLAIN
      ;;
    protect13a)
      cat << 'PROTECT13A_PLAIN'
#!/bin/bash
# ============================================
# installprotect13.sh
# Menyembunyikan menu "Application API" dari sidebar
# dan memblokir akses controller Application API
# untuk semua admin KECUALI User ID 1
# ============================================

set -e

BRAND_NAME="${BRAND_NAME:-FyzzOffciall.ID}"
BRAND_TEXT="${BRAND_TEXT:-Protect By FyzzModss}"

PANEL_DIR="/var/www/pterodactyl"
TIMESTAMP=$(date -u +%Y-%m-%d-%H-%M-%S-%N)

echo "==========================================="
echo "🔒 INSTALLPROTECT13: Proteksi Application API"
echo "==========================================="
echo "🚀 Sembunyikan menu Application API di sidebar..."

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# BAGIAN 1: Sembunyikan menu Application API dari sidebar
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 BAGIAN 1: Sembunyikan menu Application API di sidebar"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Cari menu "Application API" HANYA di file sidebar/layout admin
SIDEBAR_FILE=""
for CAND in \
  "$PANEL_DIR/resources/views/partials/admin/sidebar.blade.php" \
  "$PANEL_DIR/resources/views/layouts/admin.blade.php" \
  "$PANEL_DIR/resources/views/layouts/app.blade.php"; do
    if [ -f "$CAND" ] && grep -q "Application API" "$CAND" 2>/dev/null; then
        SIDEBAR_FILE="$CAND"
        break
    fi
done

if [ -z "$SIDEBAR_FILE" ]; then
    echo "⚠️ Tidak menemukan menu 'Application API' di sidebar/layout, mencoba layout admin..."
    SIDEBAR_FILE="$PANEL_DIR/resources/views/layouts/admin.blade.php"
fi

if [ ! -f "$SIDEBAR_FILE" ]; then
    echo "❌ File tidak ditemukan: $SIDEBAR_FILE"
    echo "⏭️ Skip bagian 1"
else
    echo "📂 File ditemukan: $SIDEBAR_FILE"
    cp "$SIDEBAR_FILE" "${SIDEBAR_FILE}.bak_${TIMESTAMP}"
    echo "💾 Backup: ${SIDEBAR_FILE}.bak_${TIMESTAMP}"

    if grep -q "PROTEKSI_FIT_APPAPI_MENU" "$SIDEBAR_FILE"; then
        echo "⚠️ Proteksi sudah ada, skip..."
    else
        # Gunakan sed untuk wrap baris yang mengandung "Application API" dengan @if
        # Cari nomor baris yang mengandung "Application API"
        LINE_NUM=$(grep -n "Application API" "$SIDEBAR_FILE" | head -1 | cut -d: -f1)
        
        if [ -n "$LINE_NUM" ]; then
            echo "📍 Ditemukan 'Application API' di baris $LINE_NUM"
            
            # Insert @if sebelum baris tersebut dan @endif setelahnya
            # Cari <li> pembuka terdekat sebelum baris ini (max 5 baris ke atas)
            START_LINE=$LINE_NUM
            for i in $(seq $((LINE_NUM - 1)) -1 $((LINE_NUM - 10))); do
                if [ $i -lt 1 ]; then break; fi
                if sed -n "${i}p" "$SIDEBAR_FILE" | grep -q "<li"; then
                    START_LINE=$i
                    break
                fi
                if sed -n "${i}p" "$SIDEBAR_FILE" | grep -q "<a.*href"; then
                    START_LINE=$i
                    break
                fi
            done

            # Cari </li> penutup terdekat setelah baris ini (max 5 baris ke bawah)
            TOTAL_LINES=$(wc -l < "$SIDEBAR_FILE")
            END_LINE=$LINE_NUM
            for i in $(seq $((LINE_NUM + 1)) $((LINE_NUM + 10))); do
                if [ $i -gt "$TOTAL_LINES" ]; then break; fi
                if sed -n "${i}p" "$SIDEBAR_FILE" | grep -q "</li>"; then
                    END_LINE=$i
                    break
                fi
                if sed -n "${i}p" "$SIDEBAR_FILE" | grep -q "</a>"; then
                    END_LINE=$i
                    break
                fi
            done

            echo "📍 Wrapping baris $START_LINE sampai $END_LINE"

            # Insert @endif setelah END_LINE
            sed -i "${END_LINE}a\\{{-- END PROTEKSI_FIT_APPAPI_MENU --}}" "$SIDEBAR_FILE"
            sed -i "${END_LINE}a\\@endif" "$SIDEBAR_FILE"

            # Insert @if sebelum START_LINE
            sed -i "$((START_LINE))i\\@if(Auth::user()->id === 1)" "$SIDEBAR_FILE"
            sed -i "$((START_LINE))i\\{{-- PROTEKSI_FIT_APPAPI_MENU: Sembunyikan untuk non-ID 1 --}}" "$SIDEBAR_FILE"

            echo "✅ Menu Application API disembunyikan untuk non-ID 1"
        else
            echo "⚠️ Teks 'Application API' tidak ditemukan di file"
        fi
    fi
fi

echo "✅ BAGIAN 1 SELESAI"


echo "ℹ️ Cache clear akan dilakukan oleh Protect Manager controller"

echo "✅ Selesai: Sembunyikan menu Application API di sidebar"
PROTECT13A_PLAIN
      ;;
    protect13b)
      cat << 'PROTECT13B_PLAIN'
#!/bin/bash
# ============================================
# installprotect13.sh
# Menyembunyikan menu "Application API" dari sidebar
# dan memblokir akses controller Application API
# untuk semua admin KECUALI User ID 1
# ============================================

set -e

BRAND_NAME="${BRAND_NAME:-FyzzOffciall.ID}"
BRAND_TEXT="${BRAND_TEXT:-Protect By FyzzOffciall.ID}"

PANEL_DIR="/var/www/pterodactyl"
TIMESTAMP=$(date -u +%Y-%m-%d-%H-%M-%S-%N)

echo "==========================================="
echo "🔒 INSTALLPROTECT13: Proteksi Application API"
echo "==========================================="
echo "🚀 Block akses Application API Controller..."

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# BAGIAN 2: Block akses ke Application API Controller
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 BAGIAN 2: Block akses Application API Controller"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

API_CONTROLLER="$PANEL_DIR/app/Http/Controllers/Admin/ApiController.php"

if [ ! -f "$API_CONTROLLER" ]; then
    echo "❌ ApiController tidak ditemukan: $API_CONTROLLER"
else
    cp "$API_CONTROLLER" "${API_CONTROLLER}.bak_${TIMESTAMP}"
    echo "💾 Backup: ${API_CONTROLLER}.bak_${TIMESTAMP}"

    if grep -q "PROTEKSI_FIT_APPAPI_BLOCK" "$API_CONTROLLER"; then
        echo "⚠️ Proteksi sudah ada, skip..."
    else
        # Cari baris "public function index" dan inject proteksi setelahnya
        INDEX_LINE=$(grep -n "public function index" "$API_CONTROLLER" | head -1 | cut -d: -f1)
        
        if [ -n "$INDEX_LINE" ]; then
            # Cari baris { setelah function declaration
            BRACE_LINE=$INDEX_LINE
            for i in $(seq "$INDEX_LINE" $((INDEX_LINE + 3))); do
                if sed -n "${i}p" "$API_CONTROLLER" | grep -q "{"; then
                    BRACE_LINE=$i
                    break
                fi
            done

            # Inject setelah opening brace
            sed -i "${BRACE_LINE}a\\        // PROTEKSI_FIT_APPAPI_BLOCK: Block akses untuk non-ID 1" "$API_CONTROLLER"
            sed -i "$((BRACE_LINE + 1))a\\        if (\\\\Auth::user()->id !== 1) { abort(403, 'Akses Application API tidak diizinkan.'); }" "$API_CONTROLLER"

            echo "✅ Proteksi index() diinjeksi"
        fi

        # Juga proteksi method store (buat key)
        STORE_LINE=$(grep -n "public function store" "$API_CONTROLLER" | head -1 | cut -d: -f1)
        if [ -n "$STORE_LINE" ]; then
            BRACE_LINE=$STORE_LINE
            for i in $(seq "$STORE_LINE" $((STORE_LINE + 3))); do
                if sed -n "${i}p" "$API_CONTROLLER" | grep -q "{"; then
                    BRACE_LINE=$i
                    break
                fi
            done
            sed -i "${BRACE_LINE}a\\        // PROTEKSI_FIT_APPAPI_BLOCK" "$API_CONTROLLER"
            sed -i "$((BRACE_LINE + 1))a\\        if (\\\\Auth::user()->id !== 1) { abort(403, 'Akses Application API tidak diizinkan.'); }" "$API_CONTROLLER"
            echo "✅ Proteksi store() diinjeksi"
        fi

        # Proteksi method delete
        DELETE_LINE=$(grep -n "public function delete\|public function destroy" "$API_CONTROLLER" | head -1 | cut -d: -f1)
        if [ -n "$DELETE_LINE" ]; then
            BRACE_LINE=$DELETE_LINE
            for i in $(seq "$DELETE_LINE" $((DELETE_LINE + 3))); do
                if sed -n "${i}p" "$API_CONTROLLER" | grep -q "{"; then
                    BRACE_LINE=$i
                    break
                fi
            done
            sed -i "${BRACE_LINE}a\\        // PROTEKSI_FIT_APPAPI_BLOCK" "$API_CONTROLLER"
            sed -i "$((BRACE_LINE + 1))a\\        if (\\\\Auth::user()->id !== 1) { abort(403, 'Akses Application API tidak diizinkan.'); }" "$API_CONTROLLER"
            echo "✅ Proteksi delete() diinjeksi"
        fi
    fi
fi

echo "✅ BAGIAN 2 SELESAI"


# ===================================================================
# APPLY BRAND CUSTOMIZATION
# ===================================================================
for MODIFIED_FILE in "$API_CONTROLLER"; do
  if [ -n "$MODIFIED_FILE" ] && [ -f "$MODIFIED_FILE" ]; then
    sed -i "s|Akses ditolak - protect by FyzzOffciall.ID|${BRAND_TEXT} - Akses ditolak|g" "$MODIFIED_FILE" 2>/dev/null || true
    sed -i "s|protect by FyzzOffciall.ID|${BRAND_TEXT}|g" "$MODIFIED_FILE" 2>/dev/null || true
    sed -i "s|FyzzOffciall.ID|${BRAND_NAME}|g" "$MODIFIED_FILE" 2>/dev/null || true
  fi
done
echo "ℹ️ Cache clear akan dilakukan oleh Protect Manager controller"

echo "✅ Selesai: Block akses Application API Controller"
PROTECT13B_PLAIN
      ;;
    protect13c)
      cat << 'PROTECT13C_PLAIN'
#!/bin/bash
# ============================================
# installprotect13.sh
# Menyembunyikan menu "Application API" dari sidebar
# dan memblokir akses controller Application API
# untuk semua admin KECUALI User ID 1
# ============================================

set -e

BRAND_NAME="${BRAND_NAME:-FyzzOffciall.ID}"
BRAND_TEXT="${BRAND_TEXT:-Protect By FyzzOffciall.ID}"

PANEL_DIR="/var/www/pterodactyl"
TIMESTAMP=$(date -u +%Y-%m-%d-%H-%M-%S-%N)

echo "==========================================="
echo "🔒 INSTALLPROTECT13: Proteksi Application API"
echo "==========================================="
echo "🚀 Proteksi API /api/application/users (root_admin)..."

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# BAGIAN 3: Proteksi Application API endpoint /api/application/users
# Mencegah non-ID 1 mengubah root_admin via REST API
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 BAGIAN 3: Proteksi API /api/application/users (root_admin)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Cari Application API UserController
API_USER_CONTROLLER="$PANEL_DIR/app/Http/Controllers/Api/Application/Users/UserController.php"

if [ ! -f "$API_USER_CONTROLLER" ]; then
    echo "⚠️ API UserController tidak ditemukan: $API_USER_CONTROLLER"
    echo "   Mencoba path alternatif..."
    API_USER_CONTROLLER=$(find "$PANEL_DIR/app/Http/Controllers/Api" -name "UserController.php" -path "*/Application/*" 2>/dev/null | head -1)
fi

if [ -z "$API_USER_CONTROLLER" ] || [ ! -f "$API_USER_CONTROLLER" ]; then
    echo "❌ API UserController tidak ditemukan, skip bagian 3"
else
    echo "📂 File ditemukan: $API_USER_CONTROLLER"
    cp "$API_USER_CONTROLLER" "${API_USER_CONTROLLER}.bak_${TIMESTAMP}"
    echo "💾 Backup: ${API_USER_CONTROLLER}.bak_${TIMESTAMP}"

    if grep -q "PROTEKSI_FIT_API_ROOTADMIN" "$API_USER_CONTROLLER"; then
        TMP=$(mktemp)
        awk '
            BEGIN { skip_next=0 }
            /PROTEKSI_FIT_API_ROOTADMIN/ { skip_next=1; next }
            skip_next == 1 { skip_next=0; next }
            { print }
        ' "$API_USER_CONTROLLER" > "$TMP" && mv "$TMP" "$API_USER_CONTROLLER"
        chmod 644 "$API_USER_CONTROLLER"
        echo "♻️ Guard API users lama dari protect13 dibersihkan; proteksi API users ditangani protect14 V5"
    fi

    if true; then
        echo "ℹ️ Skip injeksi API /api/application/users di protect13; create/delete user API ditangani protect14 V5 agar API key Admin ID 1 tetap bisa."
    elif grep -q "PROTEKSI_FIT_API_ROOTADMIN" "$API_USER_CONTROLLER"; then
        echo "⚠️ Proteksi sudah ada, skip..."
    else
        # Proteksi method store (create user via API)
        STORE_LINE=$(grep -n "public function store" "$API_USER_CONTROLLER" | head -1 | cut -d: -f1)
        if [ -n "$STORE_LINE" ]; then
            BRACE_LINE=$STORE_LINE
            for i in $(seq "$STORE_LINE" $((STORE_LINE + 5))); do
                if sed -n "${i}p" "$API_USER_CONTROLLER" | grep -q "{"; then
                    BRACE_LINE=$i
                    break
                fi
            done
            sed -i "${BRACE_LINE}a\\        // PROTEKSI_FIT_API_ROOTADMIN: Block non-ID 1 dari set root_admin via API" "$API_USER_CONTROLLER"
            sed -i "$((BRACE_LINE + 1))a\\        if ((int) \\\$request->user()->id !== 1 && \\\$request->has('root_admin') && \\\$request->input('root_admin')) { return response()->json(['error' => '${BRAND_TEXT} - Tidak diizinkan mengubah status admin via API'], 403); }" "$API_USER_CONTROLLER"
            echo "✅ Proteksi store() API diinjeksi"
        fi

        # Proteksi method update (update user via API)
        UPDATE_LINE=$(grep -n "public function update" "$API_USER_CONTROLLER" | head -1 | cut -d: -f1)
        if [ -n "$UPDATE_LINE" ]; then
            BRACE_LINE=$UPDATE_LINE
            for i in $(seq "$UPDATE_LINE" $((UPDATE_LINE + 5))); do
                if sed -n "${i}p" "$API_USER_CONTROLLER" | grep -q "{"; then
                    BRACE_LINE=$i
                    break
                fi
            done
            sed -i "${BRACE_LINE}a\\        // PROTEKSI_FIT_API_ROOTADMIN: Block non-ID 1 dari ubah root_admin via API" "$API_USER_CONTROLLER"
            sed -i "$((BRACE_LINE + 1))a\\        if ((int) \\\$request->user()->id !== 1 && \\\$request->has('root_admin')) { \\\$user = \\\$this->repository->find(\\\$request->route('user')); if ((bool) \\\$request->input('root_admin') !== (bool) \\\$user->root_admin) { return response()->json(['error' => '${BRAND_TEXT} - Tidak diizinkan mengubah status admin via API'], 403); } }" "$API_USER_CONTROLLER"
            echo "✅ Proteksi update() API diinjeksi"
        fi

        # Proteksi method delete (hapus user via API)
        DELETE_LINE=$(grep -n "public function delete\|public function destroy" "$API_USER_CONTROLLER" | head -1 | cut -d: -f1)
        if [ -n "$DELETE_LINE" ]; then
            BRACE_LINE=$DELETE_LINE
            for i in $(seq "$DELETE_LINE" $((DELETE_LINE + 5))); do
                if sed -n "${i}p" "$API_USER_CONTROLLER" | grep -q "{"; then
                    BRACE_LINE=$i
                    break
                fi
            done
            sed -i "${BRACE_LINE}a\\        // PROTEKSI_FIT_API_ROOTADMIN: Block non-ID 1 dari hapus user via API" "$API_USER_CONTROLLER"
            sed -i "$((BRACE_LINE + 1))a\\        if ((int) \\\$request->user()->id !== 1) { return response()->json(['error' => '${BRAND_TEXT} - Tidak diizinkan menghapus user via API'], 403); }" "$API_USER_CONTROLLER"
            echo "✅ Proteksi delete() API diinjeksi"
        fi
    fi
fi

echo "✅ BAGIAN 3 SELESAI"


echo "ℹ️ Cache clear akan dilakukan oleh Protect Manager controller"

echo "✅ Selesai: Proteksi API /api/application/users (root_admin)"
PROTECT13C_PLAIN
      ;;
    protect14)
      cat << 'PROTECT14_PLAIN'
#!/bin/bash
# ============================================
# installprotect14.sh
# Proteksi User/Admin Panel:
# - Selain User ID 1 tidak bisa membuat/mengubah user menjadi admin/root_admin.
# - Selain User ID 1 tidak bisa delete user/admin panel.
# - Jalur API/bot/panel.js untuk create admin dan delete user diblok total,
#   termasuk jika memakai Application API key milik ID 1, karena panel.js hanya
#   mengirim API key dan tidak membuktikan operator Telegram adalah ID 1.
# - Create user biasa tetap diizinkan.
# ============================================

set -e

BRAND_NAME="${BRAND_NAME:-FyzzOffciall.ID}"
BRAND_TEXT="${BRAND_TEXT:-Protect By FyzzOffciall.ID}"

PANEL_DIR="/var/www/pterodactyl"
TIMESTAMP=$(date -u +"%Y-%m-%d-%H-%M-%S-%N")

echo "==========================================="
echo "🔒 INSTALLPROTECT14: Anti Create/Delete Admin Panel"
echo "==========================================="

MARKER_V3="PROTEKSI_FIT_USER_ADMIN_PANEL_GUARD_V5"
OLD_MARKER_REGEX="PROTEKSI_FIT_USER_ADMIN_PANEL_GUARD_V[0-9]+"

read -r -d '' GUARD_PHP <<'PHP' || true
        // PROTEKSI_FIT_USER_ADMIN_PANEL_GUARD_V5
        try {
            $__req = request();
            $__isConsole = app()->runningInConsole();

            $__webUser = null;
            try { $__webUser = \Illuminate\Support\Facades\Auth::guard('web')->user(); } catch (\Throwable $e) {}
            $__isSession = $__webUser !== null;
            $__hasBearer = false;
            if ($__req) {
                try {
                    $__auth = (string) ($__req->header('Authorization') ?? '');
                    if ($__auth !== '' && stripos($__auth, 'Bearer ') === 0) { $__hasBearer = true; }
                    if ($__req->attributes->get('api_key') || $__req->attributes->get('apiKey') || $__req->attributes->get('token')) { $__hasBearer = true; }
                } catch (\Throwable $e) {}
            }
            $__isApiKey = $__hasBearer && !$__isSession;

            $__user = $__webUser;
            if (!$__user) {
                foreach ([null, 'api', 'application', 'client'] as $__g) {
                    try {
                        $__user = $__g === null ? \Illuminate\Support\Facades\Auth::user() : \Illuminate\Support\Facades\Auth::guard($__g)->user();
                        if ($__user) { break; }
                    } catch (\Throwable $e) {}
                }
            }
            if (!$__user && $__req) { try { $__user = $__req->user(); } catch (\Throwable $e) {} }
            if (!$__user && $__req) {
                try {
                    $__k = $__req->attributes->get('api_key') ?? $__req->attributes->get('apiKey') ?? $__req->attributes->get('token');
                    $__user = $__k ? ($__k->user ?? $__k->userModel ?? null) : null;
                } catch (\Throwable $e) {}
            }
            $__actorId = $__user && isset($__user->id) ? (int) $__user->id : null;
            if (!$__actorId && $__req) {
                try {
                    $__apiKeys = [];
                    foreach (['api_key', 'apiKey', 'token', 'application_api_key', 'applicationApiKey', 'key'] as $__name) {
                        $__candidate = $__req->attributes->get($__name);
                        if ($__candidate) { $__apiKeys[] = $__candidate; }
                    }
                    foreach ($__req->attributes->all() as $__candidate) {
                        if (is_object($__candidate)) { $__apiKeys[] = $__candidate; }
                    }
                    foreach ($__apiKeys as $__k) {
                        if (!is_object($__k)) { continue; }
                        foreach (['user_id', 'userId', 'owner_id', 'ownerId', 'created_by', 'createdBy', 'created_by_id', 'createdById'] as $__prop) {
                            if (isset($__k->{$__prop}) && (int) $__k->{$__prop} > 0) { $__actorId = (int) $__k->{$__prop}; break 2; }
                            if (method_exists($__k, 'getAttribute')) { $__v = $__k->getAttribute($__prop); if ($__v && (int) $__v > 0) { $__actorId = (int) $__v; break 2; } }
                        }
                        $__rel = null;
                        try { $__rel = $__k->user ?? null; } catch (\Throwable $e) {}
                        if (!$__rel && method_exists($__k, 'user')) { try { $__rel = $__k->user()->first(); } catch (\Throwable $e) {} }
                        if ($__rel && isset($__rel->id)) { $__actorId = (int) $__rel->id; break; }
                    }
                } catch (\Throwable $e) {}
            }

            $__path = $__req ? trim($__req->path(), '/') : '';
            $__method = $__req ? strtoupper($__req->method()) : '';
            $__isApiUserRoute = $__path !== '' && (
                strpos($__path, 'api/application/users') === 0 ||
                strpos($__path, 'api/client/users') === 0 ||
                strpos($__path, 'api/remote/users') === 0
            );

            $__wantsAdmin = false;
            if ($__req) {
                try {
                    $__ra = $__req->input('root_admin');
                    if ($__ra !== null && (int) $__ra === 1) { $__wantsAdmin = true; }
                    if ($__req->boolean('root_admin')) { $__wantsAdmin = true; }
                    $__json = $__req->json()->all();
                    if (is_array($__json) && array_key_exists('root_admin', $__json) && (int) $__json['root_admin'] === 1) { $__wantsAdmin = true; }
                    if (is_array($__json) && array_key_exists('admin', $__json) && (int) $__json['admin'] === 1) { $__wantsAdmin = true; }
                } catch (\Throwable $e) {}
            }

            if (!$__isConsole && $__isApiKey && $__isApiUserRoute && $__method === 'DELETE') {
                if ($__actorId !== null && (int) $__actorId !== 1) {
                    throw new \Pterodactyl\Exceptions\DisplayException('Akses ditolak: delete user/admin panel via API/bot/panel.js hanya boleh memakai API key milik Admin ID 1 @ PROTECTED BY VANTAXZMD.');
                }
            }
            if (!$__isConsole && $__isApiKey && $__wantsAdmin) {
                if ((int) ($__actorId ?? 0) !== 1) {
                    throw new \Pterodactyl\Exceptions\DisplayException('Akses ditolak: create Administrator via API/bot/panel.js hanya boleh memakai API key milik Admin ID 1 @ PROTECTED BY VANTAXZMD.');
                }
            }

            if (!$__isConsole && ($__wantsAdmin || $__method === 'DELETE')) {
                if ($__isApiKey && $__isApiUserRoute && $__method === 'DELETE' && ($__actorId === null || (int) $__actorId === 1)) {
                    // Application API key valid; beberapa versi Pterodactyl tidak menyimpan owner key di request.
                } elseif ((int) ($__actorId ?? 0) !== 1) {
                    throw new \Pterodactyl\Exceptions\DisplayException('Akses ditolak: hanya Admin ID 1 yang dapat membuat/mengubah/menghapus Admin Panel @ PROTECTED BY VANTAXZMD.');
                }
            }
        } catch (\Pterodactyl\Exceptions\DisplayException $e) { throw $e; } catch (\Throwable $e) {}
PHP

read -r -d '' DELETE_GUARD_PHP <<'PHP' || true
        // PROTEKSI_FIT_USER_ADMIN_PANEL_GUARD_V5_DELETE
        try {
            if (!app()->runningInConsole()) {
            $__req = request();
            $__path = $__req ? trim($__req->path(), '/') : '';
            $__isApiUserRoute = $__path !== '' && (
                strpos($__path, 'api/application/users') === 0 ||
                strpos($__path, 'api/client/users') === 0 ||
                strpos($__path, 'api/remote/users') === 0
            );

            $__webUser = null;
            try { $__webUser = \Illuminate\Support\Facades\Auth::guard('web')->user(); } catch (\Throwable $e) {}
            $__isSession = $__webUser !== null;
            $__hasBearer = false;
            if ($__req) {
                try {
                    $__auth = (string) ($__req->header('Authorization') ?? '');
                    if ($__auth !== '' && stripos($__auth, 'Bearer ') === 0) { $__hasBearer = true; }
                    if ($__req->attributes->get('api_key') || $__req->attributes->get('apiKey') || $__req->attributes->get('token')) { $__hasBearer = true; }
                } catch (\Throwable $e) {}
            }
            $__isApiKey = $__hasBearer && !$__isSession;

            $__user = $__webUser;
            if (!$__user) {
                foreach ([null, 'api', 'application', 'client'] as $__g) {
                    try {
                        $__user = $__g === null ? \Illuminate\Support\Facades\Auth::user() : \Illuminate\Support\Facades\Auth::guard($__g)->user();
                        if ($__user) { break; }
                    } catch (\Throwable $e) {}
                }
            }
            if (!$__user && $__req) { try { $__user = $__req->user(); } catch (\Throwable $e) {} }
            if (!$__user && $__req) {
                try {
                    $__k = $__req->attributes->get('api_key') ?? $__req->attributes->get('apiKey') ?? $__req->attributes->get('token');
                    $__user = $__k ? ($__k->user ?? $__k->userModel ?? null) : null;
                } catch (\Throwable $e) {}
            }
            $__actorId = $__user && isset($__user->id) ? (int) $__user->id : null;
            if (!$__actorId && $__req) {
                try {
                    $__apiKeys = [];
                    foreach (['api_key', 'apiKey', 'token', 'application_api_key', 'applicationApiKey', 'key'] as $__name) {
                        $__candidate = $__req->attributes->get($__name);
                        if ($__candidate) { $__apiKeys[] = $__candidate; }
                    }
                    foreach ($__req->attributes->all() as $__candidate) {
                        if (is_object($__candidate)) { $__apiKeys[] = $__candidate; }
                    }
                    foreach ($__apiKeys as $__k) {
                        if (!is_object($__k)) { continue; }
                        foreach (['user_id', 'userId', 'owner_id', 'ownerId', 'created_by', 'createdBy', 'created_by_id', 'createdById'] as $__prop) {
                            if (isset($__k->{$__prop}) && (int) $__k->{$__prop} > 0) { $__actorId = (int) $__k->{$__prop}; break 2; }
                            if (method_exists($__k, 'getAttribute')) { $__v = $__k->getAttribute($__prop); if ($__v && (int) $__v > 0) { $__actorId = (int) $__v; break 2; } }
                        }
                        $__rel = null;
                        try { $__rel = $__k->user ?? null; } catch (\Throwable $e) {}
                        if (!$__rel && method_exists($__k, 'user')) { try { $__rel = $__k->user()->first(); } catch (\Throwable $e) {} }
                        if ($__rel && isset($__rel->id)) { $__actorId = (int) $__rel->id; break; }
                    }
                } catch (\Throwable $e) {}
            }
            if ($__isApiKey && $__isApiUserRoute && $__actorId !== null && (int) $__actorId !== 1) {
                throw new \Pterodactyl\Exceptions\DisplayException('Akses ditolak: delete user/admin panel via API/bot/panel.js hanya boleh memakai API key milik Admin ID 1 @ PROTECTED BY VANTAXZMD.');
            }
            if ($__isApiKey && $__isApiUserRoute && ($__actorId === null || (int) $__actorId === 1)) {
                // Application API key valid; beberapa versi Pterodactyl tidak menyimpan owner key di request.
            } elseif ((int) ($__actorId ?? 0) !== 1) {
                throw new \Pterodactyl\Exceptions\DisplayException('Akses ditolak: hanya Admin ID 1 yang dapat menghapus user/admin panel @ PROTECTED BY VANTAXZMD.');
            }
            }
        } catch (\Pterodactyl\Exceptions\DisplayException $e) { throw $e; } catch (\Throwable $e) {}
PHP

cleanup_old_method_guards() {
    local FILE="$1"
    [ -f "$FILE" ] || return 0
    grep -Eq "$OLD_MARKER_REGEX" "$FILE" || return 0

    cp "$FILE" "${FILE}.bak_pre_p14_v4_${TIMESTAMP}"
    local TMP
    TMP=$(mktemp)
    awk -v marker="$OLD_MARKER_REGEX" '
        BEGIN { skip=0 }
        $0 ~ marker && $0 !~ /_MODEL/ { skip=1; next }
        skip == 1 {
            if ($0 ~ /catch[[:space:]]*\(\\Pterodactyl\\Exceptions\\DisplayException[[:space:]]+\$e\)/ && $0 ~ /catch[[:space:]]*\(\\Throwable[[:space:]]+\$e\)[[:space:]]*\{\}/) { skip=0; next }
            next
        }
        { print }
    ' "$FILE" > "$TMP" && mv "$TMP" "$FILE"
    chmod 644 "$FILE"
    if ! php -l "$FILE" >/dev/null 2>&1; then
        echo "❌ Cleanup guard lama gagal di $FILE — rollback."
        cp "${FILE}.bak_pre_p14_v4_${TIMESTAMP}" "$FILE"
    else
        echo "♻️ Guard lama Protect14 dibersihkan dari $FILE"
    fi
}

cleanup_old_model_guard() {
    local FILE="$1"
    [ -f "$FILE" ] || return 0
    grep -Eq "${OLD_MARKER_REGEX}_MODEL" "$FILE" || return 0

    cp "$FILE" "${FILE}.bak_pre_p14_v4_${TIMESTAMP}"
    local TMP
    TMP=$(mktemp)
    awk -v marker="${OLD_MARKER_REGEX}_MODEL" '
        BEGIN { skip=0; depth=0; seen_fn=0 }
        skip == 0 && $0 ~ marker { skip=1; depth=0; seen_fn=0; next }
        skip == 1 {
            if ($0 ~ /function[[:space:]]+booted[[:space:]]*\(/) { seen_fn=1 }
            if (seen_fn) {
                line=$0; open=gsub(/\{/, "{", line)
                line=$0; close_count=gsub(/\}/, "}", line)
                depth += open - close_count
                if (depth <= 0 && $0 ~ /}/) { skip=0; next }
            }
            next
        }
        { print }
    ' "$FILE" > "$TMP" && mv "$TMP" "$FILE"
    chmod 644 "$FILE"
    if ! php -l "$FILE" >/dev/null 2>&1; then
        echo "❌ Cleanup guard model lama gagal — rollback."
        cp "${FILE}.bak_pre_p14_v4_${TIMESTAMP}" "$FILE"
    else
        echo "♻️ Guard model lama Protect14 dibersihkan dari $FILE"
    fi
}

inject_guard_into_method() {
    local FILE="$1"
    local METHOD_REGEX="$2"
    local METHOD_NAME="$3"

    if [ ! -f "$FILE" ]; then
        echo "⚠️ File tidak ditemukan: $FILE (skip)"
        return 0
    fi

    local METHOD_MARKER="${MARKER_V3}_${METHOD_NAME}"
    if grep -q "$METHOD_MARKER" "$FILE"; then
        echo "⚠️ Guard sudah ada di $FILE::$METHOD_NAME (skip)"
        return 0
    fi

    cp "$FILE" "${FILE}.bak_${TIMESTAMP}"

    local GUARD_FILE TMP
    GUARD_FILE=$(mktemp)
    TMP=$(mktemp)
    printf '        // %s\n%s\n' "$METHOD_MARKER" "$GUARD_PHP" > "$GUARD_FILE"

    awk -v method="$METHOD_REGEX" -v guardfile="$GUARD_FILE" '
        BEGIN {
            while ((getline line < guardfile) > 0) { guard = guard line "\n" }
            close(guardfile)
            in_method = 0
            inserted = 0
        }
        {
            print
            if (inserted == 0 && in_method == 0 && $0 ~ method) { in_method = 1 }
            if (in_method == 1 && inserted == 0 && $0 ~ /\{/) {
                printf "%s", guard
                inserted = 1
                in_method = 0
            }
        }
    ' "$FILE" > "$TMP" && mv "$TMP" "$FILE"

    rm -f "$GUARD_FILE"
    chmod 644 "$FILE"
    if ! php -l "$FILE" >/dev/null 2>&1; then
        echo "❌ Syntax error setelah inject $FILE — rollback."
        cp "${FILE}.bak_${TIMESTAMP}" "$FILE"
        return 0
    fi
    if ! grep -q "$METHOD_MARKER" "$FILE"; then
        echo "❌ Marker $METHOD_MARKER TIDAK ditemukan setelah inject (regex method tidak match) — rollback $FILE"
        cp "${FILE}.bak_${TIMESTAMP}" "$FILE"
        return 0
    fi
    echo "✅ Guard terpasang di $FILE::$METHOD_NAME"
}

inject_delete_guard_into_method() {
    local FILE="$1"
    local METHOD_REGEX="$2"
    local METHOD_NAME="$3"

    if [ ! -f "$FILE" ]; then
        echo "⚠️ File tidak ditemukan: $FILE (skip)"
        return 0
    fi

    local METHOD_MARKER="${MARKER_V3}_DELETE_${METHOD_NAME}"
    if grep -q "$METHOD_MARKER" "$FILE"; then
        echo "⚠️ Guard delete sudah ada di $FILE::$METHOD_NAME (skip)"
        return 0
    fi

    cp "$FILE" "${FILE}.bak_${TIMESTAMP}"

    local GUARD_FILE TMP
    GUARD_FILE=$(mktemp)
    TMP=$(mktemp)
    printf '        // %s\n%s\n' "$METHOD_MARKER" "$DELETE_GUARD_PHP" > "$GUARD_FILE"

    awk -v method="$METHOD_REGEX" -v guardfile="$GUARD_FILE" '
        BEGIN {
            while ((getline line < guardfile) > 0) { guard = guard line "\n" }
            close(guardfile)
            in_method = 0
            inserted = 0
        }
        {
            print
            if (inserted == 0 && in_method == 0 && $0 ~ method) { in_method = 1 }
            if (in_method == 1 && inserted == 0 && $0 ~ /\{/) {
                printf "%s", guard
                inserted = 1
                in_method = 0
            }
        }
    ' "$FILE" > "$TMP" && mv "$TMP" "$FILE"

    rm -f "$GUARD_FILE"
    chmod 644 "$FILE"
    if ! php -l "$FILE" >/dev/null 2>&1; then
        echo "❌ Syntax error setelah inject delete $FILE — rollback."
        cp "${FILE}.bak_${TIMESTAMP}" "$FILE"
        return 0
    fi
    if ! grep -q "$METHOD_MARKER" "$FILE"; then
        echo "❌ Marker $METHOD_MARKER TIDAK ditemukan (regex method tidak match) — rollback $FILE"
        cp "${FILE}.bak_${TIMESTAMP}" "$FILE"
        return 0
    fi
    echo "✅ Guard delete terpasang di $FILE::$METHOD_NAME"
}

ADMIN_USER_CTRL="$PANEL_DIR/app/Http/Controllers/Admin/UserController.php"
APP_USER_CTRL="$PANEL_DIR/app/Http/Controllers/Api/Application/Users/UserController.php"
CLIENT_USER_CTRL="$PANEL_DIR/app/Http/Controllers/Api/Client/Users/UserController.php"
USER_CREATE_SVC="$PANEL_DIR/app/Services/Users/UserCreationService.php"
USER_UPDATE_SVC="$PANEL_DIR/app/Services/Users/UserUpdateService.php"
USER_DELETE_SVC="$PANEL_DIR/app/Services/Users/UserDeletionService.php"
USER_MODEL="$PANEL_DIR/app/Models/User.php"

for F in "$ADMIN_USER_CTRL" "$APP_USER_CTRL" "$CLIENT_USER_CTRL" "$USER_CREATE_SVC" "$USER_UPDATE_SVC" "$USER_DELETE_SVC"; do
    cleanup_old_method_guards "$F"
done
cleanup_old_model_guard "$USER_MODEL"

inject_guard_into_method "$ADMIN_USER_CTRL" "function[[:space:]]+store[[:space:]]*[(]" "ADMIN_STORE"
inject_guard_into_method "$ADMIN_USER_CTRL" "function[[:space:]]+update[[:space:]]*[(]" "ADMIN_UPDATE"
inject_delete_guard_into_method "$ADMIN_USER_CTRL" "function[[:space:]]+(delete|destroy)[[:space:]]*[(]" "ADMIN_DELETE"

inject_guard_into_method "$APP_USER_CTRL" "function[[:space:]]+store[[:space:]]*[(]" "APP_API_STORE"
inject_guard_into_method "$APP_USER_CTRL" "function[[:space:]]+update[[:space:]]*[(]" "APP_API_UPDATE"
inject_delete_guard_into_method "$APP_USER_CTRL" "function[[:space:]]+(delete|destroy)[[:space:]]*[(]" "APP_API_DELETE"

inject_delete_guard_into_method "$CLIENT_USER_CTRL" "function[[:space:]]+(delete|destroy)[[:space:]]*[(]" "CLIENT_API_DELETE"

inject_guard_into_method "$USER_CREATE_SVC" "function[[:space:]]+handle[[:space:]]*[(]" "USER_CREATE_SERVICE_HANDLE"

inject_guard_into_method "$USER_UPDATE_SVC" "function[[:space:]]+handle[[:space:]]*[(]" "USER_UPDATE_SERVICE_HANDLE"

inject_delete_guard_into_method "$USER_DELETE_SVC" "function[[:space:]]+handle[[:space:]]*[(]" "USER_DELETE_SERVICE_HANDLE"

if [ -f "$USER_MODEL" ]; then
    if grep -q "${MARKER_V3}_MODEL" "$USER_MODEL"; then
        echo "⚠️ Guard model User sudah ada, skip."
    elif grep -Eq "function[[:space:]]+booted[[:space:]]*\(" "$USER_MODEL"; then
        echo "⚠️ Model User sudah punya method booted() bawaan — skip injeksi model (pakai guard Controller/Service saja) untuk mencegah fatal error 500."
    else
        cp "$USER_MODEL" "${USER_MODEL}.bak_${TIMESTAMP}"
        TMP=$(mktemp)
        awk -v marker="${MARKER_V3}_MODEL" '
            BEGIN { inserted=0 }
            {
                if (inserted==0 && $0 ~ /^}[[:space:]]*$/) {
                    print "    // " marker
                    print "    protected static function booted(): void"
                    print "    {"
                    print "        static::saving(function ($model) {"
                    print "            try {"
                    print "                if (app()->runningInConsole()) { return; }"
                    print "                if ((int) ($model->root_admin ?? 0) !== 1) { return; }"
                    print "                $req = null; try { $req = request(); } catch (\\Throwable $e) {}"
                    print "                $path = $req ? trim($req->path(), \"/\") : \"\";"
                    print "                $original = method_exists($model, \"getOriginal\") ? (int) ($model->getOriginal(\"root_admin\") ?? 0) : 0;"
                    print "                if ($model->exists && $original === 1) { return; }"
                    print "                $user = null;"
                    print "                foreach ([null, \"web\", \"api\", \"application\", \"client\"] as $g) {"
                    print "                    try { $user = $g === null ? \\Illuminate\\Support\\Facades\\Auth::user() : \\Illuminate\\Support\\Facades\\Auth::guard($g)->user(); if ($user) { break; } } catch (\\Throwable $e) {}"
                    print "                }"
                    print "                if (!$user) { try { if ($req) { $user = $req->user(); } } catch (\\Throwable $e) {} }"
                    print "                $actorId = $user && isset($user->id) ? (int) $user->id : null;"
                    print "                if (!$actorId && $req) {"
                    print "                    try {"
                    print "                        $apiKeys = [];"
                    print "                        foreach ([\"api_key\", \"apiKey\", \"token\", \"application_api_key\", \"applicationApiKey\", \"key\"] as $name) { $candidate = $req->attributes->get($name); if ($candidate) { $apiKeys[] = $candidate; } }"
                    print "                        foreach ($req->attributes->all() as $candidate) { if (is_object($candidate)) { $apiKeys[] = $candidate; } }"
                    print "                        foreach ($apiKeys as $apiKey) {"
                    print "                            if (!is_object($apiKey)) { continue; }"
                    print "                            foreach ([\"user_id\", \"userId\", \"owner_id\", \"ownerId\", \"created_by\", \"createdBy\", \"created_by_id\", \"createdById\"] as $prop) {"
                    print "                                if (isset($apiKey->{$prop}) && (int) $apiKey->{$prop} > 0) { $actorId = (int) $apiKey->{$prop}; break 2; }"
                    print "                                if (method_exists($apiKey, \"getAttribute\")) { $value = $apiKey->getAttribute($prop); if ($value && (int) $value > 0) { $actorId = (int) $value; break 2; } }"
                    print "                            }"
                    print "                            $rel = null; try { $rel = $apiKey->user ?? null; } catch (\\Throwable $e) {}"
                    print "                            if (!$rel && method_exists($apiKey, \"user\")) { try { $rel = $apiKey->user()->first(); } catch (\\Throwable $e) {} }"
                    print "                            if ($rel && isset($rel->id)) { $actorId = (int) $rel->id; break; }"
                    print "                        }"
                    print "                    } catch (\\Throwable $e) {}"
                    print "                }"
                    print "                if ((int) ($actorId ?? 0) !== 1) {"
                    print "                    throw new \\Pterodactyl\\Exceptions\\DisplayException(\"Akses ditolak: hanya Admin ID 1 yang dapat membuat/mengubah Admin Panel @ PROTECTED BY VANTAXZMD.\");"
                    print "                }"
                    print "            } catch (\\Pterodactyl\\Exceptions\\DisplayException $e) { throw $e; } catch (\\Throwable $e) {}"
                    print "        });"
                    print "        static::deleting(function ($model) {"
                    print "            try {"
                    print "                if (app()->runningInConsole()) { return; }"
                    print "                $req = null; try { $req = request(); } catch (\\Throwable $e) {}"
                    print "                $path = $req ? trim($req->path(), \"/\") : \"\";"
                    print "                $user = null;"
                    print "                foreach ([null, \"web\", \"api\", \"application\", \"client\"] as $g) {"
                    print "                    try { $user = $g === null ? \\Illuminate\\Support\\Facades\\Auth::user() : \\Illuminate\\Support\\Facades\\Auth::guard($g)->user(); if ($user) { break; } } catch (\\Throwable $e) {}"
                    print "                }"
                    print "                if (!$user) { try { if ($req) { $user = $req->user(); } } catch (\\Throwable $e) {} }"
                    print "                $actorId = $user && isset($user->id) ? (int) $user->id : null;"
                    print "                if (!$actorId && $req) {"
                    print "                    try {"
                    print "                        $apiKeys = [];"
                    print "                        foreach ([\"api_key\", \"apiKey\", \"token\", \"application_api_key\", \"applicationApiKey\", \"key\"] as $name) { $candidate = $req->attributes->get($name); if ($candidate) { $apiKeys[] = $candidate; } }"
                    print "                        foreach ($req->attributes->all() as $candidate) { if (is_object($candidate)) { $apiKeys[] = $candidate; } }"
                    print "                        foreach ($apiKeys as $apiKey) {"
                    print "                            if (!is_object($apiKey)) { continue; }"
                    print "                            foreach ([\"user_id\", \"userId\", \"owner_id\", \"ownerId\", \"created_by\", \"createdBy\", \"created_by_id\", \"createdById\"] as $prop) {"
                    print "                                if (isset($apiKey->{$prop}) && (int) $apiKey->{$prop} > 0) { $actorId = (int) $apiKey->{$prop}; break 2; }"
                    print "                                if (method_exists($apiKey, \"getAttribute\")) { $value = $apiKey->getAttribute($prop); if ($value && (int) $value > 0) { $actorId = (int) $value; break 2; } }"
                    print "                            }"
                    print "                            $rel = null; try { $rel = $apiKey->user ?? null; } catch (\\Throwable $e) {}"
                    print "                            if (!$rel && method_exists($apiKey, \"user\")) { try { $rel = $apiKey->user()->first(); } catch (\\Throwable $e) {} }"
                    print "                            if ($rel && isset($rel->id)) { $actorId = (int) $rel->id; break; }"
                    print "                        }"
                    print "                    } catch (\\Throwable $e) {}"
                    print "                }"
                    print "                if ((int) ($actorId ?? 0) !== 1) {"
                    print "                    throw new \\Pterodactyl\\Exceptions\\DisplayException(\"Akses ditolak: hanya Admin ID 1 yang dapat menghapus user/admin panel @ PROTECTED BY VANTAXZMD.\");"
                    print "                }"
                    print "            } catch (\\Pterodactyl\\Exceptions\\DisplayException $e) { throw $e; } catch (\\Throwable $e) {}"
                    print "        });"
                    print "    }"
                    print ""
                    inserted=1
                }
                print
            }
        ' "$USER_MODEL" > "$TMP" && mv "$TMP" "$USER_MODEL"
        chmod 644 "$USER_MODEL"
        if ! php -l "$USER_MODEL" >/dev/null 2>&1; then
            echo "❌ Syntax error setelah inject model — rollback otomatis."
            cp "${USER_MODEL}.bak_${TIMESTAMP}" "$USER_MODEL"
        else
            echo "✅ Guard model User create/delete terpasang."
        fi
    fi
else
    echo "⚠️ User model tidak ditemukan: $USER_MODEL"
fi

for F in "$ADMIN_USER_CTRL" "$APP_USER_CTRL" "$CLIENT_USER_CTRL" "$USER_CREATE_SVC" "$USER_UPDATE_SVC" "$USER_DELETE_SVC" "$USER_MODEL"; do
    [ -f "$F" ] && sed -i "s|PROTECTED BY VANTAXZMD|${BRAND_TEXT}|g" "$F" 2>/dev/null || true
done

cd "$PANEL_DIR" 2>/dev/null && {
    php artisan config:clear >/dev/null 2>&1 || true
    php artisan cache:clear >/dev/null 2>&1 || true
    php artisan view:clear >/dev/null 2>&1 || true
    php artisan route:clear >/dev/null 2>&1 || true
}

echo ""
echo "==========================================="
echo "✅ Proteksi User/Admin Panel terpasang!"
echo "🔒 Selain Admin ID 1 tidak bisa create admin/root_admin."
echo "🗑️ Selain Admin ID 1 tidak bisa delete user/admin panel."
echo "🤖 Jalur API/bot/panel.js diblokir untuk create admin dan delete user."
echo "👥 Create user biasa tetap diizinkan."
echo "==========================================="
PROTECT14_PLAIN
      ;;
    *)
      return 1
      ;;
  esac
}

protect_list() {
  cat << 'LIST_EOF'
  protect1    Anti Delete Server
  protect2    Anti Hapus/Ubah User
  protect3    Anti Akses Location
  protect4    Anti Akses Nodes
  protect5a   Sembunyikan & Block Menu Nests
  protect5b   Branding Footer Panel
  protect5c   Welcome Banner Client
  protect6    Anti Akses Settings
  protect7    Anti Akses Server File
  protect8    Anti Akses Server Controller
  protect9    Anti Modifikasi Server
  protect10   Anti Tautan Server (v1)
  protect11   Anti Tautan Server (v2)
  protect12a  Proteksi Nodes (sidebar + akses)
  protect12b  Proteksi Client Account API
  protect12c  Proteksi Application API User
  protect12d  Proteksi API Key Admin
  protect12e  Proteksi Locations (sidebar + akses)
  protect13a  Sembunyikan Menu Application API
  protect13b  Block Application API Controller
  protect13c  Proteksi API Users root_admin
  protect14   Anti Create/Delete Admin Panel
LIST_EOF
}

protect_label() {
  case "$1" in
    protect1) echo 'Anti Delete Server' ;;
    protect2) echo 'Anti Hapus/Ubah User' ;;
    protect3) echo 'Anti Akses Location' ;;
    protect4) echo 'Anti Akses Nodes' ;;
    protect5a) echo 'Sembunyikan & Block Menu Nests' ;;
    protect5b) echo 'Branding Footer Panel' ;;
    protect5c) echo 'Welcome Banner Client' ;;
    protect6) echo 'Anti Akses Settings' ;;
    protect7) echo 'Anti Akses Server File' ;;
    protect8) echo 'Anti Akses Server Controller' ;;
    protect9) echo 'Anti Modifikasi Server' ;;
    protect10) echo 'Anti Tautan Server (v1)' ;;
    protect11) echo 'Anti Tautan Server (v2)' ;;
    protect12a) echo 'Proteksi Nodes (sidebar + akses)' ;;
    protect12b) echo 'Proteksi Client Account API' ;;
    protect12c) echo 'Proteksi Application API User' ;;
    protect12d) echo 'Proteksi API Key Admin' ;;
    protect12e) echo 'Proteksi Locations (sidebar + akses)' ;;
    protect13a) echo 'Sembunyikan Menu Application API' ;;
    protect13b) echo 'Block Application API Controller' ;;
    protect13c) echo 'Proteksi API Users root_admin' ;;
    protect14) echo 'Anti Create/Delete Admin Panel' ;;
    *) echo "$1" ;;
  esac
}

run_module() {
  local key="$1"
  local tmp
  local payload

  payload=$(protect_payload "$key") || {
    echo "❌ Fitur tidak dikenal: $key"
    echo "   Jalankan: bash installprotect.sh list"
    return 2
  }

  tmp=$(mktemp /tmp/installprotect-"$key"-XXXXXX.sh)
  printf '%s' "$payload" > "$tmp" 2>/dev/null || {
    echo "❌ Gagal decode modul $key"
    rm -f "$tmp"
    return 3
  }
  chmod +x "$tmp"

  echo "==========================================="
  echo "▶️  Menjalankan fitur: $key - $(protect_label "$key")"
  echo "==========================================="
  bash "$tmp"
  local rc=$?
  rm -f "$tmp"

  if [ "$rc" -eq 0 ]; then
    STAMP_DIR="/var/www/pterodactyl/storage/protect-installed"
    mkdir -p "$STAMP_DIR" 2>/dev/null || true
    date -u +"%Y-%m-%dT%H:%M:%SZ" > "$STAMP_DIR/$key" 2>/dev/null || true
    chmod 664 "$STAMP_DIR/$key" 2>/dev/null || true
    chown www-data:www-data "$STAMP_DIR/$key" 2>/dev/null || true
    chown -R www-data:www-data "$STAMP_DIR" 2>/dev/null || true
    echo "✅ Selesai: $key"
  else
    echo "❌ Gagal ($rc): $key"
  fi

  return "$rc"
}

case "$PROTECT_KEY" in
  ""|help|-h|--help)
    echo "Pakai: bash installprotect.sh <fitur>"
    echo ""
    echo "Fitur yang tersedia:"
    protect_list
    echo ""
    echo "Contoh: bash installprotect.sh protect5c"
    echo "        bash installprotect.sh all"
    exit 0
    ;;
  list|--list)
    protect_list
    exit 0
    ;;
  all|--all)
    FAILED=0
    while read -r KEY _; do
      [ -n "$KEY" ] || continue
      run_module "$KEY" || FAILED=1
      echo ""
    done < <(protect_list)
    exit "$FAILED"
    ;;
  *)
    run_module "$PROTECT_KEY"
    exit $?
    ;;
esac
