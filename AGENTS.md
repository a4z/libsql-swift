# libsql-swift my fork

Is is obvious that Turso is focused on the new Rust implementation,
but I can not wait until this is done.

PRs to the main repo of this library receive no feedback, therefore I create this opinionated fork of the project.

Goals:

- Works for me, on Mac for development, and on Linux for development and for my Sift on the Server app.
- For Mac, we only care about M1 arch, no Intel builds anymore
- Improve testing and documentation
- Learn more about the wrapper, to be able to make a new one for Turso when the Rust version is stable enough.
- IDE experience improvements

## Context

Read all md files in the `context.md` folder for information.

Please note, all the sourcecode we work with is available,
either in `Turso/CLibsql/libsql-c` or the Rust creates we build libsql-c from.

## Development

We work iterative, in small steps. Do not add functionality on the fly without being asked for.

Prompts happen either via prompts, or
are specified ans NextTaskN.md document in the `prompt.md` folder.
Where N defines the order of the tasks. The N number can be 1 to 9999 or even higher

We always work on the latest NextTask number, if not otherwise specified.

Important: NextTask documents in prompt.md folder can already be done, they are not required to be next tasks.
Check the latest number, this one might be in progress.
