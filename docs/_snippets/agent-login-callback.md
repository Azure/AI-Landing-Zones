**Entra application administrator — UI app registration**

1. Open **Authentication > Add a platform > Web**.
2. Register the exact UI HTTPS callback:

    ```text
    https://<frontend-hostname>/auth/oauth/azure-ad/callback
    ```

3. Record the UI origin as `https://<frontend-hostname>`, without a trailing slash.
4. Use this origin for `CHAINLIT_URL` in the application settings.
5. Include any supported deployment prefix consistently in the origin and callback.
6. Keep previous callbacks only while they remain approved and required.

**Check:** The callback matches the browser-facing scheme, host and path exactly.
It is not the Foundry endpoint.
