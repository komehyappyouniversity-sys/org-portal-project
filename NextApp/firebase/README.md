# Next App Firebase configuration

## UsageLog retention

`memberPrivate/{uid}/usageLogs/{logId}` stores only the UsageLog identifiers,
event type, playback position, and timestamps. Clients calculate `expiresAt` as
`occurredAt + 90 days`. The `usageLogs.expiresAt` collection-group field has a
TTL policy in `firestore.indexes.json`, so normal usage events are eligible for
automatic deletion after 90 days.

Deploy the rules and field configuration together:

```sh
firebase deploy --config NextApp/firebase/firebase.json --only firestore
```

Firestore TTL deletion is asynchronous. Eligible documents are normally
deleted after the expiration timestamp rather than exactly at that instant.

Run the owner-isolation regression test with the local emulator:

```sh
npx --yes firebase-tools@15.24.0 emulators:exec \
  --config NextApp/firebase/firebase.json \
  --project demo-org-portal-next \
  --only auth,firestore \
  'node NextApp/firebase/tests/usage-logs-rules.test.mjs'
```
