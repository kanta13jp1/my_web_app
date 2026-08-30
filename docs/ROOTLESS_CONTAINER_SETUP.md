# Rootless Podman / Docker development environment

Issue #2842 の再現可能な標準経路は GitHub-hosted Ubuntu runner 上で、Flutter
Dev Container を rootless Podman、Supabase Auth/DB を Rootless Docker で実行する
分離構成です。Windows 11 + WSL2-backed rootless Podman は VS Code 統合の確認や
障害調査が必要な場合だけ利用します。Dev Container 内へ Docker/Podman socket を
マウントせず、Supabase CLI と Flutter の重い image 取得・build・起動は原則クラウドへ
寄せます。

## Cloud-first verification

`.github/workflows/rootless-container-cloud-smoke.yml` は次の 2 job を別々の
GitHub-hosted runner で並行実行します。production secret や hosted Supabase project には
接続せず、権限は `contents: read` だけです。

- **Rootless Dev Container**: native Linux の非 root Podman で image を build し、
  `keep-id` bind mount、非 root UID、sudo 拒否、capability 全削除、
  `no-new-privileges` を確認する。
- **Rootless Docker Supabase Auth and DB**: GitHub runner の rootful Docker daemon を
  停止し、通常ユーザー所有の socket で Rootless Docker daemon を起動する。
  `docker info` の rootless security option、daemon UID、socket owner を確認してから Supabase CLI を
  実行し、Kong 経由の Auth HTTP 200、`pg_isready`、DB volume の permission error
  0 件、正常な `supabase stop --no-backup`、orphan container 0 件を必須とする。

2026-08-30 の [run 33298773318](https://github.com/kanta13jp1/my_web_app/actions/runs/33298773318)
では、Podman 5.8.4 / Flutter 3.38.10 と Docker 29.7.2 / Supabase CLI 2.116.0 の
両 job が成功しました。Supabase lane は repository の `config.toml` を一時 project へ
コピーし、既存 application migration / seed を読み込まない状態で Auth/DB runtime の
互換性だけを検証します。これにより rootless runtime の受け入れを既存 schema drift と
分離します。この smoke は application schema の from-scratch 再構築テストを兼ねません。

関連ファイルの Pull Request では自動実行されます。任意の branch を手動検証する場合は
Actions 画面から **Rootless Container Cloud Smoke** を選ぶか、次を実行します。

```powershell
gh workflow run rootless-container-cloud-smoke.yml `
  --ref <branch> `
  -f scope=all
```

証跡は `rootless-devcontainer-evidence` と `rootless-supabase-evidence` artifact へ
保存されます。runner は ephemeral なので、停止後の image、container、volume は
ローカル PC へ残りません。このため cloud lane では backup volume を残さず停止します。
Windows 上の VS Code provider 設定は repository contract
test で検証し、実機 UI 確認が必要なときだけ次のローカル手順を使います。
リポジトリ全体の resource routing と sparse checkout 方針は
[`CLOUD_FIRST_DEVELOPMENT.md`](./CLOUD_FIRST_DEVELOPMENT.md) に従います。

## Safety gate

Podman のインストール、machine 作成、イメージ取得、コンテナ起動はホスト状態を
変更します。owner の承認後、次を 2 回測定し、両方のサンプルで RAM 使用率 85%
未満かつ空き 2 GB 超であることを確認してください。Windows Podman machine の公式
前提は RAM 6 GB です。このリポジトリの full Supabase/Flutter 検証では、machine に
6 GB を割り当てた後もホストに余裕が残り、C: に 40 GB 以上の空きがある状態を推奨
します。

```powershell
$os = Get-CimInstance Win32_OperatingSystem
[pscustomobject]@{
  UsedRAMPercent = [math]::Round(
    (1 - $os.FreePhysicalMemory / $os.TotalVisibleMemorySize) * 100,
    1
  )
  FreeRAMGB = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
  FreeCGB = [math]::Round((Get-PSDrive C).Free / 1GB, 2)
}
```

条件未達時は machine の作成・起動や `supabase start` を行いません。不要な volume を
削除して空きを作る場合も、先に
[`CONTAINER_RESOURCE_CLEANUP.md`](./CONTAINER_RESOURCE_CLEANUP.md) の退避手順を使います。

2026-08-30 の owner 特例ではゲート未達のまま Windows 実測を行い、Podman 5.8.3 の
rootless user mapping、Docker API、`keep-id` volume write、特権 port 80 の拒否を
確認しました。一方、Supabase DB は schema 初期化中に host RAM が 99.9% へ達し
exit 137 になりました。通常の `supabase stop` で volume backup を保持し、Podman
machine も停止済みです。この結果から、同じ重い smoke をローカル標準経路にはせず、
上記 cloud workflow を採用します。

## Windows 11 + WSL2 Podman

1. 通常ユーザーの PowerShell で WSL2 とツールを確認します。

   ```powershell
   wsl --status
   wsl --list --verbose
   winget show --id RedHat.Podman --exact
   ```

2. owner 承認後に Podman 5 以降を導入します。リポジトリの Windows setup script にも
   同じ package ID が固定されています。

   ```powershell
   winget install --id RedHat.Podman --exact
   ```

3. 安全ゲート通過後、rootless を明示して WSL2-backed machine を作ります。既存の
   machine がある場合は再作成せず、`podman machine inspect` で設定を確認します。

   ```powershell
   podman machine init `
     --cpus 4 `
     --memory 6144 `
     --disk-size 40 `
     --rootful=false `
     --now

   podman machine inspect --format `
     '{{.Name}} {{.State}} rootful={{.Rootful}} memory={{.Resources.Memory}}'
   podman info --format json
   ```

   `rootful=false`、`State=running`、`host.security.rootless=true` を証跡に残します。
   rootful と rootless の image/container/volume は別ストレージです。検証の途中で
   `podman machine set --rootful=true` へ切り替えないでください。

4. VS Code で推奨拡張機能を導入します。

   - Container Tools: `ms-azuretools.vscode-containers`
   - Dev Containers: `ms-vscode-remote.remote-containers`

   `.vscode/settings.json` は次の 2 系統を設定済みです。Container Tools の provider ID
   と Dev Containers の CLI path は別設定なので、片方だけを Docker のまま残さない
   でください。

   ```json
   {
     "containers.containerClient": "com.microsoft.visualstudio.containers.podman",
     "containers.orchestratorClient": "com.microsoft.visualstudio.orchestrators.podmancompose",
     "dev.containers.dockerPath": "podman"
   }
   ```

5. VS Code で **Dev Containers: Rebuild and Reopen in Container** を実行します。
   `.devcontainer/devcontainer.json` は `--userns=keep-id`、capability 全削除、
   `no-new-privileges`、非 root の `vscode` user を固定しています。コンテナ内で確認します。

   ```bash
   test "$(id -u)" -ne 0
   ! sudo -n true
   flutter --version
   flutter pub get
   ```

## Supabase and Flutter smoke

Supabase CLI はホスト PowerShell から実行します。Docker Desktop context ではなく
Podman が選ばれていることを `podman info` で確認してから開始します。

```powershell
podman info --format '{{.Host.Security.Rootless}}'
supabase --version
supabase start
supabase status
podman ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
```

DB コンテナ名を `podman ps` から特定し、Postgres health と volume permission error の
不在を確認します。名前を推測せず、表示された値を `$dbContainer` に設定します。

```powershell
$dbContainer = '<supabase db container name>'
podman exec $dbContainer pg_isready -U postgres
podman logs $dbContainer 2>&1 |
  Select-String -Pattern 'permission denied|operation not permitted'
```

最後の検索が 0 件で、Auth/DB を含む `supabase status` が healthy であることを記録します。
Flutter Dev Container 内では非特権 port 8080 に bind します。

```bash
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080
```

ホストから `http://127.0.0.1:8080` と `http://127.0.0.1:54321/auth/v1/health`
へアクセスし、Flutter と Supabase Auth の応答を記録します。終了時は DB backup を保つ
通常の停止だけを実行します。

```powershell
supabase stop
```

`supabase stop --no-backup`、`podman volume prune`、Podman machine 削除はこの検証に
含めません。

## Rootless limitations and workarounds

### 特権ポート

rootless runtime は通常 1024 未満の特権ポートを bind できません。この repo の
Supabase ports (54320-54324) と Flutter port (8080) はすべて非特権です。80/443 が
必要でも runtime を rootful に切り替えず、8080/8443 のような非特権 port を使い、
OS 管理の reverse proxy で転送します。Linux 管理者が security trade-off を承認した
場合のみ `net.ipv4.ip_unprivileged_port_start` の変更を検討します。

### Volume permission

bind mount で `permission denied` が出た場合は、host path の owner を実行ユーザーへ
戻し、Podman では `--userns=keep-id` を維持します。Podman の `:U` option は host
filesystem の owner を再帰変更するため、対象を確認せず既存 Supabase data に適用
しません。SELinux host では専用 directory に限って `:Z`/`:z` を検討します。

### Networking and Docker API compatibility

Windows の Podman machine は rootless user socket を使用します。別 WSL distribution
から接続する場合は `podman-user.sock` を default connection に設定し、root socket を
選ばないでください。Supabase CLI が runtime を検出できない場合は、Podman の
Docker-compatible socket を `DOCKER_HOST` に設定します。TCP の平文 socket を
0.0.0.0 に公開してはいけません。

Windows の user-mode networking では、`-p 8080:80` が IPv6 loopback だけを
listen する場合があります。IPv4 loopback が必要な container は
`-p 127.0.0.1:8080:80` のように host address を明示します。2026-08-30 の実測では、
明示後に `http://127.0.0.1:8080` と `http://localhost:8080` の両方が HTTP 200 でした。

Supabase CLI と rootless Podman の組み合わせでは GoTrue と DB が healthy でも Kong が
停止し、host の `127.0.0.1:54321` だけが接続拒否になる既知の互換制限があります。
標準 cloud smoke はこの制限を成功扱いせず、Supabase lane だけ Rootless Docker へ
切り替えて gateway の Auth HTTP 200 まで検証します。rootful fallback は使用しません。

## Native Linux / WSL2 Rootless Docker alternative

Linux 側で Docker Engine を標準にする場合は、`uidmap`、`/etc/subuid`、
`/etc/subgid` を準備し、通常ユーザーで公式の setup tool を実行します。

```bash
dockerd-rootless-setuptool.sh install
systemctl --user enable --now docker
docker context use rootless
export DOCKER_HOST="unix://${XDG_RUNTIME_DIR}/docker.sock"
docker info
```

`docker info` の Security Options に `rootless` があり、system-wide の rootful daemon
へ接続していないことを確認します。この経路では VS Code の
`dev.containers.dockerPath` を `docker` に machine override し、Container Tools も
Docker provider に override します。repo default は Windows/Podman のままです。

## Evidence checklist

- Podman/Docker、Supabase CLI、Flutter の version
- 2 回の RAM/C: resource sample
- rootless user/machine/socket の証跡
- VS Code の `containers.containerClient` と `dev.containers.dockerPath`
- Dev Container の非 root UID、sudo拒否、8080応答
- Supabase Auth/DB health、volume permission error 0 件
- privileged port の実測結果と採用した非特権 port
- `supabase stop` 後に orphan process がないこと

Official references:

- [VS Code: Podman with Dev Containers](https://code.visualstudio.com/remote/advancedcontainers/docker-options)
- [VS Code Container Tools provider settings](https://github.com/microsoft/vscode-containers/blob/main/extensions/vscode-containers/package.json)
- [Podman machine](https://docs.podman.io/en/stable/markdown/podman-machine.1.html)
- [Podman rootless limitations](https://github.com/containers/podman/blob/main/rootless.md)
- [Supabase local development](https://supabase.com/docs/guides/local-development)
- [Supabase CLI: rootless Podman / Kong compatibility](https://github.com/supabase/cli/issues/3099)
- [Docker rootless mode](https://docs.docker.com/engine/security/rootless/)
