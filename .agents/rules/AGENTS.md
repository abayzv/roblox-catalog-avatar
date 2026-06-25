---
trigger: always_on
---

# AI Antigravity Rules

## General

- Gunakan Bahasa Indonesia.
- Jangan asumsi besar tanpa konfirmasi user.
- Jelaskan singkat sebelum aksi besar atau berisiko.

---

## Roblox Workflow

Project ini pakai **Rojo**.

- Edit script lewat file Rojo / file system.
- Jangan edit script utama langsung lewat Roblox MCP.
- MCP Roblox dipakai terutama untuk inspect dan testing di Roblox Studio.

---

## Roblox MCP Rules

Gunakan MCP Roblox untuk:

- cek struktur DataModel
- cek object/path di Studio
- validasi hasil sync Rojo
- masuk dan keluar Play mode
- baca console output
- ambil screenshot viewport
- test gameplay/runtime
- simulasi input player jika perlu

Untuk fitur runtime/gameplay, jangan cuma pakai `execute_luau`.

Workflow wajib:

1. Edit script via Rojo.
2. Pastikan sync ke Studio.
3. Masuk Play mode.
4. Jalankan test sesuai fitur.
5. Cek console output.
6. Stop Play mode.
7. Laporkan hasil test.

Dilarang klaim “tested” kalau belum Play mode untuk fitur runtime/gameplay.

---

## `execute_luau`

`execute_luau` hanya untuk quick inspect/debug.

Boleh untuk:

- cek object
- cek state
- print/debug ringan

Tidak boleh dianggap testing final untuk:

- gameplay
- UI runtime
- LocalScript
- RemoteEvent / RemoteFunction
- character
- physics
- animation
- tool
- combat
- shop
- inventory
- input player

---

## PowerShell Rules

- Semua command terminal harus PowerShell.
- Jangan pakai syntax bash/Linux.

Dilarang:

```powershell
rm -rf
touch
grep
sed
awk
chmod
cat <<EOF
```

Gunakan PowerShell:

```powershell
Remove-Item
New-Item
Select-String
Get-Content
Set-Content
Add-Content
Copy-Item
Move-Item
Get-ChildItem
```

Minta approval sebelum command berisiko seperti delete, overwrite besar, reset, clean, deploy, publish, atau install besar.

---

## GitHub Rules

- Gunakan `gh api`.
- Jangan pakai `gh issue` atau `gh pr` kecuali user minta eksplisit.

Benar:

```powershell
gh api repos/OWNER/REPO/issues
gh api repos/OWNER/REPO/pulls
gh api repos/OWNER/REPO/issues/NUMBER/comments
```

Dilarang:

```powershell
gh issue list
gh issue create
gh pr list
gh pr create
```

Jangan buat issue, PR, comment, atau label tanpa approval user.

---

## Git Rules

- Jangan `git push` sebelum user approve.
- Jangan push otomatis setelah commit/test/build.
- Sebelum push, tampilkan:
  - branch
  - commit terakhir
  - file berubah
  - remote target

Push hanya boleh kalau user eksplisit bilang:

- "approve push"
- "boleh push"
- "push sekarang"
- "lanjut push"

Dilarang tanpa approval:

```powershell
git push
git push origin
git push --force
git push --force-with-lease
```

---

## Final Rule

Jangan push, deploy, publish, atau upload Roblox place sebelum user approve eksplisit.
