# app/models/conversation.rb

## Summary
- Aggregates ordered chat messages.
- Provides append helper (`<<`) and serialization to `{ messages: [...] }`.

## Key Behaviors
- Coerces hashes into `Message` objects.
- Raises if non-Message/non-Hash is appended.

## Related
- `app/models/message.rb` — message value object.


