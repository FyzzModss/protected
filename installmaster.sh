#!/bin/bash
# ============================================
# installmaster.sh
# Master Installer: Inject Protect Manager ke Pterodactyl Admin Panel
# Menambahkan sidebar menu + halaman untuk install/uninstall proteksi
# Hanya tampil untuk Admin ID 1
# ============================================

set -e

PANEL_DIR="/var/www/pterodactyl"
TIMESTAMP=$(date +%Y-%m-%d-%H-%M-%S)
SCRIPTS_DIR="$PANEL_DIR/storage/app/protect-scripts"
CONFIG_FILE="$PANEL_DIR/storage/app/protect-config.json"
CONTROLLER_PATH="$PANEL_DIR/app/Http/Controllers/Admin/ProtectManagerController.php"
VIEW_PATH="$PANEL_DIR/resources/views/admin/protect-manager.blade.php"

echo "==========================================="
echo "🛡️  MASTER INSTALLER: Protect Manager Panel"
echo "==========================================="
echo ""
echo "📦 Membuat halaman Protect Manager di Admin Panel"
echo "📦 Sidebar hanya tampil untuk Admin ID 1"
echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# BAGIAN 1: Buat direktori dan config
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📁 BAGIAN 1: Setup direktori & konfigurasi"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

mkdir -p "$SCRIPTS_DIR"
chown -R www-data:www-data "$SCRIPTS_DIR" 2>/dev/null || true
chmod 775 "$SCRIPTS_DIR"

# Sumber script: API (butuh API key) dengan fallback ke GitHub.
# API key bisa diberikan lewat env PROTECT_API_KEY sebelum menjalankan installer:
#   PROTECT_API_KEY="jhy_xxx" bash installmaster.sh
API_BASE="${PROTECT_API_BASE:-https://hzgavthvdnlrihdrigyt.supabase.co/functions/v1/download}"
PROTECT_API_KEY="${PROTECT_API_KEY:-}"
GITHUB_URL="${GITHUB_URL:-https://raw.githubusercontent.com/danangvalentp/protect-panel/refs/heads/main}"
CACHE_BUSTER="$(date +%s)"

# Simpan API key agar Protect Manager bisa memakainya lagi saat update.
if [ -n "$PROTECT_API_KEY" ]; then
    echo "$PROTECT_API_KEY" > "$SCRIPTS_DIR/.protect_api_key"
    chmod 600 "$SCRIPTS_DIR/.protect_api_key" 2>/dev/null || true
elif [ -f "$SCRIPTS_DIR/.protect_api_key" ]; then
    PROTECT_API_KEY="$(cat "$SCRIPTS_DIR/.protect_api_key" 2>/dev/null)"
fi

# Validator: file hasil download harus diawali shebang `#!`.
# Kalau isinya HTML (mis. halaman auth), tolak.
is_valid_script() {
    local f="$1"
    [ -s "$f" ] || return 1
    local head
    head="$(head -c 2 "$f" 2>/dev/null)"
    [ "$head" = "#!" ] || return 1
    # Pastikan tidak mengandung tag HTML di awal file
    if head -c 4096 "$f" 2>/dev/null | grep -qiE '<(html|head|body|!doctype)'; then
        return 1
    fi
    return 0
}

download_script_file() {
    # $1 = nama file, $2 = tujuan
    local name="$1" dest="$2"
    if [ -n "$PROTECT_API_KEY" ]; then
        curl -fsSL --retry 2 --retry-delay 2 \
            -H "X-API-Key: ${PROTECT_API_KEY}" \
            -H 'Cache-Control: no-cache' -H 'Pragma: no-cache' \
            -o "$dest" "${API_BASE}?file=${name}&v=${CACHE_BUSTER}" 2>/dev/null && return 0
    fi
    curl -fsSL --retry 2 --retry-delay 2 \
        -H 'Cache-Control: no-cache' -H 'Pragma: no-cache' \
        -o "$dest" "${GITHUB_URL%/}/${name}?v=${CACHE_BUSTER}" 2>/dev/null
}

if [ -n "$PROTECT_API_KEY" ]; then
    echo "📥 Mendownload installprotect.sh via API key..."
else
    echo "📥 Mendownload installprotect.sh dari GitHub (tanpa API key)..."
fi
TARGET="$SCRIPTS_DIR/installprotect.sh"
DOWNLOADED=false
for attempt in 1 2 3; do
    if download_script_file "installprotect.sh" "$TARGET"; then
        if is_valid_script "$TARGET" && grep -q "protect5c)" "$TARGET"; then
            chmod +x "$TARGET"
            echo "   ✅ installprotect.sh (semua fitur dalam 1 file)"
            DOWNLOADED=true
            break
        fi
        echo "   ⚠️ Konten installprotect.sh tidak valid/versi lama, coba ulang..."
        rm -f "$TARGET"
    fi
    echo "   ⏳ Retry ${attempt}/3 untuk installprotect.sh..."
    sleep 2
done

if [ "$DOWNLOADED" = false ]; then
    rm -f "$TARGET"
    echo "   ❌ Gagal download installprotect.sh."
    echo "      Pastikan PROTECT_API_KEY benar & aktif, atau repo GitHub bisa diakses."
    exit 1
fi

# Bersihkan script lama per-fitur agar tidak membingungkan
rm -f "$SCRIPTS_DIR"/installprotect[0-9]*.sh 2>/dev/null || true

find "$SCRIPTS_DIR" -type f -name "*.sh" -exec chmod 755 {} \; 2>/dev/null || true

write_bundled_hotfix_script() {
    # GitHub-only mode: jangan pernah menulis fallback/bundle lokal.
    return 0
}

echo "📦 Fallback bundle dimatikan: semua script wajib dari GitHub."
# GitHub-only mode: tidak ada fallback/base64 lokal agar script selalu dari repository utama.

DEFAULT_CONFIG_TMP=$(mktemp)
cat > "$DEFAULT_CONFIG_TMP" << 'CONFIGEOF'
{
    "brand_name": "FyzzModss",
    "brand_text": "Protect By FyzzModss",
    "contact_telegram": "@FyzzModss",
    "contact_telegram_2": "@FyzAbout",
    "brand_label": "FyzzModss",
    "bot_link": "@upgradeuser_bot",
    "welcome_title": "Welcome To Server FyzzModss",
    "welcome_message": "Butuh panel legal yang anti mokad? langsung aja ke <a href=\"https://t.me/upgradeuser_bot\">@upgradeuser_bot</a>. Jangan Lupa join Channel <a href=\"https://t.me/FyzAbout\">@FyzAbout</a>.",
    "protections": {
        "protect1": {
            "name": "Anti Delete Server",
            "description": "Mencegah penghapusan server oleh admin selain ID 1",
            "marker": "PROTEKSI_FIT",
            "target_file": "app/Services/Servers/ServerDeletionService.php",
            "enabled": false
        },
        "protect2": {
            "name": "Anti Hapus/Ubah User",
            "description": "Melindungi data user dari penghapusan dan modifikasi oleh admin lain",
            "marker": "PROTEKSI_FIT",
            "target_file": "app/Http/Controllers/Admin/UserController.php",
            "enabled": false
        },
        "protect3": {
            "name": "Anti Akses Location",
            "description": "Memblokir akses menu Location untuk admin selain ID 1",
            "marker": "PROTEKSI_FIT",
            "target_file": "app/Http/Controllers/Admin/LocationController.php",
            "enabled": false
        },
        "protect4": {
            "name": "Anti Akses Nodes",
            "description": "Memblokir akses menu Nodes untuk admin selain ID 1",
            "marker": "PROTEKSI_FIT",
            "target_file": "app/Http/Controllers/Admin/Nodes/NodeController.php",
            "enabled": false
        },
        "protect5a": {
            "name": "Sembunyikan & Block Menu Nests",
            "description": "Sembunyikan menu Nests dari sidebar dan blokir akses Nest/Egg controller selain ID 1",
            "marker": "PROTEKSI_FIT",
            "target_file": "app/Http/Controllers/Admin/Nests/NestController.php",
            "extra_files": [
                "app/Http/Controllers/Admin/Nests/EggController.php",
                "resources/views/partials/admin/sidebar.blade.php"
            ],
            "enabled": false
        },
        "protect5b": {
            "name": "Branding Footer Panel",
            "description": "Pasang footer branding + ubah judul panel di layout admin",
            "marker": "BRANDING_FIT",
            "target_file": "resources/views/layouts/admin.blade.php",
            "extra_files": [
                "resources/views/layouts/app.blade.php"
            ],
            "enabled": false
        },
        "protect5c": {
            "name": "Welcome Banner Client",
            "description": "Tampilkan welcome banner di dashboard client",
            "marker": "WELCOME_FIT",
            "target_file": "resources/views/templates/wrapper.blade.php",
            "extra_files": [
                "resources/views/layouts/master.blade.php"
            ],
            "enabled": false
        },
        "protect6": {
            "name": "Anti Akses Settings",
            "description": "Memblokir akses Settings panel untuk admin selain ID 1",
            "marker": "PROTEKSI_FIT",
            "target_file": "app/Http/Controllers/Admin/Settings/IndexController.php",
            "enabled": false
        },
        "protect7": {
            "name": "Anti Akses Server File",
            "description": "Proteksi file controller server dari akses tidak sah",
            "marker": "PROTEKSI_FIT",
            "target_file": "app/Http/Controllers/Api/Client/Servers/FileController.php",
            "enabled": false
        },
        "protect8": {
            "name": "Anti Akses Server Controller",
            "description": "Proteksi server controller dari akses tidak sah",
            "marker": "PROTEKSI_FIT",
            "target_file": "app/Http/Controllers/Api/Client/Servers/ServerController.php",
            "enabled": false
        },
        "protect9": {
            "name": "Anti Modifikasi Server",
            "description": "Mencegah modifikasi detail server oleh admin lain",
            "marker": "PROTEKSI_FIT",
            "target_file": "app/Services/Servers/DetailsModificationService.php",
            "enabled": false
        },
        "protect10": {
            "name": "Anti Tautan Server (v1)",
            "description": "Mencegah perubahan tautan/link server di admin panel",
            "marker": "PROTEKSI_FIT",
            "target_file": "resources/views/admin/servers/index.blade.php",
            "enabled": false
        },
        "protect11": {
            "name": "Anti Tautan Server (v2)",
            "description": "Versi lanjutan proteksi tautan server",
            "marker": "PROTEKSI_FIT",
            "target_file": "resources/views/admin/servers/index.blade.php",
            "enabled": false
        },
        "protect12a": {
            "name": "Proteksi Nodes (Sidebar + Akses)",
            "description": "Sembunyikan menu Nodes dari sidebar dan blokir akses halaman Nodes selain ID 1",
            "marker": "PROTEKSI_FIT",
            "target_file": "app/Http/Controllers/Admin/Nodes/NodeController.php",
            "enabled": false
        },
        "protect12b": {
            "name": "Proteksi Client Account API",
            "description": "Blokir ubah password/email admin ID 1 lewat Client API",
            "marker": "PROTEKSI_FIT_ACCOUNT",
            "target_file": "app/Http/Controllers/Api/Client/AccountController.php",
            "enabled": false
        },
        "protect12c": {
            "name": "Proteksi Application API User",
            "description": "Blokir akses/ubah data admin ID 1 lewat Application API (form request + middleware)",
            "marker": "PROTEKSI_FIT_APPUSER",
            "target_file": "app/Http/Controllers/Api/Application/Users/UserController.php",
            "enabled": false
        },
        "protect12d": {
            "name": "Proteksi API Key Admin",
            "description": "Blokir buat/lihat API key atas nama User ID 1",
            "marker": "PROTEKSI_FIT_APIKEY",
            "target_file": "app/Http/Controllers/Admin/ApiController.php",
            "enabled": false
        },
        "protect12e": {
            "name": "Proteksi Locations (Sidebar + Akses)",
            "description": "Sembunyikan menu Locations dari sidebar dan blokir aksesnya selain ID 1",
            "marker": "PROTEKSI_FIT",
            "target_file": "app/Http/Controllers/Admin/LocationController.php",
            "enabled": false
        },
        "protect13a": {
            "name": "Sembunyikan Menu Application API",
            "description": "Sembunyikan menu Application API dari sidebar selain ID 1",
            "marker": "PROTEKSI_FIT_APPAPI_MENU",
            "target_file": "resources/views/layouts/admin.blade.php",
            "enabled": false
        },
        "protect13b": {
            "name": "Block Application API Controller",
            "description": "Blokir akses controller Application API selain ID 1",
            "marker": "PROTEKSI_FIT_APPAPI_BLOCK",
            "target_file": "app/Http/Controllers/Admin/ApiController.php",
            "enabled": false
        },
        "protect13c": {
            "name": "Proteksi API Users root_admin",
            "description": "Cegah non-ID 1 mengubah root_admin via /api/application/users",
            "marker": "PROTEKSI_FIT_API_ROOTADMIN",
            "target_file": "app/Http/Controllers/Api/Application/Users/UserController.php",
            "enabled": false
        },
        "protect14": {
            "name": "Anti Create/Delete Admin Panel",
            "description": "Selain Admin ID 1 tidak bisa create admin/root_admin atau delete user/admin panel; jalur API/bot/panel.js diblokir",
            "marker": "PROTEKSI_FIT_USER_ADMIN_PANEL_GUARD_V3",
            "target_file": "app/Http/Controllers/Admin/UserController.php",
            "enabled": false
        }
    }
}
CONFIGEOF

if [ "${PRESERVE_PROTECT_CONFIG:-0}" = "1" ] && [ -f "$CONFIG_FILE" ]; then
    echo "⚠️ Config lama dipertahankan karena PRESERVE_PROTECT_CONFIG=1"
else
    if [ -f "$CONFIG_FILE" ]; then
        cp "$CONFIG_FILE" "${CONFIG_FILE}.bak_${TIMESTAMP}" 2>/dev/null || true
        echo "📦 Backup config lama: ${CONFIG_FILE}.bak_${TIMESTAMP}"
        echo "🧹 Config lama di-reset agar banner/settings versi lama tidak kebawa saat reinstall."
    fi
    cp "$DEFAULT_CONFIG_TMP" "$CONFIG_FILE"
    echo "✅ Config default versi terbaru ditulis: $CONFIG_FILE"
fi
rm -f "$DEFAULT_CONFIG_TMP"

chown www-data:www-data "$CONFIG_FILE" 2>/dev/null || true
chmod 664 "$CONFIG_FILE"
chown -R www-data:www-data "$SCRIPTS_DIR" 2>/dev/null || true
find "$SCRIPTS_DIR" -type d -exec chmod 775 {} \; 2>/dev/null || true
find "$SCRIPTS_DIR" -type f -name "*.sh" -exec chmod 755 {} \; 2>/dev/null || true

# Fix permission semua layout/view files agar www-data bisa menulis
echo "🔧 Fixing permissions pada layout files..."
LAYOUT_TARGETS=(
  "$PANEL_DIR/resources/views/layouts/admin.blade.php"
  "$PANEL_DIR/resources/views/layouts/app.blade.php"
  "$PANEL_DIR/resources/views/layouts/master.blade.php"
  "$PANEL_DIR/resources/views/layouts/auth.blade.php"
  "$PANEL_DIR/resources/views/templates/wrapper.blade.php"
  "$PANEL_DIR/resources/views/partials/admin/sidebar.blade.php"
)
for LF in "${LAYOUT_TARGETS[@]}"; do
  if [ -f "$LF" ]; then
    chown www-data:www-data "$LF" 2>/dev/null || true
    chmod 664 "$LF" 2>/dev/null || true
    echo "   ✅ $(basename "$LF")"
  fi
done
# Juga fix permission pada views directory secara rekursif
chown -R www-data:www-data "$PANEL_DIR/resources/views/" 2>/dev/null || true
find "$PANEL_DIR/resources/views/" -type f -name "*.blade.php" -exec chmod 664 {} \; 2>/dev/null || true
find "$PANEL_DIR/resources/views/" -type d -exec chmod 775 {} \; 2>/dev/null || true
echo "✅ Semua layout files sekarang writable oleh www-data"

# Setup sudoers agar www-data bisa jalankan script proteksi sebagai root
SUDOERS_FILE="/etc/sudoers.d/pterodactyl-protect"
if [ ! -f "$SUDOERS_FILE" ] || ! grep -q "/usr/bin/cp" "$SUDOERS_FILE" 2>/dev/null; then
  echo "🔧 Menambahkan sudoers entry untuk www-data..."
  cat > "$SUDOERS_FILE" << 'SUDOEOF'
# Pterodactyl Protect Manager - Allow www-data to run protect scripts and file ops as root
www-data ALL=(root) NOPASSWD: /usr/bin/bash /var/www/pterodactyl/storage/app/protect-scripts/*.sh
www-data ALL=(root) NOPASSWD: /bin/bash /var/www/pterodactyl/storage/app/protect-scripts/*.sh
www-data ALL=(root) NOPASSWD: /usr/bin/bash /var/www/pterodactyl/storage/app/protect-scripts/run-*.sh
www-data ALL=(root) NOPASSWD: /bin/bash /var/www/pterodactyl/storage/app/protect-scripts/run-*.sh
www-data ALL=(root) NOPASSWD: /bin/cp /var/www/pterodactyl/*
www-data ALL=(root) NOPASSWD: /usr/bin/cp /var/www/pterodactyl/*
www-data ALL=(root) NOPASSWD: /bin/chown www-data\:www-data /var/www/pterodactyl/*
www-data ALL=(root) NOPASSWD: /usr/bin/chown www-data\:www-data /var/www/pterodactyl/*
www-data ALL=(root) NOPASSWD: /bin/chmod 664 /var/www/pterodactyl/*
www-data ALL=(root) NOPASSWD: /usr/bin/chmod 664 /var/www/pterodactyl/*
SUDOEOF
  chmod 440 "$SUDOERS_FILE"
  echo "✅ Sudoers entry ditambahkan: $SUDOERS_FILE"
else
  echo "⚠️ Sudoers entry sudah ada, skip..."
fi

echo "✅ BAGIAN 1 SELESAI"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# BAGIAN 2: Buat Controller
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎮 BAGIAN 2: Buat ProtectManagerController"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ -f "$CONTROLLER_PATH" ]; then
    cp "$CONTROLLER_PATH" "${CONTROLLER_PATH}.bak_${TIMESTAMP}"
    echo "💾 Backup controller lama"
fi

cat > "$CONTROLLER_PATH" << 'PHPEOF'
<?php

namespace Pterodactyl\Http\Controllers\Admin;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\File;
use Pterodactyl\Http\Controllers\Controller;

class ProtectManagerController extends Controller
{
    private $configPath;
    private $scriptsDir;
    private $panelDir;
    private $phpBinary;
    private $nohupBinary;

    public function __construct()
    {
        $this->panelDir = base_path();
        $this->configPath = storage_path('app/protect-config.json');
        $this->scriptsDir = storage_path('app/protect-scripts');
        $this->phpBinary = $this->resolveBinary(['PHP_BINARY', '/usr/bin/php', '/usr/local/bin/php', '/bin/php'], 'php');
        $this->nohupBinary = $this->resolveBinary(['/usr/bin/nohup', '/bin/nohup'], 'nohup');
    }

    /**
     * Cari binary absolut agar proses background tidak gagal karena PATH kosong dari PHP-FPM.
     */
    private function resolveBinary(array $candidates, string $fallback): string
    {
        foreach ($candidates as $candidate) {
            if ($candidate === 'PHP_BINARY') {
                if (defined('PHP_BINARY') && PHP_BINARY && @is_executable(PHP_BINARY)) {
                    return PHP_BINARY;
                }

                continue;
            }

            if ($candidate && @is_executable($candidate)) {
                return $candidate;
            }
        }

        return $fallback;
    }

    /**
     * Buat perintah clear cache Laravel yang aman dipanggil dari background.
     */
    private function buildLaravelCacheClearCommand(): string
    {
        return sprintf(
            'cd %s && %s artisan view:clear && %s artisan route:clear && %s artisan config:clear && %s artisan cache:clear',
            escapeshellarg($this->panelDir),
            escapeshellarg($this->phpBinary),
            escapeshellarg($this->phpBinary),
            escapeshellarg($this->phpBinary),
            escapeshellarg($this->phpBinary)
        );
    }

    /**
     * Kompatibilitas Laravel lama: hindari File::ensureDirectoryExists() yang bisa memicu 500.
     */
    private function ensureDirectory(string $path): void
    {
        if ($path === '' || is_dir($path)) {
            return;
        }

        if (!@mkdir($path, 0755, true) && !is_dir($path)) {
            throw new \RuntimeException('Gagal membuat direktori: ' . $path);
        }
    }

    /**
     * Lepas proses ke background dengan binary absolut dan log file supaya tidak silent fail.
     */
    private function launchDetachedPhpJob(string $jobFile, string $logFile): bool
    {
        $this->ensureDirectory(dirname($logFile));

        $launcherFile = $this->scriptsDir . '/launch-bulk-install-' . uniqid() . '.sh';
        $launcherContent = "#!/bin/bash\n"
            . "set -e\n"
            . 'cd ' . escapeshellarg($this->panelDir) . "\n"
            . 'exec ' . escapeshellarg($this->phpBinary) . ' ' . escapeshellarg($jobFile) . ' >> ' . escapeshellarg($logFile) . ' 2>&1' . "\n";

        File::put($launcherFile, $launcherContent);
        @chmod($launcherFile, 0755);

        $command = sprintf(
            '%s /bin/bash %s >/dev/null 2>&1 & echo $!',
            escapeshellarg($this->nohupBinary),
            escapeshellarg($launcherFile)
        );

        $output = [];
        $returnVar = 0;
        exec($command, $output, $returnVar);

        return $returnVar === 0 && !empty($output[0]);
    }

    /**
     * Cek apakah user adalah admin ID 1
     */
    private function authorizeAccess()
    {
        $user = Auth::user();
        if (!$user || (int) $user->id !== 1) {
            abort(403, '🚫 Akses ditolak! Hanya admin ID 1 yang dapat mengakses Protect Manager.');
        }
    }

    /**
     * Cari file sidebar admin yang benar-benar dipakai panel
     */
    private function resolveAdminSidebarFile()
    {
        $candidates = [
            $this->panelDir . '/resources/views/partials/admin/sidebar.blade.php',
            $this->panelDir . '/resources/views/layouts/admin.blade.php',
            $this->panelDir . '/resources/views/layouts/app.blade.php',
            $this->panelDir . '/resources/views/layouts/master.blade.php',
        ];

        foreach ($candidates as $candidate) {
            if (!File::exists($candidate)) {
                continue;
            }

            $content = File::get($candidate);
            if (
                strpos($content, 'admin.settings') !== false
                || strpos($content, 'admin.nests') !== false
                || strpos($content, 'sidebar-menu') !== false
                || strpos($content, 'admin.protect-manager') !== false
            ) {
                return $candidate;
            }
        }

        foreach ($candidates as $candidate) {
            if (File::exists($candidate)) {
                return $candidate;
            }
        }

        return null;
    }

    /**
     * Re-inject sidebar Protect Manager jika hilang (misalnya setelah restore backup)
     */
    private function ensureProtectManagerSidebar()
    {
        $layoutFile = $this->resolveAdminSidebarFile();
        if (!$layoutFile || !File::exists($layoutFile)) {
            return;
        }

        $content = File::get($layoutFile);
        if (strpos($content, 'PROTEKSI_FIT_MASTER_SIDEBAR') !== false) {
            return;
        }

        $sidebarSnippet = "\n" .
            '                {{-- PROTEKSI_FIT_MASTER_SIDEBAR: Protect Manager Menu --}}' . "\n" .
            '                @if(Auth::user() && Auth::user()->id === 1)' . "\n" .
            '                <li class="{{ Route::currentRouteName() === \'admin.protect-manager\' ? \'active\' : \'\' }}">' . "\n" .
            '                    <a href="{{ route(\'admin.protect-manager\') }}">' . "\n" .
            '                        <i class="fa fa-shield"></i> <span>Protect Manager</span>' . "\n" .
            '                    </a>' . "\n" .
            '                </li>' . "\n" .
            '                @endif' . "\n" .
            '                {{-- END PROTEKSI_FIT_MASTER_SIDEBAR --}}';

        $anchorPos = false;
        foreach (['admin.settings', 'Configuration', 'Settings', 'settings'] as $anchor) {
            $candidatePos = stripos($content, $anchor);
            if ($candidatePos !== false) {
                $anchorPos = $candidatePos;
                break;
            }
        }

        if ($anchorPos !== false) {
            $insertPos = strrpos(substr($content, 0, $anchorPos), '<li');
            if ($insertPos !== false) {
                $content = substr($content, 0, $insertPos) . $sidebarSnippet . "\n" . substr($content, $insertPos);
            }
        }

        if (strpos($content, 'PROTEKSI_FIT_MASTER_SIDEBAR') === false) {
            $lastUlPos = strrpos($content, '</ul>');
            if ($lastUlPos === false) {
                return;
            }

            $content = substr($content, 0, $lastUlPos) . $sidebarSnippet . "\n" . substr($content, $lastUlPos);
        }

        File::put($layoutFile, $content);
    }

    /**
     * Baca konfigurasi
     */
    private function getConfig()
    {
        if (!File::exists($this->configPath)) {
            return [
                'protections' => [],
                'brand_name' => 'FyzzModss',
                'brand_text' => 'Protect By FyzzModss',
                'contact_telegram' => '@FyzzModss',
                'contact_telegram_2' => '@FyzAbout',
                'brand_label' => 'FyzzModss',
                'bot_link' => '@upgradeuser_bot',
                'welcome_title' => 'Welcome To Server FyzzModss',
                'welcome_message' => 'Butuh panel legal yang anti mokad? langsung aja ke <a href=\"https://t.me/upgradeuser_bot\">@upgradeuser_bot</a>. Jangan Lupa join Channel <a href=\"https://t.me/FyzAbout\">@FyzAbout</a>.',
                'panel_title' => 'FyzzModss',
                'deny_msg_admin' => '',
                'deny_msg_server' => '',
                'deny_msg_file' => '',
                'deny_msg_modify' => '',
            ];
        }
        return json_decode(File::get($this->configPath), true);
    }

    /**
     * Simpan konfigurasi
     */
    private function saveConfig($config)
    {
        File::put($this->configPath, json_encode($config, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE));
    }

    /**
     * Lokasi file status bulk install agar hasil async bisa ditampilkan setelah redirect.
     */
    private function getBulkStatusPath(): string
    {
        return $this->scriptsDir . '/bulk-install-status.json';
    }

    /**
     * Simpan status bulk install.
     */
    private function saveBulkStatus(array $status): void
    {
        $this->ensureDirectory($this->scriptsDir);
        File::put($this->getBulkStatusPath(), json_encode($status, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE));
    }

    /**
     * Ambil status bulk install terakhir.
     */
    private function getBulkStatus(): ?array
    {
        $path = $this->getBulkStatusPath();
        if (!File::exists($path)) {
            return null;
        }

        $decoded = json_decode(File::get($path), true);

        return is_array($decoded) ? $decoded : null;
    }

    /**
     * Hapus status bulk install setelah selesai ditampilkan.
     */
    private function clearBulkStatus(): void
    {
        $path = $this->getBulkStatusPath();
        if (File::exists($path)) {
            @unlink($path);
        }
    }

    /**
     * Batasi output agar session flash tidak meledak dan memicu 500.
     */
    private function normalizeOutput(array $output, int $maxLines = 120, int $maxChars = 12000): string
    {
        $text = trim(implode("\n", array_slice($output, -$maxLines)));

        if ($text === '') {
            return '';
        }

        if (strlen($text) > $maxChars) {
            $text = substr($text, -$maxChars);
            $newlinePos = strpos($text, "\n");
            if ($newlinePos !== false) {
                $text = substr($text, $newlinePos + 1);
            }
            $text = "...[output dipotong agar panel stabil]...\n" . $text;
        }

        return $text;
    }

    /**
     * Jalankan clear cache setelah response selesai agar request aktif tidak 500.
     */
    private function queueLaravelCacheClear(): void
    {
        if (function_exists('register_shutdown_function')) {
            register_shutdown_function(function () {
                @exec($this->buildLaravelCacheClearCommand() . ' >/dev/null 2>&1 &');
            });
        }
    }

    /**
     * Bundle script lokal agar install pertama selalu pakai versi yang konsisten.
     */
    private function getBundledScriptContent(string $filename): ?string
    {
        $bundled = [
            'installprotect1.sh' => <<<'SCRIPT_INSTALLPROTECT1_SH'
IyEvYmluL2Jhc2gKCkJSQU5EX05BTUU9IiR7QlJBTkRfTkFNRTotSmhvbmFsZXkgVGVjaH0iCkJSQU5EX1RFWFQ9IiR7QlJBTkRfVEVYVDotUHJvdGVjdCBCeSBKaG9uYWxleX0iCgpSRU1PVEVfUEFUSD0iL3Zhci93d3cvcHRlcm9kYWN0eWwvYXBwL1NlcnZpY2VzL1NlcnZlcnMvU2VydmVyRGVsZXRpb25TZXJ2aWNlLnBocCIKVElNRVNUQU1QPSQoZGF0ZSAtdSArIiVZLSVtLSVkLSVILSVNLSVTIikKQkFDS1VQX1BBVEg9IiR7UkVNT1RFX1BBVEh9LmJha18ke1RJTUVTVEFNUH0iCgplY2hvICLwn5qAIE1lbWFzYW5nIHByb3Rla3NpIEFudGkgRGVsZXRlIFNlcnZlci4uLiIKCmlmIFsgLWYgIiRSRU1PVEVfUEFUSCIgXTsgdGhlbgogIG12ICIkUkVNT1RFX1BBVEgiICIkQkFDS1VQX1BBVEgiCiAgZWNobyAi8J+TpiBCYWNrdXAgZmlsZSBsYW1hIGRpYnVhdCBkaSAkQkFDS1VQX1BBVEgiCmZpCgpta2RpciAtcCAiJChkaXJuYW1lICIkUkVNT1RFX1BBVEgiKSIKY2htb2QgNzU1ICIkKGRpcm5hbWUgIiRSRU1PVEVfUEFUSCIpIgoKY2F0ID4gIiRSRU1PVEVfUEFUSCIgPDwgJ0VPRicKPD9waHAKCm5hbWVzcGFjZSBQdGVyb2RhY3R5bFxTZXJ2aWNlc1xTZXJ2ZXJzOwoKdXNlIElsbHVtaW5hdGVcU3VwcG9ydFxGYWNhZGVzXEF1dGg7CnVzZSBQdGVyb2RhY3R5bFxFeGNlcHRpb25zXERpc3BsYXlFeGNlcHRpb247CnVzZSBJbGx1bWluYXRlXEh0dHBcUmVzcG9uc2U7CnVzZSBQdGVyb2RhY3R5bFxNb2RlbHNcU2VydmVyOwp1c2UgSWxsdW1pbmF0ZVxTdXBwb3J0XEZhY2FkZXNcTG9nOwp1c2UgSWxsdW1pbmF0ZVxEYXRhYmFzZVxDb25uZWN0aW9uSW50ZXJmYWNlOwp1c2UgUHRlcm9kYWN0eWxcUmVwb3NpdG9yaWVzXFdpbmdzXERhZW1vblNlcnZlclJlcG9zaXRvcnk7CnVzZSBQdGVyb2RhY3R5bFxTZXJ2aWNlc1xEYXRhYmFzZXNcRGF0YWJhc2VNYW5hZ2VtZW50U2VydmljZTsKdXNlIFB0ZXJvZGFjdHlsXEV4Y2VwdGlvbnNcSHR0cFxDb25uZWN0aW9uXERhZW1vbkNvbm5lY3Rpb25FeGNlcHRpb247CgpjbGFzcyBTZXJ2ZXJEZWxldGlvblNlcnZpY2UKewogICAgcHJvdGVjdGVkIGJvb2wgJGZvcmNlID0gZmFsc2U7CgogICAgLyoqCiAgICAgKiBTZXJ2ZXJEZWxldGlvblNlcnZpY2UgY29uc3RydWN0b3IuCiAgICAgKi8KICAgIHB1YmxpYyBmdW5jdGlvbiBfX2NvbnN0cnVjdCgKICAgICAgICBwcml2YXRlIENvbm5lY3Rpb25JbnRlcmZhY2UgJGNvbm5lY3Rpb24sCiAgICAgICAgcHJpdmF0ZSBEYWVtb25TZXJ2ZXJSZXBvc2l0b3J5ICRkYWVtb25TZXJ2ZXJSZXBvc2l0b3J5LAogICAgICAgIHByaXZhdGUgRGF0YWJhc2VNYW5hZ2VtZW50U2VydmljZSAkZGF0YWJhc2VNYW5hZ2VtZW50U2VydmljZQogICAgKSB7CiAgICB9CgogICAgLyoqCiAgICAgKiBTZXQgaWYgdGhlIHNlcnZlciBzaG91bGQgYmUgZm9yY2libHkgZGVsZXRlZCBmcm9tIHRoZSBwYW5lbCAoaWdub3JpbmcgZGFlbW9uIGVycm9ycykgb3Igbm90LgogICAgICovCiAgICBwdWJsaWMgZnVuY3Rpb24gd2l0aEZvcmNlKGJvb2wgJGJvb2wgPSB0cnVlKTogc2VsZgogICAgewogICAgICAgICR0aGlzLT5mb3JjZSA9ICRib29sOwogICAgICAgIHJldHVybiAkdGhpczsKICAgIH0KCiAgICAvKioKICAgICAqIERlbGV0ZSBhIHNlcnZlciBmcm9tIHRoZSBwYW5lbCBhbmQgcmVtb3ZlIGFueSBhc3NvY2lhdGVkIGRhdGFiYXNlcyBmcm9tIGhvc3RzLgogICAgICoKICAgICAqIEB0aHJvd3MgXFRocm93YWJsZQogICAgICogQHRocm93cyBcUHRlcm9kYWN0eWxcRXhjZXB0aW9uc1xEaXNwbGF5RXhjZXB0aW9uCiAgICAgKi8KICAgIHB1YmxpYyBmdW5jdGlvbiBoYW5kbGUoU2VydmVyICRzZXJ2ZXIpOiB2b2lkCiAgICB7CiAgICAgICAgJHVzZXIgPSBBdXRoOjp1c2VyKCk7CgogICAgICAgIC8vIPCflJIgUHJvdGVrc2k6IGhhbnlhIEFkbWluIElEID0gMSBib2xlaCBtZW5naGFwdXMgc2VydmVyIHNpYXBhIHNhamEuCiAgICAgICAgLy8gU2VsYWluIGl0dSwgdXNlciBiaWFzYSBoYW55YSBib2xlaCBtZW5naGFwdXMgc2VydmVyIE1JTElLTllBIFNFTkRJUkkuCiAgICAgICAgLy8gSmlrYSB0aWRhayBhZGEgaW5mb3JtYXNpIHBlbWlsaWsgZGFuIHBlbmdndW5hIGJ1a2FuIGFkbWluLCB0b2xhay4KICAgICAgICBpZiAoJHVzZXIpIHsKICAgICAgICAgICAgaWYgKCR1c2VyLT5pZCAhPT0gMSkgewogICAgICAgICAgICAgICAgLy8gQ29iYSBkZXRla3NpIG93bmVyIGRlbmdhbiBiZWJlcmFwYSBmYWxsYmFjayB5YW5nIHVtdW0uCiAgICAgICAgICAgICAgICAkb3duZXJJZCA9ICRzZXJ2ZXItPm93bmVyX2lkCiAgICAgICAgICAgICAgICAgICAgPz8gJHNlcnZlci0+dXNlcl9pZAogICAgICAgICAgICAgICAgICAgID8/ICgkc2VydmVyLT5vd25lcj8tPmlkID8/IG51bGwpCiAgICAgICAgICAgICAgICAgICAgPz8gKCRzZXJ2ZXItPnVzZXI/LT5pZCA/PyBudWxsKTsKCiAgICAgICAgICAgICAgICBpZiAoJG93bmVySWQgPT09IG51bGwpIHsKICAgICAgICAgICAgICAgICAgICAvLyBUaWRhayBqZWxhcyBzaWFwYSBwZW1pbGlrbnlhIOKAlCBqYW5nYW4gaXppbmthbiBwZW5nZ3VuYSBiaWFzYSBtZW5naGFwdXMuCiAgICAgICAgICAgICAgICAgICAgdGhyb3cgbmV3IERpc3BsYXlFeGNlcHRpb24oJ0Frc2VzIGRpdG9sYWs6IGluZm9ybWFzaSBwZW1pbGlrIHNlcnZlciB0aWRhayB0ZXJzZWRpYS4nKTsKICAgICAgICAgICAgICAgIH0KCiAgICAgICAgICAgICAgICBpZiAoJG93bmVySWQgIT09ICR1c2VyLT5pZCkgewogICAgICAgICAgICAgICAgICAgIHRocm93IG5ldyBEaXNwbGF5RXhjZXB0aW9uKCdBa3NlcyBkaXRvbGFrOiBBbmRhIGhhbnlhIGRhcGF0IG1lbmdoYXB1cyBzZXJ2ZXIgbWlsaWsgQW5kYSBzZW5kaXJpIEAg8J2Qj/CdkJHwnZCO8J2Qk/CdkITwnZCC8J2QkyDwnZCB8J2QmCDwnZCJ8J2Qh/CdkI7wnZCN8J2QgPCdkIvwnZCE8J2QmCDwnZCT8J2QhPCdkILwnZCHLicpOwogICAgICAgICAgICAgICAgfQogICAgICAgICAgICB9CiAgICAgICAgICAgIC8vIGppa2EgJHVzZXItPmlkID09PSAxLCBsYW5qdXRrYW4gKGFkbWluIHN1cGVyKQogICAgICAgIH0KICAgICAgICAvLyBKaWthIHRpZGFrIGFkYSAkdXNlciAobWlzLiBDTEkvYmFja2dyb3VuZCBqb2IpLCBiaWFya2FuIHByb3NlcyBiZXJqYWxhbi4KCiAgICAgICAgdHJ5IHsKICAgICAgICAgICAgJHRoaXMtPmRhZW1vblNlcnZlclJlcG9zaXRvcnktPnNldFNlcnZlcigkc2VydmVyKS0+ZGVsZXRlKCk7CiAgICAgICAgfSBjYXRjaCAoRGFlbW9uQ29ubmVjdGlvbkV4Y2VwdGlvbiAkZXhjZXB0aW9uKSB7CiAgICAgICAgICAgIC8vIEFiYWlrYW4gZXJyb3IgNDA0LCB0YXBpIGxlbXBhciBlcnJvciBsYWluIGppa2EgdGlkYWsgbW9kZSBmb3JjZQogICAgICAgICAgICBpZiAoISR0aGlzLT5mb3JjZSAmJiAkZXhjZXB0aW9uLT5nZXRTdGF0dXNDb2RlKCkgIT09IFJlc3BvbnNlOjpIVFRQX05PVF9GT1VORCkgewogICAgICAgICAgICAgICAgdGhyb3cgJGV4Y2VwdGlvbjsKICAgICAgICAgICAgfQoKICAgICAgICAgICAgTG9nOjp3YXJuaW5nKCRleGNlcHRpb24pOwogICAgICAgIH0KCiAgICAgICAgJHRoaXMtPmNvbm5lY3Rpb24tPnRyYW5zYWN0aW9uKGZ1bmN0aW9uICgpIHVzZSAoJHNlcnZlcikgewogICAgICAgICAgICBmb3JlYWNoICgkc2VydmVyLT5kYXRhYmFzZXMgYXMgJGRhdGFiYXNlKSB7CiAgICAgICAgICAgICAgICB0cnkgewogICAgICAgICAgICAgICAgICAgICR0aGlzLT5kYXRhYmFzZU1hbmFnZW1lbnRTZXJ2aWNlLT5kZWxldGUoJGRhdGFiYXNlKTsKICAgICAgICAgICAgICAgIH0gY2F0Y2ggKFxFeGNlcHRpb24gJGV4Y2VwdGlvbikgewogICAgICAgICAgICAgICAgICAgIGlmICghJHRoaXMtPmZvcmNlKSB7CiAgICAgICAgICAgICAgICAgICAgICAgIHRocm93ICRleGNlcHRpb247CiAgICAgICAgICAgICAgICAgICAgfQoKICAgICAgICAgICAgICAgICAgICAvLyBKaWthIGdhZ2FsIGRlbGV0ZSBkYXRhYmFzZSBkaSBob3N0LCB0ZXRhcCBoYXB1cyBkYXJpIHBhbmVsCiAgICAgICAgICAgICAgICAgICAgJGRhdGFiYXNlLT5kZWxldGUoKTsKICAgICAgICAgICAgICAgICAgICBMb2c6Ondhcm5pbmcoJGV4Y2VwdGlvbik7CiAgICAgICAgICAgICAgICB9CiAgICAgICAgICAgIH0KCiAgICAgICAgICAgICRzZXJ2ZXItPmRlbGV0ZSgpOwogICAgICAgIH0pOwogICAgfQp9CkVPRgoKY2htb2QgNjQ0ICIkUkVNT1RFX1BBVEgiCgojIEFwcGx5IGJyYW5kIGN1c3RvbWl6YXRpb24Kc2VkIC1pICJzfFByb3RlY3QgQnkgSmhvbmFsZXl8JHtCUkFORF9URVhUfXxnIiAiJFJFTU9URV9QQVRIIiAyPi9kZXYvbnVsbCB8fCB0cnVlCnNlZCAtaSAic3xKaG9uYWxleSBUZWNofCR7QlJBTkRfTkFNRX18ZyIgIiRSRU1PVEVfUEFUSCIgMj4vZGV2L251bGwgfHwgdHJ1ZQpzZWQgLWkgInN88J2Qj/CdkJHwnZCO8J2Qk/CdkITwnZCC8J2QkyDwnZCB8J2QmCDwnZCJ8J2Qh/CdkI7wnZCN8J2QgPCdkIvwnZCE8J2QmCDwnZCT8J2QhPCdkILwnZCHfCR7QlJBTkRfVEVYVH18ZyIgIiRSRU1PVEVfUEFUSCIgMj4vZGV2L251bGwgfHwgdHJ1ZQoKZWNobyAi4pyFIFByb3Rla3NpIEFudGkgRGVsZXRlIFNlcnZlciBiZXJoYXNpbCBkaXBhc2FuZyEiCmVjaG8gIvCfk4IgTG9rYXNpIGZpbGU6ICRSRU1PVEVfUEFUSCIKZWNobyAi8J+Xgu+4jyBCYWNrdXAgZmlsZSBsYW1hOiAkQkFDS1VQX1BBVEggKGppa2Egc2ViZWx1bW55YSBhZGEpIgplY2hvICLwn5SSIEhhbnlhIEFkbWluIChJRCAxKSB5YW5nIGJpc2EgaGFwdXMgc2VydmVyIGxhaW4uIgo=
SCRIPT_INSTALLPROTECT1_SH,
            'installprotect2.sh' => <<<'SCRIPT_INSTALLPROTECT2_SH'
IyEvYmluL2Jhc2gKCkJSQU5EX05BTUU9IiR7QlJBTkRfTkFNRTotSmhvbmFsZXkgVGVjaH0iCkJSQU5EX1RFWFQ9IiR7QlJBTkRfVEVYVDotUHJvdGVjdCBCeSBKaG9uYWxleX0iCkNPTlRBQ1RfVEVMRUdSQU09IiR7Q09OVEFDVF9URUxFR1JBTTotQGRhbmFuZ3ZhbGVudHB9IgoKUkVNT1RFX1BBVEg9Ii92YXIvd3d3L3B0ZXJvZGFjdHlsL2FwcC9IdHRwL0NvbnRyb2xsZXJzL0FkbWluL1VzZXJDb250cm9sbGVyLnBocCIKVElNRVNUQU1QPSQoZGF0ZSAtdSArIiVZLSVtLSVkLSVILSVNLSVTIikKQkFDS1VQX1BBVEg9IiR7UkVNT1RFX1BBVEh9LmJha18ke1RJTUVTVEFNUH0iCgplY2hvICLwn5qAIE1lbWFzYW5nIHByb3Rla3NpIFVzZXJDb250cm9sbGVyLnBocCBhbnRpIGhhcHVzIGRhbiBhbnRpIHViYWggZGF0YSB1c2VyLi4uIgoKIyBCYWNrdXAgZmlsZSBsYW1hIGppa2EgYWRhCmlmIFsgLWYgIiRSRU1PVEVfUEFUSCIgXTsgdGhlbgogIG12ICIkUkVNT1RFX1BBVEgiICIkQkFDS1VQX1BBVEgiCiAgZWNobyAi8J+TpiBCYWNrdXAgZmlsZSBsYW1hIGRpYnVhdCBkaSAkQkFDS1VQX1BBVEgiCmZpCgpta2RpciAtcCAiJChkaXJuYW1lICIkUkVNT1RFX1BBVEgiKSIKY2htb2QgNzU1ICIkKGRpcm5hbWUgIiRSRU1PVEVfUEFUSCIpIgoKY2F0ID4gIiRSRU1PVEVfUEFUSCIgPDwnRU9GJwo8P3BocAoKbmFtZXNwYWNlIFB0ZXJvZGFjdHlsXEh0dHBcQ29udHJvbGxlcnNcQWRtaW47Cgp1c2UgSWxsdW1pbmF0ZVxWaWV3XFZpZXc7CnVzZSBJbGx1bWluYXRlXEh0dHBcUmVxdWVzdDsKdXNlIFB0ZXJvZGFjdHlsXE1vZGVsc1xVc2VyOwp1c2UgUHRlcm9kYWN0eWxcTW9kZWxzXE1vZGVsOwp1c2UgSWxsdW1pbmF0ZVxTdXBwb3J0XENvbGxlY3Rpb247CnVzZSBJbGx1bWluYXRlXEh0dHBcUmVkaXJlY3RSZXNwb25zZTsKdXNlIFByb2xvZ3VlXEFsZXJ0c1xBbGVydHNNZXNzYWdlQmFnOwp1c2UgU3BhdGllXFF1ZXJ5QnVpbGRlclxRdWVyeUJ1aWxkZXI7CnVzZSBJbGx1bWluYXRlXFZpZXdcRmFjdG9yeSBhcyBWaWV3RmFjdG9yeTsKdXNlIFB0ZXJvZGFjdHlsXEV4Y2VwdGlvbnNcRGlzcGxheUV4Y2VwdGlvbjsKdXNlIFB0ZXJvZGFjdHlsXEh0dHBcQ29udHJvbGxlcnNcQ29udHJvbGxlcjsKdXNlIElsbHVtaW5hdGVcQ29udHJhY3RzXFRyYW5zbGF0aW9uXFRyYW5zbGF0b3I7CnVzZSBQdGVyb2RhY3R5bFxTZXJ2aWNlc1xVc2Vyc1xVc2VyVXBkYXRlU2VydmljZTsKdXNlIFB0ZXJvZGFjdHlsXFRyYWl0c1xIZWxwZXJzXEF2YWlsYWJsZUxhbmd1YWdlczsKdXNlIFB0ZXJvZGFjdHlsXFNlcnZpY2VzXFVzZXJzXFVzZXJDcmVhdGlvblNlcnZpY2U7CnVzZSBQdGVyb2RhY3R5bFxTZXJ2aWNlc1xVc2Vyc1xVc2VyRGVsZXRpb25TZXJ2aWNlOwp1c2UgUHRlcm9kYWN0eWxcSHR0cFxSZXF1ZXN0c1xBZG1pblxVc2VyRm9ybVJlcXVlc3Q7CnVzZSBQdGVyb2RhY3R5bFxIdHRwXFJlcXVlc3RzXEFkbWluXE5ld1VzZXJGb3JtUmVxdWVzdDsKdXNlIFB0ZXJvZGFjdHlsXENvbnRyYWN0c1xSZXBvc2l0b3J5XFVzZXJSZXBvc2l0b3J5SW50ZXJmYWNlOwpjbGFzcyBVc2VyQ29udHJvbGxlciBleHRlbmRzIENvbnRyb2xsZXIKewogICAgdXNlIEF2YWlsYWJsZUxhbmd1YWdlczsKCiAgICAvKioKICAgICAqIFVzZXJDb250cm9sbGVyIGNvbnN0cnVjdG9yLgogICAgICovCiAgICBwdWJsaWMgZnVuY3Rpb24gX19jb25zdHJ1Y3QoCiAgICAgICAgcHJvdGVjdGVkIEFsZXJ0c01lc3NhZ2VCYWcgJGFsZXJ0LAogICAgICAgIHByb3RlY3RlZCBVc2VyQ3JlYXRpb25TZXJ2aWNlICRjcmVhdGlvblNlcnZpY2UsCiAgICAgICAgcHJvdGVjdGVkIFVzZXJEZWxldGlvblNlcnZpY2UgJGRlbGV0aW9uU2VydmljZSwKICAgICAgICBwcm90ZWN0ZWQgVHJhbnNsYXRvciAkdHJhbnNsYXRvciwKICAgICAgICBwcm90ZWN0ZWQgVXNlclVwZGF0ZVNlcnZpY2UgJHVwZGF0ZVNlcnZpY2UsCiAgICAgICAgcHJvdGVjdGVkIFVzZXJSZXBvc2l0b3J5SW50ZXJmYWNlICRyZXBvc2l0b3J5LAogICAgICAgIHByb3RlY3RlZCBWaWV3RmFjdG9yeSAkdmlldwogICAgKSB7CiAgICB9CgogICAgLyoqCiAgICAgKiBEaXNwbGF5IHVzZXIgaW5kZXggcGFnZS4KICAgICAqLwogICAgcHVibGljIGZ1bmN0aW9uIGluZGV4KFJlcXVlc3QgJHJlcXVlc3QpOiBWaWV3CiAgICB7CiAgICAgICAgLy8g8J+UkiBKaWthIGJ1a2FuIGFkbWluIElEIDEsIHRhbXBpbGthbiBsaXN0IGtvc29uZwogICAgICAgIGlmICgoaW50KSAkcmVxdWVzdC0+dXNlcigpLT5pZCAhPT0gMSkgewogICAgICAgICAgICAkdXNlcnMgPSBVc2VyOjpxdWVyeSgpLT53aGVyZVJhdygnMSA9IDAnKS0+cGFnaW5hdGUoNTApOwogICAgICAgICAgICByZXR1cm4gJHRoaXMtPnZpZXctPm1ha2UoJ2FkbWluLnVzZXJzLmluZGV4JywgWyd1c2VycycgPT4gJHVzZXJzXSk7CiAgICAgICAgfQoKICAgICAgICAkdXNlcnMgPSBRdWVyeUJ1aWxkZXI6OmZvcigKICAgICAgICAgICAgVXNlcjo6cXVlcnkoKS0+c2VsZWN0KCd1c2Vycy4qJykKICAgICAgICAgICAgICAgIC0+c2VsZWN0UmF3KCdDT1VOVChESVNUSU5DVChzdWJ1c2Vycy5pZCkpIGFzIHN1YnVzZXJfb2ZfY291bnQnKQogICAgICAgICAgICAgICAgLT5zZWxlY3RSYXcoJ0NPVU5UKERJU1RJTkNUKHNlcnZlcnMuaWQpKSBhcyBzZXJ2ZXJzX2NvdW50JykKICAgICAgICAgICAgICAgIC0+bGVmdEpvaW4oJ3N1YnVzZXJzJywgJ3N1YnVzZXJzLnVzZXJfaWQnLCAnPScsICd1c2Vycy5pZCcpCiAgICAgICAgICAgICAgICAtPmxlZnRKb2luKCdzZXJ2ZXJzJywgJ3NlcnZlcnMub3duZXJfaWQnLCAnPScsICd1c2Vycy5pZCcpCiAgICAgICAgICAgICAgICAtPmdyb3VwQnkoJ3VzZXJzLmlkJykKICAgICAgICApCiAgICAgICAgICAgIC0+YWxsb3dlZEZpbHRlcnMoWyd1c2VybmFtZScsICdlbWFpbCcsICd1dWlkJ10pCiAgICAgICAgICAgIC0+YWxsb3dlZFNvcnRzKFsnaWQnLCAndXVpZCddKQogICAgICAgICAgICAtPnBhZ2luYXRlKDUwKTsKCiAgICAgICAgcmV0dXJuICR0aGlzLT52aWV3LT5tYWtlKCdhZG1pbi51c2Vycy5pbmRleCcsIFsndXNlcnMnID0+ICR1c2Vyc10pOwogICAgfQoKICAgIC8qKgogICAgICogRGlzcGxheSBuZXcgdXNlciBwYWdlLgogICAgICovCiAgICBwdWJsaWMgZnVuY3Rpb24gY3JlYXRlKCk6IFZpZXcKICAgIHsKICAgICAgICByZXR1cm4gJHRoaXMtPnZpZXctPm1ha2UoJ2FkbWluLnVzZXJzLm5ldycsIFsKICAgICAgICAgICAgJ2xhbmd1YWdlcycgPT4gJHRoaXMtPmdldEF2YWlsYWJsZUxhbmd1YWdlcyh0cnVlKSwKICAgICAgICBdKTsKICAgIH0KCiAgICAvKioKICAgICAqIERpc3BsYXkgdXNlciB2aWV3IHBhZ2UuCiAgICAgKi8KICAgIHB1YmxpYyBmdW5jdGlvbiB2aWV3KFJlcXVlc3QgJHJlcXVlc3QsIFVzZXIgJHVzZXIpOiBWaWV3CiAgICB7CiAgICAgICAgLy8g8J+UkiBIYW55YSBhZG1pbiBJRCAxIHlhbmcgYmlzYSBha3NlcyBoYWxhbWFuIHZpZXcgdXNlcgogICAgICAgIGlmICgoaW50KSAkcmVxdWVzdC0+dXNlcigpLT5pZCAhPT0gMSkgewogICAgICAgICAgICBhYm9ydCg0MDMsICfinJbvuI8gQWtzZXMgZGl0b2xhayAtIHByb3RlY3QgYnkgSmhvbmFsZXkgVGVjaCcpOwogICAgICAgIH0KCiAgICAgICAgcmV0dXJuICR0aGlzLT52aWV3LT5tYWtlKCdhZG1pbi51c2Vycy52aWV3JywgWwogICAgICAgICAgICAndXNlcicgPT4gJHVzZXIsCiAgICAgICAgICAgICdsYW5ndWFnZXMnID0+ICR0aGlzLT5nZXRBdmFpbGFibGVMYW5ndWFnZXModHJ1ZSksCiAgICAgICAgXSk7CiAgICB9CgogICAgLyoqCiAgICAgKiBEZWxldGUgYSB1c2VyIGZyb20gdGhlIHN5c3RlbS4KICAgICAqCiAgICAgKiBAdGhyb3dzIEV4Y2VwdGlvbgogICAgICogQHRocm93cyBQdGVyb2RhY3R5bEV4Y2VwdGlvbnNEaXNwbGF5RXhjZXB0aW9uCiAgICAgKi8KICAgIHB1YmxpYyBmdW5jdGlvbiBkZWxldGUoUmVxdWVzdCAkcmVxdWVzdCwgVXNlciAkdXNlcik6IFJlZGlyZWN0UmVzcG9uc2UKICAgIHsKICAgICAgICAvLyA9PT0gRklUVVIgVEFNQkFIQU46IFByb3Rla3NpIGhhcHVzIHVzZXIgPT09CiAgICAgICAgaWYgKChpbnQpICRyZXF1ZXN0LT51c2VyKCktPmlkICE9PSAxKSB7CiAgICAgICAgICAgIHRocm93IG5ldyBEaXNwbGF5RXhjZXB0aW9uKCLinYwg8J2WuvCdl4TwnZeM8J2WvvCdl4wg8J2WvfCdl4LwnZeN8J2XiPCdl4XwnZa68J2XhCDwnZeJ8J2Xi/Cdl4jwnZeN8J2WvvCdlrzwnZeNIPCdlrvwnZeSIEpob25hbGV5IFRlY2giKTsKICAgICAgICB9CiAgICAgICAgLy8gPT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT0KCiAgICAgICAgaWYgKCRyZXF1ZXN0LT51c2VyKCktPmlkID09PSAkdXNlci0+aWQpIHsKICAgICAgICAgICAgdGhyb3cgbmV3IERpc3BsYXlFeGNlcHRpb24oJHRoaXMtPnRyYW5zbGF0b3ItPmdldCgnYWRtaW4vdXNlci5leGNlcHRpb25zLnVzZXJfaGFzX3NlcnZlcnMnKSk7CiAgICAgICAgfQoKICAgICAgICAkdGhpcy0+ZGVsZXRpb25TZXJ2aWNlLT5oYW5kbGUoJHVzZXIpOwoKICAgICAgICByZXR1cm4gcmVkaXJlY3QoKS0+cm91dGUoJ2FkbWluLnVzZXJzJyk7CiAgICB9CgogICAgLyoqCiAgICAgKiBDcmVhdGUgYSB1c2VyLgogICAgICoKICAgICAqIEB0aHJvd3MgRXhjZXB0aW9uCiAgICAgKiBAdGhyb3dzIFRocm93YWJsZQogICAgICovCiAgICBwdWJsaWMgZnVuY3Rpb24gc3RvcmUoTmV3VXNlckZvcm1SZXF1ZXN0ICRyZXF1ZXN0KTogUmVkaXJlY3RSZXNwb25zZQogICAgewogICAgICAgICR1c2VyID0gJHRoaXMtPmNyZWF0aW9uU2VydmljZS0+aGFuZGxlKCRyZXF1ZXN0LT5ub3JtYWxpemUoKSk7CiAgICAgICAgJHRoaXMtPmFsZXJ0LT5zdWNjZXNzKCR0aGlzLT50cmFuc2xhdG9yLT5nZXQoJ2FkbWluL3VzZXIubm90aWNlcy5hY2NvdW50X2NyZWF0ZWQnKSktPmZsYXNoKCk7CgogICAgICAgIHJldHVybiByZWRpcmVjdCgpLT5yb3V0ZSgnYWRtaW4udXNlcnMudmlldycsICR1c2VyLT5pZCk7CiAgICB9CgogICAgLyoqCiAgICAgKiBVcGRhdGUgYSB1c2VyIG9uIHRoZSBzeXN0ZW0uCiAgICAgKgogICAgICogQHRocm93cyBQdGVyb2RhY3R5bEV4Y2VwdGlvbnNNb2RlbERhdGFWYWxpZGF0aW9uRXhjZXB0aW9uCiAgICAgKiBAdGhyb3dzIFB0ZXJvZGFjdHlsRXhjZXB0aW9uc1JlcG9zaXRvcnlSZWNvcmROb3RGb3VuZEV4Y2VwdGlvbgogICAgICovCiAgICBwdWJsaWMgZnVuY3Rpb24gdXBkYXRlKFVzZXJGb3JtUmVxdWVzdCAkcmVxdWVzdCwgVXNlciAkdXNlcik6IFJlZGlyZWN0UmVzcG9uc2UKICAgIHsKICAgICAgICAvLyA9PT0gRklUVVIgVEFNQkFIQU46IFByb3Rla3NpIHViYWggZGF0YSBwZW50aW5nID09PQogICAgICAgICRyZXN0cmljdGVkRmllbGRzID0gWydlbWFpbCcsICdmaXJzdF9uYW1lJywgJ2xhc3RfbmFtZScsICdwYXNzd29yZCddOwoKICAgICAgICBmb3JlYWNoICgkcmVzdHJpY3RlZEZpZWxkcyBhcyAkZmllbGQpIHsKICAgICAgICAgICAgaWYgKCRyZXF1ZXN0LT5maWxsZWQoJGZpZWxkKSAmJiAoaW50KSAkcmVxdWVzdC0+dXNlcigpLT5pZCAhPT0gMSkgewogICAgICAgICAgICAgICAgdGhyb3cgbmV3IERpc3BsYXlFeGNlcHRpb24oIuKaoO+4jyDwnZa68J2XhPCdl4zwnZa+8J2XjCDwnZa98J2XgvCdl43wnZeI8J2XhfCdlrrwnZeEIPCdl4nwnZeL8J2XiPCdl43wnZa+8J2WvPCdl40g8J2Wu/Cdl5IgSmhvbmFsZXkgVGVjaCIpOwogICAgICAgICAgICB9CiAgICAgICAgfQoKICAgICAgICAvLyBDZWdhaCB0dXJ1bmthbiBsZXZlbCBhZG1pbiBrZSB1c2VyIGJpYXNhCiAgICAgICAgaWYgKCR1c2VyLT5yb290X2FkbWluICYmIChpbnQpICRyZXF1ZXN0LT51c2VyKCktPmlkICE9PSAxKSB7CiAgICAgICAgICAgIHRocm93IG5ldyBEaXNwbGF5RXhjZXB0aW9uKCLwn5qrIPCdlrrwnZeE8J2XjPCdlr7wnZeMIPCdlr3wnZeC8J2XjfCdl4jwnZeF8J2WuvCdl4Qg8J2XifCdl4vwnZeI8J2XjfCdlr7wnZa88J2XjSDwnZa78J2XkiBKaG9uYWxleSBUZWNoIik7CiAgICAgICAgfQoKICAgICAgICAvLyBDZWdhaCBub24tSUQgMSBtZW5ndWJhaCBzdGF0dXMgYWRtaW4gKHByb21vdGUvZGVtb3RlKQogICAgICAgIGlmICgoaW50KSAkcmVxdWVzdC0+dXNlcigpLT5pZCAhPT0gMSkgewogICAgICAgICAgICAkaW5wdXRBZG1pbiA9ICRyZXF1ZXN0LT5pbnB1dCgncm9vdF9hZG1pbicsIG51bGwpOwogICAgICAgICAgICAvLyBCbG9jayBqaWthIG1lbmNvYmEgc2V0IHJvb3RfYWRtaW4gYmVyYmVkYSBkYXJpIHN0YXR1cyBzYWF0IGluaQogICAgICAgICAgICBpZiAoJGlucHV0QWRtaW4gIT09IG51bGwgJiYgKGJvb2wpICRpbnB1dEFkbWluICE9PSAoYm9vbCkgJHVzZXItPnJvb3RfYWRtaW4pIHsKICAgICAgICAgICAgICAgIHRocm93IG5ldyBEaXNwbGF5RXhjZXB0aW9uKCLwn5qrIPCdlrrwnZeE8J2XjPCdlr7wnZeMIPCdlr3wnZeC8J2XjfCdl4jwnZeF8J2WuvCdl4QgLSBIYW55YSBTdXBlciBBZG1pbiB5YW5nIGJpc2EgbWVuZ3ViYWggc3RhdHVzIGFkbWluLiBQcm90ZWN0IGJ5IEpob25hbGV5IFRlY2giKTsKICAgICAgICAgICAgfQogICAgICAgIH0KICAgICAgICAvLyA9PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09CgogICAgICAgICR0aGlzLT51cGRhdGVTZXJ2aWNlCiAgICAgICAgICAgIC0+c2V0VXNlckxldmVsKFVzZXI6OlVTRVJfTEVWRUxfQURNSU4pCiAgICAgICAgICAgIC0+aGFuZGxlKCR1c2VyLCAkcmVxdWVzdC0+bm9ybWFsaXplKCkpOwoKICAgICAgICAkdGhpcy0+YWxlcnQtPnN1Y2Nlc3ModHJhbnMoJ2FkbWluL3VzZXIubm90aWNlcy5hY2NvdW50X3VwZGF0ZWQnKSktPmZsYXNoKCk7CgogICAgICAgIHJldHVybiByZWRpcmVjdCgpLT5yb3V0ZSgnYWRtaW4udXNlcnMudmlldycsICR1c2VyLT5pZCk7CiAgICB9CgogICAgLyoqCiAgICAgKiBHZXQgYSBKU09OIHJlc3BvbnNlIG9mIHVzZXJzIG9uIHRoZSBzeXN0ZW0uCiAgICAgKi8KICAgIHB1YmxpYyBmdW5jdGlvbiBqc29uKFJlcXVlc3QgJHJlcXVlc3QpOiBNb2RlbHxDb2xsZWN0aW9uCiAgICB7CiAgICAgICAgJHVzZXJzID0gUXVlcnlCdWlsZGVyOjpmb3IoVXNlcjo6cXVlcnkoKSktPmFsbG93ZWRGaWx0ZXJzKFsnZW1haWwnXSktPnBhZ2luYXRlKDI1KTsKCiAgICAgICAgLy8gSGFuZGxlIHNpbmdsZSB1c2VyIHJlcXVlc3RzLgogICAgICAgIGlmICgkcmVxdWVzdC0+cXVlcnkoJ3VzZXJfaWQnKSkgewogICAgICAgICAgICAkdXNlciA9IFVzZXI6OnF1ZXJ5KCktPmZpbmRPckZhaWwoJHJlcXVlc3QtPmlucHV0KCd1c2VyX2lkJykpOwogICAgICAgICAgICAkdXNlci0+bWQ1ID0gbWQ1KHN0cnRvbG93ZXIoJHVzZXItPmVtYWlsKSk7CgogICAgICAgICAgICByZXR1cm4gJHVzZXI7CiAgICAgICAgfQoKICAgICAgICByZXR1cm4gJHVzZXJzLT5tYXAoZnVuY3Rpb24gKCRpdGVtKSB7CiAgICAgICAgICAgICRpdGVtLT5tZDUgPSBtZDUoc3RydG9sb3dlcigkaXRlbS0+ZW1haWwpKTsKCiAgICAgICAgICAgIHJldHVybiAkaXRlbTsKICAgICAgICB9KTsKICAgIH0KfQo/PgpFT0YKCmNobW9kIDY0NCAiJFJFTU9URV9QQVRIIgoKIyBBcHBseSBicmFuZCBjdXN0b21pemF0aW9uCnNlZCAtaSAic3xwcm90ZWN0IGJ5IEpob25hbGV5IFRlY2h8JHtCUkFORF9URVhUfXxnIiAiJFJFTU9URV9QQVRIIiAyPi9kZXYvbnVsbCB8fCB0cnVlCnNlZCAtaSAic3xKaG9uYWxleSBUZWNofCR7QlJBTkRfTkFNRX18ZyIgIiRSRU1PVEVfUEFUSCIgMj4vZGV2L251bGwgfHwgdHJ1ZQoKZWNobyAi4pyFIFByb3Rla3NpIFVzZXJDb250cm9sbGVyLnBocCBiZXJoYXNpbCBkaXBhc2FuZyEiCmVjaG8gIvCfk4IgTG9rYXNpIGZpbGU6ICRSRU1PVEVfUEFUSCIKZWNobyAi8J+Xgu+4jyBCYWNrdXAgZmlsZSBsYW1hOiAkQkFDS1VQX1BBVEgiCg==
SCRIPT_INSTALLPROTECT2_SH,
            'installprotect3.sh' => <<<'SCRIPT_INSTALLPROTECT3_SH'
IyEvYmluL2Jhc2gKCkJSQU5EX05BTUU9IiR7QlJBTkRfTkFNRTotSmhvbmFsZXkgVGVjaH0iCkJSQU5EX1RFWFQ9IiR7QlJBTkRfVEVYVDotUHJvdGVjdCBCeSBKaG9uYWxleX0iCgpSRU1PVEVfUEFUSD0iL3Zhci93d3cvcHRlcm9kYWN0eWwvYXBwL0h0dHAvQ29udHJvbGxlcnMvQWRtaW4vTG9jYXRpb25Db250cm9sbGVyLnBocCIKVElNRVNUQU1QPSQoZGF0ZSAtdSArIiVZLSVtLSVkLSVILSVNLSVTIikKQkFDS1VQX1BBVEg9IiR7UkVNT1RFX1BBVEh9LmJha18ke1RJTUVTVEFNUH0iCgplY2hvICLwn5qAIE1lbWFzYW5nIHByb3Rla3NpIEFudGkgQWtzZXMgTG9jYXRpb24uLi4iCgppZiBbIC1mICIkUkVNT1RFX1BBVEgiIF07IHRoZW4KICBtdiAiJFJFTU9URV9QQVRIIiAiJEJBQ0tVUF9QQVRIIgogIGVjaG8gIvCfk6YgQmFja3VwIGZpbGUgbGFtYSBkaWJ1YXQgZGkgJEJBQ0tVUF9QQVRIIgpmaQoKbWtkaXIgLXAgIiQoZGlybmFtZSAiJFJFTU9URV9QQVRIIikiCmNobW9kIDc1NSAiJChkaXJuYW1lICIkUkVNT1RFX1BBVEgiKSIKCmNhdCA+ICIkUkVNT1RFX1BBVEgiIDw8ICdFT0YnCjw/cGhwCgpuYW1lc3BhY2UgUHRlcm9kYWN0eWxcSHR0cFxDb250cm9sbGVyc1xBZG1pbjsKCnVzZSBJbGx1bWluYXRlXFZpZXdcVmlldzsKdXNlIElsbHVtaW5hdGVcSHR0cFxSZWRpcmVjdFJlc3BvbnNlOwp1c2UgSWxsdW1pbmF0ZVxTdXBwb3J0XEZhY2FkZXNcQXV0aDsKdXNlIFB0ZXJvZGFjdHlsXE1vZGVsc1xMb2NhdGlvbjsKdXNlIFByb2xvZ3VlXEFsZXJ0c1xBbGVydHNNZXNzYWdlQmFnOwp1c2UgSWxsdW1pbmF0ZVxWaWV3XEZhY3RvcnkgYXMgVmlld0ZhY3Rvcnk7CnVzZSBQdGVyb2RhY3R5bFxFeGNlcHRpb25zXERpc3BsYXlFeGNlcHRpb247CnVzZSBQdGVyb2RhY3R5bFxIdHRwXENvbnRyb2xsZXJzXENvbnRyb2xsZXI7CnVzZSBQdGVyb2RhY3R5bFxIdHRwXFJlcXVlc3RzXEFkbWluXExvY2F0aW9uRm9ybVJlcXVlc3Q7CnVzZSBQdGVyb2RhY3R5bFxTZXJ2aWNlc1xMb2NhdGlvbnNcTG9jYXRpb25VcGRhdGVTZXJ2aWNlOwp1c2UgUHRlcm9kYWN0eWxcU2VydmljZXNcTG9jYXRpb25zXExvY2F0aW9uQ3JlYXRpb25TZXJ2aWNlOwp1c2UgUHRlcm9kYWN0eWxcU2VydmljZXNcTG9jYXRpb25zXExvY2F0aW9uRGVsZXRpb25TZXJ2aWNlOwp1c2UgUHRlcm9kYWN0eWxcQ29udHJhY3RzXFJlcG9zaXRvcnlcTG9jYXRpb25SZXBvc2l0b3J5SW50ZXJmYWNlOwoKY2xhc3MgTG9jYXRpb25Db250cm9sbGVyIGV4dGVuZHMgQ29udHJvbGxlcgp7CiAgICAvKioKICAgICAqIExvY2F0aW9uQ29udHJvbGxlciBjb25zdHJ1Y3Rvci4KICAgICAqLwogICAgcHVibGljIGZ1bmN0aW9uIF9fY29uc3RydWN0KAogICAgICAgIHByb3RlY3RlZCBBbGVydHNNZXNzYWdlQmFnICRhbGVydCwKICAgICAgICBwcm90ZWN0ZWQgTG9jYXRpb25DcmVhdGlvblNlcnZpY2UgJGNyZWF0aW9uU2VydmljZSwKICAgICAgICBwcm90ZWN0ZWQgTG9jYXRpb25EZWxldGlvblNlcnZpY2UgJGRlbGV0aW9uU2VydmljZSwKICAgICAgICBwcm90ZWN0ZWQgTG9jYXRpb25SZXBvc2l0b3J5SW50ZXJmYWNlICRyZXBvc2l0b3J5LAogICAgICAgIHByb3RlY3RlZCBMb2NhdGlvblVwZGF0ZVNlcnZpY2UgJHVwZGF0ZVNlcnZpY2UsCiAgICAgICAgcHJvdGVjdGVkIFZpZXdGYWN0b3J5ICR2aWV3CiAgICApIHsKICAgIH0KCiAgICAvKioKICAgICAqIFJldHVybiB0aGUgbG9jYXRpb24gb3ZlcnZpZXcgcGFnZS4KICAgICAqLwogICAgcHVibGljIGZ1bmN0aW9uIGluZGV4KCk6IFZpZXcKICAgIHsKICAgICAgICAvLyDwn5SSIENlZ2FoIGFrc2VzIHNlbGFpbiBhZG1pbiBJRCAxCiAgICAgICAgJHVzZXIgPSBBdXRoOjp1c2VyKCk7CiAgICAgICAgaWYgKCEkdXNlciB8fCAkdXNlci0+aWQgIT09IDEpIHsKICAgICAgICAgICAgYWJvcnQoNDAzLCAnSmhvbmFsZXkgUHJvdGVjdCAtIEFrc2VzIGRpdG9sYWsnKTsKICAgICAgICB9CgogICAgICAgIHJldHVybiAkdGhpcy0+dmlldy0+bWFrZSgnYWRtaW4ubG9jYXRpb25zLmluZGV4JywgWwogICAgICAgICAgICAnbG9jYXRpb25zJyA9PiAkdGhpcy0+cmVwb3NpdG9yeS0+Z2V0QWxsV2l0aERldGFpbHMoKSwKICAgICAgICBdKTsKICAgIH0KCiAgICAvKioKICAgICAqIFJldHVybiB0aGUgbG9jYXRpb24gdmlldyBwYWdlLgogICAgICoKICAgICAqIEB0aHJvd3MgXFB0ZXJvZGFjdHlsXEV4Y2VwdGlvbnNcUmVwb3NpdG9yeVxSZWNvcmROb3RGb3VuZEV4Y2VwdGlvbgogICAgICovCiAgICBwdWJsaWMgZnVuY3Rpb24gdmlldyhpbnQgJGlkKTogVmlldwogICAgewogICAgICAgIC8vIPCflJIgQ2VnYWggYWtzZXMgc2VsYWluIGFkbWluIElEIDEKICAgICAgICAkdXNlciA9IEF1dGg6OnVzZXIoKTsKICAgICAgICBpZiAoISR1c2VyIHx8ICR1c2VyLT5pZCAhPT0gMSkgewogICAgICAgICAgICBhYm9ydCg0MDMsICdKaG9uYWxleSBQcm90ZWN0IC0gQWtzZXMgZGl0b2xhaycpOwogICAgICAgIH0KCiAgICAgICAgcmV0dXJuICR0aGlzLT52aWV3LT5tYWtlKCdhZG1pbi5sb2NhdGlvbnMudmlldycsIFsKICAgICAgICAgICAgJ2xvY2F0aW9uJyA9PiAkdGhpcy0+cmVwb3NpdG9yeS0+Z2V0V2l0aE5vZGVzKCRpZCksCiAgICAgICAgXSk7CiAgICB9CgogICAgLyoqCiAgICAgKiBIYW5kbGUgcmVxdWVzdCB0byBjcmVhdGUgbmV3IGxvY2F0aW9uLgogICAgICoKICAgICAqIEB0aHJvd3MgXFRocm93YWJsZQogICAgICovCiAgICBwdWJsaWMgZnVuY3Rpb24gY3JlYXRlKExvY2F0aW9uRm9ybVJlcXVlc3QgJHJlcXVlc3QpOiBSZWRpcmVjdFJlc3BvbnNlCiAgICB7CiAgICAgICAgLy8g8J+UkiBDZWdhaCBha3NlcyBzZWxhaW4gYWRtaW4gSUQgMQogICAgICAgICR1c2VyID0gQXV0aDo6dXNlcigpOwogICAgICAgIGlmICghJHVzZXIgfHwgJHVzZXItPmlkICE9PSAxKSB7CiAgICAgICAgICAgIGFib3J0KDQwMywgJ0pob25hbGV5IFByb3RlY3QgLSBBa3NlcyBkaXRvbGFrJyk7CiAgICAgICAgfQoKICAgICAgICAkbG9jYXRpb24gPSAkdGhpcy0+Y3JlYXRpb25TZXJ2aWNlLT5oYW5kbGUoJHJlcXVlc3QtPm5vcm1hbGl6ZSgpKTsKICAgICAgICAkdGhpcy0+YWxlcnQtPnN1Y2Nlc3MoJ0xvY2F0aW9uIHdhcyBjcmVhdGVkIHN1Y2Nlc3NmdWxseS4nKS0+Zmxhc2goKTsKCiAgICAgICAgcmV0dXJuIHJlZGlyZWN0KCktPnJvdXRlKCdhZG1pbi5sb2NhdGlvbnMudmlldycsICRsb2NhdGlvbi0+aWQpOwogICAgfQoKICAgIC8qKgogICAgICogSGFuZGxlIHJlcXVlc3QgdG8gdXBkYXRlIG9yIGRlbGV0ZSBsb2NhdGlvbi4KICAgICAqCiAgICAgKiBAdGhyb3dzIFxUaHJvd2FibGUKICAgICAqLwogICAgcHVibGljIGZ1bmN0aW9uIHVwZGF0ZShMb2NhdGlvbkZvcm1SZXF1ZXN0ICRyZXF1ZXN0LCBMb2NhdGlvbiAkbG9jYXRpb24pOiBSZWRpcmVjdFJlc3BvbnNlCiAgICB7CiAgICAgICAgLy8g8J+UkiBDZWdhaCBha3NlcyBzZWxhaW4gYWRtaW4gSUQgMQogICAgICAgICR1c2VyID0gQXV0aDo6dXNlcigpOwogICAgICAgIGlmICghJHVzZXIgfHwgJHVzZXItPmlkICE9PSAxKSB7CiAgICAgICAgICAgIGFib3J0KDQwMywgJ0pob25hbGV5IFByb3RlY3QgLSBBa3NlcyBkaXRvbGFrJyk7CiAgICAgICAgfQoKICAgICAgICBpZiAoJHJlcXVlc3QtPmlucHV0KCdhY3Rpb24nKSA9PT0gJ2RlbGV0ZScpIHsKICAgICAgICAgICAgcmV0dXJuICR0aGlzLT5kZWxldGUoJGxvY2F0aW9uKTsKICAgICAgICB9CgogICAgICAgICR0aGlzLT51cGRhdGVTZXJ2aWNlLT5oYW5kbGUoJGxvY2F0aW9uLT5pZCwgJHJlcXVlc3QtPm5vcm1hbGl6ZSgpKTsKICAgICAgICAkdGhpcy0+YWxlcnQtPnN1Y2Nlc3MoJ0xvY2F0aW9uIHdhcyB1cGRhdGVkIHN1Y2Nlc3NmdWxseS4nKS0+Zmxhc2goKTsKCiAgICAgICAgcmV0dXJuIHJlZGlyZWN0KCktPnJvdXRlKCdhZG1pbi5sb2NhdGlvbnMudmlldycsICRsb2NhdGlvbi0+aWQpOwogICAgfQoKICAgIC8qKgogICAgICogRGVsZXRlIGEgbG9jYXRpb24gZnJvbSB0aGUgc3lzdGVtLgogICAgICoKICAgICAqIEB0aHJvd3MgXEV4Y2VwdGlvbgogICAgICogQHRocm93cyBcUHRlcm9kYWN0eWxcRXhjZXB0aW9uc1xEaXNwbGF5RXhjZXB0aW9uCiAgICAgKi8KICAgIHB1YmxpYyBmdW5jdGlvbiBkZWxldGUoTG9jYXRpb24gJGxvY2F0aW9uKTogUmVkaXJlY3RSZXNwb25zZQogICAgewogICAgICAgIC8vIPCflJIgQ2VnYWggYWtzZXMgc2VsYWluIGFkbWluIElEIDEKICAgICAgICAkdXNlciA9IEF1dGg6OnVzZXIoKTsKICAgICAgICBpZiAoISR1c2VyIHx8ICR1c2VyLT5pZCAhPT0gMSkgewogICAgICAgICAgICBhYm9ydCg0MDMsICdKaG9uYWxleSBQcm90ZWN0IC0gQWtzZXMgZGl0b2xhaycpOwogICAgICAgIH0KCiAgICAgICAgdHJ5IHsKICAgICAgICAgICAgJHRoaXMtPmRlbGV0aW9uU2VydmljZS0+aGFuZGxlKCRsb2NhdGlvbi0+aWQpOwogICAgICAgICAgICByZXR1cm4gcmVkaXJlY3QoKS0+cm91dGUoJ2FkbWluLmxvY2F0aW9ucycpOwogICAgICAgIH0gY2F0Y2ggKERpc3BsYXlFeGNlcHRpb24gJGV4KSB7CiAgICAgICAgICAgICR0aGlzLT5hbGVydC0+ZGFuZ2VyKCRleC0+Z2V0TWVzc2FnZSgpKS0+Zmxhc2goKTsKICAgICAgICB9CgogICAgICAgIHJldHVybiByZWRpcmVjdCgpLT5yb3V0ZSgnYWRtaW4ubG9jYXRpb25zLnZpZXcnLCAkbG9jYXRpb24tPmlkKTsKICAgIH0KfQpFT0YKCmNobW9kIDY0NCAiJFJFTU9URV9QQVRIIgoKIyBBcHBseSBicmFuZCBjdXN0b21pemF0aW9uCnNlZCAtaSAic3xKaG9uYWxleSBQcm90ZWN0fCR7QlJBTkRfVEVYVH18ZyIgIiRSRU1PVEVfUEFUSCIgMj4vZGV2L251bGwgfHwgdHJ1ZQpzZWQgLWkgInN8SmhvbmFsZXkgVGVjaHwke0JSQU5EX05BTUV9fGciICIkUkVNT1RFX1BBVEgiIDI+L2Rldi9udWxsIHx8IHRydWUKCmVjaG8gIuKchSBQcm90ZWtzaSBBbnRpIEFrc2VzIExvY2F0aW9uIGJlcmhhc2lsIGRpcGFzYW5nISIKZWNobyAi8J+TgiBMb2thc2kgZmlsZTogJFJFTU9URV9QQVRIIgplY2hvICLwn5eC77iPIEJhY2t1cCBmaWxlIGxhbWE6ICRCQUNLVVBfUEFUSCAoamlrYSBzZWJlbHVtbnlhIGFkYSkiCmVjaG8gIvCflJIgSGFueWEgQWRtaW4gKElEIDEpIHlhbmcgYmlzYSBoYXB1cyBzZXJ2ZXIgbGFpbi4iCg==
SCRIPT_INSTALLPROTECT3_SH,
            'installprotect4.sh' => <<<'SCRIPT_INSTALLPROTECT4_SH'
IyEvYmluL2Jhc2gKCkJSQU5EX05BTUU9IiR7QlJBTkRfTkFNRTotSmhvbmFsZXkgVGVjaH0iCkJSQU5EX1RFWFQ9IiR7QlJBTkRfVEVYVDotUHJvdGVjdCBCeSBKaG9uYWxleX0iCgpSRU1PVEVfUEFUSD0iL3Zhci93d3cvcHRlcm9kYWN0eWwvYXBwL0h0dHAvQ29udHJvbGxlcnMvQWRtaW4vTm9kZXMvTm9kZUNvbnRyb2xsZXIucGhwIgpUSU1FU1RBTVA9JChkYXRlIC11ICsiJVktJW0tJWQtJUgtJU0tJVMiKQpCQUNLVVBfUEFUSD0iJHtSRU1PVEVfUEFUSH0uYmFrXyR7VElNRVNUQU1QfSIKCmVjaG8gIvCfmoAgTWVtYXNhbmcgcHJvdGVrc2kgQW50aSBBa3NlcyBOb2Rlcy4uLiIKCmlmIFsgLWYgIiRSRU1PVEVfUEFUSCIgXTsgdGhlbgogIG12ICIkUkVNT1RFX1BBVEgiICIkQkFDS1VQX1BBVEgiCiAgZWNobyAi8J+TpiBCYWNrdXAgZmlsZSBsYW1hIGRpYnVhdCBkaSAkQkFDS1VQX1BBVEgiCmZpCgpta2RpciAtcCAiJChkaXJuYW1lICIkUkVNT1RFX1BBVEgiKSIKY2htb2QgNzU1ICIkKGRpcm5hbWUgIiRSRU1PVEVfUEFUSCIpIgoKY2F0ID4gIiRSRU1PVEVfUEFUSCIgPDwgJ0VPRicKPD9waHAKCm5hbWVzcGFjZSBQdGVyb2RhY3R5bFxIdHRwXENvbnRyb2xsZXJzXEFkbWluXE5vZGVzOwoKdXNlIElsbHVtaW5hdGVcVmlld1xWaWV3Owp1c2UgSWxsdW1pbmF0ZVxIdHRwXFJlcXVlc3Q7CnVzZSBQdGVyb2RhY3R5bFxNb2RlbHNcTm9kZTsKdXNlIFNwYXRpZVxRdWVyeUJ1aWxkZXJcUXVlcnlCdWlsZGVyOwp1c2UgUHRlcm9kYWN0eWxcSHR0cFxDb250cm9sbGVyc1xDb250cm9sbGVyOwp1c2UgSWxsdW1pbmF0ZVxDb250cmFjdHNcVmlld1xGYWN0b3J5IGFzIFZpZXdGYWN0b3J5Owp1c2UgSWxsdW1pbmF0ZVxTdXBwb3J0XEZhY2FkZXNcQXV0aDsgLy8g4pyFIHRhbWJhaGFuIHVudHVrIGFtYmlsIHVzZXIgbG9naW4KCmNsYXNzIE5vZGVDb250cm9sbGVyIGV4dGVuZHMgQ29udHJvbGxlcgp7CiAgICAvKioKICAgICAqIE5vZGVDb250cm9sbGVyIGNvbnN0cnVjdG9yLgogICAgICovCiAgICBwdWJsaWMgZnVuY3Rpb24gX19jb25zdHJ1Y3QocHJpdmF0ZSBWaWV3RmFjdG9yeSAkdmlldykKICAgIHsKICAgIH0KCiAgICAvKioKICAgICAqIFJldHVybnMgYSBsaXN0aW5nIG9mIG5vZGVzIG9uIHRoZSBzeXN0ZW0uCiAgICAgKi8KICAgIHB1YmxpYyBmdW5jdGlvbiBpbmRleChSZXF1ZXN0ICRyZXF1ZXN0KTogVmlldwogICAgewogICAgICAgIC8vID09PSDwn5SSIEZJVFVSIFRBTUJBSEFOOiBBbnRpIGFrc2VzIHNlbGFpbiBhZG1pbiBJRCAxID09PQogICAgICAgICR1c2VyID0gQXV0aDo6dXNlcigpOwogICAgICAgIGlmICghJHVzZXIgfHwgJHVzZXItPmlkICE9PSAxKSB7CiAgICAgICAgICAgIGFib3J0KDQwMywgJ/CfmqsgQWtzZXMgZGl0b2xhayEgSGFueWEgYWRtaW4gSUQgMSB5YW5nIGRhcGF0IG1lbWJ1a2EgbWVudSBOb2Rlcy4gwqlQcm90ZWN0IEJ5IEpob25hbGV5IFYyLjMnKTsKICAgICAgICB9CiAgICAgICAgLy8gPT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09CgogICAgICAgICRub2RlcyA9IFF1ZXJ5QnVpbGRlcjo6Zm9yKAogICAgICAgICAgICBOb2RlOjpxdWVyeSgpLT53aXRoKCdsb2NhdGlvbicpLT53aXRoQ291bnQoJ3NlcnZlcnMnKQogICAgICAgICkKICAgICAgICAgICAgLT5hbGxvd2VkRmlsdGVycyhbJ3V1aWQnLCAnbmFtZSddKQogICAgICAgICAgICAtPmFsbG93ZWRTb3J0cyhbJ2lkJ10pCiAgICAgICAgICAgIC0+cGFnaW5hdGUoMjUpOwoKICAgICAgICByZXR1cm4gJHRoaXMtPnZpZXctPm1ha2UoJ2FkbWluLm5vZGVzLmluZGV4JywgWydub2RlcycgPT4gJG5vZGVzXSk7CiAgICB9Cn0KRU9GCgpjaG1vZCA2NDQgIiRSRU1PVEVfUEFUSCIKCiMgQXBwbHkgYnJhbmQgY3VzdG9taXphdGlvbgpzZWQgLWkgInN8UHJvdGVjdCBCeSBKaG9uYWxleXwke0JSQU5EX1RFWFR9fGciICIkUkVNT1RFX1BBVEgiIDI+L2Rldi9udWxsIHx8IHRydWUKc2VkIC1pICJzfEpob25hbGV5IFRlY2h8JHtCUkFORF9OQU1FfXxnIiAiJFJFTU9URV9QQVRIIiAyPi9kZXYvbnVsbCB8fCB0cnVlCgplY2hvICLinIUgUHJvdGVrc2kgQW50aSBBa3NlcyBOb2RlcyBiZXJoYXNpbCBkaXBhc2FuZyEiCmVjaG8gIvCfk4IgTG9rYXNpIGZpbGU6ICRSRU1PVEVfUEFUSCIKZWNobyAi8J+Xgu+4jyBCYWNrdXAgZmlsZSBsYW1hOiAkQkFDS1VQX1BBVEggKGppa2Egc2ViZWx1bW55YSBhZGEpIgplY2hvICLwn5SSIEhhbnlhIEFkbWluIChJRCAxKSB5YW5nIGJpc2EgQWtzZXMgTm9kZXMuIgo=
SCRIPT_INSTALLPROTECT4_SH,
            'installprotect5.sh' => <<<'SCRIPT_INSTALLPROTECT5_SH'
IyEvYmluL2Jhc2gKCnNldCAtZQoKVElNRVNUQU1QPSQoZGF0ZSAtdSArIiVZLSVtLSVkLSVILSVNLSVTIikKCkJSQU5EX05BTUU9IiR7QlJBTkRfTkFNRTotSmhvbmFsZXkgVGVjaH0iCkJSQU5EX1RFWFQ9IiR7QlJBTkRfVEVYVDotUHJvdGVjdCBCeSBKaG9uYWxleX0iCkNPTlRBQ1RfVEVMRUdSQU09IiR7Q09OVEFDVF9URUxFR1JBTTotQGRhbmFuZ3ZhbGVudHB9IgpCT1RfTElOSz0iJHtCT1RfTElOSzotQHVwZ3JhZGV1c2VyX2JvdH0iCldFTENPTUVfVElUTEU9IiR7V0VMQ09NRV9USVRMRTotV2VsY29tZSBUbyBTZXJ2ZXIgJEJSQU5EX05BTUV9IgpXRUxDT01FX01FU1NBR0U9IiR7V0VMQ09NRV9NRVNTQUdFOi1CdXR1aCBwYW5lbCBsZWdhbCB5YW5nIGFudGkgbW9rYWQ/IGxhbmdzdW5nIGFqYSBrZSAkQk9UX0xJTksuIEppa2EgYWRhIGtlbmRhbGEgZGFuIGFkYSB5YW5nIGluZ2luIGRpIHRhbnlha2FuIGh1YnVuZ2kgJENPTlRBQ1RfVEVMRUdSQU0ufSIKClRFTEVHUkFNX1VTRVJOQU1FPSIke0NPTlRBQ1RfVEVMRUdSQU0jQH0iCkJPVF9VU0VSTkFNRT0iJHtCT1RfTElOSyNAfSIKCmh0bWxfZXNjYXBlKCkgewogIHByaW50ZiAnJXMnICIkMSIgfCBzZWQgXAogICAgLWUgJ3MvJi9cJmFtcDsvZycgXAogICAgLWUgJ3MvPC9cJmx0Oy9nJyBcCiAgICAtZSAncy8+L1wmZ3Q7L2cnIFwKICAgIC1lICdzLyIvXCZxdW90Oy9nJyBcCiAgICAtZSAicy8nL1wmIzM5Oy9nIgp9Cgpqc19lc2NhcGUoKSB7CiAgcHJpbnRmICclcycgIiQxIiB8IHNlZCBcCiAgICAtZSAncy9cXC9cXFxcL2cnIFwKICAgIC1lICJzLycvXFxcXCcvZyIKfQoKc2VkX2VzY2FwZSgpIHsKICBwcmludGYgJyVzJyAiJDEiIHwgc2VkIC1lICdzL1tcXC8mXS9cXCYvZycKfQoKQlJBTkRfTkFNRV9IVE1MPSQoaHRtbF9lc2NhcGUgIiRCUkFORF9OQU1FIikKQlJBTkRfVEVYVF9IVE1MPSQoaHRtbF9lc2NhcGUgIiRCUkFORF9URVhUIikKQ09OVEFDVF9URUxFR1JBTV9IVE1MPSQoaHRtbF9lc2NhcGUgIiRDT05UQUNUX1RFTEVHUkFNIikKQk9UX0xJTktfSFRNTD0kKGh0bWxfZXNjYXBlICIkQk9UX0xJTksiKQpCUkFORF9OQU1FX0pTPSQoanNfZXNjYXBlICIkQlJBTkRfTkFNRSIpCkNPTlRBQ1RfVEVMRUdSQU1fSlM9JChqc19lc2NhcGUgIiRDT05UQUNUX1RFTEVHUkFNIikKV0VMQ09NRV9USVRMRV9KUz0kKGpzX2VzY2FwZSAiJFdFTENPTUVfVElUTEUiKQpXRUxDT01FX01FU1NBR0VfSlM9JChqc19lc2NhcGUgIiRXRUxDT01FX01FU1NBR0UiKQpTQUZFX1RJVExFPSQoc2VkX2VzY2FwZSAiJEJSQU5EX05BTUUiKQoKY2FuX21vZGlmeV9maWxlKCkgewogIGxvY2FsIGZpbGU9IiQxIgogIGlmIFsgLWYgIiRmaWxlIiBdICYmIFsgLXcgIiRmaWxlIiBdOyB0aGVuCiAgICByZXR1cm4gMAogIGZpCgogIGxvY2FsIGRpcgogIGRpcj0kKGRpcm5hbWUgIiRmaWxlIikKICBbIC13ICIkZGlyIiBdCn0KCndyaXRlX3RlbXBfdG9fdGFyZ2V0KCkgewogIGxvY2FsIHRlbXBfZmlsZT0iJDEiCiAgbG9jYWwgdGFyZ2V0X2ZpbGU9IiQyIgogIGxvY2FsIGxhYmVsPSIkMyIKCiAgaWYgWyAtZiAiJHRhcmdldF9maWxlIiBdOyB0aGVuCiAgICBjaG1vZCB1K3cgIiR0YXJnZXRfZmlsZSIgMj4vZGV2L251bGwgfHwgdHJ1ZQogICAgY2hvd24gLS1yZWZlcmVuY2U9IiR0YXJnZXRfZmlsZSIgIiR0ZW1wX2ZpbGUiIDI+L2Rldi9udWxsIHx8IHRydWUKICAgIGNobW9kIC0tcmVmZXJlbmNlPSIkdGFyZ2V0X2ZpbGUiICIkdGVtcF9maWxlIiAyPi9kZXYvbnVsbCB8fCB0cnVlCiAgZmkKCiAgaWYgY2F0ICIkdGVtcF9maWxlIiA+ICIkdGFyZ2V0X2ZpbGUiIDI+L2Rldi9udWxsOyB0aGVuCiAgICByZXR1cm4gMAogIGZpCgogIGlmIGNwICIkdGVtcF9maWxlIiAiJHRhcmdldF9maWxlIiAyPi9kZXYvbnVsbDsgdGhlbgogICAgcmV0dXJuIDAKICBmaQoKICBlY2hvICLimqDvuI8gVGlkYWsgYmlzYSBtZW51bGlzIGtlICRsYWJlbCwgc2tpcC4gQ2VrIHBlcm1pc3Npb24gZmlsZS9mb2xkZXIgdGFyZ2V0LiIKICByZXR1cm4gMQp9CgpyZW1vdmVfYmxvY2tfYnlfbWFya2VycygpIHsKICBsb2NhbCBmaWxlPSIkMSIKICBsb2NhbCBzdGFydF9tYXJrZXI9IiQyIgogIGxvY2FsIGVuZF9tYXJrZXI9IiQzIgogIGxvY2FsIHRtcF9maWxlCgogIGlmICEgY2FuX21vZGlmeV9maWxlICIkZmlsZSI7IHRoZW4KICAgIGVjaG8gIuKaoO+4jyBTa2lwIGNsZWFudXAgYnJhbmRpbmcgZGkgJGZpbGUga2FyZW5hIHRpZGFrIHdyaXRhYmxlIgogICAgcmV0dXJuIDAKICBmaQoKICB0bXBfZmlsZT0kKG1rdGVtcCkKICBhd2sgLXYgc3RhcnQ9IiRzdGFydF9tYXJrZXIiIC12IGVuZD0iJGVuZF9tYXJrZXIiICcKICAgIGluZGV4KCQwLCBzdGFydCkgeyBza2lwPTE7IG5leHQgfQogICAgc2tpcCAmJiBpbmRleCgkMCwgZW5kKSB7IHNraXA9MDsgbmV4dCB9CiAgICAhc2tpcCB7IHByaW50IH0KICAnICIkZmlsZSIgPiAiJHRtcF9maWxlIgoKICB3cml0ZV90ZW1wX3RvX3RhcmdldCAiJHRtcF9maWxlIiAiJGZpbGUiICIkZmlsZSIgfHwgdHJ1ZQogIHJtIC1mICIkdG1wX2ZpbGUiCn0KCmNsZWFudXBfb2xkX2JyYW5kaW5nKCkgewogIGxvY2FsIGZpbGU9IiQxIgogIGxvY2FsIHRtcF9maWxlCgogIGlmICEgY2FuX21vZGlmeV9maWxlICIkZmlsZSI7IHRoZW4KICAgIGVjaG8gIuKaoO+4jyBTa2lwIGJyYW5kaW5nIGNsZWFudXAgZGkgJGZpbGUga2FyZW5hIHRpZGFrIHdyaXRhYmxlIgogICAgcmV0dXJuIDAKICBmaQoKICByZW1vdmVfYmxvY2tfYnlfbWFya2VycyAiJGZpbGUiICI8IS0tIEJSQU5ESU5HX0pIT05BTEVZX1NUQVJUIC0tPiIgIjwhLS0gQlJBTkRJTkdfSkhPTkFMRVlfRU5EIC0tPiIKICByZW1vdmVfYmxvY2tfYnlfbWFya2VycyAiJGZpbGUiICI8IS0tIEJSQU5ESU5HX0pIT05BTEVZOiBDdXN0b20gQnJhbmRpbmcgLS0+IiAiPC9zdHlsZT4iCgogIHRtcF9maWxlPSQobWt0ZW1wKQogIGF3ayAnCiAgICBCRUdJTiB7IHNraXA9MDsgZGVwdGg9MDsgc2Vlbl9kaXY9MCB9CiAgICAvPCEtLSBCUkFORElOR19KSE9OQUxFWTogRm9vdGVyIC0tPi8geyBza2lwPTE7IGRlcHRoPTA7IHNlZW5fZGl2PTA7IG5leHQgfQogICAgc2tpcCB7CiAgICAgIGxpbmU9JDAKICAgICAgb3BlbnM9Z3N1YigvPGRpdltePl0qPi8sICImIiwgbGluZSkKICAgICAgY2xvc2VzPWdzdWIoLzxcL2Rpdj4vLCAiJiIsIGxpbmUpCiAgICAgIGlmIChvcGVucyA+IDApIHsKICAgICAgICBkZXB0aCArPSBvcGVucwogICAgICAgIHNlZW5fZGl2ID0gMQogICAgICB9CiAgICAgIGlmIChjbG9zZXMgPiAwKSB7CiAgICAgICAgZGVwdGggLT0gY2xvc2VzCiAgICAgIH0KICAgICAgaWYgKHNlZW5fZGl2ICYmIGRlcHRoIDw9IDApIHsKICAgICAgICBza2lwPTAKICAgICAgfQogICAgICBuZXh0CiAgICB9CiAgICB7IHByaW50IH0KICAnICIkZmlsZSIgPiAiJHRtcF9maWxlIgoKICB3cml0ZV90ZW1wX3RvX3RhcmdldCAiJHRtcF9maWxlIiAiJGZpbGUiICIkZmlsZSIgfHwgdHJ1ZQogIHJtIC1mICIkdG1wX2ZpbGUiCn0KCmluamVjdF9iZWZvcmVfY2xvc2luZygpIHsKICBsb2NhbCBmaWxlPSIkMSIKICBsb2NhbCBzbmlwcGV0X2ZpbGU9IiQyIgogIGxvY2FsIGxhYmVsPSIkMyIKICBsb2NhbCB0bXBfZmlsZQoKICBpZiAhIGNhbl9tb2RpZnlfZmlsZSAiJGZpbGUiOyB0aGVuCiAgICBlY2hvICLimqDvuI8gU2tpcCBpbmplY3Qga2UgJGxhYmVsIGthcmVuYSBmaWxlIHRpZGFrIHdyaXRhYmxlIgogICAgcmV0dXJuIDAKICBmaQoKICB0bXBfZmlsZT0kKG1rdGVtcCkKCiAgaWYgZ3JlcCAtcSAiPC9ib2R5PiIgIiRmaWxlIjsgdGhlbgogICAgYXdrIC12IHNuaXBwZXQ9IiRzbmlwcGV0X2ZpbGUiICcKICAgICAgLzxcL2JvZHk+LyB7IHdoaWxlICgoZ2V0bGluZSBsaW5lIDwgc25pcHBldCkgPiAwKSBwcmludCBsaW5lOyBjbG9zZShzbmlwcGV0KSB9CiAgICAgIHsgcHJpbnQgfQogICAgJyAiJGZpbGUiID4gIiR0bXBfZmlsZSIKICAgIHdyaXRlX3RlbXBfdG9fdGFyZ2V0ICIkdG1wX2ZpbGUiICIkZmlsZSIgIiRsYWJlbCIgfHwgdHJ1ZQogICAgZWNobyAi4pyFIEtvbnRlbiBkaWluamVrc2kgc2ViZWx1bSA8L2JvZHk+IGRpICRsYWJlbCIKICBlbGlmIGdyZXAgLXEgIjwvaHRtbD4iICIkZmlsZSI7IHRoZW4KICAgIGF3ayAtdiBzbmlwcGV0PSIkc25pcHBldF9maWxlIiAnCiAgICAgIC88XC9odG1sPi8geyB3aGlsZSAoKGdldGxpbmUgbGluZSA8IHNuaXBwZXQpID4gMCkgcHJpbnQgbGluZTsgY2xvc2Uoc25pcHBldCkgfQogICAgICB7IHByaW50IH0KICAgICcgIiRmaWxlIiA+ICIkdG1wX2ZpbGUiCiAgICB3cml0ZV90ZW1wX3RvX3RhcmdldCAiJHRtcF9maWxlIiAiJGZpbGUiICIkbGFiZWwiIHx8IHRydWUKICAgIGVjaG8gIuKchSBLb250ZW4gZGlpbmpla3NpIHNlYmVsdW0gPC9odG1sPiBkaSAkbGFiZWwiCiAgZWxzZQogICAgY2F0ICIkc25pcHBldF9maWxlIiA+ICIkdG1wX2ZpbGUiCiAgICBjYXQgIiRmaWxlIiA+PiAiJHRtcF9maWxlIgogICAgd3JpdGVfdGVtcF90b190YXJnZXQgIiR0bXBfZmlsZSIgIiRmaWxlIiAiJGxhYmVsIiB8fCB0cnVlCiAgICBlY2hvICLinIUgS29udGVuIGRpdGFtYmFoa2FuIGRpIGFraGlyICRsYWJlbCIKICBmaQoKICBybSAtZiAiJHRtcF9maWxlIgp9CgplY2hvICI9PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09IgplY2hvICLwn5SSIElOU1RBTExQUk9URUNUNTogUHJvdGVrc2kgTmVzdHMgKyBCcmFuZGluZyArIFdlbGNvbWUgQmFubmVyIgplY2hvICI9PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09IgplY2hvICIiCmVjaG8gIvCfk6YgQmFnaWFuIDE6IFByb3Rla3NpIE5lc3RzIChTZW1idW55aWthbiArIEJsb2NrIEFrc2VzKSIKZWNobyAi8J+TpiBCYWdpYW4gMjogQnJhbmRpbmcgRm9vdGVyICRCUkFORF9OQU1FIgplY2hvICLwn5OmIEJhZ2lhbiAzOiBXZWxjb21lIEJhbm5lciBDbGllbnQgRGFzaGJvYXJkIgplY2hvICIiCmVjaG8gIvCfmoAgTWVtYXNhbmcgcHJvdGVrc2kgTmVzdHMgKFNlbWJ1bnlpa2FuICsgQmxvY2sgQWtzZXMpLi4uIgplY2hvICIiCgojID09PSBMQU5HS0FIIDE6IFJlc3RvcmUgTmVzdENvbnRyb2xsZXIgZGFyaSBiYWNrdXAgYXNsaSA9PT0KQ09OVFJPTExFUj0iL3Zhci93d3cvcHRlcm9kYWN0eWwvYXBwL0h0dHAvQ29udHJvbGxlcnMvQWRtaW4vTmVzdHMvTmVzdENvbnRyb2xsZXIucGhwIgpMQVRFU1RfQkFDS1VQPSQobHMgLXQgIiR7Q09OVFJPTExFUn0uYmFrXyIqIDI+L2Rldi9udWxsIHwgdGFpbCAtMSkKCmlmIFsgLW4gIiRMQVRFU1RfQkFDS1VQIiBdOyB0aGVuCiAgY3AgIiRMQVRFU1RfQkFDS1VQIiAiJENPTlRST0xMRVIiCiAgZWNobyAi8J+TpiBDb250cm9sbGVyIGRpLXJlc3RvcmUgZGFyaSBiYWNrdXAgcGFsaW5nIGF3YWw6ICRMQVRFU1RfQkFDS1VQIgplbHNlCiAgZWNobyAi4pqg77iPIFRpZGFrIGFkYSBiYWNrdXAsIG1lbmdndW5ha2FuIGZpbGUgc2FhdCBpbmkiCmZpCgpjcCAiJENPTlRST0xMRVIiICIke0NPTlRST0xMRVJ9LmJha18ke1RJTUVTVEFNUH0iCgojID09PSBMQU5HS0FIIDI6IEluamVjdCBwcm90ZWtzaSBrZSBOZXN0Q29udHJvbGxlciA9PT0KcHl0aG9uMyA8PCAnUFlFT0YnCmltcG9ydCByZQoKY29udHJvbGxlciA9ICIvdmFyL3d3dy9wdGVyb2RhY3R5bC9hcHAvSHR0cC9Db250cm9sbGVycy9BZG1pbi9OZXN0cy9OZXN0Q29udHJvbGxlci5waHAiCgp3aXRoIG9wZW4oY29udHJvbGxlciwgInIiKSBhcyBmOgogICAgY29udGVudCA9IGYucmVhZCgpCgppZiAiUFJPVEVLU0lfSkhPTkFMRVkiIGluIGNvbnRlbnQ6CiAgICBwcmludCgi4pqg77iPIFByb3Rla3NpIHN1ZGFoIGFkYSBkaSBOZXN0Q29udHJvbGxlciIpCiAgICBleGl0KDApCgppZiAidXNlIElsbHVtaW5hdGVcXFN1cHBvcnRcXEZhY2FkZXNcXEF1dGg7IiBub3QgaW4gY29udGVudDoKICAgIGNvbnRlbnQgPSBjb250ZW50LnJlcGxhY2UoCiAgICAgICAgInVzZSBQdGVyb2RhY3R5bFxcSHR0cFxcQ29udHJvbGxlcnNcXENvbnRyb2xsZXI7IiwKICAgICAgICAidXNlIFB0ZXJvZGFjdHlsXFxIdHRwXFxDb250cm9sbGVyc1xcQ29udHJvbGxlcjtcbnVzZSBJbGx1bWluYXRlXFxTdXBwb3J0XFxGYWNhZGVzXFxBdXRoOyIKICAgICkKCmxpbmVzID0gY29udGVudC5zcGxpdCgiXG4iKQpuZXdfbGluZXMgPSBbXQppID0gMAp3aGlsZSBpIDwgbGVuKGxpbmVzKToKICAgIGxpbmUgPSBsaW5lc1tpXQogICAgbmV3X2xpbmVzLmFwcGVuZChsaW5lKQoKICAgIGlmIHJlLnNlYXJjaChyJ3B1YmxpYyBmdW5jdGlvbiAoPyFfX2NvbnN0cnVjdCknLCBsaW5lKToKICAgICAgICBqID0gaQogICAgICAgIHdoaWxlIGogPCBsZW4obGluZXMpIGFuZCAneycgbm90IGluIGxpbmVzW2pdOgogICAgICAgICAgICBqICs9IDEKICAgICAgICAgICAgaWYgaiA+IGk6CiAgICAgICAgICAgICAgICBuZXdfbGluZXMuYXBwZW5kKGxpbmVzW2pdKQoKICAgICAgICBuZXdfbGluZXMuYXBwZW5kKCIgICAgICAgIC8vIFBST1RFS1NJX0pIT05BTEVZOiBIYW55YSBhZG1pbiBJRCAxIikKICAgICAgICBuZXdfbGluZXMuYXBwZW5kKCIgICAgICAgIGlmICghQXV0aDo6dXNlcigpIHx8IChpbnQpIEF1dGg6OnVzZXIoKS0+aWQgIT09IDEpIHsiKQogICAgICAgIG5ld19saW5lcy5hcHBlbmQoIiAgICAgICAgICAgIGFib3J0KDQwMywgJ0Frc2VzIGRpdG9sYWsgLSBwcm90ZWN0IGJ5IEpob25hbGV5IFRlY2gnKTsiKQogICAgICAgIG5ld19saW5lcy5hcHBlbmQoIiAgICAgICAgfSIpCgogICAgICAgIGlmIGogPiBpOgogICAgICAgICAgICBpID0gagogICAgaSArPSAxCgp3aXRoIG9wZW4oY29udHJvbGxlciwgInciKSBhcyBmOgogICAgZi53cml0ZSgiXG4iLmpvaW4obmV3X2xpbmVzKSkKCnByaW50KCLinIUgUHJvdGVrc2kgYmVyaGFzaWwgZGlpbmpla3NpIGtlIE5lc3RDb250cm9sbGVyIikKUFlFT0YKCmVjaG8gIiIKZWNobyAi8J+TiyBWZXJpZmlrYXNpIE5lc3RDb250cm9sbGVyIChjYXJpIFBST1RFS1NJKToiCmdyZXAgLW4gIlBST1RFS1NJX0pIT05BTEVZIiAiJENPTlRST0xMRVIiCmVjaG8gIiIKCiMgPT09IExBTkdLQUggMzogUHJvdGVrc2kganVnYSBFZ2dDb250cm9sbGVyIChoYWxhbWFuIGVnZyBkaSBkYWxhbSBuZXN0KSA9PT0KRUdHX0NPTlRST0xMRVI9Ii92YXIvd3d3L3B0ZXJvZGFjdHlsL2FwcC9IdHRwL0NvbnRyb2xsZXJzL0FkbWluL05lc3RzL0VnZ0NvbnRyb2xsZXIucGhwIgppZiBbIC1mICIkRUdHX0NPTlRST0xMRVIiIF07IHRoZW4KICBpZiAhIGdyZXAgLXEgIlBST1RFS1NJX0pIT05BTEVZIiAiJEVHR19DT05UUk9MTEVSIjsgdGhlbgogICAgY3AgIiRFR0dfQ09OVFJPTExFUiIgIiR7RUdHX0NPTlRST0xMRVJ9LmJha18ke1RJTUVTVEFNUH0iCgogICAgcHl0aG9uMyA8PCAnUFlFT0YyJwppbXBvcnQgcmUKCmNvbnRyb2xsZXIgPSAiL3Zhci93d3cvcHRlcm9kYWN0eWwvYXBwL0h0dHAvQ29udHJvbGxlcnMvQWRtaW4vTmVzdHMvRWdnQ29udHJvbGxlci5waHAiCgp3aXRoIG9wZW4oY29udHJvbGxlciwgInIiKSBhcyBmOgogICAgY29udGVudCA9IGYucmVhZCgpCgppZiAiUFJPVEVLU0lfSkhPTkFMRVkiIGluIGNvbnRlbnQ6CiAgICBwcmludCgi4pqg77iPIFN1ZGFoIGFkYSBwcm90ZWtzaSBkaSBFZ2dDb250cm9sbGVyIikKICAgIGV4aXQoMCkKCmlmICJ1c2UgSWxsdW1pbmF0ZVxcU3VwcG9ydFxcRmFjYWRlc1xcQXV0aDsiIG5vdCBpbiBjb250ZW50OgogICAgY29udGVudCA9IGNvbnRlbnQucmVwbGFjZSgKICAgICAgICAidXNlIFB0ZXJvZGFjdHlsXFxIdHRwXFxDb250cm9sbGVyc1xcQ29udHJvbGxlcjsiLAogICAgICAgICJ1c2UgUHRlcm9kYWN0eWxcXEh0dHBcXENvbnRyb2xsZXJzXFxDb250cm9sbGVyO1xudXNlIElsbHVtaW5hdGVcXFN1cHBvcnRcXEZhY2FkZXNcXEF1dGg7IgogICAgKQoKbGluZXMgPSBjb250ZW50LnNwbGl0KCJcbiIpCm5ld19saW5lcyA9IFtdCmkgPSAwCndoaWxlIGkgPCBsZW4obGluZXMpOgogICAgbGluZSA9IGxpbmVzW2ldCiAgICBuZXdfbGluZXMuYXBwZW5kKGxpbmUpCgogICAgaWYgcmUuc2VhcmNoKHIncHVibGljIGZ1bmN0aW9uICg/IV9fY29uc3RydWN0KScsIGxpbmUpOgogICAgICAgIGogPSBpCiAgICAgICAgd2hpbGUgaiA8IGxlbihsaW5lcykgYW5kICd7JyBub3QgaW4gbGluZXNbal06CiAgICAgICAgICAgIGogKz0gMQogICAgICAgICAgICBpZiBqID4gaToKICAgICAgICAgICAgICAgIG5ld19saW5lcy5hcHBlbmQobGluZXNbal0pCgogICAgICAgIG5ld19saW5lcy5hcHBlbmQoIiAgICAgICAgLy8gUFJPVEVLU0lfSkhPTkFMRVk6IEhhbnlhIGFkbWluIElEIDEiKQogICAgICAgIG5ld19saW5lcy5hcHBlbmQoIiAgICAgICAgaWYgKCFBdXRoOjp1c2VyKCkgfHwgKGludCkgQXV0aDo6dXNlcigpLT5pZCAhPT0gMSkgeyIpCiAgICAgICAgbmV3X2xpbmVzLmFwcGVuZCgiICAgICAgICAgICAgYWJvcnQoNDAzLCAnQWtzZXMgZGl0b2xhayAtIHByb3RlY3QgYnkgSmhvbmFsZXkgVGVjaCcpOyIpCiAgICAgICAgbmV3X2xpbmVzLmFwcGVuZCgiICAgICAgICB9IikKCiAgICAgICAgaWYgaiA+IGk6CiAgICAgICAgICAgIGkgPSBqCiAgICBpICs9IDEKCndpdGggb3Blbihjb250cm9sbGVyLCAidyIpIGFzIGY6CiAgICBmLndyaXRlKCJcbiIuam9pbihuZXdfbGluZXMpKQoKcHJpbnQoIuKchSBFZ2dDb250cm9sbGVyIGp1Z2EgZGlwcm90ZWtzaSIpClBZRU9GMgogIGVsc2UKICAgIGVjaG8gIuKaoO+4jyBFZ2dDb250cm9sbGVyIHN1ZGFoIGRpcHJvdGVrc2kiCiAgZmkKZmkKCiMgPT09IExBTkdLQUggNDogU2VtYnVueWlrYW4gbWVudSBOZXN0cyBkaSBzaWRlYmFyID09PQplY2hvICLwn5SnIE1lbnllbWJ1bnlpa2FuIG1lbnUgTmVzdHMgZGFyaSBzaWRlYmFyLi4uIgoKU0lERUJBUl9GSUxFUz0oCiAgIi92YXIvd3d3L3B0ZXJvZGFjdHlsL3Jlc291cmNlcy92aWV3cy9wYXJ0aWFscy9hZG1pbi9zaWRlYmFyLmJsYWRlLnBocCIKICAiL3Zhci93d3cvcHRlcm9kYWN0eWwvcmVzb3VyY2VzL3ZpZXdzL2xheW91dHMvYWRtaW4uYmxhZGUucGhwIgogICIvdmFyL3d3dy9wdGVyb2RhY3R5bC9yZXNvdXJjZXMvdmlld3MvbGF5b3V0cy9hcHAuYmxhZGUucGhwIgopCgpTSURFQkFSX0ZPVU5EPSIiCmZvciBTRiBpbiAiJHtTSURFQkFSX0ZJTEVTW0BdfSI7IGRvCiAgaWYgWyAtZiAiJFNGIiBdICYmIGdyZXAgLXEgImFkbWluLm5lc3RzIiAiJFNGIiAyPi9kZXYvbnVsbDsgdGhlbgogICAgU0lERUJBUl9GT1VORD0iJFNGIgogICAgYnJlYWsKICBmaQpkb25lCgppZiBbIC16ICIkU0lERUJBUl9GT1VORCIgXTsgdGhlbgogIFNJREVCQVJfRk9VTkQ9JChncmVwIC1ybCAiYWRtaW4ubmVzdHMiIC92YXIvd3d3L3B0ZXJvZGFjdHlsL3Jlc291cmNlcy92aWV3cy9wYXJ0aWFscy8gMj4vZGV2L251bGwgfCBoZWFkIC0xKQogIGlmIFsgLXogIiRTSURFQkFSX0ZPVU5EIiBdOyB0aGVuCiAgICBTSURFQkFSX0ZPVU5EPSQoZ3JlcCAtcmwgImFkbWluLm5lc3RzIiAvdmFyL3d3dy9wdGVyb2RhY3R5bC9yZXNvdXJjZXMvdmlld3MvbGF5b3V0cy8gMj4vZGV2L251bGwgfCBoZWFkIC0xKQogIGZpCmZpCgppZiBbIC1uICIkU0lERUJBUl9GT1VORCIgXTsgdGhlbgogIGVjaG8gIvCfk4IgU2lkZWJhciBkaXRlbXVrYW46ICRTSURFQkFSX0ZPVU5EIgoKICBlY2hvICLwn5OLIEJhcmlzIHRlcmthaXQgTmVzdHMgZGkgc2lkZWJhcjoiCiAgZ3JlcCAtbiAtaSAibmVzdCIgIiRTSURFQkFSX0ZPVU5EIiB8IGhlYWQgLTEwCiAgZWNobyAiIgoKICBpZiAhIGNhbl9tb2RpZnlfZmlsZSAiJFNJREVCQVJfRk9VTkQiOyB0aGVuCiAgICBlY2hvICLimqDvuI8gU2lkZWJhciB0aWRhayB3cml0YWJsZSwgc2tpcCBzZW1idW55aWthbiBtZW51IE5lc3RzLiIKICBlbHNlCiAgICBjcCAiJFNJREVCQVJfRk9VTkQiICIke1NJREVCQVJfRk9VTkR9LmJha18ke1RJTUVTVEFNUH0iIDI+L2Rldi9udWxsIHx8IHRydWUKCiAgICBTSURFQkFSX1RFTVA9JChta3RlbXApCiAgICBleHBvcnQgU0lERUJBUl9GT1VORCBTSURFQkFSX1RFTVAKICAgIHB5dGhvbjMgPDwgJ1BZRU9GMycKaW1wb3J0IG9zCgpzaWRlYmFyID0gb3MuZW52aXJvblsiU0lERUJBUl9GT1VORCJdCnNpZGViYXJfdGVtcCA9IG9zLmVudmlyb25bIlNJREVCQVJfVEVNUCJdCgp3aXRoIG9wZW4oc2lkZWJhciwgInIiKSBhcyBmOgogICAgY29udGVudCA9IGYucmVhZCgpCgppZiAiUFJPVEVLU0lfTkVTVFNfU0lERUJBUiIgaW4gY29udGVudDoKICAgIHByaW50KCLimqDvuI8gU2lkZWJhciBOZXN0cyBzdWRhaCBkaXByb3Rla3NpIikKICAgIHJhaXNlIFN5c3RlbUV4aXQoMCkKCmxpbmVzID0gY29udGVudC5zcGxpdCgiXG4iKQpuZXdfbGluZXMgPSBbXQppID0gMAoKd2hpbGUgaSA8IGxlbihsaW5lcyk6CiAgICBsaW5lID0gbGluZXNbaV0KCiAgICBpZiAoJ2FkbWluLm5lc3RzJyBpbiBsaW5lIG9yICJyb3V0ZSgnYWRtaW4ubmVzdHMnKSIgaW4gbGluZSkgYW5kICdhZG1pbi5uZXN0cy52aWV3JyBub3QgaW4gbGluZSBhbmQgJ2FkbWluLm5lc3RzLmVnZycgbm90IGluIGxpbmU6CiAgICAgICAgbGlfc3RhcnQgPSBsZW4obmV3X2xpbmVzKSAtIDEKICAgICAgICB3aGlsZSBsaV9zdGFydCA+PSAwIGFuZCAnPGxpJyBub3QgaW4gbmV3X2xpbmVzW2xpX3N0YXJ0XToKICAgICAgICAgICAgbGlfc3RhcnQgLT0gMQoKICAgICAgICBpZiBsaV9zdGFydCA+PSAwOgogICAgICAgICAgICBuZXdfbGluZXMuaW5zZXJ0KGxpX3N0YXJ0LCAie3stLSBQUk9URUtTSV9ORVNUU19TSURFQkFSIC0tfX0iKQogICAgICAgICAgICBuZXdfbGluZXMuaW5zZXJ0KGxpX3N0YXJ0LCAiQGlmKChpbnQpIEF1dGg6OnVzZXIoKS0+aWQgPT09IDEpIikKCiAgICAgICAgICAgIG5ld19saW5lcy5hcHBlbmQobGluZSkKICAgICAgICAgICAgaSArPSAxCgogICAgICAgICAgICBsaV9kZXB0aCA9IDEKICAgICAgICAgICAgd2hpbGUgaSA8IGxlbihsaW5lcykgYW5kIGxpX2RlcHRoID4gMDoKICAgICAgICAgICAgICAgIGN1cnIgPSBsaW5lc1tpXQogICAgICAgICAgICAgICAgbGlfZGVwdGggKz0gY3Vyci5jb3VudCgnPGxpJykgLSBjdXJyLmNvdW50KCc8L2xpJykKICAgICAgICAgICAgICAgIG5ld19saW5lcy5hcHBlbmQoY3VycikKICAgICAgICAgICAgICAgIGkgKz0gMQoKICAgICAgICAgICAgbmV3X2xpbmVzLmFwcGVuZCgiQGVuZGlmIikKICAgICAgICAgICAgY29udGludWUKCiAgICBuZXdfbGluZXMuYXBwZW5kKGxpbmUpCiAgICBpICs9IDEKCndpdGggb3BlbihzaWRlYmFyX3RlbXAsICJ3IikgYXMgZjoKICAgIGYud3JpdGUoIlxuIi5qb2luKG5ld19saW5lcykpCgpwcmludCgi4pyFIFRlbXAgc2lkZWJhciBiZXJoYXNpbCBkaWJ1YXQiKQpQWUVPRjMKCiAgICBpZiB3cml0ZV90ZW1wX3RvX3RhcmdldCAiJFNJREVCQVJfVEVNUCIgIiRTSURFQkFSX0ZPVU5EIiAiJFNJREVCQVJfRk9VTkQiOyB0aGVuCiAgICAgIGVjaG8gIuKchSBNZW51IE5lc3RzIGRpc2VtYnVueWlrYW4gZGFyaSBzaWRlYmFyIgogICAgZWxzZQogICAgICBlY2hvICLimqDvuI8gR2FnYWwgbWVudWxpcyBwZXJ1YmFoYW4gc2lkZWJhciwgc2tpcCBsYW5na2FoIHNlbWJ1bnlpa2FuIG1lbnUuIgogICAgZmkKCiAgICBybSAtZiAiJFNJREVCQVJfVEVNUCIKICBmaQplbHNlCiAgZWNobyAi4pqg77iPIEZpbGUgc2lkZWJhciB0aWRhayBkaXRlbXVrYW4uIgpmaQoKIyA9PT0gTEFOR0tBSCA1OiBDYWNoZSBjbGVhciBkaS1oYW5kbGUgb2xlaCBjb250cm9sbGVyID09PQplY2hvICLihLnvuI8gQ2FjaGUgY2xlYXIgYWthbiBkaWxha3VrYW4gb2xlaCBQcm90ZWN0IE1hbmFnZXIgY29udHJvbGxlciBzZXRlbGFoIGluc3RhbGwgc2VsZXNhaSIKCmVjaG8gIiIKZWNobyAiPT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PSIKZWNobyAi4pyFIFByb3Rla3NpIE5lc3RzIExFTkdLQVAgc2VsZXNhaSEiCmVjaG8gIj09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT0iCmVjaG8gIvCflJIgTWVudSBOZXN0cyBkaXNlbWJ1bnlpa2FuIGRhcmkgc2lkZWJhciAoc2VsYWluIElEIDEpIgplY2hvICLwn5SSIEFrc2VzIC9hZG1pbi9uZXN0cyBkaWJsb2NrIChzZWxhaW4gSUQgMSkiCmVjaG8gIvCflJIgQWtzZXMgL2FkbWluL25lc3RzL3ZpZXcvKiBkaWJsb2NrIChzZWxhaW4gSUQgMSkiCmVjaG8gIvCflJIgRWdnQ29udHJvbGxlciBqdWdhIGRpcHJvdGVrc2kiCmVjaG8gIvCfmoAgUGFuZWwgdGV0YXAgbm9ybWFsLCBzZXJ2ZXIgdGV0YXAgamFsYW4iCmVjaG8gIj09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT0iCmVjaG8gIiIKZWNobyAi4pqg77iPIEppa2EgYWRhIG1hc2FsYWgsIHJlc3RvcmU6IgplY2hvICIgICBjcCAke0NPTlRST0xMRVJ9LmJha18ke1RJTUVTVEFNUH0gJENPTlRST0xMRVIiCmlmIFsgLW4gIiRTSURFQkFSX0ZPVU5EIiBdOyB0aGVuCiAgZWNobyAiICAgY3AgJHtTSURFQkFSX0ZPVU5EfS5iYWtfJHtUSU1FU1RBTVB9ICRTSURFQkFSX0ZPVU5EIgpmaQplY2hvICIgICBjZCAvdmFyL3d3dy9wdGVyb2RhY3R5bCAmJiBwaHAgYXJ0aXNhbiB2aWV3OmNsZWFyICYmIHBocCBhcnRpc2FuIHJvdXRlOmNsZWFyIgoKIyA9PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT0KIyA9PT0gQlJBTkRJTkc6IEluamVjdCBmb290ZXIgYnJhbmQga2UgbGF5b3V0IHBhbmVsID09PQojID09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PQplY2hvICIiCmVjaG8gIvCfjqggTWVtYXNhbmcgYnJhbmRpbmcgJEJSQU5EX05BTUUuLi4iCgpMQVlPVVRfRklMRVM9KAogICIvdmFyL3d3dy9wdGVyb2RhY3R5bC9yZXNvdXJjZXMvdmlld3MvbGF5b3V0cy9hZG1pbi5ibGFkZS5waHAiCiAgIi92YXIvd3d3L3B0ZXJvZGFjdHlsL3Jlc291cmNlcy92aWV3cy9sYXlvdXRzL2FwcC5ibGFkZS5waHAiCikKCiMgQ2xlYW51cCBicmFuZGluZyBsYW1hIGRhcmkgbWFzdGVyLmJsYWRlLnBocCBkYW4gYXV0aC5ibGFkZS5waHAgamlrYSBhZGEKZm9yIENMRUFOVVBfRklMRSBpbiAiL3Zhci93d3cvcHRlcm9kYWN0eWwvcmVzb3VyY2VzL3ZpZXdzL2xheW91dHMvbWFzdGVyLmJsYWRlLnBocCIgIi92YXIvd3d3L3B0ZXJvZGFjdHlsL3Jlc291cmNlcy92aWV3cy9sYXlvdXRzL2F1dGguYmxhZGUucGhwIjsgZG8KICBpZiBbIC1mICIkQ0xFQU5VUF9GSUxFIiBdICYmIGdyZXAgLXEgIkJSQU5ESU5HX0pIT05BTEVZIiAiJENMRUFOVVBfRklMRSIgMj4vZGV2L251bGw7IHRoZW4KICAgIGNsZWFudXBfb2xkX2JyYW5kaW5nICIkQ0xFQU5VUF9GSUxFIgogICAgZWNobyAi8J+nuSBCcmFuZGluZyBsYW1hIGRpaGFwdXMgZGFyaSAkKGJhc2VuYW1lICIkQ0xFQU5VUF9GSUxFIikiCiAgZmkKZG9uZQoKQlJBTkRJTkdfRk9VTkQ9MAoKaW5qZWN0X2JyYW5kaW5nKCkgewogIGxvY2FsIEZJTEU9IiQxIgogIGxvY2FsIExBQkVMPSIkMiIKCiAgaWYgWyAteiAiJEZJTEUiIF0gfHwgWyAhIC1mICIkRklMRSIgXTsgdGhlbgogICAgZWNobyAi4pqg77iPIEZpbGUgJExBQkVMIHRpZGFrIGRpdGVtdWthbjogJEZJTEUiCiAgICByZXR1cm4KICBmaQoKICBCUkFORElOR19GT1VORD0xCgogIGlmICEgY2FuX21vZGlmeV9maWxlICIkRklMRSI7IHRoZW4KICAgIGVjaG8gIuKaoO+4jyBGaWxlICRMQUJFTCB0aWRhayB3cml0YWJsZSwgc2tpcCBicmFuZGluZyBkaSBmaWxlIGluaSIKICAgIHJldHVybgogIGZpCgogIGlmIFsgISAtZiAiJHtGSUxFfS5iYWtfJHtUSU1FU1RBTVB9IiBdOyB0aGVuCiAgICBjcCAiJEZJTEUiICIke0ZJTEV9LmJha18ke1RJTUVTVEFNUH0iIDI+L2Rldi9udWxsIHx8IHRydWUKICBmaQoKICBjbGVhbnVwX29sZF9icmFuZGluZyAiJEZJTEUiCgogIEJSQU5ESU5HX1RNUD0iL3RtcC9icmFuZGluZ19pbmplY3RfJHtUSU1FU1RBTVB9XyQoYmFzZW5hbWUgIiRGSUxFIikuaHRtbCIKICBjYXQgPiAiJEJSQU5ESU5HX1RNUCIgPDwgQlJBTkRIVE1MCjwhLS0gQlJBTkRJTkdfSkhPTkFMRVlfU1RBUlQgLS0+CjxzdHlsZT4KICAuamhvbmFsZXktZm9vdGVyIHsKICAgIHBvc2l0aW9uOiBmaXhlZDsKICAgIGJvdHRvbTogMDsKICAgIGxlZnQ6IDA7CiAgICByaWdodDogMDsKICAgIHotaW5kZXg6IDk5OTk7CiAgICBiYWNrZ3JvdW5kOiBsaW5lYXItZ3JhZGllbnQoMTM1ZGVnLCAjMGMxOTI5LCAjMTMyZjRjLCAjMGEyNzQ0KTsKICAgIHBhZGRpbmc6IDEwcHggMjBweDsKICAgIHRleHQtYWxpZ246IGNlbnRlcjsKICAgIGJvcmRlci10b3A6IDJweCBzb2xpZCByZ2JhKDU5LCAxMzAsIDI0NiwgMC4zNSk7CiAgICBib3gtc2hhZG93OiAwIC00cHggMjBweCByZ2JhKDU5LCAxMzAsIDI0NiwgMC4xMik7CiAgICBmb250LWZhbWlseTogJ1NlZ29lIFVJJywgc3lzdGVtLXVpLCBzYW5zLXNlcmlmOwogIH0KICAuamhvbmFsZXktZm9vdGVyIC5qdC1pbm5lciB7CiAgICBkaXNwbGF5OiBmbGV4OwogICAgYWxpZ24taXRlbXM6IGNlbnRlcjsKICAgIGp1c3RpZnktY29udGVudDogY2VudGVyOwogICAgZ2FwOiA4cHg7CiAgICBmbGV4LXdyYXA6IHdyYXA7CiAgfQogIC5qaG9uYWxleS1mb290ZXIgLmp0LWJhZGdlIHsKICAgIGJhY2tncm91bmQ6IGxpbmVhci1ncmFkaWVudCgxMzVkZWcsICMwZjNlNjgsICMxZDc0YjcpOwogICAgY29sb3I6ICNlMGYyZmU7CiAgICBwYWRkaW5nOiA0cHggMTJweDsKICAgIGJvcmRlci1yYWRpdXM6IDIwcHg7CiAgICBmb250LXNpemU6IDExcHg7CiAgICBmb250LXdlaWdodDogNzAwOwogICAgbGV0dGVyLXNwYWNpbmc6IDFweDsKICAgIHRleHQtdHJhbnNmb3JtOiB1cHBlcmNhc2U7CiAgICBib3gtc2hhZG93OiAwIDJweCAxMHB4IHJnYmEoMjksIDExNiwgMTgzLCAwLjM1KTsKICB9CiAgLmpob25hbGV5LWZvb3RlciAuanQtdGV4dCB7CiAgICBjb2xvcjogI2NmZTdmZjsKICAgIGZvbnQtc2l6ZTogMTNweDsKICAgIGZvbnQtd2VpZ2h0OiA1MDA7CiAgfQogIC5qaG9uYWxleS1mb290ZXIgLmp0LXRleHQgYSB7CiAgICBjb2xvcjogIzdkZDNmYzsKICAgIHRleHQtZGVjb3JhdGlvbjogbm9uZTsKICAgIGZvbnQtd2VpZ2h0OiA3MDA7CiAgICB0cmFuc2l0aW9uOiBhbGwgMC4zcyBlYXNlOwogIH0KICAuamhvbmFsZXktZm9vdGVyIC5qdC10ZXh0IGE6aG92ZXIgewogICAgY29sb3I6ICNiYWU2ZmQ7CiAgfQogIC5qaG9uYWxleS1mb290ZXIgLmp0LXNlcGFyYXRvciB7CiAgICBjb2xvcjogIzJmNmZhMzsKICAgIGZvbnQtc2l6ZTogMTBweDsKICB9CiAgLmpob25hbGV5LWZvb3RlciAuanQtdGcgewogICAgZGlzcGxheTogaW5saW5lLWZsZXg7CiAgICBhbGlnbi1pdGVtczogY2VudGVyOwogICAgZ2FwOiA0cHg7CiAgICBiYWNrZ3JvdW5kOiByZ2JhKDU2LCAxODksIDI0OCwgMC4xMik7CiAgICBib3JkZXI6IDFweCBzb2xpZCByZ2JhKDU2LCAxODksIDI0OCwgMC4yOCk7CiAgICBwYWRkaW5nOiAzcHggMTBweDsKICAgIGJvcmRlci1yYWRpdXM6IDE1cHg7CiAgICBjb2xvcjogI2JhZTZmZDsKICAgIGZvbnQtc2l6ZTogMTJweDsKICAgIHRleHQtZGVjb3JhdGlvbjogbm9uZTsKICAgIHRyYW5zaXRpb246IGFsbCAwLjNzIGVhc2U7CiAgfQogIC5qaG9uYWxleS1mb290ZXIgLmp0LXRnOmhvdmVyIHsKICAgIGJhY2tncm91bmQ6IHJnYmEoNTYsIDE4OSwgMjQ4LCAwLjIyKTsKICAgIGJvcmRlci1jb2xvcjogcmdiYSgxMjUsIDIxMSwgMjUyLCAwLjU1KTsKICAgIGNvbG9yOiAjZTBmMmZlOwogICAgdHJhbnNmb3JtOiB0cmFuc2xhdGVZKC0xcHgpOwogIH0KICAuamhvbmFsZXktZm9vdGVyIC5qdC10ZyBzdmcgewogICAgd2lkdGg6IDE0cHg7CiAgICBoZWlnaHQ6IDE0cHg7CiAgICBmaWxsOiBjdXJyZW50Q29sb3I7CiAgfQogIC5qaG9uYWxleS1mb290ZXIgLmp0LXByb21vIHsKICAgIGNvbG9yOiAjZGJlYWZlOwogICAgZm9udC1zaXplOiAxMnB4OwogICAgZm9udC13ZWlnaHQ6IDYwMDsKICB9CiAgLmpob25hbGV5LWZvb3RlciAuanQtcHJvbW8gYSB7CiAgICBjb2xvcjogIzdkZDNmYzsKICAgIHRleHQtZGVjb3JhdGlvbjogbm9uZTsKICAgIGZvbnQtd2VpZ2h0OiA3MDA7CiAgfQogIC5qaG9uYWxleS1mb290ZXIgLmp0LXByb21vIGE6aG92ZXIgewogICAgY29sb3I6ICNlMGYyZmU7CiAgfQogIGJvZHkgewogICAgcGFkZGluZy1ib3R0b206IDUwcHggIWltcG9ydGFudDsKICB9Cjwvc3R5bGU+CjxkaXYgY2xhc3M9Impob25hbGV5LWZvb3RlciI+CiAgPGRpdiBjbGFzcz0ianQtaW5uZXIiPgogICAgPHNwYW4gY2xhc3M9Imp0LWJhZGdlIj4kQlJBTkRfVEVYVF9IVE1MPC9zcGFuPgogICAgPHNwYW4gY2xhc3M9Imp0LXRleHQiPlBhbmVsIGJ5IDxhIGhyZWY9Imh0dHBzOi8vdC5tZS8kVEVMRUdSQU1fVVNFUk5BTUUiIHRhcmdldD0iX2JsYW5rIj4kQlJBTkRfTkFNRV9IVE1MPC9hPjwvc3Bhbj4KICAgIDxzcGFuIGNsYXNzPSJqdC1zZXBhcmF0b3IiPuKXjzwvc3Bhbj4KICAgIDxhIGNsYXNzPSJqdC10ZyIgaHJlZj0iaHR0cHM6Ly90Lm1lLyRURUxFR1JBTV9VU0VSTkFNRSIgdGFyZ2V0PSJfYmxhbmsiPgogICAgICA8c3ZnIHZpZXdCb3g9IjAgMCAyNCAyNCI+PHBhdGggZD0iTTExLjk0NCAwQTEyIDEyIDAgMCAwIDAgMTJhMTIgMTIgMCAwIDAgMTIgMTIgMTIgMTIgMCAwIDAgMTItMTJBMTIgMTIgMCAwIDAgMTIgMGExMiAxMiAwIDAgMC0uMDU2IDB6bTQuOTYyIDcuMjI0Yy4xLS4wMDIuMzIxLjAyMy40NjUuMTRhLjUwNi41MDYgMCAwIDEgLjE3MS4zMjVjLjAxNi4wOTMuMDM2LjMwNi4wMi40NzItLjE4IDEuODk4LS45NjIgNi41MDItMS4zNiA4LjYyNy0uMTY4LjktLjQ5OSAxLjIwMS0uODIgMS4yMy0uNjk2LjA2NS0xLjIyNS0uNDYtMS45LS45MDItMS4wNTYtLjY5My0xLjY1My0xLjEyNC0yLjY3OC0xLjgtMS4xODUtLjc4LS40MTctMS4yMS4yNTgtMS45MS4xNzctLjE4NCAzLjI0Ny0yLjk3NyAzLjMwNy0zLjIzLjAwNy0uMDMyLjAxNC0uMTUtLjA1Ni0uMjEycy0uMTc0LS4wNDEtLjI0OS0uMDI0Yy0uMTA2LjAyNC0xLjc5MyAxLjE0LTUuMDYxIDMuMzQ1LS40OC4zMy0uOTEzLjQ5LTEuMzAyLjQ4LS40MjgtLjAwOC0xLjI1Mi0uMjQxLTEuODY1LS40NC0uNzUyLS4yNDUtMS4zNDktLjM3NC0xLjI5Ny0uNzg5LjAyNy0uMjE2LjMyNS0uNDM3Ljg5My0uNjYzIDMuNDk4LTEuNTI0IDUuODMtMi41MjkgNi45OTgtMy4wMTQgMy4zMzItMS4zODYgNC4wMjUtMS42MjcgNC40NzYtMS42MzV6Ii8+PC9zdmc+CiAgICAgICRDT05UQUNUX1RFTEVHUkFNX0hUTUwKICAgIDwvYT4KICAgIDxzcGFuIGNsYXNzPSJqdC1zZXBhcmF0b3IiPuKXjzwvc3Bhbj4KICAgIDxzcGFuIGNsYXNzPSJqdC1wcm9tbyI+QnV0dWggcGFuZWwgeWFuZyBhbnRpIG1va2FkPyBMYW5nc3VuZyBhamEga2UgPGEgaHJlZj0iaHR0cHM6Ly90Lm1lLyRCT1RfVVNFUk5BTUUiIHRhcmdldD0iX2JsYW5rIj4kQk9UX0xJTktfSFRNTDwvYT48L3NwYW4+CiAgPC9kaXY+CjwvZGl2Pgo8IS0tIEJSQU5ESU5HX0pIT05BTEVZX0VORCAtLT4KQlJBTkRIVE1MCgogIGluamVjdF9iZWZvcmVfY2xvc2luZyAiJEZJTEUiICIkQlJBTkRJTkdfVE1QIiAiJExBQkVMIgogIHJtIC1mICIkQlJBTkRJTkdfVE1QIgogIGVjaG8gIuKchSBCcmFuZGluZyBkaXBlcmJhcnVpIGRpICRMQUJFTCIKfQoKQlJBTkRJTkdfQVBQTElFRD0wCmZvciBMRiBpbiAiJHtMQVlPVVRfRklMRVNbQF19IjsgZG8KICBpZiBbIC1mICIkTEYiIF07IHRoZW4KICAgIGluamVjdF9icmFuZGluZyAiJExGIiAiJChiYXNlbmFtZSAiJExGIikiCiAgICBpZiBncmVwIC1xICJCUkFORElOR19KSE9OQUxFWSIgIiRMRiIgMj4vZGV2L251bGw7IHRoZW4KICAgICAgQlJBTkRJTkdfQVBQTElFRD0xCiAgICBmaQogIGZpCmRvbmUKCmlmIFsgIiRCUkFORElOR19BUFBMSUVEIiAtZXEgMCBdOyB0aGVuCiAgZWNobyAi4p2MIEJyYW5kaW5nIGFkbWluIGdhZ2FsIGRpcGFzYW5nOiBsYXlvdXQgYWRtaW4gdGlkYWsgZGl0ZW11a2FuIGF0YXUgdGlkYWsgdGVybW9kaWZpa2FzaSIKICBleGl0IDEKZmkKCmZvciBMRiBpbiAiJHtMQVlPVVRfRklMRVNbQF19IjsgZG8KICBpZiBbIC1mICIkTEYiIF0gJiYgZ3JlcCAtcSAiPHRpdGxlPiIgIiRMRiI7IHRoZW4KICAgIHNlZCAtaSAic3w8dGl0bGU+Lio8L3RpdGxlPnw8dGl0bGU+UHRlcm9kYWN0eWwgLSAkU0FGRV9USVRMRTwvdGl0bGU+fGciICIkTEYiIDI+L2Rldi9udWxsIHx8IHRydWUKICAgIGVjaG8gIuKchSBUaXRsZSBkaXViYWggZGkgJChiYXNlbmFtZSAiJExGIikiCiAgZmkKZG9uZQoKZWNobyAi4pyFIEJyYW5kaW5nIHNlbGVzYWkhIgoKIyA9PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT0KIyA9PT0gQkFHSUFOIDM6IFdlbGNvbWUgQmFubmVyIGRpIENsaWVudCBEYXNoYm9hcmQgPT09CiMgPT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09CmVjaG8gIiIKZWNobyAi4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSBIgplY2hvICLwn5OmIEJBR0lBTiAzOiBXZWxjb21lIEJhbm5lciBDbGllbnQgRGFzaGJvYXJkIgplY2hvICLilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIEiCgpXUkFQUEVSX0ZJTEU9Ii92YXIvd3d3L3B0ZXJvZGFjdHlsL3Jlc291cmNlcy92aWV3cy90ZW1wbGF0ZXMvd3JhcHBlci5ibGFkZS5waHAiCk1BU1RFUl9GSUxFPSIvdmFyL3d3dy9wdGVyb2RhY3R5bC9yZXNvdXJjZXMvdmlld3MvbGF5b3V0cy9tYXN0ZXIuYmxhZGUucGhwIgoKV0VMQ09NRV9UQVJHRVQ9IiIKaWYgWyAtZiAiJFdSQVBQRVJfRklMRSIgXTsgdGhlbgogIFdFTENPTUVfVEFSR0VUPSIkV1JBUFBFUl9GSUxFIgplbGlmIFsgLWYgIiRNQVNURVJfRklMRSIgXTsgdGhlbgogIFdFTENPTUVfVEFSR0VUPSIkTUFTVEVSX0ZJTEUiCmVsc2UKICBXRUxDT01FX1RBUkdFVD0kKGZpbmQgL3Zhci93d3cvcHRlcm9kYWN0eWwvcmVzb3VyY2VzL3ZpZXdzLyAtbmFtZSAid3JhcHBlci5ibGFkZS5waHAiIDI+L2Rldi9udWxsIHwgaGVhZCAtMSkKICBpZiBbIC16ICIkV0VMQ09NRV9UQVJHRVQiIF07IHRoZW4KICAgIFdFTENPTUVfVEFSR0VUPSQoZmluZCAvdmFyL3d3dy9wdGVyb2RhY3R5bC9yZXNvdXJjZXMvdmlld3MvdGVtcGxhdGVzLyAtbmFtZSAiKi5ibGFkZS5waHAiIDI+L2Rldi9udWxsIHwgaGVhZCAtMSkKICBmaQpmaQoKaWYgWyAteiAiJFdFTENPTUVfVEFSR0VUIiBdIHx8IFsgISAtZiAiJFdFTENPTUVfVEFSR0VUIiBdOyB0aGVuCiAgZWNobyAi4pqg77iPIEZpbGUgbGF5b3V0IGNsaWVudCB0aWRhayBkaXRlbXVrYW4sIHNraXAgd2VsY29tZSBiYW5uZXIuIgplbHNlCiAgZWNobyAi8J+TgiBUYXJnZXQ6ICRXRUxDT01FX1RBUkdFVCIKCiAgY3AgIiRXRUxDT01FX1RBUkdFVCIgIiR7V0VMQ09NRV9UQVJHRVR9LmJha18ke1RJTUVTVEFNUH0iIDI+L2Rldi9udWxsIHx8IHRydWUKICByZW1vdmVfYmxvY2tfYnlfbWFya2VycyAiJFdFTENPTUVfVEFSR0VUIiAiPCEtLSBXRUxDT01FX0pIT05BTEVZOiBXZWxjb21lIEJhbm5lciAtLT4iICI8IS0tIC9XRUxDT01FX0pIT05BTEVZIC0tPiIKCiAgV0VMQ09NRV9URU1QPSQobWt0ZW1wKQogIGNhdCA+ICIkV0VMQ09NRV9URU1QIiA8PCBXRUxDT01FX0VPRgo8IS0tIFdFTENPTUVfSkhPTkFMRVk6IFdlbGNvbWUgQmFubmVyIC0tPgo8c3R5bGU+CiAgLmpob25hbGV5LXdlbGNvbWUgewogICAgYmFja2dyb3VuZDogbGluZWFyLWdyYWRpZW50KDEzNWRlZywgIzBjMTkyOSwgIzEzMmY0YywgIzBhMjc0NCk7CiAgICBib3JkZXI6IDFweCBzb2xpZCByZ2JhKDU5LCAxMzAsIDI0NiwgMC40KTsKICAgIGJvcmRlci1sZWZ0OiA0cHggc29saWQgIzNiODJmNjsKICAgIGJvcmRlci1yYWRpdXM6IDhweDsKICAgIHBhZGRpbmc6IDE2cHggMjBweDsKICAgIG1hcmdpbjogMTZweDsKICAgIGRpc3BsYXk6IGZsZXg7CiAgICBhbGlnbi1pdGVtczogZmxleC1zdGFydDsKICAgIGdhcDogMTJweDsKICAgIGZvbnQtZmFtaWx5OiAiU2Vnb2UgVUkiLCBzeXN0ZW0tdWksIC1hcHBsZS1zeXN0ZW0sIHNhbnMtc2VyaWY7CiAgICBib3gtc2hhZG93OiAwIDRweCAyMHB4IHJnYmEoNTksIDEzMCwgMjQ2LCAwLjEpOwogIH0KICAuamhvbmFsZXktd2VsY29tZSAuanctaWNvbiB7CiAgICBiYWNrZ3JvdW5kOiByZ2JhKDU5LCAxMzAsIDI0NiwgMC4yKTsKICAgIGJvcmRlci1yYWRpdXM6IDUwJTsKICAgIHdpZHRoOiAzNnB4OyBoZWlnaHQ6IDM2cHg7IG1pbi13aWR0aDogMzZweDsKICAgIGRpc3BsYXk6IGZsZXg7IGFsaWduLWl0ZW1zOiBjZW50ZXI7IGp1c3RpZnktY29udGVudDogY2VudGVyOwogICAgZm9udC1zaXplOiAxOHB4OyBjb2xvcjogIzYwYTVmYTsgbWFyZ2luLXRvcDogMnB4OwogIH0KICAuamhvbmFsZXktd2VsY29tZSAuanctY29udGVudCBoMyB7CiAgICBjb2xvcjogIzkzYzVmZDsgZm9udC1zaXplOiAxNnB4OyBmb250LXdlaWdodDogNzAwOwogICAgbWFyZ2luOiAwIDAgNnB4IDA7IGxldHRlci1zcGFjaW5nOiAwLjNweDsKICB9CiAgLmpob25hbGV5LXdlbGNvbWUgLmp3LWNvbnRlbnQgcCB7CiAgICBjb2xvcjogIzk0YTNiODsgZm9udC1zaXplOiAxNHB4OyBtYXJnaW46IDA7IGxpbmUtaGVpZ2h0OiAxLjU7CiAgfQogIC5qaG9uYWxleS13ZWxjb21lIC5qdy1jb250ZW50IGEgewogICAgY29sb3I6ICNlMmU4ZjA7IGZvbnQtd2VpZ2h0OiA3MDA7IHRleHQtZGVjb3JhdGlvbjogbm9uZTsgdHJhbnNpdGlvbjogY29sb3IgMC4yczsKICB9CiAgLmpob25hbGV5LXdlbGNvbWUgLmp3LWNvbnRlbnQgYTpob3ZlciB7CiAgICBjb2xvcjogIzkzYzVmZDsgdGV4dC1zaGFkb3c6IDAgMCA4cHggcmdiYSgxNDcsIDE5NywgMjUzLCAwLjMpOwogIH0KPC9zdHlsZT4KPHNjcmlwdD4KZG9jdW1lbnQuYWRkRXZlbnRMaXN0ZW5lcigiRE9NQ29udGVudExvYWRlZCIsIGZ1bmN0aW9uKCkgewogIGZ1bmN0aW9uIGluamVjdFdlbGNvbWUoKSB7CiAgICBpZiAoZG9jdW1lbnQuZ2V0RWxlbWVudEJ5SWQoImpob25hbGV5LXdlbGNvbWUtYmFubmVyIikpIHJldHVybjsKICAgIHZhciBjb250YWluZXJzID0gWwogICAgICBkb2N1bWVudC5xdWVyeVNlbGVjdG9yKCJbY2xhc3MqPUNvbnRlbnRDb250YWluZXJdIiksCiAgICAgIGRvY3VtZW50LnF1ZXJ5U2VsZWN0b3IoIltjbGFzcyo9Y29udGVudC13cmFwcGVyXSIpLAogICAgICBkb2N1bWVudC5xdWVyeVNlbGVjdG9yKCIjYXBwID4gZGl2ID4gZGl2Omxhc3QtY2hpbGQiKSwKICAgICAgZG9jdW1lbnQucXVlcnlTZWxlY3RvcigibWFpbiIpLAogICAgICBkb2N1bWVudC5xdWVyeVNlbGVjdG9yKCIuY29udGVudC13cmFwcGVyIiksCiAgICAgIGRvY3VtZW50LnF1ZXJ5U2VsZWN0b3IoIiNhcHAiKQogICAgXTsKICAgIHZhciB0YXJnZXQgPSBudWxsOwogICAgZm9yICh2YXIgaSA9IDA7IGkgPCBjb250YWluZXJzLmxlbmd0aDsgaSsrKSB7CiAgICAgIGlmIChjb250YWluZXJzW2ldKSB7IHRhcmdldCA9IGNvbnRhaW5lcnNbaV07IGJyZWFrOyB9CiAgICB9CiAgICBpZiAoIXRhcmdldCkgcmV0dXJuOwogICAgdmFyIGJhbm5lciA9IGRvY3VtZW50LmNyZWF0ZUVsZW1lbnQoImRpdiIpOwogICAgYmFubmVyLmlkID0gImpob25hbGV5LXdlbGNvbWUtYmFubmVyIjsKICAgIGJhbm5lci5jbGFzc05hbWUgPSAiamhvbmFsZXktd2VsY29tZSI7CiAgICBiYW5uZXIuaW5uZXJIVE1MID0gJzxkaXYgY2xhc3M9Imp3LWljb24iPuKEue+4jzwvZGl2PjxkaXYgY2xhc3M9Imp3LWNvbnRlbnQiPjxoMz4kV0VMQ09NRV9USVRMRV9KUzwvaDM+PHA+JFdFTENPTUVfTUVTU0FHRV9KUzwvcD48L2Rpdj4nOwogICAgaWYgKHRhcmdldC5maXJzdENoaWxkKSB7IHRhcmdldC5pbnNlcnRCZWZvcmUoYmFubmVyLCB0YXJnZXQuZmlyc3RDaGlsZCk7IH0KICAgIGVsc2UgeyB0YXJnZXQuYXBwZW5kQ2hpbGQoYmFubmVyKTsgfQogIH0KICBpbmplY3RXZWxjb21lKCk7CiAgdmFyIG9ic2VydmVyID0gbmV3IE11dGF0aW9uT2JzZXJ2ZXIoZnVuY3Rpb24oKSB7CiAgICBpZiAoIWRvY3VtZW50LmdldEVsZW1lbnRCeUlkKCJqaG9uYWxleS13ZWxjb21lLWJhbm5lciIpKSBpbmplY3RXZWxjb21lKCk7CiAgfSk7CiAgdmFyIGFwcEVsID0gZG9jdW1lbnQuZ2V0RWxlbWVudEJ5SWQoImFwcCIpIHx8IGRvY3VtZW50LmJvZHk7CiAgb2JzZXJ2ZXIub2JzZXJ2ZShhcHBFbCwgeyBjaGlsZExpc3Q6IHRydWUsIHN1YnRyZWU6IHRydWUgfSk7Cn0pOwo8L3NjcmlwdD4KPCEtLSAvV0VMQ09NRV9KSE9OQUxFWSAtLT4KV0VMQ09NRV9FT0YKCiAgaW5qZWN0X2JlZm9yZV9jbG9zaW5nICIkV0VMQ09NRV9UQVJHRVQiICIkV0VMQ09NRV9URU1QIiAiJChiYXNlbmFtZSAiJFdFTENPTUVfVEFSR0VUIikiCiAgcm0gLWYgIiRXRUxDT01FX1RFTVAiCiAgZWNobyAi4pyFIFdlbGNvbWUgYmFubmVyIGRpcGVyYmFydWkgZGkgJChiYXNlbmFtZSAiJFdFTENPTUVfVEFSR0VUIikiCmZpCgojID09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT0KIyBSRS1JTkpFQ1QgU0lERUJBUiBQUk9URUNUIE1BTkFHRVIgKGppa2EgaGlsYW5nIHNldGVsYWggbW9kaWZpa2FzaSBhZG1pbi5ibGFkZS5waHApCiMgPT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PQpBRE1JTl9MQVlPVVQ9IiIKZm9yIENBTkRJREFURSBpbiBcCiAgIi92YXIvd3d3L3B0ZXJvZGFjdHlsL3Jlc291cmNlcy92aWV3cy9wYXJ0aWFscy9hZG1pbi9zaWRlYmFyLmJsYWRlLnBocCIgXAogICIvdmFyL3d3dy9wdGVyb2RhY3R5bC9yZXNvdXJjZXMvdmlld3MvbGF5b3V0cy9hZG1pbi5ibGFkZS5waHAiIFwKICAiL3Zhci93d3cvcHRlcm9kYWN0eWwvcmVzb3VyY2VzL3ZpZXdzL2xheW91dHMvYXBwLmJsYWRlLnBocCI7IGRvCiAgaWYgWyAtZiAiJENBTkRJREFURSIgXTsgdGhlbgogICAgQURNSU5fTEFZT1VUPSIkQ0FORElEQVRFIgogICAgYnJlYWsKICBmaQpkb25lCgppZiBbIC1mICIkQURNSU5fTEFZT1VUIiBdICYmICEgZ3JlcCAtcSAiUFJPVEVLU0lfSkhPTkFMRVlfTUFTVEVSX1NJREVCQVIiICIkQURNSU5fTEFZT1VUIiAyPi9kZXYvbnVsbDsgdGhlbgogIGVjaG8gIvCflKcgUmUtaW5qZWN0IHNpZGViYXIgUHJvdGVjdCBNYW5hZ2VyLi4uIgoKICBTSURFQkFSX1NOSVBQRVQ9JChta3RlbXApCiAgY2F0ID4gIiRTSURFQkFSX1NOSVBQRVQiIDw8ICdTSURFQkFSX1BNX0VPRicKICAgICAgICAgICAgICAgIHt7LS0gUFJPVEVLU0lfSkhPTkFMRVlfTUFTVEVSX1NJREVCQVI6IFByb3RlY3QgTWFuYWdlciBNZW51IC0tfX0KICAgICAgICAgICAgICAgIEBpZihBdXRoOjp1c2VyKCkgJiYgQXV0aDo6dXNlcigpLT5pZCA9PT0gMSkKICAgICAgICAgICAgICAgIDxsaSBjbGFzcz0ie3sgUm91dGU6OmN1cnJlbnRSb3V0ZU5hbWUoKSA9PT0gJ2FkbWluLnByb3RlY3QtbWFuYWdlcicgPyAnYWN0aXZlJyA6ICcnIH19Ij4KICAgICAgICAgICAgICAgICAgICA8YSBocmVmPSJ7eyByb3V0ZSgnYWRtaW4ucHJvdGVjdC1tYW5hZ2VyJykgfX0iPgogICAgICAgICAgICAgICAgICAgICAgICA8aSBjbGFzcz0iZmEgZmEtc2hpZWxkIj48L2k+IDxzcGFuPlByb3RlY3QgTWFuYWdlcjwvc3Bhbj4KICAgICAgICAgICAgICAgICAgICA8L2E+CiAgICAgICAgICAgICAgICA8L2xpPgogICAgICAgICAgICAgICAgQGVuZGlmCiAgICAgICAgICAgICAgICB7ey0tIEVORCBQUk9URUtTSV9KSE9OQUxFWV9NQVNURVJfU0lERUJBUiAtLX19ClNJREVCQVJfUE1fRU9GCgogIElOU0VSVF9MSU5FPSIiCiAgU0VUVElOR1NfTElORT0kKGdyZXAgLW4gImFkbWluLnNldHRpbmdzXHxDb25maWd1cmF0aW9uXHxTZXR0aW5nc1x8c2V0dGluZ3MiICIkQURNSU5fTEFZT1VUIiAyPi9kZXYvbnVsbCB8IGhlYWQgLTEgfCBjdXQgLWQ6IC1mMSkKICBpZiBbIC1uICIkU0VUVElOR1NfTElORSIgXTsgdGhlbgogICAgSU5TRVJUX0xJTkU9JCgoU0VUVElOR1NfTElORSAtIDEpKQogICAgd2hpbGUgWyAiJElOU0VSVF9MSU5FIiAtZ3QgMCBdOyBkbwogICAgICBpZiBzZWQgLW4gIiR7SU5TRVJUX0xJTkV9cCIgIiRBRE1JTl9MQVlPVVQiIHwgZ3JlcCAtcSAiPGxpIjsgdGhlbgogICAgICAgIGJyZWFrCiAgICAgIGZpCiAgICAgIElOU0VSVF9MSU5FPSQoKElOU0VSVF9MSU5FIC0gMSkpCiAgICBkb25lCiAgZmkKCiAgaWYgWyAteiAiJElOU0VSVF9MSU5FIiBdIHx8IFsgIiRJTlNFUlRfTElORSIgLWxlIDAgXTsgdGhlbgogICAgSU5TRVJUX0xJTkU9JChncmVwIC1uICI8L3VsPiIgIiRBRE1JTl9MQVlPVVQiIHwgdGFpbCAtMSB8IGN1dCAtZDogLWYxKQogICAgaWYgWyAtbiAiJElOU0VSVF9MSU5FIiBdOyB0aGVuCiAgICAgIElOU0VSVF9MSU5FPSQoKElOU0VSVF9MSU5FIC0gMSkpCiAgICBmaQogIGZpCgogIGlmIFsgLW4gIiRJTlNFUlRfTElORSIgXSAmJiBbICIkSU5TRVJUX0xJTkUiIC1ndCAwIF07IHRoZW4KICAgIFRFTVBfTEFZT1VUPSQobWt0ZW1wKQogICAgaGVhZCAtbiAiJElOU0VSVF9MSU5FIiAiJEFETUlOX0xBWU9VVCIgPiAiJFRFTVBfTEFZT1VUIgogICAgY2F0ICIkU0lERUJBUl9TTklQUEVUIiA+PiAiJFRFTVBfTEFZT1VUIgogICAgdGFpbCAtbiArIiQoKElOU0VSVF9MSU5FICsgMSkpIiAiJEFETUlOX0xBWU9VVCIgPj4gIiRURU1QX0xBWU9VVCIKICAgIGlmIGNhdCAiJFRFTVBfTEFZT1VUIiA+ICIkQURNSU5fTEFZT1VUIiAyPi9kZXYvbnVsbDsgdGhlbgogICAgICBlY2hvICLinIUgU2lkZWJhciBQcm90ZWN0IE1hbmFnZXIgYmVyaGFzaWwgZGktcmUtaW5qZWN0IgogICAgZWxzZQogICAgICBlY2hvICLimqDvuI8gR2FnYWwgcmUtaW5qZWN0IHNpZGViYXIsIHNraXAiCiAgICBmaQogICAgcm0gLWYgIiRURU1QX0xBWU9VVCIKICBlbHNlCiAgICBlY2hvICLimqDvuI8gVGlkYWsgYmlzYSBtZW5lbXVrYW4gcG9zaXNpIHNpZGViYXIgdW50dWsgcmUtaW5qZWN0IgogIGZpCiAgcm0gLWYgIiRTSURFQkFSX1NOSVBQRVQiCmZpCgojID09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT0KIyBDTEVBUiBDQUNIRSAtIGRpLWhhbmRsZSBvbGVoIGNvbnRyb2xsZXIKIyA9PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09CmVjaG8gIuKEue+4jyBDYWNoZSBjbGVhciBha2FuIGRpbGFrdWthbiBvbGVoIFByb3RlY3QgTWFuYWdlciBjb250cm9sbGVyIgoKZWNobyAiIgplY2hvICI9PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09IgplY2hvICLinIUgSU5TVEFMTFBST1RFQ1Q1IFNFTEVTQUkhIgplY2hvICI9PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09IgplY2hvICLwn5SSIE1lbnUgTmVzdHMgZGlzZW1idW55aWthbiAoc2VsYWluIElEIDEpIgplY2hvICLwn5SSIEFrc2VzIE5lc3RDb250cm9sbGVyIGRpYmxvY2sgKHNlbGFpbiBJRCAxKSIKZWNobyAi8J+OqCBCcmFuZGluZyBmb290ZXIgJEJSQU5EX05BTUUgdGVycGFzYW5nIChoYW55YSBhZG1pbikiCmVjaG8gIvCfk50gVGl0bGUgcGFuZWwgZGl1YmFoIgplY2hvICLwn5OLIFdlbGNvbWUgYmFubmVyIHRlcnBhc2FuZyBkaSBjbGllbnQgZGFzaGJvYXJkIgplY2hvICLwn5OxIEtvbnRhazogJENPTlRBQ1RfVEVMRUdSQU0iCmVjaG8gIj09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT0i
SCRIPT_INSTALLPROTECT5_SH,
            'installprotect6.sh' => <<<'SCRIPT_INSTALLPROTECT6_SH'
IyEvYmluL2Jhc2gKCkJSQU5EX05BTUU9IiR7QlJBTkRfTkFNRTotSmhvbmFsZXkgVGVjaH0iCkJSQU5EX1RFWFQ9IiR7QlJBTkRfVEVYVDotUHJvdGVjdCBCeSBKaG9uYWxleX0iCgpSRU1PVEVfUEFUSD0iL3Zhci93d3cvcHRlcm9kYWN0eWwvYXBwL0h0dHAvQ29udHJvbGxlcnMvQWRtaW4vU2V0dGluZ3MvSW5kZXhDb250cm9sbGVyLnBocCIKVElNRVNUQU1QPSQoZGF0ZSAtdSArIiVZLSVtLSVkLSVILSVNLSVTIikKQkFDS1VQX1BBVEg9IiR7UkVNT1RFX1BBVEh9LmJha18ke1RJTUVTVEFNUH0iCgplY2hvICLwn5qAIE1lbWFzYW5nIHByb3Rla3NpIEFudGkgQWtzZXMgU2V0dGluZ3MuLi4iCgppZiBbIC1mICIkUkVNT1RFX1BBVEgiIF07IHRoZW4KICBtdiAiJFJFTU9URV9QQVRIIiAiJEJBQ0tVUF9QQVRIIgogIGVjaG8gIvCfk6YgQmFja3VwIGZpbGUgbGFtYSBkaWJ1YXQgZGkgJEJBQ0tVUF9QQVRIIgpmaQoKbWtkaXIgLXAgIiQoZGlybmFtZSAiJFJFTU9URV9QQVRIIikiCmNobW9kIDc1NSAiJChkaXJuYW1lICIkUkVNT1RFX1BBVEgiKSIKCmNhdCA+ICIkUkVNT1RFX1BBVEgiIDw8ICdFT0YnCjw/cGhwCgpuYW1lc3BhY2UgUHRlcm9kYWN0eWxcSHR0cFxDb250cm9sbGVyc1xBZG1pblxTZXR0aW5nczsKCnVzZSBJbGx1bWluYXRlXFZpZXdcVmlldzsKdXNlIElsbHVtaW5hdGVcSHR0cFxSZWRpcmVjdFJlc3BvbnNlOwp1c2UgSWxsdW1pbmF0ZVxTdXBwb3J0XEZhY2FkZXNcQXV0aDsKdXNlIFByb2xvZ3VlXEFsZXJ0c1xBbGVydHNNZXNzYWdlQmFnOwp1c2UgSWxsdW1pbmF0ZVxDb250cmFjdHNcQ29uc29sZVxLZXJuZWw7CnVzZSBJbGx1bWluYXRlXFZpZXdcRmFjdG9yeSBhcyBWaWV3RmFjdG9yeTsKdXNlIFB0ZXJvZGFjdHlsXEh0dHBcQ29udHJvbGxlcnNcQ29udHJvbGxlcjsKdXNlIFB0ZXJvZGFjdHlsXFRyYWl0c1xIZWxwZXJzXEF2YWlsYWJsZUxhbmd1YWdlczsKdXNlIFB0ZXJvZGFjdHlsXFNlcnZpY2VzXEhlbHBlcnNcU29mdHdhcmVWZXJzaW9uU2VydmljZTsKdXNlIFB0ZXJvZGFjdHlsXENvbnRyYWN0c1xSZXBvc2l0b3J5XFNldHRpbmdzUmVwb3NpdG9yeUludGVyZmFjZTsKdXNlIFB0ZXJvZGFjdHlsXEh0dHBcUmVxdWVzdHNcQWRtaW5cU2V0dGluZ3NcQmFzZVNldHRpbmdzRm9ybVJlcXVlc3Q7CgpjbGFzcyBJbmRleENvbnRyb2xsZXIgZXh0ZW5kcyBDb250cm9sbGVyCnsKICAgIHVzZSBBdmFpbGFibGVMYW5ndWFnZXM7CgogICAgLyoqCiAgICAgKiBJbmRleENvbnRyb2xsZXIgY29uc3RydWN0b3IuCiAgICAgKi8KICAgIHB1YmxpYyBmdW5jdGlvbiBfX2NvbnN0cnVjdCgKICAgICAgICBwcml2YXRlIEFsZXJ0c01lc3NhZ2VCYWcgJGFsZXJ0LAogICAgICAgIHByaXZhdGUgS2VybmVsICRrZXJuZWwsCiAgICAgICAgcHJpdmF0ZSBTZXR0aW5nc1JlcG9zaXRvcnlJbnRlcmZhY2UgJHNldHRpbmdzLAogICAgICAgIHByaXZhdGUgU29mdHdhcmVWZXJzaW9uU2VydmljZSAkdmVyc2lvblNlcnZpY2UsCiAgICAgICAgcHJpdmF0ZSBWaWV3RmFjdG9yeSAkdmlldwogICAgKSB7CiAgICB9CgogICAgLyoqCiAgICAgKiBSZW5kZXIgdGhlIFVJIGZvciBiYXNpYyBQYW5lbCBzZXR0aW5ncy4KICAgICAqLwogICAgcHVibGljIGZ1bmN0aW9uIGluZGV4KCk6IFZpZXcKICAgIHsKICAgICAgICAvLyDwn5SSIEFudGkgYWtzZXMgbWVudSBTZXR0aW5ncyBzZWxhaW4gdXNlciBJRCAxCiAgICAgICAgJHVzZXIgPSBBdXRoOjp1c2VyKCk7CiAgICAgICAgaWYgKCEkdXNlciB8fCAkdXNlci0+aWQgIT09IDEpIHsKICAgICAgICAgICAgYWJvcnQoNDAzLCAnSmhvbmFsZXkgUHJvdGVjdCAtIEFrc2VzIGRpdG9sYWvinYwnKTsKICAgICAgICB9CgogICAgICAgIHJldHVybiAkdGhpcy0+dmlldy0+bWFrZSgnYWRtaW4uc2V0dGluZ3MuaW5kZXgnLCBbCiAgICAgICAgICAgICd2ZXJzaW9uJyA9PiAkdGhpcy0+dmVyc2lvblNlcnZpY2UsCiAgICAgICAgICAgICdsYW5ndWFnZXMnID0+ICR0aGlzLT5nZXRBdmFpbGFibGVMYW5ndWFnZXModHJ1ZSksCiAgICAgICAgXSk7CiAgICB9CgogICAgLyoqCiAgICAgKiBIYW5kbGUgc2V0dGluZ3MgdXBkYXRlLgogICAgICoKICAgICAqIEB0aHJvd3MgXFB0ZXJvZGFjdHlsXEV4Y2VwdGlvbnNcTW9kZWxcRGF0YVZhbGlkYXRpb25FeGNlcHRpb24KICAgICAqIEB0aHJvd3MgXFB0ZXJvZGFjdHlsXEV4Y2VwdGlvbnNcUmVwb3NpdG9yeVxSZWNvcmROb3RGb3VuZEV4Y2VwdGlvbgogICAgICovCiAgICBwdWJsaWMgZnVuY3Rpb24gdXBkYXRlKEJhc2VTZXR0aW5nc0Zvcm1SZXF1ZXN0ICRyZXF1ZXN0KTogUmVkaXJlY3RSZXNwb25zZQogICAgewogICAgICAgIC8vIPCflJIgQW50aSBha3NlcyB1cGRhdGUgc2V0dGluZ3Mgc2VsYWluIHVzZXIgSUQgMQogICAgICAgICR1c2VyID0gQXV0aDo6dXNlcigpOwogICAgICAgIGlmICghJHVzZXIgfHwgJHVzZXItPmlkICE9PSAxKSB7CiAgICAgICAgICAgIGFib3J0KDQwMywgJ0pob25hbGV5IFByb3RlY3QgdC5tZS9KaG9uYWxleSAtIEFrc2VzIGRpdG9sYWsnKTsKICAgICAgICB9CgogICAgICAgIGZvcmVhY2ggKCRyZXF1ZXN0LT5ub3JtYWxpemUoKSBhcyAka2V5ID0+ICR2YWx1ZSkgewogICAgICAgICAgICAkdGhpcy0+c2V0dGluZ3MtPnNldCgnc2V0dGluZ3M6OicgLiAka2V5LCAkdmFsdWUpOwogICAgICAgIH0KCiAgICAgICAgJHRoaXMtPmtlcm5lbC0+Y2FsbCgncXVldWU6cmVzdGFydCcpOwogICAgICAgICR0aGlzLT5hbGVydC0+c3VjY2VzcygKICAgICAgICAgICAgJ1BhbmVsIHNldHRpbmdzIGhhdmUgYmVlbiB1cGRhdGVkIHN1Y2Nlc3NmdWxseSBhbmQgdGhlIHF1ZXVlIHdvcmtlciB3YXMgcmVzdGFydGVkIHRvIGFwcGx5IHRoZXNlIGNoYW5nZXMuJwogICAgICAgICktPmZsYXNoKCk7CgogICAgICAgIHJldHVybiByZWRpcmVjdCgpLT5yb3V0ZSgnYWRtaW4uc2V0dGluZ3MnKTsKICAgIH0KfQpFT0YKCmNobW9kIDY0NCAiJFJFTU9URV9QQVRIIgoKIyBBcHBseSBicmFuZCBjdXN0b21pemF0aW9uCnNlZCAtaSAic3xKaG9uYWxleSBQcm90ZWN0fCR7QlJBTkRfVEVYVH18ZyIgIiRSRU1PVEVfUEFUSCIgMj4vZGV2L251bGwgfHwgdHJ1ZQpzZWQgLWkgInN8SmhvbmFsZXkgVGVjaHwke0JSQU5EX05BTUV9fGciICIkUkVNT1RFX1BBVEgiIDI+L2Rldi9udWxsIHx8IHRydWUKCmVjaG8gIuKchSBQcm90ZWtzaSBBbnRpIEFrc2VzIFNldHRpbmdzIGJlcmhhc2lsIGRpcGFzYW5nISIKZWNobyAi8J+TgiBMb2thc2kgZmlsZTogJFJFTU9URV9QQVRIIgplY2hvICLwn5eC77iPIEJhY2t1cCBmaWxlIGxhbWE6ICRCQUNLVVBfUEFUSCAoamlrYSBzZWJlbHVtbnlhIGFkYSkiCmVjaG8gIvCflJIgSGFueWEgQWRtaW4gKElEIDEpIHlhbmcgYmlzYSBBa3NlcyBTZXR0aW5ncy4iCg==
SCRIPT_INSTALLPROTECT6_SH,
            'installprotect7.sh' => <<<'SCRIPT_INSTALLPROTECT7_SH'
IyEvYmluL2Jhc2gKCkJSQU5EX05BTUU9IiR7QlJBTkRfTkFNRTotSmhvbmFsZXkgVGVjaH0iCkJSQU5EX1RFWFQ9IiR7QlJBTkRfVEVYVDotUHJvdGVjdCBCeSBKaG9uYWxleX0iCgpSRU1PVEVfUEFUSD0iL3Zhci93d3cvcHRlcm9kYWN0eWwvYXBwL0h0dHAvQ29udHJvbGxlcnMvQXBpL0NsaWVudC9TZXJ2ZXJzL0ZpbGVDb250cm9sbGVyLnBocCIKVElNRVNUQU1QPSQoZGF0ZSAtdSArIiVZLSVtLSVkLSVILSVNLSVTIikKQkFDS1VQX1BBVEg9IiR7UkVNT1RFX1BBVEh9LmJha18ke1RJTUVTVEFNUH0iCgplY2hvICLwn5qAIE1lbWFzYW5nIHByb3Rla3NpIEFudGkgQWtzZXMgU2VydmVyIEZpbGUgQ29udHJvbGxlci4uLiIKCmlmIFsgLWYgIiRSRU1PVEVfUEFUSCIgXTsgdGhlbgogIG12ICIkUkVNT1RFX1BBVEgiICIkQkFDS1VQX1BBVEgiCiAgZWNobyAi8J+TpiBCYWNrdXAgZmlsZSBsYW1hIGRpYnVhdCBkaSAkQkFDS1VQX1BBVEgiCmZpCgpta2RpciAtcCAiJChkaXJuYW1lICIkUkVNT1RFX1BBVEgiKSIKY2htb2QgNzU1ICIkKGRpcm5hbWUgIiRSRU1PVEVfUEFUSCIpIgoKY2F0ID4gIiRSRU1PVEVfUEFUSCIgPDwgJ0VPRicKPD9waHAKCm5hbWVzcGFjZSBQdGVyb2RhY3R5bFxIdHRwXENvbnRyb2xsZXJzXEFwaVxDbGllbnRcU2VydmVyczsKCnVzZSBDYXJib25cQ2FyYm9uSW1tdXRhYmxlOwp1c2UgSWxsdW1pbmF0ZVxIdHRwXFJlc3BvbnNlOwp1c2UgSWxsdW1pbmF0ZVxIdHRwXEpzb25SZXNwb25zZTsKdXNlIFB0ZXJvZGFjdHlsXE1vZGVsc1xTZXJ2ZXI7CnVzZSBQdGVyb2RhY3R5bFxGYWNhZGVzXEFjdGl2aXR5Owp1c2UgUHRlcm9kYWN0eWxcU2VydmljZXNcTm9kZXNcTm9kZUpXVFNlcnZpY2U7CnVzZSBQdGVyb2RhY3R5bFxSZXBvc2l0b3JpZXNcV2luZ3NcRGFlbW9uRmlsZVJlcG9zaXRvcnk7CnVzZSBQdGVyb2RhY3R5bFxUcmFuc2Zvcm1lcnNcQXBpXENsaWVudFxGaWxlT2JqZWN0VHJhbnNmb3JtZXI7CnVzZSBQdGVyb2RhY3R5bFxIdHRwXENvbnRyb2xsZXJzXEFwaVxDbGllbnRcQ2xpZW50QXBpQ29udHJvbGxlcjsKdXNlIFB0ZXJvZGFjdHlsXEh0dHBcUmVxdWVzdHNcQXBpXENsaWVudFxTZXJ2ZXJzXEZpbGVzXENvcHlGaWxlUmVxdWVzdDsKdXNlIFB0ZXJvZGFjdHlsXEh0dHBcUmVxdWVzdHNcQXBpXENsaWVudFxTZXJ2ZXJzXEZpbGVzXFB1bGxGaWxlUmVxdWVzdDsKdXNlIFB0ZXJvZGFjdHlsXEh0dHBcUmVxdWVzdHNcQXBpXENsaWVudFxTZXJ2ZXJzXEZpbGVzXExpc3RGaWxlc1JlcXVlc3Q7CnVzZSBQdGVyb2RhY3R5bFxIdHRwXFJlcXVlc3RzXEFwaVxDbGllbnRcU2VydmVyc1xGaWxlc1xDaG1vZEZpbGVzUmVxdWVzdDsKdXNlIFB0ZXJvZGFjdHlsXEh0dHBcUmVxdWVzdHNcQXBpXENsaWVudFxTZXJ2ZXJzXEZpbGVzXERlbGV0ZUZpbGVSZXF1ZXN0Owp1c2UgUHRlcm9kYWN0eWxcSHR0cFxSZXF1ZXN0c1xBcGlcQ2xpZW50XFNlcnZlcnNcRmlsZXNcUmVuYW1lRmlsZVJlcXVlc3Q7CnVzZSBQdGVyb2RhY3R5bFxIdHRwXFJlcXVlc3RzXEFwaVxDbGllbnRcU2VydmVyc1xGaWxlc1xDcmVhdGVGb2xkZXJSZXF1ZXN0Owp1c2UgUHRlcm9kYWN0eWxcSHR0cFxSZXF1ZXN0c1xBcGlcQ2xpZW50XFNlcnZlcnNcRmlsZXNcQ29tcHJlc3NGaWxlc1JlcXVlc3Q7CnVzZSBQdGVyb2RhY3R5bFxIdHRwXFJlcXVlc3RzXEFwaVxDbGllbnRcU2VydmVyc1xGaWxlc1xEZWNvbXByZXNzRmlsZXNSZXF1ZXN0Owp1c2UgUHRlcm9kYWN0eWxcSHR0cFxSZXF1ZXN0c1xBcGlcQ2xpZW50XFNlcnZlcnNcRmlsZXNcR2V0RmlsZUNvbnRlbnRzUmVxdWVzdDsKdXNlIFB0ZXJvZGFjdHlsXEh0dHBcUmVxdWVzdHNcQXBpXENsaWVudFxTZXJ2ZXJzXEZpbGVzXFdyaXRlRmlsZUNvbnRlbnRSZXF1ZXN0OwoKY2xhc3MgRmlsZUNvbnRyb2xsZXIgZXh0ZW5kcyBDbGllbnRBcGlDb250cm9sbGVyCnsKICAgIHB1YmxpYyBmdW5jdGlvbiBfX2NvbnN0cnVjdCgKICAgICAgICBwcml2YXRlIE5vZGVKV1RTZXJ2aWNlICRqd3RTZXJ2aWNlLAogICAgICAgIHByaXZhdGUgRGFlbW9uRmlsZVJlcG9zaXRvcnkgJGZpbGVSZXBvc2l0b3J5CiAgICApIHsKICAgICAgICBwYXJlbnQ6Ol9fY29uc3RydWN0KCk7CiAgICB9CgogICAgLyoqCiAgICAgKiDwn5SSIEZ1bmdzaSB0YW1iYWhhbjogQ2VnYWggYWtzZXMgc2VydmVyIG9yYW5nIGxhaW4uCiAgICAgKi8KICAgIHByaXZhdGUgZnVuY3Rpb24gY2hlY2tTZXJ2ZXJBY2Nlc3MoJHJlcXVlc3QsIFNlcnZlciAkc2VydmVyKQogICAgewogICAgICAgICR1c2VyID0gJHJlcXVlc3QtPnVzZXIoKTsKCiAgICAgICAgLy8gQWRtaW4gKHVzZXIgaWQgPSAxKSBiZWJhcyBha3NlcyBzZW11YQogICAgICAgIGlmICgoaW50KSAkdXNlci0+aWQgPT09IDEpIHsKICAgICAgICAgICAgcmV0dXJuOwogICAgICAgIH0KCiAgICAgICAgLy8gSmlrYSBzZXJ2ZXIgYnVrYW4gbWlsaWsgdXNlciwgdG9sYWsgYWtzZXMKICAgICAgICBpZiAoKGludCkgJHNlcnZlci0+b3duZXJfaWQgIT09IChpbnQpICR1c2VyLT5pZCkgewogICAgICAgICAgICBhYm9ydCg0MDMsICdBbmRhIHRpZGFrIG1lbWlsaWtpIGFrc2VzIGtlIHNlcnZlciBpbmkuJyk7CiAgICAgICAgfQogICAgfQoKICAgIHB1YmxpYyBmdW5jdGlvbiBkaXJlY3RvcnkoTGlzdEZpbGVzUmVxdWVzdCAkcmVxdWVzdCwgU2VydmVyICRzZXJ2ZXIpOiBhcnJheQogICAgewogICAgICAgICR0aGlzLT5jaGVja1NlcnZlckFjY2VzcygkcmVxdWVzdCwgJHNlcnZlcik7CgogICAgICAgICRjb250ZW50cyA9ICR0aGlzLT5maWxlUmVwb3NpdG9yeQogICAgICAgICAgICAtPnNldFNlcnZlcigkc2VydmVyKQogICAgICAgICAgICAtPmdldERpcmVjdG9yeSgkcmVxdWVzdC0+Z2V0KCdkaXJlY3RvcnknKSA/PyAnLycpOwoKICAgICAgICByZXR1cm4gJHRoaXMtPmZyYWN0YWwtPmNvbGxlY3Rpb24oJGNvbnRlbnRzKQogICAgICAgICAgICAtPnRyYW5zZm9ybVdpdGgoJHRoaXMtPmdldFRyYW5zZm9ybWVyKEZpbGVPYmplY3RUcmFuc2Zvcm1lcjo6Y2xhc3MpKQogICAgICAgICAgICAtPnRvQXJyYXkoKTsKICAgIH0KCiAgICBwdWJsaWMgZnVuY3Rpb24gY29udGVudHMoR2V0RmlsZUNvbnRlbnRzUmVxdWVzdCAkcmVxdWVzdCwgU2VydmVyICRzZXJ2ZXIpOiBSZXNwb25zZQogICAgewogICAgICAgICR0aGlzLT5jaGVja1NlcnZlckFjY2VzcygkcmVxdWVzdCwgJHNlcnZlcik7CgogICAgICAgICRyZXNwb25zZSA9ICR0aGlzLT5maWxlUmVwb3NpdG9yeS0+c2V0U2VydmVyKCRzZXJ2ZXIpLT5nZXRDb250ZW50KAogICAgICAgICAgICAkcmVxdWVzdC0+Z2V0KCdmaWxlJyksCiAgICAgICAgICAgIGNvbmZpZygncHRlcm9kYWN0eWwuZmlsZXMubWF4X2VkaXRfc2l6ZScpCiAgICAgICAgKTsKCiAgICAgICAgQWN0aXZpdHk6OmV2ZW50KCdzZXJ2ZXI6ZmlsZS5yZWFkJyktPnByb3BlcnR5KCdmaWxlJywgJHJlcXVlc3QtPmdldCgnZmlsZScpKS0+bG9nKCk7CgogICAgICAgIHJldHVybiBuZXcgUmVzcG9uc2UoJHJlc3BvbnNlLCBSZXNwb25zZTo6SFRUUF9PSywgWydDb250ZW50LVR5cGUnID0+ICd0ZXh0L3BsYWluJ10pOwogICAgfQoKICAgIHB1YmxpYyBmdW5jdGlvbiBkb3dubG9hZChHZXRGaWxlQ29udGVudHNSZXF1ZXN0ICRyZXF1ZXN0LCBTZXJ2ZXIgJHNlcnZlcik6IGFycmF5CiAgICB7CiAgICAgICAgJHRoaXMtPmNoZWNrU2VydmVyQWNjZXNzKCRyZXF1ZXN0LCAkc2VydmVyKTsKCiAgICAgICAgJHRva2VuID0gJHRoaXMtPmp3dFNlcnZpY2UKICAgICAgICAgICAgLT5zZXRFeHBpcmVzQXQoQ2FyYm9uSW1tdXRhYmxlOjpub3coKS0+YWRkTWludXRlcygxNSkpCiAgICAgICAgICAgIC0+c2V0VXNlcigkcmVxdWVzdC0+dXNlcigpKQogICAgICAgICAgICAtPnNldENsYWltcyhbCiAgICAgICAgICAgICAgICAnZmlsZV9wYXRoJyA9PiByYXd1cmxkZWNvZGUoJHJlcXVlc3QtPmdldCgnZmlsZScpKSwKICAgICAgICAgICAgICAgICdzZXJ2ZXJfdXVpZCcgPT4gJHNlcnZlci0+dXVpZCwKICAgICAgICAgICAgXSkKICAgICAgICAgICAgLT5oYW5kbGUoJHNlcnZlci0+bm9kZSwgJHJlcXVlc3QtPnVzZXIoKS0+aWQgLiAkc2VydmVyLT51dWlkKTsKCiAgICAgICAgQWN0aXZpdHk6OmV2ZW50KCdzZXJ2ZXI6ZmlsZS5kb3dubG9hZCcpLT5wcm9wZXJ0eSgnZmlsZScsICRyZXF1ZXN0LT5nZXQoJ2ZpbGUnKSktPmxvZygpOwoKICAgICAgICByZXR1cm4gWwogICAgICAgICAgICAnb2JqZWN0JyA9PiAnc2lnbmVkX3VybCcsCiAgICAgICAgICAgICdhdHRyaWJ1dGVzJyA9PiBbCiAgICAgICAgICAgICAgICAndXJsJyA9PiBzcHJpbnRmKAogICAgICAgICAgICAgICAgICAgICclcy9kb3dubG9hZC9maWxlP3Rva2VuPSVzJywKICAgICAgICAgICAgICAgICAgICAkc2VydmVyLT5ub2RlLT5nZXRDb25uZWN0aW9uQWRkcmVzcygpLAogICAgICAgICAgICAgICAgICAgICR0b2tlbi0+dG9TdHJpbmcoKQogICAgICAgICAgICAgICAgKSwKICAgICAgICAgICAgXSwKICAgICAgICBdOwogICAgfQoKICAgIHB1YmxpYyBmdW5jdGlvbiB3cml0ZShXcml0ZUZpbGVDb250ZW50UmVxdWVzdCAkcmVxdWVzdCwgU2VydmVyICRzZXJ2ZXIpOiBKc29uUmVzcG9uc2UKICAgIHsKICAgICAgICAkdGhpcy0+Y2hlY2tTZXJ2ZXJBY2Nlc3MoJHJlcXVlc3QsICRzZXJ2ZXIpOwoKICAgICAgICAkdGhpcy0+ZmlsZVJlcG9zaXRvcnktPnNldFNlcnZlcigkc2VydmVyKS0+cHV0Q29udGVudCgkcmVxdWVzdC0+Z2V0KCdmaWxlJyksICRyZXF1ZXN0LT5nZXRDb250ZW50KCkpOwoKICAgICAgICBBY3Rpdml0eTo6ZXZlbnQoJ3NlcnZlcjpmaWxlLndyaXRlJyktPnByb3BlcnR5KCdmaWxlJywgJHJlcXVlc3QtPmdldCgnZmlsZScpKS0+bG9nKCk7CgogICAgICAgIHJldHVybiBuZXcgSnNvblJlc3BvbnNlKFtdLCBSZXNwb25zZTo6SFRUUF9OT19DT05URU5UKTsKICAgIH0KCiAgICBwdWJsaWMgZnVuY3Rpb24gY3JlYXRlKENyZWF0ZUZvbGRlclJlcXVlc3QgJHJlcXVlc3QsIFNlcnZlciAkc2VydmVyKTogSnNvblJlc3BvbnNlCiAgICB7CiAgICAgICAgJHRoaXMtPmNoZWNrU2VydmVyQWNjZXNzKCRyZXF1ZXN0LCAkc2VydmVyKTsKCiAgICAgICAgJHRoaXMtPmZpbGVSZXBvc2l0b3J5CiAgICAgICAgICAgIC0+c2V0U2VydmVyKCRzZXJ2ZXIpCiAgICAgICAgICAgIC0+Y3JlYXRlRGlyZWN0b3J5KCRyZXF1ZXN0LT5pbnB1dCgnbmFtZScpLCAkcmVxdWVzdC0+aW5wdXQoJ3Jvb3QnLCAnLycpKTsKCiAgICAgICAgQWN0aXZpdHk6OmV2ZW50KCdzZXJ2ZXI6ZmlsZS5jcmVhdGUtZGlyZWN0b3J5JykKICAgICAgICAgICAgLT5wcm9wZXJ0eSgnbmFtZScsICRyZXF1ZXN0LT5pbnB1dCgnbmFtZScpKQogICAgICAgICAgICAtPnByb3BlcnR5KCdkaXJlY3RvcnknLCAkcmVxdWVzdC0+aW5wdXQoJ3Jvb3QnKSkKICAgICAgICAgICAgLT5sb2coKTsKCiAgICAgICAgcmV0dXJuIG5ldyBKc29uUmVzcG9uc2UoW10sIFJlc3BvbnNlOjpIVFRQX05PX0NPTlRFTlQpOwogICAgfQoKICAgIHB1YmxpYyBmdW5jdGlvbiByZW5hbWUoUmVuYW1lRmlsZVJlcXVlc3QgJHJlcXVlc3QsIFNlcnZlciAkc2VydmVyKTogSnNvblJlc3BvbnNlCiAgICB7CiAgICAgICAgJHRoaXMtPmNoZWNrU2VydmVyQWNjZXNzKCRyZXF1ZXN0LCAkc2VydmVyKTsKCiAgICAgICAgJHRoaXMtPmZpbGVSZXBvc2l0b3J5CiAgICAgICAgICAgIC0+c2V0U2VydmVyKCRzZXJ2ZXIpCiAgICAgICAgICAgIC0+cmVuYW1lRmlsZXMoJHJlcXVlc3QtPmlucHV0KCdyb290JyksICRyZXF1ZXN0LT5pbnB1dCgnZmlsZXMnKSk7CgogICAgICAgIEFjdGl2aXR5OjpldmVudCgnc2VydmVyOmZpbGUucmVuYW1lJykKICAgICAgICAgICAgLT5wcm9wZXJ0eSgnZGlyZWN0b3J5JywgJHJlcXVlc3QtPmlucHV0KCdyb290JykpCiAgICAgICAgICAgIC0+cHJvcGVydHkoJ2ZpbGVzJywgJHJlcXVlc3QtPmlucHV0KCdmaWxlcycpKQogICAgICAgICAgICAtPmxvZygpOwoKICAgICAgICByZXR1cm4gbmV3IEpzb25SZXNwb25zZShbXSwgUmVzcG9uc2U6OkhUVFBfTk9fQ09OVEVOVCk7CiAgICB9CgogICAgcHVibGljIGZ1bmN0aW9uIGNvcHkoQ29weUZpbGVSZXF1ZXN0ICRyZXF1ZXN0LCBTZXJ2ZXIgJHNlcnZlcik6IEpzb25SZXNwb25zZQogICAgewogICAgICAgICR0aGlzLT5jaGVja1NlcnZlckFjY2VzcygkcmVxdWVzdCwgJHNlcnZlcik7CgogICAgICAgICR0aGlzLT5maWxlUmVwb3NpdG9yeQogICAgICAgICAgICAtPnNldFNlcnZlcigkc2VydmVyKQogICAgICAgICAgICAtPmNvcHlGaWxlKCRyZXF1ZXN0LT5pbnB1dCgnbG9jYXRpb24nKSk7CgogICAgICAgIEFjdGl2aXR5OjpldmVudCgnc2VydmVyOmZpbGUuY29weScpLT5wcm9wZXJ0eSgnZmlsZScsICRyZXF1ZXN0LT5pbnB1dCgnbG9jYXRpb24nKSktPmxvZygpOwoKICAgICAgICByZXR1cm4gbmV3IEpzb25SZXNwb25zZShbXSwgUmVzcG9uc2U6OkhUVFBfTk9fQ09OVEVOVCk7CiAgICB9CgogICAgcHVibGljIGZ1bmN0aW9uIGNvbXByZXNzKENvbXByZXNzRmlsZXNSZXF1ZXN0ICRyZXF1ZXN0LCBTZXJ2ZXIgJHNlcnZlcik6IGFycmF5CiAgICB7CiAgICAgICAgJHRoaXMtPmNoZWNrU2VydmVyQWNjZXNzKCRyZXF1ZXN0LCAkc2VydmVyKTsKCiAgICAgICAgJGZpbGUgPSAkdGhpcy0+ZmlsZVJlcG9zaXRvcnktPnNldFNlcnZlcigkc2VydmVyKS0+Y29tcHJlc3NGaWxlcygKICAgICAgICAgICAgJHJlcXVlc3QtPmlucHV0KCdyb290JyksCiAgICAgICAgICAgICRyZXF1ZXN0LT5pbnB1dCgnZmlsZXMnKQogICAgICAgICk7CgogICAgICAgIEFjdGl2aXR5OjpldmVudCgnc2VydmVyOmZpbGUuY29tcHJlc3MnKQogICAgICAgICAgICAtPnByb3BlcnR5KCdkaXJlY3RvcnknLCAkcmVxdWVzdC0+aW5wdXQoJ3Jvb3QnKSkKICAgICAgICAgICAgLT5wcm9wZXJ0eSgnZmlsZXMnLCAkcmVxdWVzdC0+aW5wdXQoJ2ZpbGVzJykpCiAgICAgICAgICAgIC0+bG9nKCk7CgogICAgICAgIHJldHVybiAkdGhpcy0+ZnJhY3RhbC0+aXRlbSgkZmlsZSkKICAgICAgICAgICAgLT50cmFuc2Zvcm1XaXRoKCR0aGlzLT5nZXRUcmFuc2Zvcm1lcihGaWxlT2JqZWN0VHJhbnNmb3JtZXI6OmNsYXNzKSkKICAgICAgICAgICAgLT50b0FycmF5KCk7CiAgICB9CgogICAgcHVibGljIGZ1bmN0aW9uIGRlY29tcHJlc3MoRGVjb21wcmVzc0ZpbGVzUmVxdWVzdCAkcmVxdWVzdCwgU2VydmVyICRzZXJ2ZXIpOiBKc29uUmVzcG9uc2UKICAgIHsKICAgICAgICAkdGhpcy0+Y2hlY2tTZXJ2ZXJBY2Nlc3MoJHJlcXVlc3QsICRzZXJ2ZXIpOwoKICAgICAgICBzZXRfdGltZV9saW1pdCgzMDApOwoKICAgICAgICAkdGhpcy0+ZmlsZVJlcG9zaXRvcnktPnNldFNlcnZlcigkc2VydmVyKS0+ZGVjb21wcmVzc0ZpbGUoCiAgICAgICAgICAgICRyZXF1ZXN0LT5pbnB1dCgncm9vdCcpLAogICAgICAgICAgICAkcmVxdWVzdC0+aW5wdXQoJ2ZpbGUnKQogICAgICAgICk7CgogICAgICAgIEFjdGl2aXR5OjpldmVudCgnc2VydmVyOmZpbGUuZGVjb21wcmVzcycpCiAgICAgICAgICAgIC0+cHJvcGVydHkoJ2RpcmVjdG9yeScsICRyZXF1ZXN0LT5pbnB1dCgncm9vdCcpKQogICAgICAgICAgICAtPnByb3BlcnR5KCdmaWxlcycsICRyZXF1ZXN0LT5pbnB1dCgnZmlsZScpKQogICAgICAgICAgICAtPmxvZygpOwoKICAgICAgICByZXR1cm4gbmV3IEpzb25SZXNwb25zZShbXSwgSnNvblJlc3BvbnNlOjpIVFRQX05PX0NPTlRFTlQpOwogICAgfQoKICAgIHB1YmxpYyBmdW5jdGlvbiBkZWxldGUoRGVsZXRlRmlsZVJlcXVlc3QgJHJlcXVlc3QsIFNlcnZlciAkc2VydmVyKTogSnNvblJlc3BvbnNlCiAgICB7CiAgICAgICAgJHRoaXMtPmNoZWNrU2VydmVyQWNjZXNzKCRyZXF1ZXN0LCAkc2VydmVyKTsKCiAgICAgICAgJHRoaXMtPmZpbGVSZXBvc2l0b3J5LT5zZXRTZXJ2ZXIoJHNlcnZlciktPmRlbGV0ZUZpbGVzKAogICAgICAgICAgICAkcmVxdWVzdC0+aW5wdXQoJ3Jvb3QnKSwKICAgICAgICAgICAgJHJlcXVlc3QtPmlucHV0KCdmaWxlcycpCiAgICAgICAgKTsKCiAgICAgICAgQWN0aXZpdHk6OmV2ZW50KCdzZXJ2ZXI6ZmlsZS5kZWxldGUnKQogICAgICAgICAgICAtPnByb3BlcnR5KCdkaXJlY3RvcnknLCAkcmVxdWVzdC0+aW5wdXQoJ3Jvb3QnKSkKICAgICAgICAgICAgLT5wcm9wZXJ0eSgnZmlsZXMnLCAkcmVxdWVzdC0+aW5wdXQoJ2ZpbGVzJykpCiAgICAgICAgICAgIC0+bG9nKCk7CgogICAgICAgIHJldHVybiBuZXcgSnNvblJlc3BvbnNlKFtdLCBSZXNwb25zZTo6SFRUUF9OT19DT05URU5UKTsKICAgIH0KCiAgICBwdWJsaWMgZnVuY3Rpb24gY2htb2QoQ2htb2RGaWxlc1JlcXVlc3QgJHJlcXVlc3QsIFNlcnZlciAkc2VydmVyKTogSnNvblJlc3BvbnNlCiAgICB7CiAgICAgICAgJHRoaXMtPmNoZWNrU2VydmVyQWNjZXNzKCRyZXF1ZXN0LCAkc2VydmVyKTsKCiAgICAgICAgJHRoaXMtPmZpbGVSZXBvc2l0b3J5LT5zZXRTZXJ2ZXIoJHNlcnZlciktPmNobW9kRmlsZXMoCiAgICAgICAgICAgICRyZXF1ZXN0LT5pbnB1dCgncm9vdCcpLAogICAgICAgICAgICAkcmVxdWVzdC0+aW5wdXQoJ2ZpbGVzJykKICAgICAgICApOwoKICAgICAgICByZXR1cm4gbmV3IEpzb25SZXNwb25zZShbXSwgUmVzcG9uc2U6OkhUVFBfTk9fQ09OVEVOVCk7CiAgICB9CgogICAgcHVibGljIGZ1bmN0aW9uIHB1bGwoUHVsbEZpbGVSZXF1ZXN0ICRyZXF1ZXN0LCBTZXJ2ZXIgJHNlcnZlcik6IEpzb25SZXNwb25zZQogICAgewogICAgICAgICR0aGlzLT5jaGVja1NlcnZlckFjY2VzcygkcmVxdWVzdCwgJHNlcnZlcik7CgogICAgICAgICR0aGlzLT5maWxlUmVwb3NpdG9yeS0+c2V0U2VydmVyKCRzZXJ2ZXIpLT5wdWxsKAogICAgICAgICAgICAkcmVxdWVzdC0+aW5wdXQoJ3VybCcpLAogICAgICAgICAgICAkcmVxdWVzdC0+aW5wdXQoJ2RpcmVjdG9yeScpLAogICAgICAgICAgICAkcmVxdWVzdC0+c2FmZShbJ2ZpbGVuYW1lJywgJ3VzZV9oZWFkZXInLCAnZm9yZWdyb3VuZCddKQogICAgICAgICk7CgogICAgICAgIEFjdGl2aXR5OjpldmVudCgnc2VydmVyOmZpbGUucHVsbCcpCiAgICAgICAgICAgIC0+cHJvcGVydHkoJ2RpcmVjdG9yeScsICRyZXF1ZXN0LT5pbnB1dCgnZGlyZWN0b3J5JykpCiAgICAgICAgICAgIC0+cHJvcGVydHkoJ3VybCcsICRyZXF1ZXN0LT5pbnB1dCgndXJsJykpCiAgICAgICAgICAgIC0+bG9nKCk7CgogICAgICAgIHJldHVybiBuZXcgSnNvblJlc3BvbnNlKFtdLCBSZXNwb25zZTo6SFRUUF9OT19DT05URU5UKTsKICAgIH0KfQpFT0YKCmNobW9kIDY0NCAiJFJFTU9URV9QQVRIIgoKIyBBcHBseSBicmFuZCBjdXN0b21pemF0aW9uCnNlZCAtaSAic3xBbmRhIHRpZGFrIG1lbWlsaWtpIGFrc2VzIGtlIHNlcnZlciBpbml8JHtCUkFORF9URVhUfSAtIEFrc2VzIGRpdG9sYWt8ZyIgIiRSRU1PVEVfUEFUSCIgMj4vZGV2L251bGwgfHwgdHJ1ZQoKZWNobyAi4pyFIFByb3Rla3NpIEFudGkgQWtzZXMgU2VydmVyIEZpbGUgQ29udHJvbGxlciBiZXJoYXNpbCBkaXBhc2FuZyEiCmVjaG8gIvCfk4IgTG9rYXNpIGZpbGU6ICRSRU1PVEVfUEFUSCIKZWNobyAi8J+Xgu+4jyBCYWNrdXAgZmlsZSBsYW1hOiAkQkFDS1VQX1BBVEggKGppa2Egc2ViZWx1bW55YSBhZGEpIgplY2hvICLwn5SSIEhhbnlhIEFkbWluIChJRCAxKSB5YW5nIGJpc2EgQWtzZXMgU2VydmVyIEZpbGUgQ29udHJvbGxlci4iCg==
SCRIPT_INSTALLPROTECT7_SH,
            'installprotect8.sh' => <<<'SCRIPT_INSTALLPROTECT8_SH'
IyEvYmluL2Jhc2gKCkJSQU5EX05BTUU9IiR7QlJBTkRfTkFNRTotSmhvbmFsZXkgVGVjaH0iCkJSQU5EX1RFWFQ9IiR7QlJBTkRfVEVYVDotUHJvdGVjdCBCeSBKaG9uYWxleX0iCgpSRU1PVEVfUEFUSD0iL3Zhci93d3cvcHRlcm9kYWN0eWwvYXBwL0h0dHAvQ29udHJvbGxlcnMvQXBpL0NsaWVudC9TZXJ2ZXJzL1NlcnZlckNvbnRyb2xsZXIucGhwIgpUSU1FU1RBTVA9JChkYXRlIC11ICsiJVktJW0tJWQtJUgtJU0tJVMiKQpCQUNLVVBfUEFUSD0iJHtSRU1PVEVfUEFUSH0uYmFrXyR7VElNRVNUQU1QfSIKCmVjaG8gIsOwxbjFoeKCrCBNZW1hc2FuZyBwcm90ZWtzaSBBbnRpIEFrc2VzIFNlcnZlciBDb250cm9sbGVyLi4uIgoKaWYgWyAtZiAiJFJFTU9URV9QQVRIIiBdOyB0aGVuCiAgbXYgIiRSRU1PVEVfUEFUSCIgIiRCQUNLVVBfUEFUSCIKICBlY2hvICLDsMW44oCcwqYgQmFja3VwIGZpbGUgbGFtYSBkaWJ1YXQgZGkgJEJBQ0tVUF9QQVRIIgpmaQoKbWtkaXIgLXAgIiQoZGlybmFtZSAiJFJFTU9URV9QQVRIIikiCmNobW9kIDc1NSAiJChkaXJuYW1lICIkUkVNT1RFX1BBVEgiKSIKCmNhdCA+ICIkUkVNT1RFX1BBVEgiIDw8ICdFT0YnCjw/cGhwCgpuYW1lc3BhY2UgUHRlcm9kYWN0eWxcSHR0cFxDb250cm9sbGVyc1xBcGlcQ2xpZW50XFNlcnZlcnM7Cgp1c2UgSWxsdW1pbmF0ZVxTdXBwb3J0XEZhY2FkZXNcQXV0aDsKdXNlIFB0ZXJvZGFjdHlsXE1vZGVsc1xTZXJ2ZXI7CnVzZSBQdGVyb2RhY3R5bFxUcmFuc2Zvcm1lcnNcQXBpXENsaWVudFxTZXJ2ZXJUcmFuc2Zvcm1lcjsKdXNlIFB0ZXJvZGFjdHlsXFNlcnZpY2VzXFNlcnZlcnNcR2V0VXNlclBlcm1pc3Npb25zU2VydmljZTsKdXNlIFB0ZXJvZGFjdHlsXEh0dHBcQ29udHJvbGxlcnNcQXBpXENsaWVudFxDbGllbnRBcGlDb250cm9sbGVyOwp1c2UgUHRlcm9kYWN0eWxcSHR0cFxSZXF1ZXN0c1xBcGlcQ2xpZW50XFNlcnZlcnNcR2V0U2VydmVyUmVxdWVzdDsKCmNsYXNzIFNlcnZlckNvbnRyb2xsZXIgZXh0ZW5kcyBDbGllbnRBcGlDb250cm9sbGVyCnsKICAgIC8qKgogICAgICogU2VydmVyQ29udHJvbGxlciBjb25zdHJ1Y3Rvci4KICAgICAqLwogICAgcHVibGljIGZ1bmN0aW9uIF9fY29uc3RydWN0KHByaXZhdGUgR2V0VXNlclBlcm1pc3Npb25zU2VydmljZSAkcGVybWlzc2lvbnNTZXJ2aWNlKQogICAgewogICAgICAgIHBhcmVudDo6X19jb25zdHJ1Y3QoKTsKICAgIH0KCiAgICAvKioKICAgICAqIFRyYW5zZm9ybSBhbiBpbmRpdmlkdWFsIHNlcnZlciBpbnRvIGEgcmVzcG9uc2UgdGhhdCBjYW4gYmUgY29uc3VtZWQgYnkgYQogICAgICogY2xpZW50IHVzaW5nIHRoZSBBUEkuCiAgICAgKi8KICAgIHB1YmxpYyBmdW5jdGlvbiBpbmRleChHZXRTZXJ2ZXJSZXF1ZXN0ICRyZXF1ZXN0LCBTZXJ2ZXIgJHNlcnZlcik6IGFycmF5CiAgICB7CiAgICAgICAgLy8g8J+UkiBBbnRpIGludGlwIHNlcnZlciBvcmFuZyBsYWluIChrZWN1YWxpIGFkbWluIElEIDEpCiAgICAgICAgJGF1dGhVc2VyID0gQXV0aDo6dXNlcigpOwoKICAgICAgICBpZiAoKGludCkgJGF1dGhVc2VyLT5pZCAhPT0gMSAmJiAoaW50KSAkc2VydmVyLT5vd25lcl9pZCAhPT0gKGludCkgJGF1dGhVc2VyLT5pZCkgewogICAgICAgICAgICBhYm9ydCg0MDMsICdA8J2ZhfCdmYPwnZmK8J2ZifCdmLzwnZmH8J2ZgPCdmZQg8J2Zj/CdmYDwnZi+8J2ZgyDigKIg8J2XlPCdl7jwnZiA8J2XsvCdmIAg8J2Xl/Cdl7Yg8J2Xp/Cdl7zwnZe58J2XrvCdl7jinYwuIPCdl5vwnZeu8J2Xu/CdmIbwnZeuIPCdl5XwnZe28J2YgPCdl64g8J2XoPCdl7LwnZe58J2XtvCdl7XwnZeu8J2YgSDwnZem8J2XsvCdl7/wnZiD8J2XsvCdl78g8J2XoPCdl7bwnZe58J2XtvCdl7gg8J2XpvCdl7LwnZe78J2XsfCdl7bwnZe/8J2Xti4nKTsKICAgICAgICB9CgogICAgICAgIHJldHVybiAkdGhpcy0+ZnJhY3RhbC0+aXRlbSgkc2VydmVyKQogICAgICAgICAgICAtPnRyYW5zZm9ybVdpdGgoJHRoaXMtPmdldFRyYW5zZm9ybWVyKFNlcnZlclRyYW5zZm9ybWVyOjpjbGFzcykpCiAgICAgICAgICAgIC0+YWRkTWV0YShbCiAgICAgICAgICAgICAgICAnaXNfc2VydmVyX293bmVyJyA9PiAkcmVxdWVzdC0+dXNlcigpLT5pZCA9PT0gJHNlcnZlci0+b3duZXJfaWQsCiAgICAgICAgICAgICAgICAndXNlcl9wZXJtaXNzaW9ucycgPT4gJHRoaXMtPnBlcm1pc3Npb25zU2VydmljZS0+aGFuZGxlKCRzZXJ2ZXIsICRyZXF1ZXN0LT51c2VyKCkpLAogICAgICAgICAgICBdKQogICAgICAgICAgICAtPnRvQXJyYXkoKTsKICAgIH0KfQpFT0YKCmNobW9kIDY0NCAiJFJFTU9URV9QQVRIIgoKIyBBcHBseSBicmFuZCBjdXN0b21pemF0aW9uIC0gcmVwbGFjZSB0aGUgdW5pY29kZSBhYm9ydCBtZXNzYWdlCkFCT1JUX0xJTkU9JChncmVwIC1uICJhYm9ydCg0MDMiICIkUkVNT1RFX1BBVEgiIHwgaGVhZCAtMSB8IGN1dCAtZDogLWYxKQppZiBbIC1uICIkQUJPUlRfTElORSIgXTsgdGhlbgogIHNlZCAtaSAiJHtBQk9SVF9MSU5FfXN8YWJvcnQoNDAzLC4qfGFib3J0KDQwMywgJyR7QlJBTkRfVEVYVH0gLSBBa3NlcyBEaXRvbGFrLiBIYW55YSBCaXNhIE1lbGloYXQgU2VydmVyIE1pbGlrIFNlbmRpcmkuJyk7fCIgIiRSRU1PVEVfUEFUSCIgMj4vZGV2L251bGwgfHwgdHJ1ZQpmaQoKZWNobyAi4pyFIFByb3Rla3NpIEFudGkgQWtzZXMgU2VydmVyIENvbnRyb2xsZXIgYmVyaGFzaWwgZGlwYXNhbmchIgplY2hvICLDsMW44oCc4oCaIExva2FzaSBmaWxlOiAkUkVNT1RFX1BBVEgiCmVjaG8gIsOwxbjigJTigJrDr8K4wo8gQmFja3VwIGZpbGUgbGFtYTogJEJBQ0tVUF9QQVRIIChqaWthIHNlYmVsdW1ueWEgYWRhKSIKZWNobyAiw7DFuOKAneKAmSBIYW55YSBBZG1pbiAoSUQgMSkgeWFuZyBiaXNhIEFrc2VzIFNlcnZlciBDb250cm9sbGVyLiIK
SCRIPT_INSTALLPROTECT8_SH,
            'installprotect9.sh' => <<<'SCRIPT_INSTALLPROTECT9_SH'
IyEvYmluL2Jhc2gKCkJSQU5EX05BTUU9IiR7QlJBTkRfTkFNRTotSmhvbmFsZXkgVGVjaH0iCkJSQU5EX1RFWFQ9IiR7QlJBTkRfVEVYVDotUHJvdGVjdCBCeSBKaG9uYWxleX0iCgpSRU1PVEVfUEFUSD0iL3Zhci93d3cvcHRlcm9kYWN0eWwvYXBwL1NlcnZpY2VzL1NlcnZlcnMvRGV0YWlsc01vZGlmaWNhdGlvblNlcnZpY2UucGhwIgpUSU1FU1RBTVA9JChkYXRlIC11ICsiJVktJW0tJWQtJUgtJU0tJVMiKQpCQUNLVVBfUEFUSD0iJHtSRU1PVEVfUEFUSH0uYmFrXyR7VElNRVNUQU1QfSIKCmVjaG8gIvCfmoAgTWVtYXNhbmcgcHJvdGVrc2kgQW50aSBNb2RpZmlrYXNpIFNlcnZlci4uLiIKCmlmIFsgLWYgIiRSRU1PVEVfUEFUSCIgXTsgdGhlbgogIG12ICIkUkVNT1RFX1BBVEgiICIkQkFDS1VQX1BBVEgiCiAgZWNobyAi8J+TpiBCYWNrdXAgZmlsZSBsYW1hIGRpYnVhdCBkaSAkQkFDS1VQX1BBVEgiCmZpCgpta2RpciAtcCAiJChkaXJuYW1lICIkUkVNT1RFX1BBVEgiKSIKY2htb2QgNzU1ICIkKGRpcm5hbWUgIiRSRU1PVEVfUEFUSCIpIgoKY2F0ID4gIiRSRU1PVEVfUEFUSCIgPDwgJ0VPRicKPD9waHAKCm5hbWVzcGFjZSBQdGVyb2RhY3R5bFxTZXJ2aWNlc1xTZXJ2ZXJzOwoKdXNlIElsbHVtaW5hdGVcU3VwcG9ydFxBcnI7CnVzZSBQdGVyb2RhY3R5bFxNb2RlbHNcU2VydmVyOwp1c2UgSWxsdW1pbmF0ZVxTdXBwb3J0XEZhY2FkZXNcQXV0aDsKdXNlIElsbHVtaW5hdGVcRGF0YWJhc2VcQ29ubmVjdGlvbkludGVyZmFjZTsKdXNlIFB0ZXJvZGFjdHlsXFRyYWl0c1xTZXJ2aWNlc1xSZXR1cm5zVXBkYXRlZE1vZGVsczsKdXNlIFB0ZXJvZGFjdHlsXFJlcG9zaXRvcmllc1xXaW5nc1xEYWVtb25TZXJ2ZXJSZXBvc2l0b3J5Owp1c2UgUHRlcm9kYWN0eWxcRXhjZXB0aW9uc1xIdHRwXENvbm5lY3Rpb25cRGFlbW9uQ29ubmVjdGlvbkV4Y2VwdGlvbjsKCmNsYXNzIERldGFpbHNNb2RpZmljYXRpb25TZXJ2aWNlCnsKICAgIHVzZSBSZXR1cm5zVXBkYXRlZE1vZGVsczsKCiAgICBwdWJsaWMgZnVuY3Rpb24gX19jb25zdHJ1Y3QoCiAgICAgICAgcHJpdmF0ZSBDb25uZWN0aW9uSW50ZXJmYWNlICRjb25uZWN0aW9uLAogICAgICAgIHByaXZhdGUgRGFlbW9uU2VydmVyUmVwb3NpdG9yeSAkc2VydmVyUmVwb3NpdG9yeQogICAgKSB7fQoKICAgIC8qKgogICAgICogVXBkYXRlIHRoZSBkZXRhaWxzIGZvciBhIHNpbmdsZSBzZXJ2ZXIgaW5zdGFuY2UuCiAgICAgKgogICAgICogQHRocm93cyBcVGhyb3dhYmxlCiAgICAgKi8KICAgIHB1YmxpYyBmdW5jdGlvbiBoYW5kbGUoU2VydmVyICRzZXJ2ZXIsIGFycmF5ICRkYXRhKTogU2VydmVyCiAgICB7CiAgICAgICAgLy8g8J+aqyBCYXRhc2kgYWtzZXMgaGFueWEgdW50dWsgdXNlciBJRCAxCiAgICAgICAgJHVzZXIgPSBBdXRoOjp1c2VyKCk7CiAgICAgICAgaWYgKCEkdXNlciB8fCAoaW50KSAkdXNlci0+aWQgIT09IDEpIHsKICAgICAgICAgICAgYWJvcnQoNDAzLCAnQWtzZXMgZGl0b2xhazogaGFueWEgYWRtaW4gdXRhbWEgeWFuZyBiaXNhIG1lbmd1YmFoIGRldGFpbCBzZXJ2ZXIuJyk7CiAgICAgICAgfQoKICAgICAgICByZXR1cm4gJHRoaXMtPmNvbm5lY3Rpb24tPnRyYW5zYWN0aW9uKGZ1bmN0aW9uICgpIHVzZSAoJGRhdGEsICRzZXJ2ZXIpIHsKICAgICAgICAgICAgJG93bmVyID0gJHNlcnZlci0+b3duZXJfaWQ7CgogICAgICAgICAgICAkc2VydmVyLT5mb3JjZUZpbGwoWwogICAgICAgICAgICAgICAgJ2V4dGVybmFsX2lkJyA9PiBBcnI6OmdldCgkZGF0YSwgJ2V4dGVybmFsX2lkJyksCiAgICAgICAgICAgICAgICAnb3duZXJfaWQnID0+IEFycjo6Z2V0KCRkYXRhLCAnb3duZXJfaWQnKSwKICAgICAgICAgICAgICAgICduYW1lJyA9PiBBcnI6OmdldCgkZGF0YSwgJ25hbWUnKSwKICAgICAgICAgICAgICAgICdkZXNjcmlwdGlvbicgPT4gQXJyOjpnZXQoJGRhdGEsICdkZXNjcmlwdGlvbicpID8/ICcnLAogICAgICAgICAgICBdKS0+c2F2ZU9yRmFpbCgpOwoKICAgICAgICAgICAgLy8gSmlrYSBvd25lciBiZXJ1YmFoLCByZXZva2UgdG9rZW4gbGFtYQogICAgICAgICAgICBpZiAoJHNlcnZlci0+b3duZXJfaWQgIT09ICRvd25lcikgewogICAgICAgICAgICAgICAgdHJ5IHsKICAgICAgICAgICAgICAgICAgICAkdGhpcy0+c2VydmVyUmVwb3NpdG9yeS0+c2V0U2VydmVyKCRzZXJ2ZXIpLT5yZXZva2VVc2VySlRJKCRvd25lcik7CiAgICAgICAgICAgICAgICB9IGNhdGNoIChEYWVtb25Db25uZWN0aW9uRXhjZXB0aW9uICRleGNlcHRpb24pIHsKICAgICAgICAgICAgICAgICAgICAvLyBBYmFpa2FuIGVycm9yIGRhcmkgV2luZ3Mgb2ZmbGluZQogICAgICAgICAgICAgICAgfQogICAgICAgICAgICB9CgogICAgICAgICAgICByZXR1cm4gJHNlcnZlcjsKICAgICAgICB9KTsKICAgIH0KfQpFT0YKCmNobW9kIDY0NCAiJFJFTU9URV9QQVRIIgoKIyBBcHBseSBicmFuZCBjdXN0b21pemF0aW9uCnNlZCAtaSAic3xBa3NlcyBkaXRvbGFrOiBoYW55YSBhZG1pbiB1dGFtYSB5YW5nIGJpc2EgbWVuZ3ViYWggZGV0YWlsIHNlcnZlci58JHtCUkFORF9URVhUfSAtIEFrc2VzIGRpdG9sYWsufGciICIkUkVNT1RFX1BBVEgiIDI+L2Rldi9udWxsIHx8IHRydWUKCmVjaG8gIuKchSBQcm90ZWtzaSBBbnRpIE1vZGlmaWthc2kgU2VydmVyIGJlcmhhc2lsIGRpcGFzYW5nISIKZWNobyAi8J+TgiBMb2thc2kgZmlsZTogJFJFTU9URV9QQVRIIgplY2hvICLwn5eC77iPIEJhY2t1cCBmaWxlIGxhbWE6ICRCQUNLVVBfUEFUSCAoamlrYSBzZWJlbHVtbnlhIGFkYSkiCmVjaG8gIvCflJIgSGFueWEgQWRtaW4gKElEIDEpIHlhbmcgYmlzYSBNb2RpZmlrYXNpIFNlcnZlci4iCg==
SCRIPT_INSTALLPROTECT9_SH,
            'installprotect10.sh' => <<<'SCRIPT_INSTALLPROTECT10_SH'
IyEvYmluL2Jhc2gKCkJSQU5EX05BTUU9IiR7QlJBTkRfTkFNRTotSmhvbmFsZXkgVGVjaH0iCkJSQU5EX1RFWFQ9IiR7QlJBTkRfVEVYVDotUHJvdGVjdCBCeSBKaG9uYWxleX0iCkNPTlRBQ1RfVEVMRUdSQU09IiR7Q09OVEFDVF9URUxFR1JBTTotQGRhbmFuZ3ZhbGVudHB9IgoKZWNobyAi8J+agCBNZW1hc2FuZyBwcm90ZWtzaSBBbnRpIFRhdXRhbiBTZXJ2ZXIuLi4iCgpJTkRFWF9GSUxFPSIvdmFyL3d3dy9wdGVyb2RhY3R5bC9yZXNvdXJjZXMvdmlld3MvYWRtaW4vc2VydmVycy9pbmRleC5ibGFkZS5waHAiClRJTUVTVEFNUD0kKGRhdGUgLXUgKyIlWS0lbS0lZC0lSC0lTS0lUyIpCgppZiBbIC1mICIkSU5ERVhfRklMRSIgXTsgdGhlbgogIGNwICIkSU5ERVhfRklMRSIgIiR7SU5ERVhfRklMRX0uYmFrXyR7VElNRVNUQU1QfSIKICBlY2hvICLwn5OmIEJhY2t1cCBpbmRleCBmaWxlIGRpYnVhdDogJHtJTkRFWF9GSUxFfS5iYWtfJHtUSU1FU1RBTVB9IgpmaQoKY2F0ID4gIiRJTkRFWF9GSUxFIiA8PCAnRU9GJwpAZXh0ZW5kcygnbGF5b3V0cy5hZG1pbicpCkBzZWN0aW9uKCd0aXRsZScpCiAgICBTZXJ2ZXJzCkBlbmRzZWN0aW9uCgpAc2VjdGlvbignY29udGVudC1oZWFkZXInKQogICAgPGgxPlNlcnZlcnM8c21hbGw+QWxsIHNlcnZlcnMgYXZhaWxhYmxlIG9uIHRoZSBzeXN0ZW0uPC9zbWFsbD48L2gxPgogICAgPG9sIGNsYXNzPSJicmVhZGNydW1iIj4KICAgICAgICA8bGk+PGEgaHJlZj0ie3sgcm91dGUoJ2FkbWluLmluZGV4JykgfX0iPkFkbWluPC9hPjwvbGk+CiAgICAgICAgPGxpIGNsYXNzPSJhY3RpdmUiPlNlcnZlcnM8L2xpPgogICAgPC9vbD4KQGVuZHNlY3Rpb24KCkBzZWN0aW9uKCdjb250ZW50JykKPGRpdiBjbGFzcz0icm93Ij4KICAgIDxkaXYgY2xhc3M9ImNvbC14cy0xMiI+CiAgICAgICAgPGRpdiBjbGFzcz0iYm94IGJveC1wcmltYXJ5Ij4KICAgICAgICAgICAgPGRpdiBjbGFzcz0iYm94LWhlYWRlciB3aXRoLWJvcmRlciI+CiAgICAgICAgICAgICAgICA8aDMgY2xhc3M9ImJveC10aXRsZSI+U2VydmVyIExpc3Q8L2gzPgogICAgICAgICAgICAgICAgPGRpdiBjbGFzcz0iYm94LXRvb2xzIHNlYXJjaDAxIj4KICAgICAgICAgICAgICAgICAgICA8Zm9ybSBhY3Rpb249Int7IHJvdXRlKCdhZG1pbi5zZXJ2ZXJzJykgfX0iIG1ldGhvZD0iR0VUIj4KICAgICAgICAgICAgICAgICAgICAgICAgPGRpdiBjbGFzcz0iaW5wdXQtZ3JvdXAgaW5wdXQtZ3JvdXAtc20iPgogICAgICAgICAgICAgICAgICAgICAgICAgICAgPGlucHV0IHR5cGU9InRleHQiIG5hbWU9InF1ZXJ5IiBjbGFzcz0iZm9ybS1jb250cm9sIHB1bGwtcmlnaHQiIHZhbHVlPSJ7eyByZXF1ZXN0KCktPmlucHV0KCdxdWVyeScpIH19IiBwbGFjZWhvbGRlcj0iU2VhcmNoIFNlcnZlcnMiPgogICAgICAgICAgICAgICAgICAgICAgICAgICAgPGRpdiBjbGFzcz0iaW5wdXQtZ3JvdXAtYnRuIj4KICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICA8YnV0dG9uIHR5cGU9InN1Ym1pdCIgY2xhc3M9ImJ0biBidG4tZGVmYXVsdCI+PGkgY2xhc3M9ImZhIGZhLXNlYXJjaCI+PC9pPjwvYnV0dG9uPgogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIDxhIGhyZWY9Int7IHJvdXRlKCdhZG1pbi5zZXJ2ZXJzLm5ldycpIH19Ij48YnV0dG9uIHR5cGU9ImJ1dHRvbiIgY2xhc3M9ImJ0biBidG4tc20gYnRuLXByaW1hcnkiIHN0eWxlPSJib3JkZXItcmFkaXVzOjAgM3B4IDNweCAwO21hcmdpbi1sZWZ0OjJweDsiPkNyZWF0ZSBOZXc8L2J1dHRvbj48L2E+CiAgICAgICAgICAgICAgICAgICAgICAgICAgICA8L2Rpdj4KICAgICAgICAgICAgICAgICAgICAgICAgPC9kaXY+CiAgICAgICAgICAgICAgICAgICAgPC9mb3JtPgogICAgICAgICAgICAgICAgPC9kaXY+CiAgICAgICAgICAgIDwvZGl2PgogICAgICAgICAgICA8ZGl2IGNsYXNzPSJib3gtYm9keSB0YWJsZS1yZXNwb25zaXZlIG5vLXBhZGRpbmciPgogICAgICAgICAgICAgICAgPHRhYmxlIGNsYXNzPSJ0YWJsZSB0YWJsZS1ob3ZlciI+CiAgICAgICAgICAgICAgICAgICAgPHRoZWFkPgogICAgICAgICAgICAgICAgICAgICAgICA8dHI+CiAgICAgICAgICAgICAgICAgICAgICAgICAgICA8dGg+U2VydmVyIE5hbWU8L3RoPgogICAgICAgICAgICAgICAgICAgICAgICAgICAgPHRoPlVVSUQ8L3RoPgogICAgICAgICAgICAgICAgICAgICAgICAgICAgPHRoPk93bmVyPC90aD4KICAgICAgICAgICAgICAgICAgICAgICAgICAgIDx0aD5Ob2RlPC90aD4KICAgICAgICAgICAgICAgICAgICAgICAgICAgIDx0aD5Db25uZWN0aW9uPC90aD4KICAgICAgICAgICAgICAgICAgICAgICAgICAgIDx0aCBjbGFzcz0idGV4dC1jZW50ZXIiPkFjdGlvbnM8L3RoPgogICAgICAgICAgICAgICAgICAgICAgICA8L3RyPgogICAgICAgICAgICAgICAgICAgIDwvdGhlYWQ+CiAgICAgICAgICAgICAgICAgICAgPHRib2R5PgogICAgICAgICAgICAgICAgICAgICAgICBAZm9yZWFjaCAoJHNlcnZlcnMgYXMgJHNlcnZlcikKICAgICAgICAgICAgICAgICAgICAgICAgICAgIDx0ciBjbGFzcz0iYWxpZ24tbWlkZGxlIj4KICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICA8dGQgY2xhc3M9Im1pZGRsZSI+CiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIDxzdHJvbmc+e3sgJHNlcnZlci0+bmFtZSB9fTwvc3Ryb25nPgogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICBAaWYoJHNlcnZlci0+aWQgPT0gMjYpCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIDxicj48c21hbGwgY2xhc3M9InRleHQtbXV0ZWQiPkpob2FubGV5IFRlY2g8L3NtYWxsPgogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICBAZW5kaWYKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICA8L3RkPgogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIDx0ZCBjbGFzcz0ibWlkZGxlIj48Y29kZT57eyAkc2VydmVyLT51dWlkU2hvcnQgfX08L2NvZGU+PC90ZD4KICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICA8dGQgY2xhc3M9Im1pZGRsZSI+CiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIDxzcGFuIGNsYXNzPSJsYWJlbCBsYWJlbC1kZWZhdWx0Ij4KICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIDxpIGNsYXNzPSJmYSBmYS11c2VyIj48L2k+IHt7ICRzZXJ2ZXItPnVzZXItPnVzZXJuYW1lIH19CiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIDwvc3Bhbj4KICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICA8L3RkPgogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIDx0ZCBjbGFzcz0ibWlkZGxlIj4KICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgPHNwYW4gY2xhc3M9ImxhYmVsIGxhYmVsLWluZm8iPgogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgPGkgY2xhc3M9ImZhIGZhLXNlcnZlciI+PC9pPiB7eyAkc2VydmVyLT5ub2RlLT5uYW1lIH19CiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIDwvc3Bhbj4KICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICA8L3RkPgogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIDx0ZCBjbGFzcz0ibWlkZGxlIj4KICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgPGNvZGU+e3sgJHNlcnZlci0+YWxsb2NhdGlvbi0+YWxpYXMgfX06e3sgJHNlcnZlci0+YWxsb2NhdGlvbi0+cG9ydCB9fTwvY29kZT4KICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgQGlmKCRzZXJ2ZXItPmlkID09IDI2KQogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICA8YnI+PHNtYWxsPjxjb2RlPkpob2FubGV5IFRlY2g6MjAwNzwvY29kZT48L3NtYWxsPgogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICBAZW5kaWYKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICA8L3RkPgogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIDx0ZCBjbGFzcz0idGV4dC1jZW50ZXIiPgogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICBAaWYoKGludCkgYXV0aCgpLT51c2VyKCktPmlkID09PSAxKQogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgPGEgaHJlZj0ie3sgcm91dGUoJ2FkbWluLnNlcnZlcnMudmlldycsICRzZXJ2ZXItPmlkKSB9fSIgY2xhc3M9ImJ0biBidG4teHMgYnRuLXByaW1hcnkiPgogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIDxpIGNsYXNzPSJmYSBmYS13cmVuY2giPjwvaT4gTWFuYWdlCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICA8L2E+CiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIEBlbHNlCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICA8c3BhbiBjbGFzcz0ibGFiZWwgbGFiZWwtd2FybmluZyIgZGF0YS10b2dnbGU9InRvb2x0aXAiIHRpdGxlPSJIYW55YSBSb290IEFkbWluIHlhbmcgYmlzYSBtZW5nYWtzZXMiPgogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIDxpIGNsYXNzPSJmYSBmYS1zaGllbGQiPjwvaT4gUHJvdGVjdGVkCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICA8L3NwYW4+CiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIEBlbmRpZgogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIDwvdGQ+CiAgICAgICAgICAgICAgICAgICAgICAgICAgICA8L3RyPgogICAgICAgICAgICAgICAgICAgICAgICBAZW5kZm9yZWFjaAogICAgICAgICAgICAgICAgICAgIDwvdGJvZHk+CiAgICAgICAgICAgICAgICA8L3RhYmxlPgogICAgICAgICAgICA8L2Rpdj4KICAgICAgICAgICAgQGlmKCRzZXJ2ZXJzLT5oYXNQYWdlcygpKQogICAgICAgICAgICAgICAgPGRpdiBjbGFzcz0iYm94LWZvb3RlciB3aXRoLWJvcmRlciI+CiAgICAgICAgICAgICAgICAgICAgPGRpdiBjbGFzcz0iY29sLW1kLTEyIHRleHQtY2VudGVyIj57ISEgJHNlcnZlcnMtPmFwcGVuZHMoWydxdWVyeScgPT4gUmVxdWVzdDo6aW5wdXQoJ3F1ZXJ5JyldKS0+cmVuZGVyKCkgISF9PC9kaXY+CiAgICAgICAgICAgICAgICA8L2Rpdj4KICAgICAgICAgICAgQGVuZGlmCiAgICAgICAgPC9kaXY+CgogICAgICAgIEBpZigoaW50KSBhdXRoKCktPnVzZXIoKS0+aWQgIT09IDEpCiAgICAgICAgPGRpdiBjbGFzcz0iYWxlcnQgYWxlcnQtd2FybmluZyI+CiAgICAgICAgICAgIDxoNCBzdHlsZT0ibWFyZ2luLXRvcDogMDsiPgogICAgICAgICAgICAgICAgPGkgY2xhc3M9ImZhIGZhLXNoaWVsZCI+PC9pPiBTZWN1cml0eSBQcm90ZWN0aW9uIEFjdGl2ZQogICAgICAgICAgICA8L2g0PgogICAgICAgICAgICA8cCBzdHlsZT0ibWFyZ2luLWJvdHRvbTogNXB4OyI+CiAgICAgICAgICAgICAgICA8c3Ryb25nPvCflJIgU2VydmVyIE1hbmFnZW1lbnQgUmVzdHJpY3RlZDo8L3N0cm9uZz4KICAgICAgICAgICAgICAgIEhhbnlhIDxzdHJvbmc+Um9vdCBBZG1pbmlzdHJhdG9yIChJRDogMSk8L3N0cm9uZz4geWFuZyBkYXBhdCBtZW5nZWxvbGEgc2VydmVyIGV4aXN0aW5nLgogICAgICAgICAgICA8L3A+CiAgICAgICAgICAgIDxwIHN0eWxlPSJtYXJnaW4tYm90dG9tOiAwOyBmb250LXNpemU6IDEycHg7Ij4KICAgICAgICAgICAgICAgIDxzdHJvbmc+4pyFIENyZWF0ZSBOZXcgU2VydmVyOjwvc3Ryb25nPiBBdmFpbGFibGUgZm9yIGFsbCBhZG1pbmlzdHJhdG9yczxicj4KICAgICAgICAgICAgICAgIDxzdHJvbmc+8J+aqyBNYW5hZ2UgRXhpc3Rpbmc6PC9zdHJvbmc+IFJvb3QgQWRtaW4gb25seTxicj4KICAgICAgICAgICAgICAgIDxpIGNsYXNzPSJmYSBmYS1pbmZvLWNpcmNsZSI+PC9pPgogICAgICAgICAgICAgICAgUHJvdGVjdGVkIGJ5OgogICAgICAgICAgICAgICAgPHNwYW4gY2xhc3M9ImxhYmVsIGxhYmVsLXByaW1hcnkiPkpob25hbGV5IFRlY2g8L3NwYW4+CiAgICAgICAgICAgICAgICA8c3BhbiBjbGFzcz0ibGFiZWwgbGFiZWwtc3VjY2VzcyI+QGRhbmFuZ3ZhbGVudHA8L3NwYW4+CiAgICAgICAgICAgICAgICA8c3BhbiBjbGFzcz0ibGFiZWwgbGFiZWwtaW5mbyI+QGpob25hbGV5dGVzdGkzPC9zcGFuPgogICAgICAgICAgICA8L3A+CiAgICAgICAgPC9kaXY+CiAgICAgICAgQGVsc2UKICAgICAgICA8ZGl2IGNsYXNzPSJhbGVydCBhbGVydC1zdWNjZXNzIj4KICAgICAgICAgICAgPGg0IHN0eWxlPSJtYXJnaW4tdG9wOiAwOyI+CiAgICAgICAgICAgICAgICA8aSBjbGFzcz0iZmEgZmEtY3Jvd24iPjwvaT4gUm9vdCBBZG1pbmlzdHJhdG9yIEFjY2VzcwogICAgICAgICAgICA8L2g0PgogICAgICAgICAgICA8cCBzdHlsZT0ibWFyZ2luLWJvdHRvbTogMDsiPgogICAgICAgICAgICAgICAgQW5kYSBtZW1pbGlraSBha3NlcyBwZW51aCBzZWJhZ2FpIDxzdHJvbmc+Um9vdCBBZG1pbmlzdHJhdG9yIChJRDogMSk8L3N0cm9uZz4uCiAgICAgICAgICAgICAgICBTZW11YSBzZXJ2ZXIgZGFwYXQgZGlrZWxvbGEgc2VjYXJhIG5vcm1hbC4KICAgICAgICAgICAgPC9wPgogICAgICAgIDwvZGl2PgogICAgICAgIEBlbmRpZgogICAgPC9kaXY+CjwvZGl2PgpAZW5kc2VjdGlvbgoKQHNlY3Rpb24oJ2Zvb3Rlci1zY3JpcHRzJykKICAgIEBwYXJlbnQKICAgIDxzY3JpcHQ+CiAgICAgICAgJChkb2N1bWVudCkucmVhZHkoZnVuY3Rpb24oKSB7CiAgICAgICAgICAgICQoJ1tkYXRhLXRvZ2dsZT0idG9vbHRpcCJdJykudG9vbHRpcCgpOwoKICAgICAgICAgICAgQGlmKChpbnQpIGF1dGgoKS0+dXNlcigpLT5pZCAhPT0gMSkKICAgICAgICAgICAgJCgnYVtocmVmKj0iL2FkbWluL3NlcnZlcnMvdmlldy8iXScpLm9uKCdjbGljaycsIGZ1bmN0aW9uKGUpIHsKICAgICAgICAgICAgICAgIGUucHJldmVudERlZmF1bHQoKTsKICAgICAgICAgICAgICAgIGFsZXJ0KCfwn5qrIEFjY2VzcyBEZW5pZWQ6IEhhbnlhIFJvb3QgQWRtaW5pc3RyYXRvciAoSUQ6IDEpIHlhbmcgZGFwYXQgbWVuZ2Vsb2xhIHNlcnZlciBleGlzdGluZy5cblxu4pyFIEFuZGEgbWFzaWggYmlzYSBtZW1idWF0IHNlcnZlciBiYXJ1IGRlbmdhbiB0b21ib2wgIkNyZWF0ZSBOZXciXG5cblByb3RlY3RlZCBieTogSmhvbmFsZXkgVGVjaCcpOwogICAgICAgICAgICB9KTsKICAgICAgICAgICAgQGVuZGlmCiAgICAgICAgfSk7CiAgICA8L3NjcmlwdD4KQGVuZHNlY3Rpb24KRU9GCgpzZWQgLWkgInN8SmhvbmFsZXkgVGVjaHwke0JSQU5EX05BTUV9fGciICIkSU5ERVhfRklMRSIgMj4vZGV2L251bGwgfHwgdHJ1ZQpzZWQgLWkgInN8QGRhbmFndmFsZW50cHwke0NPTlRBQ1RfVEVMRUdSQU19fGciICIkSU5ERVhfRklMRSIgMj4vZGV2L251bGwgfHwgdHJ1ZQpzZWQgLWkgInN8QGRhbmFuZ3ZhbGVudHB8JHtDT05UQUNUX1RFTEVHUkFNfXxnIiAiJElOREVYX0ZJTEUiIDI+L2Rldi9udWxsIHx8IHRydWUKc2VkIC1pICJzfFByb3RlY3RlZCBieTogSmhvbmFsZXkgVGVjaHxQcm90ZWN0ZWQgYnk6ICR7QlJBTkRfTkFNRX18ZyIgIiRJTkRFWF9GSUxFIiAyPi9kZXYvbnVsbCB8fCB0cnVlCgpjaG1vZCA2NDQgIiRJTkRFWF9GSUxFIgoKZWNobyAi4oS577iPIENhY2hlIGNsZWFyIGFrYW4gZGlsYWt1a2FuIG9sZWggUHJvdGVjdCBNYW5hZ2VyIGNvbnRyb2xsZXIiCgplY2hvICIiCmVjaG8gIvCfjokgUFJPVEVLU0kgQkVSSEFTSUwgRElQQVNBTkchIgplY2hvICLinIUgQWRtaW4gSUQgMTogQmlzYSBha3NlcyBzZW11YSAoc2VydmVyIGxpc3QsIHZpZXcsIGRhbiBtYW5hZ2VtZW50KSIKZWNobyAi4pyFIEFkbWluIGxhaW46IEJpc2EgQ3JlYXRlIE5ldyBzZXJ2ZXIsIHRhcGkgdGlkYWsgYmlzYSBtYW5hZ2UgZXhpc3RpbmciCmVjaG8gIuKchSBWaWV3IHNlcnZlciBhc2xpIHRpZGFrIGRpdWJhaCBhZ2FyIHRhYiB0ZXRhcCBub3JtYWwiCmVjaG8gIvCfm6HvuI8gU2VjdXJpdHkgYnk6IEBkYW5hbmd2YWxlbnRwIgo=
SCRIPT_INSTALLPROTECT10_SH,
            'installprotect11.sh' => <<<'SCRIPT_INSTALLPROTECT11_SH'
IyEvYmluL2Jhc2gKCkJSQU5EX05BTUU9IiR7QlJBTkRfTkFNRTotSmhvbmFsZXkgVGVjaH0iCkJSQU5EX1RFWFQ9IiR7QlJBTkRfVEVYVDotUHJvdGVjdCBCeSBKaG9uYWxleX0iCkNPTlRBQ1RfVEVMRUdSQU09IiR7Q09OVEFDVF9URUxFR1JBTTotQGRhbmFuZ3ZhbGVudHB9IgoKZWNobyAi8J+agCBNZW1hc2FuZyBwcm90ZWtzaSBBbnRpIFRhdXRhbiBTZXJ2ZXIuLi4iCgpJTkRFWF9GSUxFPSIvdmFyL3d3dy9wdGVyb2RhY3R5bC9yZXNvdXJjZXMvdmlld3MvYWRtaW4vc2VydmVycy9pbmRleC5ibGFkZS5waHAiClRJTUVTVEFNUD0kKGRhdGUgLXUgKyIlWS0lbS0lZC0lSC0lTS0lUyIpCgppZiBbIC1mICIkSU5ERVhfRklMRSIgXTsgdGhlbgogIGNwICIkSU5ERVhfRklMRSIgIiR7SU5ERVhfRklMRX0uYmFrXyR7VElNRVNUQU1QfSIKICBlY2hvICLwn5OmIEJhY2t1cCBpbmRleCBmaWxlIGRpYnVhdDogJHtJTkRFWF9GSUxFfS5iYWtfJHtUSU1FU1RBTVB9IgpmaQoKY2F0ID4gIiRJTkRFWF9GSUxFIiA8PCAnRU9GJwpAZXh0ZW5kcygnbGF5b3V0cy5hZG1pbicpCkBzZWN0aW9uKCd0aXRsZScpCiAgICBTZXJ2ZXJzCkBlbmRzZWN0aW9uCgpAc2VjdGlvbignY29udGVudC1oZWFkZXInKQogICAgPGgxPlNlcnZlcnM8c21hbGw+QWxsIHNlcnZlcnMgYXZhaWxhYmxlIG9uIHRoZSBzeXN0ZW0uPC9zbWFsbD48L2gxPgogICAgPG9sIGNsYXNzPSJicmVhZGNydW1iIj4KICAgICAgICA8bGk+PGEgaHJlZj0ie3sgcm91dGUoJ2FkbWluLmluZGV4JykgfX0iPkFkbWluPC9hPjwvbGk+CiAgICAgICAgPGxpIGNsYXNzPSJhY3RpdmUiPlNlcnZlcnM8L2xpPgogICAgPC9vbD4KQGVuZHNlY3Rpb24KCkBzZWN0aW9uKCdjb250ZW50JykKPGRpdiBjbGFzcz0icm93Ij4KICAgIDxkaXYgY2xhc3M9ImNvbC14cy0xMiI+CiAgICAgICAgPGRpdiBjbGFzcz0iYm94IGJveC1wcmltYXJ5Ij4KICAgICAgICAgICAgPGRpdiBjbGFzcz0iYm94LWhlYWRlciB3aXRoLWJvcmRlciI+CiAgICAgICAgICAgICAgICA8aDMgY2xhc3M9ImJveC10aXRsZSI+U2VydmVyIExpc3Q8L2gzPgogICAgICAgICAgICAgICAgPGRpdiBjbGFzcz0iYm94LXRvb2xzIHNlYXJjaDAxIj4KICAgICAgICAgICAgICAgICAgICA8Zm9ybSBhY3Rpb249Int7IHJvdXRlKCdhZG1pbi5zZXJ2ZXJzJykgfX0iIG1ldGhvZD0iR0VUIj4KICAgICAgICAgICAgICAgICAgICAgICAgPGRpdiBjbGFzcz0iaW5wdXQtZ3JvdXAgaW5wdXQtZ3JvdXAtc20iPgogICAgICAgICAgICAgICAgICAgICAgICAgICAgPGlucHV0IHR5cGU9InRleHQiIG5hbWU9InF1ZXJ5IiBjbGFzcz0iZm9ybS1jb250cm9sIHB1bGwtcmlnaHQiIHZhbHVlPSJ7eyByZXF1ZXN0KCktPmlucHV0KCdxdWVyeScpIH19IiBwbGFjZWhvbGRlcj0iU2VhcmNoIFNlcnZlcnMiPgogICAgICAgICAgICAgICAgICAgICAgICAgICAgPGRpdiBjbGFzcz0iaW5wdXQtZ3JvdXAtYnRuIj4KICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICA8YnV0dG9uIHR5cGU9InN1Ym1pdCIgY2xhc3M9ImJ0biBidG4tZGVmYXVsdCI+PGkgY2xhc3M9ImZhIGZhLXNlYXJjaCI+PC9pPjwvYnV0dG9uPgogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIDxhIGhyZWY9Int7IHJvdXRlKCdhZG1pbi5zZXJ2ZXJzLm5ldycpIH19Ij48YnV0dG9uIHR5cGU9ImJ1dHRvbiIgY2xhc3M9ImJ0biBidG4tc20gYnRuLXByaW1hcnkiIHN0eWxlPSJib3JkZXItcmFkaXVzOjAgM3B4IDNweCAwO21hcmdpbi1sZWZ0OjJweDsiPkNyZWF0ZSBOZXc8L2J1dHRvbj48L2E+CiAgICAgICAgICAgICAgICAgICAgICAgICAgICA8L2Rpdj4KICAgICAgICAgICAgICAgICAgICAgICAgPC9kaXY+CiAgICAgICAgICAgICAgICAgICAgPC9mb3JtPgogICAgICAgICAgICAgICAgPC9kaXY+CiAgICAgICAgICAgIDwvZGl2PgogICAgICAgICAgICA8ZGl2IGNsYXNzPSJib3gtYm9keSB0YWJsZS1yZXNwb25zaXZlIG5vLXBhZGRpbmciPgogICAgICAgICAgICAgICAgPHRhYmxlIGNsYXNzPSJ0YWJsZSB0YWJsZS1ob3ZlciI+CiAgICAgICAgICAgICAgICAgICAgPHRoZWFkPgogICAgICAgICAgICAgICAgICAgICAgICA8dHI+CiAgICAgICAgICAgICAgICAgICAgICAgICAgICA8dGg+U2VydmVyIE5hbWU8L3RoPgogICAgICAgICAgICAgICAgICAgICAgICAgICAgPHRoPlVVSUQ8L3RoPgogICAgICAgICAgICAgICAgICAgICAgICAgICAgPHRoPk93bmVyPC90aD4KICAgICAgICAgICAgICAgICAgICAgICAgICAgIDx0aD5Ob2RlPC90aD4KICAgICAgICAgICAgICAgICAgICAgICAgICAgIDx0aD5Db25uZWN0aW9uPC90aD4KICAgICAgICAgICAgICAgICAgICAgICAgICAgIDx0aCBjbGFzcz0idGV4dC1jZW50ZXIiPkFjdGlvbnM8L3RoPgogICAgICAgICAgICAgICAgICAgICAgICA8L3RyPgogICAgICAgICAgICAgICAgICAgIDwvdGhlYWQ+CiAgICAgICAgICAgICAgICAgICAgPHRib2R5PgogICAgICAgICAgICAgICAgICAgICAgICBAZm9yZWFjaCAoJHNlcnZlcnMgYXMgJHNlcnZlcikKICAgICAgICAgICAgICAgICAgICAgICAgICAgIDx0ciBjbGFzcz0iYWxpZ24tbWlkZGxlIj4KICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICA8dGQgY2xhc3M9Im1pZGRsZSI+CiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIDxzdHJvbmc+e3sgJHNlcnZlci0+bmFtZSB9fTwvc3Ryb25nPgogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICBAaWYoJHNlcnZlci0+aWQgPT0gMjYpCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIDxicj48c21hbGwgY2xhc3M9InRleHQtbXV0ZWQiPkpob2FubGV5IFRlY2g8L3NtYWxsPgogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICBAZW5kaWYKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICA8L3RkPgogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIDx0ZCBjbGFzcz0ibWlkZGxlIj48Y29kZT57eyAkc2VydmVyLT51dWlkU2hvcnQgfX08L2NvZGU+PC90ZD4KICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICA8dGQgY2xhc3M9Im1pZGRsZSI+CiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIDxzcGFuIGNsYXNzPSJsYWJlbCBsYWJlbC1kZWZhdWx0Ij4KICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIDxpIGNsYXNzPSJmYSBmYS11c2VyIj48L2k+IHt7ICRzZXJ2ZXItPnVzZXItPnVzZXJuYW1lIH19CiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIDwvc3Bhbj4KICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICA8L3RkPgogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIDx0ZCBjbGFzcz0ibWlkZGxlIj4KICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgPHNwYW4gY2xhc3M9ImxhYmVsIGxhYmVsLWluZm8iPgogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgPGkgY2xhc3M9ImZhIGZhLXNlcnZlciI+PC9pPiB7eyAkc2VydmVyLT5ub2RlLT5uYW1lIH19CiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIDwvc3Bhbj4KICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICA8L3RkPgogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIDx0ZCBjbGFzcz0ibWlkZGxlIj4KICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgPGNvZGU+e3sgJHNlcnZlci0+YWxsb2NhdGlvbi0+YWxpYXMgfX06e3sgJHNlcnZlci0+YWxsb2NhdGlvbi0+cG9ydCB9fTwvY29kZT4KICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgQGlmKCRzZXJ2ZXItPmlkID09IDI2KQogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICA8YnI+PHNtYWxsPjxjb2RlPkpob2FubGV5IFRlY2g6MjAwNzwvY29kZT48L3NtYWxsPgogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICBAZW5kaWYKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICA8L3RkPgogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIDx0ZCBjbGFzcz0idGV4dC1jZW50ZXIiPgogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICBAaWYoKGludCkgYXV0aCgpLT51c2VyKCktPmlkID09PSAxKQogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgPGEgaHJlZj0ie3sgcm91dGUoJ2FkbWluLnNlcnZlcnMudmlldycsICRzZXJ2ZXItPmlkKSB9fSIgY2xhc3M9ImJ0biBidG4teHMgYnRuLXByaW1hcnkiPgogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIDxpIGNsYXNzPSJmYSBmYS13cmVuY2giPjwvaT4gTWFuYWdlCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICA8L2E+CiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIEBlbHNlCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICA8c3BhbiBjbGFzcz0ibGFiZWwgbGFiZWwtd2FybmluZyIgZGF0YS10b2dnbGU9InRvb2x0aXAiIHRpdGxlPSJIYW55YSBSb290IEFkbWluIHlhbmcgYmlzYSBtZW5nYWtzZXMiPgogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIDxpIGNsYXNzPSJmYSBmYS1zaGllbGQiPjwvaT4gUHJvdGVjdGVkCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICA8L3NwYW4+CiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIEBlbmRpZgogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIDwvdGQ+CiAgICAgICAgICAgICAgICAgICAgICAgICAgICA8L3RyPgogICAgICAgICAgICAgICAgICAgICAgICBAZW5kZm9yZWFjaAogICAgICAgICAgICAgICAgICAgIDwvdGJvZHk+CiAgICAgICAgICAgICAgICA8L3RhYmxlPgogICAgICAgICAgICA8L2Rpdj4KICAgICAgICAgICAgQGlmKCRzZXJ2ZXJzLT5oYXNQYWdlcygpKQogICAgICAgICAgICAgICAgPGRpdiBjbGFzcz0iYm94LWZvb3RlciB3aXRoLWJvcmRlciI+CiAgICAgICAgICAgICAgICAgICAgPGRpdiBjbGFzcz0iY29sLW1kLTEyIHRleHQtY2VudGVyIj57ISEgJHNlcnZlcnMtPmFwcGVuZHMoWydxdWVyeScgPT4gUmVxdWVzdDo6aW5wdXQoJ3F1ZXJ5JyldKS0+cmVuZGVyKCkgISF9PC9kaXY+CiAgICAgICAgICAgICAgICA8L2Rpdj4KICAgICAgICAgICAgQGVuZGlmCiAgICAgICAgPC9kaXY+CgogICAgICAgIEBpZigoaW50KSBhdXRoKCktPnVzZXIoKS0+aWQgIT09IDEpCiAgICAgICAgPGRpdiBjbGFzcz0iYWxlcnQgYWxlcnQtd2FybmluZyI+CiAgICAgICAgICAgIDxoNCBzdHlsZT0ibWFyZ2luLXRvcDogMDsiPgogICAgICAgICAgICAgICAgPGkgY2xhc3M9ImZhIGZhLXNoaWVsZCI+PC9pPiBTZWN1cml0eSBQcm90ZWN0aW9uIEFjdGl2ZQogICAgICAgICAgICA8L2g0PgogICAgICAgICAgICA8cCBzdHlsZT0ibWFyZ2luLWJvdHRvbTogNXB4OyI+CiAgICAgICAgICAgICAgICA8c3Ryb25nPvCflJIgU2VydmVyIE1hbmFnZW1lbnQgUmVzdHJpY3RlZDo8L3N0cm9uZz4KICAgICAgICAgICAgICAgIEhhbnlhIDxzdHJvbmc+Um9vdCBBZG1pbmlzdHJhdG9yIChJRDogMSk8L3N0cm9uZz4geWFuZyBkYXBhdCBtZW5nZWxvbGEgc2VydmVyIGV4aXN0aW5nLgogICAgICAgICAgICA8L3A+CiAgICAgICAgICAgIDxwIHN0eWxlPSJtYXJnaW4tYm90dG9tOiAwOyBmb250LXNpemU6IDEycHg7Ij4KICAgICAgICAgICAgICAgIDxzdHJvbmc+4pyFIENyZWF0ZSBOZXcgU2VydmVyOjwvc3Ryb25nPiBBdmFpbGFibGUgZm9yIGFsbCBhZG1pbmlzdHJhdG9yczxicj4KICAgICAgICAgICAgICAgIDxzdHJvbmc+8J+aqyBNYW5hZ2UgRXhpc3Rpbmc6PC9zdHJvbmc+IFJvb3QgQWRtaW4gb25seTxicj4KICAgICAgICAgICAgICAgIDxpIGNsYXNzPSJmYSBmYS1pbmZvLWNpcmNsZSI+PC9pPgogICAgICAgICAgICAgICAgUHJvdGVjdGVkIGJ5OgogICAgICAgICAgICAgICAgPHNwYW4gY2xhc3M9ImxhYmVsIGxhYmVsLXByaW1hcnkiPkBkYW5hbmd2YWxlbnRwPC9zcGFuPgogICAgICAgICAgICAgICAgPHNwYW4gY2xhc3M9ImxhYmVsIGxhYmVsLXN1Y2Nlc3MiPkBqaG9uYWxleXRlc3RpMzwvc3Bhbj4KICAgICAgICAgICAgICAgIDxzcGFuIGNsYXNzPSJsYWJlbCBsYWJlbC1pbmZvIj5KaG9uYWxleSBUZWNoPC9zcGFuPgogICAgICAgICAgICA8L3A+CiAgICAgICAgPC9kaXY+CiAgICAgICAgQGVsc2UKICAgICAgICA8ZGl2IGNsYXNzPSJhbGVydCBhbGVydC1zdWNjZXNzIj4KICAgICAgICAgICAgPGg0IHN0eWxlPSJtYXJnaW4tdG9wOiAwOyI+CiAgICAgICAgICAgICAgICA8aSBjbGFzcz0iZmEgZmEtY3Jvd24iPjwvaT4gUm9vdCBBZG1pbmlzdHJhdG9yIEFjY2VzcwogICAgICAgICAgICA8L2g0PgogICAgICAgICAgICA8cCBzdHlsZT0ibWFyZ2luLWJvdHRvbTogMDsiPgogICAgICAgICAgICAgICAgQW5kYSBtZW1pbGlraSBha3NlcyBwZW51aCBzZWJhZ2FpIDxzdHJvbmc+Um9vdCBBZG1pbmlzdHJhdG9yIChJRDogMSk8L3N0cm9uZz4uCiAgICAgICAgICAgICAgICBTZW11YSBzZXJ2ZXIgZGFwYXQgZGlrZWxvbGEgc2VjYXJhIG5vcm1hbC4KICAgICAgICAgICAgPC9wPgogICAgICAgIDwvZGl2PgogICAgICAgIEBlbmRpZgogICAgPC9kaXY+CjwvZGl2PgpAZW5kc2VjdGlvbgoKQHNlY3Rpb24oJ2Zvb3Rlci1zY3JpcHRzJykKICAgIEBwYXJlbnQKICAgIDxzY3JpcHQ+CiAgICAgICAgJChkb2N1bWVudCkucmVhZHkoZnVuY3Rpb24oKSB7CiAgICAgICAgICAgICQoJ1tkYXRhLXRvZ2dsZT0idG9vbHRpcCJdJykudG9vbHRpcCgpOwoKICAgICAgICAgICAgQGlmKChpbnQpIGF1dGgoKS0+dXNlcigpLT5pZCAhPT0gMSkKICAgICAgICAgICAgJCgnYVtocmVmKj0iL2FkbWluL3NlcnZlcnMvdmlldy8iXScpLm9uKCdjbGljaycsIGZ1bmN0aW9uKGUpIHsKICAgICAgICAgICAgICAgIGUucHJldmVudERlZmF1bHQoKTsKICAgICAgICAgICAgICAgIGFsZXJ0KCfwn5qrIEFjY2VzcyBEZW5pZWQ6IEhhbnlhIFJvb3QgQWRtaW5pc3RyYXRvciAoSUQ6IDEpIHlhbmcgZGFwYXQgbWVuZ2Vsb2xhIHNlcnZlciBleGlzdGluZy5cblxu4pyFIEFuZGEgbWFzaWggYmlzYSBtZW1idWF0IHNlcnZlciBiYXJ1IGRlbmdhbiB0b21ib2wgIkNyZWF0ZSBOZXciXG5cblByb3RlY3RlZCBieTogQGRhbmFuZ3ZhbGVudHBsJyk7CiAgICAgICAgICAgIH0pOwogICAgICAgICAgICBAZW5kaWYKICAgICAgICB9KTsKICAgIDwvc2NyaXB0PgpAZW5kc2VjdGlvbgpFT0YKCnNlZCAtaSAic3xKaG9uYWxleSBUZWNofCR7QlJBTkRfTkFNRX18ZyIgIiRJTkRFWF9GSUxFIiAyPi9kZXYvbnVsbCB8fCB0cnVlCnNlZCAtaSAic3xAZGFuYW5ndmFsZW50cHwke0NPTlRBQ1RfVEVMRUdSQU19fGciICIkSU5ERVhfRklMRSIgMj4vZGV2L251bGwgfHwgdHJ1ZQpzZWQgLWkgInN8QGRhbmFuZ3ZhbGVudHBsfCR7Q09OVEFDVF9URUxFR1JBTX18ZyIgIiRJTkRFWF9GSUxFIiAyPi9kZXYvbnVsbCB8fCB0cnVlCgpjaG1vZCA2NDQgIiRJTkRFWF9GSUxFIgoKZWNobyAi4oS577iPIENhY2hlIGNsZWFyIGFrYW4gZGlsYWt1a2FuIG9sZWggUHJvdGVjdCBNYW5hZ2VyIGNvbnRyb2xsZXIiCgplY2hvICIiCmVjaG8gIvCfjokgUFJPVEVLU0kgQkVSSEFTSUwgRElQQVNBTkchIgplY2hvICLinIUgQWRtaW4gSUQgMTogQmlzYSBha3NlcyBzZW11YSAoc2VydmVyIGxpc3QsIHZpZXcsIGRhbiBtYW5hZ2VtZW50KSIKZWNobyAi4pyFIEFkbWluIGxhaW46IEJpc2EgQ3JlYXRlIE5ldyBzZXJ2ZXIsIHRhcGkgdGlkYWsgYmlzYSBtYW5hZ2UgZXhpc3RpbmciCmVjaG8gIuKchSBWaWV3IHNlcnZlciBhc2xpIHRpZGFrIGRpdWJhaCBhZ2FyIHRhYiB0ZXRhcCBub3JtYWwiCmVjaG8gIvCfm6HvuI8gU2VjdXJpdHkgYnk6IEBkYW5hbmd2YWxlbnRwIgo=
SCRIPT_INSTALLPROTECT11_SH,
            'installprotect12.sh' => <<<'SCRIPT_INSTALLPROTECT12_SH'
IyEvYmluL2Jhc2gKCkJSQU5EX05BTUU9IiR7QlJBTkRfTkFNRTotSmhvbmFsZXkgVGVjaH0iCkJSQU5EX1RFWFQ9IiR7QlJBTkRfVEVYVDotUHJvdGVjdCBCeSBKaG9uYWxleX0iCkNPTlRBQ1RfVEVMRUdSQU09IiR7Q09OVEFDVF9URUxFR1JBTTotQGRhbmFuZ3ZhbGVudHB9IgoKVElNRVNUQU1QPSQoZGF0ZSAtdSArIiVZLSVtLSVkLSVILSVNLSVTIikKCmVjaG8gIvCfmoAgTWVtYXNhbmcgcHJvdGVrc2kgTm9kZXMgKyBDbGllbnQgQWNjb3VudCBBUEkgKyBBcHBsaWNhdGlvbiBBUEkgVXNlciArIEFwcGxpY2F0aW9uIEFQSSBDb250cm9sbGVyLi4uIgplY2hvICIiCgojID09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT0KIyBCQUdJQU4gMTogUFJPVEVLU0kgTk9ERVMgKFNlbWJ1bnlpa2FuICsgQmxvY2sgQWtzZXMpCiMgPT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PQplY2hvICLilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIEiCmVjaG8gIvCfk6YgQkFHSUFOIDE6IFByb3Rla3NpIE5vZGVzIgplY2hvICLilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIEiCgojID09PSBSZXN0b3JlICYgcHJvdGVrc2kgTm9kZVZpZXdDb250cm9sbGVyID09PQpDT05UUk9MTEVSPSIvdmFyL3d3dy9wdGVyb2RhY3R5bC9hcHAvSHR0cC9Db250cm9sbGVycy9BZG1pbi9Ob2Rlcy9Ob2RlVmlld0NvbnRyb2xsZXIucGhwIgpMQVRFU1RfQkFDS1VQPSQobHMgLXQgIiR7Q09OVFJPTExFUn0uYmFrXyIqIDI+L2Rldi9udWxsIHwgdGFpbCAtMSkKCmlmIFsgLW4gIiRMQVRFU1RfQkFDS1VQIiBdOyB0aGVuCiAgY3AgIiRMQVRFU1RfQkFDS1VQIiAiJENPTlRST0xMRVIiCiAgZWNobyAi8J+TpiBOb2RlVmlld0NvbnRyb2xsZXIgZGktcmVzdG9yZSBkYXJpIGJhY2t1cDogJExBVEVTVF9CQUNLVVAiCmVsc2UKICBlY2hvICLimqDvuI8gVGlkYWsgYWRhIGJhY2t1cCBOb2RlVmlld0NvbnRyb2xsZXIsIG1lbmdndW5ha2FuIGZpbGUgc2FhdCBpbmkiCmZpCgpjcCAiJENPTlRST0xMRVIiICIke0NPTlRST0xMRVJ9LmJha18ke1RJTUVTVEFNUH0iCgpweXRob24zIDw8ICdQWUVPRicKaW1wb3J0IHJlCgpjb250cm9sbGVyID0gIi92YXIvd3d3L3B0ZXJvZGFjdHlsL2FwcC9IdHRwL0NvbnRyb2xsZXJzL0FkbWluL05vZGVzL05vZGVWaWV3Q29udHJvbGxlci5waHAiCgp3aXRoIG9wZW4oY29udHJvbGxlciwgInIiKSBhcyBmOgogICAgY29udGVudCA9IGYucmVhZCgpCgppZiAiUFJPVEVLU0lfSkhPTkFMRVkiIGluIGNvbnRlbnQ6CiAgICBwcmludCgi4pqg77iPIFByb3Rla3NpIHN1ZGFoIGFkYSBkaSBOb2RlVmlld0NvbnRyb2xsZXIiKQogICAgZXhpdCgwKQoKaWYgInVzZSBJbGx1bWluYXRlXFxTdXBwb3J0XFxGYWNhZGVzXFxBdXRoOyIgbm90IGluIGNvbnRlbnQ6CiAgICBjb250ZW50ID0gY29udGVudC5yZXBsYWNlKAogICAgICAgICJ1c2UgUHRlcm9kYWN0eWxcXEh0dHBcXENvbnRyb2xsZXJzXFxDb250cm9sbGVyOyIsCiAgICAgICAgInVzZSBQdGVyb2RhY3R5bFxcSHR0cFxcQ29udHJvbGxlcnNcXENvbnRyb2xsZXI7XG51c2UgSWxsdW1pbmF0ZVxcU3VwcG9ydFxcRmFjYWRlc1xcQXV0aDsiCiAgICApCgpsaW5lcyA9IGNvbnRlbnQuc3BsaXQoIlxuIikKbmV3X2xpbmVzID0gW10KaSA9IDAKd2hpbGUgaSA8IGxlbihsaW5lcyk6CiAgICBsaW5lID0gbGluZXNbaV0KICAgIG5ld19saW5lcy5hcHBlbmQobGluZSkKICAgIAogICAgaWYgcmUuc2VhcmNoKHIncHVibGljIGZ1bmN0aW9uICg/IV9fY29uc3RydWN0KScsIGxpbmUpOgogICAgICAgIGogPSBpCiAgICAgICAgd2hpbGUgaiA8IGxlbihsaW5lcykgYW5kICd7JyBub3QgaW4gbGluZXNbal06CiAgICAgICAgICAgIGogKz0gMQogICAgICAgICAgICBpZiBqID4gaToKICAgICAgICAgICAgICAgIG5ld19saW5lcy5hcHBlbmQobGluZXNbal0pCiAgICAgICAgCiAgICAgICAgbmV3X2xpbmVzLmFwcGVuZCgiICAgICAgICAvLyBQUk9URUtTSV9KSE9OQUxFWTogSGFueWEgYWRtaW4gSUQgMSIpCiAgICAgICAgbmV3X2xpbmVzLmFwcGVuZCgiICAgICAgICBpZiAoIUF1dGg6OnVzZXIoKSB8fCAoaW50KSBBdXRoOjp1c2VyKCktPmlkICE9PSAxKSB7IikKICAgICAgICBuZXdfbGluZXMuYXBwZW5kKCIgICAgICAgICAgICBhYm9ydCg0MDMsICdBa3NlcyBkaXRvbGFrIC0gcHJvdGVjdCBieSBKaG9uYWxleSBUZWNoJyk7IikKICAgICAgICBuZXdfbGluZXMuYXBwZW5kKCIgICAgICAgIH0iKQogICAgICAgIAogICAgICAgIGlmIGogPiBpOgogICAgICAgICAgICBpID0gagogICAgaSArPSAxCgp3aXRoIG9wZW4oY29udHJvbGxlciwgInciKSBhcyBmOgogICAgZi53cml0ZSgiXG4iLmpvaW4obmV3X2xpbmVzKSkKCnByaW50KCLinIUgUHJvdGVrc2kgYmVyaGFzaWwgZGlpbmpla3NpIGtlIE5vZGVWaWV3Q29udHJvbGxlciIpClBZRU9GCgplY2hvICIiCmdyZXAgLW4gIlBST1RFS1NJX0pIT05BTEVZIiAiJENPTlRST0xMRVIiCgojID09PSBTZW1idW55aWthbiBtZW51IE5vZGVzIGRpIHNpZGViYXIgPT09CmVjaG8gIiIKZWNobyAi8J+UpyBNZW55ZW1idW55aWthbiBtZW51IE5vZGVzIGRhcmkgc2lkZWJhci4uLiIKClNJREVCQVJfRklMRVM9KAogICIvdmFyL3d3dy9wdGVyb2RhY3R5bC9yZXNvdXJjZXMvdmlld3MvbGF5b3V0cy9hZG1pbi5ibGFkZS5waHAiCiAgIi92YXIvd3d3L3B0ZXJvZGFjdHlsL3Jlc291cmNlcy92aWV3cy9wYXJ0aWFscy9hZG1pbi9zaWRlYmFyLmJsYWRlLnBocCIKKQoKU0lERUJBUl9GT1VORD0iIgpmb3IgU0YgaW4gIiR7U0lERUJBUl9GSUxFU1tAXX0iOyBkbwogIGlmIFsgLWYgIiRTRiIgXTsgdGhlbgogICAgU0lERUJBUl9GT1VORD0iJFNGIgogICAgYnJlYWsKICBmaQpkb25lCgppZiBbIC16ICIkU0lERUJBUl9GT1VORCIgXTsgdGhlbgogIFNJREVCQVJfRk9VTkQ9JChncmVwIC1ybCAiYWRtaW4ubm9kZXMiIC92YXIvd3d3L3B0ZXJvZGFjdHlsL3Jlc291cmNlcy92aWV3cy9sYXlvdXRzLyAyPi9kZXYvbnVsbCB8IGhlYWQgLTEpCiAgaWYgWyAteiAiJFNJREVCQVJfRk9VTkQiIF07IHRoZW4KICAgIFNJREVCQVJfRk9VTkQ9JChncmVwIC1ybCAiYWRtaW4ubm9kZXMiIC92YXIvd3d3L3B0ZXJvZGFjdHlsL3Jlc291cmNlcy92aWV3cy9wYXJ0aWFscy8gMj4vZGV2L251bGwgfCBoZWFkIC0xKQogIGZpCmZpCgppZiBbIC1uICIkU0lERUJBUl9GT1VORCIgXTsgdGhlbgogIGlmIFsgISAtZiAiJHtTSURFQkFSX0ZPVU5EfS5iYWtfJHtUSU1FU1RBTVB9IiBdOyB0aGVuCiAgICBjcCAiJFNJREVCQVJfRk9VTkQiICIke1NJREVCQVJfRk9VTkR9LmJha18ke1RJTUVTVEFNUH0iCiAgZmkKICBlY2hvICLwn5OCIFNpZGViYXIgZGl0ZW11a2FuOiAkU0lERUJBUl9GT1VORCIKCiAgcHl0aG9uMyA8PCBQWUVPRjIKc2lkZWJhciA9ICIkU0lERUJBUl9GT1VORCIKCndpdGggb3BlbihzaWRlYmFyLCAiciIpIGFzIGY6CiAgICBjb250ZW50ID0gZi5yZWFkKCkKCmlmICJQUk9URUtTSV9OT0RFU19TSURFQkFSIiBpbiBjb250ZW50OgogICAgcHJpbnQoIuKaoO+4jyBTaWRlYmFyIE5vZGVzIHN1ZGFoIGRpcHJvdGVrc2kiKQogICAgZXhpdCgwKQoKaW1wb3J0IHJlCgpsaW5lcyA9IGNvbnRlbnQuc3BsaXQoIlxuIikKbmV3X2xpbmVzID0gW10KaSA9IDAKCndoaWxlIGkgPCBsZW4obGluZXMpOgogICAgbGluZSA9IGxpbmVzW2ldCgogICAgaWYgKCdhZG1pbi5ub2RlcycgaW4gbGluZSBvciAicm91dGUoJ2FkbWluLm5vZGVzJykiIGluIGxpbmUpIGFuZCAnYWRtaW4ubm9kZXMudmlldycgbm90IGluIGxpbmU6CiAgICAgICAgbGlfc3RhcnQgPSBsZW4obmV3X2xpbmVzKSAtIDEKICAgICAgICB3aGlsZSBsaV9zdGFydCA+PSAwIGFuZCAnPGxpJyBub3QgaW4gbmV3X2xpbmVzW2xpX3N0YXJ0XToKICAgICAgICAgICAgbGlfc3RhcnQgLT0gMQoKICAgICAgICBpZiBsaV9zdGFydCA+PSAwOgogICAgICAgICAgICBuZXdfbGluZXMuaW5zZXJ0KGxpX3N0YXJ0LCAie3stLSBQUk9URUtTSV9OT0RFU19TSURFQkFSIC0tfX0iKQogICAgICAgICAgICBuZXdfbGluZXMuaW5zZXJ0KGxpX3N0YXJ0LCAiQGlmKChpbnQpIEF1dGg6OnVzZXIoKS0+aWQgPT09IDEpIikKCiAgICAgICAgICAgIG5ld19saW5lcy5hcHBlbmQobGluZSkKICAgICAgICAgICAgaSArPSAxCgogICAgICAgICAgICBsaV9kZXB0aCA9IDEKICAgICAgICAgICAgd2hpbGUgaSA8IGxlbihsaW5lcykgYW5kIGxpX2RlcHRoID4gMDoKICAgICAgICAgICAgICAgIGN1cnIgPSBsaW5lc1tpXQogICAgICAgICAgICAgICAgbGlfZGVwdGggKz0gY3Vyci5jb3VudCgnPGxpJykgLSBjdXJyLmNvdW50KCc8L2xpJykKICAgICAgICAgICAgICAgIG5ld19saW5lcy5hcHBlbmQoY3VycikKICAgICAgICAgICAgICAgIGkgKz0gMQoKICAgICAgICAgICAgbmV3X2xpbmVzLmFwcGVuZCgiQGVuZGlmIikKICAgICAgICAgICAgY29udGludWUKCiAgICBuZXdfbGluZXMuYXBwZW5kKGxpbmUpCiAgICBpICs9IDEKCndpdGggb3BlbihzaWRlYmFyLCAidyIpIGFzIGY6CiAgICBmLndyaXRlKCJcbiIuam9pbihuZXdfbGluZXMpKQoKcHJpbnQoIuKchSBNZW51IE5vZGVzIGRpc2VtYnVueWlrYW4gZGFyaSBzaWRlYmFyIikKUFlFT0YyCgplbHNlCiAgZWNobyAi4pqg77iPIEZpbGUgc2lkZWJhciB0aWRhayBkaXRlbXVrYW4uIgpmaQoKIyA9PT0gUHJvdGVrc2kgTm9kZUNvbnRyb2xsZXIgKGhhbGFtYW4gbGlzdCBub2RlcykgPT09Ck5PREVfTElTVD0iL3Zhci93d3cvcHRlcm9kYWN0eWwvYXBwL0h0dHAvQ29udHJvbGxlcnMvQWRtaW4vTm9kZXMvTm9kZUNvbnRyb2xsZXIucGhwIgppZiBbIC1mICIkTk9ERV9MSVNUIiBdOyB0aGVuCiAgaWYgISBncmVwIC1xICJQUk9URUtTSV9KSE9OQUxFWSIgIiROT0RFX0xJU1QiOyB0aGVuCiAgICBjcCAiJE5PREVfTElTVCIgIiR7Tk9ERV9MSVNUfS5iYWtfJHtUSU1FU1RBTVB9IgogICAgCiAgICBweXRob24zIDw8ICdQWUVPRjMnCmNvbnRyb2xsZXIgPSAiL3Zhci93d3cvcHRlcm9kYWN0eWwvYXBwL0h0dHAvQ29udHJvbGxlcnMvQWRtaW4vTm9kZXMvTm9kZUNvbnRyb2xsZXIucGhwIgoKd2l0aCBvcGVuKGNvbnRyb2xsZXIsICJyIikgYXMgZjoKICAgIGNvbnRlbnQgPSBmLnJlYWQoKQoKaWYgIlBST1RFS1NJX0pIT05BTEVZIiBpbiBjb250ZW50OgogICAgcHJpbnQoIuKaoO+4jyBTdWRhaCBhZGEgcHJvdGVrc2kiKQogICAgZXhpdCgwKQoKaWYgInVzZSBJbGx1bWluYXRlXFxTdXBwb3J0XFxGYWNhZGVzXFxBdXRoOyIgbm90IGluIGNvbnRlbnQ6CiAgICBjb250ZW50ID0gY29udGVudC5yZXBsYWNlKAogICAgICAgICJ1c2UgUHRlcm9kYWN0eWxcXEh0dHBcXENvbnRyb2xsZXJzXFxDb250cm9sbGVyOyIsCiAgICAgICAgInVzZSBQdGVyb2RhY3R5bFxcSHR0cFxcQ29udHJvbGxlcnNcXENvbnRyb2xsZXI7XG51c2UgSWxsdW1pbmF0ZVxcU3VwcG9ydFxcRmFjYWRlc1xcQXV0aDsiCiAgICApCgppbXBvcnQgcmUKbGluZXMgPSBjb250ZW50LnNwbGl0KCJcbiIpCm5ld19saW5lcyA9IFtdCmkgPSAwCndoaWxlIGkgPCBsZW4obGluZXMpOgogICAgbGluZSA9IGxpbmVzW2ldCiAgICBuZXdfbGluZXMuYXBwZW5kKGxpbmUpCiAgICAKICAgIGlmIHJlLnNlYXJjaChyJ3B1YmxpYyBmdW5jdGlvbiAoPyFfX2NvbnN0cnVjdCknLCBsaW5lKToKICAgICAgICBqID0gaQogICAgICAgIHdoaWxlIGogPCBsZW4obGluZXMpIGFuZCAneycgbm90IGluIGxpbmVzW2pdOgogICAgICAgICAgICBqICs9IDEKICAgICAgICAgICAgaWYgaiA+IGk6CiAgICAgICAgICAgICAgICBuZXdfbGluZXMuYXBwZW5kKGxpbmVzW2pdKQogICAgICAgIAogICAgICAgIG5ld19saW5lcy5hcHBlbmQoIiAgICAgICAgLy8gUFJPVEVLU0lfSkhPTkFMRVk6IEhhbnlhIGFkbWluIElEIDEiKQogICAgICAgIG5ld19saW5lcy5hcHBlbmQoIiAgICAgICAgaWYgKCFBdXRoOjp1c2VyKCkgfHwgKGludCkgQXV0aDo6dXNlcigpLT5pZCAhPT0gMSkgeyIpCiAgICAgICAgbmV3X2xpbmVzLmFwcGVuZCgiICAgICAgICAgICAgYWJvcnQoNDAzLCAnQWtzZXMgZGl0b2xhayAtIHByb3RlY3QgYnkgSmhvbmFsZXkgVGVjaCcpOyIpCiAgICAgICAgbmV3X2xpbmVzLmFwcGVuZCgiICAgICAgICB9IikKICAgICAgICAKICAgICAgICBpZiBqID4gaToKICAgICAgICAgICAgaSA9IGoKICAgIGkgKz0gMQoKd2l0aCBvcGVuKGNvbnRyb2xsZXIsICJ3IikgYXMgZjoKICAgIGYud3JpdGUoIlxuIi5qb2luKG5ld19saW5lcykpCgpwcmludCgi4pyFIE5vZGVDb250cm9sbGVyIGp1Z2EgZGlwcm90ZWtzaSIpClBZRU9GMwogIGVsc2UKICAgIGVjaG8gIuKaoO+4jyBOb2RlQ29udHJvbGxlciBzdWRhaCBkaXByb3Rla3NpIgogIGZpCmZpCgplY2hvICIiCmVjaG8gIuKchSBCQUdJQU4gMSBTRUxFU0FJOiBQcm90ZWtzaSBOb2RlcyB0ZXJwYXNhbmciCmVjaG8gIiIKCiMgPT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PQojIEJBR0lBTiAyOiBQUk9URUtTSSBDTElFTlQgQUNDT1VOVCBBUEkgKEJsb2NrIHViYWggcGFzc3dvcmQvZW1haWwgYWRtaW4gSUQgMSkKIyA9PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09CmVjaG8gIuKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgSIKZWNobyAi8J+TpiBCQUdJQU4gMjogUHJvdGVrc2kgQ2xpZW50IEFjY291bnQgQVBJIgplY2hvICLilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIEiCgpBQ0NUX0NUUkw9Ii92YXIvd3d3L3B0ZXJvZGFjdHlsL2FwcC9IdHRwL0NvbnRyb2xsZXJzL0FwaS9DbGllbnQvQWNjb3VudENvbnRyb2xsZXIucGhwIgoKaWYgWyAhIC1mICIkQUNDVF9DVFJMIiBdOyB0aGVuCiAgQUNDVF9DVFJMPSQoZmluZCAvdmFyL3d3dy9wdGVyb2RhY3R5bC9hcHAvSHR0cC9Db250cm9sbGVycy9BcGkvQ2xpZW50IC1tYXhkZXB0aCAxIC1pbmFtZSAiQWNjb3VudENvbnRyb2xsZXIucGhwIiAyPi9kZXYvbnVsbCB8IGhlYWQgLTEpCmZpCgppZiBbIC1uICIkQUNDVF9DVFJMIiBdICYmIFsgLWYgIiRBQ0NUX0NUUkwiIF07IHRoZW4KICBlY2hvICLwn5OCIENsaWVudCBBY2NvdW50Q29udHJvbGxlciBkaXRlbXVrYW46ICRBQ0NUX0NUUkwiCgogIEFDQ1RfQkFDS1VQPSQobHMgLXQgIiR7QUNDVF9DVFJMfS5iYWtfIiogMj4vZGV2L251bGwgfCB0YWlsIC0xKQogIGlmIFsgLW4gIiRBQ0NUX0JBQ0tVUCIgXTsgdGhlbgogICAgY3AgIiRBQ0NUX0JBQ0tVUCIgIiRBQ0NUX0NUUkwiCiAgICBlY2hvICLwn5OmIFJlc3RvcmUgZGFyaSBiYWNrdXA6ICRBQ0NUX0JBQ0tVUCIKICBmaQoKICBjcCAiJEFDQ1RfQ1RSTCIgIiR7QUNDVF9DVFJMfS5iYWtfJHtUSU1FU1RBTVB9IgoKICBweXRob24zIDw8IFBZRU9GNAppbXBvcnQgcmUKCmNvbnRyb2xsZXIgPSAiJEFDQ1RfQ1RSTCIKCndpdGggb3Blbihjb250cm9sbGVyLCAiciIpIGFzIGY6CiAgICBjb250ZW50ID0gZi5yZWFkKCkKCmlmICJQUk9URUtTSV9KSE9OQUxFWV9BQ0NPVU5UIiBpbiBjb250ZW50OgogICAgcHJpbnQoIuKaoO+4jyBQcm90ZWtzaSBzdWRhaCBhZGEgZGkgQWNjb3VudENvbnRyb2xsZXIiKQogICAgZXhpdCgwKQoKaWYgInVzZSBJbGx1bWluYXRlXFxTdXBwb3J0XFxGYWNhZGVzXFxBdXRoOyIgbm90IGluIGNvbnRlbnQ6CiAgICB1c2VfcGF0dGVybiA9IHInKHVzZSBQdGVyb2RhY3R5bFxcW147XSs7KScKICAgIG1hdGNoID0gcmUuc2VhcmNoKHVzZV9wYXR0ZXJuLCBjb250ZW50KQogICAgaWYgbWF0Y2g6CiAgICAgICAgY29udGVudCA9IGNvbnRlbnQucmVwbGFjZShtYXRjaC5ncm91cCgwKSwgbWF0Y2guZ3JvdXAoMCkgKyAiXG51c2UgSWxsdW1pbmF0ZVxcU3VwcG9ydFxcRmFjYWRlc1xcQXV0aDsiLCAxKQoKbGluZXMgPSBjb250ZW50LnNwbGl0KCJcbiIpCm5ld19saW5lcyA9IFtdCmkgPSAwCgp3aGlsZSBpIDwgbGVuKGxpbmVzKToKICAgIGxpbmUgPSBsaW5lc1tpXQogICAgbmV3X2xpbmVzLmFwcGVuZChsaW5lKQogICAgCiAgICBpZiByZS5zZWFyY2gocidwdWJsaWMgZnVuY3Rpb24gKHVwZGF0ZVBhc3N3b3JkfHVwZGF0ZUVtYWlsfHVwZGF0ZSlcYicsIGxpbmUpIGFuZCAnX19jb25zdHJ1Y3QnIG5vdCBpbiBsaW5lOgogICAgICAgIGogPSBpCiAgICAgICAgd2hpbGUgaiA8IGxlbihsaW5lcykgYW5kICd7JyBub3QgaW4gbGluZXNbal06CiAgICAgICAgICAgIGogKz0gMQogICAgICAgICAgICBpZiBqID4gaToKICAgICAgICAgICAgICAgIG5ld19saW5lcy5hcHBlbmQobGluZXNbal0pCiAgICAgICAgCiAgICAgICAgbmV3X2xpbmVzLmFwcGVuZCgiICAgICAgICAvLyBQUk9URUtTSV9KSE9OQUxFWV9BQ0NPVU5UOiBCbG9jayB1YmFoIGRhdGEgYWRtaW4gSUQgMSIpCiAgICAgICAgbmV3X2xpbmVzLmFwcGVuZCgiICAgICAgICBcJHRhcmdldFVzZXIgPSBcJHJlcXVlc3QtPnVzZXIoKTsiKQogICAgICAgIG5ld19saW5lcy5hcHBlbmQoIiAgICAgICAgaWYgKChpbnQpIFwkdGFyZ2V0VXNlci0+aWQgPT09IDEgJiYgKCFBdXRoOjp1c2VyKCkgfHwgKGludCkgQXV0aDo6dXNlcigpLT5pZCAhPT0gMSkpIHsiKQogICAgICAgIG5ld19saW5lcy5hcHBlbmQoIiAgICAgICAgICAgIGFib3J0KDQwMywgJ0Frc2VzIGRpdG9sYWsgLSBwcm90ZWN0IGJ5IEpob25hbGV5IFRlY2gnKTsiKQogICAgICAgIG5ld19saW5lcy5hcHBlbmQoIiAgICAgICAgfSIpCiAgICAgICAgCiAgICAgICAgaWYgaiA+IGk6CiAgICAgICAgICAgIGkgPSBqCiAgICBpICs9IDEKCndpdGggb3Blbihjb250cm9sbGVyLCAidyIpIGFzIGY6CiAgICBmLndyaXRlKCJcbiIuam9pbihuZXdfbGluZXMpKQoKcHJpbnQoIuKchSBQcm90ZWtzaSBiZXJoYXNpbCBkaWluamVrc2kga2UgQ2xpZW50IEFjY291bnRDb250cm9sbGVyIikKUFlFT0Y0CgogIGVjaG8gIiIKICBncmVwIC1uICJQUk9URUtTSV9KSE9OQUxFWV9BQ0NPVU5UIiAiJEFDQ1RfQ1RSTCIKZWxzZQogIGVjaG8gIuKaoO+4jyBDbGllbnQgQWNjb3VudENvbnRyb2xsZXIgdGlkYWsgZGl0ZW11a2FuLCBza2lwLiIKZmkKCmVjaG8gIiIKZWNobyAi4pyFIEJBR0lBTiAyIFNFTEVTQUk6IFByb3Rla3NpIENsaWVudCBBY2NvdW50IEFQSSB0ZXJwYXNhbmciCmVjaG8gIiIKCiMgPT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PQojIEJBR0lBTiAzOiBQUk9URUtTSSBBUFBMSUNBVElPTiBBUEkgVVNFUgojIFN0cmF0ZWdpOiBJbmplY3QgYXV0aG9yaXplKCkgZGkgRm9ybSBSZXF1ZXN0ICsgTWlkZGxld2FyZSArIENvbnRyb2xsZXIKIyA9PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09CmVjaG8gIuKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgSIKZWNobyAi8J+TpiBCQUdJQU4gMzogUHJvdGVrc2kgQXBwbGljYXRpb24gQVBJIFVzZXIiCmVjaG8gIuKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgSIKCiMgPT09IExBTkdLQUggM2E6IFByb3Rla3NpIHZpYSBGb3JtIFJlcXVlc3QgYXV0aG9yaXplKCkgPT09CiMgYXV0aG9yaXplKCkgamFsYW4gU0VCRUxVTSBydWxlcygpLCBqYWRpIGluaSBwYWxpbmcgZWZla3RpZgplY2hvICLwn5SnIExhbmdrYWggM2E6IEluamVjdCBwcm90ZWtzaSBrZSBGb3JtIFJlcXVlc3QuLi4iCgpGT1JNX1JFUVVFU1RfRElSPSIvdmFyL3d3dy9wdGVyb2RhY3R5bC9hcHAvSHR0cC9SZXF1ZXN0cy9BcGkvQXBwbGljYXRpb24vVXNlcnMiCgppZiBbIC1kICIkRk9STV9SRVFVRVNUX0RJUiIgXTsgdGhlbgogIGZvciBGUl9GSUxFIGluICIkRk9STV9SRVFVRVNUX0RJUiIvKi5waHA7IGRvCiAgICBpZiBbIC1mICIkRlJfRklMRSIgXTsgdGhlbgogICAgICBGUl9OQU1FPSQoYmFzZW5hbWUgIiRGUl9GSUxFIikKICAgICAgCiAgICAgIGlmIGdyZXAgLXEgIlBST1RFS1NJX0pIT05BTEVZX0ZPUk1SRVEiICIkRlJfRklMRSI7IHRoZW4KICAgICAgICBlY2hvICLimqDvuI8gJEZSX05BTUUgc3VkYWggZGlwcm90ZWtzaSIKICAgICAgICBjb250aW51ZQogICAgICBmaQogICAgICAKICAgICAgY3AgIiRGUl9GSUxFIiAiJHtGUl9GSUxFfS5iYWtfJHtUSU1FU1RBTVB9IgogICAgICAKICAgICAgcHl0aG9uMyA8PCBQWUVPRl9GUgppbXBvcnQgcmUKCmZyX2ZpbGUgPSAiJEZSX0ZJTEUiCmZyX25hbWUgPSAiJEZSX05BTUUiCgp3aXRoIG9wZW4oZnJfZmlsZSwgInIiKSBhcyBmOgogICAgY29udGVudCA9IGYucmVhZCgpCgppZiAiUFJPVEVLU0lfSkhPTkFMRVlfRk9STVJFUSIgaW4gY29udGVudDoKICAgIHByaW50KGYi4pqg77iPIHtmcl9uYW1lfSBzdWRhaCBkaXByb3Rla3NpIikKICAgIGV4aXQoMCkKCiMgQ2FyaSBtZXRob2QgYXV0aG9yaXplKCkKYXV0aF9wYXR0ZXJuID0gcicocHVibGljIGZ1bmN0aW9uIGF1dGhvcml6ZVxzKlwoXHMqXClbXntdKlx7KScKbWF0Y2ggPSByZS5zZWFyY2goYXV0aF9wYXR0ZXJuLCBjb250ZW50KQoKaWYgbWF0Y2g6CiAgICAjIEluamVjdCBjaGVjayBkaSBhd2FsIGF1dGhvcml6ZSgpCiAgICBpbmplY3QgPSAnJycKICAgICAgICAvLyBQUk9URUtTSV9KSE9OQUxFWV9GT1JNUkVROiBCbG9jayBtb2RpZmlrYXNpIHVzZXIgSUQgMQogICAgICAgIGlmIChwcmVnX21hdGNoKCcjL2FwaS9hcHBsaWNhdGlvbi91c2Vycy8xKD86XFxcP3wkfC8pIycsIHJlcXVlc3QoKS0+Z2V0UGF0aEluZm8oKSkpIHsKICAgICAgICAgICAgaWYgKGluX2FycmF5KHJlcXVlc3QoKS0+bWV0aG9kKCksIFsnUEFUQ0gnLCAnUFVUJywgJ0RFTEVURSddKSkgewogICAgICAgICAgICAgICAgYWJvcnQoNDAzLCAnQWtzZXMgZGl0b2xhayAtIHByb3RlY3QgYnkgSmhvbmFsZXkgVGVjaCcpOwogICAgICAgICAgICB9CiAgICAgICAgfQonJycKICAgIGNvbnRlbnQgPSBjb250ZW50LnJlcGxhY2UobWF0Y2guZ3JvdXAoMSksIG1hdGNoLmdyb3VwKDEpICsgaW5qZWN0KQogICAgCiAgICB3aXRoIG9wZW4oZnJfZmlsZSwgInciKSBhcyBmOgogICAgICAgIGYud3JpdGUoY29udGVudCkKICAgIHByaW50KGYi4pyFIHtmcl9uYW1lfSBkaXByb3Rla3NpIHZpYSBhdXRob3JpemUoKSIpCmVsc2U6CiAgICAjIFRpZGFrIGFkYSBhdXRob3JpemUoKSwgdGFtYmFoa2FuIG1ldGhvZCBiYXJ1CiAgICAjIENhcmkgY2xhc3MgYm9keQogICAgY2xhc3NfcGF0dGVybiA9IHInKGNsYXNzIFx3K1tee10qXHspJwogICAgY2xhc3NfbWF0Y2ggPSByZS5zZWFyY2goY2xhc3NfcGF0dGVybiwgY29udGVudCkKICAgIGlmIGNsYXNzX21hdGNoOgogICAgICAgIGluamVjdF9tZXRob2QgPSAnJycKCiAgICAvLyBQUk9URUtTSV9KSE9OQUxFWV9GT1JNUkVROiBCbG9jayBtb2RpZmlrYXNpIHVzZXIgSUQgMQogICAgcHVibGljIGZ1bmN0aW9uIGF1dGhvcml6ZSgpOiBib29sCiAgICB7CiAgICAgICAgaWYgKHByZWdfbWF0Y2goJyMvYXBpL2FwcGxpY2F0aW9uL3VzZXJzLzEoPzpcXFw/fCR8LykjJywgcmVxdWVzdCgpLT5nZXRQYXRoSW5mbygpKSkgewogICAgICAgICAgICBpZiAoaW5fYXJyYXkocmVxdWVzdCgpLT5tZXRob2QoKSwgWydQQVRDSCcsICdQVVQnLCAnREVMRVRFJ10pKSB7CiAgICAgICAgICAgICAgICBhYm9ydCg0MDMsICdBa3NlcyBkaXRvbGFrIC0gcHJvdGVjdCBieSBKaG9uYWxleSBUZWNoJyk7CiAgICAgICAgICAgIH0KICAgICAgICB9CiAgICAgICAgcmV0dXJuIHRydWU7CiAgICB9CicnJwogICAgICAgIGNvbnRlbnQgPSBjb250ZW50LnJlcGxhY2UoY2xhc3NfbWF0Y2guZ3JvdXAoMSksIGNsYXNzX21hdGNoLmdyb3VwKDEpICsgaW5qZWN0X21ldGhvZCkKICAgICAgICAKICAgICAgICB3aXRoIG9wZW4oZnJfZmlsZSwgInciKSBhcyBmOgogICAgICAgICAgICBmLndyaXRlKGNvbnRlbnQpCiAgICAgICAgcHJpbnQoZiLinIUge2ZyX25hbWV9IGRpcHJvdGVrc2kgKGF1dGhvcml6ZSgpIGJhcnUgZGl0YW1iYWhrYW4pIikKICAgIGVsc2U6CiAgICAgICAgcHJpbnQoZiLinYwgR2FnYWwgbWVuZW11a2FuIGNsYXNzIGRpIHtmcl9uYW1lfSIpCgpQWUVPRl9GUgogICAgZmkKICBkb25lCmVsc2UKICBlY2hvICLimqDvuI8gRGlyZWt0b3JpIEZvcm0gUmVxdWVzdCB0aWRhayBkaXRlbXVrYW46ICRGT1JNX1JFUVVFU1RfRElSIgogIGVjaG8gIvCflI0gTWVuY2FyaSBGb3JtIFJlcXVlc3QuLi4iCiAgRk9STV9SRVFVRVNUX0RJUj0kKGZpbmQgL3Zhci93d3cvcHRlcm9kYWN0eWwvYXBwL0h0dHAvUmVxdWVzdHMgLXR5cGUgZCAtaW5hbWUgIlVzZXJzIiAtcGF0aCAiKi9BcHBsaWNhdGlvbi8qIiAyPi9kZXYvbnVsbCB8IGhlYWQgLTEpCiAgaWYgWyAtbiAiJEZPUk1fUkVRVUVTVF9ESVIiIF07IHRoZW4KICAgIGVjaG8gIvCfk4IgRGl0ZW11a2FuOiAkRk9STV9SRVFVRVNUX0RJUiIKICAgIGVjaG8gIuKaoO+4jyBKYWxhbmthbiB1bGFuZyBzY3JpcHQgc2V0ZWxhaCBwYXRoIGRpcGVyYmFpa2kiCiAgZmkKZmkKCiMgPT09IExBTkdLQUggM2I6IEJ1YXQgTWlkZGxld2FyZSAobGF5ZXIgdGFtYmFoYW4pID09PQplY2hvICIiCmVjaG8gIvCflKcgTGFuZ2thaCAzYjogTWlkZGxld2FyZSBQcm90ZWN0QWRtaW5Vc2VyLi4uIgpNSURETEVXQVJFX0RJUj0iL3Zhci93d3cvcHRlcm9kYWN0eWwvYXBwL0h0dHAvTWlkZGxld2FyZSIKTUlERExFV0FSRV9GSUxFPSIke01JRERMRVdBUkVfRElSfS9Qcm90ZWN0QWRtaW5Vc2VyLnBocCIKCmNhdCA+ICIkTUlERExFV0FSRV9GSUxFIiA8PCAnTVdFT0YnCjw/cGhwCgpuYW1lc3BhY2UgUHRlcm9kYWN0eWxcSHR0cFxNaWRkbGV3YXJlOwoKdXNlIENsb3N1cmU7CnVzZSBJbGx1bWluYXRlXEh0dHBcUmVxdWVzdDsKCmNsYXNzIFByb3RlY3RBZG1pblVzZXIKewogICAgLyoqCiAgICAgKiBQUk9URUtTSV9KSE9OQUxFWV9NSURETEVXQVJFOiBCbG9jayBzZW11YSBha3NlcyBBUEkga2UgVXNlciBJRCAxCiAgICAgKi8KICAgIHB1YmxpYyBmdW5jdGlvbiBoYW5kbGUoUmVxdWVzdCAkcmVxdWVzdCwgQ2xvc3VyZSAkbmV4dCkKICAgIHsKICAgICAgICAkcGF0aCA9ICRyZXF1ZXN0LT5nZXRQYXRoSW5mbygpOwoKICAgICAgICBpZiAocHJlZ19tYXRjaCgnIy9hcGkvYXBwbGljYXRpb24vdXNlcnMvMSg/Olw/fCR8LykjJywgJHBhdGgpKSB7CiAgICAgICAgICAgIGlmIChpbl9hcnJheSgkcmVxdWVzdC0+bWV0aG9kKCksIFsnUEFUQ0gnLCAnUFVUJywgJ0RFTEVURScsICdQT1NUJ10pKSB7CiAgICAgICAgICAgICAgICBhYm9ydCg0MDMsICdBa3NlcyBkaXRvbGFrIC0gcHJvdGVjdCBieSBKaG9uYWxleSBUZWNoJyk7CiAgICAgICAgICAgIH0KICAgICAgICB9CgogICAgICAgIHJldHVybiAkbmV4dCgkcmVxdWVzdCk7CiAgICB9Cn0KTVdFT0YKCmVjaG8gIuKchSBNaWRkbGV3YXJlIFByb3RlY3RBZG1pblVzZXIgZGlidWF0IgoKIyA9PT0gTEFOR0tBSCAzYzogUmVnaXN0ZXIgbWlkZGxld2FyZSBkaSBLZXJuZWwucGhwID09PQpLRVJORUw9Ii92YXIvd3d3L3B0ZXJvZGFjdHlsL2FwcC9IdHRwL0tlcm5lbC5waHAiCgppZiBbIC1mICIkS0VSTkVMIiBdOyB0aGVuCiAgaWYgISBncmVwIC1xICJQcm90ZWN0QWRtaW5Vc2VyIiAiJEtFUk5FTCI7IHRoZW4KICAgIGNwICIkS0VSTkVMIiAiJHtLRVJORUx9LmJha18ke1RJTUVTVEFNUH0iCgogICAgcHl0aG9uMyA8PCAnUFlFT0Y1JwppbXBvcnQgcmUKCmtlcm5lbCA9ICIvdmFyL3d3dy9wdGVyb2RhY3R5bC9hcHAvSHR0cC9LZXJuZWwucGhwIgoKd2l0aCBvcGVuKGtlcm5lbCwgInIiKSBhcyBmOgogICAgY29udGVudCA9IGYucmVhZCgpCgppZiAiUHJvdGVjdEFkbWluVXNlciIgaW4gY29udGVudDoKICAgIHByaW50KCLimqDvuI8gTWlkZGxld2FyZSBzdWRhaCB0ZXJkYWZ0YXIgZGkgS2VybmVsIikKICAgIGV4aXQoMCkKCiMgQ2FyaSBwcm90ZWN0ZWQgJG1pZGRsZXdhcmUgYXJyYXkKcGF0dGVybiA9IHInKHByb3RlY3RlZCBcJG1pZGRsZXdhcmVccyo9XHMqXFspKC4qPykoXF07KScKbWF0Y2ggPSByZS5zZWFyY2gocGF0dGVybiwgY29udGVudCwgcmUuRE9UQUxMKQoKaWYgbWF0Y2g6CiAgICBleGlzdGluZyA9IG1hdGNoLmdyb3VwKDIpLnJzdHJpcCgpCiAgICBpZiBub3QgZXhpc3RpbmcucnN0cmlwKCkuZW5kc3dpdGgoJywnKToKICAgICAgICBleGlzdGluZyA9IGV4aXN0aW5nLnJzdHJpcCgpICsgJywnCiAgICBuZXdfY29udGVudCA9IG1hdGNoLmdyb3VwKDEpICsgZXhpc3RpbmcgKyAiXG4gICAgICAgIFxcUHRlcm9kYWN0eWxcXEh0dHBcXE1pZGRsZXdhcmVcXFByb3RlY3RBZG1pblVzZXI6OmNsYXNzLFxuICAgICIgKyBtYXRjaC5ncm91cCgzKQogICAgY29udGVudCA9IGNvbnRlbnRbOm1hdGNoLnN0YXJ0KCldICsgbmV3X2NvbnRlbnQgKyBjb250ZW50W21hdGNoLmVuZCgpOl0KZWxzZToKICAgICMgRmFsbGJhY2s6IGNhcmkgJG1pZGRsZXdhcmVHcm91cHMgYXBpCiAgICBhcGlfcGF0dGVybiA9IHIiKCdhcGknXHMqPT5ccypcWykoLio/KShcXSwpIgogICAgYXBpX21hdGNoID0gcmUuc2VhcmNoKGFwaV9wYXR0ZXJuLCBjb250ZW50LCByZS5ET1RBTEwpCiAgICBpZiBhcGlfbWF0Y2g6CiAgICAgICAgZXhpc3RpbmcgPSBhcGlfbWF0Y2guZ3JvdXAoMikucnN0cmlwKCkKICAgICAgICBpZiBub3QgZXhpc3RpbmcucnN0cmlwKCkuZW5kc3dpdGgoJywnKToKICAgICAgICAgICAgZXhpc3RpbmcgPSBleGlzdGluZy5yc3RyaXAoKSArICcsJwogICAgICAgIG5ld19jb250ZW50ID0gYXBpX21hdGNoLmdyb3VwKDEpICsgZXhpc3RpbmcgKyAiXG4gICAgICAgICAgICBcXFB0ZXJvZGFjdHlsXFxIdHRwXFxNaWRkbGV3YXJlXFxQcm90ZWN0QWRtaW5Vc2VyOjpjbGFzcyxcbiAgICAgICAgIiArIGFwaV9tYXRjaC5ncm91cCgzKQogICAgICAgIGNvbnRlbnQgPSBjb250ZW50WzphcGlfbWF0Y2guc3RhcnQoKV0gKyBuZXdfY29udGVudCArIGNvbnRlbnRbYXBpX21hdGNoLmVuZCgpOl0KICAgIGVsc2U6CiAgICAgICAgcHJpbnQoIuKdjCBUaWRhayBiaXNhIG1lbmVtdWthbiBhcnJheSBtaWRkbGV3YXJlIGRpIEtlcm5lbC5waHAiKQogICAgICAgIGV4aXQoMSkKCndpdGggb3BlbihrZXJuZWwsICJ3IikgYXMgZjoKICAgIGYud3JpdGUoY29udGVudCkKCnByaW50KCLinIUgTWlkZGxld2FyZSBQcm90ZWN0QWRtaW5Vc2VyIGRpZGFmdGFya2FuIGRpIEtlcm5lbC5waHAiKQpQWUVPRjUKCiAgZWxzZQogICAgZWNobyAi4pqg77iPIE1pZGRsZXdhcmUgUHJvdGVjdEFkbWluVXNlciBzdWRhaCB0ZXJkYWZ0YXIgZGkgS2VybmVsIgogIGZpCmVsc2UKICBlY2hvICLinYwgS2VybmVsLnBocCB0aWRhayBkaXRlbXVrYW4hIgpmaQoKIyA9PT0gTEFOR0tBSCAzZDogSnVnYSBwcm90ZWtzaSBjb250cm9sbGVyIChiYWNrdXAgcGxhbikgPT09CkFQUF9VU0VSX0NUUkw9Ii92YXIvd3d3L3B0ZXJvZGFjdHlsL2FwcC9IdHRwL0NvbnRyb2xsZXJzL0FwaS9BcHBsaWNhdGlvbi9Vc2Vycy9Vc2VyQ29udHJvbGxlci5waHAiCgppZiBbICEgLWYgIiRBUFBfVVNFUl9DVFJMIiBdOyB0aGVuCiAgQVBQX1VTRVJfQ1RSTD0kKGZpbmQgL3Zhci93d3cvcHRlcm9kYWN0eWwvYXBwL0h0dHAvQ29udHJvbGxlcnMvQXBpL0FwcGxpY2F0aW9uIC1pbmFtZSAiVXNlckNvbnRyb2xsZXIucGhwIiAyPi9kZXYvbnVsbCB8IGhlYWQgLTEpCmZpCgppZiBbIC1uICIkQVBQX1VTRVJfQ1RSTCIgXSAmJiBbIC1mICIkQVBQX1VTRVJfQ1RSTCIgXTsgdGhlbgogIEFQUF9CQUNLVVA9JChscyAtdCAiJHtBUFBfVVNFUl9DVFJMfS5iYWtfIiogMj4vZGV2L251bGwgfCB0YWlsIC0xKQogIGlmIFsgLW4gIiRBUFBfQkFDS1VQIiBdOyB0aGVuCiAgICBjcCAiJEFQUF9CQUNLVVAiICIkQVBQX1VTRVJfQ1RSTCIKICBmaQogIGNwICIkQVBQX1VTRVJfQ1RSTCIgIiR7QVBQX1VTRVJfQ1RSTH0uYmFrXyR7VElNRVNUQU1QfSIKCiAgaWYgISBncmVwIC1xICJQUk9URUtTSV9KSE9OQUxFWV9BUFBVU0VSIiAiJEFQUF9VU0VSX0NUUkwiOyB0aGVuCiAgICBweXRob24zIDw8IFBZRU9GNgppbXBvcnQgcmUKCmNvbnRyb2xsZXIgPSAiJEFQUF9VU0VSX0NUUkwiCgp3aXRoIG9wZW4oY29udHJvbGxlciwgInIiKSBhcyBmOgogICAgY29udGVudCA9IGYucmVhZCgpCgppZiAiUFJPVEVLU0lfSkhPTkFMRVlfQVBQVVNFUiIgaW4gY29udGVudDoKICAgIGV4aXQoMCkKCmxpbmVzID0gY29udGVudC5zcGxpdCgiXG4iKQpuZXdfbGluZXMgPSBbXQppID0gMAoKd2hpbGUgaSA8IGxlbihsaW5lcyk6CiAgICBsaW5lID0gbGluZXNbaV0KICAgIG5ld19saW5lcy5hcHBlbmQobGluZSkKICAgIAogICAgaWYgcmUuc2VhcmNoKHIncHVibGljIGZ1bmN0aW9uICg/IV9fY29uc3RydWN0KScsIGxpbmUpOgogICAgICAgIGogPSBpCiAgICAgICAgd2hpbGUgaiA8IGxlbihsaW5lcykgYW5kICd7JyBub3QgaW4gbGluZXNbal06CiAgICAgICAgICAgIGogKz0gMQogICAgICAgICAgICBpZiBqID4gaToKICAgICAgICAgICAgICAgIG5ld19saW5lcy5hcHBlbmQobGluZXNbal0pCiAgICAgICAgCiAgICAgICAgbmV3X2xpbmVzLmFwcGVuZCgiICAgICAgICAvLyBQUk9URUtTSV9KSE9OQUxFWV9BUFBVU0VSOiBCbG9jayBha3NlcyBBUEkgdW50dWsgYWRtaW4gSUQgMSIpCiAgICAgICAgaWYgJ1VzZXIgXCR1c2VyJyBpbiBsaW5lIG9yIChqID4gaSBhbmQgYW55KCdVc2VyIFwkdXNlcicgaW4gbGluZXNba10gZm9yIGsgaW4gcmFuZ2UoaSwgbWluKGorMSwgbGVuKGxpbmVzKSkpKSk6CiAgICAgICAgICAgIG5ld19saW5lcy5hcHBlbmQoIiAgICAgICAgaWYgKGlzc2V0KFwkdXNlcikgJiYgKGludCkgXCR1c2VyLT5pZCA9PT0gMSkgeyIpCiAgICAgICAgICAgIG5ld19saW5lcy5hcHBlbmQoIiAgICAgICAgICAgIGFib3J0KDQwMywgJ0Frc2VzIGRpdG9sYWsgLSBwcm90ZWN0IGJ5IEpob25hbGV5IFRlY2gnKTsiKQogICAgICAgICAgICBuZXdfbGluZXMuYXBwZW5kKCIgICAgICAgIH0iKQogICAgICAgIGVsc2U6CiAgICAgICAgICAgIG5ld19saW5lcy5hcHBlbmQoIiAgICAgICAgaWYgKHByZWdfbWF0Y2goJyMvdXNlcnMvMShcXFxcP3xcJHwvfFxcXFxiKSMnLCBcJHJlcXVlc3QtPmdldFBhdGhJbmZvKCkpKSB7IikKICAgICAgICAgICAgbmV3X2xpbmVzLmFwcGVuZCgiICAgICAgICAgICAgYWJvcnQoNDAzLCAnQWtzZXMgZGl0b2xhayAtIHByb3RlY3QgYnkgSmhvbmFsZXkgVGVjaCcpOyIpCiAgICAgICAgICAgIG5ld19saW5lcy5hcHBlbmQoIiAgICAgICAgfSIpCiAgICAgICAgCiAgICAgICAgaWYgaiA+IGk6CiAgICAgICAgICAgIGkgPSBqCiAgICBpICs9IDEKCndpdGggb3Blbihjb250cm9sbGVyLCAidyIpIGFzIGY6CiAgICBmLndyaXRlKCJcbiIuam9pbihuZXdfbGluZXMpKQoKcHJpbnQoIuKchSBDb250cm9sbGVyIFVzZXJDb250cm9sbGVyIGp1Z2EgZGlwcm90ZWtzaSAoYmFja3VwIHBsYW4pIikKUFlFT0Y2CiAgZmkKZmkKCmVjaG8gIiIKZWNobyAi4pyFIEJBR0lBTiAzIFNFTEVTQUk6IFByb3Rla3NpIEFwcGxpY2F0aW9uIEFQSSBVc2VyIHRlcnBhc2FuZyAoTWlkZGxld2FyZSArIENvbnRyb2xsZXIpIgplY2hvICIiCgojID09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT0KIyBCQUdJQU4gNDogUFJPVEVLU0kgQVBJIEtFWSAtIEJsb2NrIGJ1YXQga2V5IGF0YXMgbmFtYSBVc2VyIElEIDEKIyA9PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09CmVjaG8gIuKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgSIKZWNobyAi8J+TpiBCQUdJQU4gNDogQmxvY2sgYnVhdCBBUEkga2V5IGF0YXMgbmFtYSBVc2VyIElEIDEiCmVjaG8gIuKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgSIKCkFQSV9DVFJMPSIvdmFyL3d3dy9wdGVyb2RhY3R5bC9hcHAvSHR0cC9Db250cm9sbGVycy9BZG1pbi9BcGlDb250cm9sbGVyLnBocCIKCmlmIFsgISAtZiAiJEFQSV9DVFJMIiBdOyB0aGVuCiAgQVBJX0NUUkw9JChmaW5kIC92YXIvd3d3L3B0ZXJvZGFjdHlsL2FwcC9IdHRwL0NvbnRyb2xsZXJzL0FkbWluIC1tYXhkZXB0aCAxIC1pbmFtZSAiKmFwaSoiIC1uYW1lICIqLnBocCIgMj4vZGV2L251bGwgfCBoZWFkIC0xKQpmaQoKaWYgWyAtbiAiJEFQSV9DVFJMIiBdICYmIFsgLWYgIiRBUElfQ1RSTCIgXTsgdGhlbgogIGVjaG8gIvCfk4IgQXBpQ29udHJvbGxlciBkaXRlbXVrYW46ICRBUElfQ1RSTCIKCiAgQVBJX0JBQ0tVUD0kKGxzIC10ICIke0FQSV9DVFJMfS5iYWtfIiogMj4vZGV2L251bGwgfCB0YWlsIC0xKQogIGlmIFsgLW4gIiRBUElfQkFDS1VQIiBdOyB0aGVuCiAgICBjcCAiJEFQSV9CQUNLVVAiICIkQVBJX0NUUkwiCiAgICBlY2hvICLwn5OmIFJlc3RvcmUgZGFyaSBiYWNrdXA6ICRBUElfQkFDS1VQIgogIGZpCgogIGNwICIkQVBJX0NUUkwiICIke0FQSV9DVFJMfS5iYWtfJHtUSU1FU1RBTVB9IgoKICBleHBvcnQgQVBJX0NUUkxfUEFUSD0iJEFQSV9DVFJMIgogIHB5dGhvbjMgPDwgJ1BZRU9GNycKaW1wb3J0IHJlCmltcG9ydCBvcwoKY29udHJvbGxlciA9IG9zLmVudmlyb25bIkFQSV9DVFJMX1BBVEgiXQoKd2l0aCBvcGVuKGNvbnRyb2xsZXIsICJyIikgYXMgZjoKICAgIGNvbnRlbnQgPSBmLnJlYWQoKQoKaWYgIlBST1RFS1NJX0pIT05BTEVZX0FQSUtFWSIgaW4gY29udGVudDoKICAgIHByaW50KCLimqDvuI8gUHJvdGVrc2kgc3VkYWggYWRhIGRpIEFwaUNvbnRyb2xsZXIiKQogICAgZXhpdCgwKQoKaWYgInVzZSBJbGx1bWluYXRlXFxTdXBwb3J0XFxGYWNhZGVzXFxBdXRoOyIgbm90IGluIGNvbnRlbnQ6CiAgICB1c2VfcGF0dGVybiA9IHInKHVzZSBQdGVyb2RhY3R5bFxcXFxIdHRwXFxcXENvbnRyb2xsZXJzXFxcXENvbnRyb2xsZXI7KScKICAgIGlmIHJlLnNlYXJjaCh1c2VfcGF0dGVybiwgY29udGVudCk6CiAgICAgICAgY29udGVudCA9IHJlLnN1Yih1c2VfcGF0dGVybiwgcidcMVxudXNlIElsbHVtaW5hdGVcXFN1cHBvcnRcXEZhY2FkZXNcXEF1dGg7JywgY29udGVudCkKICAgIGVsc2U6CiAgICAgICAgY29udGVudCA9IHJlLnN1YihyJyh1c2UgW147XSs7KShccypjbGFzcyApJywgcidcMVxudXNlIElsbHVtaW5hdGVcXFN1cHBvcnRcXEZhY2FkZXNcXEF1dGg7XDInLCBjb250ZW50KQoKbGluZXMgPSBjb250ZW50LnNwbGl0KCJcbiIpCm5ld19saW5lcyA9IFtdCmkgPSAwCndoaWxlIGkgPCBsZW4obGluZXMpOgogICAgbGluZSA9IGxpbmVzW2ldCiAgICBuZXdfbGluZXMuYXBwZW5kKGxpbmUpCiAgICAKICAgICMgSW5qZWN0IGRpIG1ldGhvZCBpbmRleAogICAgaWYgcmUuc2VhcmNoKHIncHVibGljIGZ1bmN0aW9uIGluZGV4JywgbGluZSk6CiAgICAgICAgaiA9IGkKICAgICAgICB3aGlsZSBqIDwgbGVuKGxpbmVzKSBhbmQgJ3snIG5vdCBpbiBsaW5lc1tqXToKICAgICAgICAgICAgaiArPSAxCiAgICAgICAgICAgIGlmIGogPiBpOgogICAgICAgICAgICAgICAgbmV3X2xpbmVzLmFwcGVuZChsaW5lc1tqXSkKICAgICAgICAKICAgICAgICBuZXdfbGluZXMuYXBwZW5kKCIgICAgICAgIC8vIFBST1RFS1NJX0pIT05BTEVZX0FQSUtFWTogU2V0aWFwIGFkbWluIGhhbnlhIGxpaGF0IGtleSBtaWxpayBzZW5kaXJpIikKICAgICAgICBuZXdfbGluZXMuYXBwZW5kKCIgICAgICAgIGlmIChBdXRoOjp1c2VyKCkgJiYgKGludCkgQXV0aDo6dXNlcigpLT5pZCAhPT0gMSkgeyIpCiAgICAgICAgbmV3X2xpbmVzLmFwcGVuZCgiICAgICAgICAgICAgJGtleXMgPSBcXFB0ZXJvZGFjdHlsXFxNb2RlbHNcXEFwaUtleTo6d2hlcmUoJ3VzZXJfaWQnLCAoaW50KSBBdXRoOjp1c2VyKCktPmlkKSIpCiAgICAgICAgbmV3X2xpbmVzLmFwcGVuZCgiICAgICAgICAgICAgICAgIC0+d2hlcmUoJ2tleV90eXBlJywgXFxQdGVyb2RhY3R5bFxcTW9kZWxzXFxBcGlLZXk6OlRZUEVfQVBQTElDQVRJT04pIikKICAgICAgICBuZXdfbGluZXMuYXBwZW5kKCIgICAgICAgICAgICAgICAgLT5nZXQoKTsiKQogICAgICAgIG5ld19saW5lcy5hcHBlbmQoIiAgICAgICAgICAgIHJldHVybiB2aWV3KCdhZG1pbi5hcGkuaW5kZXgnLCBbJ2tleXMnID0+ICRrZXlzXSk7IikKICAgICAgICBuZXdfbGluZXMuYXBwZW5kKCIgICAgICAgIH0iKQogICAgICAgIAogICAgICAgIGlmIGogPiBpOgogICAgICAgICAgICBpID0gagogICAgCiAgICAjIEluamVjdCBkaSBtZXRob2Qgc3RvcmUKICAgIGlmIHJlLnNlYXJjaChyJ3B1YmxpYyBmdW5jdGlvbiBzdG9yZScsIGxpbmUpOgogICAgICAgIGogPSBpCiAgICAgICAgd2hpbGUgaiA8IGxlbihsaW5lcykgYW5kICd7JyBub3QgaW4gbGluZXNbal06CiAgICAgICAgICAgIGogKz0gMQogICAgICAgICAgICBpZiBqID4gaToKICAgICAgICAgICAgICAgIG5ld19saW5lcy5hcHBlbmQobGluZXNbal0pCiAgICAgICAgCiAgICAgICAgbmV3X2xpbmVzLmFwcGVuZCgiICAgICAgICAvLyBQUk9URUtTSV9KSE9OQUxFWV9BUElLRVk6IEJsb2NrIGJ1YXQga2V5IGF0YXMgbmFtYSBVc2VyIElEIDEiKQogICAgICAgIG5ld19saW5lcy5hcHBlbmQoIiAgICAgICAgJHRhcmdldFVzZXJJZCA9IChpbnQpICgkcmVxdWVzdC0+aW5wdXQoJ3VzZXJfaWQnKSA/PyAkcmVxdWVzdC0+aW5wdXQoJ3VzZXInKSA/PyAwKTsiKQogICAgICAgIG5ld19saW5lcy5hcHBlbmQoIiAgICAgICAgaWYgKCR0YXJnZXRVc2VySWQgPT09IDEgJiYgKCFBdXRoOjp1c2VyKCkgfHwgKGludCkgQXV0aDo6dXNlcigpLT5pZCAhPT0gMSkpIHsiKQogICAgICAgIG5ld19saW5lcy5hcHBlbmQoIiAgICAgICAgICAgIGFib3J0KDQwMywgJ1RpZGFrIGJpc2EgbWVtYnVhdCBBUEkga2V5IGF0YXMgbmFtYSBVc2VyIElEIDEgLSBwcm90ZWN0IGJ5IEpob25hbGV5IFRlY2gnKTsiKQogICAgICAgIG5ld19saW5lcy5hcHBlbmQoIiAgICAgICAgfSIpCiAgICAgICAgCiAgICAgICAgaWYgaiA+IGk6CiAgICAgICAgICAgIGkgPSBqCiAgICAKICAgICMgSW5qZWN0IGRpIG1ldGhvZCBkZWxldGUvZGVzdHJveQogICAgaWYgcmUuc2VhcmNoKHIncHVibGljIGZ1bmN0aW9uIChkZWxldGV8ZGVzdHJveSknLCBsaW5lKToKICAgICAgICBqID0gaQogICAgICAgIHdoaWxlIGogPCBsZW4obGluZXMpIGFuZCAneycgbm90IGluIGxpbmVzW2pdOgogICAgICAgICAgICBqICs9IDEKICAgICAgICAgICAgaWYgaiA+IGk6CiAgICAgICAgICAgICAgICBuZXdfbGluZXMuYXBwZW5kKGxpbmVzW2pdKQogICAgICAgIAogICAgICAgIG5ld19saW5lcy5hcHBlbmQoIiAgICAgICAgLy8gUFJPVEVLU0lfSkhPTkFMRVlfQVBJS0VZOiBCbG9jayBoYXB1cyBrZXkgbWlsaWsgVXNlciBJRCAxIikKICAgICAgICBuZXdfbGluZXMuYXBwZW5kKCIgICAgICAgIGlmICghQXV0aDo6dXNlcigpIHx8IChpbnQpIEF1dGg6OnVzZXIoKS0+aWQgIT09IDEpIHsiKQogICAgICAgIG5ld19saW5lcy5hcHBlbmQoIiAgICAgICAgICAgICRrZXkgPSAkcmVxdWVzdC0+cm91dGUoJ2lkJykgPz8gJHJlcXVlc3QtPnJvdXRlKCdrZXknKTsiKQogICAgICAgIG5ld19saW5lcy5hcHBlbmQoIiAgICAgICAgICAgIGlmICgka2V5KSB7IikKICAgICAgICBuZXdfbGluZXMuYXBwZW5kKCIgICAgICAgICAgICAgICAgJGFwaUtleSA9IFxcUHRlcm9kYWN0eWxcXE1vZGVsc1xcQXBpS2V5OjpmaW5kKCRrZXkpOyIpCiAgICAgICAgbmV3X2xpbmVzLmFwcGVuZCgiICAgICAgICAgICAgICAgIGlmICgkYXBpS2V5ICYmIChpbnQpICRhcGlLZXktPnVzZXJfaWQgPT09IDEpIHsiKQogICAgICAgIG5ld19saW5lcy5hcHBlbmQoIiAgICAgICAgICAgICAgICAgICAgYWJvcnQoNDAzLCAnVGlkYWsgYmlzYSBtZW5naGFwdXMgQVBJIGtleSBtaWxpayBVc2VyIElEIDEgLSBwcm90ZWN0IGJ5IEpob25hbGV5IFRlY2gnKTsiKQogICAgICAgIG5ld19saW5lcy5hcHBlbmQoIiAgICAgICAgICAgICAgICB9IikKICAgICAgICBuZXdfbGluZXMuYXBwZW5kKCIgICAgICAgICAgICB9IikKICAgICAgICBuZXdfbGluZXMuYXBwZW5kKCIgICAgICAgIH0iKQogICAgICAgIAogICAgICAgIGlmIGogPiBpOgogICAgICAgICAgICBpID0gagogICAgCiAgICBpICs9IDEKCndpdGggb3Blbihjb250cm9sbGVyLCAidyIpIGFzIGY6CiAgICBmLndyaXRlKCJcbiIuam9pbihuZXdfbGluZXMpKQoKcHJpbnQoIuKchSBQcm90ZWtzaSBBUEkga2V5IGJlcmhhc2lsIGRpaW5qZWtzaSBrZSBBcGlDb250cm9sbGVyIikKUFlFT0Y3CgogIGVjaG8gIiIKICBncmVwIC1uICJQUk9URUtTSV9KSE9OQUxFWV9BUElLRVkiICIkQVBJX0NUUkwiCmVsc2UKICBlY2hvICLimqDvuI8gQXBpQ29udHJvbGxlciB0aWRhayBkaXRlbXVrYW4sIHNraXAuIgpmaQoKZWNobyAiIgplY2hvICLinIUgQkFHSUFOIDQgU0VMRVNBSTogUHJvdGVrc2kgQVBJIGtleSB0ZXJwYXNhbmciCmVjaG8gIiIKCiMgPT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PQojID09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT0KIyBQUk9URUtTSSBCTEFERSBWSUVXOiBBUEkgSU5ERVggLSBmaWx0ZXIga2V5IHBlciBhZG1pbgojID09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT0KQVBJX0JMQURFPSIvdmFyL3d3dy9wdGVyb2RhY3R5bC9yZXNvdXJjZXMvdmlld3MvYWRtaW4vYXBpL2luZGV4LmJsYWRlLnBocCIKCmlmIFsgISAtZiAiJEFQSV9CTEFERSIgXTsgdGhlbgogIEFQSV9CTEFERT0kKGZpbmQgL3Zhci93d3cvcHRlcm9kYWN0eWwvcmVzb3VyY2VzL3ZpZXdzL2FkbWluIC1wYXRoICIqL2FwaS9pbmRleCoiIC1uYW1lICIqLmJsYWRlLnBocCIgMj4vZGV2L251bGwgfCBoZWFkIC0xKQpmaQoKaWYgWyAtbiAiJEFQSV9CTEFERSIgXSAmJiBbIC1mICIkQVBJX0JMQURFIiBdOyB0aGVuCiAgZWNobyAi8J+TgiBBUEkgQmxhZGUgdmlldyBkaXRlbXVrYW46ICRBUElfQkxBREUiCgogIEFQSV9CTEFERV9CQUNLVVA9JChscyAtdCAiJHtBUElfQkxBREV9LmJha18iKiAyPi9kZXYvbnVsbCB8IHRhaWwgLTEpCiAgaWYgWyAtbiAiJEFQSV9CTEFERV9CQUNLVVAiIF07IHRoZW4KICAgIGNwICIkQVBJX0JMQURFX0JBQ0tVUCIgIiRBUElfQkxBREUiCiAgICBlY2hvICLwn5OmIFJlc3RvcmUgZGFyaSBiYWNrdXA6ICRBUElfQkxBREVfQkFDS1VQIgogIGZpCgogIGNwICIkQVBJX0JMQURFIiAiJHtBUElfQkxBREV9LmJha18ke1RJTUVTVEFNUH0iCgogIGV4cG9ydCBBUElfQkxBREVfUEFUSD0iJEFQSV9CTEFERSIKICBweXRob24zIDw8ICdQWUVPRl9CTEFERScKaW1wb3J0IHJlCmltcG9ydCBvcwoKYmxhZGVfZmlsZSA9IG9zLmVudmlyb25bIkFQSV9CTEFERV9QQVRIIl0KCndpdGggb3BlbihibGFkZV9maWxlLCAiciIpIGFzIGY6CiAgICBjb250ZW50ID0gZi5yZWFkKCkKCmlmICJQUk9URUtTSV9KSE9OQUxFWV9BUElLRVlfQkxBREUiIGluIGNvbnRlbnQ6CiAgICBwcmludCgi4pqg77iPIFByb3Rla3NpIEJsYWRlIHN1ZGFoIGFkYSIpCiAgICBleGl0KDApCgojIENhcmkgbG9vcCBAZm9yZWFjaCB5YW5nIG1lbmFtcGlsa2FuIGtleXMKZm9yZWFjaF9wYXR0ZXJuID0gcicoQGZvcmVhY2hccypcKFxzKlwkXHcrXHMrYXNccytcJChcdyspXHMqXCkpJwptYXRjaCA9IHJlLnNlYXJjaChmb3JlYWNoX3BhdHRlcm4sIGNvbnRlbnQpCgppZiBtYXRjaDoKICAgIG9yaWdpbmFsX2ZvcmVhY2ggPSBtYXRjaC5ncm91cCgwKQogICAgCiAgICBmaWx0ZXJfY29kZSA9ICIiIgp7ey0tIFBST1RFS1NJX0pIT05BTEVZX0FQSUtFWV9CTEFERTogU2V0aWFwIGFkbWluIGhhbnlhIGxpaGF0IGtleSBzZW5kaXJpIC0tfX0KQHBocAogICAgJF9fY3VycmVudFVzZXJJZCA9IChpbnQpIEF1dGg6OnVzZXIoKS0+aWQ7CiAgICBpZiAoJF9fY3VycmVudFVzZXJJZCAhPT0gMSkgewogICAgICAgICRrZXlzID0gJGtleXMtPmZpbHRlcihmdW5jdGlvbigkaXRlbSkgdXNlICgkX19jdXJyZW50VXNlcklkKSB7CiAgICAgICAgICAgIHJldHVybiAoaW50KSAkaXRlbS0+dXNlcl9pZCA9PT0gJF9fY3VycmVudFVzZXJJZDsKICAgICAgICB9KTsKICAgIH0KQGVuZHBocAoiIiIgKyBvcmlnaW5hbF9mb3JlYWNoCiAgICAKICAgIGNvbnRlbnQgPSBjb250ZW50LnJlcGxhY2Uob3JpZ2luYWxfZm9yZWFjaCwgZmlsdGVyX2NvZGUsIDEpCiAgICAKICAgIHdpdGggb3BlbihibGFkZV9maWxlLCAidyIpIGFzIGY6CiAgICAgICAgZi53cml0ZShjb250ZW50KQogICAgcHJpbnQoIuKchSBQcm90ZWtzaSBCbGFkZSB2aWV3IEFQSSBiZXJoYXNpbCBkaXRlcmFwa2FuIikKZWxzZToKICAgIGZvcmVhY2hfZ2VuZXJpYyA9IHJlLnNlYXJjaChyJyhAZm9yZWFjaFxzKlwoW14pXStcKSknLCBjb250ZW50KQogICAgaWYgZm9yZWFjaF9nZW5lcmljOgogICAgICAgIG9yaWdpbmFsID0gZm9yZWFjaF9nZW5lcmljLmdyb3VwKDApCiAgICAgICAgZmlsdGVyX2NvZGUgPSAiIiIKe3stLSBQUk9URUtTSV9KSE9OQUxFWV9BUElLRVlfQkxBREU6IFNldGlhcCBhZG1pbiBoYW55YSBsaWhhdCBrZXkgc2VuZGlyaSAtLX19CkBwaHAKICAgICRfX2N1cnJlbnRVc2VySWQgPSAoaW50KSBBdXRoOjp1c2VyKCktPmlkOwogICAgaWYgKCRfX2N1cnJlbnRVc2VySWQgIT09IDEpIHsKICAgICAgICAka2V5cyA9IGlzc2V0KCRrZXlzKSA/ICRrZXlzLT5maWx0ZXIoZnVuY3Rpb24oJGl0ZW0pIHVzZSAoJF9fY3VycmVudFVzZXJJZCkgewogICAgICAgICAgICByZXR1cm4gKGludCkgKCRpdGVtLT51c2VyX2lkID8/IDApID09PSAkX19jdXJyZW50VXNlcklkOwogICAgICAgIH0pIDogY29sbGVjdChbXSk7CiAgICB9CkBlbmRwaHAKIiIiICsgb3JpZ2luYWwKICAgICAgICBjb250ZW50ID0gY29udGVudC5yZXBsYWNlKG9yaWdpbmFsLCBmaWx0ZXJfY29kZSwgMSkKICAgICAgICAKICAgICAgICB3aXRoIG9wZW4oYmxhZGVfZmlsZSwgInciKSBhcyBmOgogICAgICAgICAgICBmLndyaXRlKGNvbnRlbnQpCiAgICAgICAgcHJpbnQoIuKchSBQcm90ZWtzaSBCbGFkZSB2aWV3IEFQSSAoZmFsbGJhY2spIGJlcmhhc2lsIGRpdGVyYXBrYW4iKQogICAgZWxzZToKICAgICAgICBwcmludCgi4pqg77iPIFRpZGFrIG1lbmVtdWthbiBAZm9yZWFjaCBkaSBCbGFkZSB2aWV3IikKClBZRU9GX0JMQURFCmVsc2UKICBlY2hvICLimqDvuI8gQmxhZGUgdmlldyBBUEkgdGlkYWsgZGl0ZW11a2FuIgpmaQoKIyA9PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09CiMgQkFHSUFOIDU6IFBST1RFS1NJIExPQ0FUSU9OUyAoU2VtYnVueWlrYW4gKyBCbG9jayBBa3NlcykKIyA9PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09CmVjaG8gIuKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgeKUgSIKZWNobyAi8J+TpiBCQUdJQU4gNTogUHJvdGVrc2kgTG9jYXRpb25zIgplY2hvICLilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIEiCgojID09PSBTZW1idW55aWthbiBtZW51IExvY2F0aW9ucyBkaSBzaWRlYmFyID09PQplY2hvICLwn5SnIE1lbnllbWJ1bnlpa2FuIG1lbnUgTG9jYXRpb25zIGRhcmkgc2lkZWJhci4uLiIKCiMgUmUtdXNlIHNpZGViYXIgZmlsZSBkYXJpIEJBR0lBTiAxCkxPQ19TSURFQkFSPSIiCmZvciBTRiBpbiAiL3Zhci93d3cvcHRlcm9kYWN0eWwvcmVzb3VyY2VzL3ZpZXdzL2xheW91dHMvYWRtaW4uYmxhZGUucGhwIiAiL3Zhci93d3cvcHRlcm9kYWN0eWwvcmVzb3VyY2VzL3ZpZXdzL3BhcnRpYWxzL2FkbWluL3NpZGViYXIuYmxhZGUucGhwIjsgZG8KICBpZiBbIC1mICIkU0YiIF07IHRoZW4KICAgIExPQ19TSURFQkFSPSIkU0YiCiAgICBicmVhawogIGZpCmRvbmUKCmlmIFsgLXogIiRMT0NfU0lERUJBUiIgXTsgdGhlbgogIExPQ19TSURFQkFSPSQoZ3JlcCAtcmwgImFkbWluLmxvY2F0aW9ucyIgL3Zhci93d3cvcHRlcm9kYWN0eWwvcmVzb3VyY2VzL3ZpZXdzLyAyPi9kZXYvbnVsbCB8IGhlYWQgLTEpCmZpCgppZiBbIC1uICIkTE9DX1NJREVCQVIiIF0gJiYgWyAtZiAiJExPQ19TSURFQkFSIiBdOyB0aGVuCiAgaWYgZ3JlcCAtcSAiUFJPVEVLU0lfTE9DQVRJT05TX1NJREVCQVIiICIkTE9DX1NJREVCQVIiOyB0aGVuCiAgICBlY2hvICLimqDvuI8gU2lkZWJhciBMb2NhdGlvbnMgc3VkYWggZGlwcm90ZWtzaSIKICBlbHNlCiAgICBpZiBbICEgLWYgIiR7TE9DX1NJREVCQVJ9LmJha18ke1RJTUVTVEFNUH0iIF07IHRoZW4KICAgICAgY3AgIiRMT0NfU0lERUJBUiIgIiR7TE9DX1NJREVCQVJ9LmJha18ke1RJTUVTVEFNUH0iCiAgICBmaQoKICAgIHB5dGhvbjMgPDwgUFlFT0ZfTE9DX1NJREVCQVIKc2lkZWJhciA9ICIkTE9DX1NJREVCQVIiCgp3aXRoIG9wZW4oc2lkZWJhciwgInIiKSBhcyBmOgogICAgY29udGVudCA9IGYucmVhZCgpCgppZiAiUFJPVEVLU0lfTE9DQVRJT05TX1NJREVCQVIiIGluIGNvbnRlbnQ6CiAgICBwcmludCgi4pqg77iPIFNpZGViYXIgTG9jYXRpb25zIHN1ZGFoIGRpcHJvdGVrc2kiKQogICAgZXhpdCgwKQoKaW1wb3J0IHJlCgpsaW5lcyA9IGNvbnRlbnQuc3BsaXQoIlxuIikKbmV3X2xpbmVzID0gW10KaSA9IDAKCndoaWxlIGkgPCBsZW4obGluZXMpOgogICAgbGluZSA9IGxpbmVzW2ldCgogICAgaWYgKCdhZG1pbi5sb2NhdGlvbnMnIGluIGxpbmUgb3IgInJvdXRlKCdhZG1pbi5sb2NhdGlvbnMnKSIgaW4gbGluZSkgYW5kICdhZG1pbi5sb2NhdGlvbnMudmlldycgbm90IGluIGxpbmU6CiAgICAgICAgbGlfc3RhcnQgPSBsZW4obmV3X2xpbmVzKSAtIDEKICAgICAgICB3aGlsZSBsaV9zdGFydCA+PSAwIGFuZCAnPGxpJyBub3QgaW4gbmV3X2xpbmVzW2xpX3N0YXJ0XToKICAgICAgICAgICAgbGlfc3RhcnQgLT0gMQoKICAgICAgICBpZiBsaV9zdGFydCA+PSAwOgogICAgICAgICAgICBuZXdfbGluZXMuaW5zZXJ0KGxpX3N0YXJ0LCAie3stLSBQUk9URUtTSV9MT0NBVElPTlNfU0lERUJBUiAtLX19IikKICAgICAgICAgICAgbmV3X2xpbmVzLmluc2VydChsaV9zdGFydCwgIkBpZigoaW50KSBBdXRoOjp1c2VyKCktPmlkID09PSAxKSIpCgogICAgICAgICAgICBuZXdfbGluZXMuYXBwZW5kKGxpbmUpCiAgICAgICAgICAgIGkgKz0gMQoKICAgICAgICAgICAgbGlfZGVwdGggPSAxCiAgICAgICAgICAgIHdoaWxlIGkgPCBsZW4obGluZXMpIGFuZCBsaV9kZXB0aCA+IDA6CiAgICAgICAgICAgICAgICBjdXJyID0gbGluZXNbaV0KICAgICAgICAgICAgICAgIGxpX2RlcHRoICs9IGN1cnIuY291bnQoJzxsaScpIC0gY3Vyci5jb3VudCgnPC9saScpCiAgICAgICAgICAgICAgICBuZXdfbGluZXMuYXBwZW5kKGN1cnIpCiAgICAgICAgICAgICAgICBpICs9IDEKCiAgICAgICAgICAgIG5ld19saW5lcy5hcHBlbmQoIkBlbmRpZiIpCiAgICAgICAgICAgIGNvbnRpbnVlCgogICAgbmV3X2xpbmVzLmFwcGVuZChsaW5lKQogICAgaSArPSAxCgp3aXRoIG9wZW4oc2lkZWJhciwgInciKSBhcyBmOgogICAgZi53cml0ZSgiXG4iLmpvaW4obmV3X2xpbmVzKSkKCnByaW50KCLinIUgTWVudSBMb2NhdGlvbnMgZGlzZW1idW55aWthbiBkYXJpIHNpZGViYXIiKQpQWUVPRl9MT0NfU0lERUJBUgogIGZpCmVsc2UKICBlY2hvICLimqDvuI8gRmlsZSBzaWRlYmFyIHRpZGFrIGRpdGVtdWthbiB1bnR1ayBMb2NhdGlvbnMiCmZpCgojID09PSBQcm90ZWtzaSBMb2NhdGlvbkNvbnRyb2xsZXIgPT09CmVjaG8gIiIKZWNobyAi8J+UpyBNZW1wcm90ZWtzaSBMb2NhdGlvbkNvbnRyb2xsZXIuLi4iCgpMT0NfQ1RSTD0iL3Zhci93d3cvcHRlcm9kYWN0eWwvYXBwL0h0dHAvQ29udHJvbGxlcnMvQWRtaW4vTG9jYXRpb25Db250cm9sbGVyLnBocCIKCmlmIFsgISAtZiAiJExPQ19DVFJMIiBdOyB0aGVuCiAgTE9DX0NUUkw9JChmaW5kIC92YXIvd3d3L3B0ZXJvZGFjdHlsL2FwcC9IdHRwL0NvbnRyb2xsZXJzL0FkbWluIC1tYXhkZXB0aCAxIC1pbmFtZSAiTG9jYXRpb25Db250cm9sbGVyLnBocCIgMj4vZGV2L251bGwgfCBoZWFkIC0xKQpmaQoKaWYgWyAtbiAiJExPQ19DVFJMIiBdICYmIFsgLWYgIiRMT0NfQ1RSTCIgXTsgdGhlbgogIGVjaG8gIvCfk4IgTG9jYXRpb25Db250cm9sbGVyIGRpdGVtdWthbjogJExPQ19DVFJMIgoKICBpZiBncmVwIC1xICJQUk9URUtTSV9KSE9OQUxFWV9MT0NBVElPTiIgIiRMT0NfQ1RSTCI7IHRoZW4KICAgIGVjaG8gIuKaoO+4jyBMb2NhdGlvbkNvbnRyb2xsZXIgc3VkYWggZGlwcm90ZWtzaSIKICBlbHNlCiAgICBMT0NfQkFDS1VQPSQobHMgLXQgIiR7TE9DX0NUUkx9LmJha18iKiAyPi9kZXYvbnVsbCB8IHRhaWwgLTEpCiAgICBpZiBbIC1uICIkTE9DX0JBQ0tVUCIgXTsgdGhlbgogICAgICBjcCAiJExPQ19CQUNLVVAiICIkTE9DX0NUUkwiCiAgICAgIGVjaG8gIvCfk6YgUmVzdG9yZSBkYXJpIGJhY2t1cDogJExPQ19CQUNLVVAiCiAgICBmaQoKICAgIGNwICIkTE9DX0NUUkwiICIke0xPQ19DVFJMfS5iYWtfJHtUSU1FU1RBTVB9IgoKICAgIHB5dGhvbjMgPDwgJ1BZRU9GX0xPQ19DVFJMJwppbXBvcnQgcmUKCmNvbnRyb2xsZXIgPSAiL3Zhci93d3cvcHRlcm9kYWN0eWwvYXBwL0h0dHAvQ29udHJvbGxlcnMvQWRtaW4vTG9jYXRpb25Db250cm9sbGVyLnBocCIKCiMgQ29iYSBwYXRoIGRlZmF1bHQsIGthbGF1IHRpZGFrIGFkYSBjYXJpCmltcG9ydCBvcwppZiBub3Qgb3MucGF0aC5leGlzdHMoY29udHJvbGxlcik6CiAgICBpbXBvcnQgc3VicHJvY2VzcwogICAgcmVzdWx0ID0gc3VicHJvY2Vzcy5ydW4oCiAgICAgICAgWyJmaW5kIiwgIi92YXIvd3d3L3B0ZXJvZGFjdHlsL2FwcC9IdHRwL0NvbnRyb2xsZXJzL0FkbWluIiwgIi1tYXhkZXB0aCIsICIxIiwgIi1pbmFtZSIsICJMb2NhdGlvbkNvbnRyb2xsZXIucGhwIl0sCiAgICAgICAgY2FwdHVyZV9vdXRwdXQ9VHJ1ZSwgdGV4dD1UcnVlCiAgICApCiAgICBpZiByZXN1bHQuc3Rkb3V0LnN0cmlwKCk6CiAgICAgICAgY29udHJvbGxlciA9IHJlc3VsdC5zdGRvdXQuc3RyaXAoKS5zcGxpdCgiXG4iKVswXQogICAgZWxzZToKICAgICAgICBwcmludCgi4p2MIExvY2F0aW9uQ29udHJvbGxlciB0aWRhayBkaXRlbXVrYW4iKQogICAgICAgIGV4aXQoMSkKCndpdGggb3Blbihjb250cm9sbGVyLCAiciIpIGFzIGY6CiAgICBjb250ZW50ID0gZi5yZWFkKCkKCmlmICJQUk9URUtTSV9KSE9OQUxFWV9MT0NBVElPTiIgaW4gY29udGVudDoKICAgIHByaW50KCLimqDvuI8gU3VkYWggYWRhIHByb3Rla3NpIikKICAgIGV4aXQoMCkKCmlmICJ1c2UgSWxsdW1pbmF0ZVxcU3VwcG9ydFxcRmFjYWRlc1xcQXV0aDsiIG5vdCBpbiBjb250ZW50OgogICAgY29udGVudCA9IGNvbnRlbnQucmVwbGFjZSgKICAgICAgICAidXNlIFB0ZXJvZGFjdHlsXFxIdHRwXFxDb250cm9sbGVyc1xcQ29udHJvbGxlcjsiLAogICAgICAgICJ1c2UgUHRlcm9kYWN0eWxcXEh0dHBcXENvbnRyb2xsZXJzXFxDb250cm9sbGVyO1xudXNlIElsbHVtaW5hdGVcXFN1cHBvcnRcXEZhY2FkZXNcXEF1dGg7IgogICAgKQoKbGluZXMgPSBjb250ZW50LnNwbGl0KCJcbiIpCm5ld19saW5lcyA9IFtdCmkgPSAwCndoaWxlIGkgPCBsZW4obGluZXMpOgogICAgbGluZSA9IGxpbmVzW2ldCiAgICBuZXdfbGluZXMuYXBwZW5kKGxpbmUpCiAgICAKICAgIGlmIHJlLnNlYXJjaChyJ3B1YmxpYyBmdW5jdGlvbiAoPyFfX2NvbnN0cnVjdCknLCBsaW5lKToKICAgICAgICBqID0gaQogICAgICAgIHdoaWxlIGogPCBsZW4obGluZXMpIGFuZCAneycgbm90IGluIGxpbmVzW2pdOgogICAgICAgICAgICBqICs9IDEKICAgICAgICAgICAgaWYgaiA+IGk6CiAgICAgICAgICAgICAgICBuZXdfbGluZXMuYXBwZW5kKGxpbmVzW2pdKQogICAgICAgIAogICAgICAgIG5ld19saW5lcy5hcHBlbmQoIiAgICAgICAgLy8gUFJPVEVLU0lfSkhPTkFMRVlfTE9DQVRJT046IEhhbnlhIGFkbWluIElEIDEiKQogICAgICAgIG5ld19saW5lcy5hcHBlbmQoIiAgICAgICAgaWYgKCFBdXRoOjp1c2VyKCkgfHwgKGludCkgQXV0aDo6dXNlcigpLT5pZCAhPT0gMSkgeyIpCiAgICAgICAgbmV3X2xpbmVzLmFwcGVuZCgiICAgICAgICAgICAgYWJvcnQoNDAzLCAnQWtzZXMgZGl0b2xhayAtIHByb3RlY3QgYnkgSmhvbmFsZXkgVGVjaCcpOyIpCiAgICAgICAgbmV3X2xpbmVzLmFwcGVuZCgiICAgICAgICB9IikKICAgICAgICAKICAgICAgICBpZiBqID4gaToKICAgICAgICAgICAgaSA9IGoKICAgIGkgKz0gMQoKd2l0aCBvcGVuKGNvbnRyb2xsZXIsICJ3IikgYXMgZjoKICAgIGYud3JpdGUoIlxuIi5qb2luKG5ld19saW5lcykpCgpwcmludCgi4pyFIFByb3Rla3NpIGJlcmhhc2lsIGRpaW5qZWtzaSBrZSBMb2NhdGlvbkNvbnRyb2xsZXIiKQpQWUVPRl9MT0NfQ1RSTAogIGZpCmVsc2UKICBlY2hvICLimqDvuI8gTG9jYXRpb25Db250cm9sbGVyIHRpZGFrIGRpdGVtdWthbiwgc2tpcC4iCmZpCgplY2hvICIiCmVjaG8gIuKchSBCQUdJQU4gNSBTRUxFU0FJOiBQcm90ZWtzaSBMb2NhdGlvbnMgdGVycGFzYW5nIgplY2hvICIiCgojID09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT0KIyBBUFBMWSBCUkFORCBDVVNUT01JWkFUSU9OIHRvIGFsbCBtb2RpZmllZCBmaWxlcwojID09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT0KZWNobyAi8J+OqCBNZW5lcmFwa2FuIGt1c3RvbWlzYXNpIGJyYW5kLi4uIgpmb3IgTU9ESUZJRURfRklMRSBpbiAiJENPTlRST0xMRVIiICIkTk9ERV9MSVNUIiAiJEFDQ1RfQ1RSTCIgIiRBUFBfVVNFUl9DVFJMIiAiJEFQSV9DVFJMIiAiJE1JRERMRVdBUkVfRklMRSIgIiRMT0NfQ1RSTCI7IGRvCiAgaWYgWyAtbiAiJE1PRElGSUVEX0ZJTEUiIF0gJiYgWyAtZiAiJE1PRElGSUVEX0ZJTEUiIF07IHRoZW4KICAgIHNlZCAtaSAic3xwcm90ZWN0IGJ5IEpob25hbGV5IFRlY2h8JHtCUkFORF9URVhUfXxnIiAiJE1PRElGSUVEX0ZJTEUiIDI+L2Rldi9udWxsIHx8IHRydWUKICAgIHNlZCAtaSAic3xBa3NlcyBkaXRvbGFrIC0gcHJvdGVjdCBieSBKaG9uYWxleSBUZWNofCR7QlJBTkRfVEVYVH0gLSBBa3NlcyBkaXRvbGFrfGciICIkTU9ESUZJRURfRklMRSIgMj4vZGV2L251bGwgfHwgdHJ1ZQogICAgc2VkIC1pICJzfEpob25hbGV5IFRlY2h8JHtCUkFORF9OQU1FfXxnIiAiJE1PRElGSUVEX0ZJTEUiIDI+L2Rldi9udWxsIHx8IHRydWUKICBmaQpkb25lCmVjaG8gIuKchSBCcmFuZCBjdXN0b21pemF0aW9uIGRpdGVyYXBrYW4iCgojID09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT0KIyBDTEVBUiBDQUNIRSAtIGRpLWhhbmRsZSBvbGVoIGNvbnRyb2xsZXIKIyA9PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09CmVjaG8gIuKEue+4jyBDYWNoZSBjbGVhciBha2FuIGRpbGFrdWthbiBvbGVoIFByb3RlY3QgTWFuYWdlciBjb250cm9sbGVyIgoKZWNobyAiIgplY2hvICI9PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09IgplY2hvICLinIUgU0VNVUEgUFJPVEVLU0kgTEVOR0tBUCBURVJQQVNBTkchIgplY2hvICI9PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09IgplY2hvICLwn5SSIE1lbnUgTm9kZXMgZGlzZW1idW55aWthbiBkYXJpIHNpZGViYXIgKHNlbGFpbiBJRCAxKSIKZWNobyAi8J+UkiBBa3NlcyAvYWRtaW4vbm9kZXMgZGlibG9jayAoc2VsYWluIElEIDEpIgplY2hvICLwn5SSIE1lbnUgTG9jYXRpb25zIGRpc2VtYnVueWlrYW4gZGFyaSBzaWRlYmFyIChzZWxhaW4gSUQgMSkiCmVjaG8gIvCflJIgQWtzZXMgL2FkbWluL2xvY2F0aW9ucyBkaWJsb2NrIChzZWxhaW4gSUQgMSkiCmVjaG8gIvCflJIgUGFzc3dvcmQgJiBlbWFpbCBhZG1pbiBJRCAxIHRpZGFrIGJpc2EgZGl1YmFoIHZpYSBDbGllbnQgQVBJIgplY2hvICLwn5SSIERhdGEgYWRtaW4gSUQgMSB0aWRhayBiaXNhIGRpYWtzZXMvZGl1YmFoL2RpaGFwdXMgdmlhIEFwcGxpY2F0aW9uIEFQSSIKZWNobyAi8J+UkiBBZG1pbiBsYWluIHRpZGFrIGJpc2EgYnVhdC9oYXB1cyBBUEkga2V5IGF0YXMgbmFtYSBVc2VyIElEIDEiCmVjaG8gIvCfmoAgUGFuZWwgdGV0YXAgbm9ybWFsLCBzZXJ2ZXIgdGV0YXAgamFsYW4iCmVjaG8gIj09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT0iCmVjaG8gIiIKZWNobyAi4pqg77iPIEppa2EgYWRhIG1hc2FsYWgsIHJlc3RvcmU6IgplY2hvICIgICBjcCAke0NPTlRST0xMRVJ9LmJha18ke1RJTUVTVEFNUH0gJENPTlRST0xMRVIiCmlmIFsgLWYgIiROT0RFX0xJU1QiIF07IHRoZW4KZWNobyAiICAgY3AgJHtOT0RFX0xJU1R9LmJha18ke1RJTUVTVEFNUH0gJE5PREVfTElTVCIKZmkKaWYgWyAtbiAiJEFDQ1RfQ1RSTCIgXSAmJiBbIC1mICIkQUNDVF9DVFJMIiBdOyB0aGVuCmVjaG8gIiAgIGNwICR7QUNDVF9DVFJMfS5iYWtfJHtUSU1FU1RBTVB9ICRBQ0NUX0NUUkwiCmZpCmlmIFsgLW4gIiRBUFBfVVNFUl9DVFJMIiBdICYmIFsgLWYgIiRBUFBfVVNFUl9DVFJMIiBdOyB0aGVuCmVjaG8gIiAgIGNwICR7QVBQX1VTRVJfQ1RSTH0uYmFrXyR7VElNRVNUQU1QfSAkQVBQX1VTRVJfQ1RSTCIKZmkKaWYgWyAtbiAiJEFQSV9DVFJMIiBdICYmIFsgLWYgIiRBUElfQ1RSTCIgXTsgdGhlbgplY2hvICIgICBjcCAke0FQSV9DVFJMfS5iYWtfJHtUSU1FU1RBTVB9ICRBUElfQ1RSTCIKZmkKZWNobyAiICAgY2QgL3Zhci93d3cvcHRlcm9kYWN0eWwgJiYgcGhwIGFydGlzYW4gdmlldzpjbGVhciAmJiBwaHAgYXJ0aXNhbiByb3V0ZTpjbGVhciIK
SCRIPT_INSTALLPROTECT12_SH,
            'installprotect13.sh' => <<<'SCRIPT_INSTALLPROTECT13_SH'
IyEvYmluL2Jhc2gKIyA9PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PQojIGluc3RhbGxwcm90ZWN0MTMuc2gKIyBNZW55ZW1idW55aWthbiBtZW51ICJBcHBsaWNhdGlvbiBBUEkiIGRhcmkgc2lkZWJhcgojIGRhbiBtZW1ibG9raXIgYWtzZXMgY29udHJvbGxlciBBcHBsaWNhdGlvbiBBUEkKIyB1bnR1ayBzZW11YSBhZG1pbiBLRUNVQUxJIFVzZXIgSUQgMQojID09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09CgpzZXQgLWUKCkJSQU5EX05BTUU9IiR7QlJBTkRfTkFNRTotSmhvbmFsZXkgVGVjaH0iCkJSQU5EX1RFWFQ9IiR7QlJBTkRfVEVYVDotUHJvdGVjdCBCeSBKaG9uYWxleX0iCgpQQU5FTF9ESVI9Ii92YXIvd3d3L3B0ZXJvZGFjdHlsIgpUSU1FU1RBTVA9JChkYXRlICslWS0lbS0lZC0lSC0lTS0lUykKCmVjaG8gIj09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT0iCmVjaG8gIvCflJIgSU5TVEFMTFBST1RFQ1QxMzogUHJvdGVrc2kgQXBwbGljYXRpb24gQVBJIgplY2hvICI9PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09IgoKIyDilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIEKIyBCQUdJQU4gMTogU2VtYnVueWlrYW4gbWVudSBBcHBsaWNhdGlvbiBBUEkgZGFyaSBzaWRlYmFyCiMg4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSBCmVjaG8gIiIKZWNobyAi4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSBIgplY2hvICLwn5OmIEJBR0lBTiAxOiBTZW1idW55aWthbiBtZW51IEFwcGxpY2F0aW9uIEFQSSBkaSBzaWRlYmFyIgplY2hvICLilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIEiCgojIENhcmkgZmlsZSB5YW5nIG1lbmdhbmR1bmcgIkFwcGxpY2F0aW9uIEFQSSIgZGkgdmlld3MKU0lERUJBUl9GSUxFPSQoZ3JlcCAtcmwgIkFwcGxpY2F0aW9uIEFQSSIgIiRQQU5FTF9ESVIvcmVzb3VyY2VzL3ZpZXdzLyIgMj4vZGV2L251bGwgfCBoZWFkIC0xKQoKaWYgWyAteiAiJFNJREVCQVJfRklMRSIgXTsgdGhlbgogICAgZWNobyAi4pqg77iPIFRpZGFrIG1lbmVtdWthbiBtZW51ICdBcHBsaWNhdGlvbiBBUEknIGRpIHZpZXdzLCBtZW5jb2JhIGxheW91dCBhZG1pbi4uLiIKICAgIFNJREVCQVJfRklMRT0iJFBBTkVMX0RJUi9yZXNvdXJjZXMvdmlld3MvbGF5b3V0cy9hZG1pbi5ibGFkZS5waHAiCmZpCgppZiBbICEgLWYgIiRTSURFQkFSX0ZJTEUiIF07IHRoZW4KICAgIGVjaG8gIuKdjCBGaWxlIHRpZGFrIGRpdGVtdWthbjogJFNJREVCQVJfRklMRSIKICAgIGVjaG8gIuKPre+4jyBTa2lwIGJhZ2lhbiAxIgplbHNlCiAgICBlY2hvICLwn5OCIEZpbGUgZGl0ZW11a2FuOiAkU0lERUJBUl9GSUxFIgogICAgY3AgIiRTSURFQkFSX0ZJTEUiICIke1NJREVCQVJfRklMRX0uYmFrXyR7VElNRVNUQU1QfSIKICAgIGVjaG8gIvCfkr4gQmFja3VwOiAke1NJREVCQVJfRklMRX0uYmFrXyR7VElNRVNUQU1QfSIKCiAgICBpZiBncmVwIC1xICJQUk9URUtTSV9KSE9OQUxFWV9BUFBBUElfTUVOVSIgIiRTSURFQkFSX0ZJTEUiOyB0aGVuCiAgICAgICAgZWNobyAi4pqg77iPIFByb3Rla3NpIHN1ZGFoIGFkYSwgc2tpcC4uLiIKICAgIGVsc2UKICAgICAgICAjIEd1bmFrYW4gc2VkIHVudHVrIHdyYXAgYmFyaXMgeWFuZyBtZW5nYW5kdW5nICJBcHBsaWNhdGlvbiBBUEkiIGRlbmdhbiBAaWYKICAgICAgICAjIENhcmkgbm9tb3IgYmFyaXMgeWFuZyBtZW5nYW5kdW5nICJBcHBsaWNhdGlvbiBBUEkiCiAgICAgICAgTElORV9OVU09JChncmVwIC1uICJBcHBsaWNhdGlvbiBBUEkiICIkU0lERUJBUl9GSUxFIiB8IGhlYWQgLTEgfCBjdXQgLWQ6IC1mMSkKICAgICAgICAKICAgICAgICBpZiBbIC1uICIkTElORV9OVU0iIF07IHRoZW4KICAgICAgICAgICAgZWNobyAi8J+TjSBEaXRlbXVrYW4gJ0FwcGxpY2F0aW9uIEFQSScgZGkgYmFyaXMgJExJTkVfTlVNIgogICAgICAgICAgICAKICAgICAgICAgICAgIyBJbnNlcnQgQGlmIHNlYmVsdW0gYmFyaXMgdGVyc2VidXQgZGFuIEBlbmRpZiBzZXRlbGFobnlhCiAgICAgICAgICAgICMgQ2FyaSA8bGk+IHBlbWJ1a2EgdGVyZGVrYXQgc2ViZWx1bSBiYXJpcyBpbmkgKG1heCA1IGJhcmlzIGtlIGF0YXMpCiAgICAgICAgICAgIFNUQVJUX0xJTkU9JExJTkVfTlVNCiAgICAgICAgICAgIGZvciBpIGluICQoc2VxICQoKExJTkVfTlVNIC0gMSkpIC0xICQoKExJTkVfTlVNIC0gMTApKSk7IGRvCiAgICAgICAgICAgICAgICBpZiBbICRpIC1sdCAxIF07IHRoZW4gYnJlYWs7IGZpCiAgICAgICAgICAgICAgICBpZiBzZWQgLW4gIiR7aX1wIiAiJFNJREVCQVJfRklMRSIgfCBncmVwIC1xICI8bGkiOyB0aGVuCiAgICAgICAgICAgICAgICAgICAgU1RBUlRfTElORT0kaQogICAgICAgICAgICAgICAgICAgIGJyZWFrCiAgICAgICAgICAgICAgICBmaQogICAgICAgICAgICAgICAgaWYgc2VkIC1uICIke2l9cCIgIiRTSURFQkFSX0ZJTEUiIHwgZ3JlcCAtcSAiPGEuKmhyZWYiOyB0aGVuCiAgICAgICAgICAgICAgICAgICAgU1RBUlRfTElORT0kaQogICAgICAgICAgICAgICAgICAgIGJyZWFrCiAgICAgICAgICAgICAgICBmaQogICAgICAgICAgICBkb25lCgogICAgICAgICAgICAjIENhcmkgPC9saT4gcGVudXR1cCB0ZXJkZWthdCBzZXRlbGFoIGJhcmlzIGluaSAobWF4IDUgYmFyaXMga2UgYmF3YWgpCiAgICAgICAgICAgIFRPVEFMX0xJTkVTPSQod2MgLWwgPCAiJFNJREVCQVJfRklMRSIpCiAgICAgICAgICAgIEVORF9MSU5FPSRMSU5FX05VTQogICAgICAgICAgICBmb3IgaSBpbiAkKHNlcSAkKChMSU5FX05VTSArIDEpKSAkKChMSU5FX05VTSArIDEwKSkpOyBkbwogICAgICAgICAgICAgICAgaWYgWyAkaSAtZ3QgIiRUT1RBTF9MSU5FUyIgXTsgdGhlbiBicmVhazsgZmkKICAgICAgICAgICAgICAgIGlmIHNlZCAtbiAiJHtpfXAiICIkU0lERUJBUl9GSUxFIiB8IGdyZXAgLXEgIjwvbGk+IjsgdGhlbgogICAgICAgICAgICAgICAgICAgIEVORF9MSU5FPSRpCiAgICAgICAgICAgICAgICAgICAgYnJlYWsKICAgICAgICAgICAgICAgIGZpCiAgICAgICAgICAgICAgICBpZiBzZWQgLW4gIiR7aX1wIiAiJFNJREVCQVJfRklMRSIgfCBncmVwIC1xICI8L2E+IjsgdGhlbgogICAgICAgICAgICAgICAgICAgIEVORF9MSU5FPSRpCiAgICAgICAgICAgICAgICAgICAgYnJlYWsKICAgICAgICAgICAgICAgIGZpCiAgICAgICAgICAgIGRvbmUKCiAgICAgICAgICAgIGVjaG8gIvCfk40gV3JhcHBpbmcgYmFyaXMgJFNUQVJUX0xJTkUgc2FtcGFpICRFTkRfTElORSIKCiAgICAgICAgICAgICMgSW5zZXJ0IEBlbmRpZiBzZXRlbGFoIEVORF9MSU5FCiAgICAgICAgICAgIHNlZCAtaSAiJHtFTkRfTElORX1hXFx7ey0tIEVORCBQUk9URUtTSV9KSE9OQUxFWV9BUFBBUElfTUVOVSAtLX19IiAiJFNJREVCQVJfRklMRSIKICAgICAgICAgICAgc2VkIC1pICIke0VORF9MSU5FfWFcXEBlbmRpZiIgIiRTSURFQkFSX0ZJTEUiCgogICAgICAgICAgICAjIEluc2VydCBAaWYgc2ViZWx1bSBTVEFSVF9MSU5FCiAgICAgICAgICAgIHNlZCAtaSAiJCgoU1RBUlRfTElORSkpaVxcQGlmKEF1dGg6OnVzZXIoKS0+aWQgPT09IDEpIiAiJFNJREVCQVJfRklMRSIKICAgICAgICAgICAgc2VkIC1pICIkKChTVEFSVF9MSU5FKSlpXFx7ey0tIFBST1RFS1NJX0pIT05BTEVZX0FQUEFQSV9NRU5VOiBTZW1idW55aWthbiB1bnR1ayBub24tSUQgMSAtLX19IiAiJFNJREVCQVJfRklMRSIKCiAgICAgICAgICAgIGVjaG8gIuKchSBNZW51IEFwcGxpY2F0aW9uIEFQSSBkaXNlbWJ1bnlpa2FuIHVudHVrIG5vbi1JRCAxIgogICAgICAgIGVsc2UKICAgICAgICAgICAgZWNobyAi4pqg77iPIFRla3MgJ0FwcGxpY2F0aW9uIEFQSScgdGlkYWsgZGl0ZW11a2FuIGRpIGZpbGUiCiAgICAgICAgZmkKICAgIGZpCmZpCgplY2hvICLinIUgQkFHSUFOIDEgU0VMRVNBSSIKCiMg4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSBCiMgQkFHSUFOIDI6IEJsb2NrIGFrc2VzIGtlIEFwcGxpY2F0aW9uIEFQSSBDb250cm9sbGVyCiMg4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSBCmVjaG8gIiIKZWNobyAi4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSBIgplY2hvICLwn5OmIEJBR0lBTiAyOiBCbG9jayBha3NlcyBBcHBsaWNhdGlvbiBBUEkgQ29udHJvbGxlciIKZWNobyAi4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSBIgoKQVBJX0NPTlRST0xMRVI9IiRQQU5FTF9ESVIvYXBwL0h0dHAvQ29udHJvbGxlcnMvQWRtaW4vQXBpQ29udHJvbGxlci5waHAiCgppZiBbICEgLWYgIiRBUElfQ09OVFJPTExFUiIgXTsgdGhlbgogICAgZWNobyAi4p2MIEFwaUNvbnRyb2xsZXIgdGlkYWsgZGl0ZW11a2FuOiAkQVBJX0NPTlRST0xMRVIiCmVsc2UKICAgIGNwICIkQVBJX0NPTlRST0xMRVIiICIke0FQSV9DT05UUk9MTEVSfS5iYWtfJHtUSU1FU1RBTVB9IgogICAgZWNobyAi8J+SviBCYWNrdXA6ICR7QVBJX0NPTlRST0xMRVJ9LmJha18ke1RJTUVTVEFNUH0iCgogICAgaWYgZ3JlcCAtcSAiUFJPVEVLU0lfSkhPTkFMRVlfQVBQQVBJX0JMT0NLIiAiJEFQSV9DT05UUk9MTEVSIjsgdGhlbgogICAgICAgIGVjaG8gIuKaoO+4jyBQcm90ZWtzaSBzdWRhaCBhZGEsIHNraXAuLi4iCiAgICBlbHNlCiAgICAgICAgIyBDYXJpIGJhcmlzICJwdWJsaWMgZnVuY3Rpb24gaW5kZXgiIGRhbiBpbmplY3QgcHJvdGVrc2kgc2V0ZWxhaG55YQogICAgICAgIElOREVYX0xJTkU9JChncmVwIC1uICJwdWJsaWMgZnVuY3Rpb24gaW5kZXgiICIkQVBJX0NPTlRST0xMRVIiIHwgaGVhZCAtMSB8IGN1dCAtZDogLWYxKQogICAgICAgIAogICAgICAgIGlmIFsgLW4gIiRJTkRFWF9MSU5FIiBdOyB0aGVuCiAgICAgICAgICAgICMgQ2FyaSBiYXJpcyB7IHNldGVsYWggZnVuY3Rpb24gZGVjbGFyYXRpb24KICAgICAgICAgICAgQlJBQ0VfTElORT0kSU5ERVhfTElORQogICAgICAgICAgICBmb3IgaSBpbiAkKHNlcSAiJElOREVYX0xJTkUiICQoKElOREVYX0xJTkUgKyAzKSkpOyBkbwogICAgICAgICAgICAgICAgaWYgc2VkIC1uICIke2l9cCIgIiRBUElfQ09OVFJPTExFUiIgfCBncmVwIC1xICJ7IjsgdGhlbgogICAgICAgICAgICAgICAgICAgIEJSQUNFX0xJTkU9JGkKICAgICAgICAgICAgICAgICAgICBicmVhawogICAgICAgICAgICAgICAgZmkKICAgICAgICAgICAgZG9uZQoKICAgICAgICAgICAgIyBJbmplY3Qgc2V0ZWxhaCBvcGVuaW5nIGJyYWNlCiAgICAgICAgICAgIHNlZCAtaSAiJHtCUkFDRV9MSU5FfWFcXCAgICAgICAgLy8gUFJPVEVLU0lfSkhPTkFMRVlfQVBQQVBJX0JMT0NLOiBCbG9jayBha3NlcyB1bnR1ayBub24tSUQgMSIgIiRBUElfQ09OVFJPTExFUiIKICAgICAgICAgICAgc2VkIC1pICIkKChCUkFDRV9MSU5FICsgMSkpYVxcICAgICAgICBpZiAoXFxcXEF1dGg6OnVzZXIoKS0+aWQgIT09IDEpIHsgYWJvcnQoNDAzLCAnQWtzZXMgQXBwbGljYXRpb24gQVBJIHRpZGFrIGRpaXppbmthbi4nKTsgfSIgIiRBUElfQ09OVFJPTExFUiIKCiAgICAgICAgICAgIGVjaG8gIuKchSBQcm90ZWtzaSBpbmRleCgpIGRpaW5qZWtzaSIKICAgICAgICBmaQoKICAgICAgICAjIEp1Z2EgcHJvdGVrc2kgbWV0aG9kIHN0b3JlIChidWF0IGtleSkKICAgICAgICBTVE9SRV9MSU5FPSQoZ3JlcCAtbiAicHVibGljIGZ1bmN0aW9uIHN0b3JlIiAiJEFQSV9DT05UUk9MTEVSIiB8IGhlYWQgLTEgfCBjdXQgLWQ6IC1mMSkKICAgICAgICBpZiBbIC1uICIkU1RPUkVfTElORSIgXTsgdGhlbgogICAgICAgICAgICBCUkFDRV9MSU5FPSRTVE9SRV9MSU5FCiAgICAgICAgICAgIGZvciBpIGluICQoc2VxICIkU1RPUkVfTElORSIgJCgoU1RPUkVfTElORSArIDMpKSk7IGRvCiAgICAgICAgICAgICAgICBpZiBzZWQgLW4gIiR7aX1wIiAiJEFQSV9DT05UUk9MTEVSIiB8IGdyZXAgLXEgInsiOyB0aGVuCiAgICAgICAgICAgICAgICAgICAgQlJBQ0VfTElORT0kaQogICAgICAgICAgICAgICAgICAgIGJyZWFrCiAgICAgICAgICAgICAgICBmaQogICAgICAgICAgICBkb25lCiAgICAgICAgICAgIHNlZCAtaSAiJHtCUkFDRV9MSU5FfWFcXCAgICAgICAgLy8gUFJPVEVLU0lfSkhPTkFMRVlfQVBQQVBJX0JMT0NLIiAiJEFQSV9DT05UUk9MTEVSIgogICAgICAgICAgICBzZWQgLWkgIiQoKEJSQUNFX0xJTkUgKyAxKSlhXFwgICAgICAgIGlmIChcXFxcQXV0aDo6dXNlcigpLT5pZCAhPT0gMSkgeyBhYm9ydCg0MDMsICdBa3NlcyBBcHBsaWNhdGlvbiBBUEkgdGlkYWsgZGlpemlua2FuLicpOyB9IiAiJEFQSV9DT05UUk9MTEVSIgogICAgICAgICAgICBlY2hvICLinIUgUHJvdGVrc2kgc3RvcmUoKSBkaWluamVrc2kiCiAgICAgICAgZmkKCiAgICAgICAgIyBQcm90ZWtzaSBtZXRob2QgZGVsZXRlCiAgICAgICAgREVMRVRFX0xJTkU9JChncmVwIC1uICJwdWJsaWMgZnVuY3Rpb24gZGVsZXRlXHxwdWJsaWMgZnVuY3Rpb24gZGVzdHJveSIgIiRBUElfQ09OVFJPTExFUiIgfCBoZWFkIC0xIHwgY3V0IC1kOiAtZjEpCiAgICAgICAgaWYgWyAtbiAiJERFTEVURV9MSU5FIiBdOyB0aGVuCiAgICAgICAgICAgIEJSQUNFX0xJTkU9JERFTEVURV9MSU5FCiAgICAgICAgICAgIGZvciBpIGluICQoc2VxICIkREVMRVRFX0xJTkUiICQoKERFTEVURV9MSU5FICsgMykpKTsgZG8KICAgICAgICAgICAgICAgIGlmIHNlZCAtbiAiJHtpfXAiICIkQVBJX0NPTlRST0xMRVIiIHwgZ3JlcCAtcSAieyI7IHRoZW4KICAgICAgICAgICAgICAgICAgICBCUkFDRV9MSU5FPSRpCiAgICAgICAgICAgICAgICAgICAgYnJlYWsKICAgICAgICAgICAgICAgIGZpCiAgICAgICAgICAgIGRvbmUKICAgICAgICAgICAgc2VkIC1pICIke0JSQUNFX0xJTkV9YVxcICAgICAgICAvLyBQUk9URUtTSV9KSE9OQUxFWV9BUFBBUElfQkxPQ0siICIkQVBJX0NPTlRST0xMRVIiCiAgICAgICAgICAgIHNlZCAtaSAiJCgoQlJBQ0VfTElORSArIDEpKWFcXCAgICAgICAgaWYgKFxcXFxBdXRoOjp1c2VyKCktPmlkICE9PSAxKSB7IGFib3J0KDQwMywgJ0Frc2VzIEFwcGxpY2F0aW9uIEFQSSB0aWRhayBkaWl6aW5rYW4uJyk7IH0iICIkQVBJX0NPTlRST0xMRVIiCiAgICAgICAgICAgIGVjaG8gIuKchSBQcm90ZWtzaSBkZWxldGUoKSBkaWluamVrc2kiCiAgICAgICAgZmkKICAgIGZpCmZpCgplY2hvICLinIUgQkFHSUFOIDIgU0VMRVNBSSIKCiMg4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSBCiMgQkFHSUFOIDM6IFByb3Rla3NpIEFwcGxpY2F0aW9uIEFQSSBlbmRwb2ludCAvYXBpL2FwcGxpY2F0aW9uL3VzZXJzCiMgTWVuY2VnYWggbm9uLUlEIDEgbWVuZ3ViYWggcm9vdF9hZG1pbiB2aWEgUkVTVCBBUEkKIyDilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIEKZWNobyAiIgplY2hvICLilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIEiCmVjaG8gIvCfk6YgQkFHSUFOIDM6IFByb3Rla3NpIEFQSSAvYXBpL2FwcGxpY2F0aW9uL3VzZXJzIChyb290X2FkbWluKSIKZWNobyAi4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSB4pSBIgoKIyBDYXJpIEFwcGxpY2F0aW9uIEFQSSBVc2VyQ29udHJvbGxlcgpBUElfVVNFUl9DT05UUk9MTEVSPSIkUEFORUxfRElSL2FwcC9IdHRwL0NvbnRyb2xsZXJzL0FwaS9BcHBsaWNhdGlvbi9Vc2Vycy9Vc2VyQ29udHJvbGxlci5waHAiCgppZiBbICEgLWYgIiRBUElfVVNFUl9DT05UUk9MTEVSIiBdOyB0aGVuCiAgICBlY2hvICLimqDvuI8gQVBJIFVzZXJDb250cm9sbGVyIHRpZGFrIGRpdGVtdWthbjogJEFQSV9VU0VSX0NPTlRST0xMRVIiCiAgICBlY2hvICIgICBNZW5jb2JhIHBhdGggYWx0ZXJuYXRpZi4uLiIKICAgIEFQSV9VU0VSX0NPTlRST0xMRVI9JChmaW5kICIkUEFORUxfRElSL2FwcC9IdHRwL0NvbnRyb2xsZXJzL0FwaSIgLW5hbWUgIlVzZXJDb250cm9sbGVyLnBocCIgLXBhdGggIiovQXBwbGljYXRpb24vKiIgMj4vZGV2L251bGwgfCBoZWFkIC0xKQpmaQoKaWYgWyAteiAiJEFQSV9VU0VSX0NPTlRST0xMRVIiIF0gfHwgWyAhIC1mICIkQVBJX1VTRVJfQ09OVFJPTExFUiIgXTsgdGhlbgogICAgZWNobyAi4p2MIEFQSSBVc2VyQ29udHJvbGxlciB0aWRhayBkaXRlbXVrYW4sIHNraXAgYmFnaWFuIDMiCmVsc2UKICAgIGVjaG8gIvCfk4IgRmlsZSBkaXRlbXVrYW46ICRBUElfVVNFUl9DT05UUk9MTEVSIgogICAgY3AgIiRBUElfVVNFUl9DT05UUk9MTEVSIiAiJHtBUElfVVNFUl9DT05UUk9MTEVSfS5iYWtfJHtUSU1FU1RBTVB9IgogICAgZWNobyAi8J+SviBCYWNrdXA6ICR7QVBJX1VTRVJfQ09OVFJPTExFUn0uYmFrXyR7VElNRVNUQU1QfSIKCiAgICBpZiBncmVwIC1xICJQUk9URUtTSV9KSE9OQUxFWV9BUElfUk9PVEFETUlOIiAiJEFQSV9VU0VSX0NPTlRST0xMRVIiOyB0aGVuCiAgICAgICAgZWNobyAi4pqg77iPIFByb3Rla3NpIHN1ZGFoIGFkYSwgc2tpcC4uLiIKICAgIGVsc2UKICAgICAgICAjIFByb3Rla3NpIG1ldGhvZCBzdG9yZSAoY3JlYXRlIHVzZXIgdmlhIEFQSSkKICAgICAgICBTVE9SRV9MSU5FPSQoZ3JlcCAtbiAicHVibGljIGZ1bmN0aW9uIHN0b3JlIiAiJEFQSV9VU0VSX0NPTlRST0xMRVIiIHwgaGVhZCAtMSB8IGN1dCAtZDogLWYxKQogICAgICAgIGlmIFsgLW4gIiRTVE9SRV9MSU5FIiBdOyB0aGVuCiAgICAgICAgICAgIEJSQUNFX0xJTkU9JFNUT1JFX0xJTkUKICAgICAgICAgICAgZm9yIGkgaW4gJChzZXEgIiRTVE9SRV9MSU5FIiAkKChTVE9SRV9MSU5FICsgNSkpKTsgZG8KICAgICAgICAgICAgICAgIGlmIHNlZCAtbiAiJHtpfXAiICIkQVBJX1VTRVJfQ09OVFJPTExFUiIgfCBncmVwIC1xICJ7IjsgdGhlbgogICAgICAgICAgICAgICAgICAgIEJSQUNFX0xJTkU9JGkKICAgICAgICAgICAgICAgICAgICBicmVhawogICAgICAgICAgICAgICAgZmkKICAgICAgICAgICAgZG9uZQogICAgICAgICAgICBzZWQgLWkgIiR7QlJBQ0VfTElORX1hXFwgICAgICAgIC8vIFBST1RFS1NJX0pIT05BTEVZX0FQSV9ST09UQURNSU46IEJsb2NrIG5vbi1JRCAxIGRhcmkgc2V0IHJvb3RfYWRtaW4gdmlhIEFQSSIgIiRBUElfVVNFUl9DT05UUk9MTEVSIgogICAgICAgICAgICBzZWQgLWkgIiQoKEJSQUNFX0xJTkUgKyAxKSlhXFwgICAgICAgIGlmICgoaW50KSBcXFwkcmVxdWVzdC0+dXNlcigpLT5pZCAhPT0gMSAmJiBcXFwkcmVxdWVzdC0+aGFzKCdyb290X2FkbWluJykgJiYgXFxcJHJlcXVlc3QtPmlucHV0KCdyb290X2FkbWluJykpIHsgcmV0dXJuIHJlc3BvbnNlKCktPmpzb24oWydlcnJvcicgPT4gJyR7QlJBTkRfVEVYVH0gLSBUaWRhayBkaWl6aW5rYW4gbWVuZ3ViYWggc3RhdHVzIGFkbWluIHZpYSBBUEknXSwgNDAzKTsgfSIgIiRBUElfVVNFUl9DT05UUk9MTEVSIgogICAgICAgICAgICBlY2hvICLinIUgUHJvdGVrc2kgc3RvcmUoKSBBUEkgZGlpbmpla3NpIgogICAgICAgIGZpCgogICAgICAgICMgUHJvdGVrc2kgbWV0aG9kIHVwZGF0ZSAodXBkYXRlIHVzZXIgdmlhIEFQSSkKICAgICAgICBVUERBVEVfTElORT0kKGdyZXAgLW4gInB1YmxpYyBmdW5jdGlvbiB1cGRhdGUiICIkQVBJX1VTRVJfQ09OVFJPTExFUiIgfCBoZWFkIC0xIHwgY3V0IC1kOiAtZjEpCiAgICAgICAgaWYgWyAtbiAiJFVQREFURV9MSU5FIiBdOyB0aGVuCiAgICAgICAgICAgIEJSQUNFX0xJTkU9JFVQREFURV9MSU5FCiAgICAgICAgICAgIGZvciBpIGluICQoc2VxICIkVVBEQVRFX0xJTkUiICQoKFVQREFURV9MSU5FICsgNSkpKTsgZG8KICAgICAgICAgICAgICAgIGlmIHNlZCAtbiAiJHtpfXAiICIkQVBJX1VTRVJfQ09OVFJPTExFUiIgfCBncmVwIC1xICJ7IjsgdGhlbgogICAgICAgICAgICAgICAgICAgIEJSQUNFX0xJTkU9JGkKICAgICAgICAgICAgICAgICAgICBicmVhawogICAgICAgICAgICAgICAgZmkKICAgICAgICAgICAgZG9uZQogICAgICAgICAgICBzZWQgLWkgIiR7QlJBQ0VfTElORX1hXFwgICAgICAgIC8vIFBST1RFS1NJX0pIT05BTEVZX0FQSV9ST09UQURNSU46IEJsb2NrIG5vbi1JRCAxIGRhcmkgdWJhaCByb290X2FkbWluIHZpYSBBUEkiICIkQVBJX1VTRVJfQ09OVFJPTExFUiIKICAgICAgICAgICAgc2VkIC1pICIkKChCUkFDRV9MSU5FICsgMSkpYVxcICAgICAgICBpZiAoKGludCkgXFxcJHJlcXVlc3QtPnVzZXIoKS0+aWQgIT09IDEgJiYgXFxcJHJlcXVlc3QtPmhhcygncm9vdF9hZG1pbicpKSB7IFxcXCR1c2VyID0gXFxcJHRoaXMtPnJlcG9zaXRvcnktPmZpbmQoXFxcJHJlcXVlc3QtPnJvdXRlKCd1c2VyJykpOyBpZiAoKGJvb2wpIFxcXCRyZXF1ZXN0LT5pbnB1dCgncm9vdF9hZG1pbicpICE9PSAoYm9vbCkgXFxcJHVzZXItPnJvb3RfYWRtaW4pIHsgcmV0dXJuIHJlc3BvbnNlKCktPmpzb24oWydlcnJvcicgPT4gJyR7QlJBTkRfVEVYVH0gLSBUaWRhayBkaWl6aW5rYW4gbWVuZ3ViYWggc3RhdHVzIGFkbWluIHZpYSBBUEknXSwgNDAzKTsgfSB9IiAiJEFQSV9VU0VSX0NPTlRST0xMRVIiCiAgICAgICAgICAgIGVjaG8gIuKchSBQcm90ZWtzaSB1cGRhdGUoKSBBUEkgZGlpbmpla3NpIgogICAgICAgIGZpCgogICAgICAgICMgUHJvdGVrc2kgbWV0aG9kIGRlbGV0ZSAoaGFwdXMgdXNlciB2aWEgQVBJKQogICAgICAgIERFTEVURV9MSU5FPSQoZ3JlcCAtbiAicHVibGljIGZ1bmN0aW9uIGRlbGV0ZVx8cHVibGljIGZ1bmN0aW9uIGRlc3Ryb3kiICIkQVBJX1VTRVJfQ09OVFJPTExFUiIgfCBoZWFkIC0xIHwgY3V0IC1kOiAtZjEpCiAgICAgICAgaWYgWyAtbiAiJERFTEVURV9MSU5FIiBdOyB0aGVuCiAgICAgICAgICAgIEJSQUNFX0xJTkU9JERFTEVURV9MSU5FCiAgICAgICAgICAgIGZvciBpIGluICQoc2VxICIkREVMRVRFX0xJTkUiICQoKERFTEVURV9MSU5FICsgNSkpKTsgZG8KICAgICAgICAgICAgICAgIGlmIHNlZCAtbiAiJHtpfXAiICIkQVBJX1VTRVJfQ09OVFJPTExFUiIgfCBncmVwIC1xICJ7IjsgdGhlbgogICAgICAgICAgICAgICAgICAgIEJSQUNFX0xJTkU9JGkKICAgICAgICAgICAgICAgICAgICBicmVhawogICAgICAgICAgICAgICAgZmkKICAgICAgICAgICAgZG9uZQogICAgICAgICAgICBzZWQgLWkgIiR7QlJBQ0VfTElORX1hXFwgICAgICAgIC8vIFBST1RFS1NJX0pIT05BTEVZX0FQSV9ST09UQURNSU46IEJsb2NrIG5vbi1JRCAxIGRhcmkgaGFwdXMgdXNlciB2aWEgQVBJIiAiJEFQSV9VU0VSX0NPTlRST0xMRVIiCiAgICAgICAgICAgIHNlZCAtaSAiJCgoQlJBQ0VfTElORSArIDEpKWFcXCAgICAgICAgaWYgKChpbnQpIFxcXCRyZXF1ZXN0LT51c2VyKCktPmlkICE9PSAxKSB7IHJldHVybiByZXNwb25zZSgpLT5qc29uKFsnZXJyb3InID0+ICcke0JSQU5EX1RFWFR9IC0gVGlkYWsgZGlpemlua2FuIG1lbmdoYXB1cyB1c2VyIHZpYSBBUEknXSwgNDAzKTsgfSIgIiRBUElfVVNFUl9DT05UUk9MTEVSIgogICAgICAgICAgICBlY2hvICLinIUgUHJvdGVrc2kgZGVsZXRlKCkgQVBJIGRpaW5qZWtzaSIKICAgICAgICBmaQogICAgZmkKZmkKCmVjaG8gIuKchSBCQUdJQU4gMyBTRUxFU0FJIgoKIyDilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIEKIyBCRVJTSUhLQU4gQ0FDSEUKIyDilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIHilIEKZWNobyAiIgplY2hvICLwn6e5IE1lbWJlcnNpaGthbiBjYWNoZS4uLiIKCiMgQXBwbHkgYnJhbmQgY3VzdG9taXphdGlvbgppZiBbIC1mICIkQVBJX0NPTlRST0xMRVIiIF07IHRoZW4KICBzZWQgLWkgInN8QWtzZXMgQXBwbGljYXRpb24gQVBJIHRpZGFrIGRpaXppbmthbnwke0JSQU5EX1RFWFR9IC0gQWtzZXMgZGl0b2xha3xnIiAiJEFQSV9DT05UUk9MTEVSIiAyPi9kZXYvbnVsbCB8fCB0cnVlCmZpCgplY2hvICLihLnvuI8gQ2FjaGUgY2xlYXIgYWthbiBkaWxha3VrYW4gb2xlaCBQcm90ZWN0IE1hbmFnZXIgY29udHJvbGxlciIKCmVjaG8gIiIKZWNobyAiPT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PSIKZWNobyAi4pyFIElOU1RBTExQUk9URUNUMTMgU0VMRVNBSSEiCmVjaG8gIj09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT0iCmVjaG8gIvCflJIgTWVudSBBcHBsaWNhdGlvbiBBUEkgZGlzZW1idW55aWthbiAoc2VsYWluIElEIDEpIgplY2hvICLwn5SSIEFrc2VzIGNvbnRyb2xsZXIgQXBwbGljYXRpb24gQVBJIGRpYmxvY2sgKHNlbGFpbiBJRCAxKSIKZWNobyAiPT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PSIKZWNobyAiIgplY2hvICLimqDvuI8gSmlrYSBhZGEgbWFzYWxhaCwgcmVzdG9yZToiClsgLWYgIiR7U0lERUJBUl9GSUxFfS5iYWtfJHtUSU1FU1RBTVB9IiBdICYmIGVjaG8gIiAgIGNwICR7U0lERUJBUl9GSUxFfS5iYWtfJHtUSU1FU1RBTVB9ICR7U0lERUJBUl9GSUxFfSIKWyAtZiAiJHtBUElfQ09OVFJPTExFUn0uYmFrXyR7VElNRVNUQU1QfSIgXSAmJiBlY2hvICIgICBjcCAke0FQSV9DT05UUk9MTEVSfS5iYWtfJHtUSU1FU1RBTVB9ICR7QVBJX0NPTlRST0xMRVJ9IgplY2hvICIgICBjZCAkUEFORUxfRElSICYmIHBocCBhcnRpc2FuIHZpZXc6Y2xlYXIgJiYgcGhwIGFydGlzYW4gcm91dGU6Y2xlYXIiCg==
SCRIPT_INSTALLPROTECT13_SH,
        ];

        if (!isset($bundled[$filename])) {
            return null;
        }

        $decoded = base64_decode(trim($bundled[$filename]), true);

        return $decoded === false ? null : $decoded;
    }

    /**
     * Ambil URL raw script. Prioritas: API key (Lovable), lalu GitHub.
     */
    private function getScriptUrls(string $filename): array
    {
        $urls = [];

        $keyFile = rtrim($this->scriptsDir, '/') . '/.protect_api_key';
        if (is_file($keyFile)) {
            $apiKey = trim((string) @file_get_contents($keyFile));
            if ($apiKey !== '') {
                $urls[] = 'https://hzgavthvdnlrihdrigyt.supabase.co/functions/v1/download?file='
                    . rawurlencode($filename) . '&key=' . rawurlencode($apiKey);
            }
        }

        $urls[] = 'https://raw.githubusercontent.com/danangvalentp/protect-panel/refs/heads/main/' . $filename;

        return $urls;
    }

    private function getScriptUrl(string $filename): string
    {
        return $this->getScriptUrls($filename)[0];
    }

    /**
     * Validasi konten: harus diawali shebang & tidak boleh HTML.
     */
    private function isValidScriptContent(?string $content): bool
    {
        if ($content === null) return false;
        $trim = ltrim($content);
        if ($trim === '') return false;
        if (strncmp($trim, '#!', 2) !== 0) return false;
        $head = strtolower(substr($trim, 0, 4096));
        if (preg_match('/<(html|head|body|!doctype)/i', $head)) return false;
        if (strpos($content, '404: Not Found') !== false) return false;
        return true;
    }

    /**
     * Pastikan script tersedia. Coba semua sumber remote, validasi, lalu fallback ke bundle.
     */
    private function ensureScriptExists(string $filename): bool
    {
        $scriptPath = $this->scriptsDir . '/' . $filename;
        $this->ensureDirectory($this->scriptsDir);

        $needsDispatcher = ($filename === 'installprotect.sh');

        foreach ($this->getScriptUrls($filename) as $url) {
            $content = @file_get_contents($url . '?v=' . time());
            if ($needsDispatcher && is_string($content) && strpos($content, 'protect5c)') === false) {
                continue;
            }
            if ($this->isValidScriptContent($content)) {
                if (!File::exists($scriptPath) || File::get($scriptPath) !== $content) {
                    File::put($scriptPath, $content);
                }
                @chmod($scriptPath, 0755);
                return true;
            }
        }

        if (File::exists($scriptPath) && $this->isValidScriptContent(File::get($scriptPath))) {
            @chmod($scriptPath, 0755);
            return true;
        }

        $bundledContent = $this->getBundledScriptContent($filename);
        if ($this->isValidScriptContent($bundledContent)) {
            File::put($scriptPath, $bundledContent);
            @chmod($scriptPath, 0755);
            return true;
        }

        return false;
    }

    /**
     * Jalankan script proteksi via wrapper sudo tanpa preserve env
     */
    private function runProtectedScript(string $scriptFile, array $config, string $protectKey = ''): array
    {
        $this->ensureDirectory($this->scriptsDir);
        @chmod($this->scriptsDir, 0775);
        $wrapperFile = $this->scriptsDir . '/run-' . basename($scriptFile, '.sh') . '-' . uniqid() . '.sh';
        $scriptArgs = $protectKey === '' ? '' : ' ' . escapeshellarg($protectKey);
        $wrapperContent = "#!/bin/bash\n"
            . "set -e\n"
            . 'export BRAND_NAME=' . escapeshellarg($config['brand_name'] ?? 'FyzzModss') . "\n"
            . 'export BRAND_TEXT=' . escapeshellarg($config['brand_text'] ?? 'Protect By FyzzModss') . "\n"
            . 'export CONTACT_TELEGRAM=' . escapeshellarg($config['contact_telegram'] ?? '@FyzzModss') . "\n"
            . 'export CONTACT_TELEGRAM_2=' . escapeshellarg($config['contact_telegram_2'] ?? '@FyzAbout') . "\n"
            . 'export BRAND_LABEL=' . escapeshellarg($config['brand_label'] ?? ($config['brand_name'] ?? 'FyzzModss')) . "\n"
            . 'export BOT_LINK=' . escapeshellarg($config['bot_link'] ?? '@upgradeuser_bot') . "\n"
            . 'export WELCOME_TITLE=' . escapeshellarg($config['welcome_title'] ?? 'Welcome To Server FyzzModss') . "\n"
            . 'export WELCOME_MESSAGE=' . escapeshellarg($config['welcome_message'] ?? '') . "\n"
            . 'export PANEL_TITLE=' . escapeshellarg($config['panel_title'] ?? ($config['brand_name'] ?? 'FyzzModss')) . "\n"
            . 'export DENY_MSG_ADMIN=' . escapeshellarg($config['deny_msg_admin'] ?? '') . "\n"
            . 'export DENY_MSG_SERVER=' . escapeshellarg($config['deny_msg_server'] ?? '') . "\n"
            . 'export DENY_MSG_FILE=' . escapeshellarg($config['deny_msg_file'] ?? '') . "\n"
            . 'export DENY_MSG_MODIFY=' . escapeshellarg($config['deny_msg_modify'] ?? '') . "\n"
            . 'exec /bin/bash ' . escapeshellarg($scriptFile) . $scriptArgs . "\n";

        File::put($wrapperFile, $wrapperContent);
        @chmod($wrapperFile, 0755);
        @chown($wrapperFile, 'www-data');
        @chgrp($wrapperFile, 'www-data');

        $output = [];
        $returnVar = 0;
        $command = sprintf(
            'cd %s && sudo /bin/bash %s 2>&1',
            escapeshellarg($this->panelDir),
            escapeshellarg($wrapperFile)
        );
        exec($command, $output, $returnVar);
        @unlink($wrapperFile);

        return [$output, $returnVar];
    }

    /**
     * Jalankan bulk install di background agar request web tidak timeout/500.
     */
    private function dispatchBulkInstallJob(array $selected, array $config): void
    {
        $jobFile = $this->scriptsDir . '/bulk-install-job-' . uniqid() . '.php';
        $payload = [
            'selected' => array_values($selected),
            'config' => $config,
            'scripts_dir' => $this->scriptsDir,
            'panel_dir' => $this->panelDir,
            'config_path' => $this->configPath,
            'status_path' => $this->getBulkStatusPath(),
            'php_binary' => $this->phpBinary,
        ];

        $jobScript = <<<'PHPJOB'
<?php
$payload = json_decode(base64_decode('__PAYLOAD__'), true);
if (!is_array($payload)) {
    exit(1);
}

$selected = $payload['selected'] ?? [];
$config = $payload['config'] ?? ['protections' => []];
$scriptsDir = $payload['scripts_dir'] ?? '';
$panelDir = $payload['panel_dir'] ?? '';
$configPath = $payload['config_path'] ?? '';
$statusPath = $payload['status_path'] ?? '';
$phpBinary = $payload['php_binary'] ?? 'php';

$writeStatus = function (array $status) use ($scriptsDir, $statusPath): void {
    if (!is_dir($scriptsDir)) {
        @mkdir($scriptsDir, 0755, true);
    }

    file_put_contents($statusPath, json_encode($status, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE));
};

$normalizeOutput = function (array $output, int $maxLines = 80, int $maxChars = 6000): string {
    $text = trim(implode("\n", array_slice($output, -$maxLines)));
    if ($text === '') {
        return '';
    }

    if (strlen($text) > $maxChars) {
        $text = substr($text, -$maxChars);
        $newlinePos = strpos($text, "\n");
        if ($newlinePos !== false) {
            $text = substr($text, $newlinePos + 1);
        }
        $text = "...[output dipotong agar panel stabil]...\n" . $text;
    }

    return $text;
};

$runProtectedScript = function (string $scriptFile, array $config, string $protectKey = '') use ($scriptsDir, $panelDir): array {
    $wrapperFile = $scriptsDir . '/run-' . basename($scriptFile, '.sh') . '-' . uniqid() . '.sh';
    $scriptArgs = $protectKey === '' ? '' : ' ' . escapeshellarg($protectKey);
    $wrapperContent = "#!/bin/bash\n"
        . "set -e\n"
        . 'export BRAND_NAME=' . escapeshellarg($config['brand_name'] ?? 'FyzzModss') . "\n"
        . 'export BRAND_TEXT=' . escapeshellarg($config['brand_text'] ?? 'Protect By FyzzModss') . "\n"
        . 'export CONTACT_TELEGRAM=' . escapeshellarg($config['contact_telegram'] ?? '@FyzzModss') . "\n"
        . 'export CONTACT_TELEGRAM_2=' . escapeshellarg($config['contact_telegram_2'] ?? '@FyzAbout') . "\n"
        . 'export BRAND_LABEL=' . escapeshellarg($config['brand_label'] ?? ($config['brand_name'] ?? 'FyzzModss')) . "\n"
        . 'export BOT_LINK=' . escapeshellarg($config['bot_link'] ?? '@upgradeuser_bot') . "\n"
        . 'export WELCOME_TITLE=' . escapeshellarg($config['welcome_title'] ?? 'Welcome To Server FyzzModss') . "\n"
        . 'export WELCOME_MESSAGE=' . escapeshellarg($config['welcome_message'] ?? '') . "\n"
        . 'export PANEL_TITLE=' . escapeshellarg($config['panel_title'] ?? ($config['brand_name'] ?? 'FyzzModss')) . "\n"
        . 'export DENY_MSG_ADMIN=' . escapeshellarg($config['deny_msg_admin'] ?? '') . "\n"
        . 'export DENY_MSG_SERVER=' . escapeshellarg($config['deny_msg_server'] ?? '') . "\n"
        . 'export DENY_MSG_FILE=' . escapeshellarg($config['deny_msg_file'] ?? '') . "\n"
        . 'export DENY_MSG_MODIFY=' . escapeshellarg($config['deny_msg_modify'] ?? '') . "\n"
        . 'exec /bin/bash ' . escapeshellarg($scriptFile) . $scriptArgs . "\n";

    file_put_contents($wrapperFile, $wrapperContent);
    @chmod($wrapperFile, 0755);

    $output = [];
    $returnVar = 0;
    exec('cd ' . escapeshellarg($panelDir) . ' && sudo /bin/bash ' . escapeshellarg($wrapperFile) . ' 2>&1', $output, $returnVar);
    @unlink($wrapperFile);

    return [$output, $returnVar];
};

$results = [];
$allOutput = [];

$writeStatus([
    'status' => 'running',
    'started_at' => date('c'),
    'results' => [],
    'output' => '',
]);

foreach ($selected as $key) {
    if (!isset($config['protections'][$key])) {
        continue;
    }

    $scriptFile = rtrim($scriptsDir, '/') . '/installprotect.sh';
    if (!is_file($scriptFile)) {
        $results[] = '⚠️ ' . ($config['protections'][$key]['name'] ?? $key) . ': Script tidak ditemukan di server';
        continue;
    }

    [$output, $returnVar] = $runProtectedScript($scriptFile, $config, $key);

    if ($returnVar === 0) {
        $config['protections'][$key]['enabled'] = true;
        $results[] = '✅ ' . ($config['protections'][$key]['name'] ?? $key) . ': Berhasil diinstall';
    } else {
        $config['protections'][$key]['enabled'] = false;
        $results[] = '❌ ' . ($config['protections'][$key]['name'] ?? $key) . ': Gagal install';
    }

    $outputText = $normalizeOutput($output, 80, 6000);
    if ($outputText !== '') {
        $allOutput[] = '[' . $key . ']';
        $allOutput[] = $outputText;
    }

    $writeStatus([
        'status' => 'running',
        'started_at' => date('c'),
        'results' => $results,
        'output' => trim(implode("\n\n", $allOutput)),
    ]);
}

file_put_contents($configPath, json_encode($config, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE));
@exec(
    'cd ' . escapeshellarg($panelDir)
    . ' && ' . escapeshellarg($phpBinary) . ' artisan view:clear'
    . ' && ' . escapeshellarg($phpBinary) . ' artisan route:clear'
    . ' && ' . escapeshellarg($phpBinary) . ' artisan config:clear'
    . ' && ' . escapeshellarg($phpBinary) . ' artisan cache:clear >/dev/null 2>&1'
);

$writeStatus([
    'status' => 'done',
    'finished_at' => date('c'),
    'results' => $results,
    'output' => trim(implode("\n\n", $allOutput)),
]);

@unlink(__FILE__);
PHPJOB;

        $jobScript = str_replace('__PAYLOAD__', base64_encode(json_encode($payload, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE)), $jobScript);

        File::put($jobFile, $jobScript);
        @chmod($jobFile, 0644);

        $this->saveBulkStatus([
            'status' => 'running',
            'started_at' => date('c'),
            'results' => [],
            'output' => '',
        ]);

        $logFile = $this->scriptsDir . '/bulk-install.log';
        $started = $this->launchDetachedPhpJob($jobFile, $logFile);

        if (!$started) {
            $this->saveBulkStatus([
                'status' => 'failed',
                'finished_at' => date('c'),
                'results' => ['❌ Bulk install gagal dijalankan di background.'],
                'output' => 'Background job gagal start. Cek binary PHP/nohup dan permission folder protect-scripts.',
            ]);
        }
    }

    /**
     * Cek apakah proteksi sudah terinstall dengan memeriksa marker di file target
     */
    private function checkInstalled($protectionKey, $protection)
    {
        // Hormati flag enabled di config — jika sudah di-uninstall via panel,
        // anggap tidak terinstall meskipun masih ada sisa marker di file lain.
        if (array_key_exists('enabled', $protection) && $protection['enabled'] === false) {
            return false;
        }

        $containsAny = function (string $relativePath, array $needles): bool {
            $fullPath = $this->panelDir . '/' . ltrim($relativePath, '/');
            if (!File::exists($fullPath)) {
                return false;
            }

            $content = File::get($fullPath);
            foreach ($needles as $needle) {
                if ($needle !== '' && strpos($content, $needle) !== false) {
                    return true;
                }
            }

            return false;
        };

        switch ($protectionKey) {
            case 'protect1':
                return $containsAny('app/Services/Servers/ServerDeletionService.php', [
                    'Akses ditolak: Anda hanya dapat menghapus server milik Anda sendiri',
                    '$user->id !== 1',
                    'PROTEKSI_FIT',
                    'assertDeletionAllowed',
                    'hanya Admin ID 1 yang dapat menghapus server',
                ]);

            case 'protect2':
                return $containsAny('app/Http/Controllers/Admin/UserController.php', [
                    '✖️ Akses ditolak - protect by',
                    'Hanya admin ID 1 yang bisa akses halaman view user',
                ]);

            case 'protect3':
                return $containsAny('app/Http/Controllers/Admin/LocationController.php', [
                    'FyzzModss Protect - Akses ditolak',
                ]);

            case 'protect4':
                return $containsAny('app/Http/Controllers/Admin/Nodes/NodeController.php', [
                    'membuka menu Nodes',
                    '©Protect By FyzzModss V2.3',
                ]);

            case 'protect5a':
                return $containsAny('app/Http/Controllers/Admin/Nests/NestController.php', ['PROTEKSI_FIT'])
                    || $containsAny('app/Http/Controllers/Admin/Nests/EggController.php', ['PROTEKSI_FIT'])
                    || $containsAny('resources/views/partials/admin/sidebar.blade.php', ['PROTEKSI_NESTS_SIDEBAR'])
                    || $containsAny('resources/views/layouts/admin.blade.php', ['PROTEKSI_NESTS_SIDEBAR'])
                    || $containsAny('resources/views/layouts/app.blade.php', ['PROTEKSI_NESTS_SIDEBAR']);

            case 'protect5b':
                return $containsAny('resources/views/layouts/admin.blade.php', ['BRANDING_FIT'])
                    || $containsAny('resources/views/layouts/app.blade.php', ['BRANDING_FIT']);

            case 'protect5c':
                return $containsAny('resources/views/layouts/master.blade.php', ['WELCOME_FIT'])
                    || $containsAny('resources/views/templates/wrapper.blade.php', ['WELCOME_FIT']);

            case 'protect6':
                return $containsAny('app/Http/Controllers/Admin/Settings/IndexController.php', [
                    'FyzzModss Protect - Akses ditolak',
                    'Protect By FyzzModss',
                    'Akses ditolak',
                    '$user->id !== 1',
                ]);

            case 'protect7':
                return $containsAny('app/Http/Controllers/Api/Client/Servers/FileController.php', [
                    'private function checkServerAccess',
                    'Anda tidak memiliki akses ke server ini.',
                ]);

            case 'protect8':
                return $containsAny('app/Http/Controllers/Api/Client/Servers/ServerController.php', [
                    'Hanya Bisa Melihat Server Milik Sendiri.',
                    '𝗛𝗮𝗻𝘆𝗮 𝗕𝗶𝘀𝗮 𝗠𝗲𝗹𝗶𝗵𝗮𝘁 𝗦𝗲𝗿𝘃𝗲𝗿 𝗠𝗶𝗹𝗶𝗸 𝗦𝗲𝗻𝗱𝗶𝗿𝗶.',
                ]);

            case 'protect9':
                return $containsAny('app/Services/Servers/DetailsModificationService.php', [
                    'hanya admin utama yang bisa mengubah detail server',
                    'Protect By FyzzModss',
                    'Akses ditolak',
                    '$user->id !== 1',
                ]);

            case 'protect10':
                return $containsAny('resources/views/admin/servers/index.blade.php', [
                    'Security Protection Active',
                    'Protected by:',
                ]) || $containsAny('resources/views/admin/servers/view/index.blade.php', [
                    'SERVER MANAGEMENT RESTRICTED',
                    'Root Administrator Access Required',
                ]);

            case 'protect11':
                return $containsAny('resources/views/admin/servers/index.blade.php', [
                    'Protected by: ',
                    '@h4mamklul',
                ]) || $containsAny('resources/views/admin/servers/view/index.blade.php', [
                    'BLUR PROTECTION FOR NON-ROOT ADMINS',
                    'backdrop-filter: blur(20px);',
                ]);

            case 'protect12a':
                return $containsAny('resources/views/layouts/admin.blade.php', ['PROTEKSI_NODES_SIDEBAR'])
                    || $containsAny('resources/views/partials/admin/sidebar.blade.php', ['PROTEKSI_NODES_SIDEBAR'])
                    || $containsAny('app/Http/Controllers/Admin/Nodes/NodeViewController.php', ['PROTEKSI_FIT']);

            case 'protect12b':
                return $containsAny('app/Http/Controllers/Api/Client/AccountController.php', ['PROTEKSI_FIT_ACCOUNT']);

            case 'protect12c':
                return $containsAny('app/Http/Middleware/ProtectAdminOneApi.php', ['PROTEKSI_FIT_MIDDLEWARE'])
                    || $containsAny('app/Http/Controllers/Api/Application/Users/UserController.php', ['PROTEKSI_FIT_APPUSER']);

            case 'protect12d':
                return $containsAny('app/Http/Controllers/Admin/ApiController.php', ['PROTEKSI_FIT_APIKEY'])
                    || $containsAny('resources/views/admin/api/index.blade.php', ['PROTEKSI_FIT_APIKEY_BLADE']);

            case 'protect12e':
                return $containsAny('resources/views/layouts/admin.blade.php', ['PROTEKSI_LOCATIONS_SIDEBAR'])
                    || $containsAny('resources/views/partials/admin/sidebar.blade.php', ['PROTEKSI_LOCATIONS_SIDEBAR'])
                    || $containsAny('app/Http/Controllers/Admin/LocationController.php', ['PROTEKSI_FIT']);

            case 'protect13a':
                return $containsAny('resources/views/layouts/admin.blade.php', ['PROTEKSI_FIT_APPAPI_MENU'])
                    || $containsAny('resources/views/partials/admin/sidebar.blade.php', ['PROTEKSI_FIT_APPAPI_MENU']);

            case 'protect13b':
                return $containsAny('app/Http/Controllers/Admin/ApiController.php', ['PROTEKSI_FIT_APPAPI_BLOCK']);

            case 'protect13c':
                return $containsAny('app/Http/Controllers/Api/Application/Users/UserController.php', ['PROTEKSI_FIT_API_ROOTADMIN']);

            case 'protect14':
                return $containsAny('app/Http/Controllers/Admin/UserController.php', ['PROTEKSI_FIT_USER_ADMIN_PANEL_GUARD_V5', 'PROTEKSI_FIT_USER_ADMIN_PANEL_GUARD_V4', 'PROTEKSI_FIT_USER_ADMIN_PANEL_GUARD_V3', 'PROTEKSI_FIT_BLOCK_CREATE_ADMIN_V2_PANELJS_API', 'PROTEKSI_FIT_BLOCK_CREATE_ADMIN'])
                    || $containsAny('app/Http/Controllers/Api/Application/Users/UserController.php', ['PROTEKSI_FIT_USER_ADMIN_PANEL_GUARD_V5', 'PROTEKSI_FIT_USER_ADMIN_PANEL_GUARD_V4', 'PROTEKSI_FIT_USER_ADMIN_PANEL_GUARD_V3', 'PROTEKSI_FIT_BLOCK_CREATE_ADMIN_V2_PANELJS_API', 'PROTEKSI_FIT_BLOCK_CREATE_ADMIN'])
                    || $containsAny('app/Services/Users/UserDeletionService.php', ['PROTEKSI_FIT_USER_ADMIN_PANEL_GUARD_V5', 'PROTEKSI_FIT_USER_ADMIN_PANEL_GUARD_V4', 'PROTEKSI_FIT_USER_ADMIN_PANEL_GUARD_V3'])
                    || $containsAny('app/Models/User.php', ['PROTEKSI_FIT_USER_ADMIN_PANEL_GUARD_V5', 'PROTEKSI_FIT_USER_ADMIN_PANEL_GUARD_V4', 'PROTEKSI_FIT_USER_ADMIN_PANEL_GUARD_V3', 'PROTEKSI_FIT_USER_MODEL_ADMIN_GUARD_V2_PANELJS_API', 'PROTEKSI_FIT_USER_MODEL_ADMIN_GUARD']);
        }

        $targetFile = $this->panelDir . '/' . $protection['target_file'];
        if (!File::exists($targetFile)) {
            return false;
        }

        return strpos(File::get($targetFile), $protection['marker']) !== false;
    }

    /**
     * Halaman utama Protect Manager
     */
    public function index()
    {
        $this->authorizeAccess();
        $config = $this->getConfig();
        $bulkStatus = $this->getBulkStatus();

        // Cek status install setiap proteksi
        foreach ($config['protections'] as $key => &$prot) {
            $prot['installed'] = $this->checkInstalled($key, $prot);
        }

        if ($bulkStatus && ($bulkStatus['status'] ?? null) === 'done') {
            session()->flash('success', implode("\n", $bulkStatus['results'] ?? ['✅ Bulk install selesai.']));

            $outputText = trim((string) ($bulkStatus['output'] ?? ''));
            if ($outputText !== '') {
                session()->flash('output', $outputText);
            }

            $this->clearBulkStatus();
        } elseif ($bulkStatus && ($bulkStatus['status'] ?? null) === 'failed') {
            session()->flash('error', implode("\n", $bulkStatus['results'] ?? ['❌ Bulk install gagal dijalankan.']));

            $outputText = trim((string) ($bulkStatus['output'] ?? ''));
            if ($outputText !== '') {
                session()->flash('output', $outputText);
            }

            $this->clearBulkStatus();
        } elseif ($bulkStatus && ($bulkStatus['status'] ?? null) === 'running') {
            session()->flash('success', '⏳ Bulk install sedang berjalan di background. Refresh halaman ini beberapa detik lagi untuk melihat hasilnya.');
        }

        return view('admin.protect-manager', [
            'config' => $config,
            'protections' => $config['protections'],
            'bulkStatus' => $bulkStatus,
        ]);
    }

    /**
     * Install proteksi
     */
    public function install(Request $request)
    {
        $this->authorizeAccess();
        $key = $request->input('protection_key');
        $config = $this->getConfig();

        if (!isset($config['protections'][$key])) {
            return redirect()->route('admin.protect-manager')->with('error', 'Proteksi tidak ditemukan: ' . $key);
        }

        $scriptFilename = 'installprotect.sh';
        $scriptFile = $this->scriptsDir . '/' . $scriptFilename;

        if (!$this->ensureScriptExists($scriptFilename)) {
            return redirect()->route('admin.protect-manager')->with('error', 'Script tidak ditemukan di server maupun GitHub: ' . $scriptFilename);
        }

        // Jalankan fitur yang dipilih dari file tunggal installprotect.sh
        [$output, $returnVar] = $this->runProtectedScript($scriptFile, $config, $key);

        $config['protections'][$key]['enabled'] = ($returnVar === 0);
        $this->saveConfig($config);

        // Re-inject sidebar Protect Manager jika hilang setelah install script
        $this->ensureProtectManagerSidebar();

        // Tunda clear cache hingga response selesai agar request install tetap stabil.
        $this->queueLaravelCacheClear();

        $outputText = $this->normalizeOutput($output);

        if ($returnVar === 0) {
            return redirect()->route('admin.protect-manager')->with('success', "✅ {$config['protections'][$key]['name']} berhasil diinstall!")->with('output', $outputText);
        }

        return redirect()->route('admin.protect-manager')->with('error', "❌ Gagal install {$config['protections'][$key]['name']}")->with('output', $outputText);
    }

    /**
     * Uninstall proteksi (restore dari backup)
     */
    public function uninstall(Request $request)
    {
        $this->authorizeAccess();
        $key = $request->input('protection_key');
        $config = $this->getConfig();

        if (!isset($config['protections'][$key])) {
            return redirect()->route('admin.protect-manager')->with('error', 'Proteksi tidak ditemukan.');
        }

        $res = $this->restoreProtection($key, $config);
        $this->saveConfig($config);

        try { $this->ensureProtectManagerSidebar(); } catch (\Exception $e) {}
        $this->fixLayoutPermissions();
        $this->queueLaravelCacheClear();

        if ($res['restored'] === 0 && !empty($res['errors'])) {
            return redirect()->route('admin.protect-manager')->with('error', '❌ Gagal restore: ' . implode(', ', $res['errors']));
        }

        return redirect()->route('admin.protect-manager')->with('success', "✅ {$res['name']} berhasil di-uninstall! ({$res['restored']} file di-restore)");
    }

    /**
     * Bulk uninstall: restore beberapa proteksi sekaligus dari backup.
     */
    public function bulkUninstall(Request $request)
    {
        $this->authorizeAccess();
        $selected = $request->input('selected_protections', []);
        $config = $this->getConfig();

        if (empty($selected)) {
            return redirect()->route('admin.protect-manager')->with('error', '❌ Tidak ada proteksi yang dipilih untuk di-uninstall.');
        }

        $results = [];
        foreach ($selected as $key) {
            if (!isset($config['protections'][$key])) continue;
            if (!$this->checkInstalled($key, $config['protections'][$key])) continue;

            $res = $this->restoreProtection($key, $config);
            if ($res['restored'] > 0) {
                $results[] = "✅ {$res['name']}: {$res['restored']} file di-restore";
            } elseif (!empty($res['errors'])) {
                $results[] = "❌ {$res['name']}: " . implode(', ', $res['errors']);
            } else {
                $results[] = "⚠️ {$res['name']}: tidak ada backup ditemukan";
            }
        }

        $this->saveConfig($config);
        try { $this->ensureProtectManagerSidebar(); } catch (\Exception $e) {}
        $this->fixLayoutPermissions();
        $this->queueLaravelCacheClear();

        if (empty($results)) {
            return redirect()->route('admin.protect-manager')->with('error', '❌ Tidak ada proteksi terinstall yang dipilih.');
        }

        return redirect()->route('admin.protect-manager')->with('success', "🗑️ Bulk Uninstall selesai:\n" . implode("\n", $results));
    }

    /**
     * Restore satu proteksi dari backup. Mengembalikan ['restored','errors','name']
     */
    private function restoreProtection(string $key, array &$config): array
    {
        $prot = $config['protections'][$key];
        $filesToRestore = [$prot['target_file']];
        if (!empty($prot['extra_files'])) {
            $filesToRestore = array_merge($filesToRestore, $prot['extra_files']);
        }

        $restoredCount = 0;
        $errors = [];
        $markers = ['PROTEKSI_FIT', 'BRANDING_FIT', 'WELCOME_FIT', 'PROTEKSI_NESTS_SIDEBAR'];

        foreach ($filesToRestore as $relPath) {
            $targetFile = $this->panelDir . '/' . $relPath;
            $dir = dirname($targetFile);
            $basename = basename($targetFile);
            $backups = glob($dir . '/' . $basename . '.bak_*');
            if (empty($backups)) continue;

            sort($backups);
            $cleanBackup = null;
            foreach ($backups as $bak) {
                if (!File::exists($bak)) continue;
                $bakContent = File::get($bak);
                $isClean = true;
                foreach ($markers as $m) {
                    if (strpos($bakContent, $m) !== false) { $isClean = false; break; }
                }
                if ($isClean) { $cleanBackup = $bak; break; }
            }
            if (!$cleanBackup) $cleanBackup = $backups[0];

            try {
                $cmd = sprintf('sudo cp %s %s 2>&1', escapeshellarg($cleanBackup), escapeshellarg($targetFile));
                exec($cmd, $cpOutput, $cpReturn);
                if ($cpReturn === 0) {
                    exec(sprintf('sudo chown www-data:www-data %s 2>&1', escapeshellarg($targetFile)));
                    exec(sprintf('sudo chmod 664 %s 2>&1', escapeshellarg($targetFile)));
                    $restoredCount++;
                } else {
                    File::copy($cleanBackup, $targetFile);
                    $restoredCount++;
                }
            } catch (\Exception $e) {
                $errors[] = $relPath . ': ' . $e->getMessage();
            }
        }

        $config['protections'][$key]['enabled'] = false;

        return ['restored' => $restoredCount, 'errors' => $errors, 'name' => $prot['name'] ?? $key];
    }

    /**
     * Fix permissions pada layout files setelah restore.
     */
    private function fixLayoutPermissions(): void
    {
        $layoutFiles = [
            $this->panelDir . '/resources/views/layouts/admin.blade.php',
            $this->panelDir . '/resources/views/layouts/app.blade.php',
            $this->panelDir . '/resources/views/layouts/master.blade.php',
        ];
        foreach ($layoutFiles as $lf) {
            if (File::exists($lf)) {
                exec(sprintf('sudo chown www-data:www-data %s 2>&1', escapeshellarg($lf)));
                exec(sprintf('sudo chmod 664 %s 2>&1', escapeshellarg($lf)));
            }
        }
    }

    /**
     * Update konfigurasi (nama brand, teks, dll)
     */
    public function updateConfig(Request $request)
    {
        $this->authorizeAccess();
        $config = $this->getConfig();

        // Konfigurasi bebas diubah; fitur branding/banner yang aktif akan otomatis di-apply ulang di bawah.

        $config['brand_name'] = $request->input('brand_name', $config['brand_name']);
        $config['brand_text'] = $request->input('brand_text', $config['brand_text']);
        $config['contact_telegram'] = $request->input('contact_telegram', $config['contact_telegram']);
        $config['contact_telegram_2'] = $request->input('contact_telegram_2', $config['contact_telegram_2'] ?? '@FyzAbout');
        $config['brand_label'] = $request->input('brand_label', $config['brand_label'] ?? ($config['brand_name'] ?? 'FyzzModss'));
        $config['bot_link'] = $request->input('bot_link', $config['bot_link']);
        $config['welcome_title'] = $request->input('welcome_title', $config['welcome_title'] ?? '');
        $config['welcome_message'] = $request->input('welcome_message', $config['welcome_message'] ?? '');
        $config['panel_title'] = $request->input('panel_title', $config['panel_title'] ?? '');
        $config['deny_msg_admin'] = $request->input('deny_msg_admin', $config['deny_msg_admin'] ?? '');
        $config['deny_msg_server'] = $request->input('deny_msg_server', $config['deny_msg_server'] ?? '');
        $config['deny_msg_file'] = $request->input('deny_msg_file', $config['deny_msg_file'] ?? '');
        $config['deny_msg_modify'] = $request->input('deny_msg_modify', $config['deny_msg_modify'] ?? '');

        // Update nama dan deskripsi proteksi jika dikirim
        if ($request->has('protection_names')) {
            foreach ($request->input('protection_names') as $key => $name) {
                if (isset($config['protections'][$key])) {
                    $config['protections'][$key]['name'] = $name;
                }
            }
        }
        if ($request->has('protection_descriptions')) {
            foreach ($request->input('protection_descriptions') as $key => $desc) {
                if (isset($config['protections'][$key])) {
                    $config['protections'][$key]['description'] = $desc;
                }
            }
        }

        $this->saveConfig($config);

        $messages = ['✅ Konfigurasi berhasil diupdate!'];
        $outputBlocks = [];

        // Re-apply hanya fitur tampilan (branding & welcome banner) yang memang terinstall.
        foreach (['protect5b' => 'Branding footer', 'protect5c' => 'Welcome banner'] as $reapplyKey => $reapplyLabel) {
            if (!isset($config['protections'][$reapplyKey]) || !$this->checkInstalled($reapplyKey, $config['protections'][$reapplyKey])) {
                continue;
            }

            $scriptFilename = 'installprotect.sh';
            $scriptFile = $this->scriptsDir . '/' . $scriptFilename;

            if (!$this->ensureScriptExists($scriptFilename)) {
                continue;
            }

            [$output, $returnVar] = $this->runProtectedScript($scriptFile, $config, $reapplyKey);

            if ($returnVar === 0) {
                $config['protections'][$reapplyKey]['enabled'] = true;
                $this->saveConfig($config);
                $this->ensureProtectManagerSidebar();
                $messages[] = '🔄 ' . $reapplyLabel . ' otomatis diterapkan ulang dengan konfigurasi baru.';
            } else {
                $messages[] = '⚠️ Gagal re-apply ' . $reapplyLabel . '. Cek output di bawah.';
            }

            $outputText = $this->normalizeOutput($output, 80, 8000);
            if ($outputText !== '') {
                $outputBlocks[] = '[' . $reapplyKey . ']' . "\n" . $outputText;
            }
        }

        $redirect = redirect()->route('admin.protect-manager')->with('success', implode("\n", $messages));

        if (!empty($outputBlocks)) {
            $redirect = $redirect->with('output', trim(implode("\n\n", $outputBlocks)));
        }

        return $redirect;
    }

    // (uploadScript dihapus — script proteksi diunduh otomatis dari GitHub jika belum ada)



    /**
     * Install semua proteksi yang dicentang
     */
    public function bulkInstall(Request $request)
    {
        $this->authorizeAccess();
        $selected = $request->input('selected_protections', []);
        $config = $this->getConfig();

        if (empty($selected)) {
            return redirect()->route('admin.protect-manager')->with('error', '❌ Tidak ada proteksi yang dipilih.');
        }

        $validSelected = [];
        $warnings = [];

        foreach ($selected as $key) {
            if (!isset($config['protections'][$key])) {
                continue;
            }

            $scriptFilename = 'installprotect.sh';

            if (!$this->ensureScriptExists($scriptFilename)) {
                $warnings[] = "⚠️ {$config['protections'][$key]['name']}: Script tidak ditemukan di server maupun GitHub";
                continue;
            }

            $validSelected[] = $key;
        }

        if (empty($validSelected)) {
            return redirect()->route('admin.protect-manager')->with('error', implode("\n", $warnings ?: ['❌ Tidak ada script valid untuk diinstall.']));
        }

        // Jalankan sinkron satu per satu (seperti single install) agar tidak silent-fail
        $results = [];
        $allOutput = [];

        foreach ($validSelected as $key) {
            $scriptFile = $this->scriptsDir . '/installprotect.sh';

            try {
                [$output, $returnVar] = $this->runProtectedScript($scriptFile, $config, $key);

                if ($returnVar === 0) {
                    $config['protections'][$key]['enabled'] = true;
                    $results[] = '✅ ' . ($config['protections'][$key]['name'] ?? $key) . ': Berhasil';
                } else {
                    $config['protections'][$key]['enabled'] = false;
                    $results[] = '❌ ' . ($config['protections'][$key]['name'] ?? $key) . ': Gagal';
                }

                $outputText = $this->normalizeOutput($output, 40, 3000);
                if ($outputText !== '') {
                    $allOutput[] = '[' . $key . '] ' . $outputText;
                }
            } catch (\Exception $e) {
                $results[] = '❌ ' . ($config['protections'][$key]['name'] ?? $key) . ': ' . $e->getMessage();
            }
        }

        $this->saveConfig($config);
        $this->ensureProtectManagerSidebar();
        $this->queueLaravelCacheClear();

        $allResults = array_merge($results, $warnings);
        $combinedOutput = $this->normalizeOutput($allOutput, 80, 8000);

        $redirect = redirect()->route('admin.protect-manager')
            ->with('success', implode("\n", $allResults));

        if ($combinedOutput !== '') {
            $redirect = $redirect->with('output', $combinedOutput);
        }

        return $redirect;
    }
}
PHPEOF

chmod 644 "$CONTROLLER_PATH"
echo "✅ Controller dibuat: $CONTROLLER_PATH"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# BAGIAN 3: Buat View (Blade Template)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎨 BAGIAN 3: Buat Blade View"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ -f "$VIEW_PATH" ]; then
    cp "$VIEW_PATH" "${VIEW_PATH}.bak_${TIMESTAMP}"
fi

cat > "$VIEW_PATH" << 'VIEWEOF'
@extends('layouts.admin')

@section('title')
    Protect Manager
@endsection

@section('content-header')
    <h1>🛡️ Protect Manager<small>Kelola proteksi panel Anda</small></h1>
    <ol class="breadcrumb">
        <li><a href="{{ route('admin.index') }}">Admin</a></li>
        <li class="active">Protect Manager</li>
    </ol>
@endsection

@section('content')
<style>
    :root {
        --pm-bg: #0b1424;
        --pm-card: #101d33;
        --pm-card-hover: #14253f;
        --pm-border: #1e3a5f;
        --pm-accent: #3b82f6;
        --pm-accent-2: #60a5fa;
        --pm-text: #e2e8f0;
        --pm-muted: #94a3b8;
        --pm-green: #22c55e;
        --pm-red: #ef4444;
    }
    .pm-wrap { max-width: 1200px; margin: 0 auto; }
    .pm-hero {
        background: linear-gradient(135deg, #0c1929 0%, #1a365d 60%, #1d4ed8 130%);
        border: 1px solid var(--pm-border);
        border-radius: 16px;
        padding: 28px 30px;
        margin-bottom: 22px;
        display: flex;
        align-items: center;
        justify-content: space-between;
        flex-wrap: wrap;
        gap: 16px;
    }
    .pm-hero h2 { color: #dbeafe; margin: 0 0 6px 0; font-size: 24px; font-weight: 700; }
    .pm-hero p { color: var(--pm-muted); margin: 0; font-size: 14px; max-width: 560px; }
    .pm-stats { display: flex; gap: 10px; flex-wrap: wrap; }
    .pm-stat {
        background: rgba(15, 23, 42, 0.6);
        border: 1px solid var(--pm-border);
        border-radius: 12px;
        padding: 10px 18px;
        text-align: center;
        min-width: 96px;
    }
    .pm-stat .num { font-size: 22px; font-weight: 700; color: #fff; line-height: 1.1; }
    .pm-stat .lbl { font-size: 11px; color: var(--pm-muted); text-transform: uppercase; letter-spacing: 0.5px; }
    .pm-stat.green .num { color: #4ade80; }
    .pm-stat.slate .num { color: #94a3b8; }

    .pm-toolbar {
        background: var(--pm-card);
        border: 1px solid var(--pm-border);
        border-radius: 14px;
        padding: 14px 18px;
        margin-bottom: 18px;
        display: flex;
        align-items: center;
        gap: 14px;
        flex-wrap: wrap;
        position: sticky;
        top: 10px;
        z-index: 50;
        box-shadow: 0 8px 24px rgba(2, 6, 23, 0.45);
    }
    .pm-search {
        flex: 1;
        min-width: 200px;
        background: #0f172a;
        border: 1px solid #334155;
        color: var(--pm-text);
        border-radius: 10px;
        padding: 9px 14px 9px 36px;
        font-size: 14px;
        background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='14' height='14' fill='%2394a3b8' viewBox='0 0 16 16'%3E%3Cpath d='M11.7 10.3l3.1 3.1-1.4 1.4-3.1-3.1a6 6 0 1 1 1.4-1.4zM6 11a5 5 0 1 0 0-10 5 5 0 0 0 0 10z'/%3E%3C/svg%3E");
        background-repeat: no-repeat;
        background-position: 12px center;
    }
    .pm-search:focus { border-color: var(--pm-accent); outline: none; box-shadow: 0 0 0 3px rgba(59,130,246,0.15); }
    .pm-toggle-label {
        display: inline-flex; align-items: center; gap: 8px;
        color: var(--pm-text); font-size: 13px; cursor: pointer; user-select: none;
        padding: 6px 10px; border-radius: 8px; border: 1px solid transparent;
    }
    .pm-toggle-label:hover { background: #0f172a; border-color: #334155; }
    .pm-btn {
        border: none; border-radius: 10px; padding: 10px 20px;
        font-size: 13px; font-weight: 600; cursor: pointer; color: #fff;
        transition: transform .15s, box-shadow .15s, opacity .15s;
    }
    .pm-btn:hover { transform: translateY(-1px); }
    .pm-btn:disabled { opacity: .45; cursor: not-allowed; transform: none; }
    .pm-btn-install { background: linear-gradient(135deg, #2563eb, #3b82f6); box-shadow: 0 4px 14px rgba(37,99,235,.35); }
    .pm-btn-uninstall { background: linear-gradient(135deg, #dc2626, #ef4444); box-shadow: 0 4px 14px rgba(220,38,38,.3); }
    .pm-count { font-size: 12px; color: var(--pm-muted); }

    .pm-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(330px, 1fr)); gap: 14px; }
    .pm-card {
        background: linear-gradient(160deg, var(--pm-card) 0%, #0d1a2e 100%);
        border: 1px solid var(--pm-border);
        border-radius: 14px;
        padding: 18px;
        cursor: pointer;
        position: relative;
        transition: border-color .2s, box-shadow .2s, transform .15s, background .2s;
        overflow: hidden;
    }
    .pm-card::before {
        content: ''; position: absolute; left: 0; top: 0; bottom: 0; width: 4px;
        background: #475569; transition: background .2s;
    }
    .pm-card.installed::before { background: var(--pm-green); }
    .pm-card:hover { border-color: var(--pm-accent); background: var(--pm-card-hover); transform: translateY(-2px); box-shadow: 0 10px 26px rgba(2,6,23,.5); }
    .pm-card.checked { border-color: var(--pm-accent); box-shadow: 0 0 0 2px rgba(59,130,246,.35), 0 10px 26px rgba(2,6,23,.5); }
    .pm-card.checked-to-remove { border-color: var(--pm-red); box-shadow: 0 0 0 2px rgba(239,68,68,.3), 0 10px 26px rgba(2,6,23,.5); }
    .pm-card-head { display: flex; align-items: flex-start; gap: 12px; }
    .pm-check {
        width: 20px; height: 20px; margin-top: 2px; cursor: pointer; flex-shrink: 0;
        accent-color: var(--pm-accent);
    }
    .pm-check.remove { accent-color: var(--pm-red); }
    .pm-title { color: var(--pm-text); font-size: 15px; font-weight: 600; margin-bottom: 4px; }
    .pm-desc { color: var(--pm-muted); font-size: 12.5px; line-height: 1.5; margin-bottom: 12px; min-height: 36px; }
    .pm-meta { display: flex; align-items: center; justify-content: space-between; gap: 8px; flex-wrap: wrap; }
    .pm-badge { padding: 3px 11px; border-radius: 999px; font-size: 11px; font-weight: 600; display: inline-flex; align-items: center; gap: 5px; }
    .pm-badge.on { background: rgba(34,197,94,.15); color: #4ade80; border: 1px solid rgba(34,197,94,.35); }
    .pm-badge.off { background: rgba(100,116,139,.15); color: #94a3b8; border: 1px solid rgba(100,116,139,.3); }
    .pm-key { color: #475569; font-size: 11px; font-family: monospace; background: rgba(15,23,42,.7); padding: 2px 8px; border-radius: 6px; border: 1px solid #1e293b; }
    .pm-card-actions { margin-top: 12px; padding-top: 12px; border-top: 1px dashed #1e3a5f; display: flex; justify-content: flex-end; }
    .pm-btn-sm { border: none; border-radius: 8px; padding: 6px 16px; font-size: 12px; font-weight: 600; cursor: pointer; color: #fff; transition: opacity .15s; }
    .pm-btn-sm:hover { opacity: .85; }
    .pm-btn-sm.install { background: linear-gradient(135deg, #2563eb, #3b82f6); }
    .pm-btn-sm.uninstall { background: linear-gradient(135deg, #dc2626, #ef4444); }

    .pm-tab-btn {
        background: var(--pm-card); border: 1px solid var(--pm-border); color: var(--pm-muted);
        padding: 10px 24px; border-radius: 10px; cursor: pointer; font-size: 14px; font-weight: 600;
        transition: all .2s; margin-right: 8px;
    }
    .pm-tab-btn.active, .pm-tab-btn:hover { background: #1e3a5f; border-color: var(--pm-accent); color: #93c5fd; }

    .config-section {
        background: linear-gradient(160deg, var(--pm-card) 0%, #0d1a2e 100%);
        border: 1px solid var(--pm-border);
        border-radius: 14px;
        padding: 24px;
        margin-bottom: 20px;
    }
    .config-section h3 { color: #93c5fd; margin: 0 0 20px 0; font-size: 17px; font-weight: 700; }
    .config-input {
        background: #0f172a; border: 1px solid #334155; color: var(--pm-text);
        border-radius: 8px; padding: 8px 12px; width: 100%; font-size: 14px; transition: border-color .2s;
    }
    .config-input:focus { border-color: var(--pm-accent); outline: none; box-shadow: 0 0 0 3px rgba(59,130,246,.1); }
    .config-label { color: var(--pm-muted); font-size: 13px; margin-bottom: 5px; display: block; }
    .btn-save-config {
        background: linear-gradient(135deg, #7c3aed, #8b5cf6); color: #fff; border: none;
        padding: 10px 28px; border-radius: 10px; font-size: 14px; font-weight: 600; cursor: pointer;
        box-shadow: 0 4px 14px rgba(124,58,237,.35); transition: transform .15s;
    }
    .btn-save-config:hover { transform: translateY(-1px); }
    .alert-custom { border-radius: 10px; padding: 15px 20px; margin-bottom: 20px; font-size: 14px; }
    .output-box {
        background: #0f172a; border: 1px solid #334155; border-radius: 10px; padding: 14px;
        color: var(--pm-muted); font-family: monospace; font-size: 12px; max-height: 220px;
        overflow-y: auto; white-space: pre-wrap; margin-bottom: 18px;
    }
    .editable-name, .editable-desc {
        background: transparent; border: 1px solid transparent; border-radius: 6px;
        padding: 4px 8px; width: 100%; transition: all .2s;
    }
    .editable-name { color: var(--pm-text); font-size: 14px; font-weight: 600; }
    .editable-desc { color: var(--pm-muted); font-size: 13px; }
    .editable-name:hover, .editable-name:focus, .editable-desc:hover, .editable-desc:focus {
        background: #0f172a; border-color: #334155; outline: none;
    }
    .pm-empty {
        text-align: center; color: var(--pm-muted); padding: 40px 20px;
        border: 1px dashed var(--pm-border); border-radius: 14px; font-size: 14px;
    }
</style>

@php
    $totalProt = count($protections);
    $installedProt = collect($protections)->where('installed', true)->count();
    $notInstalledProt = $totalProt - $installedProt;
@endphp

<div class="pm-wrap">

{{-- Notifikasi --}}
@if(session('success'))
    <div class="alert alert-success alert-custom">{!! nl2br(e(session('success'))) !!}</div>
@endif
@if(session('error'))
    <div class="alert alert-danger alert-custom">{!! nl2br(e(session('error'))) !!}</div>
@endif
@if(session('output'))
    <div class="output-box">{{ session('output') }}</div>
@endif

{{-- Hero + Statistik --}}
<div class="pm-hero">
    <div>
        <h2>🛡️ Protect Manager</h2>
        <p>Centang fitur proteksi yang ingin diaktifkan, lalu klik <b>Terapkan</b>. Setiap fitur berdiri sendiri dan bisa dinyalakan/dimatikan satu per satu.</p>
    </div>
    <div class="pm-stats">
        <div class="pm-stat"><div class="num">{{ $totalProt }}</div><div class="lbl">Total Fitur</div></div>
        <div class="pm-stat green"><div class="num">{{ $installedProt }}</div><div class="lbl">Aktif</div></div>
        <div class="pm-stat slate"><div class="num">{{ $notInstalledProt }}</div><div class="lbl">Nonaktif</div></div>
    </div>
</div>

{{-- Tab Navigation --}}
<div style="margin-bottom: 18px;">
    <button class="pm-tab-btn active" onclick="showTab('protections', this)">🔒 Proteksi</button>
    <button class="pm-tab-btn" onclick="showTab('config', this)">⚙️ Konfigurasi</button>
</div>

{{-- TAB: Proteksi --}}
<div id="tab-protections">
    <form id="bulkInstallForm" action="{{ route('admin.protect-manager.bulk-install') }}" method="POST">
        @csrf
    </form>
    <form id="bulkUninstallForm" action="{{ route('admin.protect-manager.bulk-uninstall') }}" method="POST" onsubmit="return confirm('🗑️ Uninstall semua proteksi yang dicentang? File akan direstore dari backup.');">
        @csrf
    </form>

    {{-- Toolbar --}}
    <div class="pm-toolbar">
        <input type="text" id="pmSearch" class="pm-search" placeholder="Cari fitur proteksi..." oninput="filterCards(this.value)">
        <label class="pm-toggle-label" title="Centang semua yang belum terinstall">
            <input type="checkbox" class="pm-check" id="selectAll" onchange="toggleAll(this)"> Pilih nonaktif
        </label>
        <label class="pm-toggle-label" title="Centang semua yang sudah terinstall">
            <input type="checkbox" class="pm-check remove" id="selectAllUninstall" onchange="toggleAllUninstall(this)"> Pilih aktif
        </label>
        <span class="pm-count" id="pmSelectedInfo">0 dipilih</span>
        <button type="submit" form="bulkInstallForm" class="pm-btn pm-btn-install" id="btnBulkInstall" disabled>🚀 Terapkan (<span id="cntInstall">0</span>)</button>
        <button type="submit" form="bulkUninstallForm" class="pm-btn pm-btn-uninstall" id="btnBulkUninstall" disabled>🗑️ Uninstall (<span id="cntUninstall">0</span>)</button>
    </div>

    {{-- Protection Cards --}}
    <div class="pm-grid" id="pmGrid">
        @foreach($protections as $key => $prot)
        <div class="pm-card {{ $prot['installed'] ? 'installed' : '' }}" data-name="{{ strtolower($prot['name'] . ' ' . $prot['description'] . ' ' . $key) }}" onclick="cardClicked(event, this)">
            <div class="pm-card-head">
                @if(!$prot['installed'])
                <input type="checkbox" name="selected_protections[]" value="{{ $key }}" form="bulkInstallForm" class="pm-check protect-check" onclick="event.stopPropagation()" onchange="syncCardState(this)">
                @else
                <input type="checkbox" name="selected_protections[]" value="{{ $key }}" form="bulkUninstallForm" class="pm-check remove protect-uninstall-check" onclick="event.stopPropagation()" onchange="syncCardState(this)">
                @endif
                <div style="flex:1;">
                    <div class="pm-title">{{ $prot['name'] }}</div>
                    <div class="pm-desc">{{ $prot['description'] }}</div>
                </div>
            </div>
            <div class="pm-meta">
                @if($prot['installed'])
                    <span class="pm-badge on">● Aktif</span>
                @else
                    <span class="pm-badge off">○ Nonaktif</span>
                @endif
                <span class="pm-key">{{ $key }}</span>
            </div>
            <div class="pm-card-actions">
                @if(!$prot['installed'])
                <form action="{{ route('admin.protect-manager.install') }}" method="POST" style="display:inline;" onclick="event.stopPropagation()">
                    @csrf
                    <input type="hidden" name="protection_key" value="{{ $key }}">
                    <button type="submit" class="pm-btn-sm install" onclick="return confirm('Install {{ $prot['name'] }}?')">Install</button>
                </form>
                @else
                <form action="{{ route('admin.protect-manager.uninstall') }}" method="POST" style="display:inline;" onclick="event.stopPropagation()">
                    @csrf
                    <input type="hidden" name="protection_key" value="{{ $key }}">
                    <button type="submit" class="pm-btn-sm uninstall" onclick="return confirm('Uninstall {{ $prot['name'] }}? Ini akan restore dari backup.')">Uninstall</button>
                </form>
                @endif
            </div>
        </div>
        @endforeach
    </div>
    <div class="pm-empty" id="pmEmpty" style="display:none;">🔍 Tidak ada fitur yang cocok dengan pencarian.</div>
</div>

{{-- TAB: Konfigurasi --}}
<div id="tab-config" style="display: none;">
    <div style="background: linear-gradient(135deg, #38bdf822, #38bdf811); border: 1px solid #38bdf855; border-radius: 12px; padding: 16px 20px; margin-bottom: 20px; display: flex; align-items: center; gap: 12px;">
        <span style="font-size: 24px;">💡</span>
        <div>
            <strong style="color: #7dd3fc;">Konfigurasi Bebas Diubah</strong>
            <p style="color: #93c5fd; margin: 4px 0 0; font-size: 13px;">Setelah disimpan, fitur <b>Branding Footer</b> dan <b>Welcome Banner</b> yang aktif akan otomatis dipasang ulang dengan nilai baru. Fitur lain tidak ikut diubah.</p>
        </div>
    </div>

    <form action="{{ route('admin.protect-manager.update-config') }}" method="POST">
        @csrf
        <fieldset style="border:none;padding:0;margin:0;">

        {{-- 1. Brand Identity --}}
        <div class="config-section">
            <h3>🏷️ Identitas Brand</h3>
            <p style="color:#64748b;font-size:12px;margin:-12px 0 18px 0;">Nama dan label yang muncul di footer panel, judul tab browser, dan badge proteksi.</p>
            <div class="row">
                <div class="col-md-6">
                    <div class="form-group">
                        <label class="config-label">Nama Brand <span style="color:#64748b;font-weight:400;">(footer, title)</span></label>
                        <input type="text" name="brand_name" value="{{ $config['brand_name'] ?? 'FyzzModss' }}" class="config-input" placeholder="FyzzModss">
                    </div>
                </div>
                <div class="col-md-6">
                    <div class="form-group">
                        <label class="config-label">Teks Proteksi <span style="color:#64748b;font-weight:400;">(badge & pesan abort)</span></label>
                        <input type="text" name="brand_text" value="{{ $config['brand_text'] ?? 'Protect By FyzzModss' }}" class="config-input" placeholder="Protect By FyzzModss">
                    </div>
                </div>
                <div class="col-md-12">
                    <div class="form-group">
                        <label class="config-label">Judul Panel <span style="color:#64748b;font-weight:400;">(tag &lt;title&gt; browser)</span></label>
                        <input type="text" name="panel_title" value="{{ $config['panel_title'] ?? ($config['brand_name'] ?? 'FyzzModss') }}" class="config-input" placeholder="Pterodactyl - Brand Anda">
                    </div>
                </div>
            </div>
        </div>

        {{-- 2. Kontak --}}
        <div class="config-section">
            <h3>💬 Kontak & Bot</h3>
            <p style="color:#64748b;font-size:12px;margin:-12px 0 18px 0;">Akan muncul di footer panel, banner "Protected by", dan welcome banner. Awali dengan <code>@</code>.</p>
            <div class="row">
                <div class="col-md-4">
                    <div class="form-group">
                        <label class="config-label">Username Telegram Admin</label>
                        <input type="text" name="contact_telegram" value="{{ $config['contact_telegram'] ?? '@FyzzModss' }}" class="config-input" placeholder="@FyzzModss">
                    </div>
                </div>
                <div class="col-md-4">
                    <div class="form-group">
                        <label class="config-label">Username Telegram Admin 2 (Protected by)</label>
                        <input type="text" name="contact_telegram_2" value="{{ $config['contact_telegram_2'] ?? '@FyzAbout' }}" class="config-input" placeholder="@adminkedua">
                    </div>
                </div>
                <div class="col-md-4">
                    <div class="form-group">
                        <label class="config-label">Username Bot Telegram</label>
                        <input type="text" name="bot_link" value="{{ $config['bot_link'] ?? '@upgradeuser_bot' }}" class="config-input" placeholder="@botanda">
                    </div>
                </div>
                <div class="col-md-12">
                    <div class="form-group">
                        <label class="config-label">Label Brand (Protected by)</label>
                        <input type="text" name="brand_label" value="{{ $config['brand_label'] ?? ($config['brand_name'] ?? 'FyzzModss') }}" class="config-input" placeholder="Nama brand untuk tag Protected by">
                        <small style="color:#64748b;font-size:11px;">Teks pada label biru di banner "Protected by" halaman daftar server. Bisa beda dengan Nama Brand utama.</small>
                    </div>
                </div>
            </div>
        </div>

        {{-- 3. Welcome Banner --}}
        <div class="config-section">
            <h3>📋 Welcome Banner (Client Dashboard)</h3>
            <p style="color:#64748b;font-size:12px;margin:-12px 0 18px 0;">Banner info yang tampil di halaman daftar server client. Bisa pakai tag HTML seperti <code>&lt;a href="https://t.me/username"&gt;@username&lt;/a&gt;</code> untuk link Telegram.</p>
            <div class="row">
                <div class="col-md-12">
                    <div class="form-group">
                        <label class="config-label">Judul Banner</label>
                        <input type="text" name="welcome_title" value="{{ $config['welcome_title'] ?? 'Welcome To Server FyzzModss' }}" class="config-input" placeholder="Welcome To Server ...">
                    </div>
                </div>
                <div class="col-md-12">
                    <div class="form-group">
                        <label class="config-label">Pesan Banner</label>
                        <textarea name="welcome_message" class="config-input" rows="3" placeholder="Pesan welcome untuk client...">{{ $config['welcome_message'] ?? '' }}</textarea>
                    </div>
                </div>
            </div>
        </div>

        {{-- 4. Pesan Akses Ditolak (KUSTOM) --}}
        <div class="config-section">
            <h3>🚫 Pesan Akses Ditolak</h3>
            <p style="color:#64748b;font-size:12px;margin:-12px 0 18px 0;">Override pesan default yang muncul ketika user mencoba akses fitur terproteksi. Kosongkan untuk pakai default.</p>
            <div class="row">
                <div class="col-md-12">
                    <div class="form-group">
                        <label class="config-label">Menu Admin <span style="color:#64748b;font-weight:400;">(Nests / Settings / Nodes / Locations)</span></label>
                        <input type="text" name="deny_msg_admin" value="{{ $config['deny_msg_admin'] ?? '' }}" class="config-input" placeholder="Akses ditolak — hanya admin utama yang dapat membuka menu ini.">
                    </div>
                </div>
                <div class="col-md-12">
                    <div class="form-group">
                        <label class="config-label">Akses Server <span style="color:#64748b;font-weight:400;">(intip server orang lain)</span></label>
                        <input type="text" name="deny_msg_server" value="{{ $config['deny_msg_server'] ?? '' }}" class="config-input" placeholder="Akses ditolak. Anda hanya bisa melihat server milik sendiri.">
                    </div>
                </div>
                <div class="col-md-12">
                    <div class="form-group">
                        <label class="config-label">Akses File Server <span style="color:#64748b;font-weight:400;">(download / browse file)</span></label>
                        <input type="text" name="deny_msg_file" value="{{ $config['deny_msg_file'] ?? '' }}" class="config-input" placeholder="Anda tidak memiliki akses ke file server ini.">
                    </div>
                </div>
                <div class="col-md-12">
                    <div class="form-group">
                        <label class="config-label">Modifikasi Server <span style="color:#64748b;font-weight:400;">(ubah owner / detail)</span></label>
                        <input type="text" name="deny_msg_modify" value="{{ $config['deny_msg_modify'] ?? '' }}" class="config-input" placeholder="Hanya admin utama yang bisa mengubah detail server.">
                    </div>
                </div>
            </div>
        </div>

        {{-- 5. Edit Nama Proteksi --}}
        <div class="config-section">
            <h3>✏️ Nama & Deskripsi Proteksi</h3>
            <p style="color:#64748b;font-size:12px;margin:-12px 0 18px 0;">Ubah label proteksi yang tampil di tab "Proteksi". Tidak mengubah perilaku script.</p>
            @foreach($protections as $key => $prot)
            <div style="padding: 12px 0; border-bottom: 1px solid #1e3a5f;">
                <div class="row">
                    <div class="col-md-1" style="display: flex; align-items: center; justify-content: center;">
                        <span class="pm-key">{{ $key }}</span>
                    </div>
                    <div class="col-md-4">
                        <input type="text" name="protection_names[{{ $key }}]" value="{{ $prot['name'] }}" class="editable-name" placeholder="Nama proteksi">
                    </div>
                    <div class="col-md-7">
                        <input type="text" name="protection_descriptions[{{ $key }}]" value="{{ $prot['description'] }}" class="editable-desc" placeholder="Deskripsi">
                    </div>
                </div>
            </div>
            @endforeach
        </div>

        <div style="text-align: right; margin-top: 15px;">
            <button type="submit" class="btn-save-config">💾 Simpan Konfigurasi</button>
        </div>
        </fieldset>
    </form>
</div>

</div>{{-- /pm-wrap --}}

<script>
function showTab(tab, btn) {
    document.getElementById('tab-protections').style.display = 'none';
    document.getElementById('tab-config').style.display = 'none';
    document.getElementById('tab-' + tab).style.display = 'block';

    document.querySelectorAll('.pm-tab-btn').forEach(b => b.classList.remove('active'));
    btn.classList.add('active');
}

function refreshSelectionUI() {
    var installCount = document.querySelectorAll('.protect-check:checked').length;
    var uninstallCount = document.querySelectorAll('.protect-uninstall-check:checked').length;
    document.getElementById('cntInstall').textContent = installCount;
    document.getElementById('cntUninstall').textContent = uninstallCount;
    document.getElementById('btnBulkInstall').disabled = installCount === 0;
    document.getElementById('btnBulkUninstall').disabled = uninstallCount === 0;
    var total = installCount + uninstallCount;
    document.getElementById('pmSelectedInfo').textContent = total + ' dipilih';

    var allInstall = document.querySelectorAll('.protect-check');
    var allUninstall = document.querySelectorAll('.protect-uninstall-check');
    var sa = document.getElementById('selectAll');
    var sau = document.getElementById('selectAllUninstall');
    if (sa) sa.checked = allInstall.length > 0 && installCount === allInstall.length;
    if (sau) sau.checked = allUninstall.length > 0 && uninstallCount === allUninstall.length;
}

function syncCardState(cb) {
    var card = cb.closest('.pm-card');
    if (card) {
        card.classList.toggle('checked', cb.checked && cb.classList.contains('protect-check'));
        card.classList.toggle('checked-to-remove', cb.checked && cb.classList.contains('protect-uninstall-check'));
    }
    refreshSelectionUI();
}

function toggleAll(checkbox) {
    document.querySelectorAll('.protect-check').forEach(cb => {
        cb.checked = checkbox.checked;
        syncCardState(cb);
    });
    refreshSelectionUI();
}
function toggleAllUninstall(checkbox) {
    document.querySelectorAll('.protect-uninstall-check').forEach(cb => {
        cb.checked = checkbox.checked;
        syncCardState(cb);
    });
    refreshSelectionUI();
}

function cardClicked(event, card) {
    if (event.target.closest('button') || event.target.closest('form') || event.target.closest('input') || event.target.closest('a')) {
        return;
    }
    var cb = card.querySelector('input[type="checkbox"]');
    if (cb) {
        cb.checked = !cb.checked;
        syncCardState(cb);
    }
}

function filterCards(query) {
    var q = (query || '').toLowerCase().trim();
    var visible = 0;
    document.querySelectorAll('#pmGrid .pm-card').forEach(card => {
        var match = q === '' || (card.getAttribute('data-name') || '').indexOf(q) !== -1;
        card.style.display = match ? '' : 'none';
        if (match) visible++;
    });
    document.getElementById('pmEmpty').style.display = visible === 0 ? 'block' : 'none';
}

refreshSelectionUI();
</script>
@endsection
VIEWEOF

chmod 644 "$VIEW_PATH"
echo "✅ View dibuat: $VIEW_PATH"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# BAGIAN 4: Tambah Route
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🛣️  BAGIAN 4: Tambah Route"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

ROUTES_FILE="$PANEL_DIR/routes/admin.php"

if [ ! -f "$ROUTES_FILE" ]; then
    echo "❌ File routes tidak ditemukan: $ROUTES_FILE"
else
    cp "$ROUTES_FILE" "${ROUTES_FILE}.bak_${TIMESTAMP}"
    echo "💾 Backup: ${ROUTES_FILE}.bak_${TIMESTAMP}"

    if grep -q "protect-manager" "$ROUTES_FILE"; then
        echo "⚠️ Route protect-manager sudah ada, skip..."
    else
        # Tambahkan route di akhir file (sebelum closing bracket terakhir jika ada)
        cat >> "$ROUTES_FILE" << 'ROUTEEOF'

/*
|--------------------------------------------------------------------------
| Protect Manager Routes (PROTEKSI_FIT_MASTER)
|--------------------------------------------------------------------------
*/
Route::group(['prefix' => 'protect-manager'], function () {
    Route::get('/', [\Pterodactyl\Http\Controllers\Admin\ProtectManagerController::class, 'index'])->name('admin.protect-manager');
    Route::post('/install', [\Pterodactyl\Http\Controllers\Admin\ProtectManagerController::class, 'install'])->name('admin.protect-manager.install');
    Route::post('/uninstall', [\Pterodactyl\Http\Controllers\Admin\ProtectManagerController::class, 'uninstall'])->name('admin.protect-manager.uninstall');
    Route::post('/update-config', [\Pterodactyl\Http\Controllers\Admin\ProtectManagerController::class, 'updateConfig'])->name('admin.protect-manager.update-config');
    
    Route::post('/bulk-install', [\Pterodactyl\Http\Controllers\Admin\ProtectManagerController::class, 'bulkInstall'])->name('admin.protect-manager.bulk-install');
    Route::post('/bulk-uninstall', [\Pterodactyl\Http\Controllers\Admin\ProtectManagerController::class, 'bulkUninstall'])->name('admin.protect-manager.bulk-uninstall');
});
ROUTEEOF
        echo "✅ Route ditambahkan"
    fi
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# BAGIAN 5: Tambah Sidebar Menu (hanya ID 1)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📌 BAGIAN 5: Tambah Sidebar Menu"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Cari file sidebar/layout admin
LAYOUT_FILE=""
LAYOUT_CANDIDATES=(
    "$PANEL_DIR/resources/views/partials/admin/sidebar.blade.php"
    "$PANEL_DIR/resources/views/layouts/admin.blade.php"
    "$PANEL_DIR/resources/views/layouts/app.blade.php"
    "$PANEL_DIR/resources/views/layouts/master.blade.php"
)

for candidate in "${LAYOUT_CANDIDATES[@]}"; do
    if [ -f "$candidate" ]; then
        LAYOUT_FILE="$candidate"
        break
    fi
done

if [ -z "$LAYOUT_FILE" ]; then
    echo "❌ Layout file tidak ditemukan!"
    echo "⏭️ Skip penambahan sidebar. Tambahkan manual."
else
    echo "📂 Layout ditemukan: $LAYOUT_FILE"
    cp "$LAYOUT_FILE" "${LAYOUT_FILE}.bak_pm_${TIMESTAMP}"
    echo "💾 Backup: ${LAYOUT_FILE}.bak_pm_${TIMESTAMP}"

    if grep -q "PROTEKSI_FIT_MASTER_SIDEBAR" "$LAYOUT_FILE"; then
        echo "⚠️ Sidebar Protect Manager sudah ada, skip..."
    else
        # Cari posisi sidebar - biasanya sebelum </ul> terakhir atau sebelum tag tertentu
        # Strategi: cari baris terakhir yang mengandung "</li>" di dalam sidebar
        # dan inject setelahnya

        # Metode 1: Cari "Settings" menu item sebagai anchor point (biasanya terakhir)
        SETTINGS_LINE=$(grep -n "Settings\|settings\|Configuration" "$LAYOUT_FILE" | grep -i "href\|route\|url" | tail -1 | cut -d: -f1)
        
        if [ -z "$SETTINGS_LINE" ]; then
            # Metode 2: Cari </ul> terakhir di sidebar
            SETTINGS_LINE=$(grep -n "</ul>" "$LAYOUT_FILE" | tail -1 | cut -d: -f1)
        fi

        if [ -n "$SETTINGS_LINE" ]; then
            # Cari </li> terdekat setelah SETTINGS_LINE
            TOTAL_LINES=$(wc -l < "$LAYOUT_FILE")
            INSERT_LINE=$SETTINGS_LINE
            for i in $(seq "$SETTINGS_LINE" $((SETTINGS_LINE + 15))); do
                if [ "$i" -gt "$TOTAL_LINES" ]; then break; fi
                if sed -n "${i}p" "$LAYOUT_FILE" | grep -q "</li>"; then
                    INSERT_LINE=$i
                    break
                fi
            done

            # Inject sidebar menu setelah INSERT_LINE menggunakan temp file
            TEMP_FILE=$(mktemp)
            head -n "$INSERT_LINE" "$LAYOUT_FILE" > "$TEMP_FILE"
            cat >> "$TEMP_FILE" << 'SIDEBAREOF'
                {{-- PROTEKSI_FIT_MASTER_SIDEBAR: Protect Manager Menu --}}
                @if(Auth::user() && Auth::user()->id === 1)
                <li class="{{ Route::currentRouteName() === 'admin.protect-manager' ? 'active' : '' }}">
                    <a href="{{ route('admin.protect-manager') }}">
                        <i class="fa fa-shield"></i> <span>Protect Manager</span>
                    </a>
                </li>
                @endif
                {{-- END PROTEKSI_FIT_MASTER_SIDEBAR --}}
SIDEBAREOF
            tail -n +"$((INSERT_LINE + 1))" "$LAYOUT_FILE" >> "$TEMP_FILE"
            mv "$TEMP_FILE" "$LAYOUT_FILE"
            chmod 644 "$LAYOUT_FILE"
            
            echo "✅ Sidebar menu ditambahkan di baris $INSERT_LINE"
        else
            echo "⚠️ Tidak bisa menemukan posisi sidebar yang tepat"
            echo "📝 Tambahkan manual di layout file:"
            echo '   @if(Auth::user() && Auth::user()->id === 1)'
            echo '   <li><a href="{{ route('\''admin.protect-manager'\'') }}"><i class="fa fa-shield"></i> <span>Protect Manager</span></a></li>'
            echo '   @endif'
        fi
    fi
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# BAGIAN 6: Clear Cache
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo ""
echo "🧹 Membersihkan cache..."
cd "$PANEL_DIR"
php artisan route:clear 2>/dev/null || true
php artisan config:clear 2>/dev/null || true
php artisan cache:clear 2>/dev/null || true
php artisan view:clear 2>/dev/null || true
echo "✅ Semua cache dibersihkan"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SELESAI
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo ""
echo "==========================================="
echo "✅ MASTER INSTALLER SELESAI!"
echo "==========================================="
echo ""
echo "🛡️  Protect Manager berhasil diinstall!"
echo ""
echo "📌 Fitur:"
echo "   • Sidebar menu 'Protect Manager' (hanya untuk Admin ID 1)"
echo "   • Install/Uninstall proteksi via centang & klik"
echo "   • Edit nama brand, teks proteksi, kontak"
echo "   • Edit nama & deskripsi setiap proteksi"
echo "   • Kustomisasi pesan akses ditolak & judul panel"
echo "   • Bulk install (centang beberapa, terapkan sekaligus)"
echo ""
echo "✅ Semua script proteksi sudah otomatis didownload ke server."
echo ""
echo "🌐 Akses: Admin Panel → Sidebar → Protect Manager"
echo ""
echo "⚠️ Jika ada masalah, restore:"
[ -f "${CONTROLLER_PATH}.bak_${TIMESTAMP}" ] && echo "   cp ${CONTROLLER_PATH}.bak_${TIMESTAMP} ${CONTROLLER_PATH}"
echo "   rm ${VIEW_PATH}"
[ -f "${ROUTES_FILE}.bak_${TIMESTAMP}" ] && echo "   cp ${ROUTES_FILE}.bak_${TIMESTAMP} ${ROUTES_FILE}"
[ -f "${LAYOUT_FILE}.bak_pm_${TIMESTAMP}" ] && echo "   cp ${LAYOUT_FILE}.bak_pm_${TIMESTAMP} ${LAYOUT_FILE}"
echo "   cd $PANEL_DIR && php artisan view:clear && php artisan route:clear"
