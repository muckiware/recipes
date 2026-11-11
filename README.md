# Muckiware Flex Recipes

[Symfony Flex](https://symfony.com/doc/current/setup/flex.html) recipes for the **Muckidrive**
platform: Shopware 6.7 Core used as an application framework, without Checkout, Storefront and
commerce logic.

The recipes set up a Muckidrive project (`config/bundles.php`, front controller, `bin/console`,
`.env`, `.gitignore`, ...) and **replace** the official Shopware recipe, which would register the
Shopware Checkout bundle and the Shopware installer kernel.

## Recipes

| Package | Recipe version | Applies to | Purpose |
|---|---|---|---|
| `muckiware/core` | `0.0` | `0.0.x` | Bundles, project skeleton, front controller using `Muckiware\Core\Installer\InstallerKernel` |
| `muckiware/core` | `0.1` | `>= 0.1` | Same skeleton, front controller delegates to `Muckiware\Core\Framework\Adapter\Kernel\KernelBootstrap` |
| `muckiware/master` | `0.0` | `>= 0.0` | Registers `Muckiware\Master\Administration`, adds the administration build scripts to `bin/` |
| `shopware/core` | `6.7` | `>= 6.7` | **Override**: no bundles and no files, suppresses the official `shopware/core` recipe |
| `symfony/mcp-bundle` | `0.1` | `>= 0.1` | Registers `Symfony\AI\McpBundle\McpBundle` only (no config or route files) |

## Usage in a project

List this endpoint **first** in `composer.json`, before `shopware/recipes` and `flex://defaults`,
and allow contrib recipes:

```json
{
    "extra": {
        "symfony": {
            "allow-contrib": true,
            "endpoint": [
                "https://raw.githubusercontent.com/muckiware/recipes/flex/main/index.json",
                "https://raw.githubusercontent.com/shopware/recipes/flex/main/index.json",
                "flex://defaults"
            ]
        }
    }
}
```

Flex takes the recipe of a package from the **first** endpoint whose `index.json` lists that
package. This is what makes the overrides (`shopware/core`, `symfony/mcp-bundle`) work: if this
endpoint is not listed first, the official recipes win.

## Layout

```
<vendor>/<package>/<version>/manifest.json
<vendor>/<package>/<version>/<files referenced by copy-from-recipe>
```

The `main` branch holds the recipe sources. On every push to `main`, the
[`flex-update`](.github/workflows/flex-update.yml) workflow (the same callable workflow used by
`symfony/recipes` and `shopware/recipes`) generates the Flex endpoint and force-pushes it to the
`flex/main` branch:

```
index.json
<vendor>.<package>.<version>.json
archived/<vendor>.<package>/<ref>.json
RECIPES.md
```

Never edit `flex/main` by hand.

## Version matching

The recipe version is a `<major>.<minor>` directory. Flex reduces the installed package version to
`major.minor` (`0.0.3.0` -> `0.0`, `6.7.15.0` -> `6.7`) and picks the **highest recipe version that
is lower than or equal to it**. Examples:

- `muckiware/core` `0.0.3.0` -> recipe `0.0`; `0.1.0.0` or `0.4.2.0` -> recipe `0.1`
- `symfony/mcp-bundle` `0.9.0`, `0.11.0`, `0.13.0` -> recipe `0.1`

## Adding or changing a recipe

- **New recipe version:** create `<vendor>/<package>/<major.minor>/` (copy the previous version
  as a starting point). It applies to every package release from that `major.minor` on, until a
  higher recipe version exists.
- **Changing an existing version:** edit the files in place. Every change produces a new recipe
  `ref`; projects pick it up with `composer recipes:update <package>` (older refs stay available in
  `archived/`).
- Executable files (scripts in `bin/`) must keep their executable bit (`git update-index --chmod=+x`).
- Top-level files and directories of a recipe must be listed in `copy-from-recipe`.
- Open a pull request; the [QA](.github/workflows/qa.yml) workflow validates the layout and runs
  `symfony-tools/recipes-checker lint:manifests --contrib`.

### The `shopware/core` override must stay file-less

`shopware/core/6.7/manifest.json` only contains a `post-install-output` line. Its job is to make
Flex use this endpoint (and therefore *no* official recipe) for `shopware/core`. Do **not** add
bundles or files to it: `muckiware/core` owns `config/bundles.php`, `public/index.php` and the
project skeleton, and two recipes writing the same files would conflict.

The manifest must not be empty, though: `generate:flex-endpoint` silently skips recipes whose
manifest is empty (`{}`, or only `aliases`), and the package would then be missing from
`index.json`, so the official Shopware recipe would be applied again. `aliases` is also rejected by
`lint:manifests --contrib`. A `post-install-output` entry is the only key that keeps the recipe
listed without touching any project file.

The `6.7` version also covers later Shopware releases (6.8, ...), so no further version
directory is needed.

## First-time setup of the GitHub repository

The callable workflow switches to an existing `flex/main` branch and removes the `*.json` files on
it, so the branch has to be bootstrapped once before the first push to `main`:

```bash
git switch --orphan flex/main
echo '{}' > index.json
git add index.json
git commit -m "chore: bootstrap flex endpoint branch"
git push origin flex/main
git switch main
```

The repository must allow GitHub Actions to write contents (`Settings > Actions > General >
Workflow permissions`), as the workflow pushes `flex/main` with the `GITHUB_TOKEN`.

## License

MIT, see [LICENSE](LICENSE).
