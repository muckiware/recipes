#!/usr/bin/env bash

CWD="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"

export PROJECT_ROOT="${PROJECT_ROOT:-"$(dirname "$CWD")"}"
export ENV_FILE=${ENV_FILE:-"${PROJECT_ROOT}/.env"}
export NPM_CONFIG_FUND=false
export NPM_CONFIG_AUDIT=false
export NPM_CONFIG_UPDATE_NOTIFIER=false

# shellcheck source=functions.sh
source "${PROJECT_ROOT}/bin/functions.sh"

curenv=$(declare -p -x)

load_dotenv "$ENV_FILE"

# Restore environment variables set globally
set -o allexport
eval "$curenv"
set +o allexport

set -euo pipefail

export PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true
export DISABLE_ADMIN_COMPILATION_TYPECHECK=true
export PROJECT_ROOT="${PROJECT_ROOT:-"$(dirname "$CWD")"}"

if [[ -e "${PROJECT_ROOT}/vendor/shopware/platform" ]]; then
    ADMIN_ROOT="${ADMIN_ROOT:-"${PROJECT_ROOT}/vendor/shopware/platform/src/Administration"}"
else
    ADMIN_ROOT="${ADMIN_ROOT:-"${PROJECT_ROOT}/vendor/muckiware/master"}"
fi

# Determine how to invoke PHP console commands.
# Inside DDEV container ($IS_DDEV_PROJECT is set): use the local console directly.
# Outside DDEV, with ddev available: delegate PHP calls through `ddev exec` so
# that the correct PHP 8.4 runtime is used (the host may only have PHP 7.x/8.2).
# In CI: use the ci binary as before.
if [[ ${CI:-""} ]]; then
    BIN_TOOL=("${CWD}/ci")
    if [[ ! -x "${BIN_TOOL[0]}" ]]; then
        chmod +x "${BIN_TOOL[0]}"
    fi
elif [[ -n "${IS_DDEV_PROJECT:-}" ]]; then
    BIN_TOOL=("${CWD}/console")
elif command -v ddev >/dev/null 2>&1; then
    BIN_TOOL=(ddev exec bin/console)
else
    BIN_TOOL=("${CWD}/console")
fi

# build admin
[[ ${SHOPWARE_SKIP_BUNDLE_DUMP:-""} ]] || "${BIN_TOOL[@]}" bundle:dump
"${BIN_TOOL[@]}" feature:dump || true

if [[ $(command -v jq) ]]; then
    OLDPWD=$(pwd)
    cd "$PROJECT_ROOT" || exit

    jq -c '.[]' "var/plugins.json" | while read -r config; do
        srcPath=$(echo "$config" | jq -r '(.basePath + .administration.path)')

        # the package.json files are always one upper
        path=$(dirname "$srcPath")
        name=$(echo "$config" | jq -r '.technicalName' )

        skippingEnvVarName="SKIP_$(echo "$name" | sed -e 's/\([a-z]\)/\U\1/g' -e 's/-/_/g')"

        if [[ ${!skippingEnvVarName:-""} ]]; then
            continue
        fi

        if [[ -f "$path/package.json" && ! -d "$path/node_modules" && $name != "administration" ]]; then
            echo "=> Installing npm dependencies for ${name}"

            npm install --prefix "$path" --no-audit --prefer-offline
        fi
    done
    cd "$OLDPWD" || exit
else
    echo "Cannot check extensions for required npm installations as jq is not installed"
fi

(cd "${ADMIN_ROOT}"/Resources/app/administration && npm install --prefer-offline --production)

echo "ADMIN_ROOT ${ADMIN_ROOT}"
# Dump entity schema
if [[ -z "${SHOPWARE_SKIP_ENTITY_SCHEMA_DUMP:-""}" ]] && [[ -f "${ADMIN_ROOT}"/Resources/app/administration/scripts/entitySchemaConverter/entity-schema-converter.ts ]]; then
  mkdir -p "${ADMIN_ROOT}"/Resources/app/administration/test/_mocks_
  SCHEMA_FILE="${ADMIN_ROOT}/Resources/app/administration/test/_mocks_/entity-schema.json"
  # `ddev exec` runs in the project root inside the container, where the host path does not exist
  if [[ "${BIN_TOOL[0]}" == "ddev" ]]; then
    SCHEMA_FILE="${SCHEMA_FILE#"${PROJECT_ROOT}"/}"
  fi
  "${BIN_TOOL[@]}" -e prod framework:schema -s 'entity-schema' "${SCHEMA_FILE}"
  (cd "${ADMIN_ROOT}"/Resources/app/administration && npm run convert-entity-schema)
fi

(cd "${ADMIN_ROOT}"/Resources/app/administration && rm -rdf public/bundles && npm run build)
[[ ${SHOPWARE_SKIP_ASSET_COPY:-""} ]] || "${BIN_TOOL[@]}" assets:install
