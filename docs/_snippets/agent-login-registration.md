**Entra application administrator — Microsoft Entra admin center**

1. Open [Microsoft Entra admin center](https://entra.microsoft.com/).
2. Select **App registrations > New registration**.
3. Enter a name for this environment's UI application.
4. Select **Accounts in this organizational directory only**.
5. Select **Register**.
6. Record the **Application (client) ID** and **Directory (tenant) ID** in the environment's approved nonsecret deployment record.
7. Open **Expose an API** in this registration.
8. Set the Application ID URI to `api://<client-id>`.
9. Add an enabled delegated scope named `user_impersonation`.
10. Set `api.requestedAccessTokenVersion` to `2` in the registration's manifest.

The same registration is the UI's confidential web client and its exposed API.
The UI needs an access token for this API, not an ID token or Microsoft Graph access token.

Do not enable public client flows to work around a token error.

Microsoft's [registration](https://learn.microsoft.com/entra/identity-platform/quickstart-register-app)
and [exposed-scope procedure](https://learn.microsoft.com/entra/identity-platform/quickstart-configure-app-expose-web-apis)
describe the portal fields. The final callback needs the provisioned UI URL.

**Check:** The tenant/client IDs, API URI, enabled scope and version-2 token setting identify the intended environment.
