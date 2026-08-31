// Google Identity Services token model. Access tokens live only in Flutter's
// in-memory session and are never written to localStorage, PocketBase,
// settings, or appointment records.
window.apexoGoogleCalendarOAuthSupported = function () {
  return Boolean(
    window.google &&
      window.google.accounts &&
      window.google.accounts.oauth2,
  );
};

window.apexoGoogleCalendarAuthorize = function (
  clientId,
  apexoAccountId,
  forceAccountChooser,
) {
  return new Promise(function (resolve, reject) {
    if (!window.apexoGoogleCalendarOAuthSupported()) {
      reject(
        new Error(
          "Google Identity Services is still loading. Try again in a moment.",
        ),
      );
      return;
    }
    let settled = false;
    const finishReject = function (error) {
      if (settled) return;
      settled = true;
      reject(error instanceof Error ? error : new Error(String(error)));
    };
    const timeout = setTimeout(function () {
      finishReject(new Error("Google authorization timed out."));
    }, 120000);
    const client = window.google.accounts.oauth2.initTokenClient({
      client_id: clientId,
      scope: [
        "https://www.googleapis.com/auth/calendar.events",
        "https://www.googleapis.com/auth/userinfo.email",
      ].join(" "),
      callback: async function (response) {
        if (settled) return;
        if (!response || response.error || !response.access_token) {
          clearTimeout(timeout);
          finishReject(
            new Error(
              (response &&
                (response.error_description || response.error)) ||
                "Google authorization failed.",
            ),
          );
          return;
        }
        try {
          const profileResponse = await fetch(
            "https://www.googleapis.com/oauth2/v3/userinfo",
            {
              headers: { Authorization: "Bearer " + response.access_token },
            },
          );
          if (!profileResponse.ok) {
            throw new Error(
              "Could not read the authorized Google account email.",
            );
          }
          const profile = await profileResponse.json();
          if (!profile.email) {
            throw new Error("Google did not return an account email.");
          }
          settled = true;
          clearTimeout(timeout);
          resolve(
            JSON.stringify({
              accessToken: response.access_token,
              email: profile.email,
              scope: response.scope || "",
              expiresAtMilliseconds:
                Date.now() + Number(response.expires_in || 3600) * 1000,
              apexoAccountId: apexoAccountId,
            }),
          );
        } catch (error) {
          clearTimeout(timeout);
          finishReject(error);
        }
      },
      error_callback: function (error) {
        clearTimeout(timeout);
        finishReject(
          new Error(
            (error && error.type) ||
              "Google authorization window failed.",
          ),
        );
      },
    });
    client.requestAccessToken({
      prompt: forceAccountChooser ? "select_account" : "",
    });
  });
};

window.apexoGoogleCalendarRevoke = function (accessToken) {
  return new Promise(function (resolve) {
    if (!window.apexoGoogleCalendarOAuthSupported() || !accessToken) {
      resolve("{}");
      return;
    }
    window.google.accounts.oauth2.revoke(accessToken, function (result) {
      resolve(JSON.stringify(result || {}));
    });
  });
};
