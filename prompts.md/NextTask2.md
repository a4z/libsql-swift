# Next refactoring

We fork the project, and I want following additions as first step.

While we know that `.sourcekit-lsp/config.json` can fix our VS Code problem, this solution is not optimal.

Better is, adding a build plugin that ensures the static library is linked into the build folder,
so SoureKit can find it.
This is a temporary solution, since I reported the issue, see <https://github.com/swiftlang/swift-package-manager/issues/9567>

So step one, we need a build plugin that creates the link if it does not exist.

There is an existing build plugin for Linux, that does if linux ... , if possible use that.

Read `context.md/VS_CodeIDE.md` for context.

In a future step, I want the binary xcframework out of the GitRepo.
I want an action that builds the xcframework and provides it as download via GitHub releases.
But this will only happen if it is possible to still create the link.
If not, this will have to wait until SPM fixes the issue.

## Solution

### Attempt 1: Build Plugin

Attempted to create symlink via build plugin (similar to Linux approach). Build plugins are sandboxed and can only write to `pluginWorkDirectory` (`.build/plugins/outputs/...`), not to `.build/index-build/arm64-apple-macosx/debug/` where SourceKit expects the library for indexing builds.

Staying with `.sourcekit-lsp/config.json` solution for now.

Next: Try command plugin approach - users/consumers can run `swift package plugin setup-sourcekit` to create the required symlink. This could help downstream users of this library.
