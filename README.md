# autotrade - Hansen Auto Trade Loader

This repository contains `loader_final.lua` — a single-file loader for the Hansen Auto Trade Script.

Usage (after uploading to GitHub `main` branch):

```lua
loadstring(game:HttpGet('https://raw.githubusercontent.com/YOUR_USERNAME/autotrade/main/loader_final.lua'))()
```

Replace `YOUR_USERNAME` with the GitHub account that owns the repository (e.g. `azminug`).

Notes:
- This repository must be public for executors to fetch via `HttpGet`.
- If push fails due to authentication, see the fallback section in this README.

Fallback (manual upload via web):
1. Go to https://github.com/azminug/autotrade
2. Click Add file -> Upload files, drag `loader_final.lua` and `README.md`.
3. Commit and open the file to copy the `Raw` link.

If you want, I can attempt to push from this machine to `https://github.com/azminug/autotrade.git` now; you may need to authenticate locally (Git credential manager / SSH key).
