# Template Timeslot Preservation Logic

## How Timeslots Are Handled in Bot API

The BotRendererService now has intelligent logic to handle timeslots from three sources:

1. **Template default timeslots** (in template metadata)
2. **API call parameters** (`event.timeslots`)
3. **API call `available_slots`** (dynamic generation)

### Priority Rules

**Rule 1**: `available_slots` always wins
```ruby
# API Call:
parameters: {
  available_slots: [slot1, slot2, slot3]
}

# Result: Uses available_slots (ignores template and event.timeslots)
```

**Rule 2**: If no `available_slots`, preserve template timeslots unless explicitly overridden
```ruby
# Template has: { event: { timeslots: [template_slot1, template_slot2] } }

# API Call:
parameters: {
  event: { title: 'New Title' }  # No timeslots specified
}

# Result: Template timeslots PRESERVED + title updated
# { event: { timeslots: [template_slot1, template_slot2], title: 'New Title' } }
```

**Rule 3**: Empty timeslots in parameters don't clear template timeslots
```ruby
# Template has: { event: { timeslots: [template_slot1, template_slot2] } }

# API Call:
parameters: {
  event: { title: 'New Title', timeslots: [] }  # Empty array
}

# Result: Template timeslots PRESERVED
# { event: { timeslots: [template_slot1, template_slot2], title: 'New Title' } }
# Logs: "[BotRendererService] Preserved 2 template timeslots"
```

**Rule 4**: Non-empty timeslots in parameters DO override template
```ruby
# Template has: { event: { timeslots: [template_slot1, template_slot2] } }

# API Call:
parameters: {
  event: { timeslots: [api_slot1, api_slot2, api_slot3] }
}

# Result: API timeslots override template
# { event: { timeslots: [api_slot1, api_slot2, api_slot3] } }
```

## Implementation Details

The logic is implemented in `app/services/templates/bot_renderer_service.rb` lines 79-126:

```ruby
# 1. Merge parameters
if parameters.present?
  filtered_params = filter_parameters_for_content_type(parameters, actual_content_type)
  filtered_params = filtered_params.reject { |_k, v| v.blank? }

  # 2. Special handling for time picker
  if actual_content_type == 'apple_time_picker' &&
     parameters['available_slots'].blank? &&
     parameters[:available_slots].blank?

    # 3. Check if we need to preserve template timeslots
    if filtered_params['event'].present? && transformed_attrs['event'].present?
      template_timeslots = transformed_attrs.dig('event', 'timeslots')
      param_timeslots = filtered_params.dig('event', 'timeslots')

      # 4. Preserve if template has slots and param has none/empty
      if template_timeslots.present? && (param_timeslots.nil? || param_timeslots.empty?)
        saved_timeslots = template_timeslots
        transformed_attrs = transformed_attrs.deep_merge(filtered_params)
        transformed_attrs['event']['timeslots'] = saved_timeslots  # ← Restore
        Rails.logger.info "[BotRendererService] Preserved #{saved_timeslots.length} template timeslots"
      else
        transformed_attrs = transformed_attrs.deep_merge(filtered_params)
      end
    else
      transformed_attrs = transformed_attrs.deep_merge(filtered_params)
    end
  else
    transformed_attrs = transformed_attrs.deep_merge(filtered_params)
  end
end

# 5. Handle available_slots (takes precedence over everything)
if actual_content_type == 'apple_time_picker'
  available_slots = parameters['available_slots'] || parameters[:available_slots]
  if available_slots.present?
    formatted_timeslots = format_timeslots_for_bot(available_slots)
    transformed_attrs['event'] ||= {}
    transformed_attrs['event']['timeslots'] = formatted_timeslots  # ← Override everything
    Rails.logger.info "[BotRendererService] Converted #{available_slots.length} available_slots to timeslots"
  end
end
```

## Use Cases

### Use Case 1: Dynamic Booking Slots
```ruby
# Bot API provides real-time available appointment slots
POST /bot_templates/send_message
{
  "template_id": 123,
  "parameters": {
    "available_slots": [
      "2025-11-09T10:00:00-08:00",
      "2025-11-09T11:00:00-08:00",
      "2025-11-09T14:00:00-08:00"
    ]
  }
}

# Result: Uses available_slots, ignores template defaults
```

### Use Case 2: Use Template Defaults, Customize Other Fields
```ruby
# Template has 3 default slots, we just want to change title
POST /bot_templates/send_message
{
  "template_id": 123,
  "parameters": {
    "event": {
      "title": "Book a Meeting",
      "timezone_offset": -480
    }
  }
}

# Result: Template's 3 slots preserved, title and timezone updated
```

### Use Case 3: Use Template Defaults Unchanged
```ruby
# Just send the template as-is
POST /bot_templates/send_message
{
  "template_id": 123,
  "parameters": {}
}

# Result: All template defaults used, including timeslots
```

## Testing

Test all scenarios with:
```bash
ruby debug_time_picker_bot_api.rb
```

Or manually test each scenario:
```ruby
# Test 1: available_slots override
service = Templates::BotRendererService.new(
  template_id: template_id,
  parameters: { available_slots: [Time.current.iso8601, (Time.current + 1.hour).iso8601] },
  channel_type: 'apple_messages_for_business'
)
result = service.render_for_bot
puts result[:content_attributes]['event']['timeslots'].inspect

# Test 2: Preserve template slots
service = Templates::BotRendererService.new(
  template_id: template_id,
  parameters: { event: { title: 'New Title' } },
  channel_type: 'apple_messages_for_business'
)
result = service.render_for_bot
puts result[:content_attributes]['event']['timeslots'].inspect

# Test 3: Empty slots don't clear template
service = Templates::BotRendererService.new(
  template_id: template_id,
  parameters: { event: { title: 'New Title', timeslots: [] } },
  channel_type: 'apple_messages_for_business'
)
result = service.render_for_bot
puts result[:content_attributes]['event']['timeslots'].inspect
```

## Logging

Watch for these log messages:
- `"[BotRendererService] Preserved X template timeslots"` - Template slots were preserved
- `"[BotRendererService] Converted X available_slots to timeslots"` - Dynamic slots were used
