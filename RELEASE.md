# Releasing GigTypst

A release goes in one order, and nothing but this file enforces it. GigTypst depends on Giggly
and Scales, so it is published after both are on Hex. The documentation links each function to
its source at the tag `v<version>` (`source_ref` in `mix.exs`), so the tag is pushed before the
package is published.

Publishing to Hex needs the maintainer's Hex keys; it is never done by an agent.

1. **Take Giggly and Scales from Hex.** Once Giggly 0.2.0 and Scales 0.2.0 are published, in
   `mix.exs` switch their path deps to `{:giggly, "~> 0.2.0"}` and `{:scales, "~> 0.2.0"}`,
   update the comment above `deps`, run `mix deps.get`, and commit `mix.exs` and `mix.lock`.
   Hex will not build a package with a path dependency.

2. **Set the version.** In `mix.exs`, set `@version` to the release, say `"0.1.0"`, and commit it.

3. **See the gate pass**: `mix quality` locally, and CI on that commit.

4. **Check the package.**

   ```bash
   mix hex.build --unpack
   ```

   The unpacked package should hold `lib/` and `priv/fonts/` (the Liberation Sans fonts and
   their licence, `OFL.txt`, read when a label is laid out), `mix.exs`, `.formatter.exs`,
   `README.md` and `LICENSE`, and nothing else. Delete the unpacked directory afterwards.

5. **Tag and push.**

   ```bash
   git tag v0.1.0
   git push origin main v0.1.0
   ```

6. **Publish.**

   ```bash
   mix hex.publish
   ```
