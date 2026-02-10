# Forward Auth 配置指南（Traefik / Stargate）

本文档用于在 Buzzy 通过网关（如 Traefik + Stargate）接入 SSO/统一登录时，正确配置 `Forward Auth` 并排查常见 401/重定向循环问题。

## 1. Buzzy 侧环境变量

至少开启以下配置：

```env
FORWARD_AUTH_ENABLED=true
FORWARD_AUTH_TRUSTED_IPS=172.16.0.0/12,127.0.0.1
FORWARD_AUTH_CREATE_SESSION=true
```

推荐再加一层密钥头校验（防止伪造请求）：

```env
FORWARD_AUTH_SECRET_HEADER=X-Forward-Auth-Verified
FORWARD_AUTH_SECRET=<long-random-secret>
```

可选项：

```env
FORWARD_AUTH_AUTO_PROVISION=true
FORWARD_AUTH_DEFAULT_ROLE=member
FORWARD_AUTH_AUTO_CREATE_ACCOUNT=true
FORWARD_AUTH_AUTO_CREATE_ACCOUNT_NAME=My Workspace
```

修改 `.env` 后请重建应用容器：

```bash
docker compose up -d --force-recreate app
```

## 2. Traefik ForwardAuth 关键点

### 必须透传的身份头

网关鉴权通过后，后端应用至少需要收到：

- `X-Auth-Email`（必需）
- `X-Auth-User`（可选）
- `X-Auth-Name`（可选）
- `X-Forwarded-User`（可选）
- `X-Auth-Amr`（可选）

### 推荐透传的校验头

若启用 `FORWARD_AUTH_SECRET_HEADER/FORWARD_AUTH_SECRET`，网关需要向后端附加固定密钥头，例如：

- `X-Forward-Auth-Verified: <same-secret>`

### Traefik 动态配置示例

以下示例仅说明关键字段（按你的网关部署方式改写）：

```yaml
http:
  middlewares:
    stargate-auth:
      forwardAuth:
        address: "http://stargate:8080/verify"
        trustForwardHeader: true
        authResponseHeaders:
          - X-Auth-Email
          - X-Auth-User
          - X-Auth-Name
          - X-Forwarded-User
          - X-Auth-Amr
          - X-Forward-Auth-Verified
```

## 3. 为什么会出现“request not trusted”

在 Traefik 场景中：

- `remote_addr` 往往是网关容器地址（如 `172.18.0.2`）
- `remote_ip` 往往是客户端公网地址（如 `124.x.x.x`，来自 `X-Forwarded-For`）

如果只用 `remote_ip` 判定“是否来自可信网关”，会把真实用户 IP 误判成不可信代理。

当前 Buzzy 已兼容该场景：会综合连接来源与远端 IP 进行信任判断。

## 4. 快速自检清单

1. `whoami` 返回中是否有 `X-Auth-Email`。
2. Buzzy 日志是否出现：
   - `[ForwardAuth] Skipped: request not trusted ...`
   - `[ForwardAuth] Skipped: missing or invalid X-Auth-Email`
3. `FORWARD_AUTH_TRUSTED_IPS` 是否覆盖 Traefik 到 app 的网络段（常见 `172.16.0.0/12`）。
4. 若启用密钥头，Traefik 与 Buzzy 的 header 名称和值是否完全一致。
5. 修改环境变量后是否执行了 `--force-recreate app`。

## 5. 常见现象与处理

- **现象：访问 `/session/new` 返回 401**
  - 原因：Forward Auth 开启但请求未被判定可信，或缺少 `X-Auth-Email`。
  - 处理：先看日志中的 `remote_addr/remote_ip`，再核对 trusted IP 与头透传配置。

- **现象：反复 302 到 `/session/new` 或 `/session/menu`**
  - 原因：请求未完成认证链路，`Current.identity` 未建立。
  - 处理：先修复 trusted 判定与 `X-Auth-Email` 透传，再检查是否开启 `FORWARD_AUTH_CREATE_SESSION=true`。

# Forward Auth integration

Buzzy can authenticate requests using headers set by a Forward Auth gateway (e.g. [Stargate](https://github.com/soulteary/stargate)). When the gateway has already verified the user, it adds headers such as `X-Auth-Email` to the request. If the request is from a **trusted source**, Buzzy treats it as authenticated and sets the current user accordingly—no magic link or login page required.

Terminology note: in this document, **Account** can be read as a user's workspace boundary, while **User** is that person's membership inside a specific Account.

## When to use it

- You put Traefik (or another reverse proxy) and Stargate in front of Buzzy.
- Stargate performs login/session/OTP checks and, on success, forwards the request to Buzzy with extra headers.
- You want a single sign-on flow at the edge so Buzzy does not implement its own login for those requests.

## Required headers from the gateway

The gateway must set at least:

| Header         | Required | Description |
|----------------|----------|-------------|
| `X-Auth-Email` | Yes      | Authenticated user's email (used to find or create Identity and User). |

Optional:

| Header        | Description |
|---------------|-------------|
| `X-Auth-Name` | Gateway's user display name; used as the Buzzy user's display name when auto-provisioning. |
| `X-Auth-Amr`  | Authentication method (e.g. `otp,dingtalk`); for logging/audit only. |

`X-Forwarded-For` and `X-Real-Ip` are not used for authentication but may be used by Buzzy for logging/audit (e.g. `request.remote_ip`).

## Trust and security

Buzzy only trusts Forward Auth headers when the request is considered **trusted**. Do not trust headers from the public internet, or anyone could impersonate users by sending `X-Auth-Email`.

You must configure at least one trust mechanism when Forward Auth is enabled. If both trusted IPs and the secret header are empty or unset, no request is trusted (this avoids accidentally trusting all IPs).

Configure trust using one or both of:

1. **Trusted IPs**  
   Only requests whose `request.remote_ip` is in the configured list (or CIDR) are trusted. Typically you list the IP(s) of your Traefik/Stargate instance(s) or your internal network (e.g. `127.0.0.1`, `10.0.0.0/8`). When Buzzy runs behind Docker and receives requests from Traefik on the same Docker network, the connection may come from a `172.16.0.0/12` address—include that range if you rely on IP trust.

2. **Secret header**  
   The gateway sets a custom header (e.g. `X-Forward-Auth-Verified`) to a shared secret. Buzzy checks that the header value matches the configured secret. Use a strong, random value and keep it secret.

If both are configured, the request must satisfy both (IP in list and secret header correct).

## Configuration (environment variables)

| Variable | Default | Description |
|----------|---------|-------------|
| `FORWARD_AUTH_ENABLED` | (off) | Set to `true` or `1` to enable Forward Auth. |
| `FORWARD_AUTH_TRUSTED_IPS` | (empty) | Comma-separated IPs or CIDRs (e.g. `127.0.0.1,10.0.0.0/8`). If empty, trust is based only on the secret header (if set). |
| `FORWARD_AUTH_SECRET_HEADER` | (none) | Name of the header the gateway sets with the secret (e.g. `X-Forward-Auth-Verified`). |
| `FORWARD_AUTH_SECRET` | (none) | Expected value of that header. Use a long random string. |
| `FORWARD_AUTH_AUTO_PROVISION` | `false` | If `true`, Buzzy will create an Identity (by email) and/or a User (in the current account) when they do not exist. If `false`, the Identity and User must already exist. |
| `FORWARD_AUTH_DEFAULT_ROLE` | `member` | Role assigned when auto-provisioning a User (`owner`, `admin`, `member`, `system`). |
| `FORWARD_AUTH_CREATE_SESSION` | `true` | If `true`, on successful Forward Auth login Buzzy creates a normal session and sets the session cookie so ActionCable and later requests work without headers. If `false`, every request must carry the Forward Auth headers. |
| `FORWARD_AUTH_USE_EMAIL_LOCAL_PART_AND_LOCK_EMAIL` | `false` | If `true`, when authenticating via Forward Auth: the display name is set from the email local part (e.g. `suyang` from `suyang@staff.linkerhub.work`) when auto-provisioning, and the identity's email is locked so it cannot be changed in profile settings. |
| `FORWARD_AUTH_AUTO_CREATE_ACCOUNT` | `true` | When `true`, a Forward Auth user with no accounts gets a new account created automatically and is redirected there, so they never see "You don't have any Buzzy accounts." Set to `false` to require manual sign-up. |
| `FORWARD_AUTH_AUTO_CREATE_ACCOUNT_NAME` | `My Workspace` | Name of the account created when `FORWARD_AUTH_AUTO_CREATE_ACCOUNT` is used. |

## Example: Stargate in front of Buzzy

1. Configure Traefik to use Stargate as Forward Auth for the Buzzy backend.
2. Configure Stargate so that after successful auth it adds `X-Auth-Email` (and optionally `X-Auth-Name`) to the request to Buzzy.
3. Set Buzzy env vars, for example:

   ```bash
   FORWARD_AUTH_ENABLED=true
   FORWARD_AUTH_TRUSTED_IPS=127.0.0.1,10.0.0.0/8
   FORWARD_AUTH_AUTO_PROVISION=true
   FORWARD_AUTH_CREATE_SESSION=true
   ```

4. Ensure requests to Buzzy go through Traefik so the client IP seen by Buzzy is the proxy (and in your trusted range), and the headers are present.

5. **PWA manifest**  
   Buzzy serves the web app manifest at the **root** path (`/manifest.json`) so the gateway can allow it without auth. Configure the gateway (e.g. Stargate or Traefik) to allow unauthenticated `GET /manifest.json` (and optionally `GET /service-worker`) for the Buzzy host. Otherwise the browser’s manifest request is redirected to the login page, which causes CORS errors and breaks PWA install.  
   If the public origin differs from the request host (e.g. behind a proxy), set `PWA_MANIFEST_BASE_URL` to the public origin (e.g. `https://buzzy.lab.dev`) so the manifest link in the HTML points to the correct URL.

## Behaviour summary

- **Authentication order**  
  For each request that requires authentication, Buzzy tries: (1) Forward Auth headers (if enabled and trusted), (2) session cookie, (3) Bearer token, (4) redirect to login. Forward Auth is tried first so that when the request comes through the gateway with headers, the gateway identity is used even if the browser has an old session.

- **Account**  
  The current account is still taken from the URL path (e.g. `/{account_id}/boards`). Forward Auth only identifies the user; access to a given account still depends on that user having a User record in that account (or auto-provisioning, if enabled). When a Forward Auth user with no accounts hits the session menu and `FORWARD_AUTH_AUTO_CREATE_ACCOUNT` is `true` (default), a new account is created for them and they are redirected there, so they do not see "You don't have any Buzzy accounts."

- **Session**  
  If `FORWARD_AUTH_CREATE_SESSION` is `true`, the first successful Forward Auth login creates a Buzzy session and sets the cookie. WebSockets (ActionCable) and subsequent page loads then use the cookie and do not need the Forward Auth headers.

- **Web login and signup**  
  When Forward Auth is enabled, the web login page (`GET /session/new`) and signup flow (`/signup`, `/signup/completion`) are disabled: requests are redirected to the root path or session menu. Magic Link and Bearer token authentication remain available for API and native clients (e.g. `POST /session` and `GET/POST /session/magic_link` with JSON).

- **Logout**  
  When Forward Auth is enabled, the sign-out (logout) action is disabled: the logout button is hidden in the UI (settings menu and user profile), and requests to the session destroy endpoint are rejected (HTML is redirected back, JSON returns 404). Users are expected to sign out at the gateway (e.g. Stargate) instead.

- **Logging**  
  Successful Forward Auth logins are logged (e.g. identity id and email) for audit; secrets and tokens are not logged.

## Risks

- **Trust scope**  
  Do not use a broad range (e.g. `0.0.0.0/0`) or a weak/leaked secret. Restrict to the proxy’s IP(s) and use a strong secret.

- **Multi-tenancy**  
  Forward Auth only answers “who is this user?”. “Which accounts they can access?” is still determined by Buzzy (URL + User membership and Access). Keep gateway and Buzzy configuration in sync if you rely on auto-provisioning.
