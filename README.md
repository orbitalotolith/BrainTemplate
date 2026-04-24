# BrainTemplate

Skeleton Brain vault. Clone this repo on a new machine to bootstrap a fresh private Brain.

## Bootstrap

```bash
git clone git@github.com:<your-org>/BrainTemplate.git ~/Development/Brain<Name>
cd ~/Development/Brain<Name>
bash _setup.sh           # creates ~/.claude/ symlinks; on Windows use Git Bash
```

Then open Claude Code in this directory and run:

```
/setup-new-brain
```

The skill walks identity, persona, git remotes, and optional BrainShared collab. After it finishes you have a working private Brain.

## Architecture

See [_HowThisWorks.md](_HowThisWorks.md) for the full multi-Brain partner architecture, sync model, and per-project collab pattern.

## Windows prereqs

- Git for Windows (provides Git Bash)
- Settings → Privacy & security → For developers → Developer Mode ON
- `git config --global core.symlinks true`
- SSH key registered with GitHub

See `key-to-dev.md` "New Machine Setup → Windows" for the full list.
