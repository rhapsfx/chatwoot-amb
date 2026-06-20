# AMB Spec Patterns

## High-Value Checks

1. Payload routing
- Ensure mutually exclusive paths are respected (example: `richLinkDataRef` takes precedence over `richLinkData`).

2. Idempotency and locking
- Verify duplicate-send guards (`already_sent?`) and lock failure behavior return controlled errors.

3. Sanitized logging
- For payloads that may include image/base64 fields, assert logs use sanitized data structures.
- Avoid raw `inspect` assertions on unbounded payload hashes.

4. Error and fallback paths
- Cover invalid payload, parse failures, and transport failures with explicit expected responses.

5. State-machine transitions
- In bot service specs, assert state updates and handler routing for quick replies, list pickers, time pickers, and IDR-like payload shapes.

## Common Setup Pattern

```ruby
before do
  allow_any_instance_of(Channel::AppleMessagesForBusiness)
    .to receive(:validate_jwt_credentials)
    .and_return(nil)
end
```

Use the existing style in nearby specs if they already define better-scoped doubles.

## Focused Commands

```bash
bundle exec rspec spec/services/apple_messages_for_business/send_rich_link_service_spec.rb
bundle exec rspec spec/services/apple_messages_for_business/acoustic_house_bot_service_spec.rb
bundle exec rspec spec/services/apple_messages_for_business
bundle exec rspec spec/integration/apple_messages_for_business_message_flow_spec.rb
```
