# naval_advmobprog

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

---

# Lab Activity 6: Discussion

Lab Activity 6 (Firebase Part II) adds real-time chat on top of the existing
Firebase Authentication from Lab Activity 5. The login/register flow was not
changed: `FirebaseAuth.instance.currentUser` is still the only source of
identity, and Cloud Firestore only stores the profile documents and the chat
messages.

Files used by this activity:

- `lib/services/chat_service.dart` — every Firestore read/write for chat
- `lib/models/message.dart` — the `MessageModel` used for messages
- `lib/screens/chat_screen.dart` — the chat list
- `lib/screens/chat_detailscreen.dart` — the conversation screen
  (`chat_detail_screen.dart` re-exports it so older imports keep working)

## User Structure

Registered accounts live in the Firestore `Users` collection. The existing
`UserService` writes one profile document per Firebase account during sign-up
and during sign-in (with `SetOptions(merge: true)`, so the same document is
refreshed instead of being duplicated):

```
Users
  {firebaseUid}          <- document id = Firebase Authentication UID
    uid        : String  <- same UID, stored explicitly for queries
    email      : String
    username   : String
    firstName  : String
    lastName   : String
    image      : String
```

Relationship between Firebase Authentication and Firestore:

- The Firebase Auth UID is the identity of the account, and it is also the
  **document id** of the profile in `Users`. `Users/{uid}` and the Auth user
  are therefore always the same account — no extra lookup table is needed.
- Deleting the Firebase account also deletes that `Users` document.
- The chat list reads `Users` through a real-time `snapshots()` stream
  (`ChatService.getUsersStream()`), and `ChatService.getUidByEmail(email)`
  queries the stored `email` field to resolve a UID.

No fake users are created and no existing field names were changed.

## Chat Structure

Messages are not stored on the user documents. Each conversation gets its own
room document:

```
chat_rooms
  {chatRoomId}
    messages
      {autoId}
        senderId
        senderEmail
        receiverId
        message
        timestamp
```

The room id is built by `ChatService._buildChatRoomId(userId1, userId2)`:
both UIDs are collected into a list, sorted in ascending order, and joined
with an underscore. For `abc123` and `xyz789` the room is `abc123_xyz789`.

Because the sort happens **before** joining, the pair produces the same id in
both directions. If the ids were joined in the order they were received,
`abc123_xyz789` and `xyz789_abc123` would become two different rooms and the
conversation would be split in half. The deterministic id guarantees exactly
one room per pair of users, so it is used identically when sending and when
reading messages.

## Message Structure

Each document inside `chat_rooms/{chatRoomId}/messages` contains:

- `senderId` — UID of the sender (the signed-in Firebase user)
- `senderEmail` — email of the sender at the time of writing
- `receiverId` — UID of the other participant
- `message` — the trimmed message text
- `timestamp` — a Firestore `Timestamp` (`Timestamp.now()`)

`MessageModel.fromMap()` converts the stored map back into an object and
handles missing, null, `DateTime` or epoch-millisecond values safely, so one
broken document cannot crash the conversation screen. Messages are read with
`orderBy('timestamp', descending: true)` and rendered in a reversed list, so
the newest message is always at the bottom and both sides update in real time
through Firestore snapshots (no manual polling).

## Initiating a Chat

1. The FloatingActionButton on the home screen opens the chat list through the
   existing navigation route `'/chat'`.
2. `ChatScreen` subscribes once to the `Users` stream, excludes the currently
   logged-in user and shows an avatar/placeholder, the user's name and the
   user's email for everyone else.
3. The search bar filters the already loaded list locally (case-insensitive
   match on name, username or email) — no new Firestore request is made per
   keystroke.
4. Tapping a user pushes `ChatDetailScreen(currentUserEmail, tappedUserId,
   tappedUserName)`, which subscribes to that pair's chat room.
5. Sending goes through `ChatService.sendMessage(receiverId, message)`: the
   text is trimmed, empty messages are ignored, the current UID and email are
   taken from `FirebaseAuth.instance.currentUser`, the deterministic room id
   is generated, and the document is written to
   `chat_rooms/{chatRoomId}/messages`.
6. While Firestore confirms the write, the message is shown as an optimistic
   bubble with a spinner and the label **sending...**. When the real-time
   snapshot returns the stored document, the bubble is replaced by the
   confirmed message with its timestamp and a single **✓** check mark. There
   is no delivered/seen tracking in this project, so no read receipt is
   faked. If the write fails, the optimistic bubble is removed and the text is
   put back into the input field with an error message, so the text is never
   silently lost.

Bubbles fade and slide in through a `TweenAnimationBuilder` keyed by the
Firestore document id (or the local pending id), so existing messages never
re-animate, never duplicate and the list keeps scrolling normally.

## Self Chat

A user cannot chat with themselves through the normal UI flow:

- `ChatScreen` filters out the document whose UID matches
  `FirebaseAuth.instance.currentUser.uid`, so the signed-in user never appears
  in their own chat list, and the tap handler additionally ignores an empty or
  self UID.
- As a second safety net, `ChatDetailScreen` checks `_isSelfChat`: if it is
  ever opened with the current user's own UID (or without a signed-in
  session), it shows "You cannot start a chat with yourself." (or a
  sign-in message) instead of a conversation, and the composer is not built at
  all, so no `chat_rooms/{uid_uid}` document can be created from the UI.
# naval_admobproj
