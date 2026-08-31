const assert = require("node:assert/strict");

global.window = global;

let tokenConfig;
let requestedPrompt;
let revokedToken;

window.google = {
  accounts: {
    oauth2: {
      initTokenClient(config) {
        tokenConfig = config;
        return {
          requestAccessToken(options) {
            requestedPrompt = options.prompt;
            config.callback({
              access_token: "short-lived-token",
              expires_in: 3600,
              scope: config.scope,
            });
          },
        };
      },
      revoke(token, callback) {
        revokedToken = token;
        callback({ successful: true });
      },
    },
  },
};

global.fetch = async () => ({
  ok: true,
  json: async () => ({ email: "dentist@example.test" }),
});

require("../../web/google_calendar_oauth.js");

async function main() {
  assert.equal(window.apexoGoogleCalendarOAuthSupported(), true);

  const raw = await window.apexoGoogleCalendarAuthorize(
    "public-client-id",
    "apexo-user-a",
    true,
  );
  const session = JSON.parse(raw);

  assert.equal(requestedPrompt, "select_account");
  assert.equal(session.accessToken, "short-lived-token");
  assert.equal(session.email, "dentist@example.test");
  assert.equal(session.apexoAccountId, "apexo-user-a");
  assert.match(tokenConfig.scope, /calendar\.events/);
  assert.match(tokenConfig.scope, /userinfo\.email/);

  await window.apexoGoogleCalendarRevoke(session.accessToken);
  assert.equal(revokedToken, "short-lived-token");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
