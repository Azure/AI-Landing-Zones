**Configuration operator — environment App Configuration store**

1. Create `ALLOWED_USER_PRINCIPALS` with label `agent-lz` in **Configuration explorer**.
2. Enter only approved users as comma-separated `tenant-id:object-id` values.

`ALLOWED_USER_NAMES` is an alternative list of sign-in names.
The two lists combine with **OR**.
Empty lists admit all successfully authenticated users.
The callback does not fetch Graph group membership.
These lists restrict UI admission, not Foundry access or document ACLs.

Do not leave both admission lists empty for a restricted pilot.
Remove unapproved entries from either admission list.

**Check:** Only the approved pilot users appear in the admission settings.
Each approved user also needs a separate Foundry caller grant.
