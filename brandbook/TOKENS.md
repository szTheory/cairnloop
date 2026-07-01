# Brandbook Token Derivation

The canonical token source is `priv/static/cairnloop.css`. Phase 50 mirrors only the `:root` and `[data-theme="dark"]` `--cl-*` declarations into brandbook collateral.

Generated outputs:

- `brandbook/assets/css/tokens.css`
- `brandbook/color/swatches.json`

Regenerate both outputs after canonical token changes:

```bash
mix run scripts/derive_brandbook_tokens.exs
```

Check for drift before committing:

```bash
mix run scripts/derive_brandbook_tokens.exs --check
```

Do not edit generated token outputs by hand. Change `priv/static/cairnloop.css`, regenerate, review the diff, and rerun the check command.

`brandbook/` is git-tracked collateral for Phase 51 and Phase 52, but it is intentionally outside the Hex package boundary. Keep `mix.exs` package files unchanged unless a later phase explicitly ships brandbook assets.
