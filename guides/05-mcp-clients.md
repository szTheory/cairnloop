# MCP Clients

Cairnloop exposes an embedded Model Context Protocol (MCP) router. This allows external AI assistants—like Claude Desktop, Cursor, or your own custom automation runners—to securely connect to your Phoenix application and use the same operator tools that your internal team uses.

Because Cairnloop is embedded in your application, these tools have direct, secure access to your database and business logic without needing an external API sync layer.

## 1. Expose the MCP Endpoint

By default, the Cairnloop router macros do not expose the MCP endpoint to the public internet. You must explicitly mount it in your `router.ex`.

`Cairnloop.Web.MCP.Router` runs `Cairnloop.Web.MCP.AuthPlug` internally. The plug validates Bearer tokens against the configured Cairnloop repo and assigns `conn.assigns.mcp_token` for the router's token-required methods. You may still put your own host auth, rate limiting, or network controls before the forward, but Cairnloop's MCP Bearer token check remains required for JSON-RPC tool access.

```elixir
# lib/my_app_web/router.ex

scope "/mcp" do
  # The MCP router handles initialize, tools/list, and tools/call.
  forward "/", Cairnloop.Web.MCP.Router
end
```

With this configuration, your MCP endpoint is available at `https://your-app.com/mcp`.

Public well-known OAuth/resource metadata may remain mounted for MCP client discovery. Treat that metadata as the public discovery surface only; `initialize`, `tools/list`, and `tools/call` require a valid Bearer token and return HTTP 401 before exposing capabilities, tool metadata, or governed write surfaces.

## 2. Generate a Bearer Token

MCP clients authenticate using a Bearer token. You can generate these tokens directly from the Cairnloop Operator Dashboard.

1. Navigate to the **Settings** surface in the Cairnloop dashboard (e.g., `/support/settings`).
2. Locate the **MCP Access Tokens** section.
3. Click **Generate Token**.
4. Copy the generated raw token immediately. Treat it as an opaque copy-once value: Cairnloop does not
   promise a stable public prefix or parseable token shape. For security, the raw token is never stored
   in the database - only its SHA-256 hash is retained.

## 3. Configure Your Client

Once you have your endpoint URL and Bearer token, configure your MCP client to connect using the SSE (Server-Sent Events) or HTTP transport (Cairnloop supports HTTP POST for JSON-RPC).

### Example: Cursor

To add Cairnloop as an MCP server in Cursor:

1. Open Cursor Settings.
2. Navigate to **Features** > **MCP Servers**.
3. Add a new server:
   - **Name:** Cairnloop (or your app's name)
   - **Type:** command
   - **Command:** Use a script that bridges HTTP to stdio (since Cursor natively expects stdio servers), or use a community HTTP MCP bridge, passing the URL `https://your-app.com/mcp` and an `Authorization: Bearer <raw-token>` header.

### Example: Claude Desktop

If you are using Claude Desktop with an HTTP-to-stdio bridge, configure your `claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "cairnloop": {
      "command": "npx",
      "args": [
        "-y",
        "@smithery/mcp-http-bridge",
        "--url",
        "https://your-app.com/mcp",
        "--header",
        "Authorization: Bearer paste_the_raw_token_here"
      ]
    }
  }
}
```

## How It Works

When an MCP client connects with a valid Bearer token and issues an `initialize` request, Cairnloop returns the MCP protocol version and capabilities. When it issues a valid-token `tools/list` request, Cairnloop dynamically projects your registered `Cairnloop.Tool` implementations into the JSON-RPC response.

When the client issues a valid-token `tools/call` request, Cairnloop does *not* execute the tool blindly. Instead, the request is routed through the exact same `Cairnloop.Governance.propose/3` pipeline used by human operators. That means MCP writes create a governed proposal; this is not inline `run/3` execution.

If the tool's automation policy requires approval (`:require_approval`), the tool call returns a "Proposal created" message synchronously to the AI, and a human operator must approve the execution from the Cairnloop dashboard.

Requests to `initialize`, `tools/list`, and `tools/call` without a valid Bearer token fail closed with HTTP 401 and `WWW-Authenticate: Bearer`. Malformed JSON and unsupported methods still use JSON-RPC error envelopes when the request is not trying to access a token-required method.
