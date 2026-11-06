# Publishing a release

GitHub Actions builds an installable ZIP and its SHA-256 checksum automatically. It uses the repository's built-in token; no personal access token or CurseForge secret is needed.

The workflows do not publish to CurseForge. Upload the generated ZIP there separately if wanted.

## Prepare the version

1. Finish changes and test them in game, including switching Acquainted off and verifying original settings return.
2. Update the version in **both** `Acquainted/Acquainted.toc` and `Acquainted/Acquainted.lua`.
3. Add a matching `## VERSION` entry at the top of `CHANGELOG.md` with the release notes.
4. Run:

   ```sh
   lua tests/run.lua
   python3 -m unittest discover -s tests -p 'test_*.py'
   python3 scripts/package.py --tag v0.3.0
   ```

   Replace `v0.3.0` with the version being released. The tag must match the two source version fields and changelog. Build output is placed in `dist/`.

5. Commit and push those changes to `main`.

Use a new version/tag for each release. Do not move an already published tag to a different commit.

## Option 1: Use GitHub's website

1. Open the repository's **Releases** page and choose **Draft a new release**.
2. Choose a tag such as `v0.3.0`. Create it against the tested `main` commit if it does not exist.
3. Enter a title, for example **Acquainted 0.3.0**, and paste the matching changelog entry.
4. Mark the release as a prerelease when appropriate, then publish it.
5. Open **Actions → Release** and wait for the workflow to complete.
6. Return to the release. Its assets will include `Acquainted-0.3.0-Forever.zip` and `SHA256SUMS`.

The installable ZIP is the attached **Acquainted** asset, rather than GitHub's automatically generated source archive.

## Option 2: Push a version tag

After the version changes have been committed and pushed:

```sh
git tag v0.3.0
git push origin v0.3.0
```

This runs the same checks, creates a GitHub Release if needed, and attaches the ZIP and checksum. Notes come from the corresponding changelog section. Tags such as `v0.3.0-beta.1` produce prereleases when the source version is `0.3.0-beta.1`.

Publishing a release for an existing tag can trigger a second run. The workflow serializes runs for that tag and replaces only the generated ZIP/checksum assets; it preserves manually written release notes.

## Retry a failed build

Correct the underlying problem and release a new version if the tagged code was wrong. If only an external service failed, rerun the failed workflow from the Actions page. Alternatively, use **Actions → Release → Run workflow**, supplying the existing tag.

A tag/version mismatch, missing changelog entry, failing tests, or malformed addon package stops publication. The workflow needs Actions enabled and permission to write repository contents; its release job declares that permission explicitly.

## Review the release

Extract the ZIP into a clean folder. Its top-level folder must be `Acquainted`, containing `Acquainted.toc`, Lua files, README, and changelog. Do not add local saves, account folders, installation backups, credentials, or development archives.
