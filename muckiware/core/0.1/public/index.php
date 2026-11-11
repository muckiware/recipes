<?php declare(strict_types=1);

use Muckiware\Core\Framework\Adapter\Kernel\KernelBootstrap;

$_SERVER['SCRIPT_FILENAME'] = __FILE__;

require_once __DIR__ . '/../vendor/autoload_runtime.php';

if (!file_exists(__DIR__ . '/../.env') && !file_exists(__DIR__ . '/../.env.dist') && !file_exists(__DIR__ . '/../.env.local.php')) {
    $_SERVER['APP_RUNTIME_OPTIONS']['disable_dotenv'] = true;
}

return static fn (array $context) => KernelBootstrap::create($context, require __DIR__ . '/../vendor/autoload.php', dirname(__DIR__));
